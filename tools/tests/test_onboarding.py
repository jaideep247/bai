#!/usr/bin/env python3
"""Fixture tests of the process onboarding tools (tools/abaptools): the scaffold new_process.py writes every
row a process needs once (a second run adds nothing), a skeleton class with its test include, the process
document; the offline completeness check onboarding.py passes a scaffolded process and fails each missing
piece (check, control, alert rule, ownership, purge, authorisation, placeholder in an active row, aggregate
on a table not approved).

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
"""
import csv
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from abaptools import new_process  # noqa: E402
from abaptools import onboarding  # noqa: E402

AUTH = 'docs/auth.md'


def spec(**changes):
    base = {
        'area': 'ZPE_OPS', 'process': 'PAY_LIFE', 'name': 'Payment lifecycle', 'owner_team': 'Payment operations',
        'auth_role': 'Z_PE_OPS_OPERATOR', 'schedule_group': 'DAILY', 'new_area': {'description': 'Payments'},
        'alert_rule': {'id': 'PAY_LIFE', 'destination': 'ZPE_PAYOPS'},
        'checks': [
            {'id': 'PAY_PENDING', 'description': 'Pending requests past their date', 'bukrs_aware': True,
             'aggregates': [{'id': 'R1', 'table': 'ZPE_REQUEST', 'func': 'AGE', 'date_field': 'REQ_DATE',
                             'min_age_days': 1, 'bukrs_field': 'BUKRS', 'status_field': 'STATUS',
                             'status_value': 'PENDING', 'amber': 1, 'red': 3}]},
            {'id': 'PAY_REFUND', 'description': 'Rejected without refund', 'class': 'ZCL_PE_C_REFUND',
             'skeleton': True}],
    }
    base.update(changes)
    return base


