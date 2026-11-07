"""Unit tests of tools/checks.py (run: python3 -m unittest discover -s tools/tests)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import checks  # noqa: E402

HEADER = ('*&---------------------------------------------------------------------*\n'
          '*& Artifact: {name}\n*& Purpose:\n*& Test.\n*& Modification log:\n'
          '*& 2026-11-07 | Initial version.\n'
          '*&---------------------------------------------------------------------*\n')


class CheckTest(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        os.makedirs(os.path.join(self.root, 'src'))

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as handle:
            handle.write(text)

    def abap(self, name, body):
        self.write(os.path.join('src', name), HEADER.format(name=name) + body)

    def test_header_missing_is_reported(self):
        self.write('src/zcl_ca_x.clas.abap', 'CLASS zcl_ca_x DEFINITION PUBLIC FINAL.\nENDCLASS.\n')
        self.assertEqual(len(checks.check_artifact_header(self.root)), 1)

    def test_header_present_passes(self):
        self.abap('zcl_ca_x.clas.abap', 'CLASS zcl_ca_x DEFINITION PUBLIC FINAL.\nENDCLASS.\n')
        self.assertEqual(checks.check_artifact_header(self.root), [])

    def test_table_name_over_16(self):
        self.write('src/zca_param_too_long.tabl.xml', '<x/>')
        self.assertEqual(len(checks.check_name_lengths(self.root)), 1)

    def test_class_name_30_passes(self):
        self.write('src/' + 'z' * 30 + '.clas.xml', '<x/>')
        self.assertEqual(checks.check_name_lengths(self.root), [])

    def test_posix_regex_is_reported(self):
        self.abap('zcl_ca_x.clas.abap', "  FIND REGEX lv_p IN lv_text.\n  x = matches( val = a regex = b ).\n")
        self.assertEqual(len(checks.check_pcre_only(self.root)), 2)

    def test_pcre_passes(self):
        self.abap('zcl_ca_x.clas.abap', "  FIND PCRE lv_p IN lv_text.\n  x = matches( val = a pcre = b ).\n")
        self.assertEqual(checks.check_pcre_only(self.root), [])

    def test_cp_comparison_is_reported(self):
        self.abap('zcl_ca_x.clas.abap', "  IF lv_a CP lv_b.\n  ENDIF.\n")
        self.assertEqual(len(checks.check_no_cp(self.root)), 1)

    def test_inline_text_is_reported(self):
        self.abap('zcl_ca_x.clas.abap', "  lv_text = 'Value is not valid'.\n")
        self.assertEqual(len(checks.check_no_inline_texts(self.root)), 1)

    def test_message_literal_is_reported(self):
        self.abap('zcl_ca_x.clas.abap', "  MESSAGE 'Hello' TYPE 'I'.\n")
        self.assertEqual(len(checks.check_no_inline_texts(self.root)), 1)

    def test_declaration_and_test_msg_pass(self):
        self.abap('zcl_ca_x.clas.abap', "  CONSTANTS lc_a TYPE string VALUE `two words`.\n")
        self.abap('zcl_ca_x.clas.testclasses.abap', "  cl_abap_unit_assert=>assert_true( act = x msg = `two words` ).\n")
        self.assertEqual(checks.check_no_inline_texts(self.root), [])

    def test_select_star_is_reported(self):
        self.abap('zcl_ca_x.clas.abap', "  SELECT * FROM t000 INTO TABLE @DATA(lt).\n")
        self.assertEqual(checks.check_no_select_star(self.root), ['zcl_ca_x.clas.abap'])

    def test_non_final_class_is_reported(self):
        self.abap('zcl_ca_x.clas.abap', 'CLASS zcl_ca_x DEFINITION PUBLIC CREATE PUBLIC.\nENDCLASS.\n')
        self.assertEqual(checks.check_final(self.root), ['zcl_ca_x.clas.abap'])

    def test_test_class_without_harmless(self):
        self.abap('zcl_ca_x.clas.testclasses.abap',
                  'CLASS ltc_x DEFINITION FINAL FOR TESTING RISK LEVEL DANGEROUS DURATION SHORT.\n'
                  '  PRIVATE SECTION.\n    METHODS run FOR TESTING.\nENDCLASS.\n')
        self.assertEqual(len(checks.check_test_classes(self.root)), 1)

    def test_messages_match_constants(self):
        self.write('config/repository.json', '{"message_class": {"source": "config/m.md"}}')
        self.write('config/m.md', '| 001 | area_unknown | Area &1 does not exist |\n')
        self.abap('zif_ca_param_types.intf.abap',
                  "  CONSTANTS:\n    BEGIN OF gc_msg,\n      area_unknown TYPE symsgno VALUE '001',\n"
                  "      name_unknown TYPE symsgno VALUE '003',\n    END OF gc_msg.\n")
        self.assertEqual(len(checks.check_messages(self.root)), 1)

    def test_repository_passes_all_checks(self):
        results = checks.run(checks.ROOT)
        self.assertEqual({k: v for k, v in results.items() if v}, {})


if __name__ == '__main__':
    unittest.main()
