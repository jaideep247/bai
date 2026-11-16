"""Blank-slate test of the product: the distributable set of the parameter framework and the operations framework (and
the shared tools shipped with them) carries no data of the first customer.

The deny list is built here, from the first consumer's own folder (ops-suite), so its words never enter the product:
its object names, the append fields (ZZ*) its code and dictionary name, its scheduler job names and patterns, its
parameter areas, roles, recipient lists, own tables and every e-mail address it holds. The product side is the
distributable set of release/manifest.json (component folders minus the distribution exclusions) plus tools/abaptools.
The product's own rules (no e-mail address outside the example domains, customer columns of delivered CSV files, no
foreign object or append field in production code) are the manifest check (tools/release_manifest.py --check).

Modification log:
2026-11-15 | Initial version (build M: blank-slate install check).
"""
import csv
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import abaptools  # noqa: E402

rm = abaptools.fresh('release_manifest', 'blank_slate_test')
SUITE = os.path.join(ROOT, 'ops-suite')
MANIFEST = os.path.join(ROOT, 'ops-framework', 'release', 'manifest.json')
PLACEHOLDER = re.compile(r'^\s*(‹[^›]*›|<[^>]*>)?\s*$')
EMAIL = re.compile(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}\b')


def _read(path):
    try:
        with open(path, encoding='utf-8') as handle:
            return handle.read()
    except (OSError, UnicodeDecodeError):
        return ''


def _rows(name):
    path = os.path.join(SUITE, 'config', name)
    if not os.path.exists(path):
        return []
    with open(path, encoding='utf-8') as handle:
        return list(csv.DictReader(handle))


def _walk(top, skip=('__pycache__', 'node_modules', 'deps', 'lint_stubs')):
    for d, dirs, names in os.walk(top):
        dirs[:] = sorted(x for x in dirs if x not in skip and not x.startswith('.'))
        for f in sorted(names):
            yield os.path.join(d, f)


def deny_list():
    """{word: why} of the first customer, read from its folder."""
    deny = {}

    def add(word, why, minimum=4):
        word = (word or '').strip()
        if len(word) >= minimum and not PLACEHOLDER.match(word):
            deny.setdefault(word.upper(), why)

    for top in ('src', 'cds'):
        for path in _walk(os.path.join(SUITE, top)):
            name = os.path.basename(path).split('.')[0]
            if name[:1] in ('z', 'Z', 'y', 'Y'):
                add(name, 'object of the first customer')
    for top in ('src', 'ddic', 'cds', 'config', 'docs'):
        for path in _walk(os.path.join(SUITE, top)):
            text = _read(path)
            for word in re.findall(r'\bZZ[A-Z0-9_]+', text):
                add(word, 'append field of the first customer')
            for word in EMAIL.findall(text):
                add(word, 'e-mail address of the first customer')
    for row in _rows('scheduler_jobs.csv'):
        for word in re.findall(r'[ZY][A-Z0-9_]{3,}', row.get('SAP_PATTERN', '')):
            add(word.rstrip('_'), 'scheduler job of the first customer')
        add(row.get('SCHED_JOB'), 'scheduler job of the first customer')
        add(row.get('SCHED_FOLDER'), 'scheduler folder of the first customer')
    for row in _rows('param_areas.csv'):
        add(row.get('AREA'), 'parameter area of the first customer')
    for row in _rows('process_register.csv'):
        add(row.get('AUTH_ROLE'), 'role of the first customer')
    for row in _rows('alert_rules.csv'):
        add(row.get('DESTINATION'), 'recipient list of the first customer')
        add(row.get('ESCALATION_DEST'), 'recipient list of the first customer')
    for line in _read(os.path.join(SUITE, 'config', 'ddic', 'customer_tables.txt')).splitlines():
        add(line.split('#')[0], 'table of the first customer')
    return deny


KINDS = ('ZBP_R', 'ZCL', 'ZIF', 'ZCX', 'ZUI', 'ZR', 'ZC', 'ZI', 'ZA', 'ZD', 'ZE')


def object_prefixes(deny, manifest):
    """Name prefixes of the first customer's objects (kind + its own name space, e.g. a class prefix), so an
    object it once had - not only one it has today - is found; prefixes of the product are never taken."""
    product = [re.compile(rx, re.I) for rx in manifest['namespace']['product_patterns']]
    out = set()
    for name, why in deny.items():
        if why != 'object of the first customer' or '_' not in name:
            continue
        kind = next((k for k in KINDS if name.startswith(k + '_')), None)
        rest = name[len(kind) + 1:] if kind else name
        space = rest.split('_')[0]
        prefix = (kind + '_' if kind else '') + space + '_'
        if len(space) >= 2 and not any(p.search(prefix) for p in product):
            out.add(prefix)
    return out


