#!/usr/bin/env python3
"""Tests of the framework's RAP generator profile (tools/rap_generate.py): the app is complete
and generated, every pattern field of the alert rules is validated as PCRE on save.

Run:  python3 -m unittest discover -s tools/tests      (from ops-framework/)
"""
import os
import sys
import unittest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import rap_generate  # noqa: E402  (import writes nothing: generation runs in main( ) only)


class FrameworkAppTest(unittest.TestCase):

    def test_every_pattern_field_is_validated(self):
        expected = {('framework', 'zca_ops_alrule', 'rule_pattern'), ('framework', 'zca_ops_alrule', 'check_pattern'),
                    ('framework', 'zca_ops_alrule', 'group1_pattern'), ('framework', 'zca_ops_alrule', 'group2_pattern')}
        found = {(mod, t[0], c[1]) for mod, app in rap_generate.SPEC.items() for t in app['tables']
                 for c in t[6] if c[0] == 'pcre'}
        self.assertEqual(found, expected)

    def test_app_is_the_framework_one(self):
        self.assertEqual(list(rap_generate.SPEC), ['framework'])
        app = rap_generate.SPEC['framework']
        self.assertEqual(app['prefix'], 'ca')
        self.assertEqual(app['service'], 'ZUI_CA_OPS_CFG')
        self.assertNotIn('base', app)  # generated into this folder, never from another component

    def test_tables_are_framework_tables(self):
        tables = [t[0] for t in rap_generate.SPEC['framework']['tables']]
        self.assertEqual(tables, ['zca_ops_alrule', 'zca_ops_alchn', 'zca_ops_purge'])


if __name__ == '__main__':
    unittest.main()
