#!/usr/bin/env python3
"""Extension and release-gate proof (build Q, ops-framework/docs/EXTENSION_AND_GATE_PROOF.md).

The fictitious customer XX adds an intake flow and its payment reference by configuration only:
- the generators (link registry, extensions, payment model) run on the XX folder ops-framework/examples/intake_xx and
  write into that folder only; every output is current;
- the product's payment trace (generated payment model: payment -> request link, request page) and one product view
  (the exceptions list, CDS extension) show XX's request reference;
- a "to one" link whose conditions do not cover the identity of its target (feeder system, company code, payment
  reference) is ambiguous by design: refused without a reason, listed in the lineage, joined in the n:m section of the
  payment model only, and an extension on it renders a candidates view - its columns stay blank with the marker
  AMBIGUOUS when several rows are candidates;
- no product source names an XX intake object; the house check customer_terms stays green;
- with an abaplint binary (environment ABAPLINT_BIN) the generated XX sources compile against the product.

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
Modification log:
2026-11-16 | Initial version (build Q: extension and release-gate proof).
"""
import copy
import importlib.util
import csv
import io
import json
import os
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, 'tools'))
sys.path.insert(0, os.path.join(REPO, 'ops-framework', 'tools'))
import abaptools  # noqa: E402
import intake_xx  # noqa: E402

FW = os.path.join(REPO, 'ops-framework')
XX = os.path.join(FW, 'examples', 'intake_xx')
LR = abaptools.fresh('link_registry', 'proof_test')
EXT = abaptools.fresh('extensions', 'proof_test')
PAYM = abaptools.fresh('payment_model', 'proof_test')


def _read(rel):
    with open(os.path.join(XX, rel), encoding='utf-8') as handle:
        return handle.read()


def _overlay():
    with open(intake_xx.OVERLAY, encoding='utf-8') as handle:
        return json.load(handle)


def _registry(spec):
    reg = LR.Registry()
    for path in LR.PRODUCT_LAYERS:
        with open(path, encoding='utf-8') as handle:
            reg.add(json.load(handle), path)
    reg.add(spec, 'xx')
    return reg


class ExtensionProofTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.files = intake_xx.outputs(XX)

    # ---------------------------------------------------------------- configuration only
    def test_generators_write_into_the_xx_folder_only(self):
        for rel in self.files:
            self.assertFalse(os.path.isabs(rel) or os.path.normpath(rel).startswith('..'), rel)
        for rel in ('src/ext/zxx_x_exc_c.ddls.asddls', 'src/paym/zi_xx_paymreqlink.ddls.asddls',
                    'src/paym/zc_xx_paymrequest.ddls.asddls', 'config/links/seed/zca_ops_lnkobj.csv',
                    'config/extensions/pending/zxx_xc_brk_group_intake.ddls.asddls', 'docs/links/lineage.md'):
            self.assertIn(rel, self.files)

    def test_outputs_are_current(self):
        self.assertEqual(intake_xx.check_generated(XX), [])

    def test_seed_rows_are_the_customer_layer_only(self):
        rows = list(csv.DictReader(io.StringIO(self.files['config/links/seed/zca_ops_lnkobj.csv'])))
        self.assertTrue(rows)
        self.assertTrue(all(r['LAYER_ID'] == 'XX' for r in rows))
        intake = next(r for r in rows if r['OBJECT_ID'] == 'XX_INTAKE')
        self.assertEqual(intake['IDENTITY_FIELDS'], 'LOGSYS,BUKRS,PAY_REF')
        fields = list(csv.DictReader(io.StringIO(self.files['config/links/seed/zca_ops_lnkfld.csv'])))
        self.assertIn(('FICA_OPEN_ITEM', 'ZZXX_PAYREF', 'XX'),
                      {(r['OBJECT_ID'], r['FIELD_NAME'], r['LAYER_ID']) for r in fields})

    # ---------------------------------------------------------------- the request reference is shown
    def test_payment_trace_links_the_payment_to_the_intake(self):
        link = self.files['src/paym/zi_xx_paymreqlink.ddls.asddls']
        # the join is rendered from registry link XX_ITEM_TO_INTAKE (custom field on the standard item)
        self.assertIn('inner join zxx_intake as Ink on  Ink.pay_ref = Itm.zzxx_payref', link)
        self.assertIn('and Ink.bukrs   = Itm.bukrs', link)
        self.assertIn('cast( Ink.intake_id as abap.char( 40 ) ) as RequestReference', link)
        self.assertIn('XX_ITEM_TO_INTAKE is ambiguous by design', link)
        request = self.files['src/paym/zi_xx_paymreqfact.ddls.asddls']
        self.assertIn('cast( Ink.pay_ref as abap.char( 40 ) ) as FeederReference', request)
        self.assertIn('Ink.logsys as Source', request)
        page = self.files['src/paym/zc_xx_paymrequest.ddls.asddls']
        for element in ('RequestReference', 'FeederReference', 'Source'):
            self.assertIn(element, page)

    def test_product_view_shows_the_intake(self):
        ext = self.files['src/ext/zxx_x_exc_c.ddls.asddls']
        self.assertIn('extend view entity ZC_CA_OpsException with', ext)
        self.assertIn("$projection.ObjectType = 'XXINTK'", ext)
        self.assertIn('_ZZXXIntake.pay_ref as ZZXX_IntakePayRef', ext)

    # ---------------------------------------------------------------- identity and ambiguity
    def test_lineage_lists_the_links_ambiguous_by_design(self):
        lineage = self.files['docs/links/lineage.md']
        self.assertIn('## Ambiguous by design', lineage)
        for link in ('XX_ITEM_TO_INTAKE', 'XX_GLITEM_TO_INTAKE', 'XX_ITEM_TO_REQ'):
            self.assertRegex(lineage, r'\| ' + link + r' \| XX \|')

    def test_uncovered_identity_without_reason_is_refused(self):
        spec = _overlay()
        link = next(x for x in spec['links'] if x['id'] == 'XX_ITEM_TO_INTAKE')
        del link['ambiguity']
        problems = LR.validate(_registry(spec))
        self.assertTrue(any('XX_ITEM_TO_INTAKE' in p and 'ambiguous by design' in p and 'LOGSYS' in p
                            for p in problems), problems)

    def test_covered_identity_needs_no_reason(self):
        spec = _overlay()
        intake = next(o for o in spec['objects'] if o['id'] == 'XX_INTAKE')
        intake['identity'] = ['BUKRS', 'PAY_REF']
        problems = LR.validate(_registry(spec))
        self.assertTrue(any('XX_ITEM_TO_INTAKE' in p and 'remove the ambiguity' in p for p in problems), problems)

    def test_prefer_does_not_make_a_link_to_one(self):
        spec = _overlay()
        link = next(x for x in spec['links'] if x['id'] == 'XX_ITEM_TO_REQ')
        del link['ambiguity']
        problems = LR.validate(_registry(spec))
        self.assertTrue(any('XX_ITEM_TO_REQ' in p and 'PREFER' in p for p in problems), problems)

    def test_identity_field_must_be_declared(self):
        spec = _overlay()
        intake = next(o for o in spec['objects'] if o['id'] == 'XX_INTAKE')
        intake['identity'] = ['LOGSYS', 'GJAHR']
        problems = LR.validate(_registry(spec))
        self.assertTrue(any('identity field GJAHR is not a field' in p for p in problems), problems)

    def test_ambiguous_extension_is_blank_with_a_marker(self):
        ext = self.files['config/extensions/pending/zxx_x_brkgrp_r.ddls.asddls']
        self.assertIn('association [0..1] to ZXX_XC_BRK_GROUP_INTAKE as _ZZXXGrpIntake', ext)
        self.assertIn('case when _ZZXXGrpIntake.Candidates = 1 then _ZZXXGrpIntake.logsys end as ZZXX_GrpIntakeFeeder',
                      ext)
        self.assertIn("case when _ZZXXGrpIntake.Candidates > 1 then 'AMBIGUOUS' else ' ' end", ext)
        candidates = self.files['config/extensions/pending/zxx_xc_brk_group_intake.ddls.asddls']
        self.assertIn('count( * ) as Candidates', candidates)
        self.assertIn('group by Cnd.pay_ref, Cnd.bukrs', candidates)
        # the projection passes the marker on
        self.assertIn('ZZXX_GrpIntakeMatch', self.files['config/extensions/pending/zxx_x_brkgrp_c.ddls.asddls'])

    def test_ambiguous_extension_needs_its_marker(self):
        pack, exts = EXT.load_pack(os.path.join(XX, 'config', 'extensions'))
        reg, problems = EXT.pack_registry(XX, pack)
        self.assertEqual(problems, [])
        broken = copy.deepcopy(exts)
        for ext in broken:
            ext.pop('ambiguity_element', None)
        problems, _ = EXT.analyse(pack, broken, EXT.load_inventory(), reg)
        self.assertTrue(any('XX_BRK_GROUP_INTAKE' in p and 'ambiguity_element' in p for p in problems), problems)

    def test_ambiguous_link_only_in_the_n_to_m_section(self):
        spec = PAYM.load(os.path.join(XX, intake_xx.PAYMENT_MODEL))
        spec['request']['from'] = 'dfkkop as Itm'
        spec['request']['joins'] = [{'link': 'XX_ITEM_TO_INTAKE', 'join': 'inner join', 'alias': 'Ink',
                                     'from_alias': 'Itm'}]
        with self.assertRaises(PAYM.SpecError) as err:
            PAYM.outputs(XX, spec)
        self.assertIn('ambiguous by design', str(err.exception))

    # ---------------------------------------------------------------- no product object edited
    def test_no_product_source_names_the_xx_intake(self):
        self.assertEqual(intake_xx.check_neutral(FW, XX), [])

    def test_customer_terms_stay_green(self):
        # the framework's house checks, loaded by path (another component's checks.py may be imported already)
        spec = importlib.util.spec_from_file_location('ops_framework_checks_proof', os.path.join(FW, 'tools', 'checks.py'))
        checks = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checks)
        self.assertEqual(checks.check_customer_terms(FW), [])

    @unittest.skipUnless(os.environ.get('ABAPLINT_BIN'), 'no abaplint binary (set ABAPLINT_BIN)')
    def test_xx_sources_compile_against_the_product(self):
        self.assertEqual(intake_xx.check_abaplint(os.environ['ABAPLINT_BIN'], XX), [])


if __name__ == '__main__':
    unittest.main()
