#!/usr/bin/env python3
"""Fixture tests for tools/param_definitions.py (portable check param_definitions_complete):
each case writes a small fixture suite (types interface, adapter prefix table, a reading
class, seed files, generated seed class) into a temporary folder.

Run:  python3 -m unittest discover -s tools/tests      (from ops-suite/)
"""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import param_definitions as pd  # noqa: E402

TYPES = """INTERFACE zif_cd_ops_types PUBLIC.
  CONSTANTS:
    BEGIN OF gc_param,
      limit TYPE ty_param_name VALUE 'FIX_LIMIT',
      flag  TYPE ty_param_name VALUE 'FIX_FLAG',
    END OF gc_param.
  CONSTANTS:
    BEGIN OF gc_param_prefix,
      alert TYPE ty_param_name VALUE 'ALERT_',
    END OF gc_param_prefix.
  CONSTANTS:
    BEGIN OF gc_param_default,
      limit TYPE i VALUE 10,
      route TYPE ty_param_name VALUE 'MORNING',
    END OF gc_param_default.
  CONSTANTS:
    BEGIN OF gc_param_area,
      ops TYPE zif_ca_param_types=>ty_area VALUE 'CD_OPS',
    END OF gc_param_area.
  CONSTANTS:
    BEGIN OF gc_param_area_prefix,
      alert TYPE ty_param_name VALUE 'ALERT_',
      fix   TYPE ty_param_name VALUE 'FIX_',
    END OF gc_param_area_prefix.
ENDINTERFACE.
"""
ADAPTER = """CLASS zcl_ca_ops_params IMPLEMENTATION.
  METHOD prefix_areas.
    rt_map = VALUE #( ( prefix = zif_cd_ops_types=>gc_param_area_prefix-alert area = zif_cd_ops_types=>gc_param_area-ops )
                      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-fix   area = zif_cd_ops_types=>gc_param_area-ops ) ).
  ENDMETHOD.
ENDCLASS.
"""
READER = """CLASS zcl_cd_fix IMPLEMENTATION.
  METHOD run.
    DATA(lv_limit) = lo_params->get_param( iv_name    = zif_cd_ops_types=>gc_param-limit
                                           iv_default = |{ zif_cd_ops_types=>gc_param_default-limit }| ).
    DATA(lv_on) = xsdbool( lo_params->get_param( zif_cd_ops_types=>gc_param-flag ) = abap_true ).
    DATA(lv_to) = lo_params->get_param( |{ zif_cd_ops_types=>gc_param_prefix-alert }{ lv_route }| ).
  ENDMETHOD.
ENDCLASS.
"""
AREAS = "AREA,DESCRIPTION,OWNER_TEAM,PROD_EDITABLE,ACTIVE\nCD_OPS,Fixture,TEAM,X,X\n"
HEADER = ",".join(pd.DEF_COLS) + "\n"
ROWS = {
    'ALERT_MORNING': "CD_OPS,ALERT_MORNING,P,LIST,,,,,,,,Recipients,TEAM\n",
    'FIX_FLAG': "CD_OPS,FIX_FLAG,P,BOOL,,,,,,,,A flag,TEAM\n",
    'FIX_LIMIT': "CD_OPS,FIX_LIMIT,P,INT,1,,10,,,,,A limit,TEAM\n",
}
SCOPE_DEF = {'NAME': 'FIX_SCOPE', 'VALUE_TYPE': 'CHAR', 'ALLOWED_PCRE': '[AC]'}
LIST_DEF = {'NAME': 'FIX_FIELDS', 'VALUE_TYPE': 'LIST', 'ALLOWED_PCRE': '[A-Z][A-Z0-9_]*'}
RUNTIME = {(pd.OPS_TYPES, 'gc_param_prefix-alert'): ('const', pd.OPS_TYPES, 'gc_param_default-route')}


