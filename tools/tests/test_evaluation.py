#!/usr/bin/env python3
"""Tests of the evaluation state, the period-close rule, the monitor coverage and the delivery confirmation of the
operations framework (ops-framework/docs/EVALUATION_AND_COVERAGE.md, build O): every scenario of the offline fixture
spec ops-framework/config/evaluation/fixtures.json gives its expected result through the reference model
tools/abaptools/evaluation.py (the rules of ZCL_CA_OPS_EVAL, ZCL_CA_OPS_EVAL_PERIOD, ZCL_CA_OPS_COVERAGE and
ZCL_CA_OPS_ALERT_CONFIRM); every scenario names an existing FOR TESTING method of its class; the codes of the model
are those of ZIF_CA_OPS_EVAL_TYPES and of the domains of ddic/dictionary.json (fixed values <= 10 characters, texts
from DD07L / DD07T); every result class and every coverage state is covered by a scenario; and the wiring is there
(the optional TY_RESULT-EVAL, the runner deriving and saving one record per check, the cash checks and the payment
file check folding their own vocabulary, no core object naming an object of the pack FICA_CASH). The same scenarios
run on a system later (VERIFY V285).

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
"""
import json
import os
import re
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, 'tools'))
from abaptools import evaluation as model  # noqa: E402

FRAMEWORK = os.path.join(REPO, 'ops-framework')
SRC = os.path.join(FRAMEWORK, 'src')
SPEC = os.path.join(FRAMEWORK, 'config', 'evaluation', 'fixtures.json')
TYPES = os.path.join(SRC, 'zif_ca_ops_eval_types.intf.abap')
DICTIONARY = os.path.join(FRAMEWORK, 'ddic', 'dictionary.json')


