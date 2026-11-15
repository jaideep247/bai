#!/usr/bin/env python3
"""Licensing of the operations framework ZCA_OPS: the licensable modules of the product, the module map of the runtime
and the licence payload a vendor signs (offline engine; the runtime twins are ZCL_CA_OPS_LIC_POLICY - the decision -
and ZCL_CA_OPS_LICENSE - verification, binding and caching; docs/LICENSING.md of the framework).

First principle: the customer decides what runs (activation); the vendor decides what may be activated (the licence).
The licence is a vendor-signed file naming the customer's installation, systems, product versions and modules with
their validity; the product refuses a module the file does not cover (switch LIC_ENFORCE) and never refuses CORE.

Module catalogue (config/licensing/modules.json of the framework):
  modules         [{code, name, always, seq, requires [codes], enforcement (runtime | contract), description,
                    entry_points [paths], check_classes [ZCL_...], config [entity aliases of ZUI_CA_OPS_CFG],
                    gates [paths naming gc_module-<code>], docs [paths]}]
  derived_config  [{entity, field, rule}]   configuration entities whose module follows from the row
Catalogue packages / processes name their module in their own spec (license_module, product packages only).

Validation: codes (A-Z, 0-9, _; <= 20), unique, exactly the module CORE always included; names <= 60; requires known;
every path exists; every check class of the product (src/zcl_<p>_chk_*.clas.abap) in exactly one module; a gate file
names the module's constant (gc_module-<code>); a configuration entity of a module (and every derived entity) has the
licence validation in the generated behaviour pool (license_refused in its handler); every product catalogue package
names a known module, a process override too.

Outputs (generate / check): the generated class of the module map (rows of kind MOD / CLAS / PKG / PRC, constants
only) and the module document. --check fails on an invalid catalogue or an out-of-date output.

Licence payload (asJSON of the ABAP structure ZIF_CA_OPS_LIC_TYPES=>TY_PAYLOAD under the name LICENSE, so the
runtime reads it with CALL TRANSFORMATION id):
  {"LICENSE": {"FORMAT": 1, "LICENSE_ID": "...", "PRODUCT": "ZCA_OPS", "CUSTOMER": "...",
               "INSTALLATIONS": ["0020123456"], "SYSTEMS": [{"SID": "PS4", "CLIENT": "100"}],
               "VERSION_FROM": "1.0", "VERSION_TO": "1", "MODULES": [{"CODE": "JOBS", "VALID_FROM": "20261115",
               "VALID_TO": "20271114"}], "GRACE_DAYS": 30, "ISSUED_AT": "20261115120000"}}
evaluate( ) is the Python twin of the runtime decision (vendor support, tests): licence state VALID / MISSING /
SIGNATURE / BINDING / VERSION, module states INCLUDED / LICENSED / EXPIRING / GRACE / EXPIRED / UNLICENSED and whether
each module may run under the enforcement W (warn) or X (refuse).

Modification log:
2026-11-15 | Initial version (licensing: module catalogue, module map, licence payload and decision twin).
"""
import datetime
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
CODE = re.compile(r'^[A-Z][A-Z0-9_]{1,19}$')
CLASS = re.compile(r'^Z[A-Z0-9_]{1,29}$')
DATE = re.compile(r'^20[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$')
STAMP = re.compile(r'^20[0-9]{12}$')
INSTALLATION = re.compile(r'^[0-9]{10}$')
SID = re.compile(r'^[A-Z][A-Z0-9]{2}$')
CLIENT = re.compile(r'^([0-9]{3})?$')
VERSION = re.compile(r'^[0-9]+(\.[0-9]+){0,2}$')
LICENSE_ID = re.compile(r'^[A-Z0-9][A-Z0-9_./-]{0,39}$')
NAME_MAX = 60
FORMAT = 1
KINDS = ('MOD', 'CLAS', 'PKG', 'PRC')
STATES = ('INCLUDED', 'LICENSED', 'EXPIRING', 'GRACE', 'EXPIRED', 'UNLICENSED')
RUNS = ('INCLUDED', 'LICENSED', 'EXPIRING', 'GRACE')
CORE = 'CORE'


class LicensingError(ValueError):
    """The module catalogue or a licence payload is invalid (message lists every problem)."""


