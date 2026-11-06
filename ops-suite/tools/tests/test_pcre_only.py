"""Fixture tests for the pcre_only portable check (tools/name_checks.py)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import name_checks  # noqa: E402


class PcreOnlyTest(unittest.TestCase):

    def _failures(self, code):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, 'src', 'core'))
            with open(os.path.join(root, 'src', 'core', 'zcl_x.clas.abap'), 'w', encoding='utf-8') as fh:
                fh.write(code)
            return name_checks.posix_regex_failures(root)

    def test_pcre_is_accepted(self):
        self.assertEqual(self._failures("    rv_ok = xsdbool( matches( val = lv_text pcre = gc_pattern ) ).\n"), [])

    def test_posix_argument_is_reported(self):
        self.assertEqual(len(self._failures("    rv_ok = xsdbool( matches( val = lv_text regex = gc_pattern ) ).\n")), 1)

    def test_find_regex_statement_is_reported(self):
        self.assertEqual(len(self._failures("    FIND FIRST OCCURRENCE OF REGEX gc_pattern IN lv_text.\n")), 1)

    def test_find_pcre_statement_is_accepted(self):
        self.assertEqual(self._failures("    FIND FIRST OCCURRENCE OF PCRE gc_pattern IN lv_text.\n"), [])

    def test_posix_factory_is_reported(self):
        self.assertEqual(len(self._failures("    DATA(lo_regex) = cl_abap_regex=>create_posix( pattern = gc_pattern ).\n")), 1)

    def test_comments_and_literals_ignored(self):
        code = ("* uses regex = in a comment\n"
                "    lv_text = `regex = in a literal`. \" regex = here too\n")
        self.assertEqual(self._failures(code), [])


if __name__ == '__main__':
    unittest.main()
