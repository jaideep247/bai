"""Unit tests of tools/abapgit_serialize.py (run: python3 -m unittest discover -s tools/tests)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import abapgit_serialize as ser  # noqa: E402

AREA = """@EndUserText.label : 'Areas'
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_t_area {
  key client : abap.clnt not null;
  key area   : zca_param_area_id not null;
  text       : abap.char(60);
}
"""
DEF = """@EndUserText.label : 'Definitions'
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_t_def {
  key client : abap.clnt not null;
  @AbapCatalog.foreignKey.screenCheck : true
  key area   : zca_param_area_id not null
    with foreign key [0..*,1] zca_t_area
      where client = zca_t_def.client
        and area = zca_t_def.area;
  key name   : abap.char(30) not null; // comment
}
"""


class SerializeTest(unittest.TestCase):

    def test_parse_fields_and_foreign_key(self):
        table, problems = ser.parse_table(DEF, 'def.tabl.ddl')
        self.assertEqual(problems, [])
        self.assertEqual([f['name'] for f in table['fields']], ['CLIENT', 'AREA', 'NAME'])
        self.assertEqual(table['fields'][1]['fk']['checktable'], 'ZCA_T_AREA')
        self.assertEqual(table['fields'][1]['fk']['conditions'],
                         [('CLIENT', 'ZCA_T_DEF', 'CLIENT'), ('AREA', 'ZCA_T_DEF', 'AREA')])

    def test_foreign_key_xml(self):
        area, _ = ser.parse_table(AREA, 'area.tabl.ddl')
        definition, _ = ser.parse_table(DEF, 'def.tabl.ddl')
        xml, problems = ser.table_xml(definition, {'ZCA_T_AREA': area, 'ZCA_T_DEF': definition},
                                      {'ZCA_PARAM_AREA_ID': 'CHAR'}, {'ZCA_PARAM_AREA_ID': 'ZCA_PARAM_AREA_ID'})
        self.assertEqual(problems, [])
        self.assertIn('<CHECKTABLE>ZCA_T_AREA</CHECKTABLE>', xml)
        self.assertEqual(xml.count('<DD05M>'), 2)
        self.assertIn('<PRIMPOS>0002</PRIMPOS>', xml)
        self.assertIn('<PROTOKOLL>X</PROTOKOLL>', xml)

    def test_unknown_check_table_is_a_problem(self):
        definition, _ = ser.parse_table(DEF, 'def.tabl.ddl')
        _, problems = ser.table_xml(definition, {'ZCA_T_DEF': definition}, {}, {})
        self.assertEqual(len(problems), 1)

    def test_long_table_name_is_a_problem(self):
        _, problems = ser.parse_table(AREA.replace('zca_t_area', 'zca_t_area_too_long'), 'x.tabl.ddl')
        self.assertEqual(len(problems), 1)

    def test_unparsable_field_is_a_problem(self):
        _, problems = ser.parse_table(AREA.replace('text       : abap.char(60);', 'text abap.char(60);'), 'x')
        self.assertEqual(len(problems), 1)

    def test_repository_is_serialized_and_current(self):
        stage, rows = ser.build()
        self.assertEqual(stage.problems, [])
        self.assertEqual(stage.changed(), [], 'run python3 tools/abapgit_serialize.py')
        self.assertGreater(len(rows), 0)


if __name__ == '__main__':
    unittest.main()
