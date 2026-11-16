#!/usr/bin/env python3
"""Tests of the customer extension engine (tools/abaptools/extensions.py): the inventory of extension points matches
the product (annotations, anchors, documents, no other extensible view, the generated matrix); the worked example of
a fictitious second customer (XX) and the ops suite's pack are valid and up to date with zero framework change; every
generator rule refuses what it must (point, anchor, a "to many" link, a link from another object, a field the anchor
does not provide, a key object of another layer or with an unmapped key, an unknown or hidden field, a masked field
declared weaker, prefixes of IDs, elements and associations, the quota, optional views and their sources); statuses
(active, pending on an inactive link / VERIFY field / placeholder / declared item, blocked); rendering (key and link
anchors, discriminator, PREFER as a filter, masking, a replacement link, the query copy, the element suffix switch);
and that no product file of the framework references a customer object.
Build Q (2026-11-16): a link ambiguous by design (its conditions do not cover the identity of the target) needs a
marker element and reads a candidates view - PREFER is a filter of the candidates, the columns are blank unless one
row is a candidate; a covered link renders PREFER in the ON condition as before.

Run:  python3 -m unittest discover -s tools/tests      (from the repository root)
"""
import copy
import os
import re
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from abaptools import checks as shared  # noqa: E402
from abaptools import extensions as ex  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FRAMEWORK = os.path.join(REPO, 'ops-framework')
SUITE = os.path.join(REPO, 'ops-suite')
EXAMPLE = 'config/extensions/examples/xx'
FRAMEWORK_PROFILE = {
    'inventory': 'config/extension_points.json', 'doc': 'docs/EXTENDING_WITH_CUSTOMER_DATA.md',
    'examples': [{'pack': EXAMPLE, 'doc': 'docs/extensions/example_xx.md',
                  'title': 'Worked example - extensions of the fictitious customer XX'}]}
MOVED = re.compile(r'\| Moved from Z\w+ to the reusable framework ZCA_OPS')
SUITE_PROFILE = {'pack': 'config/extensions', 'title': 'Extensions of the ops suite on the framework views'}


def read(path):
    with open(path, encoding='utf-8', errors='ignore') as handle:
        return handle.read()


def write(path, text):
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(text)


def example():
    pack, exts = ex.load_pack(os.path.join(FRAMEWORK, EXAMPLE))
    reg, problems = ex.pack_registry(FRAMEWORK, pack)
    assert problems == [], problems
    return pack, {e['id']: e for e in exts}, reg


class InventoryTest(unittest.TestCase):

    def test_inventory_matches_the_product(self):
        self.assertEqual(ex.check_inventory(FRAMEWORK, ex.load_inventory()), [])

    def test_framework_profile_up_to_date(self):
        self.assertEqual(ex.check(FRAMEWORK, FRAMEWORK_PROFILE), [])

    def test_every_cds_point_has_a_base_and_an_anchor(self):
        for pt in ex.cds_points(ex.load_inventory()):
            self.assertEqual(pt['views'][0]['role'], 'base', pt['id'])
            self.assertTrue(pt['anchors'], pt['id'])

    def test_matrix_lists_every_point(self):
        inv = ex.load_inventory()
        text = ex.matrix(inv)
        for pt in inv['points']:
            self.assertIn(f'`{pt["id"]}`', text)

    def drift(self, change):
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, 'ops-framework')
            shutil.copytree(FRAMEWORK, root, ignore=shutil.ignore_patterns('__pycache__'))
            os.symlink(os.path.join(REPO, 'tools'), os.path.join(tmp, 'tools'))
            change(root)
            return '\n'.join(ex.check_inventory(root, ex.load_inventory()))

    def test_unlisted_extensible_view_refused(self):
        def change(root):
            path = os.path.join(root, 'src', 'ui', 'zc_ca_opsjobfailure.ddls.asddls')
            text = read(path)
            write(path, '@AbapCatalog.extensibility.extensible: true\n' + text)
        self.assertIn('zc_ca_opsjobfailure.ddls.asddls: extensible but not a view of', self.drift(change))

    def test_missing_annotation_refused(self):
        def change(root):
            path = os.path.join(root, 'src', 'ui', 'zr_ca_opsbrkgroup.ddls.asddls')
            text = read(path)
            write(path, text.replace("@AbapCatalog.extensibility.dataSources: [ 'Grp' ]\n",
                                                                 ''))
        self.assertIn("lacks the annotation \"@AbapCatalog.extensibility.dataSources: [ 'Grp' ]\"", self.drift(change))

    def test_renamed_anchor_element_refused(self):
        def change(root):
            path = os.path.join(root, 'src', 'ui', 'zc_ca_opsctlreview.ddls.asddls')
            text = read(path)
            write(path, text.replace('ControlId', 'CtlId'))
        self.assertIn('point CTL_REVIEW / CONTROL: ZC_CA_OpsCtlReview has no element ControlId', self.drift(change))

    def test_document_must_mention_the_object(self):
        def change(root):
            path = os.path.join(root, 'docs', 'CONTROL_REVIEW.md')
            text = read(path)
            write(path, text.replace('ZC_CA_OpsCtlReview', 'the review view'))
        self.assertIn('point CTL_REVIEW: document docs/CONTROL_REVIEW.md does not mention ZC_CA_OpsCtlReview',
                      self.drift(change))


