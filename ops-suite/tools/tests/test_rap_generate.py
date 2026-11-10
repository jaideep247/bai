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
            self.assertIn(f'zcl_ca_ops_cfg_injector=>{call}', self.text)

    def test_permission_read_on_root_entity(self):
        self.assertIn('GET PERMISSIONS ONLY GLOBAL AUTHORIZATION ENTITY zr_cd_opscfgall', self.text)
        self.assertIn("VALUE 'CD_OPS'", self.text)

    def test_every_assertion_has_a_message(self):
        for call in re.findall(r'cl_abap_unit_assert=>assert_\w+\((.*?)\)\.', self.text, re.S):
            self.assertIn('msg =', call)

    def test_test_method_names_max_30(self):
        for name in re.findall(r'METHODS (\w+) FOR TESTING', self.text):
            self.assertLessEqual(len(name), 30, name)

    def test_one_include_per_app(self):
        names = {rap_generate.localize(rap_generate.bp_tests(app), app).splitlines()[1]
                 for app in rap_generate.SPEC.values()}
        self.assertEqual(len(names), len(rap_generate.SPEC))


class ActivityPerChildTest(unittest.TestCase):
    """ZCD_OPS per child entity (user 2026-11-08): create 01 on the root association, change 02 and
    delete 06 on the child (authorization master), editing the singleton with one of the three."""

    def setUp(self):
        self.app = rap_generate.SPEC['hck']
        self.app['chg'] = self.app['root'].replace('All', 'Chg')
        self.tables = [dict(table=t[0], alias=t[1], draft=t[2], singular=t[3], plural=t[4], blank_keys=t[5],
                            checks=[], fields=[dict(key=True, name='id', el='Id', type='abap.char(1)')])
                       for t in self.app['tables']]

    def test_every_child_is_authorization_master(self):
        text = rap_generate.bdef_r(self.app, self.tables)
        self.assertNotIn('authorization dependent by', text)
        self.assertEqual(text.count('authorization master ( global )'), len(self.tables) + 1)

    def test_root_create_needs_01_edit_needs_one(self):
        text = rap_generate.bp_locals(self.app, self.tables)
        for t in self.tables:
            self.assertIn(f"result-%assoc-_{t['alias']} = lcl_auth=>answer( zif_ca_ops_cfg_types=>gc_actvt-create )",
                          text)
        self.assertIn('result-%action-Edit = lcl_auth=>edit( ).', text)
        self.assertIn('->may_edit( gc_area )', text)
        self.assertIn("VALUE 'CD_HCK'", text)

    def test_child_change_02_delete_06(self):
        text = rap_generate.bp_locals(self.app, self.tables)
        self.assertEqual(text.count('result-%update = lcl_auth=>answer( zif_ca_ops_cfg_types=>gc_actvt-change )'),
                         len(self.tables))
        self.assertEqual(text.count('result-%delete = lcl_auth=>answer( zif_ca_ops_cfg_types=>gc_actvt-delete )'),
                         len(self.tables))

    def test_permission_tests_per_activity(self):
        text = rap_generate.bp_tests(self.app)
        for name in ('change_only_no_create_delete', 'create_only_no_change', 'delete_only_may_delete',
                     'no_activity_no_edit'):
            self.assertIn(f'METHODS {name} FOR TESTING.', text)
        self.assertIn(f"GET PERMISSIONS ONLY GLOBAL AUTHORIZATION ENTITY zr_cd_{self.tables[0]['alias'].lower()}", text)


