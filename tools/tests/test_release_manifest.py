"""Tests of the release manifest engine (tools/abaptools/release_manifest.py) and of the upgrade notes
(tools/abaptools/release_diff.py): the product's manifest is valid, membership follows the rules, every rule fails
when it is broken, the blank-slate rules find planted customer data, the namespace report, and the upgrade notes of
two revisions of a throwaway git repository (dictionary changes classified, rollback guidance).

Modification log:
2026-11-15 | Initial version (build M: clean install and release baseline).
"""
import copy
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import abaptools  # noqa: E402

rm = abaptools.fresh('release_manifest', 'test')
rd = abaptools.fresh('release_diff', 'test')
MANIFEST = os.path.join(ROOT, 'ops-framework', 'release', 'manifest.json')
DOC = os.path.join(ROOT, 'ops-framework', 'release', 'MANIFEST.md')


def pack(manifest, pid):
    return next(p for p in manifest['packs'] if p['id'] == pid)


class ProductManifestTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.manifest = rm.load(MANIFEST)
        cls.objects, cls.problems = rm.inventory(ROOT, cls.manifest)

    def fresh(self):
        objects = [dict(o, pack=None) for o in self.objects]
        return copy.deepcopy(self.manifest), objects

    def test_product_manifest_valid_and_document_current(self):
        self.assertEqual(rm.check(ROOT, MANIFEST, DOC), [])

    def test_every_object_in_one_pack_by_folder(self):
        m, objects = self.fresh()
        self.assertEqual(self.problems, [])
        self.assertEqual(rm.assign(objects, m), [])
        packs = {o['pack'] for o in objects}
        self.assertEqual(packs, {'PARAM', 'CORE', 'DEMO'})
        self.assertTrue(all(o['component'] == 'ZCA_PARAM' for o in objects if o['pack'] == 'PARAM'))
        self.assertEqual({o['package'] for o in objects if o['pack'] == 'DEMO'}, {'ZCA_OPS_DEMO'})

    def test_object_of_an_unknown_folder_is_in_no_pack(self):
        m, objects = self.fresh()
        pack(m, 'CORE')['objects']['folders'] = ['']
        failures = rm.assign(objects, m)
        self.assertTrue(failures and all('in no pack' in f and 'src/ui' in f for f in failures))

    def test_name_rule_wins_over_folder_and_order_is_checked(self):
        m, objects = self.fresh()
        # a plug-in nothing in the core refers to may move into the FI-CA pack
        pack(m, 'FICA_CASH')['objects']['names'] = ['ZCL_CA_OPS_FLOW_SRC_FICA']
        self.assertEqual(rm.assign(objects, m), [])
        self.assertEqual(next(o['pack'] for o in objects if o['name'] == 'ZCL_CA_OPS_FLOW_SRC_FICA'), 'FICA_CASH')
        self.assertEqual(rm.check_order(m, objects), [])
        # the types interface the whole core uses may not sit in a pack the core does not stand on
        m, objects = self.fresh()
        pack(m, 'DEMO')['objects']['names'] = ['ZIF_CA_OPS_TYPES']
        rm.assign(objects, m)
        failures = rm.check_order(m, objects)
        self.assertTrue(any('refers to ZIF_CA_OPS_TYPES of pack DEMO, not a prerequisite' in f for f in failures))

    def test_import_order_and_requires(self):
        m, objects = self.fresh()
        rm.assign(objects, m)
        m['import_order'] = ['CORE', 'PARAM', 'FICA_CASH', 'FSCD_STANDARD', 'DEMO']
        self.assertTrue(any('CORE before its prerequisite PARAM' in f for f in rm.check_order(m, objects)))
        m['import_order'] = ['PARAM', 'CORE']
        self.assertTrue(rm.check_order(m, objects))
        self.assertEqual(rm.derived_order(self.manifest)[:2], ['PARAM', 'CORE'])
        m = copy.deepcopy(self.manifest)
        pack(m, 'PARAM')['requires'] = ['DEMO']
        with self.assertRaises(rm.ManifestError):
            rm.derived_order(m)

    def test_versions_read_from_the_constants(self):
        m = copy.deepcopy(self.manifest)
        m['components'][1]['version'] = '9.9.9'
        m['components'][1]['requires'][0]['min_version'] = '1.0.0'
        failures = rm.check_structure(ROOT, m)
        self.assertTrue(any('version 9.9.9 in the manifest, 1.0.0 in' in f for f in failures))
        self.assertTrue(any('minimum ZCA_PARAM 1.0.0 in the manifest, 1.1.0' in f for f in failures))

    def test_licence_modules(self):
        m = copy.deepcopy(self.manifest)
        pack(m, 'FICA_CASH')['license_modules'].append('JOBS')
        pack(m, 'DEMO')['license_modules'] = ['NO_SUCH']
        failures = rm.check_licensing(ROOT, m)
        self.assertTrue(any('JOBS: in packs CORE, FICA_CASH' in f for f in failures))
        self.assertTrue(any('NO_SUCH' in f for f in failures))
        m = copy.deepcopy(self.manifest)
        pack(m, 'CORE')['license_modules'].remove('ONBOARD')
        pack(m, 'DEMO')['license_modules'] = ['ONBOARD']
        failures = rm.check_licensing(ROOT, m)
        self.assertTrue(any('CATALOGUE_FICA (pack FICA_CASH) requires ONBOARD of pack DEMO' in f for f in failures))
        m['licensing']['enforce_parameter']['delivered'] = 'X'
        self.assertTrue(any('activation must never depend on a licence' in f for f in rm.check_licensing(ROOT, m)))

    def test_seed_rows_in_exactly_one_pack(self):
        seeds, failures = rm.seed_assignment(ROOT, self.manifest)
        self.assertEqual(failures, [])
        self.assertGreater(seeds['ops-framework/config/catalogue/seed/zca_ops_catprc.csv']['FICA_CASH'], 10)
        m = copy.deepcopy(self.manifest)
        pack(m, 'FICA_CASH')['seed_keys']['layer'] = []
        _, failures = rm.seed_assignment(ROOT, m)
        self.assertTrue(any('LAYER_ID FICA in no pack' in f for f in failures))
        pack(m, 'DEMO')['seed_keys'] = {'prefix': ['S4_']}
        _, failures = rm.seed_assignment(ROOT, m)
        self.assertTrue(any('in packs CORE, DEMO' in f for f in failures))

    def test_checks_catalogue_contracts(self):
        m, objects = self.fresh()
        rm.assign(objects, m)
        classes = rm.pack_checks(ROOT, m)
        self.assertIn('ZCL_CA_OPS_CHK_LICENSE', classes['CORE'])
        self.assertIn('ZCL_CA_OPS_CHK_BREAK', classes['FICA_CASH'])
        pack(m, 'FICA_CASH')['catalogue']['processes'].append('FICA_NO_SUCH')
        self.assertTrue(any('FICA_NO_SUCH' in f for f in rm.check_catalogue(ROOT, m)))
        pack(m, 'DEMO')['source_contracts'] = ['FLOW_SOURCE', 'NO_POINT']
        failures = rm.check_contracts(ROOT, m, objects)
        self.assertTrue(any('FLOW_SOURCE: in packs FICA_CASH, DEMO' in f for f in failures))
        self.assertTrue(any('NO_POINT' in f for f in failures))

    def test_open_item_blocks_a_token(self):
        m, objects = self.fresh()
        rm.assign(objects, m)
        self.assertEqual(rm.check_open_items(m, objects), [])
        pack(m, 'FICA_CASH')['open_items'][0]['tokens'] = ['DFKKOP']
        failures = rm.check_open_items(m, objects)
        self.assertTrue(any('ZCL_CA_OPS_FLOW_DAO uses DFKKOP' in f for f in failures))

    def test_names_limits_and_collisions(self):
        m, objects = self.fresh()
        objects.append({'name': 'ZCA_OPS_MUCH_TOO_LONG', 'type': 'tabl', 'component': 'ZCA_OPS', 'folder': '',
                        'package': 'ZCA_OPS', 'files': [], 'pack': 'CORE'})
        objects.append({'name': 'ZCA_OPS_RUN', 'type': 'dtel', 'component': 'ZCA_OPS', 'folder': '',
                        'package': 'ZCA_OPS', 'files': [], 'pack': 'CORE'})
        objects.append({'name': 'ZCL_CD_SOMETHING', 'type': 'clas', 'component': 'ZCA_OPS', 'folder': '',
                        'package': 'ZCA_OPS', 'files': [], 'pack': 'CORE'})
        objects.append({'name': 'XCL_NOT_CUSTOMER', 'type': 'clas', 'component': 'ZCA_OPS', 'folder': '',
                        'package': 'ZCA_OPS', 'files': [], 'pack': 'CORE'})
        failures = rm.check_objects(ROOT, m, objects)
        self.assertIn('tabl ZCA_OPS_MUCH_TOO_LONG: 21 characters, limit 16', failures)
        self.assertIn('ZCA_OPS_RUN: one name for dtel, tabl (one name space)', failures)
        self.assertIn('clas ZCL_CD_SOMETHING: not a product name (namespace.product_patterns)', failures)
        self.assertIn('clas XCL_NOT_CUSTOMER: not in the customer (Z / Y) or a registered namespace', failures)

    def test_namespace_report(self):
        m, objects = self.fresh()
        self.assertEqual(rm.rename('ZCL_CA_OPS_STORE', m, '/XYZ/'), '/XYZ/CL_OPS_STORE')
        self.assertEqual(rm.rename('ZR_CA_OpsBrkGroup', m, '/XYZ/'), '/XYZ/R_OPSBRKGROUP')
        self.assertEqual(rm.rename('ZCA_OPS_RUN', m, '/XYZ/'), '/XYZ/OPS_RUN')
        text, rows = rm.namespace_report(ROOT, m, objects, '/XYZ/')
        bad = {(r['type'], r['name']): r['status'] for r in rows if r['status'] != 'ok'}
        self.assertEqual(bad[('susc', 'ZCA')], 'too long')
        self.assertIn('| susc | `ZCA` | `/XYZ/`', text)
        _, rows = rm.namespace_report(ROOT, m, objects, '/LONGNS/')
        self.assertGreater(sum(1 for r in rows if r['status'] == 'too long'), len(bad))