class PackTest(unittest.TestCase):

    def setUp(self):
        self.inv = ex.load_inventory()
        self.pack, self.exts, self.reg = example()

    def run_one(self, ext):
        problems, results = ex.analyse(self.pack, [ext], self.inv, self.reg)
        return '\n'.join(problems), (results[0] if results else None)

    def ext(self, ext_id):
        return copy.deepcopy(self.exts[ext_id])

    def test_example_statuses(self):
        problems, results = ex.analyse(self.pack, list(self.exts.values()), self.inv, self.reg)
        self.assertEqual(problems, [])
        status = {r['id']: r['status'] for r in results}
        self.assertEqual(status, {'XX_CTL_AUDIT_REF': 'active', 'XX_EXC_REQUEST': 'active',
                                  'XX_FLOW_STAGE_SLA': 'active', 'XX_FLOW_STAGE_TEAM': 'active',
                                  'XX_BRK_GROUP_REQ': 'pending', 'XX_BRK_LINE_CASE': 'blocked'})

    def test_example_needs_no_framework_change(self):
        """The example lives only in example folders: no product source, dictionary or template names it."""
        names = {'ZXX_X_', 'ZC_XX_'}
        for ext in self.exts.values():
            names |= {f.get('element', '') for f in ext.get('fields', [])} | {ext.get('association') or ''}
        names |= {self.reg.objects[o]['source'] for o in ('XX_REQUEST', 'XX_CTL_REGISTER', 'XX_STAGE_SLA')}
        names.discard('')
        pattern = re.compile(r'\b(' + '|'.join(re.escape(n) for n in sorted(names)) + r')', re.I)
        for top in ('src', 'ddic', 'templates'):
            for folder, _, files in os.walk(os.path.join(FRAMEWORK, top)):
                for name in files:
                    text = read(os.path.join(folder, name))
                    self.assertIsNone(pattern.search(text), os.path.join(folder, name))

    def test_key_anchor_renders_all_keys_and_the_discriminator(self):
        _, res = self.run_one(self.ext('XX_EXC_REQUEST'))
        self.assertEqual(res['on'], ['_ZZXXRequest.req_id = $projection.ObjectKey',
                                     "$projection.ObjectType = 'XXREQ'"])
        self.assertEqual(res['target'], 'zxx_request')

    def test_masked_field_rendered_masked(self):
        _, res = self.run_one(self.ext('XX_EXC_REQUEST'))
        member = next(e for e in res['elements'] if e['name'] == 'ZZXX_Member')
        self.assertEqual(member['expr'], "concat( '****', right( _ZZXXRequest.member_id, 4 ) )")

    def test_masked_field_declared_weaker_refused(self):
        ext = self.ext('XX_EXC_REQUEST')
        ext['fields'][2]['sensitivity'] = ''
        self.assertIn('MEMBER_ID is masked (M) in the registry - declare it M', self.run_one(ext)[0])

    def test_hidden_field_refused(self):
        ext = self.ext('XX_EXC_REQUEST')
        ext['fields'][0]['sensitivity'] = 'H'
        self.assertIn('FEEDER is hidden (H) - a hidden field is never added', self.run_one(ext)[0])

    def test_unknown_field_refused(self):
        ext = self.ext('XX_EXC_REQUEST')
        ext['fields'][0]['field'] = 'NO_SUCH'
        self.assertIn('NO_SUCH is not a registry field of XX_REQUEST', self.run_one(ext)[0])

    def test_unmapped_key_refused(self):
        ext = self.ext('XX_CTL_AUDIT_REF')
        del ext['keys']['AREA']
        self.assertIn('key field AREA of XX_CTL_REGISTER is not mapped', self.run_one(ext)[0])

    def test_key_mapped_to_a_non_anchor_element_refused(self):
        ext = self.ext('XX_CTL_AUDIT_REF')
        ext['keys']['AREA'] = 'CompanyCode'
        self.assertIn('CompanyCode is not an element of anchor CONTROL', self.run_one(ext)[0])

    def test_key_object_of_another_layer_refused(self):
        ext = self.ext('XX_CTL_AUDIT_REF')
        ext['object'] = 'FICA_DOC_HEADER'
        ext['keys'] = {'OPBEL': 'ControlId'}
        self.assertIn('FICA_DOC_HEADER is not of the customer layer XX', self.run_one(ext)[0])

    def test_discriminator_required(self):
        ext = self.ext('XX_EXC_REQUEST')
        del ext['discriminator']
        self.assertIn('needs the value of ObjectType', self.run_one(ext)[0])

    def test_unknown_point_and_anchor_refused(self):
        ext = self.ext('XX_EXC_REQUEST')
        ext['point'] = 'CHECK_ROW'
        self.assertIn("'CHECK_ROW' is not a CDS extension point", self.run_one(ext)[0])
        ext = self.ext('XX_EXC_REQUEST')
        ext['anchor'] = 'STAGE'
        self.assertIn("anchor 'STAGE' is not an anchor of EXC", self.run_one(ext)[0])

    def test_prefixes_refused(self):
        ext = self.ext('XX_EXC_REQUEST')
        ext['id'] = 'CD_EXC_REQUEST'
        self.assertIn('id must start with XX_', self.run_one(ext)[0])
        ext = self.ext('XX_EXC_REQUEST')
        ext['fields'][0]['element'] = 'Feeder'
        self.assertIn("element 'Feeder' must be ZZXX_", self.run_one(ext)[0])
        ext = self.ext('XX_EXC_REQUEST')
        ext['association'] = '_Request'
        self.assertIn('association must be _ZZXX', self.run_one(ext)[0])

    def test_link_pending_while_inactive(self):
        problems, res = self.run_one(self.ext('XX_BRK_GROUP_REQ'))
        self.assertEqual(problems, '')
        self.assertEqual(res['status'], 'pending')
        self.assertIn('link XX_GLITEM_TO_REQUEST inactive (VERIFY)', res['reasons'])
        self.assertEqual(res['on'], ['_ZZXXBrkReq.req_id = $projection.Assignment'])

    def test_link_from_another_object_refused(self):
        ext = self.ext('XX_BRK_GROUP_REQ')
        ext['link'] = 'XX_ITEM_TO_REQ'
        self.assertIn('link XX_ITEM_TO_REQ leaves FICA_OPEN_ITEM, the anchor JOURNAL_GROUP is S4_JOURNAL_ITEM',
                      self.run_one(ext)[0])

    def test_to_many_link_refused(self):
        self.reg.links['XX_GLITEM_TO_REQS'] = dict(copy.deepcopy(self.reg.links['XX_GLITEM_TO_REQUEST']),
                                                   id='XX_GLITEM_TO_REQS', cardinality='NM')
        ext = self.ext('XX_BRK_GROUP_REQ')
        ext['link'] = 'XX_GLITEM_TO_REQS'
        self.assertIn('only a "to one" link (11, N1)', self.run_one(ext)[0])

    def test_field_the_anchor_does_not_provide_refused(self):
        link = dict(copy.deepcopy(self.reg.links['XX_GLITEM_TO_REQUEST']), id='XX_GLITEM_BY_DOC')
        link['conditions'] = [{'kind': 'EQ', 'from': 'ClearingJournalEntry', 'to': 'REQ_ID'}]
        self.reg.links['XX_GLITEM_BY_DOC'] = link
        ext = self.ext('XX_BRK_GROUP_REQ')
        ext['link'] = 'XX_GLITEM_BY_DOC'
        self.assertIn('reads ClearingJournalEntry, which anchor JOURNAL_GROUP does not provide', self.run_one(ext)[0])

    def _payreq_link(self):
        link = dict(copy.deepcopy(self.reg.links['XX_GLITEM_TO_REQUEST']), id='XX_GLITEM_TO_PAYREQ',
                    to='XX_PAY_REQUEST', active=True, verify='')
        link['conditions'] = [{'kind': 'EQ', 'from': 'AssignmentReference', 'to': 'REQ_ID'},
                              {'kind': 'PREFER', 'to': 'STATUS', 'value': 'OK'}]
        self.reg.links['XX_GLITEM_TO_PAYREQ'] = link
        ext = self.ext('XX_BRK_GROUP_REQ')
        ext['link'] = 'XX_GLITEM_TO_PAYREQ'
        return ext

    def test_prefer_is_a_filter_and_an_active_link_makes_it_active(self):
        # the identity of the request is its number (declared): the link covers it, PREFER filters the attempt
        self.reg.objects['XX_PAY_REQUEST'] = dict(self.reg.objects['XX_PAY_REQUEST'], identity=['REQ_ID'])
        problems, res = self.run_one(self._payreq_link())
        self.assertEqual(problems, '')
        self.assertEqual(res['on'], ['_ZZXXBrkReq.req_id = $projection.Assignment', "_ZZXXBrkReq.status = 'OK'"])
        self.assertEqual(res['status'], 'active')
        self.assertIsNone(res['ambiguous'])

    def test_ambiguous_link_reads_a_candidates_view(self):
        # build Q: the identity is the keys (REQ_ID, ATTEMPT) - ATTEMPT is not covered: ambiguous by design
        ext = self._payreq_link()
        self.assertIn('ambiguity_element', self.run_one(ext)[0])
        ext['ambiguity_element'] = 'ZZXX_BrkReqMatch'
        problems, res = self.run_one(ext)
        self.assertEqual(problems, '')
        self.assertEqual(res['on'], ['_ZZXXBrkReq.req_id = $projection.Assignment'])
        self.assertEqual(res['ambiguous']['filters'], ["Cnd.status = 'OK'"])
        self.assertEqual(res['ambiguous']['uncovered'], ['ATTEMPT'])
        self.assertEqual(res['target'], 'ZXX_XC_BRK_GROUP_REQ')
        self.assertTrue(all(e['expr'].startswith('case when _ZZXXBrkReq.Candidates') or
                            e['expr'].startswith('cast( case when _ZZXXBrkReq.Candidates') for e in res['elements']))
        self.assertEqual(res['elements'][-1]['name'], 'ZZXX_BrkReqMatch')

    def test_replacement_link_is_rendered(self):
        self.reg.links['XX_ITEM_TO_JOURNAL'] = dict(copy.deepcopy(self.reg.links['S4_ITEM_TO_JOURNAL']),
                                                    id='XX_ITEM_TO_JOURNAL', layer='XX', active=True,
                                                    replaces='S4_ITEM_TO_JOURNAL')
        ext = self.ext('XX_BRK_GROUP_REQ')
        ext.update(point='BRK_LINE', anchor='JOURNAL_ITEM', link='S4_ITEM_TO_JOURNAL', also=[],
                   fields=[{'field': 'ReverseDocument', 'element': 'ZZXX_ReverseDoc', 'label': 'Reversed by'}])
        problems, res = self.run_one(ext)
        self.assertEqual(problems, '')
        self.assertEqual(res['joins'], 'XX_ITEM_TO_JOURNAL (replaces S4_ITEM_TO_JOURNAL)')
        self.assertIn('_ZZXXBrkReq.AccountingDocument = $projection.AccountingDocument', res['on'])
        self.assertEqual(res['status'], 'pending')   # the released view's element names are VERIFY (V110)
        self.assertIn('field ReverseDocument VERIFY V110', res['reasons'])

    def test_declared_verify_and_placeholder_make_it_pending(self):
        ext = self.ext('XX_CTL_AUDIT_REF')
        ext['verify'] = 'V999'
        _, res = self.run_one(ext)
        self.assertEqual((res['status'], res['reasons']), ('pending', ['VERIFY V999 of the declaration open']))
        self.reg.objects['XX_CTL_REGISTER'] = dict(self.reg.objects['XX_CTL_REGISTER'], source='‹audit table›')
        _, res = self.run_one(self.ext('XX_CTL_AUDIT_REF'))
        self.assertEqual(res['status'], 'pending')
        self.assertEqual(res['target'], '‹audit table›')

    def test_blocked_needs_its_reason(self):
        ext = self.ext('XX_BRK_LINE_CASE')
        del ext['reason']
        self.assertIn('a blocked extension names its reason', self.run_one(ext)[0])

    def test_optional_views_and_their_sources(self):
        ext = self.ext('XX_BRK_GROUP_REQ')
        ext['also'] = ['BRKGRP_QRY']
        self.assertIn('BRKGRP_QRY needs BRKGRP_CUBE (add it to also)', self.run_one(ext)[0])
        ext['also'] = ['BRKGRP_C']
        self.assertIn('BRKGRP_C is not an optional view of BRK_GROUP', self.run_one(ext)[0])

    def test_duplicate_element_and_quota(self):
        one, two = self.ext('XX_FLOW_STAGE_SLA'), self.ext('XX_FLOW_STAGE_SLA')
        two['id'], two['association'] = 'XX_FLOW_STAGE_SLA2', '_ZZXXStageSla2'
        problems, _ = ex.analyse(self.pack, [one, two], self.inv, self.reg)
        self.assertIn('XX_FLOW_STAGE_SLA2: element ZZXX_SlaHours also added by XX_FLOW_STAGE_SLA', problems)
        inv = copy.deepcopy(self.inv)
        inv['annotation']['max_fields'] = 1
        problems, _ = ex.analyse(self.pack, [one], inv, self.reg)
        self.assertIn('point FLOW_STAGE: 2 elements exceed the quota of 1', problems)

    def test_element_suffix_switch(self):
        inv = copy.deepcopy(self.inv)
        inv['annotation']['suffix_in_names'] = True
        problems, results = ex.analyse(self.pack, [self.ext('XX_CTL_AUDIT_REF')], inv, self.reg)
        self.assertEqual(problems, [])
        self.assertEqual([e['name'] for e in results[0]['elements']], ['ZZXX_AuditRefZOP', 'ZZXX_TesterZOP'])


