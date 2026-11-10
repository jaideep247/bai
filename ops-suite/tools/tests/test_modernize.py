#!/usr/bin/env python3
"""Fixture tests for tools/modernize.py: table renames, caught-exception names, local test
helper classes - each on a small fixture suite in a temporary folder; a second run changes
nothing (idempotent). The quick-fix phase needs abaplint and is not run here.

Run:  python3 -m unittest discover -s tools/tests      (from ops-suite/)
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

SUITE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(SUITE, 'tools', 'modernize.py')

DDL = """@EndUserText.label : 'Ops suite: alert channels'
define table zcd_ops_alert_chn {
  key mandt : abap.clnt not null;
  key channel_id : abap.char(10) not null;
}
"""
ABAP = """*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fixture.clas.abap
*& Purpose:
*& Reads ZCD_OPS_ALERT_CHN; lx stays in this comment; ZCD_OPS_ALERT_CHNX is another table.
*&---------------------------------------------------------------------*
CLASS zcl_cd_fixture IMPLEMENTATION.
  METHOD read.
    TRY.
        SELECT channel_id FROM zcd_ops_alert_chn INTO TABLE @DATA(lt_rows).
        DATA(lv_text) = `lx in a literal`.
      CATCH cx_sy_open_sql_db INTO DATA(lx).
        " lx in a comment
        rv_text = lx->get_text( ) && ls_struct-lx.
        TRY.
            rv_text = lv_text.
          CATCH cx_root INTO DATA(lx_inner).
            rv_text = lx_inner->get_text( ) && lx->get_text( ).
        ENDTRY.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
"""
TESTS = """CLASS lcl_rows DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CLASS-METHODS row RETURNING VALUE(rs_row) TYPE zcd_ops_alert_log.
ENDCLASS.
CLASS lcl_kept DEFINITION FINAL.
ENDCLASS.
CLASS ltc_test IMPLEMENTATION.
  METHOD test.
    DATA(ls_row) = lcl_rows=>row( ).
    DATA(lo_kept) = NEW lcl_kept( ).
  ENDMETHOD.
ENDCLASS.
"""
DOC = "| ZCD_OPS_ALERT_RULE | `zcd_ops_alert_rule` routes; zcd_ops_alert_rules is not a table name |\n"


class ModernizeFixture(unittest.TestCase):

    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.put(os.path.join('ddic', 'core', 'zcd_ops_alert_chn.tabl.ddl'), DDL)
        self.put(os.path.join('src', 'core', 'zcd_ops_alert_chn.tabl.xml'), '<TABNAME>ZCD_OPS_ALERT_CHN</TABNAME>\n')
        self.put(os.path.join('src', 'core', 'zcl_cd_fixture.clas.abap'), ABAP)
        self.put(os.path.join('src', 'core', 'zcl_cd_fixture.clas.testclasses.abap'), TESTS)
        self.put(os.path.join('docs', 'ALERTING.md'), DOC)

    def tearDown(self):
        shutil.rmtree(self.root)

    def put(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)

    def read(self, rel):
        with open(os.path.join(self.root, rel), encoding='utf-8') as fh:
            return fh.read()

    def run_script(self, *extra):
        return subprocess.run([sys.executable, '-I', SCRIPT, '--root', self.root, *extra],
                              capture_output=True, text=True)

    def test_tables_renamed_with_files(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.assertTrue(os.path.exists(os.path.join(self.root, 'ddic', 'core', 'zca_ops_alchn.tabl.ddl')))
        self.assertFalse(os.path.exists(os.path.join(self.root, 'ddic', 'core', 'zcd_ops_alert_chn.tabl.ddl')))
        self.assertIn('define table zca_ops_alchn {', self.read(os.path.join('ddic', 'core', 'zca_ops_alchn.tabl.ddl')))
        self.assertEqual(self.read(os.path.join('src', 'core', 'zca_ops_alchn.tabl.xml')),
                         '<TABNAME>ZCA_OPS_ALCHN</TABNAME>\n')
        abap = self.read(os.path.join('src', 'core', 'zcl_cd_fixture.clas.abap'))
        self.assertIn('FROM zca_ops_alchn INTO', abap)
        self.assertIn('Reads ZCA_OPS_ALCHN;', abap)
        self.assertIn('ZCD_OPS_ALERT_CHNX is another table', abap, 'token boundary: longer names stay')
        doc = self.read(os.path.join('docs', 'ALERTING.md'))
        self.assertIn('| ZCA_OPS_ALRULE | `zca_ops_alrule` routes; zcd_ops_alert_rules is not', doc)

    def test_caught_exception_renamed_in_its_block(self):
        self.assertEqual(self.run_script().returncode, 0)
        abap = self.read(os.path.join('src', 'core', 'zcl_cd_fixture.clas.abap'))
        self.assertIn('CATCH cx_sy_open_sql_db INTO DATA(lx_error).', abap)
        self.assertIn('rv_text = lx_error->get_text( ) && ls_struct-lx.', abap, 'components are not variables')
        self.assertIn('rv_text = lx_inner->get_text( ) && lx_error->get_text( ).', abap, 'nested TRY in the block')
        self.assertIn('" lx in a comment', abap)
        self.assertIn('`lx in a literal`', abap)
        self.assertIn('lx stays in this comment', abap)

    def test_local_test_helper_renamed(self):
        self.assertEqual(self.run_script().returncode, 0)
        tests = self.read(os.path.join('src', 'core', 'zcl_cd_fixture.clas.testclasses.abap'))
        self.assertIn('CLASS ltd_rows DEFINITION FINAL FOR TESTING.', tests)
        self.assertIn('DATA(ls_row) = ltd_rows=>row( ).', tests)
        self.assertIn('NEW lcl_kept( )', tests, 'a local class that is not FOR TESTING keeps its name')
        self.assertIn('TYPE zca_ops_allog.', tests)

    def test_second_run_changes_nothing(self):
        self.assertEqual(self.run_script().returncode, 0)
        snapshot = {}
        for folder, _, files in os.walk(self.root):
            for name in files:
                snapshot[os.path.join(folder, name)] = self.read(os.path.join(folder, name))
        check = self.run_script('--check')
        self.assertEqual(check.returncode, 0, check.stdout)
        result = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertIn('tables: 0 file(s) changed', result.stdout)
        self.assertIn('exceptions: 0 file(s) changed', result.stdout)
        self.assertIn('naming: 0 file(s) changed', result.stdout)
        after = {}
        for folder, _, files in os.walk(self.root):
            for name in files:
                after[os.path.join(folder, name)] = self.read(os.path.join(folder, name))
        self.assertEqual(after, snapshot)

    def test_check_mode_changes_nothing(self):
        result = self.run_script('--check')
        self.assertEqual(result.returncode, 1, 'pending changes are reported with exit 1')
        self.assertTrue(os.path.exists(os.path.join(self.root, 'ddic', 'core', 'zcd_ops_alert_chn.tabl.ddl')))
        self.assertIn('INTO DATA(lx).', self.read(os.path.join('src', 'core', 'zcl_cd_fixture.clas.abap')))


if __name__ == '__main__':
    unittest.main()