# ------------------------------------------------------------------------------------------------ catalogue
def load(path):
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def catalogue_rows(package_paths):
    """(kind, name, module, description) of every product catalogue package and process override."""
    rows = []
    for path in package_paths:
        spec = load(path)
        pkg = spec.get('package', {})
        rows.append(('PKG', pkg.get('id', ''), pkg.get('license_module', ''), str(pkg.get('description', ''))))
        for proc in spec.get('processes', []):
            if proc.get('license_module'):
                rows.append(('PRC', proc.get('id', ''), proc['license_module'], str(proc.get('name', ''))))
    return rows


def _behaviour_handlers(root, pool):
    """Handler blocks of a generated behaviour pool: alias (lower case) -> source of its class."""
    path = os.path.join(root, pool)
    if not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as handle:
        text = handle.read()
    blocks = {}
    for match in re.finditer(r'^CLASS lhc_(\w+) IMPLEMENTATION\.(.*?)^ENDCLASS\.', text, re.M | re.S):
        blocks[match.group(1).lower()] = match.group(2)
    return blocks


def validate(spec, root, profile):
    """Problems of the module catalogue against the product (empty = valid)."""
    problems = []
    modules = spec.get('modules', [])
    codes = [m.get('code', '') for m in modules]
    if not modules:
        problems.append('no module')
    for code in codes:
        if not CODE.match(code or ''):
            problems.append(f'module {code!r}: code must be A-Z, 0-9, _ (2-20 characters)')
    for code in sorted({c for c in codes if codes.count(c) > 1}):
        problems.append(f'module {code}: defined twice')
    always = [m['code'] for m in modules if m.get('always')]
    if always != [CORE]:
        problems.append(f'exactly the module {CORE} is always included (found {always})')
    seqs = [m.get('seq') for m in modules]
    if any(not isinstance(s, int) for s in seqs) or len(set(seqs)) != len(seqs):
        problems.append('every module needs its own sequence number (seq)')
    owner = {}
    handlers = _behaviour_handlers(root, profile['behaviour_pool'])
    prefix = profile['class_prefix']
    for mod in modules:
        code = mod.get('code', '')
        if not mod.get('name') or len(mod['name']) > NAME_MAX:
            problems.append(f'module {code}: name missing or longer than {NAME_MAX}')
        if mod.get('enforcement', 'runtime') not in ('runtime', 'contract'):
            problems.append(f'module {code}: enforcement must be runtime or contract')
        for req in mod.get('requires', []):
            if req not in codes or req == code or req == CORE:
                problems.append(f'module {code}: requires {req} (unknown, itself or the always included {CORE})')
        for path in mod.get('entry_points', []) + mod.get('gates', []) + mod.get('docs', []):
            if not os.path.exists(os.path.normpath(os.path.join(root, path))):
                problems.append(f'module {code}: {path} does not exist')
        for cls in mod.get('check_classes', []):
            if not CLASS.match(cls):
                problems.append(f'module {code}: check class {cls} is not a class name')
            elif cls in owner:
                problems.append(f'check class {cls}: in modules {owner[cls]} and {code}')
            else:
                owner[cls] = code
            if not os.path.exists(os.path.join(root, 'src', cls.lower() + '.clas.abap')):
                problems.append(f'module {code}: check class {cls} has no source in src/')
        constant = f'gc_module-{code.lower()}'
        for path in mod.get('gates', []):
            full = os.path.normpath(os.path.join(root, path))
            if os.path.exists(full) and constant not in (_read(full) or '').lower():
                problems.append(f'module {code}: gate {path} does not name {constant}')
        if mod.get('enforcement') == 'contract' and (mod.get('gates') or mod.get('config') or mod.get('check_classes')):
            problems.append(f'module {code}: a module enforced by contract has no gate, configuration or check class')
        for entity in mod.get('config', []):
            if 'license_refused' not in handlers.get(entity.lower(), ''):
                problems.append(f'module {code}: configuration entity {entity} has no licence validation '
                                f'(license_refused) in {profile["behaviour_pool"]}')
    for item in spec.get('derived_config', []):
        if 'license_refused' not in handlers.get(item.get('entity', '').lower(), ''):
            problems.append(f'derived configuration entity {item.get("entity")}: no licence validation '
                            f'(license_refused) in {profile["behaviour_pool"]}')
    pattern = re.compile(r'^' + re.escape(prefix.lower()) + r'chk_\w+\.clas\.abap$')
    for name in sorted(os.listdir(os.path.join(root, 'src'))):
        if pattern.match(name):
            cls = name[:-len('.clas.abap')].upper()
            if cls not in owner:
                problems.append(f'check class {cls}: in no module (add it to check_classes of its module)')
    for kind, name, module, _ in catalogue_rows(profile_packages(profile)):
        if module not in codes:
            problems.append(f'catalogue {"package" if kind == "PKG" else "process"} {name}: license_module '
                            f'{module!r} is not a module')
    return problems


