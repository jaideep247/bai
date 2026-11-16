#!/usr/bin/env python3
"""Extension proof of the operations framework (build Q, docs/EXTENSION_AND_GATE_PROOF.md): the fictitious customer XX
adds an intake flow and its payment reference by configuration only, and the product's generators turn that
configuration into XX's own objects - never into a product object.

The XX folder examples/intake_xx is a customer folder (docs/EXTENDING_WITH_CUSTOMER_DATA.md section 5):
  config/links         its registry layer is the framework's worked example config/links/examples/xx_overlay.json
                       (objects XX_INTAKE with an identity beyond the request number, custom field ZZXX_PAYREF on the
                       standard items, links into the FI-CA layer); generated here: its seed rows, lineage, snippets,
                       impact (shared engine tools/abaptools/link_registry.py)
  config/extensions    declarations: the intake on the exceptions list (active) and on the break groups through a link
                       ambiguous by design (pending, candidates view and marker) -> src/ext, the pending folder and the
                       report (shared engine tools/abaptools/extensions.py)
  config/payment_model the payment model: payments from XX's register, payment -> intake through registry link
                       XX_ITEM_TO_INTAKE, requests from the intake -> src/paym (shared engine
                       tools/abaptools/payment_model.py and the framework's templates)
  ddic, src            XX's own tables and the abapGit XML of everything in src (shared serializer)

Checks (house check intake_xx of tools/checks.py; root test tools/tests/test_extension_proof.py):
  generated   every generator's output is up to date and lies inside the XX folder
  neutral     no product source (src/, ddic/, templates/, config/ outside the examples, the shared engines) names an
              object, a registry ID or the custom field of the XX intake
With --abaplint <binary>: the generated XX sources compile against the product (examples/intake_xx/abaplint.json).

Usage:  python3 tools/intake_xx.py [--check] [--abaplint <binary>]     (without --check: regenerate the XX folder)

Modification log:
2026-11-16 | Initial version (build Q: extension and release-gate proof).
"""
import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

FOLDER = os.path.join(ROOT, 'examples', 'intake_xx')
OVERLAY = os.path.join(ROOT, 'config', 'links', 'examples', 'xx_overlay.json')
LINKS = {
    'base': abaptools.fresh('link_registry', 'intake_xx_base').PRODUCT_LAYERS,
    'own': ['../../config/links/examples/xx_overlay.json'],
    'seed_folder': 'config/links/seed',
    'docs_folder': 'docs/links',
    'ddic': ['ddic'],
    'payment_model': 'config/payment_model/mapping.json',
    'show_all': True,
    'title': 'Link registry of the example customer XX (intake)',
}
EXTENSIONS = {'pack': 'config/extensions', 'title': 'Extensions of the example customer XX (intake)'}
PAYMENT_MODEL = os.path.join('config', 'payment_model', 'mapping.json')
# Registry IDs and the custom field of the intake flow (never in a product source)
INTAKE_IDS = ('XX_INTAKE', 'XX_INTAKE_TO_ITEMS', 'XX_ITEM_TO_INTAKE', 'XX_GLITEM_TO_INTAKE', 'ZZXX_PAYREF')
PRODUCT_FOLDERS = ('src', 'ddic', 'templates', 'config')
TEXT_EXT = ('.abap', '.asddls', '.asddlxs', '.asdcls', '.asbdef', '.srvdsrv', '.ddl', '.csv', '.json', '.xml', '.tpl',
            '.py')


def engines():
    return (abaptools.fresh('link_registry', 'intake_xx'), abaptools.fresh('extensions', 'intake_xx'),
            abaptools.fresh('payment_model', 'intake_xx'), abaptools.fresh('abapgit_serialize', 'intake_xx'))


def generate(folder=FOLDER):
    """Run the generators on the XX folder (links, extensions, payment model, then the serializer)."""
    links, ext, paym, ser = engines()
    out = links.generate(folder, LINKS)
    written, removed = ext.generate(folder, EXTENSIONS)
    out += written + removed
    written, removed = paym.generate(folder, PAYMENT_MODEL)
    out += written + removed
    ser.main([], folder)
    return out


