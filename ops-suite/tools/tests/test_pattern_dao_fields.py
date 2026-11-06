"""Guard of the pattern migration: ZCL_CD_OPS_PATTERN_DAO reads every configuration row with the
complete field list of its table and writes the row back whole (UPDATE ... FROM TABLE), so a
field missing from a list would be cleared. Each SELECT of read_table must name exactly the
fields of the table's DDL in ddic/ (client excluded)."""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DAO = os.path.join(ROOT, 'src', 'core', 'zcl_cd_ops_pattern_dao.clas.abap')
FIELD = re.compile(r'^\s*(key\s+)?([a-z_0-9]+)\s*:', re.I)


def ddl_fields(table):
    for folder in os.listdir(os.path.join(ROOT, 'ddic')):
        path = os.path.join(ROOT, 'ddic', folder, table + '.tabl.ddl')
        if os.path.exists(path):
            body = open(path, encoding='utf-8').read().split('{', 1)[1].split('}', 1)[0]
            return [m.group(2).lower() for line in body.splitlines()
                    for m in [FIELD.match(line.split('//')[0])] if m and m.group(2).lower() != 'mandt']
    raise AssertionError(f'no DDL for {table}')


def read_table_selects():
    text = open(DAO, encoding='utf-8').read()
    body = re.search(r'METHOD read_table\.(.*?)ENDMETHOD\.', text, re.S).group(1)
    return {m.group(2).lower(): [f.strip().lower() for f in m.group(1).split(',')]
            for m in re.finditer(r'SELECT\s+(.*?)\s+FROM\s+(\w+)', body, re.S)}


class PatternDaoFieldListTest(unittest.TestCase):

    def test_every_migration_table_is_read(self):
        self.assertEqual(set(read_table_selects()), {'zcd_ebs_flow_pat', 'zcd_fmon_iface', 'zcd_job_step',
                                                     'zcd_ops_alrule', 'zcd_hck_def', 'zcd_hck_suppress'})

    def test_field_lists_are_complete(self):
        for table, fields in read_table_selects().items():
            with self.subTest(table=table):
                self.assertEqual(sorted(fields), sorted(ddl_fields(table)))


if __name__ == '__main__':
    unittest.main()
