"""Fixture tests for the no_inline_in_call house rule (tools/abaptools/name_checks.py): no inline declaration
after IMPORTING of a method call in a functional position (refused by the compiler of the reference system
S/4HANA 2025, accepted by abaplint).

Modification log:
2026-11-16 | Initial version.
"""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from abaptools import checks, name_checks  # noqa: E402


class InlineInCallTest(unittest.TestCase):

    def _failures(self, code):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, 'src', 'core'))
            with open(os.path.join(root, 'src', 'core', 'zcl_x.clas.abap'), 'w', encoding='utf-8') as fh:
                fh.write(code)
            return name_checks.inline_in_call_failures(root)

    def test_assignment_with_inline_importing_is_reported(self):
        code = ("    DATA(lt_acks) = acks_of( EXPORTING it_payments = lt_due\n"
                "                             IMPORTING ev_has_time = DATA(lv_has_time) ).\n")
        failures = self._failures(code)
        self.assertEqual(len(failures), 1)
        self.assertIn('zcl_x.clas.abap:1:', failures[0])

    def test_declared_variable_is_accepted(self):
        code = ("    DATA lv_has_time TYPE abap_bool.\n"
                "    DATA(lt_acks) = acks_of( EXPORTING it_payments = lt_due\n"
                "                             IMPORTING ev_has_time = lv_has_time ).\n")
        self.assertEqual(self._failures(code), [])

    def test_existing_target_and_final_are_reported(self):
        self.assertEqual(len(self._failures("    lv_x = lo->m( IMPORTING ev_y = FINAL(lv_y) ).\n")), 1)

    def test_condition_is_reported(self):
        code = ("    IF lo_lock->acquire( EXPORTING iv_area = iv_area\n"
                "                         IMPORTING ev_holder = DATA(lv_holder) ) = abap_false.\n"
                "    ENDIF.\n")
        self.assertEqual(len(self._failures(code)), 1)

    def test_nested_call_is_reported(self):
        code = "    lo->m( iv_a = other( IMPORTING ev_b = DATA(lv_b) ) ).\n"
        self.assertEqual(len(self._failures(code)), 1)

    def test_standalone_call_is_accepted(self):
        code = ("    read( EXPORTING is_link = ls_link\n"
                "          IMPORTING et_rows = DATA(lt_rows) ev_failed = DATA(lv_failed) ).\n"
                "    lo->m( IMPORTING ev_y = DATA(lv_y) ).\n"
                "    zcl_y=>m( IMPORTING ev_y = DATA(lv_z) ).\n"
                "    CALL METHOD lo->m IMPORTING ev_y = DATA(lv_w).\n")
        self.assertEqual(self._failures(code), [])

    def test_inline_after_exporting_only_is_accepted(self):
        code = "    DATA(lv_x) = lo->m( EXPORTING iv_a = 1 IMPORTING ev_b = lv_b ) + VALUE i( ).\n"
        self.assertEqual(self._failures(code), [])

    def test_method_declarations_comments_and_literals_ignored(self):
        code = ("    METHODS m\n"
                "      IMPORTING\n"
                "        iv_a TYPE i\n"
                "      RETURNING\n"
                "        VALUE(rv_b) TYPE i.\n"
                "* lv_x = m( IMPORTING e = DATA(y) ).\n"
                "    lv_t = `x = m( IMPORTING e = DATA(y) )`. \" lv_x = m( IMPORTING e = DATA(y) )\n")
        self.assertEqual(self._failures(code), [])

    def test_shared_check_wraps_the_rule(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, 'src'))
            with open(os.path.join(root, 'src', 'zcl_x.clas.abap'), 'w', encoding='utf-8') as fh:
                fh.write("    lv_x = m( IMPORTING e = DATA(y) ).\n")
            self.assertEqual(len(checks.check_no_inline_in_call(root)), 1)


if __name__ == '__main__':
    unittest.main()
