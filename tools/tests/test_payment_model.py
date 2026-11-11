#!/usr/bin/env python3
"""Tests of the payment model generator (tools/abaptools/payment_model.py): a fictitious customer (prefix PE,
tables ZPE_*, two feeder systems) maps the product contract; active sections are generated into the package,
pending ones into the pending folder and left out of the service, the DCL and the navigation; the spec is
refused when it breaks the contract; --check reports a hand-edited or superfluous file; the suite's own spec
(ops-suite/config/payment_model/mapping.json) is valid and its generated files are up to date.

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
"""
import copy
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from abaptools import checks  # noqa: E402
from abaptools import payment_model  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def fields(section, overrides=None):
    out = {}
    for name, *_ in payment_model.CONTRACT[section]:
        out[name] = {'expr': f'Src.{name.lower()}'}
    out.update(overrides or {})
    return out


def spec():
    return {
        'model': {'prefix': 'PE', 'area': 'ZPE_OPS', 'areas': ['ZPE_OPS'], 'consumer': 'example customer',
                  'service': 'ZUI_PE_PAYM', 'package_folder': 'src/paym', 'pending_folder': 'pending',
                  'since': '2026-11-11', 'window_days': 40, 'trend_days': 30, 'peak_day_min': 500000,
                  'intents': {'trace': ['ZPETrace', 'display'], 'exceptions': ['ZPEExc', 'manage'],
                              'job': ['ZPEJob', 'display']}},
        'payment': {'from': 'zpe_payment as Src', 'fields': fields('payment', {
            'TransactionType': {'expr': None, 'verify': 'not delivered by the payment system'}})},
        'payment_request': {'from': 'zpe_pay_req as Src', 'fields': fields('payment_request')},
        'request': {'from': 'zpe_request as Src', 'fields': fields('request')},
        'request_attempt': {'status': 'pending', 'reason': 'attempt table not yet named',
                            'from': '‹attempt table› as Src', 'fields': fields('request_attempt')},
    }


def ledger_spec():
    """The fictitious customer with the ledger and document-change sections (all active)."""
    out = spec()
    out['model']['ledger'] = {'area': 'ZPE_OPS', 'parameter': 'ZPE_LEDGER', 'default': '0L'}
    out['model']['gl_reference_type'] = 'ZPEGL'
    for section in ('ledger_item', 'ledger_batch', 'recon_account', 'recon_result', 'recon_bank_line',
                    'document_event'):
        out[section] = {'from': f'zpe_{section} as Src', 'fields': fields(section)}
    return out