class RenderTest(unittest.TestCase):

    def setUp(self):
        self.inv = ex.load_inventory()
        self.pack, exts, reg = example()
        problems, self.results = ex.analyse(self.pack, list(exts.values()), self.inv, reg)
        self.assertEqual(problems, [])
        self.files = ex.render_pack(self.pack, self.results)

    def test_files_by_status(self):
        names = {os.path.relpath(p, self.pack['package_folder']) if p.startswith(self.pack['package_folder'])
                 else 'pending/' + os.path.basename(p) for p in self.files}
        self.assertEqual(names, {'package.devc.xml', 'zxx_x_ctlrev_c.ddls.asddls', 'zxx_x_exc_c.ddls.asddls',
                                 'zxx_x_flowstg_c.ddls.asddls', 'zxx_x_flow_cube.ddls.asddls',
                                 'zc_xx_flowqry.ddls.asddls', 'pending/zxx_x_brkgrp_r.ddls.asddls',
                                 'pending/zxx_x_brkgrp_c.ddls.asddls', 'pending/zxx_x_brkgrp_cube.ddls.asddls',
                                 'pending/zc_xx_brkqry.ddls.asddls'})

    def text(self, name):
        return next(t for p, t in self.files.items() if p.endswith(name))

    def test_base_extension(self):
        text = self.text('zxx_x_ctlrev_c.ddls.asddls')
        self.assertIn('extend view entity ZC_CA_OpsCtlReview with\n'
                      '  association [0..1] to zxx_ctl_reg as _ZZXXCtlReg on  _ZZXXCtlReg.area = $projection.Area\n'
                      '                                                   and _ZZXXCtlReg.control_id = '
                      '$projection.ControlId\n{', text)
        self.assertIn("  @UI.lineItem: [ { position: 910, importance: #LOW } ]\n"
                      "  @UI.identification: [ { position: 910 } ]\n"
                      "  concat( '****', right( _ZZXXCtlReg.tester, 4 ) ) as ZZXX_Tester\n}", text)
        self.assertIn('// Extension: XX extension of ZC_CA_OpsCtlReview', text)

    def test_propagation_and_query_copy(self):
        self.assertIn('extend view entity ZC_CA_OpsBrkGroup with\n{', self.text('zxx_x_brkgrp_c.ddls.asddls'))
        self.assertIn('  Grp.ZZXX_BrkFeeder\n}', self.text('zxx_x_brkgrp_cube.ddls.asddls'))
        query = self.text('zc_xx_flowqry.ddls.asddls')
        self.assertIn('define transient view entity ZC_XX_FlowQry\n', query)
        self.assertIn('  ControlOpenCount,\n', query)
        self.assertTrue(query.endswith("  @AnalyticsDetails.query.axis: #FREE\n  ZZXX_StageTeam\n}\n"))
        self.assertNotIn('ZC_CA_OpsFlowQry\n', query.split('define')[1])

    def test_pending_file_holds_active_and_pending(self):
        pack, exts, reg = example()
        exts['XX_BRK_GROUP_REQ2'] = dict(copy.deepcopy(exts['XX_BRK_GROUP_REQ']), id='XX_BRK_GROUP_REQ2',
                                        link=None, anchor='ASSIGNMENT', object='XX_REQUEST',
                                        keys={'REQ_ID': 'Assignment'}, association='_ZZXXBrkReq2',
                                        fields=[{'field': 'RECEIVED_ON', 'element': 'ZZXX_BrkReceived',
                                                 'label': 'Received on'}])
        problems, results = ex.analyse(pack, list(exts.values()), self.inv, reg)
        self.assertEqual(problems, [])
        files = ex.render_pack(pack, results)
        active = files[os.path.join('src/ext', 'zxx_x_brkgrp_r.ddls.asddls')]
        pending = files[os.path.join('config/extensions/pending', 'zxx_x_brkgrp_r.ddls.asddls')]
        self.assertIn('ZZXX_BrkReceived', active)
        self.assertNotIn('ZZXX_BrkFeeder', active)
        self.assertIn('ZZXX_BrkReceived', pending)
        self.assertIn('ZZXX_BrkFeeder', pending)


