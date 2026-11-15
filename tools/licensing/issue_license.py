#!/usr/bin/env python3
"""Issue a licence file of the operations framework ZCA_OPS (vendor side; ops-framework/docs/LICENSING.md).

The payload (customer, installation number(s), systems, product versions, modules with their validity, grace days)
is built from a JSON file and / or the arguments, validated against the module catalogue
(ops-framework/config/licensing/modules.json), written as canonical UTF-8 JSON and signed with the vendor's private key
as PKCS#7 / CMS signed data with the content enveloped (openssl cms -sign -nodetach), PEM armoured. The customer
installs the file with the report ZCA_OPS_LICENSE_INSTALL; SSF verifies it with the vendor's certificate in STRUST.

The private key never belongs in this repository: the tool refuses a key file inside it. Standard library and the
openssl command line only.

Usage:
  python3 tools/licensing/issue_license.py --key <vendor key> --cert <vendor cert> --out <licence.pem>
      [--payload <payload.json>] [--license-id ID] [--customer NAME] [--installation 0020123456 ...]
      [--system PS4/100 ...] [--version-from 1.0] [--version-to 1] [--module JOBS:20261115:20271114 ...]
      [--grace-days 30] [--issued-at YYYYMMDDhhmmss] [--payload-out <payload.json>] [--force] [--modules <json>]

A payload file may use the canonical form {"LICENSE": {...}} or friendly lower-case keys (license_id, customer,
installations, systems ["PS4/100"], version_from, version_to, modules [{code, valid_from, valid_to}], grace_days);
arguments win over the file. --force issues a licence whose modules miss a module they require (printed).

Modification log:
2026-11-15 | Initial version (licensing).
"""
import argparse
import datetime
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'tools'))
from abaptools import licensing  # noqa: E402

MODULES = os.path.join(REPO, 'ops-framework', 'config', 'licensing', 'modules.json')


def openssl(args):
    """Run the openssl command line; raises RuntimeError with its message on a failure."""
    try:
        result = subprocess.run(['openssl'] + args, capture_output=True, text=True, check=False)
    except FileNotFoundError as error:
        raise RuntimeError('openssl not found on the PATH') from error
    if result.returncode != 0:
        raise RuntimeError(f'openssl {args[0]} failed: {result.stderr.strip()}')
    return result.stdout


def inside_repository(path):
    return os.path.commonpath([os.path.realpath(path), os.path.realpath(REPO)]) == os.path.realpath(REPO)


def build_payload(args):
    raw = {}
    if args.payload:
        with open(args.payload, encoding='utf-8') as handle:
            raw = json.load(handle)
    payload = licensing.normalise(raw)
    body = payload['LICENSE']
    overrides = {'LICENSE_ID': (args.license_id or '').upper(), 'CUSTOMER': args.customer,
                 'VERSION_FROM': args.version_from, 'VERSION_TO': args.version_to, 'ISSUED_AT': args.issued_at}
    for key, value in overrides.items():
        if value:
            body[key] = value
    if args.installation:
        body['INSTALLATIONS'] = list(args.installation)
    if args.system:
        body['SYSTEMS'] = licensing.normalise({'systems': args.system})['LICENSE']['SYSTEMS']
    if args.module:
        body['MODULES'] = licensing.normalise({'modules': args.module})['LICENSE']['MODULES']
    if args.grace_days is not None:
        body['GRACE_DAYS'] = args.grace_days
    if not body.get('ISSUED_AT'):
        body['ISSUED_AT'] = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%S')
    return payload


def issue(args):
    """Validate, sign and write; returns the payload. Raises ValueError / RuntimeError."""
    if inside_repository(args.key):
        raise ValueError('the private key lies inside the repository - keep it outside (vendor key store)')
    spec = licensing.load(args.modules)
    payload = build_payload(args)
    problems = licensing.validate_payload(payload, spec)
    if problems:
        raise ValueError('payload not valid:\n  ' + '\n  '.join(problems))
    missing = licensing.missing_requirements(payload, spec)
    if missing and not args.force:
        raise ValueError('modules miss what they require (use --force to issue anyway):\n  ' + '\n  '.join(missing))
    with tempfile.TemporaryDirectory() as work:
        content = os.path.join(work, 'payload.json')
        with open(content, 'wb') as handle:
            handle.write(licensing.canonical_json(payload))
        openssl(['cms', '-sign', '-binary', '-nodetach', '-md', 'sha256', '-in', content, '-signer', args.cert,
                 '-inkey', args.key, '-outform', 'PEM', '-out', args.out])
    if args.payload_out:
        with open(args.payload_out, 'w', encoding='utf-8') as handle:
            json.dump(payload, handle, indent=1, ensure_ascii=False)
            handle.write('\n')
    return payload, missing


def parser():
    p = argparse.ArgumentParser(description='Issue a signed licence file of ZCA_OPS (vendor side).')
    p.add_argument('--key', required=True, help="vendor's private key (PEM), outside the repository")
    p.add_argument('--cert', required=True, help="vendor's certificate (PEM) - the one imported in STRUST")
    p.add_argument('--out', required=True, help='licence file to write (PEM)')
    p.add_argument('--payload', help='payload JSON (canonical or friendly keys)')
    p.add_argument('--license-id')
    p.add_argument('--customer')
    p.add_argument('--installation', action='append', help='installation number (repeat)')
    p.add_argument('--system', action='append', help='SID or SID/CLIENT (repeat)')
    p.add_argument('--version-from')
    p.add_argument('--version-to')
    p.add_argument('--module', action='append', help='CODE:YYYYMMDD:YYYYMMDD (repeat)')
    p.add_argument('--grace-days', type=int)
    p.add_argument('--issued-at', help='YYYYMMDDhhmmss (default: now, UTC)')
    p.add_argument('--payload-out', help='also write the signed payload as JSON (the vendor register)')
    p.add_argument('--force', action='store_true', help='issue although a module misses a required module')
    p.add_argument('--modules', default=MODULES, help='module catalogue (default: the framework\'s modules.json)')
    return p


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        payload, missing = issue(args)
    except (ValueError, RuntimeError, OSError) as error:
        print(f'not issued: {error}', file=sys.stderr)
        return 1
    body = payload['LICENSE']
    for item in missing:
        print(f'warning: {item}')
    print(f'issued {body["LICENSE_ID"]} for {body["CUSTOMER"]}: {len(body["MODULES"])} module(s), '
          f'systems {", ".join(s["SID"] + ("/" + s["CLIENT"] if s["CLIENT"] else "") for s in body["SYSTEMS"])} '
          f'-> {args.out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
