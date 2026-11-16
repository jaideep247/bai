#!/usr/bin/env python3
"""Install harness of the product: installs the parameter framework and then the operations framework (never a
consumer) into sandbox packages through the ADT REST API, in the import order of the release manifest, then
activates and runs ABAP Unit, ATC and the CDS / OData and licensing checks, and writes the evidence into
ops-framework/release/qualification/<release>/<UTC>/ (summary.md, results.json and the system's raw answers).

Adapted from the qualification harness of the repository jaideep247/zcd-test-tool (ci/qualify/qualify.py, proven on
the reference system A4H): the logon, TLS pin, CSRF handling, object creation, source sync, text, message, settings,
activation, ABAP Unit and ATC calls are that harness's; the manifest-driven object list, the package mapping, the
write guard, the collision test, the dictionary prerequisites, the CDS / OData, inventory and licensing stages are
new here (their ADT and OData endpoints are VERIFY V203 until a run on A4H shows them).

First principle: the harness may change only development objects of the product in the packages the user names;
everything else it only reads. Analogy: a fitter with a key to one empty flat - it checks the name on every door
first and leaves at once if any of its furniture already stands in somebody else's flat.

Stages (each records pass / fail / blocked / error / skipped with its evidence; default order):
  preflight  offline: the manifest check (tools/release_manifest.py --check) and the object list of the run
  connect    ADT discovery, logon, CSRF token, system information (release recorded against the manifest)
  packages   the target packages exist (they are created by the user, never by the harness)
  collision  every product object name in TADIR of the system (data preview, read only): an object with the same
             name and type (or a type sharing its name space) in a package outside the target packages is a clash -
             the run stops before anything is written
  ddic       objects the harness does not create (domains, data elements, message classes, authorization objects and
             fields, object class) exist - else import the component with abapGit first
  tables     create the missing tables from their DDL source (ddic/*.tabl.ddl); existing tables are left alone
  sync       write the sources (classes, interfaces, CDS, access controls, metadata extensions, behaviour,
             services, programs) where the system differs, each object locked in the transport request
  texts      selection texts of the programs
  messages   messages of the message classes
  settings   technical settings of the tables (data class, logging)
  activate   mass activation of the inactive product objects, component by component in the import order
  inventory  installed version constants against the manifest, inactive product objects
  aunit      ABAP Unit of the target packages
  atc        ATC with the check variant on the target packages
  cds        every CDS source of the product exists and is active
  odata      every service binding <service definition>_O4 answers its OData V4 metadata
  licensing  activation proven without a licence: no licence installed, LIC_ENFORCE = W (or not set: default W)
             and the activation of this run (or no inactive product object) - V208

Safety: --package-root and --transport are mandatory (the run refuses to start without them); --dry-run reads
only (no write, no activation, no ABAP Unit / ATC run); every write goes through a guard that accepts only the ADT
paths of the product's own objects and refuses anything else; the harness has no call that writes table contents
(no business data, no configuration rows - seed rows are entered by the user, docs/RELEASE_AND_INSTALL.md).

Logon from the environment, never from arguments or files:
  SAP_URL / SAP_USER / SAP_PASSWORD / SAP_CLIENT (or ZCA_TT_A4H_URL / _USER / _PASSWORD / _CLIENT), optional
  SAP_TLS_PIN (or ZCA_TT_A4H_TLS_PIN): SHA-256 fingerprint of a self-signed test system's certificate.
The password is sent only in the Authorization header and never written.

  python qualify.py --package-root ZR1 --transport A4HK900123 [--stages ...] [--dry-run] [--with-demo]
                    [--variant DEFAULT] [--max-priority 2] [--only REGEX] [--out DIR]

Standard library only (Python 3.13 on Windows; run.ps1 next to this file).

Modification log:
2026-11-15 | Initial version (build M: clean install and release baseline), adapted from the test tool's harness.
"""
import argparse
import base64
import datetime
import hashlib
import html
import http.client
import http.cookiejar
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from xml.sax.saxutils import quoteattr

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import abaptools  # noqa: E402

RM = abaptools.fresh('release_manifest', 'qualify')
MANIFEST = os.path.join(ROOT, 'ops-framework', 'release', 'manifest.json')
EVIDENCE = os.path.join(ROOT, 'ops-framework', 'release', 'qualification')
DEFAULT_STAGES = ('preflight,connect,packages,collision,ddic,tables,sync,texts,messages,settings,activate,inventory,'
                  'aunit,atc,cds,odata,licensing')
WRITING = {'tables', 'sync', 'texts', 'messages', 'settings', 'activate'}
SYSTEM_RUNS = {'aunit', 'atc'}
NOT_CREATED = ('doma', 'dtel', 'msag', 'suso', 'auth', 'susc')
TADIR_TYPE = {'clas': 'CLAS', 'intf': 'INTF', 'tabl': 'TABL', 'dtel': 'DTEL', 'doma': 'DOMA', 'ddls': 'DDLS',
              'ddlx': 'DDLX', 'dcls': 'DCLS', 'bdef': 'BDEF', 'srvd': 'SRVD', 'prog': 'PROG', 'msag': 'MSAG',
              'suso': 'SUSO', 'auth': 'AUTH', 'susc': 'SUSC'}
# TADIR types that share one name space (a DDIC type name, a class pool name)
NAME_SPACES = [{'TABL', 'DTEL', 'DDLS', 'TTYP', 'VIEW'}, {'CLAS', 'INTF'}]
SOURCE_BASE = {'clas': '/oo/classes', 'intf': '/oo/interfaces', 'ddls': '/ddic/ddl/sources',
               'ddlx': '/ddic/ddlx/sources', 'dcls': '/acm/dcl/sources', 'bdef': '/bo/behaviordefinitions',
               'srvd': '/ddic/srvd/sources', 'prog': '/programs/programs'}
SOURCE_EXT = {'clas': 'clas.abap', 'intf': 'intf.abap', 'ddls': 'ddls.asddls', 'ddlx': 'ddlx.asddlxs',
              'dcls': 'dcls.asdcls', 'bdef': 'bdef.asbdef', 'srvd': 'srvd.srvdsrv', 'prog': 'prog.abap'}
INCLUDES = {'locals_def': 'includes/definitions', 'locals_imp': 'includes/implementations',
            'macros': 'includes/macros', 'testclasses': 'includes/testclasses'}
# order of the sync inside a component: types interface, exception classes, interfaces, CDS, DCL, DDLX, BDEF, SRVD,
# classes, programs (the source harness's order)
RANK = ['intf', 'clas:zcx', 'ddls', 'dcls', 'ddlx', 'bdef', 'srvd', 'clas', 'prog']
READ_ONLY_POST = (re.compile(r'^/datapreview/freestyle\b'), re.compile(r'^/cts/transportchecks$'))


def env(*names, required=True):
    for n in names:
        if os.environ.get(n):
            return os.environ[n]
    if required:
        raise SystemExit(f"missing environment variable {' or '.join(names)}")
    return ''


class GuardError(Exception):
    """A call the harness must never send (a write outside the product's objects, or any write in a dry run)."""


class PinnedHandler(urllib.request.HTTPSHandler):
    def __init__(self, pin, ctx):
        super().__init__(context=ctx)
        self.pin = pin

    def https_open(self, req):
        pin = self.pin

        class Conn(http.client.HTTPSConnection):
            def connect(self):
                super().connect()
                seen = hashlib.sha256(self.sock.getpeercert(binary_form=True)).hexdigest()
                if seen != pin:
                    self.sock.close()
                    raise ssl.SSLError(f'certificate fingerprint {seen} is not the pinned one')
        return self.do_open(Conn, req, context=self._context)


