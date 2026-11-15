"""Tests of the offline validation of the account flow configuration (tools/abaptools/flow_config.py).

Modification log:
2026-11-15 | Initial version (build G: account flow reconciliation).
"""
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from abaptools import flow_config  # noqa: E402

FLOW = {'AREA': 'ZT', 'FLOW_ID': 'DISB', 'DIRECTION': 'D', 'ACTIVE': ''}


def stage(stage_id, seq, expect_from='', expect_to=''):
    return {'AREA': 'ZT', 'FLOW_ID': 'DISB', 'STAGE_ID': stage_id, 'SEQ': seq, 'EXPECT_FROM': expect_from,
            'EXPECT_TO': expect_to, 'ACTIVE': ''}


def rule(rule_id, seq, stage_id, source='G', active='', **criteria):
    row = {'AREA': 'ZT', 'FLOW_ID': 'DISB', 'RULE_SEQ': seq, 'RULE_ID': rule_id, 'STAGE_ID': stage_id,
           'LINE_SOURCE': source, 'ACTIVE': active}
    row.update({k: '' for k in flow_config.ALL_CRITERIA})
    row.update(criteria)
    return row


def account(acct, role, bukrs='ZT01', currency='USD'):
    return {'AREA': 'ZT', 'FLOW_ID': 'DISB', 'FLOW_ACCT': acct, 'ROLE': role, 'BUKRS': bukrs, 'CURRENCY': currency,
            'LINE_SOURCE': 'G', 'EVAL_CATEGORY': '', 'ACTIVE': ''}


def layer(stages=(), rules=(), accounts=(), tiles=(), controls=()):
    return {'flows': [FLOW], 'accounts': list(accounts), 'stages': list(stages), 'tiles': list(tiles),
            'controls': list(controls), 'rules': list(rules)}


class FlowConfigTest(unittest.TestCase):

    def test_valid_product_template(self):
        rows = layer([stage('GL_TRANSFER', '60')], [rule('S4_GL_TRANSFER', '0050', 'GL_TRANSFER', REF_TYPE='FKKSU')])
        self.assertEqual(flow_config.validate([('product', rows)], product={'product'}, inactive={'product'}), [])

    def test_reserved_stage_and_unknown_rule_stage(self):
        rows = layer([stage('OPENING', '10')], [rule('S4_X', '0010', 'NOPE', DOC_TYPE='ZB')])
        problems = flow_config.validate([('product', rows)])
        self.assertTrue(any('reserved row' in p for p in problems))
        self.assertTrue(any("stage 'NOPE'" in p for p in problems))

    def test_other_is_a_valid_rule_target(self):
        rows = layer([stage('A', '10')], [rule('S4_X', '0010', 'OTHER', DOC_TYPE='ZB')])
        self.assertEqual(flow_config.validate([('product', rows)]), [])

    def test_criterion_of_the_other_source(self):
        rows = layer([stage('A', '10')], [rule('S4_X', '0010', 'A', ORIGIN='01'),
                                         rule('FICA_Y', '0020', 'A', source='F', REF_TYPE='FKKSU')])
        problems = flow_config.validate([('product', rows)])
        self.assertTrue(any('ORIGIN does not apply' in p for p in problems))
        self.assertTrue(any('REF_TYPE does not apply' in p for p in problems))

    def test_active_rule_without_criterion(self):
        rows = layer([stage('A', '10')], [rule('S4_X', '0010', 'A', active='X')])
        self.assertTrue(any('hide the row OTHER' in p for p in flow_config.validate([('overlay', rows)])))

    def test_duplicate_sequence_and_product_prefix(self):
        rows = layer([stage('A', '10')], [rule('XX_A', '10', 'A', DOC_TYPE='ZB'), rule('S4_B', '0010', 'A', DOC_TYPE='ZC')])
        problems = flow_config.validate([('product', rows)], product={'product'})
        self.assertTrue(any('deterministic' in p for p in problems))
        self.assertTrue(any('starts with S4_' in p for p in problems))

    def test_product_holds_no_account_and_rows_inactive(self):
        acc = account('CASH', 'CASH')
        acc['ACTIVE'] = 'X'
        problems = flow_config.validate([('product', layer(accounts=[acc]))], product={'product'},
                                        inactive={'product'})
        self.assertTrue(any('holds no account' in p for p in problems))
        self.assertTrue(any('delivered inactive' in p for p in problems))

    def test_one_account_per_role_and_roles_held(self):
        rows = layer([stage('RETURNS_LOT', '50', 'CLARIFICATION', 'CASH')],
                     accounts=[account('CASH', 'CASH'), account('CASH2', 'CASH'), account('X1', 'OUTSIDE'),
                               account('X2', 'OUTSIDE'), account('CLR1', 'CLEARING'), account('CLR2', 'CLEARING')])
        problems = flow_config.validate([('overlay', rows)])
        self.assertTrue(any('one account per role' in p for p in problems))
        self.assertTrue(any('no account holds role CLARIFICATION' in p for p in problems))
        self.assertFalse(any('X2' in p or 'CLR2' in p for p in problems))

    def test_tile_and_control(self):
        tiles = [{'AREA': 'ZT', 'FLOW_ID': 'DISB', 'TILE': 'PAID', 'STAGE_ID': 'NOPE', 'ROLE': 'CASH', 'SIDE': 'X'}]
        controls = [{'AREA': 'ZT', 'FLOW_ID': 'DISB', 'STAGE_ID': 'A', 'CHECK_AREA': 'ZT', 'CHECK_ID': 'UNKNOWN'}]
        problems = flow_config.validate([('product', layer([stage('A', '10')], tiles=tiles, controls=controls))],
                                        product={'product'}, checks={('ZT', 'KNOWN')})
        self.assertTrue(any('side' in p for p in problems))
        self.assertTrue(any('stage is not defined' in p for p in problems))
        self.assertTrue(any('not a check of the product' in p for p in problems))

    def test_product_seed_files_valid(self):
        folder = os.path.join(ROOT, 'ops-framework', 'config', 'flows')
        self.assertEqual(flow_config.check_folders([('product', folder)], product={'product'},
                                                   inactive={'product'}), [])


if __name__ == '__main__':
    unittest.main()
