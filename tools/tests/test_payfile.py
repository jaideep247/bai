#!/usr/bin/env python3
"""Tests of the payment file lifecycle reference model (tools/abaptools/payfile.py) and of the framework's proof of its
two integration setups (ops-framework/tools/payfile.py).

- the fixtures give their expected business results in the test profile with a middleware and in the example XX
  (direct folder transfer, own scheduler) - and the same results in both;
- a profile that maps a status to another milestone changes the result (the proof is not vacuous);
- a stale source, a valid zero-volume day, a holiday and a failed read are four different day results;
- the example XX names no product class and every adapter row names a class of its role's interface;
- with an abaplint binary (environment ABAPLINT_BIN) the example compiles against the product.

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
Modification log:
2026-11-15 | Initial version (build K: payment file lifecycle).
"""
import copy
import json
import os
import shutil
import sys
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, 'tools'))
sys.path.insert(0, os.path.join(REPO, 'ops-framework', 'tools'))
from abaptools import payfile  # noqa: E402
import payfile as framework_payfile  # noqa: E402

FW = os.path.join(REPO, 'ops-framework')
FIXTURES = os.path.join(FW, 'config', 'payfile', 'fixtures.json')
MIDDLEWARE = os.path.join(FW, 'config', 'payfile', 'profiles', 'middleware.json')
XX = os.path.join(FW, 'examples', 'payfile_xx', 'config', 'profile.json')


class PayfileModelTest(unittest.TestCase):

    def setUp(self):
        with open(FIXTURES, encoding='utf-8') as f:
            self.fx = json.load(f)

    def test_fixtures_hold_in_both_setups(self):
        self.assertEqual(payfile.check_fixtures(FIXTURES, [MIDDLEWARE, XX]), [])

    def test_flagship_result(self):
        sc = next(s for s in self.fx['scenarios'] if s['id'] == 'ACK_MISSING')
        res = payfile.run_scenario(self.fx, sc, payfile.load_profile(XX))['F1']
        self.assertEqual(res['next_ms'], 'ACCEPTED')
        self.assertEqual(res['stage'], 'RECEIPT')
        self.assertEqual({f['currency'] for f in res['findings']}, {'USD', 'EUR'}, 'one finding per currency')

    def test_wrong_mapping_changes_result(self):
        prof = copy.deepcopy(payfile.load_profile(XX))
        for row in prof['statuses']:
            if row['status'] == 'RCVD':
                row['milestone'], row['outcome'] = 'ACCEPTED', 'OK'   # receipt mistaken for acceptance
        sc = next(s for s in self.fx['scenarios'] if s['id'] == 'ACK_MISSING')
        res = payfile.run_scenario(self.fx, sc, prof)['F1']
        self.assertNotEqual(res['next_ms'], 'ACCEPTED', 'collapsing receipt and acceptance hides the flagship')

    def test_day_results_differ(self):
        got = {d['id']: payfile.run_day(self.fx, d) for d in self.fx['days']}
        self.assertEqual(len({got['HOLIDAY'], got['ZERO_VOLUME'], got['STALE'], got['NOT_EVALUATED']}), 4)

    def test_amount_limit_never_across_currencies(self):
        self.assertEqual(payfile.amount_limit('USD 100', 'EUR', '1000'), 0)
        self.assertEqual(payfile.amount_limit('USD 100, 1000:USD 50', 'USD', '1000'), 50)


class ExampleWiringTest(unittest.TestCase):

    def test_wiring_and_neutrality(self):
        self.assertEqual(framework_payfile.check_wiring(), [])
        self.assertEqual(framework_payfile.check_neutral(), [])

    def test_product_class_in_example_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, 'fw')
            shutil.copytree(FW, root, ignore=shutil.ignore_patterns('node_modules', '.git', 'deps'))
            path = os.path.join(root, 'examples', 'payfile_xx', 'src', 'zcl_xx_pf_ack_table.clas.abap')
            with open(path, encoding='utf-8') as f:
                text = f.read()
            with open(path, 'w', encoding='utf-8') as f:
                f.write(text.replace('rs_batch-as_of = is_request-to_ts.',
                                     'rs_batch-as_of = zcl_ca_ops_pf_lifecycle=>add_minutes( iv_ts = is_request-to_ts '
                                     'iv_minutes = 0 ).'))
            found = framework_payfile.check_wiring(root)
            self.assertTrue(any('ZCL_CA_OPS_PF_LIFECYCLE' in f for f in found), found)

    def test_example_compiles(self):
        binary = os.environ.get('ABAPLINT_BIN', '')
        if not binary or not os.path.exists(binary):
            self.skipTest('no abaplint binary (set ABAPLINT_BIN)')
        self.assertEqual(framework_payfile.check_abaplint(binary), [])


if __name__ == '__main__':
    unittest.main()
