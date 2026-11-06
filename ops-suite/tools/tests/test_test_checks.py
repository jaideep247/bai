"""Fixture tests of the portable test-path checks (tools/test_checks.py)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import test_checks  # noqa: E402

DAO = """CLASS zcl_cd_x_dao IMPLEMENTATION.
  METHOD zif_cd_x_dao~get_rows.
    SELECT a, b FROM zcd_x_tab WHERE a = @iv_a INTO TABLE @rt_rows.
    rt_rows = helper( rt_rows ).
  ENDMETHOD.
  METHOD helper.
    SELECT c FROM zcd_x_other INTO TABLE @DATA(lt_c).
    INSERT ls_line INTO TABLE rt_rows.
  ENDMETHOD.
  METHOD zif_cd_x_dao~save.
    MODIFY zcd_x_tab FROM TABLE @it_rows.
  ENDMETHOD.
ENDCLASS.
"""
ENGINE = """CLASS zcl_cd_x_engine IMPLEMENTATION.
  METHOD run.
    DATA(lo_dao) = zcl_cd_x_factory=>get_dao( ).
    rt_rows = lo_dao->get_rows( ).
  ENDMETHOD.
ENDCLASS.
"""
SEAMED = """CLASS zcl_cd_x_switch IMPLEMENTATION.
  METHOD read_mode.
    TEST-SEAM tvarvc_read.
      SELECT SINGLE low FROM tvarvc WHERE name = @gc_name INTO @lv_low.
    END-TEST-SEAM.
  ENDMETHOD.
