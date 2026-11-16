#!/usr/bin/env python3
"""Payment file lifecycle of the operations framework: offline proof of the fixtures and of the worked example XX.

Checks (house check payfile of tools/checks.py; docs/PAYMENT_FILE_LIFECYCLE.md section 10):
  fixtures   config/payfile/fixtures.json gives its expected business results in every profile of the product's tests
             (config/payfile/profiles/*.json) and of the worked example XX (examples/payfile_xx/config/profile.json),
             and the same results in all of them (shared engine tools/abaptools/payfile.py)
  wiring     the example XX is wired only through the product's interfaces and configuration rows: its classes name
             no product class (only ZIF_CA_OPS_PF_* interfaces and ZCX_CA_OPS_ERROR), every class of its adapter rows
             exists (product or example) and implements the interface of its role, every status of its mapping names
             a product milestone and outcome, and its rows are never seeded (no XX row in the product's config)
  neutral    no product source (src/, config/ outside examples) names the example's objects
With --abaplint <binary>: the example XX compiles against the product (examples/payfile_xx/abaplint.json, 0 issues).

Usage:  python3 tools/payfile.py [--abaplint <binary>]     (exit 1 on a failure)

Modification log:
2026-11-15 | Initial version (build K: payment file lifecycle).
"""
import csv
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
from abaptools import payfile as _engine  # noqa: E402

FIXTURES = os.path.join(ROOT, 'config', 'payfile', 'fixtures.json')
EXAMPLE = os.path.join(ROOT, 'examples', 'payfile_xx')
ROLE_INTF = {'FILE': 'ZIF_CA_OPS_PF_FILE_SRC', 'TRANSFER': 'ZIF_CA_OPS_PF_TRANSFER_SRC', 'ACK': 'ZIF_CA_OPS_PF_ACK_SRC',
             'SCHED': 'ZIF_CA_OPS_PF_SCHED_SRC', 'STMT': 'ZIF_CA_OPS_PF_STMT_SRC',
             'TICKET': 'ZIF_CA_OPS_PF_TICKET_SINK', 'CALENDAR': 'ZIF_CA_OPS_PF_CALENDAR'}
ALLOWED_PRODUCT = re.compile(r'^(ZIF_CA_OPS_PF_\w+|ZCX_CA_OPS_ERROR)$')


def profiles(root=ROOT):
    return sorted(glob.glob(os.path.join(root, 'config', 'payfile', 'profiles', '*.json'))) + \
        [os.path.join(root, 'examples', 'payfile_xx', 'config', 'profile.json')]


def _read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def _code(text):
    return '\n'.join(re.sub(r'".*$', '', l) for l in text.splitlines() if not l.lstrip().startswith('*'))


def _classes(folder):
    out = {}
    for path in glob.glob(os.path.join(folder, '*.clas.abap')):
        out[os.path.basename(path).split('.')[0].upper()] = _code(_read(path))
    return out


def _interfaces_of(code):
    return {m.upper() for m in re.findall(r'^\s*INTERFACES\s+(\w+)', code, re.I | re.M)}


def check_wiring(root=ROOT):
    failures = []
    example_classes = _classes(os.path.join(root, 'examples', 'payfile_xx', 'src'))
    product_classes = _classes(os.path.join(root, 'src'))
    for name, code in example_classes.items():
        for token in sorted({t.upper() for t in re.findall(r'\bZ\w+', code, re.I)}):
            if token.startswith(('ZCL_XX_', 'ZIF_XX_', 'ZXX_')):
                continue
            if not ALLOWED_PRODUCT.match(token):
                failures.append(f'example {name}: names product object {token} (only ZIF_CA_OPS_PF_* interfaces and '
                                f'ZCX_CA_OPS_ERROR)')
    cfg = os.path.join(root, 'examples', 'payfile_xx', 'config')
    with open(os.path.join(cfg, 'zca_ops_pfadp.csv'), newline='', encoding='utf-8') as f:
        for row in csv.DictReader(f):
            cls = row['CLASS_NAME'].upper()
            code = example_classes.get(cls) or product_classes.get(cls)
            if code is None:
                failures.append(f'example adapter {row["ROLE"]}: class {cls} exists neither in the product nor in the example')
                continue
            intf = ROLE_INTF.get(row['ROLE'])
            if intf is None or intf not in _interfaces_of(code):
                failures.append(f'example adapter {row["ROLE"]}: class {cls} does not implement {intf}')
    milestones = set(_engine.ORDER)
    with open(os.path.join(cfg, 'zca_ops_pfmap.csv'), newline='', encoding='utf-8') as f:
        for row in csv.DictReader(f):
            if row['MILESTONE'] and row['MILESTONE'] not in milestones:
                failures.append(f'example mapping {row["SOURCE_ID"]}/{row["STATUS"]}: {row["MILESTONE"]} is no milestone')
            if row['OUTCOME'] not in ('OK', 'REJECTED', 'PARTIAL', 'FAILED', 'INFO'):
                failures.append(f'example mapping {row["SOURCE_ID"]}/{row["STATUS"]}: outcome {row["OUTCOME"]}')
    return failures


def check_neutral(root=ROOT):
    """No product object names an object of the example (src/, ddic/, config/; the example's own folder excepted)."""
    names = {os.path.basename(p).split('.')[0].upper()
             for p in glob.glob(os.path.join(root, 'examples', 'payfile_xx', 'src', '*.abap'))
             + glob.glob(os.path.join(root, 'examples', 'payfile_xx', 'ddic', '*.ddl'))}
    pattern = re.compile(r'\b(' + '|'.join(sorted(names)) + r')\b', re.I) if names else None
    failures = []
    for folder in ('src', 'ddic', 'config'):
        for dirpath, _, files in os.walk(os.path.join(root, folder)):
            for name in files:
                path = os.path.join(dirpath, name)
                if pattern and name.endswith(('.abap', '.asddls', '.asddlxs', '.asdcls', '.asbdef', '.srvdsrv', '.ddl',
                                              '.csv', '.json')):
                    m = pattern.search(_read(path))
                    if m:
                        failures.append(f'{os.path.relpath(path, root)}: names the example object {m.group(1)}')
    return failures


def check_abaplint(binary, root=ROOT):
    out = subprocess.run([binary, 'abaplint.json'], cwd=os.path.join(root, 'examples', 'payfile_xx'),
                         capture_output=True, text=True).stdout
    m = re.search(r'abaplint: (\d+) issue', out)
    if not m:
        return [f'abaplint did not complete: {out[-300:]}']
    return [] if m.group(1) == '0' else [l for l in out.splitlines() if '[E]' in l][:20]


def failures(root=ROOT, abaplint=None):
    out = _engine.check_fixtures(FIXTURES if root == ROOT else os.path.join(root, 'config', 'payfile', 'fixtures.json'),
                                 profiles(root))
    out += check_wiring(root) + check_neutral(root)
    if abaplint:
        out += check_abaplint(abaplint, root)
    return out


def main(argv):
    binary = argv[argv.index('--abaplint') + 1] if '--abaplint' in argv else None
    found = failures(abaplint=binary)
    if found:
        print('Payment file lifecycle: failures', *found, sep='\n  ')
        return 1
    print('payment file fixtures, example wiring and neutrality OK' + (' (example XX compiles)' if binary else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