def profile_packages(profile):
    return [os.path.join(REPO, p) for p in profile['packages']]


def map_rows(spec, profile):
    """Rows of the module map (generated class): modules, check classes, catalogue packages and processes."""
    rows = []
    for mod in sorted(spec['modules'], key=lambda m: m['seq']):
        rows.append({'OBJ_KIND': 'MOD', 'OBJ_NAME': mod['code'], 'MODULE': mod['code'],
                     'ALWAYS': 'X' if mod.get('always') else '', 'SEQ': mod['seq'], 'DESCRIPTION': mod['name']})
    for mod in sorted(spec['modules'], key=lambda m: m['seq']):
        for cls in sorted(mod.get('check_classes', [])):
            rows.append({'OBJ_KIND': 'CLAS', 'OBJ_NAME': cls, 'MODULE': mod['code'], 'ALWAYS': '', 'SEQ': mod['seq'],
                         'DESCRIPTION': f'Registered check class of module {mod["code"]}'[:NAME_MAX]})
    seq = {m['code']: m['seq'] for m in spec['modules']}
    for kind, name, module, text in catalogue_rows(profile_packages(profile)):
        rows.append({'OBJ_KIND': kind, 'OBJ_NAME': name, 'MODULE': module, 'ALWAYS': '', 'SEQ': seq.get(module, 0),
                     'DESCRIPTION': text[:NAME_MAX]})
    return rows


def _abap_text(value):
    return str(value).replace("'", "''")


def render_class(rows, profile):
    """ABAP source of the generated class of the module map (constants only, no database)."""
    name = profile['map_class'].lower()
    types = profile['types_interface']
    out = ['*&---------------------------------------------------------------------*',
           f'*& Artifact: {name}.clas.abap',
           '*& Purpose:',
           '*& Module map of the licence (docs/LICENSING.md) - GENERATED by',
           '*& tools/licensing.py from config/licensing/modules.json and the',
           '*& license_module of the catalogue packages; do not edit, regenerate.',
           '*& Rows: MOD the licensable modules (ALWAYS = never refused), CLAS the',
           '*& registered check classes of a module, PKG / PRC the catalogue packages',
           '*& and processes of a module. Product code, not configuration: a customer',
           '*& changes the map only by a modification (visible in the version',
           '*& history). Production-safe: no database.',
           '*& Modification log:',
           '*& 2026-11-15 | Initial version (generated; licensing).',
           '*&---------------------------------------------------------------------*',
           '"! <p class="shorttext synchronized">Operations framework - licence module map</p>',
           '"! Licensable modules and the objects that need them (generated from config/licensing).',
           f'CLASS {name} DEFINITION',
           '  PUBLIC',
           '  FINAL',
           '  CREATE PRIVATE.',
           '',
           '  PUBLIC SECTION.',
           '    "! Every row of the map: modules first (by sequence), then check classes, packages, processes',
           '    CLASS-METHODS rows',
           '      RETURNING',
           f'        VALUE(rt_rows) TYPE {types}=>tt_map.',
           '',
           '  PRIVATE SECTION.']
    for index, row in enumerate(rows, start=1):
        always = "abap_true" if row['ALWAYS'] else "abap_false"
        out += ['    CONSTANTS:',
                f'      BEGIN OF gc_r{index:03d},',
                f"        obj_kind    TYPE {types}=>ty_obj_kind VALUE '{row['OBJ_KIND']}',",
                f"        obj_name    TYPE {types}=>ty_obj_name VALUE '{row['OBJ_NAME']}',",
                f"        module      TYPE {types}=>ty_module VALUE '{row['MODULE']}',",
                f'        always      TYPE abap_bool VALUE {always},',
                f"        seq         TYPE i VALUE {int(row['SEQ'])},",
                f"        description TYPE {types}=>ty_text VALUE '{_abap_text(row['DESCRIPTION'])}',",
                f'      END OF gc_r{index:03d}.']
    out += ['ENDCLASS.', '', '', '', f'CLASS {name} IMPLEMENTATION.', '', '  METHOD rows.']
    first = True
    for index in range(1, len(rows) + 1):
        lead = '    rt_rows = VALUE #( ' if first else '                       '
        tail = ' ).' if index == len(rows) else ''
        out.append(f'{lead}( CORRESPONDING #( gc_r{index:03d} ) ){tail}')
        first = False
    out += ['  ENDMETHOD.', '', 'ENDCLASS.', '']
    return '\n'.join(out)


