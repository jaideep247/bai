#!/usr/bin/env python3
"""Verify a licence file of the operations framework ZCA_OPS offline with the vendor's public certificate
(ops-framework/docs/LICENSING.md) - the vendor's support, a customer's check before the installation, the tests.

Checks the PKCS#7 / CMS signature against the certificate (openssl cms -verify, the certificate as the only trust
anchor), prints the signer's subject and the SHA-256 fingerprint of its certificate (the product's trust anchor
ZIF_CA_OPS_LIC_TYPES=>GC_VENDOR), validates the payload against the module catalogue and, with the identity of a
system, evaluates the licence as the runtime would (the Python twin of ZCL_CA_OPS_LIC_POLICY): licence state VALID /
SIGNATURE / BINDING / VERSION and every module's state on a day.

Usage:
  python3 tools/licensing/verify_license.py --cert <vendor cert> --licence <licence.pem>
      [--today YYYYMMDD] [--installation 0020123456] [--sid PS4] [--client 100] [--version 1.0.0]
      [--warn-days 30] [--enforce W|X] [--modules <json>]
Prints one JSON document; exit 0 when the signature is valid, the payload readable and valid and - with a system
given - the licence state VALID, else 1.

Modification log:
2026-11-15 | Initial version (licensing).
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'tools'))
from abaptools import licensing  # noqa: E402

MODULES = os.path.join(REPO, 'ops-framework', 'config', 'licensing', 'modules.json')
FINGERPRINT = re.compile(r'Fingerprint=([0-9A-F:]+)', re.I)


def _run(args):
    try:
        return subprocess.run(['openssl'] + args, capture_output=True, text=True, check=False)
    except FileNotFoundError as error:
        raise RuntimeError('openssl not found on the PATH') from error


def verify(cert, licence):
    """(signature ok, payload bytes or None, signer subject, signer SHA-256 fingerprint, openssl message)."""
    with tempfile.TemporaryDirectory() as work:
        content = os.path.join(work, 'payload.json')
        signer = os.path.join(work, 'signer.pem')
        result = _run(['cms', '-verify', '-binary', '-inform', 'PEM', '-in', licence, '-CAfile', cert,
                       '-purpose', 'any', '-signer', signer, '-out', content])
        if result.returncode != 0:
            return False, None, '', '', result.stderr.strip()
        with open(content, 'rb') as handle:
            data = handle.read()
        info = _run(['x509', '-in', signer, '-noout', '-subject', '-fingerprint', '-sha256', '-nameopt', 'RFC2253'])
        subject = ''
        sha256 = ''
        for line in info.stdout.splitlines():
            if line.startswith('subject='):
                subject = line[len('subject='):].strip()
            match = FINGERPRINT.search(line)
            if match:
                sha256 = match.group(1).replace(':', '').upper()
        return True, data, subject, sha256, ''


def report(args):
    spec = licensing.load(args.modules)
    ok, data, subject, sha256, message = verify(args.cert, args.licence)
    out = {'signature': 'ok' if ok else 'invalid', 'signer_subject': subject, 'signer_sha256': sha256}
    if not ok:
        out['message'] = message
        return out, False
    try:
        payload = json.loads(data.decode('utf-8'))
    except (UnicodeDecodeError, ValueError) as error:
        out['problems'] = [f'payload not readable: {error}']
        return out, False
    out['payload'] = payload
    out['problems'] = licensing.validate_payload(payload, spec)
    out['missing_requirements'] = licensing.missing_requirements(payload, spec) if not out['problems'] else []
    valid = not out['problems']
    today = licensing._date(args.today) if args.today else datetime.date.today()
    if valid:
        codes = [m['code'] for m in sorted(spec['modules'], key=lambda m: m['seq'])]
        always = tuple(m['code'] for m in spec['modules'] if m.get('always'))
        status = licensing.evaluate(payload, today, installation=args.installation or '', sid=args.sid or '',
                                    client=args.client or '', version=args.version, warn_days=args.warn_days,
                                    enforce=args.enforce, always=always, codes=codes)
        out['status'] = status
        out['today'] = today.strftime('%Y%m%d')
        if args.installation or args.sid:
            valid = status['state'] == 'VALID'
    return out, valid


def parser():
    p = argparse.ArgumentParser(description='Verify a licence file of ZCA_OPS offline.')
    p.add_argument('--cert', required=True, help="vendor's certificate (PEM)")
    p.add_argument('--licence', required=True, help='licence file (PEM)')
    p.add_argument('--today', help='YYYYMMDD (default: today)')
    p.add_argument('--installation')
    p.add_argument('--sid')
    p.add_argument('--client')
    p.add_argument('--version', default='1.0.0', help='product version of the system (default 1.0.0)')
    p.add_argument('--warn-days', type=int, default=30)
    p.add_argument('--enforce', default='W', choices=['W', 'X'])
    p.add_argument('--modules', default=MODULES)
    return p


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        out, valid = report(args)
    except (RuntimeError, OSError) as error:
        print(json.dumps({'signature': 'not checked', 'message': str(error)}))
        return 1
    print(json.dumps(out, indent=1, ensure_ascii=False))
    return 0 if valid else 1


if __name__ == '__main__':
    sys.exit(main())