class Adt:
    """ADT client of the source harness with a write guard: write_paths = regular expressions of the paths a
    non-GET call may use (read-only POSTs always allowed); dry_run = only GET and read-only POSTs."""

    def __init__(self, url, user, password, client, write_paths=(), dry_run=False):
        self.base = url.rstrip('/') + '/sap/bc/adt'
        self.client = client
        self.token = 'Fetch'
        self.stateful = False
        self.dry_run = dry_run
        self.write_paths = [re.compile(p, re.I) for p in write_paths]
        self.collections = set()
        self.creatable = set()
        self.calls = []
        self.auth = 'Basic ' + base64.b64encode(f'{user}:{password}'.encode()).decode()
        ctx = ssl.create_default_context()
        pin = env('SAP_TLS_PIN', 'ZCA_TT_A4H_TLS_PIN', required=False).replace(':', '').lower()
        handler = urllib.request.HTTPSHandler(context=ctx)
        if pin:
            # Self-signed test system: the certificate is pinned by its SHA-256 fingerprint instead of a CA chain
            ctx.check_hostname, ctx.verify_mode = False, ssl.CERT_NONE
            handler = PinnedHandler(pin, ctx)
        if url.lower().startswith('http://') and not re.match(r'http://(127\.0\.0\.1|localhost)[:/]', url.lower()):
            print('WARNING: plain HTTP sends the logon unencrypted; use the HTTPS port', file=sys.stderr)
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()), handler)

    def guard(self, method, path, body=None):
        if method == 'GET':
            return
        bare = path.split('?')[0]
        if any(p.match(bare) for p in READ_ONLY_POST) and method == 'POST':
            return
        if self.dry_run:
            raise GuardError(f'dry run: {method} {path} refused')
        if not any(p.match(bare) for p in self.write_paths):
            raise GuardError(f'{method} {bare}: not a path of a product object - refused')
        if bare in self.collections and method == 'POST':
            # a create on a collection: the object named in the body must be one of the run
            name = re.search(r'adtcore:name="([^"]+)"', body or '')
            if not name or name.group(1).upper() not in self.creatable:
                raise GuardError(f'create of {name.group(1) if name else "an unnamed object"} on {bare} refused')

    def call(self, method, path, body=None, ctype=None, accept='*/*', timeout=600):
        self.guard(method, path, body if isinstance(body, str) else None)
        self.calls.append((method, path.split('?')[0]))
        tries = 3 if method == 'GET' else 1
        for attempt in range(tries):
            try:
                result = self._call(method, path, body, ctype, accept, timeout)
                if result[0] == 403 and 'CSRF' in result[1] and method != 'GET':
                    self.token = 'Fetch'
                    self._call('GET', '/discovery', None, None, 'application/atomsvc+xml', 60)
                    result = self._call(method, path, body, ctype, accept, timeout)
                return result
            except (urllib.error.URLError, ConnectionError, TimeoutError):
                if attempt == tries - 1:
                    raise
                time.sleep(2 * (attempt + 1))
        return 0, '', {}

    def _call(self, method, path, body=None, ctype=None, accept='*/*', timeout=600):
        url = (self.base[:-len('/sap/bc/adt')] + path) if path.startswith('/sap/') else self.base + path
        req = urllib.request.Request(url, data=body.encode() if isinstance(body, str) else body, method=method)
        req.add_header('Authorization', self.auth)
        req.add_header('sap-client', self.client)
        req.add_header('X-CSRF-Token', self.token)
        req.add_header('Accept', accept)
        if self.stateful:
            req.add_header('X-sap-adt-sessiontype', 'stateful')
        if ctype:
            req.add_header('Content-Type', ctype)
        try:
            with self.opener.open(req, timeout=timeout) as r:
                tok = r.headers.get('x-csrf-token')
                if tok and tok.lower() != 'required':
                    self.token = tok
                return r.status, r.read().decode('utf-8', 'replace'), dict(r.headers)
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode('utf-8', 'replace'), dict(e.headers or {})


# ------------------------------------------------------------------------------------------------ the run
class Run:
    """The objects of the run (manifest packs in import order), the package mapping and the evidence folder."""

    def __init__(self, args, manifest, objects):
        self.args = args
        self.manifest = manifest
        packs = {p['id']: p for p in manifest['packs']}
        wanted = [pid for pid in manifest['import_order'] if packs[pid]['status'] == 'release'
                  and (packs[pid].get('production', True) or args.with_demo)]
        self.packs = wanted
        objs = [o for o in objects if o['pack'] in wanted]
        if args.only:
            objs = [o for o in objs if re.search(args.only, o['name'], re.I)]
        self.objects = sorted(objs, key=lambda o: (wanted.index(o['pack']), rank(o), o['name']))
        self.package = {o['package']: map_package(o['package'], args.package_root) for o in objects
                        if o['pack'] in wanted}
        self.names = {o['name'] for o in objects}
        self.ctx = {}

    def target(self, obj):
        return self.package[obj['package']]

    def write_paths(self):
        """Paths a write may use: the ADT paths of the run's objects (and their collections for a create with the
        object's name in the body), activation, ABAP Unit and ATC."""
        names = '|'.join(re.escape(o['name'].lower()) for o in self.objects) or 'x^'
        bases = '|'.join(re.escape(b) for b in list(SOURCE_BASE.values()) +
                         ['/ddic/tables', '/ddic/db/settings', '/messageclass', '/textelements/programs'])
        return [rf'^({bases})/({names})(/.*)?$', rf'^({bases})$', r'^/activation$', r'^/abapunit/testruns$',
                r'^/atc/(worklists|runs)$']


def map_package(package, root):
    """Target package of a product package: the product prefix ZCA replaced by the root (ZCA keeps the names)."""
    root = root.upper()
    return package if root == 'ZCA' else root + package[3:]


def rank(obj):
    key = 'clas:zcx' if obj['type'] == 'clas' and obj['name'].startswith('ZCX') else obj['type']
    if obj['type'] == 'intf' and obj['name'].endswith('_TYPES'):
        return -1
    return RANK.index(key) if key in RANK else len(RANK)


def validate_args(args, manifest, objects):
    """Refusals before any connection."""
    problems = []
    root = (args.package_root or '').upper()
    if not root:
        problems.append('--package-root is mandatory (the sandbox packages the product is installed into)')
    elif not re.fullmatch(r'\$?[ZY][A-Z0-9_]{1,25}|/[A-Z0-9]{3,8}/[A-Z0-9_]{0,20}', root):
        problems.append(f'--package-root {root}: must start with Z, Y, $Z, $Y or a registered namespace')
    if not args.transport:
        problems.append('--transport is mandatory (a modifiable request of the sandbox, or LOCAL for $ packages)')
    elif args.transport.upper() == 'LOCAL' and root and not root.startswith('$'):
        problems.append('--transport LOCAL only with local packages ($...)')
    elif args.transport.upper() != 'LOCAL' and not re.fullmatch(r'[A-Z0-9]{3}K[0-9]{6}', args.transport.upper()):
        problems.append(f'--transport {args.transport}: not a request number (e.g. A4HK900123)')
    if root:
        for pkg in sorted({o['package'] for o in objects}):
            if len(map_package(pkg, root)) > 30:
                problems.append(f'package {map_package(pkg, root)}: longer than 30 characters')
    folders = {os.path.normpath(os.path.join(ROOT, c['folder'])) for c in manifest['components']}
    for o in objects:
        for f in o['files']:
            if not any(os.path.normpath(f).startswith(d + os.sep) for d in folders):
                problems.append(f'{f}: outside the product components - refused')
    return problems


