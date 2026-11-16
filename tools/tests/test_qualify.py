"""Tests of the install harness tools/qualify/qualify.py against a fake ADT server (pattern of the test tool's
ci/test_ci.py): refusals before any connection, the collision stage that stops the run before anything is written,
a clean install run with evidence, the dry run, the write guard, the licensing stage and the ABAP Unit verdict.

Modification log:
2026-11-15 | Initial version (build M: install harness).
"""
import contextlib
import http.server
import io
import json
import os
import re
import sys
import tempfile
import threading
import unittest
import urllib.parse
import xml.etree.ElementTree as ET
from unittest import mock

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'qualify'))
import qualify as q  # noqa: E402

ONLY = r'^(ZIF_CA_PARAM_TYPES|ZCA_PARAM_AREA|ZCL_CA_PARAM_DAO|ZIF_CA_OPS_TYPES|ZCA_OPS_RUN|ZC_CA_OPSEXCEPTION|' \
       r'ZUI_CA_OPS_EXC|ZCA_OPS_CHECK_RUN)$'
DP = 'http://www.sap.com/adt/dataPreview'


def preview_xml(columns, rows):
    cols = []
    for c in columns:
        data = ''.join(f'<dataPreview:data>{r.get(c, "")}</dataPreview:data>' for r in rows)
        cols.append(f'<dataPreview:columns><dataPreview:metadata dataPreview:name="{c}"/>'
                    f'<dataPreview:dataSet>{data}</dataPreview:dataSet></dataPreview:columns>')
    return f'<dataPreview:tableData xmlns:dataPreview="{DP}">' + ''.join(cols) + '</dataPreview:tableData>'


