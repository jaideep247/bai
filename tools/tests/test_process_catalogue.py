#!/usr/bin/env python3
"""Tests of the process catalogue engine (tools/abaptools/process_catalogue.py): the product packages of the
framework, the worked example of a customer layer (prefix XX) and the suite's customer layer are valid and their
generated outputs current; the activation rule (delivered default, the latest row on or before the day, package
switched off, unknown process) - the same rule as ZCL_CA_OPS_CATALOG; every validation rule refuses what it must (a
wrong prefix, a dependency on an unknown process or one of a higher package, a dependency cycle, an activation row
of a product package, of an unknown process, without reason or naming a person, a link object on another table, a
product process with a VERIFY item active by default, an aggregate on a table the process does not list, a
CAT_PROCESS of the register that is not in the catalogue, an onboarded business process whose CAT_PROCESS differs);
monitoring rows of the product are all inactive and name their catalogue process; the scaffold accepts aggregate
rows of the outage check class and refuses them for another class.

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
"""
import copy
import importlib.util
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from abaptools import link_registry as lr  # noqa: E402
from abaptools import new_process  # noqa: E402
from abaptools import process_catalogue as pc  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FRAMEWORK = os.path.join(REPO, 'ops-framework')
SUITE = os.path.join(REPO, 'ops-suite')
EXAMPLE = os.path.join(FRAMEWORK, 'config', 'catalogue', 'examples', 'xx_layer.json')
DAY = '20261111'