def read(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def strip(text):
    return re.sub(r'<[^>]+>', ' ', text or '')[:300]


def transport(run):
    tr = run.args.transport.upper()
    return '' if tr == 'LOCAL' else tr


# ------------------------------------------------------------------------------------------------ stages
def stage_preflight(adt, run, out):
    failures = RM.check(ROOT, MANIFEST)
    counts = {}
    for o in run.objects:
        counts[o['pack']] = counts.get(o['pack'], 0) + 1
    res = {'release': run.manifest['release'], 'packs': run.packs, 'objects_by_pack': counts,
           'packages': run.package, 'manifest_failures': failures[:50]}
    with open(os.path.join(out, 'objects.csv'), 'w', encoding='utf-8', newline='\n') as handle:
        handle.write('PACK,TYPE,NAME,TARGET_PACKAGE\n')
        handle.writelines(f'{o["pack"]},{o["type"]},{o["name"]},{run.target(o)}\n' for o in run.objects)
    res['status'] = 'pass' if not failures and run.objects else 'fail'
    res['detail'] = (f'{len(run.objects)} objects of {", ".join(run.packs)} into {len(set(run.package.values()))} '
                     f'packages; manifest {"valid" if not failures else f"{len(failures)} problem(s)"}')
    return res


def stage_connect(adt, run, out):
    code, _, _ = adt.call('GET', '/discovery', accept='application/atomsvc+xml')
    if code != 200:
        return {'status': 'fail' if code in (401, 403) else 'error', 'detail': f'ADT discovery answered {code}'}
    code2, body2, _ = adt.call('GET', '/system/information', accept='application/json')
    info = {}
    if code2 == 200:
        try:
            info = json.loads(body2)
        except ValueError:
            info = {}
    system = {k: v for k, v in info.items() if k in ('systemID', 'client', 'release', 'kernelRelease',
                                                     'databaseSystem', 'SAPRelease')}
    run.ctx['system'] = system
    return {'status': 'pass', 'detail': f'logon and CSRF token; system {system.get("systemID", "?")} release '
                                        f'{system.get("release") or system.get("SAPRelease") or "unavailable"}',
            'csrf': adt.token != 'Fetch', 'system': system or 'unavailable',
            'supported_releases': [(r['id'], r['status']) for r in run.manifest['supported_releases']]}


def quick(adt, query, kind=None, limit=50):
    q = f'/repository/informationsystem/search?operation=quickSearch&query={urllib.parse.quote(query)}' \
        f'&maxResults={limit}' + (f'&objectType={kind}' if kind else '')
    code, body, _ = adt.call('GET', q, accept='application/xml')
    found = re.findall(r'adtcore:name="([^"]+)"', body) if code == 200 else []
    return code, [n.upper() for n in found]


def stage_packages(adt, run, out):
    missing, res = [], {}
    for pkg in sorted(set(run.package.values())):
        code, names = quick(adt, pkg, 'DEVC/K', 10)
        res[pkg] = 'present' if pkg in names else (f'absent' if code == 200 else f'search answered {code}')
        if pkg not in names:
            missing.append(pkg)
    if missing:
        return {'status': 'blocked', 'packages': res,
                'detail': f'create the packages first (SE21 / ADT, software component and transport layer of the '
                          f'sandbox; sub-packages under their parent): {", ".join(missing)}'}
    return {'status': 'pass', 'packages': res, 'detail': f'{len(res)} target packages present'}


def preview(adt, sql, rows=1000):
    """Rows of a read-only ABAP SQL statement (ADT data preview, as the source harness's probe): (code, [dict])."""
    if not re.match(r'\s*SELECT\b', sql, re.I):
        raise GuardError('only SELECT statements in the data preview')
    code, body, _ = adt.call('POST', f'/datapreview/freestyle?rowNumber={rows}', sql, 'text/plain',
                             'application/xml, application/vnd.sap.adt.datapreview.table.v1+xml')
    if code != 200:
        return code, strip(body)
    ns = {'dp': 'http://www.sap.com/adt/dataPreview'}
    root = ET.fromstring(body)
    cols = root.findall('dp:columns', ns)
    names = [c.find('dp:metadata', ns).get(f'{{{ns["dp"]}}}name').upper() for c in cols]
    data = [[d.text or '' for d in c.find('dp:dataSet', ns).findall('dp:data', ns)] for c in cols]
    return code, [dict(zip(names, [col[i] for col in data])) for i in range(len(data[0]) if data else 0)]


def stage_collision(adt, run, out):
    """Product names in TADIR outside the target packages. Same name and type, or a type of the same name space,
    is a clash; the run stops before writing anything."""
    targets = set(run.package.values())
    by_name = {}
    for o in run.objects:
        if o['type'] in TADIR_TYPE:
            by_name.setdefault(o['name'], []).append(TADIR_TYPE[o['type']])
    names = sorted(by_name)
    clashes, present, chunk = [], {}, 40
    for i in range(0, len(names), chunk):
        part = names[i:i + chunk]
        sql = ("SELECT pgmid, object, obj_name, devclass FROM tadir WHERE pgmid = 'R3TR' AND obj_name IN ( "
               + ', '.join("'" + n.replace("'", '') + "'" for n in part) + ' )')
        code, rows = preview(adt, sql)
        if code != 200:
            return {'status': 'error', 'detail': f'TADIR not readable (data preview HTTP {code}: {rows}); no proof '
                                                 'that the names are free - nothing is written (VERIFY V203)'}
        for row in rows:
            name, kind, pkg = row.get('OBJ_NAME', '').upper(), row.get('OBJECT', '').upper(), \
                row.get('DEVCLASS', '').upper()
            mine = by_name.get(name, [])
            space = set().union(*[s for s in NAME_SPACES if any(k in s for k in mine)]) | set(mine)
            if kind not in space:
                continue
            if pkg in targets:
                present.setdefault(name, []).append(kind)
            else:
                clashes.append({'name': name, 'product_type': '/'.join(mine), 'system_type': kind, 'package': pkg})
    run.ctx['present'] = present
    with open(os.path.join(out, 'collision.json'), 'w', encoding='utf-8') as handle:
        json.dump({'checked': len(names), 'clashes': clashes, 'in_target_packages': len(present)}, handle, indent=1)
    if clashes:
        return {'status': 'fail', 'clashes': clashes[:200],
                'detail': f'{len(clashes)} product name(s) already used outside the target packages - nothing '
                          'written; rename on the system side or decide on the product names (R1-D1)'}
    return {'status': 'pass', 'checked': len(names), 'in_target_packages': len(present),
            'detail': f'{len(names)} names checked, none outside the target packages ({len(present)} already in them)'}


def stage_ddic(adt, run, out):
    missing = []
    for o in run.objects:
        if o['type'] not in NOT_CREATED:
            continue
        if o['name'] in run.ctx.get('present', {}):
            continue
        code, names = quick(adt, o['name'], None, 20)
        if o['name'] not in names:
            missing.append(f'{o["type"]} {o["name"]}')
    if missing:
        return {'status': 'blocked', 'missing': missing,
                'detail': f'{len(missing)} objects the harness does not create: import the component with abapGit '
                          f'(offline ZIP) first, then run the harness again'}
    return {'status': 'pass', 'detail': 'domains, data elements, message classes, authorization objects present'}


def lock(adt, uri):
    code, resp, _ = adt.call('POST', f'{uri}?_action=LOCK&accessMode=MODIFY',
                             accept='application/*,application/vnd.sap.as+xml;charset=UTF-8;'
                                    'dataname=com.sap.adt.lock.result')
    m = re.search(r'<LOCK_HANDLE>([^<]+)</LOCK_HANDLE>', resp)
    return (m.group(1) if code == 200 and m else None), code, resp


def unlock(adt, uri, handle):
    try:
        adt.call('POST', f'{uri}?_action=UNLOCK&lockHandle={urllib.parse.quote(handle)}')
    except (urllib.error.URLError, ConnectionError, TimeoutError):
        pass


def qparams(handle, tr):
    return f'lockHandle={urllib.parse.quote(handle)}' + (f'&corrNr={tr}' if tr else '')


def table_ddl(obj):
    """DDL source of a table: ddic/<name>.tabl.ddl of its component (the serializer's source), found by name."""
    comp = obj['files'][0].split(os.sep + 'src' + os.sep)[0]
    for d, _, names in os.walk(os.path.join(comp, 'ddic')):
        if f'{obj["name"].lower()}.tabl.ddl' in names:
            return read(os.path.join(d, f'{obj["name"].lower()}.tabl.ddl'))
    return None


def stage_tables(adt, run, out):
    adt.stateful = not run.args.dry_run
    tr = transport(run)
    created, failed, present = [], [], 0
    for o in [x for x in run.objects if x['type'] == 'tabl']:
        uri = f'/ddic/tables/{o["name"].lower()}'
        code, _, _ = adt.call('GET', f'{uri}/source/main', accept='text/plain')
        if code == 200:
            present += 1
            continue
        ddl = table_ddl(o)
        if ddl is None:
            failed.append({'object': o['name'], 'step': 'source', 'http': 0, 'text': 'no ddic/*.tabl.ddl source'})
            continue
        if run.args.dry_run:
            created.append(o['name'])
            continue
        body = ('<?xml version="1.0" encoding="UTF-8"?><blue:blueSource xmlns:blue="http://www.sap.com/wbobj/blue" '
                f'xmlns:adtcore="http://www.sap.com/adt/core" adtcore:description="{o["name"]}" '
                f'adtcore:name="{o["name"]}" adtcore:type="TABL/DT"><adtcore:packageRef adtcore:name="{run.target(o)}"/>'
                '</blue:blueSource>')
        ccode, resp, _ = adt.call('POST', '/ddic/tables' + (f'?corrNr={tr}' if tr else ''), body,
                                  ctype='application/vnd.sap.adt.tables.v2+xml')
        if ccode not in (200, 201):
            failed.append({'object': o['name'], 'step': 'create', 'http': ccode, 'text': strip(resp)})
            continue
        handle, lcode, resp = lock(adt, uri)
        if not handle:
            failed.append({'object': o['name'], 'step': 'lock', 'http': lcode, 'text': strip(resp)})
            continue
        try:
            pcode, resp, _ = adt.call('PUT', f'{uri}/source/main?{qparams(handle, tr)}', ddl,
                                      ctype='text/plain; charset=utf-8')
            if pcode in (200, 204):
                created.append(o['name'])
            else:
                failed.append({'object': o['name'], 'step': 'source', 'http': pcode, 'text': strip(resp)})
        finally:
            unlock(adt, uri, handle)
    adt.stateful = False
    return {'status': 'pass' if not failed else 'fail', 'created': created, 'failed': failed,
            'detail': f'{len(created)} {"to create" if run.args.dry_run else "created"}, {present} present, '
                      f'{len(failed)} failed'}


def norm(text):
    return '\n'.join(line.rstrip() for line in text.replace('\r\n', '\n').strip().split('\n')).lower()


def source_parts(obj):
    """{ADT include path: source} of a source object."""
    main = next((f for f in obj['files'] if f.endswith('.' + SOURCE_EXT[obj['type']])
                 and os.path.basename(f).count('.') == 2), None)
    parts = {'source/main': read(main)} if main else {}
    if obj['type'] == 'clas':
        for suffix, path in INCLUDES.items():
            f = next((x for x in obj['files'] if x.endswith(f'.clas.{suffix}.abap')), None)
            if f:
                parts[path] = read(f)
    return parts


def description(obj):
    for f in obj['files']:
        if f.endswith('.xml'):
            m = re.search(r'<(DESCRIPT|DDTEXT|ENTRY)>([^<]*)</\1>', read(f))
            if m:
                return html.unescape(m.group(2))
    return obj['name']


CREATE = {
    'clas': ('/oo/classes', 'application/vnd.sap.adt.oo.classes.v4+xml',
             '<class:abapClass xmlns:class="http://www.sap.com/adt/oo/classes" xmlns:adtcore="http://www.sap.com/adt/core" '
             'adtcore:description={d} adtcore:name="{n}" adtcore:type="CLAS/OC" class:final="true" '
             'class:visibility="public"><adtcore:packageRef adtcore:name="{p}"/></class:abapClass>'),
    'intf': ('/oo/interfaces', 'application/vnd.sap.adt.oo.interfaces.v5+xml',
             '<intf:abapInterface xmlns:intf="http://www.sap.com/adt/oo/interfaces" '
             'xmlns:adtcore="http://www.sap.com/adt/core" adtcore:description={d} adtcore:name="{n}" '
             'adtcore:type="INTF/OI"><adtcore:packageRef adtcore:name="{p}"/></intf:abapInterface>'),
    'ddlx': ('/ddic/ddlx/sources', 'application/vnd.sap.adt.ddic.ddlx.v1+xml',
             '<ddlx:ddlxSource xmlns:ddlx="http://www.sap.com/adt/ddic/ddlxsources" '
             'xmlns:adtcore="http://www.sap.com/adt/core" adtcore:description={d} adtcore:name="{n}" '
             'adtcore:type="DDLX/EX"><adtcore:packageRef adtcore:name="{p}"/></ddlx:ddlxSource>'),
    'prog': ('/programs/programs', 'application/*',
             '<program:abapProgram xmlns:program="http://www.sap.com/adt/programs/programs" '
             'xmlns:adtcore="http://www.sap.com/adt/core" adtcore:description={d} adtcore:name="{n}" '
             'adtcore:type="PROG/P"><adtcore:packageRef adtcore:name="{p}"/></program:abapProgram>'),
    'ddls': ('/ddic/ddl/sources', 'application/vnd.sap.adt.ddlSource+xml',
             '<ddl:ddlSource xmlns:ddl="http://www.sap.com/adt/ddic/ddlsources" '
             'xmlns:adtcore="http://www.sap.com/adt/core" adtcore:description={d} adtcore:name="{n}" '
             'adtcore:type="DDLS/DF"><adtcore:packageRef adtcore:name="{p}"/></ddl:ddlSource>'),
}


def create(adt, run, obj, tr):
    """Creates a missing class, interface, CDS view, metadata extension or program (empty), as the source harness;
    access controls, behaviour and service definitions come from abapGit (0 = not supported)."""
    spec = CREATE.get(obj['type'])
    if not spec:
        return 0
    path, ctype, body = spec
    xml_body = '<?xml version="1.0" encoding="UTF-8"?>' + body.format(
        d=quoteattr(description(obj)[:60]), n=obj['name'], p=run.target(obj))
    return adt.call('POST', path + (f'?corrNr={tr}' if tr else ''), xml_body, ctype=ctype)[0]


def sync_one(adt, run, obj, tr):
    uri = f'{SOURCE_BASE[obj["type"]]}/{obj["name"].lower()}'
    parts = source_parts(obj)
    diffs = []
    for path, src in parts.items():
        code, body, _ = adt.call('GET', f'{uri}/{path}?version=inactive', accept='text/plain')
        if code != 200 or norm(body) != norm(src):
            diffs.append(path)
    if not diffs:
        return 'same', None
    if run.args.dry_run:
        return 'changed', {'object': obj['name'], 'parts': diffs}
    exists = adt.call('GET', uri, accept='*/*')[0] != 404
    handle, code, resp = (None, 404, '') if not exists else lock(adt, uri)
    if not handle and code == 404:
        ccode = create(adt, run, obj, tr)
        if ccode in (200, 201):
            handle, code, resp = lock(adt, uri)
        else:
            return 'failed', {'object': obj['name'], 'step': 'create', 'http': ccode,
                              'text': 'not created by the harness: import the component with abapGit' if not ccode
                              else 'create refused'}
    if not handle:
        return 'failed', {'object': obj['name'], 'step': 'lock', 'http': code, 'text': strip(resp)}
    try:
        for path in diffs:
            code, resp, _ = adt.call('PUT', f'{uri}/{path}?{qparams(handle, tr)}', parts[path],
                                     ctype='text/plain; charset=utf-8')
            if path.startswith('includes/') and (code == 404 or (code == 500 and 'inactive version' in resp)):
                inc = path.split('/')[1]
                cbody = ('<?xml version="1.0" encoding="UTF-8"?><class:abapClassInclude '
                         'xmlns:class="http://www.sap.com/adt/oo/classes" xmlns:adtcore="http://www.sap.com/adt/core" '
                         f'adtcore:name="dummy" class:includeType="{inc}"/>')
                adt.call('POST', f'{uri}/includes?{qparams(handle, tr)}', cbody,
                         ctype='application/vnd.sap.adt.oo.classincludes+xml')
                code, resp, _ = adt.call('PUT', f'{uri}/{path}?{qparams(handle, tr)}', parts[path],
                                         ctype='text/plain; charset=utf-8')
            if code not in (200, 204):
                return 'failed', {'object': obj['name'], 'step': path, 'http': code, 'text': strip(resp)}
        return 'changed', {'object': obj['name'], 'parts': diffs}
    finally:
        unlock(adt, uri, handle)


def stage_sync(adt, run, out):
    adt.stateful = not run.args.dry_run
    tr = transport(run)
    objs = [o for o in run.objects if o['type'] in SOURCE_BASE]
    changed, same, failed = [], 0, []
    for i, obj in enumerate(objs, start=1):
        try:
            kind, info = sync_one(adt, run, obj, tr)
        except (urllib.error.URLError, ConnectionError, TimeoutError) as x:
            kind, info = 'failed', {'object': obj['name'], 'step': 'connection', 'http': 0, 'text': str(x)[:200]}
        print(f'sync {i}/{len(objs)} {obj["name"]}: {kind}', file=sys.stderr, flush=True)
        if kind == 'same':
            same += 1
        elif kind == 'changed':
            changed.append(info)
        else:
            failed.append(info)
    adt.stateful = False
    return {'status': 'pass' if not failed else 'fail', 'transport': tr or 'LOCAL', 'dry_run': run.args.dry_run,
            'unchanged': same, 'written': len(changed), 'failed': failed[:100], 'changed': changed[:400],
            'detail': f'{len(changed)} {"to write" if run.args.dry_run else "written"}, {same} unchanged, '
                      f'{len(failed)} failed'}


SEL_TYPE = 'application/vnd.sap.adt.textelements.selections.v1'


def selections(obj):
    xml = next((read(f) for f in obj['files'] if f.endswith('.prog.xml')), '')
    sel = {}
    for item in re.findall(r'<item>(.*?)</item>', xml, re.S):
        if re.search(r'<ID>S</ID>', item):
            key = re.search(r'<KEY>([^<]+)</KEY>', item).group(1)
            entry = re.search(r'<ENTRY>([^<]*)</ENTRY>', item).group(1)
            sel[key] = html.unescape(entry)
    return sel


def stage_texts(adt, run, out):
    adt.stateful = not run.args.dry_run
    tr = transport(run)
    written, same, failed = [], 0, []
    for obj in [o for o in run.objects if o['type'] == 'prog']:
        sel = selections(obj)
        if not sel:
            continue
        name = obj['name'].lower()
        tpath = f'/textelements/programs/{name}/source/selections'
        code, body, _ = adt.call('GET', tpath, accept=SEL_TYPE)
        if code != 200:
            failed.append({'object': obj['name'], 'step': 'read', 'http': code})
            continue
        current = dict(re.findall(r'^(\S+)\s*=(.*)$', body.replace('\r', ''), re.M))
        if all(current.get(k, '').strip() == (v[8:].strip() if v[:8].strip() == '' else v.strip())
               for k, v in sel.items()):
            same += 1
            continue
        if run.args.dry_run:
            written.append(obj['name'])
            continue
        text = '\n'.join(f'{k:<8}={v[8:].strip() if v[:8].strip() == "" else v.strip()}' for k, v in sorted(sel.items()))
        lock_uri = f'/textelements/programs/{name}'
        handle, code, resp = lock(adt, lock_uri)
        if not handle:
            lock_uri = f'/programs/programs/{name}'
            handle, code, resp = lock(adt, lock_uri)
        if not handle:
            failed.append({'object': obj['name'], 'step': 'lock', 'http': code, 'text': strip(resp)})
            continue
        try:
            code, resp, _ = adt.call('PUT', f'{tpath}?{qparams(handle, tr)}', text, ctype=SEL_TYPE + '; charset=utf-8')
            (written if code in (200, 204) else failed).append(
                obj['name'] if code in (200, 204) else {'object': obj['name'], 'step': 'write', 'http': code,
                                                         'text': strip(resp)})
        finally:
            unlock(adt, lock_uri, handle)
    adt.stateful = False
    return {'status': 'pass' if not failed else 'fail', 'written': written, 'failed': failed,
            'detail': f'{len(written)} {"to write" if run.args.dry_run else "written"}, {same} unchanged, '
                      f'{len(failed)} failed'}


def stage_messages(adt, run, out):
    tr = transport(run)
    added, changed, failed = [], [], []
    for obj in [o for o in run.objects if o['type'] == 'msag']:
        xml = next((read(f) for f in obj['files'] if f.endswith('.msag.xml')), '')
        repo = {k: html.unescape(v) for k, v in re.findall(r'<MSGNR>(\d+)</MSGNR>\s*<TEXT>([^<]*)</TEXT>', xml)}
        uri = f'/messageclass/{obj["name"].lower()}'
        code, body, hdr = adt.call('GET', uri, accept='*/*')
        if code != 200:
            failed.append({'object': obj['name'], 'step': 'read', 'http': code, 'text': strip(body)})
            continue
        have = {m.group(1): html.unescape(m.group(2)) for m in re.finditer(r'mc:msgno="(\d+)" mc:msgtext="([^"]*)"', body)}
        new, mine_add, mine_chg = body, [], []
        for no, text in sorted(repo.items()):
            if no not in have:
                new = new.replace('</mc:messageClass>', f'<mc:messages mc:msgno="{no}" mc:msgtext={quoteattr(text)} '
                                  'mc:selfexplainatory="true" mc:documented="false" adtcore:name=""/></mc:messageClass>')
                mine_add.append(no)
            elif have[no].strip() != text.strip():
                new = re.sub(rf'(mc:msgno="{no}" mc:msgtext=)"[^"]*"', lambda m, t=text: m.group(1) + quoteattr(t), new)
                mine_chg.append(no)
        if not mine_add and not mine_chg:
            continue
        if run.args.dry_run:
            added += [f'{obj["name"]}/{n}' for n in mine_add]
            changed += [f'{obj["name"]}/{n}' for n in mine_chg]
            continue
        ctype = next((v for k, v in hdr.items() if k.lower() == 'content-type'), 'application/xml')
        adt.stateful = True
        handle, lcode, resp = lock(adt, uri)
        try:
            if not handle:
                failed.append({'object': obj['name'], 'step': 'lock', 'http': lcode, 'text': strip(resp)})
                continue
            pcode, resp, _ = adt.call('PUT', f'{uri}?{qparams(handle, tr)}', new, ctype=ctype)
            if pcode in (200, 204):
                added += [f'{obj["name"]}/{n}' for n in mine_add]
                changed += [f'{obj["name"]}/{n}' for n in mine_chg]
            else:
                failed.append({'object': obj['name'], 'step': 'write', 'http': pcode, 'text': strip(resp)})
        finally:
            if handle:
                unlock(adt, uri, handle)
            adt.stateful = False
    return {'status': 'pass' if not failed else 'fail', 'added': added, 'changed': changed, 'failed': failed,
            'detail': f'{len(added)} added, {len(changed)} changed, {len(failed)} failed'}


def stage_settings(adt, run, out):
    tr = transport(run)
    changed, same, failed = [], 0, []
    for obj in [o for o in run.objects if o['type'] == 'tabl']:
        xml = next((read(f) for f in obj['files'] if f.endswith('.tabl.xml')), '')
        art = re.search(r'<TABART>([^<]+)</TABART>', xml)
        if not art:
            continue
        log = '<PROTOKOLL>X</PROTOKOLL>' in xml
        uri = f'/ddic/db/settings/{obj["name"].lower()}'
        code, body, hdr = adt.call('GET', uri)
        if code != 200:
            failed.append({'object': obj['name'], 'step': 'read', 'http': code, 'text': strip(body)})
            continue
        cur_art = re.search(r'<ts:dataClassCategory>([^<]*)<', body)
        cur_log = re.search(r'<ts:loggingEnabled>([^<]*)<', body)
        if cur_art and cur_log and cur_art.group(1) == art.group(1) and (cur_log.group(1) == 'true') == log:
            same += 1
            continue
        if run.args.dry_run:
            changed.append({'object': obj['name'], 'data_class': art.group(1), 'logging': log})
            continue
        new = re.sub(r'(<ts:dataClassCategory>)[^<]*(<)', rf'\g<1>{art.group(1)}\2', body)
        new = re.sub(r'(<ts:loggingEnabled>)[^<]*(<)', rf'\g<1>{"true" if log else "false"}\2', new)
        ctype = next((v for k, v in hdr.items() if k.lower() == 'content-type'), 'application/xml')
        adt.stateful = True
        handle, lcode, resp = lock(adt, uri)
        if not handle:
            failed.append({'object': obj['name'], 'step': 'lock', 'http': lcode, 'text': strip(resp)})
            adt.stateful = False
            continue
        try:
            pcode, resp, _ = adt.call('PUT', f'{uri}?{qparams(handle, tr)}', new, ctype=ctype)
            if pcode in (200, 204):
                changed.append({'object': obj['name'], 'data_class': art.group(1), 'logging': log})
            else:
                failed.append({'object': obj['name'], 'step': 'write', 'http': pcode, 'text': strip(resp)})
        finally:
            unlock(adt, uri, handle)
            adt.stateful = False
    return {'status': 'pass' if not failed else 'fail', 'written': len(changed), 'unchanged': same, 'failed': failed,
            'detail': f'{len(changed)} {"to write" if run.args.dry_run else "written"}, {same} unchanged, '
                      f'{len(failed)} failed'}


def inactive_refs(adt, run):
    code, body, _ = adt.call('GET', '/activation/inactiveobjects',
                             accept='application/vnd.sap.adt.inactivectsobjects.v1+xml, application/xml')
    if code != 200:
        return code, []
    refs = []
    for m in re.finditer(r'<[\w:]+\b([^>]*adtcore:uri="[^"]*"[^>]*)/?>', body):
        attrs = dict(re.findall(r'adtcore:(\w+)="([^"]*)"', m.group(1)))
        name, uri = attrs.get('name', '').upper(), attrs.get('uri', '')
        if uri and name in run.names:
            refs.append((name, uri))
    return code, sorted(set(refs))


def activate(adt, refs, out, tag):
    body = ('<?xml version="1.0" encoding="UTF-8"?><adtcore:objectReferences xmlns:adtcore="http://www.sap.com/adt/core">'
            + ''.join(f'<adtcore:objectReference adtcore:uri={quoteattr(u)} adtcore:name={quoteattr(n)}/>' for n, u in refs)
            + '</adtcore:objectReferences>')
    code, resp, _ = adt.call('POST', '/activation?method=activate&preauditRequested=true', body,
                             ctype='application/xml', accept='application/xml', timeout=3600)
    with open(os.path.join(out, f'activation{tag}.xml'), 'w', encoding='utf-8') as handle:
        handle.write(resp)
    msgs = []
    for m in re.finditer(r'<msg\b([^>]*)>(.*?)</msg>', resp, re.S):
        attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        text = ' '.join(re.findall(r'<txt>(.*?)</txt>', m.group(2), re.S)) or attrs.get('shortText', '')
        obj = re.search(r'/sap/bc/adt/[^\s"#?]+', attrs.get('href', '')) if attrs.get('href') else None
        msgs.append({'type': attrs.get('type', ''), 'object': obj.group(0) if obj else attrs.get('objDescr', ''),
                     'text': re.sub(r'\s+', ' ', html.unescape(text)).strip()})
    return code, msgs


def stage_activate(adt, run, out):
    """Inactive product objects, activated component by component (parameter framework first); inside a component
    one mass activation (SAP orders the dependencies), then the failing objects once more on their own."""
    if run.args.dry_run:
        code, refs = inactive_refs(adt, run)
        return {'status': 'skipped', 'inactive': len(refs), 'detail': f'dry run: {len(refs)} inactive product objects'}
    adt.stateful = False
    code, refs = inactive_refs(adt, run)
    if code != 200:
        return {'status': 'error', 'detail': f'inactive objects answered {code}'}
    if not refs:
        run.ctx['activated'] = True
        return {'status': 'pass', 'detail': 'no inactive product objects'}
    comp_of = {o['name']: o['component'] for o in run.objects}
    order = [c['id'] for c in run.manifest['components']]
    errors, warnings, requested = [], 0, 0
    for comp in order:
        part = [r for r in refs if comp_of.get(r[0]) == comp]
        if not part:
            continue
        requested += len(part)
        code, msgs = activate(adt, part, out, f'-{comp.lower()}')
        if code != 200:
            return {'status': 'error', 'detail': f'activation of {comp} refused (HTTP {code})'}
        errs = [m for m in msgs if m['type'] in ('E', 'A')]
        if errs:
            bad = {re.sub(r'/(source/main|includes/\w+)$', '', m['object']) for m in errs}
            rest = [r for r in part if re.sub(r'/(source/main|includes/\w+)(#.*)?$', '', r[1]) not in bad]
            held = [r for r in part if r not in rest]
            if rest and held:
                code, msgs = activate(adt, rest, out, f'-{comp.lower()}-without-failing')
                code, msgs2 = activate(adt, held, out, f'-{comp.lower()}-failed-again')
                msgs += msgs2
                errs = [m for m in msgs if m['type'] in ('E', 'A')]
        errors += errs
        warnings += len(msgs) - len(errs)
    _, left = inactive_refs(adt, run)
    ok = not errors and not left
    run.ctx['activated'] = ok
    return {'status': 'pass' if ok else 'fail', 'requested': requested, 'errors': errors[:300], 'warnings': warnings,
            'still_inactive': [n for n, _ in left][:300],
            'detail': f'{requested} activated by component; {len(errors)} errors; {len(left)} still inactive'}


def stage_inventory(adt, run, out):
    res, bad = {}, []
    for comp in run.manifest['components']:
        src = comp['version_source']
        name = os.path.basename(src['file']).split('.')[0]
        code, body, _ = adt.call('GET', f'/oo/interfaces/{name}/source/main', accept='text/plain')
        m = re.search(r'CONSTANTS\s+' + src['constant'] + r"\s+TYPE\s+\S+\s+VALUE\s+[`']([^`']*)[`']", body, re.I) \
            if code == 200 else None
        res[comp['id']] = {'manifest': comp['version'], 'installed': m.group(1) if m else None, 'http': code}
        if not m or m.group(1) != comp['version']:
            bad.append(comp['id'])
    code, left = inactive_refs(adt, run)
    res['inactive_product_objects'] = len(left) if code == 200 else f'answered {code}'
    if not left and code == 200:
        run.ctx.setdefault('activated', True)
    status = 'pass' if not bad and code == 200 and not left else ('blocked' if any(
        res[c]['installed'] is None for c in bad) else 'fail')
    return {'status': status, 'components': res,
            'detail': ', '.join(f'{c} {res[c]["installed"] or "not installed"} (manifest {res[c]["manifest"]})'
                                for c in [x['id'] for x in run.manifest['components']])
            + f'; {res["inactive_product_objects"]} inactive'}


AUNIT_RUN = """<?xml version="1.0" encoding="UTF-8"?>
<aunit:runConfiguration xmlns:aunit="http://www.sap.com/adt/aunit">
  <external><coverage active="false"/></external>
  <options>
    <uriType value="semantic"/>
    <testDeterminationStrategy sameProgram="true" assignedTests="false"/>
    <testRiskLevels harmless="true" dangerous="true" critical="true"/>
    <testDurations short="true" medium="true" long="true"/>
    <withNavigationUri enabled="false"/>
  </options>
  <adtcore:objectSets xmlns:adtcore="http://www.sap.com/adt/core">
    <objectSet kind="inclusive"><adtcore:objectReferences>
{refs}
    </adtcore:objectReferences></objectSet>
  </adtcore:objectSets>
</aunit:runConfiguration>"""


def local(tag):
    return tag.split('}', 1)[-1]


def _alert_text(a):
    title = next((t.text for t in a.iter() if local(t.tag) == 'title'), '') or ''
    return f"{a.get('kind')}/{a.get('severity')}: {title.strip()}"


def aunit_cases(root):
    """Test cases of an ABAP Unit result (the source harness's rule): one per test method, plus one per program or
    class whose own alerts sit outside any method. Case = (program, class, name, is_method, messages)."""
    cases, failures = [], []

    def own_alerts(node, stop):
        found, stack = [], list(node)
        while stack:
            n = stack.pop()
            if local(n.tag) == stop:
                continue
            if local(n.tag) == 'alert':
                found.append(n)
            else:
                stack.extend(list(n))
        return found

    def name(n):
        return n.get('{http://www.sap.com/adt/core}name', '?')

    for prog in (n for n in root.iter() if local(n.tag) == 'program'):
        pname = name(prog)
        msgs = [_alert_text(a) for a in own_alerts(prog, 'testClass')]
        if msgs:
            cases.append((pname, '(program)', '(program)', False, msgs))
            failures.append(f'{pname} (program level): ' + '; '.join(msgs))
        for tclass in (n for n in prog.iter() if local(n.tag) == 'testClass'):
            cname = name(tclass)
            msgs = [_alert_text(a) for a in own_alerts(tclass, 'testMethod')]
            if msgs:
                cases.append((pname, cname, '(class)', False, msgs))
                failures.append(f'{pname} {cname} (class level): ' + '; '.join(msgs))
            for meth in (n for n in tclass.iter() if local(n.tag) == 'testMethod'):
                msgs = [_alert_text(a) for a in meth.iter() if local(a.tag) == 'alert']
                cases.append((pname, cname, name(meth), True, msgs))
                if msgs:
                    failures.append(f'{pname} {cname}->{name(meth)}: ' + '; '.join(msgs))
    return cases, failures


def write_junit(path, cases):
    failed = sum(1 for c in cases if c[4])
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             f'<testsuite name="ABAP Unit" tests="{len(cases)}" failures="{failed}">']
    for p, c, m, _is_method, msgs in cases:
        lines.append(f'  <testcase classname={quoteattr(f"{p}.{c}")} name={quoteattr(m)}>')
        lines += [f'    <failure message={quoteattr(msg[:300])}/>' for msg in msgs]
        lines.append('  </testcase>')
    lines.append('</testsuite>')
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write('\n'.join(lines) + '\n')