def _read(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def _constants(block):
    match = re.search(r'BEGIN OF ' + block + r',(.*?)END OF ' + block + r'\.', _read(TYPES), re.S)
    return [v for v in re.findall(r"VALUE '([^']*)'", match.group(1))] if match else []


def _test_include(class_name):
    name = class_name.lower() + '.clas.testclasses.abap'
    for root, _, files in os.walk(SRC):
        if name in files:
            return _read(os.path.join(root, name))
    return None


class EvaluationSpecTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.spec = json.loads(_read(SPEC))

    def _all(self):
        for kind in ('evaluation', 'period', 'coverage', 'delivery'):
            for scenario in self.spec[kind]:
                yield kind, scenario

    def test_ids_unique_and_named_tests_exist(self):
        seen = set()
        for kind, scenario in self._all():
            self.assertNotIn(scenario['id'], seen, scenario['id'])
            seen.add(scenario['id'])
            class_name, method = scenario['abap_unit'].split('=>')
            include = _test_include(class_name)
            self.assertIsNotNone(include, f'{scenario["id"]}: no test include of {class_name}')
            self.assertRegex(include, r'(?im)^\s*METHODS\s+' + re.escape(method.lower()) + r'\s+FOR TESTING',
                             f'{scenario["id"]}: {scenario["abap_unit"]} is not a FOR TESTING method')

    def test_evaluation_scenarios(self):
        for scenario in self.spec['evaluation']:
            result = model.derive(scenario['given'])
            for key, expected in scenario['expect'].items():
                self.assertEqual(result[key], expected, f'{scenario["id"]} {scenario["title"]}: {key}')

    def test_unknown_is_never_green(self):
        for scenario in self.spec['evaluation']:
            result = model.derive(scenario['given'])
            if result['completeness'] != 'C':
                self.assertTrue(model.is_unknown(result['state']), scenario['id'])
                self.assertNotIn(result['state'], ('OK', 'ZERO_OK', 'HOLIDAY'), scenario['id'])

    def test_period_scenarios(self):
        for scenario in self.spec['period']:
            self.assertEqual(model.period_closed(scenario['entries'], scenario['area'], scenario['period'],
                                                 scenario['bukrs_list']), scenario['closed'], scenario['id'])

    def test_coverage_scenarios(self):
        for scenario in self.spec['coverage']:
            self.assertEqual(model.coverage_state(scenario['given']), scenario['expect'], scenario['id'])

    def test_delivery_scenarios(self):
        for scenario in self.spec['delivery']:
            self.assertEqual(model.delivery_state(scenario['answer']), scenario['expect'], scenario['id'])
            self.assertNotEqual(model.delivery_state(''), 'D', 'no answer is never delivered')

    def test_every_class_and_state_covered(self):
        classes = {s['expect']['class'] for s in self.spec['evaluation'] if 'class' in s['expect']}
        self.assertEqual(classes, set(model.STATES) - {'PARTIAL'})
        states = {s['expect']['state'] for s in self.spec['evaluation']}
        self.assertIn('PARTIAL', states)
        self.assertEqual({s['expect'] for s in self.spec['coverage']}, set(model.COVERAGE))


class EvaluationCodesTest(unittest.TestCase):

    def test_states_are_the_interface_constants(self):
        self.assertEqual(set(_constants('gc_state')), set(model.STATES))
        self.assertEqual(set(_constants('gc_cmpl')), set(model.COMPLETENESS))
        self.assertEqual(set(_constants('gc_cov')), set(model.COVERAGE))
        self.assertEqual(set(_constants('gc_dlv')) - {' '}, {'P', 'D', 'F', 'N'})

    def test_domains_match_and_fit_dd07l(self):
        domains = {d['name']: [v[0] for v in d['values']] for d in json.loads(_read(DICTIONARY))['domains']}
        self.assertEqual(set(domains['ZCA_OPS_EVAL_STATE']), set(model.STATES))
        self.assertEqual(set(domains['ZCA_OPS_EVAL_CMPL']), set(model.COMPLETENESS))
        self.assertEqual(set(domains['ZCA_OPS_COV_STATE']), set(model.COVERAGE))
        self.assertEqual(set(domains['ZCA_OPS_DLV_STATE']), {'P', 'D', 'F', 'N'})
        for name in ('ZCA_OPS_EVAL_STATE', 'ZCA_OPS_EVAL_CMPL', 'ZCA_OPS_COV_STATE', 'ZCA_OPS_DLV_STATE'):
            for value in domains[name]:
                self.assertLessEqual(len(value), 10, f'{name} {value}: DOMVALUE_L holds 10 characters')

    def test_k_and_n_vocabulary_mapped(self):
        types = _read(os.path.join(SRC, 'zif_ca_ops_pf_types.intf.abap'))
        day = re.search(r'BEGIN OF gc_day,(.*?)END OF gc_day\.', types, re.S).group(1)
        for value in re.findall(r"VALUE '([^']*)'", day):
            self.assertIn(value, model.TERMS, f'day result {value} of build K not mapped')
        cash = _read(os.path.join(SRC, 'cash', 'zif_ca_ops_cash_types.intf.abap'))
        evaluation = re.search(r'BEGIN OF gc_evaluation,(.*?)END OF gc_evaluation\.', cash, re.S).group(1)
        for value in re.findall(r"VALUE '([^']*)'", evaluation):
            self.assertIn(value, model.TERMS, f'evaluation {value} of build N not mapped')


class EvaluationWiringTest(unittest.TestCase):

    def test_result_part_is_optional(self):
        chk = _read(os.path.join(SRC, 'zif_ca_ops_chk_types.intf.abap'))
        self.assertIn('eval       TYPE zif_ca_ops_eval_types=>ty_check_eval', chk)

    def test_runner_records_every_check(self):
        runner = _read(os.path.join(SRC, 'zcl_ca_ops_check_runner.clas.abap'))
        self.assertIn('zcl_ca_ops_eval=>derive(', runner)
        self.assertEqual(runner.count('zcl_ca_ops_eval=>not_run('), 2, 'licence refused and process off')
        self.assertIn('get_eval_dao( )->save( lt_eval )', runner)

    def test_modules_fold_their_vocabulary(self):
        ctx = _read(os.path.join(SRC, 'cash', 'zcl_ca_ops_cash_ctx.clas.abap'))
        self.assertIn('zcl_ca_ops_eval=>merge_term(', ctx)
        for name in ('clear', 'ebs', 'glkey', 'paylot', 'payrun', 'return'):
            text = _read(os.path.join(SRC, 'cash', f'zcl_ca_ops_chk_cash_{name}.clas.abap'))
            self.assertEqual(text.count('rs_result-evidence = mo_ctx->evidence( ).'),
                             text.count('rs_result-eval = mo_ctx->eval( ).'), name)
        payfile = _read(os.path.join(SRC, 'zcl_ca_ops_chk_payfile.clas.abap'))
        self.assertIn('zcl_ca_ops_eval=>merge_term(', payfile)

    def test_core_names_no_cash_object(self):
        for name in os.listdir(SRC):
            if (name.startswith(('zcl_ca_ops_eval', 'zif_ca_ops_eval', 'zcl_ca_ops_coverage', 'zcl_ca_ops_chk_coverage',
                                 'zcl_ca_ops_alert_confirm', 'zcl_ca_ops_chk_alert_dlv', 'zif_ca_ops_dlv_reader'))
                    and name.endswith('.abap')):
                text = _read(os.path.join(SRC, name)).lower()
                self.assertNotIn('zcl_ca_ops_cash', text, name)
                self.assertNotIn('zif_ca_ops_cash', text, name)
                self.assertNotIn('zcl_ca_ops_pf_', text, name)

    def test_email_never_guesses_delivery(self):
        email = _read(os.path.join(SRC, 'zcl_ca_ops_chn_email.clas.abap'))
        method = email[email.index('METHOD zif_ca_ops_alert_channel~confirm.'):]
        method = method[:method.index('ENDMETHOD.')]
        self.assertNotIn('gc_dlv-delivered', method, 'e-mail delivery only through a verified reader')


if __name__ == '__main__':
    unittest.main()
