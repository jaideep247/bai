#!/usr/bin/env python3
"""Tests of the link registry engine (tools/abaptools/link_registry.py): the product layers of the framework and the
worked example of a customer overlay (prefix XX) are valid; every validation rule refuses what it must (an active
link on a VERIFY field, a cyclic or branching fallback chain, a "to one" link without the target's keys, a sensitive
field as a constant, a replacement of the same layer, a wrong ID prefix, a reference to a higher layer, a transform
without its argument, a value with a quote, an unknown field, a field the repository's DDIC metadata does not know);
replacement and activation overrides; seed rows (pending rows left out, columns = the DDL of the registry tables);
CDS rendering (compact and column layout); the migration parity of the suite's payment model (the joins rendered from
the registry are exactly the text joins the mapping held before the migration); the payment model generator refuses
a pending or unknown link; impact and lineage of the suite.

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
"""
import copy
import importlib.util
import json
import os
import re
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from abaptools import link_registry as lr  # noqa: E402
from abaptools import payment_model  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FRAMEWORK = os.path.join(REPO, 'ops-framework')
SUITE = os.path.join(REPO, 'ops-suite')
EXAMPLE = os.path.join(FRAMEWORK, 'config', 'links', 'examples', 'xx_overlay.json')
OVERLAY = os.path.join(SUITE, 'config', 'links', 'overlay.json')

# The joins of the suite's mapping spec before the migration to the registry (git 1fc0349) - the parity baseline
BEFORE = {
    'payment': [
        "left outer join I_CompanyCode      as Cc  on  Cc.CompanyCode  = Pay.CompanyCode",
        "left outer join ZI_CD_PayMethodCls as McC on  McC.Flow        = 'C'",
        "                                          and McC.PaymentMethod = Pay.PaymentMethod",
        "left outer join ZI_CD_PayMethodCls as McD on  McD.Flow        = 'D'",
        "                                          and McD.PaymentMethod = Pay.PaymentMethod",
        "left outer join ZI_CD_PayWorkState as Ws  on  Ws.ClearingDoc  = Pay.PaymentDocument"],
    'ledger_item': ["inner join dfkkko as Clr on Clr.opbel = Op.augbl"],
    'recon_bank_line': [
        "inner join zcd_ebs_acct as Acct on  Acct.account_no = Line.PeAccount",
        "                                and Acct.active     = 'X'",
        "left outer join dfkkko as Clr on Clr.opbel = Line.BankReference"],
}


