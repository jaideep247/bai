#!/usr/bin/env python3
"""Tests of the suite's overlay of the framework's payment file lifecycle (docs/Payment_File_Overlay.md).

- the framework's fixtures give the expected business results through the suite's setup (SAP jobs, file monitoring's
  audit trail of PRISM and the bank ACK) - identical to the framework's example XX (no middleware);
- every overlay row is delivered inactive and names product milestones and outcomes only;
- every adapter row names a class of the suite or the framework that implements the interface of its role;
- the overlay classes reach the framework only through ZIF_CA_OPS_PF_* interfaces, the contract helper, the utilities
  and the exception class - never the framework's engine or register.

Run:  python3 -m unittest discover -s tools/tests      (from ops-suite/)
Modification log:
2026-11-15 | Initial version (build K: payment file lifecycle overlay).
"""
import csv
import glob
import os
import re
import sys
import unittest

SUITE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPO = os.path.dirname(SUITE)
sys.path.insert(0, os.path.join(REPO, 'tools'))
from abaptools import payfile  # noqa: E402

FW = os.path.join(REPO, 'ops-framework')
CFG = os.path.join(SUITE, 'config', 'payfile')
ROLE_INTF = {'FILE': 'ZIF_CA_OPS_PF_FILE_SRC', 'TRANSFER': 'ZIF_CA_OPS_PF_TRANSFER_SRC', 'ACK': 'ZIF_CA_OPS_PF_ACK_SRC',
             'SCHED': 'ZIF_CA_OPS_PF_SCHED_SRC', 'STMT': 'ZIF_CA_OPS_PF_STMT_SRC',
             'TICKET': 'ZIF_CA_OPS_PF_TICKET_SINK', 'CALENDAR': 'ZIF_CA_OPS_PF_CALENDAR'}
FRAMEWORK_ALLOWED = re.compile(r'^(ZIF_CA_OPS_PF_\w+|ZIF_CA_OPS_TYPES|ZCX_CA_OPS_ERROR|ZCL_CA_OPS_UTIL|ZCA_OPS|'
                               r'ZCL_CA_OPS_EXC_CONTRACT)$')


def rows(name):
    with open(os.path.join(CFG, name), newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))


def class_code(name):
    for folder in (os.path.join(SUITE, 'src'), os.path.join(FW, 'src')):
        hits = glob.glob(os.path.join(folder, '**', name.lower() + '.clas.abap'), recursive=True)
        if hits:
            with open(hits[0], encoding='utf-8') as f:
                return f.read()
    return None


class PayfileOverlayTest(unittest.TestCase):

    def test_fixtures_identical_with_example_xx(self):
        found = payfile.check_fixtures(os.path.join(FW, 'config', 'payfile', 'fixtures.json'),
                                       [os.path.join(CFG, 'profile.json'),
                                        os.path.join(FW, 'examples', 'payfile_xx', 'config', 'profile.json')])
        self.assertEqual(found, [])

    def test_rows_inactive_and_product_vocabulary(self):
        for name in ('zca_ops_pftyp.csv', 'zca_ops_pfstg.csv', 'zca_ops_pfmap.csv', 'zca_ops_pfadp.csv'):
            for row in rows(name):
                self.assertFalse(row['ACTIVE'], f'{name}: delivered inactive')
        for row in rows('zca_ops_pfmap.csv'):
            self.assertTrue(row['MILESTONE'] in payfile.ORDER or not row['MILESTONE'], row)
            self.assertIn(row['OUTCOME'], ('OK', 'REJECTED', 'PARTIAL', 'FAILED', 'INFO'))
        for row in rows('zca_ops_pfstg.csv'):
            self.assertIn(row['MILESTONE'], payfile.ORDER)

    def test_receipt_and_acceptance_kept_apart(self):
        mapped = {(r['STATUS'], r['MILESTONE']) for r in rows('zca_ops_pfmap.csv')}
        self.assertIn(('PRISM_DELIVERED', 'RECEIPT'), mapped)
        self.assertIn(('ACK_RECEIVED', 'ACCEPTED'), mapped)

    def test_adapter_classes_implement_their_role(self):
        for row in rows('zca_ops_pfadp.csv'):
            code = class_code(row['CLASS_NAME'])
            self.assertIsNotNone(code, row['CLASS_NAME'])
            self.assertRegex(code, r'(?im)^\s*INTERFACES\s+' + ROLE_INTF[row['ROLE']] + r'\s*\.', row['CLASS_NAME'])

    def test_overlay_reaches_framework_through_interfaces(self):
        for name in ('zcl_cd_pf_fmon_files', 'zcl_cd_pf_fmon_events'):
            code = class_code(name)
            code = '\n'.join(re.sub(r'".*$', '', l) for l in code.splitlines() if not l.lstrip().startswith('*'))
            for token in {t.upper() for t in re.findall(r'\bZ\w*CA_OPS\w*', code, re.I)}:
                self.assertRegex(token, FRAMEWORK_ALLOWED, f'{name} names {token}')


if __name__ == '__main__':
    unittest.main()
