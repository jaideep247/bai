#!/usr/bin/env python3
"""Fixture tests for tools/name_checks.py (portable checks name_lengths and method_names):
each case writes a small fixture suite into a temporary folder.

Run:  python3 -m unittest discover -s tools/tests      (from ops-suite/)
"""
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import name_checks  # noqa: E402

GOOD_CLASS = """CLASS zcl_cd_fixture DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CONSTANTS gc_limit TYPE i VALUE 30.
    TYPES:
      BEGIN OF ty_row,
        field TYPE c LENGTH 1,
      END OF ty_row.
    METHODS is_valid RETURNING VALUE(rv_valid) TYPE abap_bool.
    METHODS read_rows IMPORTING iv_key TYPE string.
  PRIVATE SECTION.
    DATA mt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
ENDCLASS.
CLASS zcl_cd_fixture IMPLEMENTATION.
  METHOD read_rows.
    DATA(lv_text) = `a "quoted" literal with METHODS lv_not_a_method`.
  ENDMETHOD.
  METHOD is_valid.
  ENDMETHOD.
ENDCLASS.
"""
TABLE = """@AbapCatalog.tableCategory : #TRANSPARENT
define table {name} {{
  key mandt : abap.clnt not null;
  {field} : abap.char(10);
}}
"""


class NameChecksFixture(unittest.TestCase):

    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.put(os.path.join('src', 'core', 'zcl_cd_fixture.clas.abap'), GOOD_CLASS)
        self.put(os.path.join('ddic', 'core', 'zcd_ops_alchn.tabl.ddl'),
                 TABLE.format(name='zcd_ops_alchn', field='channel_id'))

    def tearDown(self):
        shutil.rmtree(self.root)

    def put(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(text)

    def test_clean_fixture_passes(self):
        self.assertEqual(name_checks.name_length_failures(self.root), [])
        self.assertEqual(name_checks.method_name_failures(self.root), [])

    def test_transparent_table_above_16_fails(self):
        self.put(os.path.join('ddic', 'core', 'zcd_ops_long_table.tabl.ddl'),
                 TABLE.format(name='zcd_ops_long_table', field='rule_id'))
        failures = name_checks.name_length_failures(self.root)
        self.assertEqual(len(failures), 1, failures)
        self.assertIn('transparent table zcd_ops_long_table (18 > 16)', failures[0])

    def test_long_field_method_and_attribute_fail(self):
        self.put(os.path.join('ddic', 'core', 'zcd_ops_alrule.tabl.ddl'),
                 TABLE.format(name='zcd_ops_alrule', field='a_field_name_longer_than_thirty_c'))
        self.put(os.path.join('src', 'core', 'zcl_cd_long.clas.abap'),
                 "CLASS zcl_cd_long DEFINITION PUBLIC FINAL.\n  PUBLIC SECTION.\n"
                 "    METHODS a_method_name_that_is_far_too_long.\n"
                 "    DATA mv_attribute_name_that_is_too_long TYPE i.\nENDCLASS.\n")
        text = '\n'.join(name_checks.name_length_failures(self.root))
        self.assertIn('field a_field_name_longer_than_thirty_c', text)
        self.assertIn('methods a_method_name_that_is_far_too_long', text)
        self.assertIn('data mv_attribute_name_that_is_too_long', text)

    def test_long_object_and_message_class_fail(self):
        self.put(os.path.join('src', 'core', 'zcl_cd_an_object_name_longer_than_30.clas.abap'), GOOD_CLASS)
        self.put(os.path.join('src', 'core', 'zcd_a_message_class_too_long.msag.xml'), '<x/>')
        text = '\n'.join(name_checks.name_length_failures(self.root))
        self.assertIn('object name zcl_cd_an_object_name_longer_than_30', text)
        self.assertIn('object name zcd_a_message_class_too_long (28 > 20)', text)

    def test_long_cds_entity_fails(self):
        self.put(os.path.join('src', 'fmon', 'zc_cd_x.ddls.asddls'),
                 'define view entity ZC_CD_A_VIEW_ENTITY_NAME_TOO_LONG as select from zcd_ops_alchn { key mandt }')
        self.assertIn('CDS name ZC_CD_A_VIEW_ENTITY_NAME_TOO_LONG', '\n'.join(name_checks.name_length_failures(self.root)))

    def test_method_with_data_prefix_or_camel_case_fails(self):
        self.put(os.path.join('src', 'core', 'zcl_cd_bad.clas.abap'),
                 "CLASS zcl_cd_bad DEFINITION PUBLIC FINAL.\n  PUBLIC SECTION.\n"
                 "    METHODS:\n      lv_value,\n      readRows,\n      gc_limit.\n"
                 "    METHODS a_test_method_name_beyond_thirty FOR TESTING.\nENDCLASS.\n")
        failures = name_checks.method_name_failures(self.root)
        text = '\n'.join(failures)
        self.assertIn('method lv_value: starts with a data prefix', text)
        self.assertIn('method readRows: not snake_case', text)
        self.assertIn('method gc_limit: starts with a data prefix', text)
        self.assertIn('method a_test_method_name_beyond_thirty (32 > 30)', text)
        self.assertEqual(len(failures), 4, failures)

    def test_predicate_and_interface_methods_pass(self):
        self.put(os.path.join('src', 'core', 'zcl_cd_ok.clas.abap'),
                 "CLASS zcl_cd_ok DEFINITION PUBLIC FINAL.\n  PUBLIC SECTION.\n"
                 "    METHODS is_allowed RETURNING VALUE(rv_ok) TYPE abap_bool.\n"
                 "    METHODS zif_cd_ops_rule~execute REDEFINITION.\nENDCLASS.\n")
        self.assertEqual(name_checks.method_name_failures(self.root), [])


if __name__ == '__main__':
    unittest.main()