def _cell(value):
    return str(value).replace('|', '\\|').replace('\n', ' ')


def render_doc(spec, rows, title):
    """The module document (generated)."""
    out = [f'# {title}', '',
           '> Generated by `tools/licensing.py` from `config/licensing/modules.json` and the `license_module` of the',
           '> catalogue packages - do not edit, regenerate. How the licence works: `docs/LICENSING.md`.', '',
           '## Modules', '',
           '| Seq | Module | Name | Always | Requires | Enforcement | Configuration refused when unlicensed | Gates |',
           '|---|---|---|---|---|---|---|---|']
    for mod in sorted(spec['modules'], key=lambda m: m['seq']):
        out.append('| {} | `{}` | {} | {} | {} | {} | {} | {} |'.format(
            mod['seq'], mod['code'], _cell(mod['name']), 'yes' if mod.get('always') else '',
            ', '.join(f'`{r}`' for r in mod.get('requires', [])) or '-',
            mod.get('enforcement', 'runtime'),
            ', '.join(mod.get('config', [])) or '-',
            ', '.join(f'`{os.path.basename(g)}`' for g in mod.get('gates', [])) or '-'))
    out += ['', '## What each module is', '']
    for mod in sorted(spec['modules'], key=lambda m: m['seq']):
        out += [f'### `{mod["code"]}` - {mod["name"]}', '', _cell(mod.get('description', '')), '',
                '- Entry points: ' + (', '.join(f'`{p}`' for p in mod.get('entry_points', [])) or '-'),
                '- Registered check classes: ' + (', '.join(f'`{c}`' for c in mod.get('check_classes', [])) or '-'),
                '- Documents: ' + (', '.join(f'`{d}`' for d in mod.get('docs', [])) or '-'), '']
    out += ['## Configuration whose module follows from the row', '',
            '| Entity of `ZUI_CA_OPS_CFG` | Field | Rule |', '|---|---|---|']
    for item in spec.get('derived_config', []):
        out.append(f'| {item["entity"]} | `{item["field"]}` | {_cell(item["rule"])} |')
    out += ['', '## Module map of the runtime (`ZCL_CA_OPS_LIC_MAP`)', '',
            '| Kind | Object | Module | Always | Description |', '|---|---|---|---|---|']
    for row in rows:
        out.append(f'| {row["OBJ_KIND"]} | `{row["OBJ_NAME"]}` | `{row["MODULE"]}` | {row["ALWAYS"]} | '
                   f'{_cell(row["DESCRIPTION"])} |')
    return '\n'.join(out) + '\n'


# ------------------------------------------------------------------------------------------------ payload
def module_codes(spec):
    return [m['code'] for m in spec['modules']]


