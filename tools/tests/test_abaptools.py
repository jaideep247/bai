#!/usr/bin/env python3
"""Fixture tests of the shared engines (tools/abaptools): serializer settings, separate engine
instances per profile, the shared checks (packaging, references, customer wording) and the
class purpose table. The components' own tests stay in their tools/tests folders.

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
"""
import json
import os
import re
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import abaptools  # noqa: E402
from abaptools import abapgit_serialize as ser  # noqa: E402
from abaptools import checks  # noqa: E402
from abaptools import class_purpose  # noqa: E402

HEADER = ('*&---------------------------------------------------------------------*\n'
          '*& Artifact: {name}\n*& Purpose:\n*& A fixture.\n*& Modification log:\n'
          '*& 2026-11-10 | Fixture.\n'
          '*&---------------------------------------------------------------------*\n')
TABLE = """@EndUserText.label : 'Fixture'
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_t_fix {
  key mandt : abap.clnt not null;
  key id    : abap.char(10) not null;
  created   : timestampl;
}
// @index CRE: MANDT, CREATED
"""


def write(root, rel, text):
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)


class SerializerSettingsTest(unittest.TestCase):

    def component(self, root, messages, **settings):
        cfg = {'starting_folder': '/src/', 'master_language': 'E', 'packages': {'': ['ZCA_FIX', 'Fixture']},
               'message_class': {'name': 'ZCA_FIX', 'text': 'Fixture', 'source': 'config/m.md', 'folder': ''}}
        for key, value in settings.items():
            if key in ('columns', 'truncate'):
                cfg['message_class'][key] = value
            else:
                cfg[key] = value
        write(root, 'config/repository.json', json.dumps(cfg))
        write(root, 'config/m.md', messages)
        write(root, 'ddic/zca_t_fix.tabl.ddl', TABLE)
        os.makedirs(os.path.join(root, 'src'), exist_ok=True)

    def test_two_column_messages(self):
        with tempfile.TemporaryDirectory() as root:
            self.component(root, '| 001 | First text |\n')
            stage, rows = ser.build(root)
            self.assertEqual(stage.problems, [])
            self.assertEqual(rows, [('001', 'First text')])

    def test_three_column_messages(self):
        with tempfile.TemporaryDirectory() as root:
            self.component(root, '| 001 | first | First text |\n', columns=3)
            _, rows = ser.build(root)
            self.assertEqual(rows, [('001', 'First text')])

    def test_long_message_refused_or_cut(self):
        long_text = 'x' * 80
        with tempfile.TemporaryDirectory() as root:
            self.component(root, f'| 001 | {long_text} |\n')
            stage, _ = ser.build(root)
            self.assertEqual(len(stage.problems), 1)
        with tempfile.TemporaryDirectory() as root:
            self.component(root, f'| 001 | {long_text} |\n', truncate=True)
            stage, _ = ser.build(root)
            self.assertEqual(stage.problems, [])
            msag = [t for p, t in stage.pending.items() if p.endswith('.msag.xml')][0]
            self.assertIn('<TEXT>' + 'x' * 73 + '</TEXT>', msag)

    def test_secondary_index_only_with_the_setting(self):
        with tempfile.TemporaryDirectory() as root:
            self.component(root, '| 001 | Text |\n')
            stage, _ = ser.build(root)
            xml = [t for p, t in stage.pending.items() if p.endswith('zca_t_fix.tabl.xml')][0]
            self.assertNotIn('DD12V', xml)
        with tempfile.TemporaryDirectory() as root:
            self.component(root, '| 001 | Text |\n', secondary_indexes=True)
            stage, _ = ser.build(root)
            xml = [t for p, t in stage.pending.items() if p.endswith('zca_t_fix.tabl.xml')][0]
            self.assertIn('<INDEXNAME>CRE</INDEXNAME>', xml)
            self.assertLess(xml.index('</DD03P_TABLE>'), xml.index('<DD12V>'))

    def test_abapgit_xml_path_and_ignore_list(self):
        with tempfile.TemporaryDirectory() as top:
            root = os.path.join(top, 'component')
            self.component(root, '| 001 | Text |\n', abapgit_xml='../.abapgit.xml', ignore=['/README.md'],
                           starting_folder='/component/src/')
            stage, _ = ser.build(root)
            path = os.path.join(top, '.abapgit.xml')
            self.assertIn(path, stage.pending)
            self.assertIn('<STARTING_FOLDER>/component/src/</STARTING_FOLDER>', stage.pending[path])
            self.assertNotIn('CHANGELOG', stage.pending[path])

    def test_problem_writes_nothing(self):
        with tempfile.TemporaryDirectory() as root:
            self.component(root, '| 001 | Text |\n')
            write(root, 'ddic/zca_t_bad.tabl.ddl', TABLE.replace('zca_t_fix', 'zca_t_bad')
                  .replace('created   : timestampl;', 'created timestampl;'))
            self.assertEqual(ser.main(['--check'], root), 1)
            self.assertFalse(os.path.exists(os.path.join(root, '.abapgit.xml')))