class Fake(http.server.BaseHTTPRequestHandler):
    state = {}

    def log_message(self, *a):
        pass

    def send(self, code, body='', ctype='application/xml', headers=None):
        data = body.encode()
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(data)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def handle_any(self):
        st = Fake.state
        length = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(length).decode() if length else ''
        url = urllib.parse.urlsplit(self.path)
        path, query = url.path, urllib.parse.parse_qs(url.query)
        st['calls'].append((self.command, path))
        if path.startswith('/sap/opu/odata4/'):
            binding = path.split('/')[5]
            return self.send(200, '<edmx:Edmx/>') if binding.upper() in st['published'] else self.send(404)
        adt = path[len('/sap/bc/adt'):]
        if adt == '/discovery':
            return self.send(200, '<app:service/>', headers={'x-csrf-token': 'tok'})
        if self.command != 'GET' and self.headers.get('X-CSRF-Token') != 'tok':
            return self.send(403, 'CSRF token validation failed')
        if query.get('_action'):
            return self.send(200, '<LOCK_HANDLE>H1</LOCK_HANDLE>' if query['_action'][0] == 'LOCK' else '')
        if adt == '/system/information':
            return self.send(200, json.dumps({'systemID': 'FAK', 'client': '100', 'release': '758'}), 'application/json')
        if adt == '/repository/informationsystem/search':
            name = query['query'][0].upper()
            hit = f'<adtcore:objectReference adtcore:name="{name}"/>' if name in st['present'] else ''
            return self.send(200, f'<adtcore:objectReferences xmlns:adtcore="x">{hit}</adtcore:objectReferences>')
        if adt == '/datapreview/freestyle':
            sql = body.lower()
            if 'from tadir' in sql:
                names = {n.upper() for n in re.findall(r"'([^']+)'", body)[1:]}
                rows = [r for r in st['tadir'] if r['OBJ_NAME'] in names]
                return self.send(200, preview_xml(['PGMID', 'OBJECT', 'OBJ_NAME', 'DEVCLASS'], rows))
            if 'zca_ops_lic' in sql:
                return self.send(200, preview_xml(['LICENSE_ID', 'ACTIVE'], st['licences']))
            if 'zca_param_val' in sql:
                return self.send(200, preview_xml(['LOW'], [{'LOW': v} for v in st['enforce']]))
            return self.send(400, 'unknown statement')
        if adt == '/activation/inactiveobjects':
            refs = ''.join(f'<ioc:object><adtcore:objectReference adtcore:uri="/sap/bc/adt{u}" adtcore:name="{n}"/>'
                           '</ioc:object>' for n, u in sorted(st['inactive'].items()))
            return self.send(200, f'<ioc:inactiveObjects xmlns:ioc="i" xmlns:adtcore="x">{refs}</ioc:inactiveObjects>')
        if adt == '/activation':
            st['inactive'].clear()
            return self.send(200, '<chkl:messages xmlns:chkl="c"/>')
        if adt == '/abapunit/testruns':
            return self.send(200, '<aunit:runResult xmlns:aunit="http://www.sap.com/adt/aunit" '
                                  'xmlns:adtcore="http://www.sap.com/adt/core"><program adtcore:name="P"><testClasses>'
                                  '<testClass adtcore:name="C"><testMethods><testMethod adtcore:name="M"/>'
                                  '</testMethods></testClass></testClasses></program></aunit:runResult>')
        if adt == '/atc/worklists' and self.command == 'POST':
            return self.send(200, 'WL1', 'text/plain')
        if adt == '/atc/runs':
            return self.send(200, '<atc:runInfo xmlns:atc="a"/>')
        if adt.startswith('/atc/worklists/'):
            return self.send(200, '<atcworklist:worklist xmlns:atcworklist="w"/>')
        if adt.startswith('/ddic/db/settings/'):
            return self.send(200, '<ts:settings xmlns:ts="t"><ts:dataClassCategory>APPL1</ts:dataClassCategory>'
                                  '<ts:loggingEnabled>false</ts:loggingEnabled></ts:settings>')
        if adt.startswith('/textelements/programs/') and self.command == 'GET':
            return self.send(200, '', 'text/plain')
        if adt.startswith('/messageclass/') and self.command == 'GET':
            return self.send(200, '<mc:messageClass xmlns:mc="m"></mc:messageClass>')
        m = re.match(r'^(/[a-z/]+?)/([a-z0-9_]+)(/(source/main|includes/\w+))?$', adt)
        if self.command == 'POST' and re.match(r'^/(oo/classes|oo/interfaces|ddic/tables|ddic/ddl/sources|'
                                               r'ddic/ddlx/sources|programs/programs)$', adt):
            name = re.search(r'adtcore:name="([^"]+)"', body).group(1).lower()
            st['objects'].setdefault(f'{adt}/{name}', {})
            return self.send(201, '')
        if m and self.command == 'GET':
            uri, part = f'{m.group(1)}/{m.group(2)}', m.group(4) or ''
            obj = st['objects'].get(uri)
            if obj is None:
                return self.send(404, 'not found')
            if not part:
                return self.send(200, '<obj/>')
            return self.send(200, obj.get(part, ''), 'text/plain') if part in obj else self.send(404, 'no include')
        if m and self.command == 'PUT':
            uri = f'{m.group(1)}/{m.group(2)}'
            st['objects'].setdefault(uri, {})[m.group(4) or 'source/main'] = body
            st['inactive'][m.group(2).upper()] = uri
            return self.send(200, '')
        if self.command == 'PUT':
            return self.send(200, '')
        return self.send(404, f'fake: {self.command} {adt}')

    do_GET = do_POST = do_PUT = handle_any


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        pass


def reset(**changes):
    # access controls and service definitions come from abapGit (the harness writes, never creates them)
    Fake.state = {'calls': [], 'inactive': {},
                  'objects': {'/acm/dcl/sources/zc_ca_opsexception': {}, '/bo/behaviordefinitions/zc_ca_opsexception': {},
                              '/ddic/srvd/sources/zui_ca_ops_exc': {}}, 'tadir': [], 'licences': [], 'enforce': [],
                  'published': {'ZUI_CA_OPS_EXC_O4'}, 'present': {'ZR1_PARAM', 'ZR1_PARAM_UI', 'ZR1_OPS', 'ZR1_OPS_UI'}}
    Fake.state.update(changes)


class HarnessTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.server = Server(('127.0.0.1', 0), Fake)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.env = {'SAP_URL': f'http://127.0.0.1:{cls.server.server_address[1]}', 'SAP_USER': 'tester',
                   'SAP_PASSWORD': 'secret-pw', 'SAP_CLIENT': '100', 'SAP_TLS_PIN': ''}

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def run_harness(self, *argv, out=None):
        out = out or tempfile.mkdtemp()
        buf = io.StringIO()
        with mock.patch.dict(os.environ, self.env), contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            rc = q.main(list(argv) + ['--out', out])
        found = [os.path.join(d, f) for d, _, fs in os.walk(out) for f in fs if f == 'results.json']
        result = None
        if found:
            with open(found[0], encoding='utf-8') as handle:
                result = json.load(handle)
        return rc, result, buf.getvalue(), out

    def writes(self):
        return [(m, p) for m, p in Fake.state['calls'] if m in ('PUT', 'DELETE')
                or (m == 'POST' and not p.endswith(('/datapreview/freestyle', '/cts/transportchecks')))]

    def test_refuses_without_package_root_and_transport(self):
        reset()
        rc, result, text, _ = self.run_harness('--stages', 'connect')
        self.assertEqual(rc, 2)
        self.assertIn('--package-root is mandatory', text)
        self.assertIn('--transport is mandatory', text)
        self.assertIsNone(result)
        self.assertEqual(Fake.state['calls'], [])

    def test_refuses_local_transport_for_transportable_packages(self):
        reset()
        rc, _, text, _ = self.run_harness('--package-root', 'ZR1', '--transport', 'LOCAL')
        self.assertEqual(rc, 2)
        self.assertIn('LOCAL only with local packages', text)

    def test_refuses_writing_without_collision_stage(self):
        reset()
        rc, _, text, _ = self.run_harness('--package-root', 'ZR1', '--transport', 'FAKK900001', '--stages',
                                          'connect,sync', '--only', ONLY)
        self.assertEqual(rc, 2)
        self.assertIn('collision stage', text)
        self.assertEqual(Fake.state['calls'], [])

    def test_collision_stops_before_anything_is_written(self):
        reset(tadir=[{'PGMID': 'R3TR', 'OBJECT': 'CLAS', 'OBJ_NAME': 'ZCL_CA_PARAM_DAO', 'DEVCLASS': 'ZOTHER'},
                     {'PGMID': 'R3TR', 'OBJECT': 'TABL', 'OBJ_NAME': 'ZC_CA_OPSEXCEPTION', 'DEVCLASS': 'ZOTHER'},
                     {'PGMID': 'R3TR', 'OBJECT': 'PROG', 'OBJ_NAME': 'ZIF_CA_OPS_TYPES', 'DEVCLASS': 'ZOTHER'},
                     {'PGMID': 'R3TR', 'OBJECT': 'TABL', 'OBJ_NAME': 'ZCA_OPS_RUN', 'DEVCLASS': 'ZR1_OPS'}])
        rc, result, text, _ = self.run_harness('--package-root', 'ZR1', '--transport', 'FAKK900001', '--only', ONLY)
        self.assertEqual(rc, 1)
        stages = result['stages']
        self.assertEqual(stages['collision']['status'], 'fail')
        clashes = {(c['name'], c['system_type']) for c in stages['collision']['clashes']}
        # same name and type; a table with a CDS entity's name (one name space); not a program with an interface's
        # name (another name space), not the product's own table in the target package
        self.assertEqual(clashes, {('ZCL_CA_PARAM_DAO', 'CLAS'), ('ZC_CA_OPSEXCEPTION', 'TABL')})
        for st in ('ddic', 'tables', 'sync', 'activate', 'aunit', 'licensing'):
            self.assertEqual(stages[st]['status'], 'blocked')
        self.assertEqual(self.writes(), [])
        self.assertEqual(result['writes'], 0)
        self.assertIn('Name clashes (nothing written)', text)

    def test_collision_not_provable_stops_too(self):
        reset()
        with mock.patch.object(q, 'preview', return_value=(500, 'dump')):
            rc, result, _, _ = self.run_harness('--package-root', 'ZR1', '--transport', 'FAKK900001', '--only', ONLY)
        self.assertEqual(rc, 1)
        self.assertEqual(result['stages']['collision']['status'], 'error')
        self.assertEqual(result['stages']['sync']['status'], 'blocked')
        self.assertEqual(self.writes(), [])

    def test_clean_install_run_with_evidence(self):
        reset()
        rc, result, text, out = self.run_harness('--package-root', 'ZR1', '--transport', 'FAKK900001', '--only', ONLY)
        stages = result['stages']
        self.assertEqual({k: v['status'] for k, v in stages.items() if v['status'] != 'pass'}, {}, text)
        self.assertEqual(rc, 0)
        self.assertEqual(result['packages']['ZCA_PARAM'], 'ZR1_PARAM')
        self.assertEqual(result['packages']['ZCA_OPS_UI'], 'ZR1_OPS_UI')
        self.assertNotIn('ZCA_OPS_DEMO', result['packages'])
        self.assertEqual(stages['tables']['created'], ['ZCA_PARAM_AREA', 'ZCA_OPS_RUN'])
        self.assertEqual(stages['inventory']['components']['ZCA_PARAM']['installed'], '1.1.0')
        self.assertEqual(stages['licensing']['lic_enforce'], 'W')
        # every write names an object of the run (or activation / ABAP Unit / ATC)
        for method, path in self.writes():
            self.assertRegex(path.lower(), r'(zca_param_area|zcl_ca_param_dao|zif_ca_param_types|zif_ca_ops_types|'
                                           r'zca_ops_run|zc_ca_opsexception|zui_ca_ops_exc|zca_ops_check_run|'
                                           r'/oo/classes$|/oo/interfaces$|/ddic/tables$|/ddic/ddl/sources$|'
                                           r'/ddic/ddlx/sources$|/programs/programs$|/activation$|/abapunit/testruns$|'
                                           r'/atc/(worklists|runs)$)')
        # the parameter framework's sources are written before the framework's
        order = [p for m, p in Fake.state['calls'] if m == 'PUT' and '/source/main' in p]
        self.assertLess(order.index('/sap/bc/adt/oo/interfaces/zif_ca_param_types/source/main'),
                        order.index('/sap/bc/adt/oo/interfaces/zif_ca_ops_types/source/main'))
        files = {f for _, _, fs in os.walk(out) for f in fs}
        self.assertTrue({'summary.md', 'results.json', 'objects.csv', 'collision.json', 'aunit-junit.xml'} <= files)
        for d, _, fs in os.walk(out):
            for f in fs:
                with open(os.path.join(d, f), encoding='utf-8') as handle:
                    self.assertNotIn('secret-pw', handle.read())

    def test_dry_run_writes_nothing(self):
        reset()
        rc, result, _, _ = self.run_harness('--package-root', 'ZR1', '--transport', 'FAKK900001', '--only', ONLY,
                                            '--dry-run')
        stages = result['stages']
        self.assertEqual(self.writes(), [])
        self.assertEqual(stages['sync']['status'], 'pass')
        self.assertGreater(stages['sync']['written'], 0)  # to write
        self.assertEqual(stages['activate']['status'], 'skipped')
        self.assertEqual(stages['aunit']['status'], 'skipped')
        self.assertTrue(result['dry_run'])
        self.assertEqual([o for o in Fake.state['objects'].values() if o], [])
        del rc

    def test_missing_packages_block_the_run(self):
        reset(present=set())
        rc, result, _, _ = self.run_harness('--package-root', 'ZR1', '--transport', 'FAKK900001', '--only', ONLY)
        self.assertEqual(rc, 1)
        self.assertEqual(result['stages']['packages']['status'], 'blocked')
        self.assertEqual(result['stages']['collision']['status'], 'blocked')
        self.assertEqual(self.writes(), [])

    def test_licence_installed_is_not_a_proof(self):
        reset(licences=[{'LICENSE_ID': 'L1', 'ACTIVE': 'X'}])
        _, result, _, _ = self.run_harness('--package-root', 'ZR1', '--transport', 'FAKK900001', '--only', ONLY,
                                           '--stages', 'preflight,connect,inventory,licensing')
        self.assertEqual(result['stages']['licensing']['status'], 'blocked')
        reset(enforce=['X'])
        _, result, _, _ = self.run_harness('--package-root', 'ZR1', '--transport', 'FAKK900001', '--only', ONLY,
                                           '--stages', 'preflight,connect,inventory,licensing')
        self.assertEqual(result['stages']['licensing']['status'], 'fail')