class PaymentModelTest(unittest.TestCase):

    def test_active_sections_generated_into_the_package(self):
        files = payment_model.outputs(REPO, spec())
        names = {os.path.basename(p) for p in files if p.startswith('src/paym')}
        for name in ('zi_pe_paymfact.ddls.asddls', 'zr_pe_paymcube.ddls.asddls', 'zc_pe_payment.ddlx.asddlxs',
                     'zr_pe_paymrequest.ddls.asddls', 'zc_pe_paym.dcls.asdcls', 'zui_pe_paym.srvd.srvdsrv',
                     'zcl_pe_paym_cds_test.clas.testclasses.abap', 'package.devc.xml'):
            self.assertIn(name, names)
        self.assertNotIn('zr_pe_paymattempt.ddls.asddls', names)

    def test_pending_section_waits_outside_the_package(self):
        files = payment_model.outputs(REPO, spec())
        pending = {os.path.basename(p) for p in files if p.startswith('pending')}
        self.assertEqual(pending, {'zi_pe_paymattempt.ddls.asddls', 'zr_pe_paymattempt.ddls.asddls',
                                   'zc_pe_paymattempt.ddls.asddls'})
        service = files[os.path.join('src/paym', 'zui_pe_paym.srvd.srvdsrv')]
        self.assertIn('expose ZC_PE_PaymRequest as PaymentRequest;', service)
        self.assertNotIn('PaymAttempt', service)
        request = files[os.path.join('src/paym', 'zr_pe_paymrequest.ddls.asddls')]
        self.assertNotIn('_Attempts', request)

    def test_null_field_is_a_typed_blank_with_its_note(self):
        fact = payment_model.outputs(REPO, spec())[os.path.join('src/paym', 'zi_pe_paymfact.ddls.asddls')]
        self.assertIn("cast( '' as abap.char( 20 ) ) as TransactionType", fact)
        self.assertIn('// TransactionType: not delivered by the payment system', fact)
        self.assertIn("@Semantics.amount.currencyCode: 'Currency'\n      Src.amount as Amount", fact)

    def test_dcl_covers_every_exposed_entity(self):
        files = payment_model.outputs(REPO, spec())
        dcl = files[os.path.join('src/paym', 'zc_pe_paym.dcls.asdcls')]
        for entity in ('ZC_PE_PaymCube', 'ZC_PE_PaymTrend', 'ZC_PE_Payment', 'ZC_PE_PaymReqLink',
                       'ZC_PE_PaymRequest', 'ZC_PE_PaymExcTrend'):
            self.assertIn(f'grant select on {entity}\n', dcl)

    def test_contract_breaches_are_refused(self):
        broken = copy.deepcopy(spec())
        del broken['payment']['fields']['Currency']
        broken['payment']['fields']['PaymentRun'] = {'expr': None, 'verify': 'x'}
        broken['payment_request']['fields']['CompanyCode'] = {'expr': 'Src.bukrs; drop'}
        broken['request']['fields']['Source'] = {'expr': '‹source field›'}
        with self.assertRaises(payment_model.SpecError) as err:
            payment_model.validate(broken)
        text = str(err.exception)
        self.assertIn('Currency not mapped', text)
        self.assertIn('PaymentRun is required and cannot be null', text)
        self.assertIn('contains ;', text)
        self.assertIn('placeholder - the section must be pending', text)

    def test_attempts_need_an_active_request(self):
        broken = copy.deepcopy(spec())
        broken['request_attempt']['status'] = 'active'
        broken['request_attempt']['from'] = 'zpe_attempt as Src'
        broken['request']['status'] = 'pending'
        broken['request']['reason'] = 'waiting'
        with self.assertRaises(payment_model.SpecError):
            payment_model.validate(broken)

    def test_check_reports_edited_and_superfluous_files(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, 'cfg'))
            import json
            with open(os.path.join(root, 'cfg', 'spec.json'), 'w', encoding='utf-8') as handle:
                json.dump(spec(), handle)
            payment_model.generate(root, os.path.join('cfg', 'spec.json'))
            self.assertEqual(payment_model.check(root, os.path.join('cfg', 'spec.json')), [])
            cube = os.path.join(root, 'src', 'paym', 'zr_pe_paymcube.ddls.asddls')
            with open(cube, 'a', encoding='utf-8') as handle:
                handle.write('// hand edit\n')
            extra = os.path.join(root, 'src', 'paym', 'zi_pe_old.ddls.asddls')
            with open(extra, 'w', encoding='utf-8') as handle:
                handle.write('old\n')
            stale = payment_model.check(root, os.path.join('cfg', 'spec.json'))
            self.assertIn(os.path.join('src', 'paym', 'zr_pe_paymcube.ddls.asddls'), stale)
            self.assertIn(os.path.join('src', 'paym', 'zi_pe_old.ddls.asddls'), stale)

    # ------------------------------------------------------------ ledger and document-change model (2026-11-11)

    def test_ledger_sections_generate_the_ledger_views(self):
        files = payment_model.outputs(REPO, ledger_spec())
        names = {os.path.basename(p) for p in files if p.startswith('src/paym')}
        for name in ('zi_pe_ledgitem.ddls.asddls', 'zi_pe_ledgbatch.ddls.asddls', 'zi_pe_ledgcfg.ddls.asddls',
                     'zi_pe_ledgjrnl.ddls.asddls', 'zr_pe_ledgbatch.ddls.asddls', 'zr_pe_paymledger.ddls.asddls',
                     'zc_pe_paymledger.ddlx.asddlxs', 'zr_pe_ledgrecon.ddls.asddls', 'zi_pe_ledgrccube.ddls.asddls',
                     'zc_pe_ledgrcqry.ddls.asddls', 'zr_pe_ledgbankln.ddls.asddls', 'zr_pe_paymchange.ddls.asddls',
                     'zr_pe_reqchange.ddls.asddls', 'zc_pe_docevtcube.ddlx.asddlxs'):
            self.assertIn(name, names)
        service = files[os.path.join('src/paym', 'zui_pe_paym.srvd.srvdsrv')]
        for alias in ('PaymentLedger', 'SubledgerBatch', 'SubledgerItem', 'JournalLine', 'LedgerReconciliation',
                      'BankStatementLine', 'PaymentChange', 'RequestChange', 'DocumentChangeCategory'):
            self.assertIn(f' as {alias};', service)
        dcl = files[os.path.join('src/paym', 'zc_pe_paym.dcls.asdcls')]
        for entity in ('ZC_PE_PaymLedger', 'ZC_PE_LedgJrnl', 'ZC_PE_LedgRecon', 'ZI_PE_LedgRcCube'):
            self.assertIn(f'grant select on {entity}\n', dcl)

    def test_ledger_parameter_and_reference_type(self):
        files = payment_model.outputs(REPO, ledger_spec())
        cfg = files[os.path.join('src/paym', 'zi_pe_ledgcfg.ddls.asddls')]
        self.assertIn("Def.name = 'ZPE_LEDGER'", cfg)
        self.assertIn("where Area.area = 'ZPE_OPS'", cfg)
        self.assertIn("'0L' ) as abap.char( 2 ) ) as Ledger", cfg)
        gl_doc = files[os.path.join('src/paym', 'zi_pe_ledggldoc.ddls.asddls')]
        self.assertIn("Doc.awtyp = 'ZPEGL'", gl_doc)
        self.assertIn('Doc.awkey = Bat.GlReferenceKey', gl_doc)

    def test_payment_page_has_ledger_and_changes(self):
        files = payment_model.outputs(REPO, ledger_spec())
        payment = files[os.path.join('src/paym', 'zr_pe_payment.ddls.asddls')]
        self.assertIn('as _Ledger   on $projection.PaymentDocument = _Ledger.PaymentDocument', payment)
        self.assertIn('as _Changes  on $projection.PaymentDocument = _Changes.PaymentDocument', payment)
        ddlx = files[os.path.join('src/paym', 'zc_pe_payment.ddlx.asddlxs')]
        self.assertIn("targetElement: '_Ledger', label: 'Ledger'", ddlx)
        self.assertIn("targetElement: '_Changes', label: 'Changes'", ddlx)
        # without the sections the payment page is unchanged
        plain = payment_model.outputs(REPO, spec())[os.path.join('src/paym', 'zr_pe_payment.ddls.asddls')]
        self.assertNotIn('as _Ledger', plain)
        self.assertNotIn('as _Changes', plain)

    def test_stored_results_and_bank_lines_optional(self):
        lean = ledger_spec()
        del lean['recon_result']
        lean['recon_bank_line'] = {'status': 'pending', 'reason': 'statement fields not confirmed',
                                   'from': '‹statement view› as Src', 'fields': fields('recon_bank_line')}
        files = payment_model.outputs(REPO, lean)
        recon = files[os.path.join('src/paym', 'zr_pe_ledgrecon.ddls.asddls')]
        self.assertNotIn('ResultStatus', recon)
        self.assertNotIn('as _BankLines', recon)
        self.assertIn('else 2 end as abap.int1 )', recon)
        pending = {os.path.basename(p) for p in files if p.startswith('pending')}
        self.assertIn('zr_pe_ledgbankln.ddls.asddls', pending)
        self.assertIn('zi_pe_ledgbankday.ddls.asddls', pending)

    def test_ledger_needs_its_model_keys(self):
        broken = ledger_spec()
        del broken['model']['ledger']
        broken['model']['gl_reference_type'] = 'zpe gl'
        del broken['ledger_batch']
        with self.assertRaises(payment_model.SpecError) as err:
            payment_model.validate(broken)
        text = str(err.exception)
        self.assertIn('ledger area missing', text)
        self.assertIn('is not a plain name', text)
        self.assertIn('ledger_item: active only with an active ledger_batch section', text)
        self.assertIn('recon_account: active only with an active ledger_batch section', text)

    def test_else_branch_of_a_flag(self):
        text = '#if A\na\n#else\nnot a\n#endif\n#if B\n#if A\nab\n#else\nb only\n#endif\n#endif'
        self.assertEqual(payment_model.render(text, {}, {'A': False, 'B': True}), 'not a\nb only\n')
        self.assertEqual(payment_model.render(text, {}, {'A': True, 'B': False}), 'a\n')

    def test_product_layer_free_of_customer_terms(self):
        # the framework's term list (with its flags) plus the FI-CA tables and fields a template must not
        # name: the subledger is the customer's mapping (prefixes: DFKKOP, DFKKKO, ... all refused)
        rules = checks.term_rules(os.path.join(REPO, 'ops-framework'))
        rules += [(t, {'prefix'}) for t in ('DFKK', 'DPAYH', 'FIKEY', 'FKKSU', 'STBEL')]
        matchers = checks.term_matchers(rules)
        targets = [os.path.join(payment_model.TEMPLATES, name) for name in os.listdir(payment_model.TEMPLATES)]
        targets.append(payment_model.__file__)
        hits = []
        for path in targets:
            with open(path, encoding='utf-8') as handle:
                for no, line in enumerate(handle, start=1):
                    found = checks.find_term(line, matchers)
                    if found:
                        hits.append(f'{os.path.basename(path)}:{no}: {found}')
        self.assertEqual(hits, [])

    def test_suite_spec_valid_and_generated_up_to_date(self):
        root = os.path.join(REPO, 'ops-suite')
        spec_path = os.path.join('config', 'payment_model', 'mapping.json')
        payment_model.validate(payment_model.load(os.path.join(root, spec_path)))
        self.assertEqual(payment_model.check(root, spec_path), [])


if __name__ == '__main__':
    unittest.main()
