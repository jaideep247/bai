#!/usr/bin/env python3
"""Fixture tests of the framework's own checks (tools/checks.py): layering, customer wording,
messages and test paths, and the checks on the real tree.

Run:  python3 -m unittest discover -s tools/tests      (from ops-framework/)
"""
import json
import os
import sys
import tempfile
import unittest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import checks  # noqa: E402

HEADER = ('*&---------------------------------------------------------------------*\n'
          '*& Artifact: {name}\n*& Purpose:\n*& A fixture.\n*& Modification log:\n{log}'
          '*&---------------------------------------------------------------------*\n')


class FixtureTest(unittest.TestCase):

    def _root(self, root, files, messages='| 001 | Text |\n'):
        os.makedirs(os.path.join(root, 'src'))
        os.makedirs(os.path.join(root, 'config'))
        os.makedirs(os.path.join(root, 'tools'))
        with open(os.path.join(root, 'config', 'repository.json'), 'w', encoding='utf-8') as fh:
            json.dump({'message_class': {'source': 'config/msg.md'}}, fh)
        with open(os.path.join(root, 'config', 'msg.md'), 'w', encoding='utf-8') as fh:
            fh.write('| No. | Text |\n|---|---|\n' + messages)
        with open(os.path.join(root, 'config', 'customer_terms.txt'), 'w', encoding='utf-8') as fh:
            fh.write('# terms\nACME BANK\nFOO\n')
        for name, text in files.items():
            with open(os.path.join(root, 'src', name), 'w', encoding='utf-8') as fh:
                fh.write(text)

    def test_consumer_reference_is_refused(self):
        with tempfile.TemporaryDirectory() as root:
            self._root(root, {'zcl_ca_x.clas.abap': HEADER.format(name='zcl_ca_x.clas.abap', log='')
                              + 'CLASS zcl_ca_x DEFINITION.\n  DATA mo TYPE REF TO zif_cd_ops_store.\n'})
            self.assertEqual(len(checks.check_layering(root)), 1)

    def test_moved_from_line_is_allowed(self):
        log = '*& 2026-11-10 | Moved from ZCL_CD_OPS_X to the reusable framework ZCA_OPS.\n'
        with tempfile.TemporaryDirectory() as root:
            self._root(root, {'zcl_ca_x.clas.abap': HEADER.format(name='zcl_ca_x.clas.abap', log=log)})
            self.assertEqual(checks.check_layering(root), [])

    def test_customer_term_is_refused_as_whole_word(self):
        with tempfile.TemporaryDirectory() as root:
            self._root(root, {'zcl_ca_x.clas.abap': '" a comment for acme bank\n" FOOD is fine\n'})
            fails = checks.check_customer_terms(root)
            self.assertEqual(len(fails), 1)
            self.assertIn('acme bank', fails[0])

    def test_unused_and_undefined_messages(self):
        code = "CLASS zcl_ca_x IMPLEMENTATION.\n  METHOD m.\n    RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e002(zca_ops).\n"
        with tempfile.TemporaryDirectory() as root:
            self._root(root, {'zcl_ca_x.clas.abap': code})
            fails = checks.check_messages(root)
            self.assertTrue(any('002' in f and 'not defined' in f for f in fails))
            self.assertTrue(any('001' in f and 'raised by no production code' in f for f in fails))

    def test_class_without_test_path(self):
        with tempfile.TemporaryDirectory() as root:
            self._root(root, {'zcl_ca_x.clas.abap': 'CLASS zcl_ca_x DEFINITION.\n'})
            self.assertEqual(len(checks.check_test_path(root)), 1)
            with open(os.path.join(root, 'tools', 'test_path_register.csv'), 'w', encoding='utf-8') as fh:
                fh.write('object,path,covered_by,reason\nZCL_CA_X,exempt,,a reason\n')
            self.assertEqual(checks.check_test_path(root), [])


class TreeTest(unittest.TestCase):
    """The framework itself passes every check."""

    def test_every_check_passes(self):
        root = os.path.dirname(TOOLS)
        failed = {name: f[:3] for name, f in checks.run(root).items() if f}
        self.assertEqual(failed, {})


if __name__ == '__main__':
    unittest.main()