class PcreCheckTemplateTest(unittest.TestCase):
    """Pattern fields of the configuration apps are validated on save as PCRE (message 418)."""

    TABLE = dict(alias='FlowPattern', fields=[dict(name='pattern', el='Pattern')])

    def test_pcre_check_calls_the_one_helper(self):
        lines = rap_generate.abap_check(self.TABLE, ('pcre', 'pattern'), 'EbsCfgAll')
        text = chr(10).join(lines)
        self.assertIn('zcl_ca_ops_util=>pcre_valid( ls_row-Pattern ) = abap_false', text)
        self.assertIn('gc_msg-pattern_invalid', text)
        self.assertIn('element = lif_c=>gc_el-pattern', text)

    def test_every_pattern_field_is_validated(self):
        expected = {('ebs', 'zcd_ebs_flow_pat', 'pattern'), ('fmon', 'zcd_fmon_iface', 'name_pattern'),
                    ('hck', 'zcd_job_step', 'jobname'), ('hck', 'zcd_hck_seqout', 'seq_pattern'),
                    ('framework', 'zca_ops_alrule', 'rule_pattern'),
                    ('framework', 'zca_ops_alrule', 'check_pattern'), ('framework', 'zca_ops_alrule', 'group1_pattern'),
                    ('framework', 'zca_ops_alrule', 'group2_pattern')}
        found = {(mod, t[0], c[1]) for mod, app in rap_generate.SPEC.items() for t in app['tables']
                 for c in t[6] if c[0] == 'pcre'}
        self.assertEqual(found, expected)


class ConditionalCheckTemplateTest(unittest.TestCase):
    """Table consolidation 2026-11-08: one table holds several kinds / usages of a row; the checks of
    a kind apply only to the rows of that kind ('when'), with messages 422-425."""

    TABLE = dict(alias='Probe', fields=[dict(name=n, el=e) for n, e in (
        ('kind', 'Kind'), ('max_minutes', 'MaxMinutes'), ('due_time', 'DueTime'), ('hbkid', 'Hbkid'),
        ('role', 'Role'), ('scope', 'Scope'))])

    def setUp(self):
        rap_generate.CONST.clear()

    def text(self, chk):
        return chr(10).join(rap_generate.abap_check(self.TABLE, chk, 'Root'))

    def test_when_values_guard_the_checks(self):
        text = self.text(('when', 'kind', 'DURATION', [('required', 'max_minutes'), ('blank', 'due_time')]))
        self.assertTrue(text.startswith('    IF zcl_ca_ops_cfg_checks=>in_list( iv_value = CONV #( ls_row-Kind )'))
        self.assertIn('iv_list  = lif_c=>gc_when-probe_kind_duration ) = abap_true.', text)
        self.assertIn('IF ls_row-MaxMinutes IS INITIAL.', text)
        self.assertIn('gc_msg-required v1 = lif_c=>gc_el-maxminutes', text)
        self.assertIn('IF ls_row-DueTime IS NOT INITIAL.', text)
        self.assertIn('gc_msg-must_be_blank v1 = lif_c=>gc_el-duetime', text)
        self.assertIn('v2 = lif_c=>gc_el-kind v3 = ls_row-Kind', text)
        self.assertTrue(text.endswith('    ENDIF.'))
        self.assertEqual(rap_generate.CONST['when']['probe_kind_duration'], 'DURATION')

    def test_when_blank_and_filled(self):
        self.assertIn('IF ls_row-Hbkid IS INITIAL.', self.text(('when', 'hbkid', rap_generate.BLANK, [])))
        self.assertIn('IF ls_row-Hbkid IS NOT INITIAL.', self.text(('when', 'hbkid', rap_generate.FILLED, [])))

    def test_enum_per_branch_has_its_own_constant(self):
        self.text(('when', 'kind', 'DEADLINE', [('enum', 'role', 'A,B')]))
        self.text(('when', 'kind', 'DURATION', [('enum', 'role', 'C')]))
        self.assertEqual(rap_generate.CONST['val']['probe_role_deadline'], 'A,B')
        self.assertEqual(rap_generate.CONST['val']['probe_role_duration'], 'C')

    def test_reserved_values_of_the_other_usage(self):
        text = self.text(('when', 'kind', 'X', [('reserved', 'role', 'LEG,CUTOFF')]))
        self.assertIn('gc_msg-value_reserved v1 = ls_row-Role', text)
        self.assertIn('= abap_true.', text)

    def test_form_is_a_whole_value_pcre(self):
        text = self.text(('when', 'kind', 'X', [('form', 'scope', '[DC].{3}')]))
        self.assertIn('zcl_ca_ops_util=>pcre_match( iv_value   = ls_row-Scope', text)
        self.assertIn('gc_msg-form_invalid', text)

    def test_one_name_two_values_is_refused(self):
        rap_generate.const('val', 'same', 'A')
        with self.assertRaises(ValueError):
            rap_generate.const('val', 'same', 'B')


if __name__ == '__main__':
    unittest.main()