class OnboardingTest(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        os.makedirs(os.path.join(self.root, 'docs'))
        with open(os.path.join(self.root, AUTH), 'w', encoding='utf-8') as fh:
            fh.write('| `Z_PE_OPS_OPERATOR` | ZPE_OPS | 02, 03 | own company codes |\n')
        # the framework's no-code check, as a class of the component's sources
        os.makedirs(os.path.join(self.root, 'src'))
        open(os.path.join(self.root, 'src', 'zcl_ca_ops_chk_agg.clas.abap'), 'w').close()

    def tearDown(self):
        self.tmp.cleanup()

    def failures(self):
        return onboarding.failures(self.root, auth_docs=(AUTH,), source_roots=('src',))

    def rewrite(self, name, change):
        path = os.path.join(self.root, 'config', name)
        with open(path, encoding='utf-8', newline='') as fh:
            reader = csv.DictReader(fh)
            header, rows = reader.fieldnames, list(reader)
        rows = [r for r in (change(r) for r in rows) if r is not None]
        with open(path, 'w', encoding='utf-8', newline='') as fh:
            writer = csv.DictWriter(fh, fieldnames=header, lineterminator='\n')
            writer.writeheader()
            writer.writerows(rows)

    def test_scaffolded_process_is_complete(self):
        new_process.scaffold(self.root, spec())
        self.assertEqual(self.failures(), [])

    def test_second_run_adds_nothing(self):
        new_process.scaffold(self.root, spec())
        self.assertEqual(new_process.scaffold(self.root, spec()), [])

    def test_every_table_row_written(self):
        changes = dict(new_process.scaffold(self.root, spec()))
        for name in ('process_register.csv', 'check_registry.csv', 'check_aggregates.csv', 'approved_tables.csv',
                     'control_register.csv', 'control_guidance.csv', 'control_checks.csv', 'alert_rules.csv',
                     'param_areas.csv'):
            self.assertIn(os.path.join('config', name), changes)
        self.assertEqual(changes[os.path.join('config', 'control_checks.csv')], 2)
        self.assertEqual(changes[os.path.join('docs', 'processes', 'ZPE_OPS_PAY_LIFE.md')], 'new')

    def test_skeleton_class_and_test(self):
        new_process.scaffold(self.root, spec())
        src = os.path.join(self.root, 'src', 'zcl_pe_c_refund.clas.abap')
        with open(src, encoding='utf-8') as fh:
            text = fh.read()
        self.assertTrue(text.startswith('*&---'))
        self.assertIn('*& Artifact: zcl_pe_c_refund.clas.abap', text)
        self.assertIn('INTERFACES zif_ca_ops_check.', text)
        self.assertTrue(os.path.isfile(os.path.join(self.root, 'src', 'zcl_pe_c_refund.clas.testclasses.abap')))

    def test_missing_control_fails(self):
        new_process.scaffold(self.root, spec())
        self.rewrite('control_checks.csv', lambda r: None if r['MATCH_VALUE'] == 'PAY_REFUND' else r)
        self.assertTrue(any('PAY_REFUND covered by no control' in f for f in self.failures()))

    def test_missing_alert_rule_fails(self):
        new_process.scaffold(self.root, spec())
        self.rewrite('alert_rules.csv', lambda r: None)
        self.assertTrue(any('no alert rule' in f for f in self.failures()))

    def test_missing_owner_fails(self):
        new_process.scaffold(self.root, spec(owner_team=''))
        self.assertTrue(any('no owner' in f for f in self.failures()))

    def test_role_not_in_sheet_fails(self):
        new_process.scaffold(self.root, spec(auth_role='Z_PE_UNKNOWN'))
        self.assertTrue(any('role Z_PE_UNKNOWN' in f for f in self.failures()))

    def test_own_data_needs_purge(self):
        new_process.scaffold(self.root, spec())
        self.rewrite('process_register.csv', lambda r: dict(r, OWN_DATA='X'))
        self.assertTrue(any('without a purge target' in f for f in self.failures()))

    def test_unapproved_table_fails(self):
        new_process.scaffold(self.root, spec())
        self.rewrite('approved_tables.csv', lambda r: None)
        self.assertTrue(any('not approved' in f for f in self.failures()))

    def test_placeholder_only_inactive(self):
        placeholder = spec()
        placeholder['checks'][0]['aggregates'][0]['table'] = '‹status table›'
        new_process.scaffold(self.root, placeholder)
        self.assertTrue(any('placeholder' in f for f in self.failures()))

    def test_inactive_placeholders_pass(self):
        placeholder = spec(active=False)
        placeholder['checks'][0]['aggregates'][0]['table'] = '‹status table›'
        placeholder['checks'][1]['skeleton'] = False
        new_process.scaffold(self.root, placeholder)
        self.assertEqual(self.failures(), [])

    def test_inactive_new_area_not_delivered(self):
        changes = dict(new_process.scaffold(self.root, spec(active=False)))
        self.assertNotIn(os.path.join('config', 'param_areas.csv'), changes)
        with open(os.path.join(self.root, 'docs', 'processes', 'ZPE_OPS_PAY_LIFE.md'), encoding='utf-8') as fh:
            self.assertIn('added on activation', fh.read())

    def test_active_process_needs_area(self):
        new_process.scaffold(self.root, spec())
        self.rewrite('param_areas.csv', lambda r: None)
        self.assertTrue(any('not a parameter area' in f for f in self.failures()))

    def test_no_check_fails(self):
        new_process.scaffold(self.root, spec())
        self.rewrite('check_registry.csv', lambda r: None)
        failures = self.failures()
        self.assertTrue(any('no active check' in f for f in failures))
        self.assertTrue(any('check not registered' in f for f in failures))

    def test_long_name_refused(self):
        with self.assertRaises(new_process.SpecError):
            new_process.scaffold(self.root, spec(process='A_PROCESS_NAME_LONGER_THAN_20'))

    def test_company_code_aware_needs_field(self):
        broken = spec()
        del broken['checks'][0]['aggregates'][0]['bukrs_field']
        with self.assertRaises(new_process.SpecError):
            new_process.scaffold(self.root, broken)

    def test_command_line_dry_run_writes_nothing(self):
        code = new_process.main(['--root', self.root, '--area', 'ZPE_OPS', '--process', 'PAY_LIFE',
                                 '--name', 'Payment lifecycle', '--role', 'Z_PE_OPS_OPERATOR',
                                 '--agg', 'PAY_COUNT:COUNT:ZPE_REQUEST:STATUS:EQ:PENDING', '--dry-run'])
        self.assertEqual(code, 0)
        self.assertFalse(os.path.isdir(os.path.join(self.root, 'config')))


if __name__ == '__main__':
    unittest.main()