def package_refs(run):
    return sorted(set(run.package.values()))


def stage_aunit(adt, run, out):
    if run.args.dry_run:
        return {'status': 'skipped', 'detail': 'dry run'}
    refs = '\n'.join(f'      <adtcore:objectReference adtcore:uri="/sap/bc/adt/packages/'
                     f'{urllib.parse.quote(p.lower(), safe="")}"/>' for p in package_refs(run))
    code, body, _ = adt.call('POST', '/abapunit/testruns', AUNIT_RUN.format(refs=refs),
                             ctype='application/xml', accept='application/xml', timeout=1800)
    with open(os.path.join(out, 'aunit-result.xml'), 'w', encoding='utf-8') as handle:
        handle.write(body)
    if code != 200:
        return {'status': 'error', 'detail': f'ABAP Unit run answered {code}: {strip(body)}'}
    cases, failures = aunit_cases(ET.fromstring(body))
    write_junit(os.path.join(out, 'aunit-junit.xml'), cases)
    methods = sum(1 for c in cases if c[3])
    status = 'pass' if methods and not failures else ('fail' if failures else 'error')
    run.ctx['aunit'] = status
    return {'status': status, 'tests': methods, 'failed': len(failures), 'failures': failures[:200],
            'detail': f'{methods} test methods, {len(failures)} with alerts' if methods else 'no test methods found'}


