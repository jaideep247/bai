"""Fixture tests for the auth_fields_defined portable check (tools/auth_checks.py)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import auth_checks  # noqa: E402

_DOC = ("# sheet\n\n## 1. Authorisation field (SU20)\n\n| Field | Data element |\n|---|---|\n"
        "| `ZCD_PE_AREA` | `ZCD_PE_AREA` |\n\n## 2. Authorisation object (SU21)\n\n"
        "| Object | Class | Fields | Text |\n|---|---|---|---|\n"
        "| `ZCD_OPS` | `ZCD` | `ACTVT`, `ZCD_PE_AREA`, `BUKRS` | ops |\n\n## 3. Roles\n")


class AuthFieldsTest(unittest.TestCase):

    def _root(self, root):
        os.makedirs(os.path.join(root, 'src', 'core'))
        os.makedirs(os.path.join(root, 'config'))
        with open(os.path.join(root, 'config', 'auth_zcd_ops.md'), 'w', encoding='utf-8') as fh:
            fh.write(_DOC)

    def _failures(self, name, code):
        with tempfile.TemporaryDirectory() as root:
            self._root(root)
            with open(os.path.join(root, 'src', 'core', name), 'w', encoding='utf-8') as fh:
                fh.write(code)
            return auth_checks.failures(root)

    def test_defined_fields_read_from_doc(self):
        with tempfile.TemporaryDirectory() as root:
            self._root(root)
            self.assertEqual(auth_checks.defined_fields(root), {'ACTVT', 'ZCD_PE_AREA', 'BUKRS'})

    def test_defined_field_is_accepted(self):
        code = ("    AUTHORITY-CHECK OBJECT zif_ca_ops_auth=>gc_object\n"
                "      ID 'ACTVT' FIELD lv_a\n      ID 'ZCD_PE_AREA' FIELD lv_b\n      ID 'BUKRS' DUMMY.\n")
        self.assertEqual(self._failures('zcl_x.clas.abap', code), [])

    def test_unknown_field_is_reported(self):
        code = ("    AUTHORITY-CHECK OBJECT 'ZCD_OPS'\n"
                "      ID 'ACTVT' FIELD lv_a\n      ID 'ZCD_MODULE' FIELD lv_b.\n")
        self.assertEqual(len(self._failures('zcl_x.clas.abap', code)), 1)

    def test_other_object_is_ignored(self):
        code = "    AUTHORITY-CHECK OBJECT 'S_TABU_NAM' ID 'ACTVT' FIELD lv_a ID 'TABLE' FIELD lv_t.\n"
        self.assertEqual(self._failures('zcl_x.clas.abap', code), [])

    def test_dcl_unknown_field_is_reported(self):
        code = ("define role X {\n  grant select on Y\n"
                "    where ( A ) = aspect pfcg_auth( ZCD_OPS, ZCD_MODULE, ACTVT = '03' );\n}\n")
        self.assertEqual(len(self._failures('x.dcls.asdcls', code)), 1)

    def test_dcl_defined_fields_accepted(self):
        code = ("// pfcg_auth( ZCD_OPS, WRONG ) in a comment\ndefine role X {\n  grant select on Y\n"
                "    where ( A, B ) = aspect pfcg_auth( ZCD_OPS, ZCD_PE_AREA, BUKRS, ACTVT = '03' );\n}\n")
        self.assertEqual(self._failures('x.dcls.asdcls', code), [])


if __name__ == '__main__':
    unittest.main()