def normalise(raw):
    """The canonical payload {"LICENSE": {...}} of a canonical or a friendly (lower case keys) JSON object."""
    body = raw.get('LICENSE', raw)
    def get(key, default=None):
        return body.get(key.upper(), body.get(key.lower(), default))
    systems = []
    for item in get('systems', []) or []:
        if isinstance(item, str):
            sid, _, client = item.partition('/')
            systems.append({'SID': sid.upper(), 'CLIENT': client})
        else:
            systems.append({'SID': str(item.get('SID', item.get('sid', ''))).upper(),
                            'CLIENT': str(item.get('CLIENT', item.get('client', '')) or '')})
    modules = []
    for item in get('modules', []) or []:
        if isinstance(item, str):
            code, valid_from, valid_to = (item.split(':') + ['', ''])[:3]
            modules.append({'CODE': code.upper(), 'VALID_FROM': valid_from, 'VALID_TO': valid_to})
        else:
            modules.append({'CODE': str(item.get('CODE', item.get('code', ''))).upper(),
                            'VALID_FROM': str(item.get('VALID_FROM', item.get('valid_from', ''))),
                            'VALID_TO': str(item.get('VALID_TO', item.get('valid_to', '')))})
    grace = get('grace_days', 30)
    return {'LICENSE': {
        'FORMAT': FORMAT,
        'LICENSE_ID': str(get('license_id', get('licence_id', '')) or '').upper(),
        'PRODUCT': str(get('product', 'ZCA_OPS') or ''),
        'CUSTOMER': str(get('customer', '') or ''),
        'INSTALLATIONS': [str(i) for i in (get('installations', []) or [])],
        'SYSTEMS': systems,
        'VERSION_FROM': str(get('version_from', '') or ''),
        'VERSION_TO': str(get('version_to', '') or ''),
        'MODULES': modules,
        'GRACE_DAYS': int(grace) if str(grace).lstrip('-').isdigit() else grace,
        'ISSUED_AT': str(get('issued_at', '') or ''),
    }}


def validate_payload(payload, spec=None, product='ZCA_OPS'):
    """Problems of a canonical payload (empty = valid); with the catalogue also unknown modules / requirements."""
    problems = []
    body = payload.get('LICENSE')
    if not isinstance(body, dict):
        return ['payload: member LICENSE missing']
    if body.get('FORMAT') != FORMAT:
        problems.append(f'FORMAT must be {FORMAT}')
    if not LICENSE_ID.match(body.get('LICENSE_ID', '')):
        problems.append('LICENSE_ID: A-Z, 0-9, _ . / - (1-40 characters)')
    if body.get('PRODUCT') != product:
        problems.append(f'PRODUCT must be {product}')
    if not body.get('CUSTOMER') or len(body['CUSTOMER']) > 80:
        problems.append('CUSTOMER: 1-80 characters')
    if not body.get('INSTALLATIONS'):
        problems.append('INSTALLATIONS: at least one installation number')
    for inst in body.get('INSTALLATIONS', []):
        if not INSTALLATION.match(inst):
            problems.append(f'installation {inst!r}: ten digits')
    if not body.get('SYSTEMS'):
        problems.append('SYSTEMS: at least one system ID')
    for system in body.get('SYSTEMS', []):
        if not SID.match(system.get('SID', '')) or not CLIENT.match(system.get('CLIENT', '')):
            problems.append(f'system {system}: SID of three characters, client blank or three digits')
    for key in ('VERSION_FROM', 'VERSION_TO'):
        if not VERSION.match(body.get(key, '')):
            problems.append(f'{key}: a version like 1, 1.0 or 1.0.0')
    if all(VERSION.match(body.get(k, '')) for k in ('VERSION_FROM', 'VERSION_TO')) and \
            _version_key(body['VERSION_FROM'], 0) > _version_key(body['VERSION_TO'], 999999):
        problems.append('VERSION_FROM after VERSION_TO')
    grace = body.get('GRACE_DAYS')
    if not isinstance(grace, int) or not 0 <= grace <= 365:
        problems.append('GRACE_DAYS: 0-365')
    if not STAMP.match(body.get('ISSUED_AT', '')):
        problems.append('ISSUED_AT: YYYYMMDDhhmmss')
    codes = [m.get('CODE') for m in body.get('MODULES', [])]
    if not codes:
        problems.append('MODULES: at least one module')
    for code in sorted({c for c in codes if codes.count(c) > 1}):
        problems.append(f'module {code}: twice')
    known = module_codes(spec) if spec else None
    for mod in body.get('MODULES', []):
        code = mod.get('CODE', '')
        if known is not None and code not in known:
            problems.append(f'module {code}: not a module of the product')
        if not DATE.match(mod.get('VALID_FROM', '')) or not DATE.match(mod.get('VALID_TO', '')):
            problems.append(f'module {code}: VALID_FROM / VALID_TO as YYYYMMDD')
        elif mod['VALID_FROM'] > mod['VALID_TO']:
            problems.append(f'module {code}: VALID_FROM after VALID_TO')
    return problems