ENDCLASS.
"""


class _Tree:
    """A temporary ops-suite tree: src/core/<class> files and tools/test_path_register.csv."""

    def __init__(self):
        self.dir = tempfile.TemporaryDirectory()
        self.root = self.dir.name
        os.makedirs(os.path.join(self.root, 'src', 'core'))
        os.makedirs(os.path.join(self.root, 'tools'))

    def add(self, name, code, test=None):
        base = os.path.join(self.root, 'src', 'core', name)
        with open(base + '.clas.abap', 'w', encoding='utf-8') as fh:
            fh.write(code)
        if test is not None:
            with open(base + '.clas.testclasses.abap', 'w', encoding='utf-8') as fh:
                fh.write(test)

    def register(self, *rows):
        with open(os.path.join(self.root, 'tools', 'test_path_register.csv'), 'w', encoding='utf-8') as fh:
            fh.write('object,path,covered_by,reason\n')
            for row in rows:
                fh.write(','.join(row) + '\n')


class TestPathEveryClass(unittest.TestCase):

    def setUp(self):
        self.tree = _Tree()

    def tearDown(self):
        self.tree.dir.cleanup()

    def test_own_include_passes(self):
        self.tree.add('zcl_cd_x_engine', ENGINE, 'CLASS ltc_x DEFINITION FOR TESTING.')
        self.assertEqual(test_checks.test_path_failures(self.tree.root), [])

    def test_class_without_path_is_reported(self):
        self.tree.add('zcl_cd_x_engine', ENGINE)
        self.assertEqual(len(test_checks.test_path_failures(self.tree.root)), 1)

    def test_covering_include_must_mention_class(self):
        self.tree.add('zcl_cd_x_engine', ENGINE, 'zcl_cd_x_factory=>get_dao( ).')
        self.tree.add('zcl_cd_x_factory', 'CLASS zcl_cd_x_factory IMPLEMENTATION.\nENDCLASS.')
        self.tree.register(('ZCL_CD_X_FACTORY', 'covered', 'ZCL_CD_X_ENGINE', 'construction only'))
        self.assertEqual(test_checks.test_path_failures(self.tree.root), [])
        self.tree.register(('ZCL_CD_X_FACTORY', 'covered', 'ZCL_CD_X_MISSING', 'construction only'))
        self.assertEqual(len(test_checks.test_path_failures(self.tree.root)), 1)

    def test_exemption_needs_reason(self):
        self.tree.add('zcl_cd_x_engine', ENGINE)
        self.tree.register(('ZCL_CD_X_ENGINE', 'exempt', '', ''))
        self.assertEqual(len(test_checks.test_path_failures(self.tree.root)), 1)
        self.tree.register(('ZCL_CD_X_ENGINE', 'exempt', '', 'kernel wrapper - QA1'))
        self.assertEqual(test_checks.test_path_failures(self.tree.root), [])

    def test_stale_register_row_is_reported(self):
        self.tree.register(('ZCL_CD_X_GONE', 'exempt', '', 'removed class'))
        self.assertEqual(len(test_checks.test_path_failures(self.tree.root)), 1)


class OsqlDoublesComplete(unittest.TestCase):

    def setUp(self):
        self.tree = _Tree()

    def tearDown(self):
        self.tree.dir.cleanup()

    def test_all_tables_of_called_methods_doubled(self):
        self.tree.add('zcl_cd_x_dao', DAO, "go_env = cl_osql_test_environment=>create( i_dependency_list = "
                                           "VALUE #( ( 'ZCD_X_TAB' ) ( 'ZCD_X_OTHER' ) ) ).\n"
                                           "mo_cut->get_rows( ).\n")
        self.assertEqual(test_checks.osql_double_failures(self.tree.root), [])

    def test_table_of_helper_not_doubled_is_reported(self):
        self.tree.add('zcl_cd_x_dao', DAO, "go_env = cl_osql_test_environment=>create( i_dependency_list = "
                                           "VALUE #( ( 'ZCD_X_TAB' ) ) ).\nmo_cut->get_rows( ).\n")
        failures = test_checks.osql_double_failures(self.tree.root)
        self.assertEqual(len(failures), 1)
        self.assertIn('ZCD_X_OTHER', failures[0])

    def test_untested_method_tables_not_required(self):
        self.tree.add('zcl_cd_x_dao', DAO, "go_env = cl_osql_test_environment=>create( i_dependency_list = "
                                           "VALUE #( ( 'ZCD_X_TAB' ) ) ).\nmo_cut->save( lt_rows ).\n")
        self.assertEqual(test_checks.osql_double_failures(self.tree.root), [])

    def test_sql_class_without_environment_is_reported(self):
        self.tree.add('zcl_cd_x_dao', DAO, 'mo_cut->get_rows( ).\n')
        self.assertEqual(len(test_checks.osql_double_failures(self.tree.root)), 1)

    def test_injected_seam_needs_no_double(self):
        self.tree.add('zcl_cd_x_switch', SEAMED, 'TEST-INJECTION tvarvc_read.\nEND-TEST-INJECTION.\n'
                                                'zcl_cd_x_switch=>read_mode( ).\n')
        self.assertEqual(test_checks.osql_double_failures(self.tree.root), [])

    def test_not_reached_marker_accepted(self):
        self.tree.add('zcl_cd_x_dao', DAO, "go_env = cl_osql_test_environment=>create( i_dependency_list = "
                                           "VALUE #( ( 'ZCD_X_TAB' ) ) ).\n\" osql-not-reached: ZCD_X_OTHER\n"
                                           "mo_cut->get_rows( ).\n")
        self.assertEqual(test_checks.osql_double_failures(self.tree.root), [])

    def test_internal_table_statements_are_not_tables(self):
        self.assertEqual(test_checks._tables('INSERT ls_line INTO TABLE lt_rows.\nMODIFY lt_rows FROM ls_line.\n'
                                             'DELETE lt_rows WHERE a = 1.\n'), set())
        self.assertEqual(test_checks._tables('DELETE FROM zcd_x_tab WHERE a = @lv_a.\n'), {'ZCD_X_TAB'})


class NoRealDaoInTests(unittest.TestCase):

    def setUp(self):
        self.tree = _Tree()

    def tearDown(self):
        self.tree.dir.cleanup()

    def test_injected_double_passes(self):
        self.tree.add('zcl_cd_x_engine', ENGINE, 'zcl_cd_x_injector=>inject_dao( mo_dao ).\n')
        self.assertEqual(test_checks.real_dao_failures(self.tree.root), [])

    def test_missing_injection_is_reported(self):
        self.tree.add('zcl_cd_x_engine', ENGINE, 'DATA(lt_rows) = NEW zcl_cd_x_engine( )->run( ).\n')
        self.assertEqual(len(test_checks.real_dao_failures(self.tree.root)), 1)

    def test_real_dao_created_is_reported(self):
        self.tree.add('zcl_cd_x_engine', ENGINE, 'zcl_cd_x_injector=>inject_dao( NEW zcl_cd_x_dao( ) ).\n')
        self.assertEqual(len(test_checks.real_dao_failures(self.tree.root)), 1)

    def test_dao_class_itself_is_not_checked(self):
        self.tree.add('zcl_cd_x_dao', DAO, 'mo_cut = NEW zcl_cd_x_dao( ).\n')
        self.assertEqual(test_checks.real_dao_failures(self.tree.root), [])


if __name__ == '__main__':
    unittest.main()