def stage_atc(adt, run, out):
    if run.args.dry_run:
        return {'status': 'skipped', 'detail': 'dry run'}
    code, body, _ = adt.call('POST', f'/atc/worklists?checkVariant={urllib.parse.quote(run.args.variant)}',
                             accept='text/plain')
    if code not in (200, 201):
        return {'status': 'error', 'detail': f'worklist not created ({code}): {strip(body)}'}
    wl = body.strip()
    refs = ''.join(f'<adtcore:objectReference adtcore:uri="/sap/bc/adt/packages/'
                   f'{urllib.parse.quote(p.lower(), safe="")}"/>' for p in package_refs(run))
    body = ('<?xml version="1.0" encoding="UTF-8"?><atc:run xmlns:atc="http://www.sap.com/adt/atc" maximumVerdicts="10000">'
            '<objectSets xmlns:adtcore="http://www.sap.com/adt/core"><objectSet kind="inclusive"><adtcore:objectReferences>'
            + refs + '</adtcore:objectReferences></objectSet></objectSets></atc:run>')
    code, resp, _ = adt.call('POST', f'/atc/runs?worklistId={urllib.parse.quote(wl)}', body, ctype='application/xml',
                             accept='application/xml', timeout=1800)
    if code != 200:
        return {'status': 'error', 'detail': f'ATC run failed ({code}): {strip(resp)}'}
    code, resp, _ = adt.call('GET', f'/atc/worklists/{urllib.parse.quote(wl)}?includeExemptedFindings=false',
                             accept='application/atc.worklist.v1+xml')
    with open(os.path.join(out, 'atc-worklist.xml'), 'w', encoding='utf-8') as handle:
        handle.write(resp)
    if code != 200:
        return {'status': 'error', 'detail': f'worklist not read ({code})'}
    counts = {p: len(re.findall(rf'priority="{p}"', resp)) for p in '1234'}
    failing = sum(counts[p] for p in '1234' if int(p) <= run.args.max_priority)
    return {'status': 'pass' if failing == 0 else 'fail', 'variant': run.args.variant, 'priorities': counts,
            'detail': f'{sum(counts.values())} findings, {failing} up to priority {run.args.max_priority}'}


