#!/usr/bin/env python3
"""Fixture tests for tools/usage_checks.py (portable checks messages_used, params_used,
constants_used): each case writes a small fixture suite into a temporary folder.

Run:  python3 -m unittest discover -s tools/tests      (from ops-suite/)
"""
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import usage_checks  # noqa: E402

MESSAGES = """# Message class ZCD_OPS

| No. | Text |
|---|---|
| 001 | Raised through a constant |
| 002 | Raised by a MESSAGE statement |
| 003 | Constant read only by a test |
"""
TYPES = """INTERFACE zif_cd_fix_types PUBLIC.
  CONSTANTS:
    BEGIN OF gc_msg,
      raised    TYPE zif_cd_ops_types=>ty_msgno VALUE '001',
      test_only TYPE zif_cd_ops_types=>ty_msgno VALUE '003',
    END OF gc_msg.
  CONSTANTS:
    BEGIN OF gc_param,
      limit TYPE zif_cd_ops_types=>ty_param_name VALUE 'FIX_LIMIT',
    END OF gc_param.
  CONSTANTS:
    BEGIN OF gc_check_code,
      used      TYPE zif_cd_ops_types=>ty_check_code VALUE 'FIX_USED',
      in_cds    TYPE zif_cd_ops_types=>ty_check_code VALUE 'FIX_IN_CDS',
    END OF gc_check_code.
  "! Value domain: one referenced value keeps the others
  CONSTANTS:
    BEGIN OF gc_status,
      open   TYPE c LENGTH 1 VALUE 'O',
      closed TYPE c LENGTH 1 VALUE 'C',
    END OF gc_status.
  CONSTANTS gc_single TYPE i VALUE 7.
ENDINTERFACE.
"""
CLASS = """CLASS zcl_cd_fix DEFINITION PUBLIC FINAL.
  PUBLIC SECTION.
    METHODS run.
ENDCLASS.
CLASS zcl_cd_fix IMPLEMENTATION.
  METHOD run.
    DATA(lv_text) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fix_types=>gc_msg-raised ).
    MESSAGE e002(zcd_ops).
    DATA(lv_limit) = zif_cd_fix_types=>gc_param-limit.
    DATA(lv_code) = zif_cd_fix_types=>gc_check_code-used.
    DATA(lv_status) = zif_cd_fix_types=>gc_status-open.
    DATA(lv_single) = zif_cd_fix_types=>gc_single.
  ENDMETHOD.
ENDCLASS.
"""
TEST = """CLASS ltc_fix DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS reads_test_only FOR TESTING.
ENDCLASS.
CLASS ltc_fix IMPLEMENTATION.
  METHOD reads_test_only.
    DATA(lv_no) = zif_cd_fix_types=>gc_msg-test_only.
  ENDMETHOD.
ENDCLASS.
"""
CDS = """define view entity ZI_CD_Fix as select from zca_ops_finding
{ key run_id, case check_code when 'FIX_IN_CDS' then 'X' end as IsFix }
"""


class UsageChecksFixture(unittest.TestCase):

    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.put(os.path.join('config', 'zcd_ops_messages.md'), MESSAGES)
        self.put(os.path.join('src', 'core', 'zif_cd_fix_types.intf.abap'), TYPES)
        self.put(os.path.join('src', 'core', 'zcl_cd_fix.clas.abap'), CLASS)
        self.put(os.path.join('src', 'core', 'zcl_cd_fix.clas.testclasses.abap'), TEST)
        self.put(os.path.join('src', 'core', 'zi_cd_fix.ddls.asddls'), CDS)

    def tearDown(self):
        shutil.rmtree(self.root)

    def put(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(text)

    def replace(self, rel, old, new):
        path = os.path.join(self.root, rel)
        with open(path, encoding='utf-8') as fh:
            text = fh.read()
        self.assertIn(old, text)
        self.put(rel, text.replace(old, new))

    def test_message_raised_only_in_a_test_fails(self):
        failures = usage_checks.message_failures(self.root)
        self.assertEqual(failures, ['config/zcd_ops_messages.md: message 003 is raised by no production code'])

    def test_message_in_comment_is_not_raised(self):
        self.replace(os.path.join('src', 'core', 'zcl_cd_fix.clas.abap'), '    MESSAGE e002(zcd_ops).',
                     '    " MESSAGE e002(zcd_ops).')
        self.assertIn('config/zcd_ops_messages.md: message 002 is raised by no production code',
                      usage_checks.message_failures(self.root))

    def test_unread_parameter_fails(self):
        self.assertEqual(usage_checks.param_failures(self.root), [])
        self.replace(os.path.join('src', 'core', 'zcl_cd_fix.clas.abap'),
                     '    DATA(lv_limit) = zif_cd_fix_types=>gc_param-limit.\n', '')
        self.assertEqual(usage_checks.param_failures(self.root),
                         [os.path.join('src', 'core', 'zif_cd_fix_types.intf.abap')
                          + ': gc_param-limit is read by no production code'])

    def test_constants_used_by_code_test_or_cds_pass(self):
        self.assertEqual(usage_checks.constant_failures(self.root), [])

    def test_check_code_only_in_docs_fails(self):
        self.put(os.path.join('src', 'core', 'zi_cd_fix.ddls.asddls'), 'define view entity ZI_CD_Fix as select from t000 { key mandt }')
        self.put(os.path.join('docs', 'Fix.md'), '`FIX_IN_CDS` is explained here only.')
        self.assertEqual(usage_checks.constant_failures(self.root),
                         [os.path.join('src', 'core', 'zif_cd_fix_types.intf.abap')
                          + ': gc_check_code-in_cds is referenced by no code, test or CDS'])

    def test_value_domain_without_any_reference_fails(self):
        self.replace(os.path.join('src', 'core', 'zcl_cd_fix.clas.abap'),
                     '    DATA(lv_status) = zif_cd_fix_types=>gc_status-open.\n', '')
        self.replace(os.path.join('src', 'core', 'zcl_cd_fix.clas.abap'),
                     '    DATA(lv_single) = zif_cd_fix_types=>gc_single.\n', '')
        failures = usage_checks.constant_failures(self.root)
        rel = os.path.join('src', 'core', 'zif_cd_fix_types.intf.abap')
        self.assertEqual(sorted(failures), sorted([f'{rel}: gc_status (no value referenced by code, test or CDS)',
                                                   f'{rel}: gc_single is referenced by no code, test or CDS']))


if __name__ == '__main__':
    unittest.main()
