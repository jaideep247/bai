"""Tests of tools/abaptools/ddic_export.py (no system is called: the parsing, the table lists and the comparison).

Modification log:
2026-11-15 | Initial version (table definitions from a landscape; repository field references checked against them).
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
                    {'table': 'OTHER', 'field': 'X', 'evidence': 'V', 'where': 'e'}]
            states = {r['where']: r['state'] for r in ddic_export.compare(exports, refs)}
        self.assertEqual(states['a'], 'exists')
        self.assertTrue(states['b'].startswith('not in definition (may be in an include: CI_ZTAB'))
        self.assertEqual(states['c'], 'exists')            # a field list has includes and appends resolved
        self.assertEqual(states['d'], 'MISSING')
        self.assertEqual(states['e'], 'table not exported')

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