def wrapper(component):
    """The component's wrapper module (tools/link_registry.py) with its profile."""
    path = os.path.join(REPO, component, 'tools', 'link_registry.py')
    spec = importlib.util.spec_from_file_location(f'link_registry_{component.replace("-", "_")}', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def example():
    return lr.load(lr.PRODUCT_LAYERS + [EXAMPLE])


def text_of(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def spec_of(path):
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def registry_with(overlay):
    reg = lr.Registry()
    for path in lr.PRODUCT_LAYERS:
        reg.add(spec_of(path), path)
    reg.add(overlay, 'test overlay')
    return reg


class ComponentTest(unittest.TestCase):

    def test_framework_layers_valid_and_outputs_current(self):
        module = wrapper('ops-framework')
        self.assertEqual(module._engine.check(FRAMEWORK, module.PROFILE), [])

    def test_suite_overlay_valid_and_outputs_current(self):
        module = wrapper('ops-suite')
        self.assertEqual(module._engine.check(SUITE, module.PROFILE), [])

    def test_product_layers_are_standard_only(self):
        reg = lr.load(lr.PRODUCT_LAYERS)
        self.assertEqual({layer['kind'] for layer in reg.layers.values()}, {'S', 'I'})
        for obj in reg.objects.values():
            self.assertFalse(obj['source'].upper().startswith(('Z', 'Y')), obj['id'])
        for (_, name), _fld in reg.fields.items():
            self.assertFalse(name.startswith(('ZZ', 'YY')), name)

    def test_example_validates_with_the_product(self):
        self.assertEqual(lr.validate(example()), [])


class RulesTest(unittest.TestCase):

    def setUp(self):
        self.overlay = spec_of(EXAMPLE)

    def problems(self):
        return '\n'.join(lr.validate(registry_with(self.overlay)))

    def link(self, link_id):
        return next(x for x in self.overlay['links'] if x['id'] == link_id)

    def test_active_link_on_verify_field_refused(self):
        self.overlay['fields'][0]['evidence'] = 'V'
        self.overlay['fields'][0]['verify'] = 'V999'
        self.assertIn('XX_REQ_TO_ITEMS: active, but to field FICA_OPEN_ITEM-ZZXX_REQ_ID is VERIFY', self.problems())

    def test_verify_field_needs_its_item(self):
        self.overlay['fields'][0]['evidence'] = 'V'
        self.assertIn('names its VERIFY item', self.problems())

    def test_cyclic_fallback_refused(self):
        self.link('XX_REQ_TO_PARTNER_FDR')['fallback_of'] = 'XX_REQ_TO_PARTNER'
        self.assertIn('fallback chain is cyclic', self.problems())

    def test_branching_fallback_refused(self):
        extra = copy.deepcopy(self.link('XX_REQ_TO_PARTNER'))
        extra['id'] = 'XX_REQ_TO_PARTNER_TWO'
        self.overlay['links'].append(extra)
        self.assertIn('more than one fallback', self.problems())

    def test_to_one_needs_target_keys(self):
        self.link('XX_ITEM_TO_REQ')['conditions'].pop()  # the PREFER condition
        self.assertIn('cardinality N1 needs the key fields of XX_PAY_REQUEST', self.problems())

    def test_sensitive_constant_refused(self):
        self.link('XX_REQ_TO_PARTNER')['conditions'].append({'kind': 'CONST', 'to': 'BPEXT', 'value': '4711'})
        self.assertIn('sensitive field BPEXT as a constant', self.problems())

    def test_replacement_of_same_layer_refused(self):
        clone = copy.deepcopy(self.link('XX_REQ_TO_ITEMS'))
        clone['id'] = 'XX_REQ_TO_ITEMS_NEW'
        clone['replaces'] = 'XX_REQ_TO_ITEMS'
        self.overlay['links'].append(clone)
        self.assertIn('only a link of a lower layer can be replaced', self.problems())

    def test_id_prefix_enforced(self):
        self.link('XX_REQ_TO_ITEMS')['id'] = 'YY_REQ_TO_ITEMS'
        self.assertIn('must start with the layer prefix XX_', self.problems())

    def test_lower_layer_cannot_use_customer_field(self):
        reg = registry_with(self.overlay)
        reg.links['FICA_HDR_TO_ITEMS']['conditions'].append({'kind': 'EQ', 'from': 'OPBEL', 'to': 'ZZXX_REQ_ID'})
        self.assertIn('belongs to a higher layer (XX)', '\n'.join(lr.validate(reg)))

    def test_transform_needs_argument(self):
        self.link('XX_PAYMENT_TO_STMT_LINE')['conditions'][0]['transform'] = 'RIGHT'
        self.assertIn('RIGHT needs a length 1-99', self.problems())

    def test_value_with_quote_refused(self):
        self.link('XX_ITEM_TO_REQ')['conditions'][1]['value'] = "OK' OR '1' = '1"
        self.assertIn('contains a quote or a statement character', self.problems())

    def test_unknown_field_refused(self):
        self.link('XX_REQ_TO_ITEMS')['conditions'][0]['to'] = 'NO_SUCH_FIELD'
        self.assertIn('to field NO_SUCH_FIELD is not a field of FICA_OPEN_ITEM', self.problems())

    def test_ddic_metadata_checked(self):
        ddic = {'ZXX_PAY_REQ': {'REQ_ID', 'ATTEMPT', 'FEEDER', 'STATUS'}}
        problems = '\n'.join(lr.validate(registry_with(self.overlay), ddic))
        self.assertIn('field XX_PAY_REQUEST-MEMBER_ID: not a field of ZXX_PAY_REQ', problems)

    def test_pending_link_must_stay_inactive(self):
        self.link('XX_REQ_TO_ITEMS')['conditions'][0]['from'] = '‹request field›'
        self.overlay['objects'][0]['fields'].append({'name': '‹request field›', 'evidence': 'V', 'verify': 'V999'})
        self.assertIn('XX_REQ_TO_ITEMS: active, but from field', self.problems())


class EffectTest(unittest.TestCase):

    def test_replacement_resolves_to_customer_link(self):
        reg = example()
        self.assertEqual(reg.resolve('FICA_PAYMENT_TO_STMT_LINE')['id'], 'XX_PAYMENT_TO_STMT_LINE')
        self.assertEqual(reg.status(reg.links['FICA_PAYMENT_TO_STMT_LINE']), 'replaced by XX_PAYMENT_TO_STMT_LINE')

    def test_activation_override_switches_off(self):
        reg = example()
        self.assertEqual(reg.status(reg.links['FICA_PAYMENT_TO_NOC']), 'switched off (XX)')
        self.assertEqual(reg.status(reg.links['FICA_HDR_TO_ITEMS']), 'active')

    def test_fallback_chain_in_order(self):
        chain = lr.chains(example())['XX_REQ_TO_PARTNER_FDR']
        self.assertEqual([x['id'] for x in chain], ['XX_REQ_TO_PARTNER_FDR', 'XX_REQ_TO_PARTNER'])

    def test_layer_switched_off(self):
        overlay = spec_of(EXAMPLE)
        overlay['activation'].append({'kind': 'L', 'id': 'FICA', 'active': False, 'reason': 'test'})
        reg = registry_with(overlay)
        self.assertEqual(reg.status(reg.links['FICA_HDR_TO_ITEMS']), 'layer off')
        self.assertEqual(reg.resolve('FICA_PAYMENT_TO_STMT_LINE')['id'], 'XX_PAYMENT_TO_STMT_LINE')


class SeedTest(unittest.TestCase):

    def test_columns_are_the_ddl_fields(self):
        for table, columns in lr.TABLES:
            text = text_of(os.path.join(FRAMEWORK, 'ddic', f'{table}.tabl.ddl'))
            body = re.sub(r'//[^\n]*', '', text).split('{', 1)[1].split('}', 1)[0]
            fields = [f.upper() for f in re.findall(r'^\s*(?:key\s+)?([a-z_0-9]+)\s*:', body, re.M)]
            fields = [f for f in fields if f not in ('MANDT', 'LAST_CHANGED_BY', 'LAST_CHANGED_AT',
                                                     'LOCAL_LAST_CHANGED_AT')]
            self.assertEqual(columns, fields, table)

    def test_pending_rows_not_seeded(self):
        reg = lr.load(lr.PRODUCT_LAYERS + [OVERLAY])
        rows = lr.seed_rows(reg, ['CD'])
        links = {row[0] for row in rows['zca_ops_link']}
        self.assertNotIn('CD_ITEM_TO_REQUEST', links)  # FIN number field still a placeholder (V82)
        self.assertIn('CD_CHEQUE_TO_STATUS_HIST', links)  # named field, inactive until SE11 (V121)
        for table_rows in rows.values():
            for row in table_rows:
                self.assertFalse(any(lr.PLACEHOLDER.search(str(value)) for value in row), row)

    def test_condition_rows_carry_table_field(self):
        reg = example()
        rows = lr.seed_rows(reg, ['XX'])['zca_ops_lnkcnd']
        self.assertIn(['XX_REQ_TO_ITEMS', '001', 'EQ', 'ZXX_PAY_REQ-REQ_ID', 'DFKKOP-ZZXX_REQ_ID', '', '', ''], rows)
        self.assertIn(['XX_PAYMENT_TO_STMT_LINE', '001', 'EQ', 'DFKKOP-AUGBL', 'FEBEP-CHECT', '', 'NOZERO', ''], rows)


class RenderTest(unittest.TestCase):

    def test_compact_join(self):
        reg = example()
        self.assertEqual(lr.render_join(reg, 'FICA_ITEM_TO_CLEARING_HDR', 'inner join', 'Clr', 'Op'),
                         ['inner join dfkkko as Clr on Clr.opbel = Op.augbl'])

    def test_replacement_rendered_with_transform(self):
        reg = example()
        self.assertEqual(lr.render_join(reg, 'FICA_PAYMENT_TO_STMT_LINE', 'left outer join', 'Ln', 'Op'),
                         ["left outer join febep as Ln on Ln.chect = ltrim( Op.augbl, '0' )"])

    def test_layout_columns(self):
        reg = example()
        lines = lr.render_join(reg, 'FICA_HDR_TO_ITEMS', 'left outer join', 'It', 'Hd',
                               {'source': 8, 'alias': 3, 'left': 10})
        self.assertEqual(lines, ['left outer join dfkkop   as It  on  It.opbel   = Hd.opbel'])

    def test_pending_link_not_rendered(self):
        reg = lr.load(lr.PRODUCT_LAYERS + [OVERLAY])
        with self.assertRaises(lr.RegistryError):
            lr.render_join(reg, 'CD_ITEM_TO_REQUEST', 'inner join', 'Req', 'Op')


class PaymentModelParityTest(unittest.TestCase):
    """Migration of the payment model's link parts: the registry renders exactly the former text joins."""

    def test_registry_joins_equal_the_former_text_joins(self):
        spec = payment_model.load(os.path.join(SUITE, 'config', 'payment_model', 'mapping.json'))
        reg = payment_model.registry(SUITE, spec)
        for section, before in BEFORE.items():
            rendered = []
            for join in spec[section]['joins']:
                if isinstance(join, dict):
                    rendered += lr.render_join(reg, join['link'], join['join'], join['alias'], join['from_alias'],
                                               spec[section].get('join_layout'))
            self.assertEqual(rendered, before, section)
            # and in the order of the section: the generated view has every former line in place
            self.assertTrue(set(before) <= set(payment_model.join_lines(spec, section, reg)), section)

    def test_text_joins_need_no_registry(self):
        spec = {'model': {}, 'payment': {'joins': ['inner join zxx_a as A on A.k = Src.k']}}
        self.assertIsNone(payment_model.registry(REPO, spec))

    def test_pending_link_refused(self):
        spec = payment_model.load(os.path.join(SUITE, 'config', 'payment_model', 'mapping.json'))
        spec['ledger_item']['joins'] = [{'link': 'CD_ITEM_TO_REQUEST', 'join': 'inner join', 'alias': 'Req',
                                         'from_alias': 'Op'}]
        with self.assertRaises(payment_model.SpecError):
            payment_model.outputs(SUITE, spec)

    def test_registry_join_keys_checked(self):
        spec = payment_model.load(os.path.join(SUITE, 'config', 'payment_model', 'mapping.json'))
        spec['ledger_item']['joins'] = [{'link': 'FICA_ITEM_TO_CLEARING_HDR', 'alias': 'Clr'}]
        with self.assertRaises(payment_model.SpecError):
            payment_model.validate(spec)


class DocumentsTest(unittest.TestCase):

    def test_suite_impact_names_payment_model_and_links(self):
        text = text_of(os.path.join(SUITE, 'docs', 'links', 'impact.md'))
        row = next(line for line in text.splitlines() if line.startswith('| DFKKOP-AUGBL |'))
        self.assertIn('payment model ledger_item (active): join FICA_ITEM_TO_CLEARING_HDR', row)
        self.assertIn('FICA_PAYMENT_TO_STMT_LINE (from, active)', row)

    def test_suite_lineage_shows_custom_field_flow(self):
        text = text_of(os.path.join(SUITE, 'docs', 'links', 'lineage.md'))
        self.assertIn('| DFKKOP-ZZ_FIN_TRANS_NUM | CD | CD_ITEM_TO_REQUEST (pending (VERIFY))', text)
        self.assertIn('```mermaid', text)


if __name__ == '__main__':
    unittest.main()
