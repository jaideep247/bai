#!/usr/bin/env python3
"""Fixture tests for tools/abapgit_serialize.py (audit A89 and secondary indexes).

Each test copies ops-suite into a temporary directory, changes one DDL there and runs the
serializer of the copy, so the repository itself is never touched.

Run:  python3 -m unittest discover -s tools/tests      (from ops-suite/)
"""
import filecmp
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

SUITE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FMON_FILE = os.path.join('ddic', 'fmon', 'zcd_fmon_file.tabl.ddl')
FMON_XML = os.path.join('src', 'fmon', 'zcd_fmon_file.tabl.xml')


class SerializerFixture(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        # the serializer writes ../.abapgit.xml, so the copy sits one level down
        self.root = os.path.join(self.tmp, 'ops-suite')
        shutil.copytree(SUITE, self.root, ignore=shutil.ignore_patterns('.git', 'node_modules', '__pycache__'))
        # bring the copy to a clean, serialized state first
        self.assertEqual(self.run_serializer().returncode, 0)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_serializer(self):
        return subprocess.run([sys.executable, '-I', os.path.join(self.root, 'tools', 'abapgit_serialize.py')],
                              cwd=self.root, capture_output=True, text=True)

    def edit_ddl(self, old, new):
        path = os.path.join(self.root, FMON_FILE)
        with open(path, encoding='utf-8') as fh:
            text = fh.read()
        self.assertIn(old, text)
        with open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text.replace(old, new, 1))

    def xml_snapshot(self):
        snap = {}
        for folder, _, files in os.walk(os.path.join(self.root, 'src')):
            for name in files:
                if name.endswith('.xml'):
                    path = os.path.join(folder, name)
                    with open(path, encoding='utf-8') as fh:
                        snap[path] = fh.read()
        return snap

    def read(self, rel):
        with open(os.path.join(self.root, rel), encoding='utf-8') as fh:
            return fh.read()

    # ------------------------------------------------------------------ tests

    def test_malformed_field_leaves_all_xml_intact(self):
        # a table later in the run order changes (fmon after core/ebs) AND one field is malformed:
        # before A89 the earlier tables were already rewritten when the run failed
        before = self.xml_snapshot()
        self.edit_ddl('ack_known', 'ack_known_bad : abap.unknowntype(3);\n  ack_known')
        core = os.path.join(self.root, 'ddic', 'core', 'zcd_ops_run.tabl.ddl')
        with open(core, encoding='utf-8') as fh:
            text = fh.read()
        with open(core, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text.replace("@EndUserText.label : '", "@EndUserText.label : 'Changed ", 1))
        result = self.run_serializer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('ack_known_bad', result.stdout)
        self.assertEqual(self.xml_snapshot(), before)

    def test_unknown_index_field_writes_nothing(self):
        before = self.xml_snapshot()
        self.edit_ddl('// @index BDT', '// @index ZZZ: MANDT, NO_SUCH_FIELD\n// @index BDT')
        result = self.run_serializer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('NO_SUCH_FIELD', result.stdout)
        self.assertEqual(self.xml_snapshot(), before)

    def test_unchanged_run_is_byte_identical(self):
        before = self.xml_snapshot()
        result = self.run_serializer()
        self.assertEqual(result.returncode, 0)
        self.assertIn('0 file(s) written/updated', result.stdout)
        self.assertEqual(self.xml_snapshot(), before)

    def test_unique_index_is_serialized(self):
        xml = self.read(FMON_XML)
        self.assertIn('<DD12V>', xml)
        self.assertIn('<INDEXNAME>REF</INDEXNAME>', xml)
        self.assertIn('<UNIQUEFLAG>X</UNIQUEFLAG>', xml)
        ref = xml[xml.index('<INDEXNAME>REF</INDEXNAME>'):]
        self.assertLess(ref.index('<FIELDNAME>MANDT</FIELDNAME>'), ref.index('<FIELDNAME>BUSINESS_DATE</FIELDNAME>'))
        # DD12V/DD17V follow DD03P_TABLE (abapGit lcl_tabl_xml order)
        self.assertLess(xml.index('</DD03P_TABLE>'), xml.index('<DD12V>'))
        self.assertLess(xml.index('</DD12V>'), xml.index('<DD17V>'))

    def test_table_without_marker_has_no_index_xml(self):
        xml = self.read(os.path.join('src', 'fmon', 'zcd_fmon_src.tabl.xml'))
        self.assertNotIn('DD12V', xml)

    def test_only_changed_table_is_rewritten(self):
        other = os.path.join(self.root, 'src', 'fmon', 'zcd_fmon_src.tabl.xml')
        mtime = os.stat(other).st_mtime_ns
        self.edit_ddl("@EndUserText.label : '", "@EndUserText.label : 'X ")
        result = self.run_serializer()
        self.assertEqual(result.returncode, 0)
        self.assertIn('1 file(s) written/updated', result.stdout)
        self.assertEqual(os.stat(other).st_mtime_ns, mtime)
        self.assertFalse(filecmp.cmp(os.path.join(SUITE, FMON_XML), os.path.join(self.root, FMON_XML), shallow=False))

    def test_dcls_is_serialized(self):
        # access control: name from the file, description from @EndUserText.label (dashboard DCL)
        src = os.path.join(self.root, 'src', 'fmon', 'zc_cd_fixture.dcls.asdcls')
        with open(src, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write("@EndUserText.label: 'Fixture role'\n@MappingRole: true\n"
                     "define role ZC_CD_Fixture { grant select on ZC_CD_FmonFlow\n"
                     "  where ( PaymentEngineArea ) = aspect pfcg_auth( ZCD_OPS, ZCD_PE_AREA, ACTVT = '03' ); }\n")
        result = self.run_serializer()
        self.assertEqual(result.returncode, 0)
        xml = self.read(os.path.join('src', 'fmon', 'zc_cd_fixture.dcls.xml'))
        self.assertIn('serializer="LCL_OBJECT_DCLS"', xml)
        self.assertIn('<DCLNAME>ZC_CD_FIXTURE</DCLNAME>', xml)
        self.assertIn('<DESCRIPTION>Fixture role</DESCRIPTION>', xml)
        self.assertNotIn('define role', xml)  # the source stays in .asdcls
        # the checked-in dashboard role is serialized as well
        self.assertIn('<DCLNAME>ZC_CD_FMONFLOW</DCLNAME>',
                      self.read(os.path.join('src', 'fmon', 'zc_cd_fmonflow.dcls.xml')))


if __name__ == '__main__':
    unittest.main()