def stage_cds(adt, run, out):
    code, left = inactive_refs(adt, run)
    if code != 200:
        return {'status': 'error', 'detail': f'inactive objects answered {code}'}
    inactive = {n for n, _ in left}
    cds = [o for o in run.objects if o['type'] in ('ddls', 'dcls', 'ddlx', 'bdef', 'srvd')]
    missing, still = [], []
    for o in cds:
        code, _, _ = adt.call('GET', f'{SOURCE_BASE[o["type"]]}/{o["name"].lower()}/source/main', accept='text/plain')
        if code != 200:
            missing.append(o['name'])
        elif o['name'] in inactive:
            still.append(o['name'])
    ok = not missing and not still
    return {'status': 'pass' if ok else 'fail', 'missing': missing[:200], 'inactive': still[:200],
            'detail': f'{len(cds)} CDS / behaviour / service sources: {len(missing)} missing, {len(still)} inactive'}


def stage_odata(adt, run, out):
    suffix = run.manifest['service_bindings']['suffix']
    res, missing = {}, []
    for o in [x for x in run.objects if x['type'] == 'srvd']:
        binding = (o['name'] + suffix).lower()
        path = f'/sap/opu/odata4/sap/{binding}/srvd/sap/{o["name"].lower()}/0001/$metadata'
        code, body, _ = adt.call('GET', path, accept='application/xml')
        ok = code == 200 and 'edmx' in body[:500].lower()
        res[binding.upper()] = code
        if not ok:
            missing.append(binding.upper())
    if missing:
        return {'status': 'blocked', 'bindings': res,
                'detail': f'{len(missing)} of {len(res)} bindings without metadata: create and publish them in ADT '
                          f'(OData V4 - UI): {", ".join(missing[:20])} (V210)'}
    return {'status': 'pass', 'bindings': res, 'detail': f'{len(res)} OData V4 services answer their metadata'}


