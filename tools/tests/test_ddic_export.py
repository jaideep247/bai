"""Tests of tools/abaptools/ddic_export.py (no system is called: the parsing, the table lists and the comparison).

Modification log:
2026-11-15 | Initial version (table definitions from a landscape; repository field references checked against them).
2026-11-15 | Code scanner (ABAP SQL, typed structures, CDS), open-fields list, several export folders.
"""
import csv
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from abaptools import ddic_export  # noqa: E402

DEFINITION = """@EndUserText.label : 'Items'
@AbapCatalog.tableCategory : #TRANSPARENT
define table ztab {

  key mandt : mandt not null;
  key docno : zdocno not null;
  @AbapCatalog.foreignKey.screenCheck : true
  blart     : blart_kk
    with foreign key tfk003
      where mandt = ztab.mandt
        and blart = ztab.blart;
  augdt     : augdt_kk;
  include ci_ztab;

}
"""

PREVIEW = """<?xml version="1.0" encoding="utf-8"?>
<dataPreview:tableData xmlns:dataPreview="http://www.sap.com/adt/dataPreview">
 <dataPreview:totalRows>2</dataPreview:totalRows>
 <dataPreview:columns>
  <dataPreview:metadata dataPreview:name="FIELDNAME" dataPreview:type="C"/>
  <dataPreview:dataSet><dataPreview:data>MANDT</dataPreview:data><dataPreview:data>DOCNO</dataPreview:data></dataPreview:dataSet>
 </dataPreview:columns>
 <dataPreview:columns>
  <dataPreview:metadata dataPreview:name="KEYFLAG"/>
  <dataPreview:dataSet><dataPreview:data>X</dataPreview:data><dataPreview:data>X</dataPreview:data></dataPreview:dataSet>
 </dataPreview:columns>
</dataPreview:tableData>
"""


class TableList(unittest.TestCase):
    def test_comments_duplicates_and_case(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d, 't.txt')
            p.write_text('# header\ndfkkop\nDFKKKO   # header table\n\nDFKKOP\n', encoding='utf-8')
            self.assertEqual(ddic_export.load_table_list(p), ['DFKKOP', 'DFKKKO'])

    def test_name_that_could_change_the_sql_is_refused(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d, 't.txt')
            p.write_text("DFKKOP' OR '1'='1\n", encoding='utf-8')
            with self.assertRaises(ValueError):
                ddic_export.load_table_list(p)

    def test_product_list_is_valid_and_standard_only(self):
        names = ddic_export.load_table_list(Path(ROOT, 'ops-framework/config/ddic/standard_tables.txt'))
        self.assertIn('DFKKOP', names)
        self.assertFalse([n for n in names if n.startswith(('Z', 'Y'))])


class Parsing(unittest.TestCase):
    def test_definition_fields_keys_includes(self):
        fields, keys, includes = ddic_export.parse_definition(DEFINITION)
        self.assertEqual(fields, {'MANDT', 'DOCNO', 'BLART', 'AUGDT'})
        self.assertEqual(keys, {'MANDT', 'DOCNO'})
        self.assertEqual(includes, ['CI_ZTAB'])

    def test_preview_is_read_by_column(self):
        rows = ddic_export.parse_preview(PREVIEW)
        self.assertEqual(rows, [{'FIELDNAME': 'MANDT', 'KEYFLAG': 'X'}, {'FIELDNAME': 'DOCNO', 'KEYFLAG': 'X'}])

    def test_empty_preview(self):
        self.assertEqual(ddic_export.parse_preview('<a:tableData xmlns:a="x"/>'), [])