class BlankSlateRulesTest(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.manifest = copy.deepcopy(rm.load(MANIFEST))
        self.manifest['blank_slate']['scan'] = ['comp']
        self.manifest['distribution']['exclude'] = ['comp/config/excluded.csv']
        os.makedirs(os.path.join(self.tmp, 'comp', 'config', 'examples'))
        os.makedirs(os.path.join(self.tmp, 'comp', 'src'))

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write(self, rel, text):
        path = os.path.join(self.tmp, rel)
        with open(path, 'w', encoding='utf-8') as handle:
            handle.write(text)
        return path

    def test_planted_customer_data_found(self):
        self.write('comp/config/rules.csv', 'AREA,BUKRS,DESTINATION,OWNER,FIELD\n'
                                            'CA_X,1000,ZTEAM_LIST,OPS FRAMEWORK,ZZ_MEMBER\n'
                                            'CA_X,,‹SO23 list›,,\n')
        self.write('comp/config/examples/xx.csv', 'AREA,BUKRS\nXX,1000\n')
        self.write('comp/config/excluded.csv', 'AREA,DESTINATION\nX,someone@customer.org\n')
        self.write('comp/README.md', 'Write to ops@example.com or to lead@customer.org.\n')
        src = self.write('comp/src/zcl_ca_x.clas.abap', "* old name ZCL_CD_OLD in a comment is not code\n"
                                                        "  DATA lo TYPE REF TO zcl_cd_other.\n"
                                                        "  lv = ls_item-zz_status.\n  lv = 'ZZZZ'.\n")
        objects = [{'name': 'ZCL_CA_X', 'type': 'clas', 'files': [src], 'pack': 'CORE', 'component': 'ZCA_OPS',
                    'folder': '', 'package': 'ZCA_OPS'}]
        failures = rm.check_blank_slate(self.tmp, self.manifest, objects)
        self.assertIn('comp/config/rules.csv:2: BUKRS = 1000 (customer value in delivered configuration)', failures)
        self.assertIn('comp/config/rules.csv:2: DESTINATION = ZTEAM_LIST (customer value in delivered configuration)',
                      failures)
        self.assertIn('comp/config/rules.csv:2: FIELD = ZZ_MEMBER (append field in delivered configuration)', failures)
        self.assertIn('comp/README.md:1: e-mail address outside the example domains', failures)
        self.assertIn('comp/src/zcl_ca_x.clas.abap: refers to ZCL_CD_OTHER (not a product object)', failures)
        self.assertIn('comp/src/zcl_ca_x.clas.abap: names the append field ZZ_STATUS', failures)
        self.assertEqual(len(failures), 6, failures)


class ReleaseDiffTest(unittest.TestCase):

    def git(self, *args):
        subprocess.run(['git', '-C', self.tmp] + list(args), check=True, capture_output=True,
                       env=dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@example.com',
                                GIT_COMMITTER_NAME='t', GIT_COMMITTER_EMAIL='t@example.com'))

    def write(self, rel, text):
        path = os.path.join(self.tmp, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as handle:
            handle.write(text)

    @staticmethod
    def table(fields):
        rows = ''.join(f'<DD03P><FIELDNAME>{n}</FIELDNAME>{"<KEYFLAG>X</KEYFLAG>" if k else ""}'
                       f'<DATATYPE>CHAR</DATATYPE><LENG>{length:06d}</LENG></DD03P>' for n, k, length in fields)
        return (f'<abapGit><DD02V><TABNAME>T</TABNAME><TABCLASS>TRANSP</TABCLASS></DD02V><DD09L><TABART>APPL1'
                f'</TABART></DD09L><DD03P_TABLE>{rows}</DD03P_TABLE></abapGit>')

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.git('init', '-q')
        manifest = {'release': '1.0.0', 'import_order': ['P'],
                    'components': [{'id': 'ZC', 'folder': 'comp', 'version': '1.0.0',
                                    'version_source': {'file': 'src/zif_c_types.intf.abap', 'constant': 'gc_version'}}],
                    'packs': [{'id': 'P', 'objects': {'component': 'ZC', 'folders': ['']}}]}
        import json
        self.write('comp/release/manifest.json', json.dumps(manifest))
        self.write('comp/config/repository.json', '{"packages": {"": ["ZC", "c"]}}')
        self.write('comp/src/zif_c_types.intf.abap', "  CONSTANTS gc_version TYPE string VALUE `1.0.0`.\n")
        self.write('comp/src/zc_tab.tabl.xml', self.table([('MANDT', True, 3), ('ID', True, 10), ('OLD', False, 5),
                                                           ('TXT', False, 20), ('CODE', False, 10)]))
        self.write('comp/src/zc_gone.tabl.xml', self.table([('MANDT', True, 3)]))
        self.write('comp/src/zcl_c_a.clas.abap', 'CLASS a.\n')
        self.write('comp/config/seed.csv', 'A\n1\n')
        self.git('add', '-A')
        self.git('commit', '-q', '-m', 'one')
        self.write('comp/src/zc_tab.tabl.xml', self.table([('MANDT', True, 3), ('ID', True, 10), ('TXT', False, 40),
                                                           ('CODE', False, 4), ('NEW', False, 1)]))
        os.remove(os.path.join(self.tmp, 'comp/src/zc_gone.tabl.xml'))
        self.write('comp/src/zcl_c_a.clas.abap', 'CLASS a. "changed\n')
        self.write('comp/src/zcl_c_b.clas.abap', 'CLASS b.\n')
        self.write('comp/config/seed.csv', 'A\n2\n')
        self.git('add', '-A')
        self.git('commit', '-q', '-m', 'two')

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_upgrade_notes(self):
        result = rd.diff(self.tmp, 'HEAD~1', 'HEAD', 'comp/release/manifest.json')
        states = {(c['type'], c['name']): c['state'] for c in result['changes']}
        self.assertEqual(states, {('tabl', 'ZC_TAB'): 'changed', ('tabl', 'ZC_GONE'): 'removed',
                                  ('clas', 'ZCL_C_A'): 'changed', ('clas', 'ZCL_C_B'): 'added'})
        tab = next(c for c in result['changes'] if c['name'] == 'ZC_TAB')['dictionary']
        self.assertIn(('adjust', 'new field NEW'), tab)
        self.assertIn(('convert', 'field OLD removed (its values are lost)'), tab)
        self.assertIn(('adjust', 'field TXT: longer 20 -> 40'), tab)
        self.assertIn(('convert', 'field CODE: length 10,0 -> 4,0'), tab)
        gone = next(c for c in result['changes'] if c['name'] == 'ZC_GONE')['dictionary']
        self.assertEqual(gone[0][0], 'drop')
        self.assertIn(('comp/config/seed.csv', 'changed'), result['config'])
        text = rd.notes(result)
        self.assertIn('need a conversion or drop data', text)
        self.assertIn('ZC changed but its version constant did not', text)
        self.assertIn('## Rollback', text)

    def test_unknown_revision_reported(self):
        with self.assertRaises(rd.DiffError):
            rd.diff(self.tmp, 'no-such-rev', 'HEAD', 'comp/release/manifest.json')


if __name__ == '__main__':
    unittest.main()
