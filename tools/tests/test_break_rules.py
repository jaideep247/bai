"""Tests of the offline validation of the break analysis bucket rules (tools/abaptools/break_rules.py).

Modification log:
2026-11-11 | Initial version (build F: clearing-account break analysis).
"""
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from abaptools import break_rules  # noqa: E402

BUCKETS = [{'BUCKET': 'TIMING', 'ACTIVE': 'X'}, {'BUCKET': 'OTHER', 'ACTIVE': 'X'}]


def rule(rule_id, layer='S4CORE', area='*', seq='10', bucket='TIMING'):
    return {'AREA': area, 'RULE_ID': rule_id, 'LAYER_ID': layer, 'SEQ': seq, 'BUCKET': bucket, 'ACTIVE': 'X',
            'REASON': 'r'}


def cond(rule_id, kind='GROUP', field='LINES', op='GE', value='3', link='', area='*'):
    return {'AREA': area, 'RULE_ID': rule_id, 'COND_NO': '001', 'COND_KIND': kind, 'FIELD': field, 'OPERATOR': op,
            'COND_VALUE': value, 'LINK_ID': link, 'MIN_COUNT': ''}


class BreakRulesTest(unittest.TestCase):

    def run_layers(self, rules, conds, product=True, params=None, links=None):
        layer = ('product', {'buckets': BUCKETS, 'rules': rules, 'conds': conds})
        return break_rules.validate([layer], params=params, links=links, product={'product'} if product else None)

    def test_valid_rule(self):
        self.assertEqual(self.run_layers([rule('S4_A')], [cond('S4_A')]), [])

    def test_prefix_and_area_of_a_product_rule(self):
        problems = self.run_layers([rule('XX_A', area='ZXX_OPS')], [cond('XX_A', area='ZXX_OPS')])
        self.assertTrue(any('prefix S4_' in p for p in problems))
        self.assertTrue(any('every area' in p for p in problems))

    def test_unknown_bucket_and_shared_sequence(self):
        problems = self.run_layers([rule('S4_A', bucket='NOPE'), rule('S4_B')], [])
        self.assertTrue(any('bucket NOPE' in p for p in problems))
        self.assertTrue(any('share sequence' in p for p in problems))

    def test_operator_field_link_and_parameter(self):
        problems = self.run_layers(
            [rule('S4_A')],
            [cond('S4_A', kind='FIELD', field='DOC_TYPE', op='EX', value=''),
             cond('S4_A', kind='GROUP', field='NOPE', op='EQ', value='1'),
             cond('S4_A', kind='LINK', field='VGEXT', op='EX', value='@BRK_NONE', link='S4_NONE'),
             cond('S4_A', kind='DAYS', field='KEY_DATE', op='LE', value='')],
            params={'BRK_TIMING_DAYS'}, links={'S4_LINK'})
        self.assertTrue(any("operator 'EX' is not allowed for kind FIELD" in p for p in problems))
        self.assertTrue(any("'NOPE' is not a field of kind GROUP" in p for p in problems))
        self.assertTrue(any('link S4_NONE is not a link' in p for p in problems))
        self.assertTrue(any('parameter BRK_NONE is not defined' in p for p in problems))
        self.assertTrue(any('needs a value' in p for p in problems))

    def test_product_seed_files_are_valid(self):
        framework = os.path.join(ROOT, 'ops-framework')
        problems = break_rules.check_folders(
            [('product', os.path.join(framework, 'config', 'breaks'))],
            params=break_rules.param_names(os.path.join(framework, 'config', 'param_definitions.csv')),
            links=break_rules.link_ids(os.path.join(framework, 'config', 'links', 'seed', 'zca_ops_link.csv')),
            product={'product'})
        self.assertEqual(problems, [])


if __name__ == '__main__':
    unittest.main()
