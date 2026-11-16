#!/usr/bin/env python3
"""Tests of build P (ops-framework/docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md): expected runs of an external scheduler
compared with SAP's jobs, and FI-CA mass activity runs with their intervals and document output.

- Every scenario of the offline fixture spec ops-framework/config/expected_runs/fixtures.json gives its expected
  findings, evaluation and partial flag through the reference model tools/abaptools/expected_runs.py (the rules of
  ZCL_CA_OPS_XRUN_MONITOR, ZCL_CA_OPS_CHK_XRUN and ZCL_CA_OPS_CHK_MA_INTERVAL).
- Every scenario names an existing FOR TESTING method of its check class (and of the classes it also names).
- Check codes and stages are constants of ZIF_CA_OPS_XRUN_TYPES, ZIF_CA_OPS_MA_TYPES or ZIF_CA_OPS_CASH_TYPES.
- Scorecard scenario 1 is there with count, amount, currency, stage JOB_OK, owner, deadline and evidence (run key,
  activity type, parent job, the failed interval and its job); the scenarios never started, predecessor not
  finished, stale scheduler source and holiday are there; every owned exception has no gap of the exception
  contract (count, currency, deadline, owner, stage, evidence).
- Messages 600-629 and parameters XRUN_ / MA_ are defined and registered; VERIFY V290-V309 exist.
- Packs: no core object names an object of FI-CA Cash Operations (src/cash); the expected-run objects are core.
- The worked example examples/expected_runs is never seeded and, with an abaplint binary (ABAPLINT_BIN), compiles
  against the product.
The same scenarios run on a system later (VERIFY V306).

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
Modification log:
2026-11-16 | Initial version (build P: expected runs and FI-CA mass-activity intervals).
"""
import csv
import glob
import json
import os
import re
import subprocess
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, 'tools'))
from abaptools import expected_runs as model  # noqa: E402

FRAMEWORK = os.path.join(REPO, 'ops-framework')
SRC = os.path.join(FRAMEWORK, 'src')
CASH = os.path.join(SRC, 'cash')
SPEC = os.path.join(FRAMEWORK, 'config', 'expected_runs', 'fixtures.json')
XRUN_TYPES = os.path.join(SRC, 'zif_ca_ops_xrun_types.intf.abap')
MA_TYPES = os.path.join(CASH, 'zif_ca_ops_ma_types.intf.abap')
CASH_TYPES = os.path.join(CASH, 'zif_ca_ops_cash_types.intf.abap')
EXAMPLE = os.path.join(FRAMEWORK, 'examples', 'expected_runs')
ID = re.compile(r'^(XRUN|MA)-[0-9]{2}$')


