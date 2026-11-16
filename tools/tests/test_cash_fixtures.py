#!/usr/bin/env python3
"""Tests of the offline fixture spec of the FI-CA cash operations checks (ops-framework/config/cash/fixtures.json,
docs/FICA_CASH_OPERATIONS.md section 7): the spec format (version, day, defaults, unique scenario IDs, required keys,
dates, amounts, currencies, severities, stages and evaluations of ZIF_CA_OPS_CASH_TYPES), every expected check code
a constant of the types interface, every scenario's ABAP Unit test a FOR TESTING method of its check class, every
check registered with its class in the FICA catalogue package, every age equal to the spec day minus the oldest
item, every one of the six checks covered, the failure injection "job finished, business output incomplete" present
with stage JOB_OK, and a "not evaluated" scenario always partial. The same scenarios run on a real system later
(VERIFY V235); this test proves the spec and the ABAP Unit fixtures name the same things.

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
"""
import datetime
import json
import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FRAMEWORK = os.path.join(REPO, 'ops-framework')
SPEC = os.path.join(FRAMEWORK, 'config', 'cash', 'fixtures.json')
CASH_SRC = os.path.join(FRAMEWORK, 'src', 'cash')
TYPES = os.path.join(CASH_SRC, 'zif_ca_ops_cash_types.intf.abap')
CATALOGUE = os.path.join(FRAMEWORK, 'config', 'catalogue', 'packages', 'fica.json')

ID = re.compile(r'^(PAYRUN|PAYLOT|RETURN|EBS|CLEAR|GLKEY)-[0-9]{2}$')
AMOUNT = re.compile(r'^-?[0-9]+\.[0-9]{2}$')
CURRENCY = re.compile(r'^([A-Z]{3,5})?$')
SEVERITIES = {'B', 'E', 'W', 'I'}
FIXTURE_KEYS = {'id', 'check', 'class', 'abap_unit', 'scorecard', 'title', 'parameters', 'given', 'expect', 'partial'}
EXPECT_KEYS = {'check_code', 'severity', 'stage', 'evaluation', 'object_key', 'company_code', 'currency', 'amount',
               'item_count', 'oldest', 'age_days', 'owner', 'evidence', 'rule_param'}
CHECK_CLASSES = {'ZCL_CA_OPS_CHK_CASH_PAYRUN', 'ZCL_CA_OPS_CHK_CASH_PAYLOT', 'ZCL_CA_OPS_CHK_CASH_RETURN',
                 'ZCL_CA_OPS_CHK_CASH_EBS', 'ZCL_CA_OPS_CHK_CASH_CLEAR', 'ZCL_CA_OPS_CHK_CASH_GLKEY'}


def _read(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def _constants(block):
    """VALUE literals of the constants of one BEGIN OF block of the types interface."""
    text = _read(TYPES)
    match = re.search(r'BEGIN OF ' + block + r',(.*?)END OF ' + block + r'\.', text, re.S)
    return set(re.findall(r"VALUE '([^']*)'", match.group(1))) if match else set()


def _date(text):
    return datetime.date.fromisoformat(text)


class CashFixtureSpecTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.spec = json.loads(_read(SPEC))
        cls.codes = _constants('gc_code')
        cls.stages = _constants('gc_stage')
        cls.evaluations = _constants('gc_evaluation')
        cls.params = _constants('gc_param')

    def test_header(self):
        self.assertEqual(self.spec.get('spec_version'), 1)
        _date(self.spec['today'])
        self.assertIn('calendar', self.spec['defaults'])
        self.assertTrue(self.spec['fixtures'])

    def test_fixture_format(self):
        ids = [f.get('id') for f in self.spec['fixtures']]
        self.assertEqual(len(ids), len(set(ids)), 'scenario IDs must be unique')
        for fixture in self.spec['fixtures']:
            with self.subTest(fixture=fixture.get('id')):
                self.assertTrue(ID.match(fixture['id']), fixture['id'])
                self.assertLessEqual(FIXTURE_KEYS, set(fixture), 'required keys missing')
                self.assertIn(fixture['class'], CHECK_CLASSES)
                self.assertIsInstance(fixture['partial'], bool)
                self.assertTrue(set(fixture['scorecard']) <= {1, 2, 3, 4, 5})
                for name in fixture['parameters']:
                    self.assertIn(name, self.params, f'{name} is not a CASH_ parameter of the types interface')

    def test_expectations_use_the_product_terms(self):
        today = _date(self.spec['today'])
        for fixture in self.spec['fixtures']:
            for exp in fixture['expect']:
                with self.subTest(fixture=fixture['id'], code=exp.get('check_code')):
                    self.assertLessEqual(set(exp), EXPECT_KEYS, 'unknown expectation key')
                    self.assertIn(exp['check_code'], self.codes)
                    self.assertIn(exp['severity'], SEVERITIES)
                    self.assertIn(exp['stage'], self.stages)
                    if 'evaluation' in exp:
                        self.assertIn(exp['evaluation'], self.evaluations)
                    if 'amount' in exp:
                        self.assertTrue(AMOUNT.match(exp['amount']), exp['amount'])
                    if 'currency' in exp:
                        self.assertTrue(CURRENCY.match(exp['currency']), exp['currency'])
                    if 'oldest' in exp and 'age_days' in exp:
                        self.assertEqual((today - _date(exp['oldest'])).days, exp['age_days'])
                    if 'rule_param' in exp:
                        self.assertIn(exp['rule_param'], self.params)
                    if exp['check_code'] == 'CASH_NOT_EVALUATED':
                        self.assertTrue(fixture['partial'], 'a not evaluated rule makes the check partial')
                        self.assertEqual(exp['severity'], 'W')

    def test_abap_unit_test_exists(self):
        for fixture in self.spec['fixtures']:
            with self.subTest(fixture=fixture['id']):
                path = os.path.join(CASH_SRC, fixture['class'].lower() + '.clas.testclasses.abap')
                self.assertTrue(os.path.exists(path), path)
                text = _read(path)
                self.assertRegex(text, r'METHODS\s+' + re.escape(fixture['abap_unit']) + r'\s+FOR TESTING',
                                 f'{fixture["abap_unit"]} is not a test of {fixture["class"]}')
                # the comment right above the test's implementation names the scenario
                self.assertRegex(text, r'" Fixture ' + re.escape(fixture['id']) + r'\b[^\n]*\n(\s*"[^\n]*\n)*\s*METHOD '
                                 + re.escape(fixture['abap_unit']) + r'\.', 'the ABAP Unit test names its scenario')

    def test_checks_registered_in_the_catalogue(self):
        catalogue = json.loads(_read(CATALOGUE))
        classes = {m['check']: m.get('class') for p in catalogue['processes'] for m in p.get('monitors', [])}
        for fixture in self.spec['fixtures']:
            with self.subTest(fixture=fixture['id']):
                self.assertEqual(classes.get(fixture['check']), fixture['class'])

    def test_coverage_and_failure_injection(self):
        covered = {f['class'] for f in self.spec['fixtures']}
        self.assertEqual(covered, CHECK_CLASSES, 'every cash check has a scenario')
        injected = [f for f in self.spec['fixtures'] if f.get('injection') == 'job_ok_output_incomplete']
        self.assertTrue(injected, 'the failure injection "job finished, output incomplete" is a scenario')
        for fixture in injected:
            self.assertTrue(any(e['stage'] == 'JOB_OK' for e in fixture['expect']))
            self.assertTrue(any(r.get('STATUS') == 'F' for r in fixture['given'].get('TBTCO', [])),
                            'the injected job finished successfully')


if __name__ == '__main__':
    unittest.main()
