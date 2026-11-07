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


class PcreCheckTemplateTest(unittest.TestCase):
    """Pattern fields of the configuration apps are validated on save as PCRE (message 418)."""

    TABLE = dict(alias='FlowPattern', fields=[dict(name='pattern', el='Pattern')])

    def test_pcre_check_calls_the_one_helper(self):
        lines = rap_generate.abap_check(self.TABLE, ('pcre', 'pattern'), 'EbsCfgAll')
        text = chr(10).join(lines)
        self.assertIn('zcl_cd_ops_util=>pcre_valid( ls_row-Pattern ) = abap_false', text)
        self.assertIn('gc_msg-pattern_invalid', text)
        self.assertIn('element = lif_c=>gc_el-pattern', text)

    def test_every_pattern_field_is_validated(self):
        expected = {('ebs', 'zcd_ebs_flow_pat', 'pattern'), ('fmon', 'zcd_fmon_iface', 'name_pattern'),
                    ('hck', 'zcd_job_step', 'jobname'), ('core', 'zcd_ops_alrule', 'rule_pattern'),
                    ('core', 'zcd_ops_alrule', 'check_pattern'), ('core', 'zcd_ops_alrule', 'group1_pattern'),
                    ('core', 'zcd_ops_alrule', 'group2_pattern')}
        found = {(mod, t[0], c[1]) for mod, app in rap_generate.SPEC.items() for t in app['tables']
                 for c in t[6] if c[0] == 'pcre'}
        self.assertEqual(found, expected)


if __name__ == '__main__':
    unittest.main()



class ProductionMaintainableTest(unittest.TestCase):
    """The generator spec flag prod_create and ZIF_CD_OPS_CFG_TYPES=>GC_PROD_MAINTAINABLE name the
    same tables (RAP_Config_Apps.md 2: per-table change policy, user requirement 2026-11-07)."""

    def abap_list(self):
        path = os.path.join(rap_generate.ROOT, 'src', 'core', 'zif_cd_ops_cfg_types.intf.abap')
        text = open(path, encoding='utf-8').read()
        value = re.search(r'gc_prod_maintainable\s+TYPE\s+\w+\s+VALUE\s+`([^`]*)`', text).group(1)
        return {v.strip().lower() for v in value.split(',') if v.strip()}

    def spec_list(self):
        return {entry[0] for app in rap_generate.SPEC.values() for entry in app['tables']
                if len(entry) > 7 and entry[7].get('prod_create')}

    def test_spec_and_abap_agree(self):
        self.assertEqual(self.spec_list(), self.abap_list())

    def test_deadline_sla_calendar_alert_rules(self):
        self.assertTrue({'zcd_fmon_deadl', 'zcd_fmon_sla', 'zcd_fmon_cal', 'zcd_ops_alrule'} <= self.spec_list())

    def test_flagged_create_asks_gate_with_table(self):
        path = os.path.join(rap_generate.ROOT, 'src', 'fmon', 'zbp_r_cd_fmoncfgall.clas.locals_imp.abap')
        text = open(path, encoding='utf-8').read()
        self.assertIn('iv_table = lif_c=>gc_tab-fmondeadline', text)
        self.assertIn('result-%assoc-_FmonSource = lv_create.', text)
