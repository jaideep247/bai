"""Fixture tests for the cds_abap_parity portable check (tools/cds_abap_parity.py)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import cds_abap_parity  # noqa: E402

ABAP = ("INTERFACE zif_x PUBLIC.\n"
        "  \"! comment VALUE 99\n"
        "  CONSTANTS:\n"
        "    BEGIN OF gc_dash,\n"
        "      \"! days\n"
        "      window_days TYPE i VALUE 31,\n"
        "      pcre        TYPE string VALUE `^[A-Z]+`,\n"
        "    END OF gc_dash.\n"
        "  CONSTANTS:\n"
        "    BEGIN OF gc_status,\n"
        "      ok  TYPE c LENGTH 1 VALUE 'S',\n"
        "      bad TYPE c LENGTH 1 VALUE 'E',\n"
        "    END OF gc_status.\n"
        "  CONSTANTS gc_reason TYPE c LENGTH 2 VALUE '05'.\n"
        "ENDINTERFACE.\n")


class CdsAbapParityTest(unittest.TestCase):

    def _run(self, cds_text, pairs):
        with tempfile.TemporaryDirectory() as root:
            with open(os.path.join(root, 'v.asddls'), 'w', encoding='utf-8') as fh:
                fh.write(cds_text)
            with open(os.path.join(root, 'i.abap'), 'w', encoding='utf-8') as fh:
                fh.write(ABAP)
            return cds_abap_parity.pair_failures(root, pairs)

    @staticmethod
    def _pair(pattern, constants, mode='equal', scale=None):
        return [('p', 'v.asddls', pattern, 'i.abap', constants, mode, scale)]

    def test_constant_resolution(self):
        self.assertEqual(cds_abap_parity.abap_constant(ABAP, 'gc_dash-window_days'), '31')
        self.assertEqual(cds_abap_parity.abap_constant(ABAP, 'gc_dash-pcre'), '^[A-Z]+')
        self.assertEqual(cds_abap_parity.abap_constant(ABAP, 'gc_reason'), '05')
        self.assertIsNone(cds_abap_parity.abap_constant(ABAP, 'gc_dash-missing'))

    def test_equal_values_pass(self):
        cds = "where d >= dats_add_days( $session.system_date, -31, 'INITIAL' )\n"
        self.assertEqual(self._run(cds, self._pair(cds_abap_parity._WINDOW, 'gc_dash-window_days')), [])

    def test_drift_is_reported(self):
        cds = "where d >= dats_add_days( $session.system_date, -30, 'INITIAL' )\n"
        self.assertEqual(len(self._run(cds, self._pair(cds_abap_parity._WINDOW, 'gc_dash-window_days'))), 1)

    def test_text_constant_compared_exactly(self):
        cds = "when Item.ClearingReason = '5' then 1\n"
        self.assertEqual(len(self._run(cds, self._pair(r"ClearingReason\s*=\s*'(\w+)'", 'gc_reason'))), 1)

    def test_scale_applies(self):
        cds = "tstmp_current_utctimestamp( ), 'NULL' ) > 1860\n"
        self.assertEqual(self._run(cds, self._pair(r"'NULL'\s*\)\s*>\s*(\d+)", 'gc_dash-window_days',
                                                   scale=60)), [])

    def test_set_mode(self):
        pattern = cds_abap_parity._RUN_STATUS
        ok = "and ( status = 'S' or status = 'E' )\n"
        extra = "and ( status = 'S' or status = 'E' or status = 'N' )\n"
        pair = self._pair(pattern, ['gc_status-ok', 'gc_status-bad'], mode='set')
        self.assertEqual(self._run(ok, pair), [])
        self.assertEqual(len(self._run(extra, pair)), 1)

    def test_missing_pattern_is_drift(self):
        self.assertEqual(len(self._run("define view entity X\n",
                                       self._pair(cds_abap_parity._WINDOW, 'gc_dash-window_days'))), 1)

    def test_missing_constant_is_drift(self):
        cds = "where d >= dats_add_days( $session.system_date, -31, 'INITIAL' )\n"
        self.assertEqual(len(self._run(cds, self._pair(cds_abap_parity._WINDOW, 'gc_dash-nope'))), 1)

    def test_current_tree_has_no_drift(self):
        self.assertEqual(cds_abap_parity.failures(), [])


if __name__ == '__main__':
    unittest.main()