class Compare(unittest.TestCase):
    def _exports(self, d):
        Path(d, 'ZTAB.acds').write_text(DEFINITION, encoding='utf-8')
        with Path(d, 'ZFULL.fields.csv').open('w', newline='', encoding='utf-8') as fh:
            w = csv.DictWriter(fh, fieldnames=['FIELDNAME', 'KEYFLAG'])
            w.writeheader()
            w.writerows([{'FIELDNAME': 'MANDT', 'KEYFLAG': 'X'}, {'FIELDNAME': '.INCLUDE', 'KEYFLAG': ''},
                         {'FIELDNAME': 'ZZ_REF', 'KEYFLAG': ''}])
        return ddic_export.load_exports(d)

    def test_states(self):
        with tempfile.TemporaryDirectory() as d:
            exports = self._exports(d)
            refs = [{'table': 'ZTAB', 'field': 'AUGDT', 'evidence': 'V', 'where': 'a'},
                    {'table': 'ZTAB', 'field': 'ABGRD', 'evidence': 'V', 'where': 'b'},
                    {'table': 'ZFULL', 'field': 'ZZ_REF', 'evidence': 'V', 'where': 'c'},
                    {'table': 'ZFULL', 'field': 'NOPE', 'evidence': 'C', 'where': 'd'},
                    {'table': 'OTHER', 'field': 'X', 'evidence': 'V', 'where': 'e'},
                    {'table': 'ZFULL', 'field': '‹A FIELD›', 'evidence': 'V', 'where': 'f'}]
            states = {r['where']: r['state'] for r in ddic_export.compare(exports, refs)}
        self.assertEqual(states['a'], 'exists')
        self.assertTrue(states['b'].startswith('not in definition (may be in an include: CI_ZTAB'))
        self.assertEqual(states['c'], 'exists')            # a field list has includes and appends resolved
        self.assertEqual(states['d'], 'MISSING')
        self.assertEqual(states['e'], 'table not exported')
        self.assertEqual(states['f'], 'placeholder (not compared)')   # a placeholder never fails

    def test_report_lists_missing_first_and_counts_the_rest(self):
        rows = [{'table': 'T', 'field': 'A', 'evidence': 'V', 'state': 'exists', 'where': 'w1'},
                {'table': 'T', 'field': 'B', 'evidence': 'C', 'state': 'MISSING', 'where': 'w2'},
                {'table': 'T', 'field': 'C', 'evidence': 'C', 'state': 'exists', 'where': 'w3'},
                {'table': 'U', 'field': 'D', 'evidence': 'V', 'state': 'table not exported', 'where': 'w4'}]
        text = ddic_export.report(rows)
        body = [line for line in text.splitlines() if line.startswith('| T ')]
        self.assertEqual([line.split('|')[2].strip() for line in body], ['B', 'A'])
        self.assertIn('1 references not compared', text)

    def test_repository_references_are_found(self):
        refs = ddic_export.repo_references(ROOT)
        pairs = {(r['table'], r['field']) for r in refs}
        self.assertIn(('DFKKOP', 'AUGRD'), pairs)
        self.assertIn(('DFKKKO', 'STBEL'), pairs)

    def test_landscape_exports_of_the_first_consumer_have_no_missing_field(self):
        folder = Path(ROOT, 'ops-suite/ddic/landscape_2026-11-15')
        rows = ddic_export.compare(ddic_export.load_exports(folder), ddic_export.repo_references(ROOT))
        self.assertEqual([r for r in rows if r['state'] == 'MISSING'], [])


TABLES = {'DPAYH', 'DFKKOP', 'DFKKKO', 'TFK042Z'}

ABAP_SQL = """CLASS zcl_x IMPLEMENTATION.
  METHOD read.
    " a comment naming p~pymet is not code
    SELECT p~laufd, p~pymet, z~xeinz, 'p~bukrs' AS lit
      FROM dpayh AS p
      INNER JOIN tfk042z AS z ON z~zlsch = p~pymet
      WHERE p~xvorl = @space
        AND EXISTS ( SELECT opbel FROM dfkkop WHERE augbl = p~doc1r AND budat > @lv_day )
      INTO TABLE @DATA(lt_rows).
    SELECT laufd, bukrs, COUNT(*) AS n
      FROM dpayh
      WHERE laufi IN @lt_ids
      GROUP BY laufd, bukrs
      ORDER BY laufd, n
      INTO CORRESPONDING FIELDS OF TABLE @rt_rows.
    SELECT (lv_fields) FROM dpayh INTO TABLE @rt_any.
  ENDMETHOD.
ENDCLASS.
"""