class ParamDefinitionsTest(unittest.TestCase):

    def _failures(self, rows=None, reader=READER, extra=None, seed_stale=False):
        rows = dict(ROWS if rows is None else rows)
        with tempfile.TemporaryDirectory() as root:
            files = {pd.OPS_TYPES: TYPES, pd.ADAPTER: ADAPTER,
                     os.path.join('src', 'core', 'zcl_cd_fix.clas.abap'): reader,
                     pd.AREAS_CSV: AREAS,
                     pd.DEFS_CSV: HEADER + ''.join(rows[k] for k in sorted(rows))}
            files.update(extra or {})
            for rel, text in files.items():
                os.makedirs(os.path.dirname(os.path.join(root, rel)), exist_ok=True)
                with open(os.path.join(root, rel), 'w', encoding='utf-8') as fh:
                    fh.write(text)
            areas, defs, values, _ = pd.load(root)
            with open(os.path.join(root, pd.SEED), 'w', encoding='utf-8') as fh:
                fh.write(pd.render(areas, defs) + ('* stale\n' if seed_stale else ''))
            return pd.failures(root, runtime=RUNTIME, defaults={})

    def test_complete_fixture_passes(self):
        self.assertEqual(self._failures(), [])

    def test_constant_without_definition(self):
        rows = dict(ROWS)
        del rows['FIX_LIMIT']
        self.assertTrue(any('FIX_LIMIT' in f and 'no definition' in f for f in self._failures(rows)))

    def test_runtime_name_without_definition(self):
        rows = dict(ROWS)
        del rows['ALERT_MORNING']
        self.assertTrue(any('ALERT_MORNING' in f and 'run time' in f for f in self._failures(rows)))

    def test_definition_read_by_no_code(self):
        rows = dict(ROWS, FIX_UNUSED="CD_OPS,FIX_UNUSED,P,INT,,,,,,,,Not read,TEAM\n")
        self.assertTrue(any('FIX_UNUSED' in f and 'read by no code' in f for f in self._failures(rows)))

    def test_default_differs_from_code(self):
        rows = dict(ROWS, FIX_LIMIT="CD_OPS,FIX_LIMIT,P,INT,1,,12,,,,,A limit,TEAM\n")
        self.assertTrue(any('FIX_LIMIT' in f and 'code default' in f for f in self._failures(rows)))

    def test_flag_must_be_bool(self):
        rows = dict(ROWS, FIX_FLAG="CD_OPS,FIX_FLAG,P,CHAR,,,,,,,,A flag,TEAM\n")
        self.assertTrue(any('FIX_FLAG' in f and 'BOOL' in f for f in self._failures(rows)))

    def test_off_token_is_reported(self):
        reader = READER.replace("= abap_true ).", "<> 'N' ).")
        self.assertTrue(any("'N'" in f for f in self._failures(reader=reader)))

    def test_area_must_follow_prefix(self):
        areas = "AREA,DESCRIPTION,OWNER_TEAM,PROD_EDITABLE,ACTIVE\nCD_OPS,Fixture,TEAM,X,X\nCD_HCK,Other,TEAM,X,X\n"
        rows = dict(ROWS)
        rows['FIX_LIMIT'] = rows['FIX_LIMIT'].replace('CD_OPS', 'CD_HCK', 1)
        fails = self._failures(rows, extra={pd.AREAS_CSV: areas})
        self.assertTrue(any('FIX_LIMIT' in f and 'reads it from CD_OPS' in f for f in fails))

    def test_stale_seed_class_is_reported(self):
        self.assertTrue(any('not generated' in f for f in self._failures(seed_stale=True)))

    def test_list_needs_kind_p(self):
        rows = dict(ROWS, ALERT_MORNING="CD_OPS,ALERT_MORNING,S,LIST,,,,,,,,Recipients,TEAM\n")
        self.assertTrue(any('LIST needs kind P' in f for f in self._failures(rows)))

    def test_bool_default_must_be_x_or_blank(self):
        rows = dict(ROWS, FIX_FLAG="CD_OPS,FIX_FLAG,P,BOOL,,,N,,,,,A flag,TEAM\n")
        self.assertTrue(any('BOOL default' in f for f in self._failures(rows)))

    def test_allowed_pattern_whole_value(self):
        self.assertIsNone(pd.pattern_mismatch(SCOPE_DEF, 'C'))
        self.assertIsNone(pd.pattern_mismatch(SCOPE_DEF, 'a'))
        self.assertEqual(pd.pattern_mismatch(SCOPE_DEF, 'AC'), 'AC')

    def test_allowed_pattern_per_list_element(self):
        self.assertIsNone(pd.pattern_mismatch(LIST_DEF, 'VB1OK, VB2OK'))
        self.assertEqual(pd.pattern_mismatch(LIST_DEF, 'VB1OK,1X'), '1X')

    def test_default_outside_pattern_is_reported(self):
        rows = dict(ROWS, FIX_LIMIT="CD_OPS,FIX_LIMIT,P,INT,1,,10,[1-9],,,,A limit,TEAM\n")
        self.assertTrue(any('FIX_LIMIT' in f and 'allowed pattern' in f for f in self._failures(rows)))

    def test_delivered_queue_scope_is_c(self):
        """Design review 2026-11-07: one PRISM queue per bank is confirmed - definition default,
        value row and code default are C."""
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        _, defs, values, _ = pd.load(root)
        name = 'FMON_PRISM_THROTTLE_SCOPE'
        self.assertEqual(next(d['DEFAULT_VALUE'] for d in defs if d['NAME'] == name), 'C')
        self.assertEqual([v['LOW'] for v in values if v['NAME'] == name], ['C'])
        names = pd.expected_names(root)
        self.assertEqual(pd.code_default(root, name, names[name]), 'C')


