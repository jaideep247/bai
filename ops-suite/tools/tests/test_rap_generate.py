"""Fixture tests of the behaviour-pool test template in tools/rap_generate.py (bp_tests)."""
import os
import re
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import rap_generate  # noqa: E402  (import writes nothing: generation runs in main( ) only)


class BpTestsTemplateTest(unittest.TestCase):

    def setUp(self):
        self.text = rap_generate.bp_tests(rap_generate.SPEC['core'])

    def test_header_names_the_include(self):
        self.assertIn('*& Artifact: zbp_r_cd_opscfgall.clas.testclasses.abap', self.text)
        self.assertIn('VERIFY-ADT', self.text)

    def test_harmless_short_test_class(self):
        self.assertRegex(self.text, r'CLASS ltc_permissions DEFINITION FINAL FOR TESTING\n'
                                    r'  RISK LEVEL HARMLESS\n  DURATION SHORT\.')

    def test_gate_doubles_injected_and_reset(self):
        for call in ('inject_client', 'inject_transport', 'inject_auth', 'reset( )'):
            self.assertIn(f'zcl_cd_ops_cfg_injector=>{call}', self.text)

    def test_permission_read_on_root_entity(self):
        self.assertIn('GET PERMISSIONS ONLY GLOBAL AUTHORIZATION ENTITY zr_cd_opscfgall', self.text)
        self.assertIn("VALUE 'CORE'", self.text)

    def test_every_assertion_has_a_message(self):
        for call in re.findall(r'cl_abap_unit_assert=>assert_\w+\((.*?)\)\.', self.text, re.S):
            self.assertIn('msg =', call)

    def test_test_method_names_max_30(self):
        for name in re.findall(r'METHODS (\w+) FOR TESTING', self.text):
            self.assertLessEqual(len(name), 30, name)

    def test_one_include_per_app(self):
        names = {rap_generate.bp_tests(app).splitlines()[1] for app in rap_generate.SPEC.values()}
        self.assertEqual(len(names), len(rap_generate.SPEC))


if __name__ == '__main__':
    unittest.main()