def stage_licensing(adt, run, out):
    """Activation proven without a licence (V208): no licence row, LIC_ENFORCE W or not set (default W), and every
    product object active (activation of this run or no inactive product object)."""
    enforce = run.manifest['licensing']['enforce_parameter']
    code, rows = preview(adt, 'SELECT license_id, active FROM zca_ops_lic', 10)
    if code != 200:
        return {'status': 'error', 'detail': f'licence table not readable (HTTP {code}: {rows})'}
    code2, vals = preview(adt, f"SELECT low FROM zca_param_val WHERE area = '{enforce['area']}' "
                               f"AND name = '{enforce['name']}'", 5)
    if code2 != 200:
        return {'status': 'error', 'detail': f'parameter values not readable (HTTP {code2}: {vals})'}
    value = (vals[0].get('LOW') if vals else '') or enforce['delivered']
    activated = run.ctx.get('activated')
    res = {'licences_installed': len(rows), 'lic_enforce': value, 'value_row': bool(vals), 'activated': activated,
           'aunit': run.ctx.get('aunit', 'not run')}
    if rows:
        res.update(status='blocked', detail=f'{len(rows)} licence row(s) installed: not a proof without a licence '
                                            '(use a sandbox without a licence)')
    elif value != 'W':
        res.update(status='fail', detail=f'LIC_ENFORCE = {value}: set it back to W for this proof')
    elif activated is None:
        res.update(status='blocked', detail='run the activate or inventory stage first')
    elif not activated or res['aunit'] == 'fail':
        res.update(status='fail', detail='no licence and LIC_ENFORCE W, but activation or ABAP Unit failed')
    else:
        res.update(status='pass', detail=f'no licence installed, LIC_ENFORCE {value}'
                                         f'{" (default)" if not vals else ""}: every product object active'
                                         f'{", ABAP Unit " + res["aunit"] if res["aunit"] != "not run" else ""}')
    return res