def product_files():
    manifest = rm.load(MANIFEST)
    files = list(rm.scan_files(ROOT, manifest))
    files += [p for p in _walk(os.path.join(ROOT, 'tools', 'abaptools')) if p.endswith(rm.TEXT_SUFFIXES)]
    return manifest, files


def scan(files, deny, prefixes):
    """Lines of the files that name a word of the deny list or a word starting with one of the prefixes."""
    words = {w for w in deny if '@' not in w}
    mails = {w for w in deny if '@' in w}
    start = re.compile(r'(?<![A-Za-z0-9_])(' + '|'.join(re.escape(p) for p in sorted(prefixes)) + r')\w*', re.I) \
        if prefixes else None
    hits = []
    for path in files:
        text = _read(path)
        upper = text.upper()
        if not (set(re.findall(r'[A-Z0-9_]+', upper)) & words or any(m in upper for m in mails)
                or (start and start.search(text))):
            continue
        for no, line in enumerate(text.splitlines(), start=1):
            found = sorted(set(re.findall(r'[A-Z0-9_]+', line.upper())) & words) + \
                [m for m in mails if m in line.upper()]
            m = start.search(line) if start else None
            if m:
                found.append(m.group(0).upper())
            if found:
                hits.append(f'{os.path.relpath(path, ROOT)}:{no}: {found[0]} ({deny.get(found[0], "object prefix")})')
    return hits


class BlankSlateTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.deny = deny_list()
        cls.manifest, cls.files = product_files()

    def test_deny_list_built_from_the_first_customer(self):
        kinds = set(self.deny.values())
        self.assertIn('object of the first customer', kinds)
        self.assertIn('append field of the first customer', kinds)
        self.assertIn('scheduler job of the first customer', kinds)
        self.assertIn('parameter area of the first customer', kinds)
        self.assertGreater(len(self.deny), 100)

    def test_distributable_set_has_no_first_customer_data(self):
        self.assertEqual(scan(self.files, self.deny, object_prefixes(self.deny, self.manifest)), [])

    def test_object_prefixes_of_the_first_customer(self):
        prefixes = object_prefixes(self.deny, self.manifest)
        self.assertTrue(prefixes)
        self.assertFalse(any(p.startswith(('ZCA_', 'ZCL_CA_', 'ZIF_CA_')) for p in prefixes))

    def test_no_component_folder_of_the_first_customer_in_the_manifest(self):
        folders = {c['folder'] for c in self.manifest['components']}
        self.assertEqual(folders, {'param-framework', 'ops-framework'})
        objects, problems = rm.inventory(ROOT, self.manifest)
        self.assertEqual(problems, [])
        suite_names = {n for n, why in self.deny.items() if why == 'object of the first customer'}
        self.assertEqual(sorted({o['name'] for o in objects} & suite_names), [])

    def test_term_lists_excluded_from_the_distribution(self):
        # the house term lists name the first customer on purpose; they never ship
        excluded = set(self.manifest['distribution']['exclude'])
        for comp in ('param-framework', 'ops-framework'):
            self.assertIn(f'{comp}/config/customer_terms.txt', excluded)
        listed = {os.path.relpath(p, ROOT).replace(os.sep, '/') for p in self.files}
        self.assertFalse(listed & excluded)

    def test_scan_finds_planted_words(self):
        import tempfile
        prefixes = object_prefixes(self.deny, self.manifest)
        word = next(w for w, why in self.deny.items() if why == 'object of the first customer')
        field = next(w for w, why in self.deny.items() if why == 'append field of the first customer')
        old = sorted(prefixes)[0] + 'GONE_LONG_AGO'
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, 'x.abap')
            with open(path, 'w', encoding='utf-8') as handle:
                handle.write(f'  DATA lo TYPE REF TO {word.lower()}.\n* clean line\n  " {field} and {old}\n')
            hits = scan([path], self.deny, prefixes)
        self.assertEqual(len(hits), 2)
        self.assertIn(':1:', hits[0])
        self.assertIn(':3:', hits[1])


if __name__ == '__main__':
    unittest.main()