def _read(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def _constants(path, block):
    match = re.search(r'BEGIN OF ' + block + r',(.*?)END OF ' + block + r'\.', _read(path), re.S)
    return dict(re.findall(r"(\w+)\s+TYPE [^\n]*?VALUE '([^']*)'", match.group(1))) if match else {}


def _test_methods(class_name):
    name = class_name.lower()
    paths = glob.glob(os.path.join(SRC, '**', name + '.clas.testclasses.abap'), recursive=True)
    if not paths:
        return set()
    return {m.lower() for m in re.findall(r'METHODS\s+(\w+)\s+FOR TESTING', _read(paths[0]))}


class ExpectedRunsSpec(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.spec = json.loads(_read(SPEC))
        cls.fixtures = cls.spec['fixtures']

    def test_format(self):
        self.assertEqual(self.spec['spec_version'], 1)
        ids = [f['id'] for f in self.fixtures]
        self.assertEqual(len(ids), len(set(ids)))
        for fixture in self.fixtures:
            self.assertRegex(fixture['id'], ID)
            self.assertIn(fixture['kind'], ('xrun', 'ma'))
            for key in ('check', 'class', 'abap_unit', 'title', 'given', 'expect'):
                self.assertIn(key, fixture, fixture['id'])

    def test_model_gives_expected(self):
        for fixture in self.fixtures:
            findings, evaluation, partial = model.run(fixture, self.spec)
            expect = fixture['expect']
            got = [{k: v for k, v in f.items() if k != 'deadline' or fixture['kind'] == 'xrun'} for f in findings]
            want = [{k: v for k, v in f.items() if k != 'deadline' or fixture['kind'] == 'xrun'}
                    for f in expect['findings']]
            self.assertEqual(got, want, fixture['id'])
            self.assertEqual(evaluation, expect['evaluation'], fixture['id'])
            self.assertEqual(partial, expect['partial'], fixture['id'])

    def test_abap_unit_methods_exist(self):
        for fixture in self.fixtures:
            self.assertIn(fixture['abap_unit'].lower(), _test_methods(fixture['class']), fixture['id'])
            for other in fixture.get('also_abap_unit', []):
                cls, method = other.split('=>')
                self.assertIn(method.lower(), _test_methods(cls), fixture['id'])

    def test_codes_and_stages_are_constants(self):
        codes = set(_constants(XRUN_TYPES, 'gc_code').values()) | set(_constants(MA_TYPES, 'gc_code').values()) \
            | set(_constants(CASH_TYPES, 'gc_code').values())
        stages = set(_constants(XRUN_TYPES, 'gc_stage').values()) | set(_constants(MA_TYPES, 'gc_stage').values()) \
            | set(_constants(CASH_TYPES, 'gc_stage').values())
        for fixture in self.fixtures:
            for finding in fixture['expect']['findings']:
                self.assertIn(finding['check_code'], codes, fixture['id'])
                self.assertIn(finding['stage'], stages, fixture['id'])

    def test_required_scenarios(self):
        by_id = {f['id']: f for f in self.fixtures}
        never = [f for f in self.fixtures
                 if any(x['check_code'] == 'XRUN_NEVER_STARTED' and x['stage'] == 'SCHEDULER'
                        for x in f['expect']['findings'])]
        self.assertTrue(never, 'never started (scheduler planned, SAP has no job)')
        self.assertTrue(any(x['check_code'] == 'XRUN_PRED_NOT_FINISHED'
                            for f in self.fixtures for x in f['expect']['findings']), 'predecessor not finished')
        self.assertTrue(any(f['expect']['evaluation'] == 'STALE' for f in self.fixtures), 'stale source')
        self.assertTrue(any(f['expect']['evaluation'] == 'HOLIDAY' and not f['expect']['findings']
                            for f in self.fixtures), 'holiday')
        self.assertTrue(any(f['expect']['evaluation'] == 'NOT_EVAL' and f['expect']['partial']
                            for f in self.fixtures), 'not evaluated')
        self.assertIn('MA-01', by_id)

    def test_scorecard_one(self):
        card = [f for f in self.fixtures if 1 in f.get('scorecard', []) and f.get('injection')]
        self.assertEqual(len(card), 1)
        fixture = card[0]
        statuses = {j['role']: j['status'] for j in fixture['given']['TBTCO'] if j['role'] == 'parent'}
        self.assertEqual(statuses['parent'], 'F', 'the SAP job finished')
        self.assertTrue(any(j['role'] == 'interval' and j['status'] == 'A' for j in fixture['given']['TBTCO']))
        docs = [r for r in fixture['given']['DPAYH'] if not r['XVORL']]
        self.assertEqual((len(docs), sum(1 for r in docs if r['DOC1R'])), (3, 2), '2 of 3 payment documents')
        [finding] = fixture['expect']['findings']
        self.assertEqual((finding['check_code'], finding['severity'], finding['stage']),
                         ('MA_OUTPUT_SHORT', 'E', 'JOB_OK'))
        self.assertEqual((finding['item_count'], finding['amount'], finding['currency']), (1, '250.00', 'EUR'))
        self.assertEqual(finding['owner'], 'ZT_OWNER')
        self.assertTrue(finding['deadline'])
        names = [e['name'] for e in finding['evidence']]
        for name in ('AKTYP/LAUFD/LAUFI', 'LAUFD/LAUFI', 'JOBNAME/JOBCOUNT', 'INTERVAL'):
            self.assertIn(name, names)
        self.assertIn({'name': 'INTERVAL', 'value': '2'}, finding['evidence'])

    def test_contract_of_exceptions(self):
        for fixture in self.fixtures:
            for finding in fixture['expect']['findings']:
                if finding.get('action') != 'EXCEPTION':
                    continue
                self.assertTrue(finding['item_count'] > 0 or finding['unknown_count'] > 0, fixture['id'])
                if float(finding['amount']) != 0 or finding['item_count'] > finding['unknown_count']:
                    self.assertTrue(finding['currency'], fixture['id'])
                self.assertTrue(finding['deadline'], fixture['id'])
                self.assertTrue(finding['owner'], fixture['id'])
                self.assertTrue(finding['stage'], fixture['id'])
                self.assertTrue(finding['evidence'], fixture['id'])


class ExpectedRunsWiring(unittest.TestCase):

    def test_messages_in_range(self):
        texts = dict(re.findall(r'^\| (\d{3}) \| (.*) \|$', _read(os.path.join(FRAMEWORK, 'config',
                                                                              'zca_ops_messages.md')), re.M))
        for path in (XRUN_TYPES, MA_TYPES):
            for number in _constants(path, 'gc_msg').values():
                self.assertTrue(600 <= int(number) <= 629, number)
                self.assertIn(number, texts)
                self.assertLessEqual(len(texts[number]), 73, number)

    def test_parameters_defined_and_registered(self):
        with open(os.path.join(FRAMEWORK, 'config', 'param_definitions.csv'), encoding='utf-8') as handle:
            rows = {r['NAME']: r for r in csv.DictReader(handle)}
        for path, prefix in ((XRUN_TYPES, 'XRUN_'), (MA_TYPES, 'MA_')):
            names = _constants(path, 'gc_param')
            defaults = dict(re.findall(r'(\w+)\s+TYPE i VALUE (\d+)',
                                       re.search(r'BEGIN OF gc_param_default,(.*?)END OF gc_param_default\.',
                                                 _read(path), re.S).group(1)))
            for key, name in names.items():
                self.assertTrue(name.startswith(prefix), name)
                self.assertIn(name, rows)
                self.assertEqual(rows[name]['AREA'], 'CA_OPS')
                if key in defaults:
                    self.assertEqual(rows[name]['DEFAULT_VALUE'], defaults[key], name)
        types = _read(os.path.join(SRC, 'zif_ca_ops_types.intf.abap'))
        params = _read(os.path.join(SRC, 'zcl_ca_ops_params.clas.abap'))
        for prefix, alias in (('XRUN_', 'xrun'), ('MA_', 'mass_act')):
            self.assertIn(f"VALUE '{prefix}'", types)
            self.assertIn(f'gc_param_area_prefix-{alias}', params)

    def test_verify_ids(self):
        verify = _read(os.path.join(FRAMEWORK, 'docs', 'VERIFY.md'))
        self.assertIn('V290-V309 are reserved for it', verify)
        for number in range(290, 307):
            self.assertIn(f'| V{number} |', verify)

    def test_core_names_no_cash_object(self):
        cash_objects = {os.path.basename(p).split('.')[0].upper() for p in glob.glob(os.path.join(CASH, '*.abap'))}
        for path in glob.glob(os.path.join(SRC, 'zcl_ca_ops_xrun_*.abap')) + \
                glob.glob(os.path.join(SRC, 'zif_ca_ops_xrun_*.abap')) + \
                glob.glob(os.path.join(SRC, 'zcl_ca_ops_chk_xrun*.abap')) + \
                [os.path.join(SRC, 'zif_ca_ops_expected_run_src.intf.abap')]:
            code = '\n'.join(line for line in _read(path).upper().splitlines()
                             if not line.lstrip().startswith(('*', '"')))
            code = re.sub(r"'[^']*'|`[^`]*`", '', code)
            for name in cash_objects:
                self.assertNotRegex(code, r'\b' + name + r'\b', path)

    def test_example_never_seeded(self):
        self.assertTrue(os.path.exists(os.path.join(EXAMPLE, 'src', 'zcl_xx_xrun_src_export.clas.abap')))
        for path in glob.glob(os.path.join(FRAMEWORK, 'config', '**', '*.csv'), recursive=True):
            self.assertNotIn('ZCL_XX_XRUN', _read(path).upper(), path)
        types = _read(XRUN_TYPES)
        self.assertNotIn('ZCL_XX_', types.upper())
        self.assertIn('ZIF_CA_OPS_EXPECTED_RUN_SRC', _read(os.path.join(EXAMPLE, 'src',
                                                                       'zcl_xx_xrun_src_export.clas.abap')).upper())

    def test_example_compiles(self):
        binary = os.environ.get('ABAPLINT_BIN', '')
        if not binary or not os.path.exists(binary):
            self.skipTest('no abaplint binary (set ABAPLINT_BIN)')
        out = subprocess.run([binary, 'abaplint.json'], cwd=EXAMPLE, capture_output=True, text=True, check=False)
        self.assertEqual(out.returncode, 0, out.stdout[-2000:])


if __name__ == '__main__':
    unittest.main()