STAGES = {'preflight': stage_preflight, 'connect': stage_connect, 'packages': stage_packages,
          'collision': stage_collision, 'ddic': stage_ddic, 'tables': stage_tables, 'sync': stage_sync,
          'texts': stage_texts, 'messages': stage_messages, 'settings': stage_settings, 'activate': stage_activate,
          'inventory': stage_inventory, 'aunit': stage_aunit, 'atc': stage_atc, 'cds': stage_cds,
          'odata': stage_odata, 'licensing': stage_licensing}
STOPPING = {'preflight', 'connect', 'packages', 'collision', 'ddic'}


def summary(results, run, stamp, client):
    versions = ', '.join(c['id'] + ' ' + c['version'] for c in run.manifest['components'])
    md = [f'# Install run {stamp}', '',
          f'Release {run.manifest["release"]} ({versions}), '
          f'packs {", ".join(run.packs)}, package root {run.args.package_root.upper()}, '
          f'transport {run.args.transport.upper()}, client {client}{", dry run" if run.args.dry_run else ""}.', '',
          '| Stage | Status | Detail |', '|---|---|---|']
    md += [f'| {k} | **{v["status"]}** | {str(v.get("detail", "")).replace("|", "/")} |' for k, v in results.items()]
    clashes = results.get('collision', {}).get('clashes') or []
    if clashes:
        md += ['', '## Name clashes (nothing written)', '']
        md += [f'- `{c["name"]}` ({c["product_type"]}): {c["system_type"]} in package {c["package"]}' for c in clashes]
    for stage, key, title in (('sync', 'failed', 'Source sync failures'), ('tables', 'failed', 'Table failures')):
        items = results.get(stage, {}).get(key) or []
        if items:
            md += ['', f'## {title}', ''] + [f'- `{f["object"]}` {f["step"]} ({f["http"]}): {f["text"]}' for f in items]
    errs = results.get('activate', {}).get('errors') or []
    if errs:
        md += ['', '## Activation errors', ''] + [f'- `{e["object"]}`: {e["text"]}' for e in errs]
    fails = results.get('aunit', {}).get('failures') or []
    if fails:
        md += ['', '## ABAP Unit alerts', ''] + [f'- {f}' for f in fails]
    return '\n'.join(md) + '\n'


def parse(argv):
    ap = argparse.ArgumentParser(description='Install harness of the product (parameter framework, operations framework)')
    ap.add_argument('--package-root', help='target package root: ZCA keeps ZCA_PARAM / ZCA_OPS ..., ZR1 gives '
                                           'ZR1_PARAM / ZR1_OPS ...; $ZR1 for local packages')
    ap.add_argument('--transport', help='modifiable transport request of the sandbox, or LOCAL for $ packages')
    ap.add_argument('--stages', default=DEFAULT_STAGES)
    ap.add_argument('--variant', default=os.environ.get('CHECK_VARIANT', 'DEFAULT'))
    ap.add_argument('--max-priority', type=int, default=2)
    ap.add_argument('--with-demo', action='store_true', help='also the demo consumer (sandbox only)')
    ap.add_argument('--dry-run', action='store_true', help='read only: no write, activation, ABAP Unit or ATC run')
    ap.add_argument('--only', default='', help='regular expression: restrict the run to matching object names')
    ap.add_argument('--out', default=EVIDENCE, help='evidence root (default ops-framework/release/qualification)')
    return ap.parse_args(argv)


def main(argv=None):
    args = parse(sys.argv[1:] if argv is None else argv)
    manifest, objects, problems = RM.load_all(ROOT, MANIFEST)
    refusals = validate_args(args, manifest, objects) + problems
    if refusals:
        for r in refusals:
            print(f'refused: {r}', file=sys.stderr)
        return 2
    stages = [s.strip() for s in args.stages.split(',') if s.strip()]
    unknown = [s for s in stages if s not in STAGES]
    if unknown:
        print(f'refused: unknown stage(s) {", ".join(unknown)}', file=sys.stderr)
        return 2
    if set(stages) & WRITING and 'collision' not in stages and not args.dry_run:
        print('refused: a writing stage needs the collision stage before it in the same run', file=sys.stderr)
        return 2
    run = Run(args, manifest, objects)
    adt = Adt(env('SAP_URL', 'ZCA_TT_A4H_URL'), env('SAP_USER', 'ZCA_TT_A4H_USER'),
              env('SAP_PASSWORD', 'ZCA_TT_A4H_PASSWORD'), env('SAP_CLIENT', 'ZCA_TT_A4H_CLIENT'),
              write_paths=run.write_paths(), dry_run=args.dry_run)
    adt.collections = set(SOURCE_BASE.values()) | {'/ddic/tables'}
    adt.creatable = {o['name'] for o in run.objects}
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    out = os.path.join(args.out, manifest['release'], stamp)
    os.makedirs(out, exist_ok=True)
    results, stop = {}, None
    for st in stages:
        if stop:
            results[st] = {'status': 'blocked', 'detail': f'stage {stop} did not pass'}
            continue
        try:
            results[st] = STAGES[st](adt, run, out)
        except GuardError as x:
            results[st] = {'status': 'error', 'detail': f'guard: {x}'}
        except Exception as x:  # recorded, never hidden
            results[st] = {'status': 'error', 'detail': f'{type(x).__name__}: {x}'}
        if st in STOPPING and results[st]['status'] not in ('pass', 'skipped'):
            stop = st
    record = {'release': manifest['release'], 'components': {c['id']: c['version'] for c in manifest['components']},
              'timestamp_utc': stamp, 'system_client': adt.client, 'system': run.ctx.get('system', {}),
              'package_root': args.package_root.upper(), 'packages': run.package, 'transport': args.transport.upper(),
              'dry_run': args.dry_run, 'packs': run.packs, 'only': args.only, 'stages': results,
              'writes': sum(1 for m, _ in adt.calls if m in ('PUT', 'DELETE')) +
              sum(1 for m, p in adt.calls if m == 'POST' and not any(r.match(p) for r in READ_ONLY_POST))}
    with open(os.path.join(out, 'results.json'), 'w', encoding='utf-8') as handle:
        json.dump(record, handle, indent=2)
    text = summary(results, run, stamp, adt.client)
    with open(os.path.join(out, 'summary.md'), 'w', encoding='utf-8') as handle:
        handle.write(text)
    print(text)
    print(f'evidence: {out}')
    return 0 if all(v['status'] in ('pass', 'skipped') for v in results.values()) else 1


if __name__ == '__main__':
    sys.exit(main())