class FreshInstanceTest(unittest.TestCase):

    def test_profiles_do_not_share_settings(self):
        first = abaptools.fresh('param_definitions', 'fixture_a')
        second = abaptools.fresh('param_definitions', 'fixture_b')
        first.configure(SEED='a.clas.abap')
        second.configure(SEED='b.clas.abap')
        self.assertEqual((first.SEED, second.SEED), ('a.clas.abap', 'b.clas.abap'))

    def test_unknown_setting_is_refused(self):
        engine = abaptools.fresh('rap_generate', 'fixture')
        with self.assertRaises(KeyError):
            engine.configure(NO_SUCH_SETTING=1)


class SharedChecksTest(unittest.TestCase):

    def test_packaging_refuses_a_forbidden_folder(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, 'README.md', 'See ../consumer-x/docs/x.md\n')
            write(root, 'abaplint.json', '{"dependencies": [{"folder": "/../consumer-x/src"}]}\n')
            write(root, 'tools/x.py', "path = os.path.join('..', 'consumer-x', 'tools')\n")
            fails = checks.check_packaging(root, ('consumer-x',))
            self.assertEqual(len(fails), 3)

    def test_packaging_allows_the_change_log_the_list_and_other_folders(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, 'CHANGELOG.md', 'Extracted from consumer-x.\n')
            write(root, 'tools/checks.py', "check(root, ('consumer-x',))  # packaging: forbidden folders\n")
            write(root, 'abaplint.json', '{"dependencies": [{"folder": "/../base-framework/src"}]}\n')
            write(root, 'README.md', 'A consumer-xyz is another word; ../tools/abaptools is shared.\n')
            self.assertEqual(checks.check_packaging(root, ('consumer-x',)), [])

    def test_references_with_allowed_line(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, 'src/zcl_ca_x.clas.abap', HEADER.format(name='zcl_ca_x.clas.abap')
                  + '*& 2026-11-10 | Moved from ZCL_CD_X.\n  DATA mo TYPE REF TO zif_cd_y.\n')
            pattern = re.compile(r'\b(zif_cd_\w+|zcl_cd_\w+)', re.I)
            self.assertEqual(len(checks.check_references(root, pattern)), 2)
            allowed = re.compile(r'^\*& \d{4}-\d{2}-\d{2} \| Moved from')
            self.assertEqual(len(checks.check_references(root, pattern, allowed)), 1)

    def test_customer_terms_whole_words(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, 'config/repository.json', json.dumps({'message_class': {'source': 'config/m.md'}}))
            write(root, 'config/m.md', '| 001 | A text for Acme |\n')
            write(root, 'config/customer_terms.txt', '# terms\nAcme\n')
            write(root, 'src/zcl_ca_x.clas.abap', '" acmeline is fine\n')
            fails = checks.check_customer_terms(root)
            self.assertEqual(len(fails), 1)
            self.assertIn('m.md', fails[0])

    def terms_root(self, root, allowlist=''):
        """A component with a term list of every kind of term and the given allowlist."""
        write(root, 'config/repository.json', json.dumps({'message_class': {'source': 'config/m.md'}}))
        write(root, 'config/m.md', '| 001 | A neutral text |\n')
        write(root, 'config/customer_terms.txt', '# terms\nAcme Pay\nBASE | case, text\nZXY | prefix\n')
        write(root, 'config/allowed.txt', allowlist)

    def test_customer_terms_in_docs_and_templates(self):
        with tempfile.TemporaryDirectory() as root:
            self.terms_root(root)
            write(root, 'docs/GUIDE.md', 'Requests come from the middleware.\nThe Acme Pay refund is checked.\n')
            write(root, 'templates/model/zc_x.ddls.tpl', 'define view entity ZC_X as select from zxy_request\n')
            write(root, 'tools/tests/test_x.py', "PLANTED = 'Acme Pay'  # test fixtures plant terms on purpose\n")
            self.assertEqual(checks.check_customer_terms(root), [])  # default scope: src, texts, messages
            fails = checks.check_customer_terms(root, scopes=('.',), allowlist='config/allowed.txt')
            self.assertEqual(fails, ['docs/GUIDE.md:2: Acme Pay', 'templates/model/zc_x.ddls.tpl:1: zxy'])

    def test_customer_terms_case_and_text_flags(self):
        with tempfile.TemporaryDirectory() as root:
            self.terms_root(root)
            write(root, 'docs/GUIDE.md', 'A database, a base value and the BASEline are fine.\nSent to BASE.\n')
            write(root, 'src/zcl_ca_x.clas.abap', '    rs_x = VALUE #( BASE is_x id = 1 ).\n'
                                                   '    " the status BASE sends back\n')
            fails = checks.check_customer_terms(root, scopes=('.',))
            self.assertEqual(fails, ['docs/GUIDE.md:2: BASE', 'src/zcl_ca_x.clas.abap:2: BASE'])

    def test_customer_terms_allowlist(self):
        allow = ('# file | text | reason\n'
                 'CHANGELOG.md | moved from zxy_ops | history: the object the release replaced\n'
                 'docs/GUIDE.md | no such line | stale entry\n'
                 'docs/GUIDE.md | Acme Pay |\n')
        with tempfile.TemporaryDirectory() as root:
            self.terms_root(root, allow)
            write(root, 'CHANGELOG.md', '- Object moved from zxy_ops to the framework.\n- Later zxy_job added.\n')
            write(root, 'docs/GUIDE.md', 'The Acme Pay refund.\n')
            fails = checks.check_customer_terms(root, scopes=('.',), allowlist='config/allowed.txt')
            self.assertEqual(fails, [
                'config/allowed.txt: entry without file, text or reason: docs/GUIDE.md | Acme Pay',
                'CHANGELOG.md:2: zxy',          # the allowlisted line passes, the other line of the file not
                'docs/GUIDE.md:1: Acme Pay',    # an entry without a reason allows nothing
                'config/allowed.txt: entry matches no line with a customer word: docs/GUIDE.md | no such line'])

    def test_customer_terms_unknown_flag_refused(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, 'config/customer_terms.txt', 'Acme | exact\n')
            with self.assertRaises(ValueError):
                checks.term_rules(root)

    def test_final_and_test_class_rules(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, 'src/zcl_ca_x.clas.abap', HEADER.format(name='zcl_ca_x.clas.abap')
                  + 'CLASS zcl_ca_x DEFINITION PUBLIC CREATE PUBLIC.\nENDCLASS.\n')
            write(root, 'src/zcx_ca_x.clas.abap', HEADER.format(name='zcx_ca_x.clas.abap')
                  + 'CLASS zcx_ca_x DEFINITION PUBLIC INHERITING FROM cx_static_check.\nENDCLASS.\n')
            write(root, 'src/zcl_ca_x.clas.testclasses.abap',
                  'CLASS ltc_x DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.\n'
                  '  PRIVATE SECTION.\n    METHODS run FOR TESTING.\nENDCLASS.\n')
            self.assertEqual(checks.check_final(root), ['zcl_ca_x.clas.abap'])
            self.assertEqual(len(checks.check_test_classes(root)), 1)

    def test_runner_and_report(self):
        results = checks.run([('ok', lambda root: []), ('bad', lambda root: ['x'])], '.')
        self.assertEqual(results, {'ok': [], 'bad': ['x']})


class ClassPurposeTest(unittest.TestCase):

    HEAD = '| Area | Object | Short text (SE24) | Purpose | Own test include | Log entries |\n|---|---|---|---|---|---|\n'

    def test_table_regenerated_and_checked(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, 'src/core/zcl_ca_x.clas.abap', HEADER.format(name='zcl_ca_x.clas.abap'))
            doc = os.path.join(root, 'doc.md')
            write(root, 'doc.md', '# Objects\n\n' + self.HEAD + '| old | row |\n\nText after.\n')
            self.assertEqual(class_purpose.main(root, doc, {'core': 'CORE'}, self.HEAD, ['--check']), 1)
            self.assertEqual(class_purpose.main(root, doc, {'core': 'CORE'}, self.HEAD, []), 0)
            self.assertEqual(class_purpose.main(root, doc, {'core': 'CORE'}, self.HEAD, ['--check']), 0)
            with open(doc, encoding='utf-8') as fh:
                text = fh.read()
            self.assertIn('| CORE | ZCL_CA_X |', text)
            self.assertTrue(text.endswith('Text after.\n'))


if __name__ == '__main__':
    unittest.main()