def check_generated(folder=FOLDER):
    """Out-of-date outputs of the generators (empty = every output is current)."""
    links, ext, paym, ser = engines()
    failures = [f'links: {x}' for x in links.check(folder, LINKS)]
    failures += [f'extensions: {x}' for x in ext.check(folder, EXTENSIONS)]
    failures += [f'payment model: {x} out of date' for x in paym.check(folder, PAYMENT_MODEL)]
    stage, _ = ser.build(folder)
    failures += [f'serializer: {x}' for x in stage.problems]
    failures += [f'serializer: {x} out of date' for x in stage.changed()]
    return failures


def outputs(folder=FOLDER):
    """{path relative to the XX folder: text} of every generator (the serializer excepted)."""
    links, ext, paym, _ = engines()
    _, problems, files = links.outputs(folder, LINKS)
    if problems:
        raise ValueError('\n'.join(problems))
    problems, more, _ = ext.outputs(folder, EXTENSIONS)
    if problems:
        raise ValueError('\n'.join(problems))
    files.update(more)
    spec = paym.load(os.path.join(folder, PAYMENT_MODEL))
    spec['model'].setdefault('spec_name', PAYMENT_MODEL)
    files.update(paym.outputs(folder, spec))
    return files


def intake_names(folder=FOLDER):
    """Object names of the XX intake folder (its src and ddic) plus its registry IDs and custom field."""
    names = set(INTAKE_IDS)
    for path in glob.glob(os.path.join(folder, 'src', '**', '*.*'), recursive=True) + \
            glob.glob(os.path.join(folder, 'ddic', '*.ddl')) + \
            glob.glob(os.path.join(folder, 'config', '*', 'pending', '*.*')):
        base = os.path.basename(path).split('.')[0].upper()
        if base not in ('PACKAGE', ''):
            names.add(base)
    return names


def check_neutral(root=ROOT, folder=FOLDER):
    """No product source names an object of the XX intake (src/, ddic/, templates/, config/ outside examples, the
    shared engines tools/abaptools)."""
    names = intake_names(folder)
    pattern = re.compile(r'\b(' + '|'.join(sorted(map(re.escape, names), key=len, reverse=True)) + r')\b', re.I)
    failures = []
    scopes = [os.path.join(root, f) for f in PRODUCT_FOLDERS] + [os.path.join(root, '..', 'tools', 'abaptools')]
    for scope in scopes:
        for dirpath, dirs, files in os.walk(scope):
            dirs[:] = [d for d in dirs if d not in ('examples', '__pycache__')]
            for name in files:
                if not name.endswith(TEXT_EXT):
                    continue
                path = os.path.join(dirpath, name)
                with open(path, encoding='utf-8') as handle:
                    m = pattern.search(handle.read())
                if m:
                    failures.append(f'{os.path.relpath(path, root)}: names {m.group(1)} of the XX intake example')
    return failures


def check_abaplint(binary, folder=FOLDER):
    out = subprocess.run([binary, 'abaplint.json'], cwd=folder, capture_output=True, text=True).stdout
    m = re.search(r'abaplint: (\d+) issue', out)
    if not m:
        return [f'abaplint did not complete: {out[-300:]}']
    return [] if m.group(1) == '0' else [line for line in out.splitlines() if '[E]' in line][:20]


def failures(root=ROOT, abaplint=None):
    folder = os.path.join(root, 'examples', 'intake_xx')
    out = check_generated(folder) + check_neutral(root, folder)
    if abaplint:
        out += check_abaplint(abaplint, folder)
    return out


def main(argv):
    binary = argv[argv.index('--abaplint') + 1] if '--abaplint' in argv else None
    if '--check' not in argv:
        written = generate()
        print(f'{len(written)} generated file(s) changed in examples/intake_xx')
    found = failures(abaplint=binary)
    if found:
        print('Extension proof of the XX intake: failures', *found, sep='\n  ')
        return 1
    print('XX intake generated by configuration only, up to date; no product object names it'
          + (' (the XX sources compile against the product)' if binary else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