class CodeScanner(unittest.TestCase):
    def refs(self, text, scan=ddic_export.scan_abap, tables=TABLES):
        return {(r['table'], r['field'], int(r['where'].rsplit(':', 1)[1]), bool(r['candidates']))
                for r in scan(text, 'x', tables)}

    def test_cleaning_keeps_positions_and_drops_comments_and_literals(self):
        text = "* full line p~a\nSELECT 'x~y' \"p~b\n FROM t."
        clean = ddic_export.clean_abap(text)
        self.assertEqual(len(clean), len(text))
        self.assertNotIn('p~a', clean)
        self.assertNotIn('x~y', clean)
        self.assertNotIn('p~b', clean)
        self.assertIn('from t', clean)

    def test_aliases_joins_subqueries_and_single_table_lists(self):
        refs = self.refs(ABAP_SQL)
        self.assertIn(('DPAYH', 'PYMET', 4, False), refs)        # alias~field in the list
        self.assertIn(('DPAYH', 'PYMET', 6, False), refs)        # in the ON condition
        self.assertIn(('TFK042Z', 'XEINZ', 4, False), refs)
        self.assertIn(('DFKKOP', 'OPBEL', 8, False), refs)       # subquery with one source
        self.assertIn(('DFKKOP', 'BUDAT', 8, False), refs)       # left-hand side of its WHERE
        self.assertIn(('DPAYH', 'DOC1R', 8, False), refs)        # outer alias inside the subquery
        self.assertIn(('DPAYH', 'BUKRS', 10, False), refs)       # unqualified, one source
        self.assertIn(('DPAYH', 'LAUFI', 12, False), refs)
        self.assertIn(('DPAYH', 'BUKRS', 13, False), refs)       # GROUP BY
        fields = {f for _t, f, _l, _c in refs}
        self.assertNotIn('AUGBL', {f for t, f, _l, _c in refs if t == 'DPAYH'})
        self.assertNotIn('N', fields)                            # ORDER BY a result name
        self.assertNotIn('LV_FIELDS', fields)                    # dynamic field list
        self.assertNotIn('LT_IDS', fields)
        self.assertNotIn(('DPAYH', 'BUKRS', 4, False), refs)     # literal and comment

    def test_select_list_items_are_marked_for_a_result_name(self):
        rows = ddic_export.scan_abap(ABAP_SQL, 'x', TABLES)
        item = {(r['field'], int(r['where'].rsplit(':', 1)[1])): r['item'] for r in rows}
        self.assertTrue(item[('PYMET', 4)])
        self.assertFalse(item[('PYMET', 6)])
        self.assertTrue(item[('BUKRS', 10)])

    def test_an_alias_of_two_tables_is_unresolved(self):
        text = """CLASS c IMPLEMENTATION.
  METHOD m.
    SELECT a~opbel FROM dfkkop AS a
      WHERE EXISTS ( SELECT a~opbel FROM dfkkko AS a WHERE a~fikey = @lv )
      INTO TABLE @DATA(lt).
  ENDMETHOD.
ENDCLASS.
"""
        refs = self.refs(text)
        self.assertTrue(refs)
        self.assertTrue(all(c for _t, _f, _l, c in refs if _f in ('OPBEL', 'FIKEY')))

    def test_joins_without_qualification_are_not_judged(self):
        text = """CLASS c IMPLEMENTATION.
  METHOD m.
    SELECT laufd FROM dpayh INNER JOIN dfkkop ON dfkkop~augbl = dpayh~doc1r INTO TABLE @DATA(lt).
  ENDMETHOD.
ENDCLASS.
"""
        refs = self.refs(text)
        self.assertNotIn('LAUFD', {f for _t, f, _l, _c in refs})
        self.assertIn(('DFKKOP', 'AUGBL', 3, False), refs)

    def test_typed_structures_tables_rows_value_and_parameters(self):
        text = """CLASS ltc DEFINITION FOR TESTING.
  PRIVATE SECTION.
    METHODS run_of IMPORTING iv TYPE i RETURNING VALUE(rs_run) TYPE dpayh.
    DATA ms_item TYPE dfkkop.
ENDCLASS.
CLASS ltc IMPLEMENTATION.
  METHOD run_of.
    rs_run-pymet = iv.
    ms_item-augbl = space.
  ENDMETHOD.
  METHOD insert.
    DATA lt_runs TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA: ls_run TYPE dpayh,
          lv_x   TYPE dpayh-bukrs.
    ls_run-bukrs = 'X'.
    lt_runs = VALUE #( ( laufd = sy-datum bukrs = 'A' )
                       ( laufd = sy-datum zz_status = 'B' ) ).
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      <ls_run>-xvorl = space.
    ENDLOOP.
    DATA(ls_item) = VALUE dfkkop( opbel = '1' ).
  ENDMETHOD.
  METHOD other.
    DATA ls_run TYPE zcd_other.
    ls_run-bukrs = 'Y'.
  ENDMETHOD.
ENDCLASS.
"""
        refs = self.refs(text)
        for exp in [('DPAYH', 'PYMET', 8), ('DFKKOP', 'AUGBL', 9), ('DPAYH', 'BUKRS', 14), ('DPAYH', 'BUKRS', 15),
                    ('DPAYH', 'LAUFD', 16), ('DPAYH', 'BUKRS', 16), ('DPAYH', 'ZZ_STATUS', 17),
                    ('DPAYH', 'XVORL', 19), ('DFKKOP', 'OPBEL', 21)]:
            self.assertIn(exp + (False,), refs)
        self.assertNotIn(('DPAYH', 'BUKRS', 25, False), refs)    # same name, other type in another method

    def test_a_variable_of_two_types_is_unresolved(self):
        text = """FORM f.
  DATA ls TYPE dpayh.
  DATA ls TYPE zother.
  ls-bukrs = 1.
ENDFORM.
"""
        self.assertEqual(self.refs(text), {('DPAYH', 'BUKRS', 4, True)})

    def test_cds_aliases_joins_associations_and_single_source(self):
        text = """// a comment Pay.bukrs
@EndUserText.label: 'x'
define view entity ZI_X
  as select from    dpayh as Pay
    left outer join dpayh as Newer on Newer.doc1r = Pay.doc1r
  association [0..1] to tfk042z as _Method on _Method.zlsch = Pay.rzawe
{
  key Pay.laufd as RunDate,
      Pay.bukrs as CompanyCode,
      abs( Pay.rwbtr ) as Amount,
      _Method
}
where Pay.xvorl = ' '
"""
        refs = self.refs(text, ddic_export.scan_cds)
        for exp in [('DPAYH', 'DOC1R', 5), ('TFK042Z', 'ZLSCH', 6), ('DPAYH', 'RZAWE', 6), ('DPAYH', 'LAUFD', 8),
                    ('DPAYH', 'BUKRS', 9), ('DPAYH', 'RWBTR', 10), ('DPAYH', 'XVORL', 13)]:
            self.assertIn(exp + (False,), refs)
        self.assertNotIn(1, {line for _t, _f, line, _c in refs})
        single = """define view entity ZI_Y as select from dfkkop
{
  @Semantics.amount.currencyCode: 'Currency'
  key opbel,
      cast( betrw as abap.dec( 23, 2 ) ) as Amount,
      waers as Currency
}
where augbl <> ' ' and budat >= $session.system_date
"""
        refs = self.refs(single, ddic_export.scan_cds)
        self.assertEqual({f for _t, f, _l, _c in refs}, {'OPBEL', 'BETRW', 'WAERS', 'AUGBL', 'BUDAT'})
        union = """define view entity ZI_Z as select from dpayh as A { A.laufd as D }
union all select from dfkkop as A { A.augdt as D }
"""
        refs = self.refs(union, ddic_export.scan_cds)
        self.assertEqual(refs, {('DPAYH', 'LAUFD', 1, False), ('DFKKOP', 'AUGDT', 2, False)})

    def test_only_exported_tables_are_reported(self):
        self.assertEqual(self.refs(ABAP_SQL, tables={'TFK042Z'}), {('TFK042Z', 'XEINZ', 4, False),
                                                                    ('TFK042Z', 'ZLSCH', 6, False)})

    def test_states_open_list_and_report(self):
        exports = {'DPAYH': {'fields': {'LAUFD', 'BBUKR'}, 'complete': True, 'includes': []}}
        refs = [{'table': 'DPAYH', 'field': f, 'where': f'x:{n}', 'kind': 'sql', 'candidates': c, 'pos': 0,
                 'item': False}
                for n, (f, c) in enumerate([('LAUFD', []), ('BUKRS', []), ('ZZ_STATUS', []), ('PYMET', []),
                                            ('LAUFD', ['DPAYH', 'DFKKOP'])])]
        rows = ddic_export.compare_code(exports, refs)
        self.assertEqual([r['state'] for r in rows],
                         ['exists', 'MISSING', 'customer field (not in this export)', 'MISSING',
                          'unresolved (DPAYH | DFKKOP)'])
        rows = ddic_export.apply_open(rows, {('DPAYH', 'PYMET'): 'V999'})
        self.assertEqual(rows[3]['state'], 'missing, open V999')
        text = ddic_export.report_code(rows)
        self.assertEqual(text.splitlines()[2].split('|')[2].strip(), 'BUKRS')    # MISSING first
        self.assertIn('1 MISSING', text)
        self.assertIn('1 missing, open', text)

    def test_compare_exits_non_zero_on_a_missing_code_field(self):
        with tempfile.TemporaryDirectory() as d:
            repo, exp = Path(d, 'repo'), Path(d, 'exp')
            (repo / 'x' / 'src').mkdir(parents=True)
            exp.mkdir()
            (repo / 'x' / 'src' / 'zcl_a.clas.abap').write_text(
                "CLASS zcl_a IMPLEMENTATION.\n  METHOD m.\n    SELECT bukrs FROM dpayh INTO TABLE @DATA(lt).\n"
                "  ENDMETHOD.\nENDCLASS.\n", encoding='utf-8')
            with Path(exp, 'DPAYH.fields.csv').open('w', newline='', encoding='utf-8') as fh:
                w = csv.DictWriter(fh, fieldnames=['FIELDNAME'])
                w.writeheader()
                w.writerows([{'FIELDNAME': 'LAUFD'}, {'FIELDNAME': 'BBUKR'}])
            out = Path(d, 'open.csv')
            out.write_text('TABLE,FIELD,VERIFY,NOTE\nDPAYH,BUKRS,V999,later\n', encoding='utf-8')
            with open(os.devnull, 'w') as null:
                stdout, sys.stdout = sys.stdout, null
                try:
                    failed = ddic_export.main(['compare', '--exports', str(exp), '--repo', str(repo)])
                    accepted = ddic_export.main(['compare', '--exports', str(exp), '--repo', str(repo),
                                                 '--open', str(out)])
                finally:
                    sys.stdout = stdout
            fails, counts = ddic_export.check_folders(repo, ddic_export.export_folders(d), ())
        self.assertEqual(failed, 1)
        self.assertEqual(accepted, 0)
        self.assertEqual(fails, ['exp: DPAYH-BUKRS x/src/zcl_a.clas.abap:3'])
        self.assertEqual(counts, {'MISSING': 1})


class Export(unittest.TestCase):
    def test_export_writes_files_and_manifest(self):
        class Fake:
            def table_source(self, t):
                return (200, DEFINITION) if t == 'ZTAB' else (404, '')

            def sql(self, statement, rows=2000):
                return (200, PREVIEW) if "'ZTAB'" in statement else (200, '<a:tableData xmlns:a="x"/>')

        with tempfile.TemporaryDirectory() as d:
            manifest = ddic_export.export(Fake(), ['ZTAB', 'NONE'], Path(d), log=lambda *_: None)
            self.assertTrue(manifest['tables']['ZTAB']['found'])
            self.assertFalse(manifest['tables']['NONE']['found'])
            self.assertTrue(Path(d, 'ZTAB.acds').exists())
            self.assertEqual(json.loads(Path(d, 'manifest.json').read_text())['tables']['ZTAB']['fields'], 2)


if __name__ == '__main__':
    unittest.main()