class SuitePackTest(unittest.TestCase):

    def test_suite_pack_valid_and_up_to_date(self):
        self.assertEqual(ex.check(SUITE, SUITE_PROFILE), [])

    def test_suite_pack_statuses(self):
        inv = ex.load_inventory()
        problems, results, files, _ = ex.pack_outputs(SUITE, 'config/extensions', inv)
        self.assertEqual(problems, [])
        self.assertEqual({r['id']: r['status'] for r in results},
                         {'CD_BRK_WORK_STATE': 'pending', 'CD_BRK_LINE_REQUEST': 'blocked',
                          'CD_FLOW_REQUEST': 'blocked'})
        self.assertFalse(any(p.startswith('src') for p in files), 'nothing of the suite pack is active yet')


class NoCustomerObjectInProductTest(unittest.TestCase):
    """No product file of the framework references an object of a customer: the consumers' object prefixes of
    config/customer_terms.txt and every object the ops suite defines (sources and registry objects)."""

    def suite_objects(self):
        names = set()
        for top in ('src', 'cds'):
            for _, _, files in os.walk(os.path.join(SUITE, top)):
                names |= {f.split('.')[0].upper() for f in files if f != 'package.devc.xml'}
        return {n for n in names if len(n) > 4}

    def test_no_product_file_references_a_customer_object(self):
        prefixes = [t for t, flags in shared.term_rules(FRAMEWORK) if 'prefix' in flags]
        objects = self.suite_objects()
        self.assertIn('ZI_CD_PAYWORKSTATE', objects)
        pattern = re.compile(r'\b(' + '|'.join(re.escape(p) + r'\w*' for p in prefixes) + r'|' +
                             '|'.join(sorted((re.escape(o) for o in objects), key=len, reverse=True)) + r')\b', re.I)
        allowed = {}
        for line in read(os.path.join(FRAMEWORK, 'config', 'customer_terms_allowed.txt')).splitlines():
            if True:
                if line.strip() and not line.startswith('#'):
                    path, text = [x.strip() for x in line.split('|')[:2]]
                    allowed.setdefault(path, []).append(text)
        scopes = [(FRAMEWORK, top) for top in ('src', 'ddic', 'templates', 'config', 'docs', 'tools')] + \
                 [(REPO, os.path.join('tools', 'abaptools'))]
        found = []
        for base, top in scopes:
            for folder, dirs, files in os.walk(os.path.join(base, top)):
                dirs[:] = [d for d in dirs if d not in ('__pycache__', 'tests')]
                for name in files:
                    if name.startswith('customer_terms'):
                        continue
                    path = os.path.join(folder, name)
                    rel = os.path.relpath(path, FRAMEWORK)
                    for no, line in enumerate(read(path).splitlines(), start=1):
                        if MOVED.search(line):     # change history of an object moved into the framework
                            continue
                        if pattern.search(line) and not any(t in line for t in allowed.get(rel, [])):
                            found.append(f'{rel}:{no}: {pattern.search(line).group(0)}')
        self.assertEqual(found, [])


if __name__ == '__main__':
    unittest.main()