class ConsolidationTest(unittest.TestCase):
    """Table consolidation 2026-11-08: generated method size and the definitions that replace
    customizing tables."""

    ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

    def test_definitions_in_parts(self):
        row = dict(AREA='CD_OPS', KIND='P', VALUE_TYPE='INT', MIN_VALUE='', MAX_VALUE='', DEFAULT_VALUE='',
                   ALLOWED_PCRE='', INTERFACE_NAME='', MANDATORY='', DEVELOPER_OWNED='', DESCRIPTION='d',
                   OWNER='o')
        defs = [dict(row, NAME=f'FIX_{i:03d}') for i in range(pd.PART_ROWS + 1)]
        text = pd.render([], defs)
        self.assertIn('INSERT LINES OF definitions_part_1( ) INTO TABLE rt_definitions.', text)
        self.assertIn('INSERT LINES OF definitions_part_2( ) INTO TABLE rt_definitions.', text)
        part2 = text.split('METHOD definitions_part_2.')[1].split('ENDMETHOD.')[0]
        self.assertEqual(part2.count('INSERT CORRESPONDING'), 1)

    def test_scaled_default(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, 'src'))
            with open(os.path.join(root, 'src', 'zif_cd_fix_types.intf.abap'), 'w', encoding='utf-8') as fh:
                fh.write("INTERFACE zif_cd_fix_types PUBLIC.\n  CONSTANTS:\n    BEGIN OF gc_param_default,\n"
                         "      hours TYPE i VALUE 26,\n    END OF gc_param_default.\nENDINTERFACE.\n")
            spec = {'FIX_MIN': ('const', os.path.join('src', 'zif_cd_fix_types.intf.abap'),
                                'gc_param_default-hours', 60)}
            self.assertEqual(pd.code_default(root, 'FIX_MIN', ('x', 'y', 'runtime'), spec), '1560')

    def test_stripe_settings_delivered_blank(self):
        _, defs, _, _ = pd.load(self.ROOT)
        stripe = [d for d in defs if d['NAME'].startswith('HCK_STRIPE_')]
        self.assertEqual(len(stripe), 10)
        self.assertTrue(all(d['AREA'] == 'CD_HCK' and d['DEFAULT_VALUE'] == '' for d in stripe))
        self.assertEqual(next(d['VALUE_TYPE'] for d in stripe if d['NAME'] == 'HCK_STRIPE_TABLE'), 'DDIC')


if __name__ == '__main__':
    unittest.main()