class GuardTest(unittest.TestCase):

    def adt(self, dry=False):
        a = q.Adt('http://127.0.0.1:9', 'u', 'p', '100', write_paths=[r'^/oo/classes/(zcl_ca_ops_store)(/.*)?$',
                                                                       r'^/oo/classes$'], dry_run=dry)
        a.collections, a.creatable = {'/oo/classes'}, {'ZCL_CA_OPS_STORE'}
        return a

    def test_write_outside_the_product_refused(self):
        a = self.adt()
        with self.assertRaises(q.GuardError):
            a.guard('PUT', '/oo/classes/zcl_other/source/main?lockHandle=x')
        with self.assertRaises(q.GuardError):
            a.guard('POST', '/oo/classes?corrNr=X', '<x adtcore:name="ZCL_OTHER"/>')
        a.guard('PUT', '/oo/classes/zcl_ca_ops_store/source/main?lockHandle=x')
        a.guard('POST', '/oo/classes', '<x adtcore:name="ZCL_CA_OPS_STORE"/>')
        a.guard('POST', '/datapreview/freestyle?rowNumber=5')

    def test_dry_run_refuses_every_write(self):
        a = self.adt(dry=True)
        with self.assertRaises(q.GuardError):
            a.guard('PUT', '/oo/classes/zcl_ca_ops_store/source/main')
        a.guard('GET', '/oo/classes/zcl_ca_ops_store/source/main')

    def test_preview_accepts_select_only(self):
        with self.assertRaises(q.GuardError):
            q.preview(self.adt(), "UPDATE tadir SET devclass = 'X'")

    def test_package_mapping(self):
        self.assertEqual(q.map_package('ZCA_OPS_UI', 'ZR1'), 'ZR1_OPS_UI')
        self.assertEqual(q.map_package('ZCA_PARAM', 'ZCA'), 'ZCA_PARAM')
        self.assertEqual(q.map_package('ZCA_PARAM', '$ZR1'), '$ZR1_PARAM')


class AunitVerdictTest(unittest.TestCase):
    """An alert outside a test method (class_setup) fails the run; a clean run stays green; JUnit is well formed."""

    def test_verdicts(self):
        clean = ('<aunit:runResult xmlns:aunit="http://www.sap.com/adt/aunit" xmlns:adtcore="http://www.sap.com/adt/core">'
                 '<program adtcore:name="P"><testClasses><testClass adtcore:name="C"><testMethods>'
                 '<testMethod adtcore:name="M"/></testMethods></testClass></testClasses></program></aunit:runResult>')
        broken = clean.replace('<testMethods>', '<alerts><alert kind="exception" severity="critical">'
                               '<title>&lt;CX&amp;"x"&gt;</title></alert></alerts><testMethods>')
        for xml, expected in ((clean, 0), (broken, 1)):
            cases, fails = q.aunit_cases(ET.fromstring(xml))
            path = os.path.join(tempfile.mkdtemp(), 'j.xml')
            q.write_junit(path, cases)
            ET.parse(path)
            self.assertEqual(len(fails), expected)
            self.assertEqual(sum(1 for c in cases if c[3]), 1)


if __name__ == '__main__':
    unittest.main()