def wrapper(component):
    """The component's wrapper module (tools/process_catalogue.py) with its profile."""
    path = os.path.join(REPO, component, 'tools', 'process_catalogue.py')
    spec = importlib.util.spec_from_file_location(f'process_catalogue_{component.replace("-", "_")}', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def specs():
    out = []
    for path in pc.PRODUCT_PACKAGES + [EXAMPLE]:
        with open(path, encoding='utf-8') as handle:
            out.append(json.load(handle))
    return out


def catalogue(changed=None):
    cat = pc.Catalogue()
    for spec in (changed or specs()):
        cat.add(spec)
    return cat


def registry():
    return lr.load(lr.PRODUCT_LAYERS)


class ComponentTest(unittest.TestCase):

    def test_framework_packages_valid_and_outputs_current(self):
        module = wrapper('ops-framework')
        self.assertEqual(module._engine.check(FRAMEWORK, module.PROFILE), [])

    def test_suite_layer_valid_and_outputs_current(self):
        module = wrapper('ops-suite')
        self.assertEqual(module._engine.check(SUITE, module.PROFILE), [])

    def test_example_valid(self):
        self.assertEqual(pc.validate(catalogue(), registry()), [])

    def test_product_monitoring_rows_inactive(self):
        cat = catalogue()
        rows = pc.monitoring_rows(cat, ['S4CORE', 'FICA', 'FSCD'])
        for table, lines in rows.items():
            for row in lines:
                self.assertNotEqual(row.get('ACTIVE'), 'X', f'{table}: {row}')
        procs = {r['PROCESS_ID']: r for r in rows['zca_ops_proc']}
        self.assertEqual(procs['FICA_PAYRUN']['CAT_PROCESS'], 'FICA_PAYRUN')
        self.assertEqual(procs['FICA_PAYRUN']['AREA'], 'CA_FICA')
        checks = {r['CHECK_ID']: r for r in rows['zca_ops_check']}
        self.assertEqual(checks['FICA_GL_OUTAGE']['CLASS_NAME'], 'ZCL_CA_OPS_CHK_OUTAGE')
        self.assertEqual(checks['FICA_WO_LIMIT']['CLASS_NAME'], 'ZCL_CA_OPS_CHK_AGG')
        aggs = {(r['CHECK_ID'], r['AGG_ID']): r for r in rows['zca_ops_agg']}
        self.assertEqual(aggs[('FICA_WO_REASON', 'R1')]['COND_OP'], 'NI')
        self.assertEqual(aggs[('FICA_WO_LIMIT', 'R1')]['MAX_AGE_DAYS'], '1')
        self.assertEqual(aggs[('FICA_GL_OUTAGE', 'OUT_POST')]['TIME_FIELD'], 'CPUTM')
        ctl = {(r['CONTROL_ID'], r['MATCH_VALUE']) for r in rows['zca_ops_ctlchk']}
        self.assertIn(('FICA_WRITEOFF', 'FICA_WO_LIMIT'), ctl)

    def test_suite_proposal(self):
        module = wrapper('ops-suite')
        cat, problems, _ = module._engine.outputs(SUITE, module.PROFILE)
        self.assertEqual(problems, [])
        active = sorted(p for p in cat.processes if cat.state(p, DAY)[0])
        self.assertEqual(active, ['CD_COLL_REQ_LIFE', 'FICA_GL_TRANSFER', 'FICA_PAYRUN', 'FICA_RETURNS',
                                  'S4_BANK_STMT', 'S4_BATCH_JOBS'])


class StateTest(unittest.TestCase):

    def test_default_row_and_package(self):
        cat = catalogue()
        self.assertEqual(cat.state('FICA_PAYRUN', '20261231')[:2], (False, 'D'))
        self.assertEqual(cat.state('FICA_PAYRUN', '20270101')[:2], (True, 'A'))
        self.assertEqual(cat.state('FICA_DUNNING', '20270101')[:2], (False, 'A'))
        self.assertEqual(cat.state('FICA_INVOICING', '20270630')[:2], (False, 'D'))
        self.assertEqual(cat.state('FICA_INVOICING', '20270701')[:2], (True, 'A'))
        self.assertEqual(cat.state('S4_BATCH_JOBS', DAY)[:2], (True, 'D'))
        self.assertEqual(cat.state('XX_REQ_LIFE', DAY)[:2], (True, 'D'))
        self.assertEqual(cat.state('NO_SUCH', DAY)[:2], (False, 'U'))

    def test_package_off_wins(self):
        changed = specs()
        changed[1]['package']['active'] = False
        cat = catalogue(changed)
        self.assertEqual(cat.state('FICA_PAYRUN', '20270101')[:2], (False, 'P'))


class ValidationTest(unittest.TestCase):

    def problems(self, change):
        changed = copy.deepcopy(specs())
        change(changed)
        return pc.validate(catalogue(changed), registry())

    def test_wrong_prefix(self):
        def change(s):
            s[1]['processes'][0]['id'] = 'XX_PAYRUN_WRONG'
        self.assertTrue(any('must start with the prefix FICA_' in p for p in self.problems(change)))

    def test_dependency_unknown_or_higher(self):
        def change(s):
            s[1]['processes'][0]['depends_on'] = [{'id': 'NO_SUCH', 'kind': 'H'},
                                                  {'id': 'FSCD_PAYPLAN', 'kind': 'S'}]
        found = self.problems(change)
        self.assertTrue(any('NO_SUCH, which is not in the catalogue' in p for p in found))
        self.assertTrue(any('of the higher package FSCD' in p for p in found))

    def test_dependency_cycle(self):
        def change(s):
            gl = next(p for p in s[1]['processes'] if p['id'] == 'FICA_GL_TRANSFER')
            gl['depends_on'] = [{'id': 'FICA_PAYRUN', 'kind': 'S'}]
        self.assertIn('process FICA_GL_TRANSFER: dependency cycle', self.problems(change))

    def test_activation_rules(self):
        def change(s):
            s[3]['activation'] += [{'process': 'NO_SUCH', 'valid_from': '20270101', 'active': True, 'reason': 'x'},
                                   {'process': 'FICA_RETURNS', 'valid_from': '2027-01-01', 'active': True,
                                    'reason': ''},
                                   {'process': 'FICA_CLEARING', 'valid_from': '20270101', 'active': True,
                                    'reason': 'ok', 'approved_by': 'SOMEBODY'}]
            s[1]['activation'] = [{'process': 'FICA_PAYRUN', 'valid_from': '20270101', 'active': True,
                                   'reason': 'product'}]
        found = '\n'.join(self.problems(change))
        self.assertIn('activation NO_SUCH 20270101: process is not in the catalogue', found)
        self.assertIn('valid_from must be a date YYYYMMDD', found)
        self.assertIn('reason required', found)
        self.assertIn('approved_by names a person', found)
        self.assertIn('activation rows belong to a customer layer', found)

    def test_link_object_on_another_table(self):
        def change(s):
            s[1]['processes'][0]['tables'][0]['link_object'] = 'FICA_OPEN_ITEM'
        self.assertTrue(any('link object FICA_OPEN_ITEM reads DFKKOP' in p for p in self.problems(change)))

    def test_product_default_needs_confirmed_names(self):
        def change(s):
            s[1]['processes'][0]['default_active'] = True
        self.assertIn('process FICA_PAYRUN: a product process with a VERIFY item is never active by default',
                      self.problems(change))

    def test_aggregate_table_of_the_process(self):
        def change(s):
            s[1]['processes'][0]['monitors'][0]['aggregates'][0]['table'] = 'DFKKZK'
        self.assertTrue(any('table DFKKZK is not a table of the process' in p for p in self.problems(change)))

    def test_register_references(self):
        cat = catalogue()
        register = [{'AREA': 'ZXX', 'PROCESS_ID': 'P1', 'CAT_PROCESS': 'NO_SUCH'}]
        self.assertTrue(any('CAT_PROCESS NO_SUCH is not in the catalogue' in p
                            for p in pc.validate(cat, registry(), register)))
        cat.processes['FICA_PAYRUN']['onboarded'] = [{'area': 'ZXX', 'process': 'P1'}]
        self.assertTrue(any("names catalogue process 'NO_SUCH'" in p for p in pc.validate(cat, registry(), register)))


class ScaffoldTest(unittest.TestCase):

    def check_spec(self, cls):
        return {'area': 'ZXX', 'process': 'P1', 'name': 'n', 'auth_role': 'Z_R', 'active': False,
                'checks': [{'id': 'C1', 'class': cls,
                            'aggregates': [{'id': 'R1', 'table': 'T', 'date_field': 'D', 'time_field': 'TM',
                                            'cond_field': 'F', 'cond_op': 'NI', 'cond_value': 'A,B'}]}]}

    def test_outage_class_reads_aggregates(self):
        rows = new_process.rows_of(self.check_spec('ZCL_CA_OPS_CHK_OUTAGE'))
        self.assertEqual(rows['check_registry.csv'][0]['CLASS_NAME'], 'ZCL_CA_OPS_CHK_OUTAGE')
        self.assertEqual(rows['check_aggregates.csv'][0]['TIME_FIELD'], 'TM')

    def test_other_class_with_aggregates_refused(self):
        with self.assertRaises(new_process.SpecError):
            new_process.rows_of(self.check_spec('ZCL_XX_C_OTHER'))


if __name__ == '__main__':
    unittest.main()
