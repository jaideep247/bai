"""Fixture tests for the no_cp_patterns portable check (tools/name_checks.py)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import name_checks  # noqa: E402


class NoCpPatternsTest(unittest.TestCase):

    def _failures(self, code):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, 'src', 'core'))
            with open(os.path.join(root, 'src', 'core', 'zcl_x.clas.abap'), 'w', encoding='utf-8') as fh:
                fh.write(code)
            return name_checks.cp_pattern_failures(root)

    def test_pcre_match_is_accepted(self):
        code = "    rv_hit = zcl_cd_ops_util=>pcre_match( iv_value = lv_name iv_pattern = lv_pattern ).\n"
        self.assertEqual(self._failures(code), [])

    def test_cp_comparison_is_reported(self):
        self.assertEqual(len(self._failures("    IF lv_name CP lv_pattern.\n")), 1)

    def test_np_comparison_is_reported(self):
        self.assertEqual(len(self._failures("    IF lv_name np lv_pattern.\n")), 1)

    def test_cp_in_loop_where_is_reported(self):
        self.assertEqual(len(self._failures("    LOOP AT lt_runs INTO ls_run WHERE jobname CP lv_job.\n")), 1)

    def test_cp_range_row_is_reported(self):
        code = "    INSERT VALUE #( sign = 'I' option = 'CP' low = lv_job ) INTO TABLE lt_range.\n"
        self.assertEqual(len(self._failures(code)), 1)

    def test_cp_range_by_cond_is_reported(self):
        code = "      option = COND #( WHEN lv_token CA '*+' THEN 'CP' ELSE 'EQ' )\n"
        self.assertEqual(len(self._failures(code)), 1)

    def test_eq_range_row_is_accepted(self):
        code = "    INSERT VALUE #( sign = 'I' option = 'EQ' low = lv_job ) INTO TABLE lt_range.\n"
        self.assertEqual(self._failures(code), [])

    def test_comments_literals_and_names_ignored(self):
        code = ("* the old CP wildcard\n"
                "    lv_text = `CP in a literal`. \" CP in a comment\n"
                "    ms_def-cond1_op = 'CP'.\n"
                "    cl_abap_unit_assert=>assert_char_cp( act = lv_text exp = '*x*' ).\n"
                "    lv_x = ls_row-cp.\n")
        self.assertEqual(self._failures(code), [])


if __name__ == '__main__':
    unittest.main()