def missing_requirements(payload, spec):
    """Modules of the payload whose required modules it does not name (a warning of the issuing tool)."""
    named = {m['CODE'] for m in payload['LICENSE'].get('MODULES', [])} | {CORE}
    out = []
    for mod in spec['modules']:
        if mod['code'] in named:
            out += [f'{mod["code"]} requires {req}' for req in mod.get('requires', []) if req not in named]
    return out


def canonical_json(payload):
    """The bytes a vendor signs: UTF-8, stable member order, no insignificant white space."""
    return json.dumps(payload, ensure_ascii=False, separators=(',', ':')).encode('utf-8')


# ------------------------------------------------------------------------------------------------ decision twin
def _version_key(version, fill):
    parts = [int(p) for p in version.split('.')] if version else []
    return tuple(parts + [fill] * (3 - len(parts)))


def version_in_range(version, low, high):
    return _version_key(low, 0) <= _version_key(version, 0) <= _version_key(high, 999999)


def _date(text):
    return datetime.date(int(text[:4]), int(text[4:6]), int(text[6:8]))


def evaluate(payload, today, installation='', sid='', client='', version='1.0.0', warn_days=30, enforce='W',
             signature_ok=True, always=(CORE,), codes=()):
    """State of the licence and of every module (the decision of ZCL_CA_OPS_LIC_POLICY, twin for tests and support).
    payload None = no licence installed."""
    result = {'state': 'VALID', 'modules': {}}
    body = payload['LICENSE'] if payload else None
    if body is None:
        result['state'] = 'MISSING'
    elif not signature_ok:
        result['state'] = 'SIGNATURE'
    elif (installation and installation not in body['INSTALLATIONS']) or (sid and not any(
            s['SID'] == sid and s.get('CLIENT', '') in ('', client) for s in body['SYSTEMS'])):
        result['state'] = 'BINDING'
    elif not version_in_range(version, body['VERSION_FROM'], body['VERSION_TO']):
        result['state'] = 'VERSION'
    granted = {m['CODE']: m for m in body['MODULES']} if body and result['state'] == 'VALID' else {}
    grace = body['GRACE_DAYS'] if body else 0
    for code in list(always) + [c for c in codes if c not in always] + [c for c in granted if c not in always
                                                                        and c not in codes]:
        if code in always:
            state, days_left = 'INCLUDED', None
        elif code not in granted or _date(granted[code]['VALID_FROM']) > today:
            state, days_left = 'UNLICENSED', None
        else:
            valid_to = _date(granted[code]['VALID_TO'])
            days_left = (valid_to - today).days
            if days_left >= 0:
                state = 'EXPIRING' if days_left < warn_days else 'LICENSED'
            elif today <= valid_to + datetime.timedelta(days=grace):
                state = 'GRACE'
            else:
                state = 'EXPIRED'
        result['modules'][code] = {'state': state, 'days_left': days_left,
                                   'runs': state in RUNS or enforce != 'X',
                                   'warn': state not in ('INCLUDED', 'LICENSED')}
    return result


# ------------------------------------------------------------------------------------------------ outputs
def outputs(root, profile):
    """(path, expected text) of every generated output; raises LicensingError on an invalid catalogue."""
    spec = load(os.path.join(root, profile['modules']))
    problems = validate(spec, root, profile)
    if problems:
        raise LicensingError('\n'.join(problems))
    rows = map_rows(spec, profile)
    return [(os.path.join(root, 'src', profile['map_class'].lower() + '.clas.abap'), render_class(rows, profile)),
            (os.path.join(root, profile['doc']), render_doc(spec, rows, profile['doc_title']))]


def _read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def check(root, profile):
    """Failures (empty = valid and up to date)."""
    try:
        expected = outputs(root, profile)
    except LicensingError as error:
        return str(error).split('\n')
    return [f'{os.path.relpath(path, root)}: out of date (run tools/licensing.py)'
            for path, text in expected if _read(path) != text]


def generate(root, profile):
    for path, text in outputs(root, profile):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if _read(path) != text:
            with open(path, 'w', encoding='utf-8', newline='\n') as handle:
                handle.write(text)


def main(root, profile, argv):
    if '--check' in argv:
        failures = check(root, profile)
        for failure in failures:
            print(failure)
        print('licensing: valid and up to date' if not failures else f'licensing: {len(failures)} problem(s)')
        return 1 if failures else 0
    try:
        generate(root, profile)
    except LicensingError as error:
        print(error)
        return 1
    print('licensing: generated')
    return 0
