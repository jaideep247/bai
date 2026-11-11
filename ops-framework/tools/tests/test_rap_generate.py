#!/usr/bin/env python3
"""Tests of the framework's RAP generator profile (tools/rap_generate.py): the app is complete
and generated, every pattern field of the alert rules is validated as PCRE on save, the control register
(2026-11-10) checks owner / backup, team, runbook link and the finding field on save; the check registry of
the process onboarding (2026-11-10) checks the plug-in interface, the aggregate functions and operators, and
the table and field names of an aggregate row on save; the scheduler jobs of the SAP job monitor (2026-11-11)
check their SAP job name pattern and criticality on save; the operations response features (2026-11-11) check
the runbook link of an active runbook row, the patterns, key fields and window of a correlation rule and the
escalation severity of an alert rule on save; the link registry (2026-11-11) checks sources and fields against the
runtime DDIC, the TABLE-FIELD references and the kind-dependent fields of a condition on save.

Run:  python3 -m unittest discover -s tools/tests      (from ops-framework/)
"""
import os
import sys
import unittest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import rap_generate  # noqa: E402  (import writes nothing: generation runs in main( ) only)


class FrameworkAppTest(unittest.TestCase):

    def test_every_pattern_field_is_validated(self):
        expected = {('framework', 'zca_ops_alrule', 'rule_pattern'), ('framework', 'zca_ops_alrule', 'check_pattern'),
                    ('framework', 'zca_ops_alrule', 'group1_pattern'), ('framework', 'zca_ops_alrule', 'group2_pattern'),
                    # company-code pattern of a rule (company-code isolation, 2026-11-10)
                    ('framework', 'zca_ops_alrule', 'bukrs_pattern'),
                    # SAP job names of a scheduler job (SAP job monitor, 2026-11-11)
                    ('framework', 'zca_ops_jobsch', 'sap_pattern'),
                    # correlation rules (operations response features, 2026-11-11)
                    ('framework', 'zca_ops_corr', 'check_pattern'), ('framework', 'zca_ops_corr', 'key_pattern')}
        found = {(mod, t[0], c[1]) for mod, app in rap_generate.SPEC.items() for t in app['tables']
                 for c in t[6] if c[0] == 'pcre'}
        self.assertEqual(found, expected)

    def test_app_is_the_framework_one(self):
        self.assertEqual(list(rap_generate.SPEC), ['framework'])
        app = rap_generate.SPEC['framework']
        self.assertEqual(app['prefix'], 'ca')
        self.assertEqual(app['service'], 'ZUI_CA_OPS_CFG')
        self.assertNotIn('base', app)  # generated into this folder, never from another component

    def test_tables_are_framework_tables(self):
        tables = [t[0] for t in rap_generate.SPEC['framework']['tables']]
        self.assertEqual(tables, ['zca_ops_alrule', 'zca_ops_alchn', 'zca_ops_purge',
                                  'zca_ops_control', 'zca_ops_ctlt', 'zca_ops_ctlchk',
                                  'zca_ops_proc', 'zca_ops_check', 'zca_ops_agg', 'zca_ops_tabwl',
                                  'zca_ops_pmdim', 'zca_ops_feeder', 'zca_ops_jobsch',
                                  'zca_ops_runbook', 'zca_ops_corr', 'zca_ops_lnklyr', 'zca_ops_lnkobj',
                              'zca_ops_lnkfld', 'zca_ops_link', 'zca_ops_lnkcnd', 'zca_ops_lnkact',
                              'zca_ops_catpkg', 'zca_ops_catprc', 'zca_ops_catstp', 'zca_ops_cattab',
                              'zca_ops_catdep', 'zca_ops_catact'])

    def test_payment_model_tables_checked_on_save(self):
        checks = {t[0]: t[6] for t in rap_generate.SPEC['framework']['tables']}
        self.assertIn(('enum', 'dimension', 'FLOW,SOURCE,TRANSACTION,REQ_STATUS,PAY_STATUS,METHOD_CLASS,DOC_EVENT'),
                      checks['zca_ops_pmdim'])
        self.assertIn(('valid', 'url_template', 'zcl_ca_ops_cfg_checks=>url_valid', 'url_invalid'),
                      checks['zca_ops_feeder'])

    def test_scheduler_jobs_checked_on_save(self):
        checks = {t[0]: t[6] for t in rap_generate.SPEC['framework']['tables']}
        self.assertIn(('pcre', 'sap_pattern'), checks['zca_ops_jobsch'])
        self.assertIn(('enum', 'criticality', 'H,M,L'), checks['zca_ops_jobsch'])

    def test_check_registry_checked_on_save(self):
        checks = {t[0]: t[6] for t in rap_generate.SPEC['framework']['tables']}
        self.assertIn(('class', 'class_name', 'ZIF_CA_OPS_CHECK'), checks['zca_ops_check'])
        self.assertIn(('enum', 'agg_func', 'COUNT,AGE'), checks['zca_ops_agg'])
        self.assertIn(('enum', 'status_op', ',EQ,NE,IN,NI'), checks['zca_ops_agg'])
        self.assertIn(('table', 'tabname'), checks['zca_ops_agg'])
        fields = {c[1] for c in checks['zca_ops_agg'] if c[0] == 'field'}
        self.assertEqual(fields, {'date_field', 'time_field', 'bukrs_field', 'status_field', 'cond_field'})
        self.assertIn(('table', 'table_name'), checks['zca_ops_tabwl'])
        for table in ('zca_ops_proc', 'zca_ops_check', 'zca_ops_agg', 'zca_ops_tabwl'):
            self.assertIn(('area', 'area', False), checks[table])

    def test_process_catalogue_checked_on_save(self):
        checks = {t[0]: t[6] for t in rap_generate.SPEC['framework']['tables']}
        self.assertIn(('enum', 'pkg_kind', 'S,I,C'), checks['zca_ops_catpkg'])
        self.assertIn(('enum', 'step_kind', 'T,P,M,J,E'), checks['zca_ops_catstp'])
        self.assertIn(('valid', 'approved_by', 'zcl_ca_ops_cfg_checks=>approver_valid', 'approver_invalid'),
                      checks['zca_ops_catact'])
        self.assertIn(('when', 'valid_from', rap_generate.FILLED, [('required', 'reason'), ('required', 'pkg_id'),
                                                        ('required', 'approved_by')]), checks['zca_ops_catact'])
        self.assertIn(('when', 'evidence', 'C', [('table', 'tabname')]), checks['zca_ops_cattab'])

    def test_control_register_checked_on_save(self):
        checks = {t[0]: t[6] for t in rap_generate.SPEC['framework']['tables']}
        valid = {(c[1], c[2]) for c in checks['zca_ops_control'] if c[0] == 'valid'}
        self.assertEqual(valid, {('owner', 'zcl_ca_ops_cfg_checks=>user_valid'),
                                 ('backup', 'zcl_ca_ops_cfg_checks=>user_valid'),
                                 ('team', 'zcl_ca_ops_cfg_checks=>team_valid'),
                                 ('runbook_url', 'zcl_ca_ops_cfg_checks=>url_valid')})
        self.assertIn(('enum', 'match_field', 'RULE_ID,CHECK_CODE,GROUP2'), checks['zca_ops_ctlchk'])

    def test_response_features_checked_on_save(self):
        checks = {t[0]: t[6] for t in rap_generate.SPEC['framework']['tables']}
        # an active runbook row needs its link; a seed row with the placeholder is saved inactive
        self.assertIn(('when', 'active', 'X',
                       [('valid', 'runbook_url', 'zcl_ca_ops_cfg_checks=>link_valid', 'url_invalid')]),
                      checks['zca_ops_runbook'])
        self.assertIn(('enum', 'match_field', 'RULE_ID,CHECK_CODE,GROUP2'), checks['zca_ops_runbook'])
        valid = {(c[1], c[3]) for c in checks['zca_ops_corr'] if c[0] == 'valid'}
        self.assertEqual(valid, {('key_fields', 'corr_fields_invalid'), ('window_min', 'corr_window_invalid')})
        self.assertIn(('enum', 'esc_severity', ',B,E,W,I'), checks['zca_ops_alrule'])

    def test_link_registry_checked_on_save(self):
        checks = {t[0]: t[6] for t in rap_generate.SPEC['framework']['tables']}
        # sources and fields against the runtime DDIC, condition references TABLE-FIELD, kind-dependent fields
        self.assertIn(('table', 'source_name'), checks['zca_ops_lnkobj'])
        self.assertIn(('field', 'field_name', 'source_name'), checks['zca_ops_lnkfld'])
        self.assertIn(('when', 'evidence', 'V', [('required', 'verify_ref')]), checks['zca_ops_lnkfld'])
        refs = {c[1] for c in checks['zca_ops_lnkcnd'] if c[0] == 'valid' and c[3] == 'link_ref_invalid'}
        self.assertEqual(refs, {'from_ref', 'to_ref'})
        self.assertIn(('enum', 'cardinality', '11,1N,N1,NM'), checks['zca_ops_link'])
        bp = open(os.path.join(rap_generate.ROOT, 'src', 'ui', 'zbp_r_ca_opscfgall.clas.locals_imp.abap'),
                  encoding='utf-8').read()
        self.assertIn('zcl_ca_ops_cfg_checks=>field_ref_valid', bp)


if __name__ == '__main__':
    unittest.main()
