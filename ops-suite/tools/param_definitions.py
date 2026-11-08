#!/usr/bin/env python3
"""
Artifact: tools/param_definitions.py
Purpose:  The suite's runtime parameters in the framework ZCA_PARAM (areas CD_OPS, CD_EBS,
          CD_FMON, CD_HCK). Reads the seed files config/param_areas.csv,
          config/param_definitions.csv and config/param_values.csv (format:
          param-framework/docs/ONBOARDING.md section 6), checks their format, generates
          src/core/zcl_cd_ops_param_seed.clas.abap (the delivered areas and definitions in
          ABAP, for the configuration check PARAM_INVALID and the unit tests) and checks the
          definitions against the code (portable check param_definitions_complete):
            - every parameter name the code reads has a definition: gc_param constants,
              standalone gc_param_* constants and every name completed at run time
              (gc_param_prefix + the enumerated parts in RUNTIME, taken from code constants);
            - every definition is such a name (nothing defined that no code reads);
            - the AREA of a definition is the one ZCL_CD_OPS_PARAMS_CA derives from the prefix;
            - DEFAULT_VALUE equals the default the code delivers (gc_param_default / gc_default
              constant of the same key, or the source named in DEFAULTS; none = blank);
            - flags (default X, or the read compared with abap_true / IS INITIAL) are BOOL,
              every BOOL is such a flag, and no parameter read is compared with an off token 'N';
            - the delivered default and every value row match ALLOWED_PCRE (whole value, case
              ignored, every element of a LIST - the framework validator's rule), so a value
              the framework would refuse never ships (e.g. FMON_PRISM_THROTTLE_SCOPE C);
            - the generated class is up to date.
Usage:    python3 tools/param_definitions.py           -> regenerate the seed class
          python3 tools/param_definitions.py --check   -> report drift / incompleteness, exit 1
Modification log:
2026-11-07 | Initial version (parameters moved to ZCA_PARAM).
2026-11-07 | Default and value rows checked against ALLOWED_PCRE (design review: queue scope C).
2026-11-07 | RETENTION_DAYS_PAY_OUTCOME default from the purge target (canonical payment outcome).
2026-11-08 | Table consolidation: generated DEFINITIONS( ) in parts of PART_ROWS rows; DEFAULTS may scale
           | a constant ('const', file, constant, factor - e.g. hours to minutes).
"""
import csv
import io
import itertools
import os
import re
import sys

AREAS_CSV = os.path.join('config', 'param_areas.csv')
DEFS_CSV = os.path.join('config', 'param_definitions.csv')
VALUES_CSV = os.path.join('config', 'param_values.csv')
SEED = os.path.join('src', 'core', 'zcl_cd_ops_param_seed.clas.abap')
ADAPTER = os.path.join('src', 'core', 'zcl_cd_ops_params_ca.clas.abap')
OPS_TYPES = os.path.join('src', 'core', 'zif_cd_ops_types.intf.abap')

AREA_COLS = ['AREA', 'DESCRIPTION', 'OWNER_TEAM', 'PROD_EDITABLE', 'ACTIVE']
DEF_COLS = ['AREA', 'NAME', 'KIND', 'VALUE_TYPE', 'MIN_VALUE', 'MAX_VALUE', 'DEFAULT_VALUE', 'ALLOWED_PCRE',
            'INTERFACE_NAME', 'MANDATORY', 'DEVELOPER_OWNED', 'DESCRIPTION', 'OWNER']
VALUE_COLS = ['AREA', 'NAME', 'NUMB', 'SIGN', 'OPTI', 'LOW', 'HIGH']
KINDS = ('P', 'S')
VTYPES = ('INT', 'DEC', 'CHAR', 'BOOL', 'DATE', 'TIME', 'LIST', 'PCRE', 'DDIC', 'CLASS')
IDENT = re.compile(r'^[A-Z][A-Z0-9_]*$')
INT = re.compile(r'^[+-]?[0-9]+$')

# Names completed at run time: prefix constant -> the enumerated parts (from code constants).
# ('const', file, name) one value; ('struct', file, structure, [components] or None = all);
# ('list', file, name) comma list; ('product', part, part) joined with '_'.
RUNTIME = {
    (OPS_TYPES, 'gc_param_prefix-alert'):
        ('const', os.path.join('src', 'hck', 'zif_cd_hck_types.intf.abap'), 'gc_param_default-mail_route'),
    (OPS_TYPES, 'gc_param_prefix-retention_days'):
        ('struct', os.path.join('src', 'core', 'zif_cd_ops_purge_dao.intf.abap'), 'gc_target', None),
    (OPS_TYPES, 'gc_param_prefix-sla_days'):
        ('product', ('struct', OPS_TYPES, 'gc_pe_area', ['ebs', 'file_monitor', 'health_check']),
                    ('struct', OPS_TYPES, 'gc_severity', ['block', 'error', 'warning'])),
    # Monitor freshness per area (table consolidation 2026-11-08, was ZCD_OPS_MONCFG)
    (OPS_TYPES, 'gc_param_prefix-stale_after_min'):
        ('struct', OPS_TYPES, 'gc_pe_area', ['ebs', 'file_monitor', 'health_check']),
    (os.path.join('src', 'hck', 'zif_cd_hck_types.intf.abap'), 'gc_param_prefix-max_age'):
        ('list', os.path.join('src', 'hck', 'zif_cd_hck_types.intf.abap'), 'gc_param_default-watch_pe_areas'),
    (os.path.join('src', 'hck', 'zif_cd_hck_types.intf.abap'), 'gc_param_prefix-max_run'):
        ('list', os.path.join('src', 'hck', 'zif_cd_hck_types.intf.abap'), 'gc_param_default-watch_pe_areas'),
    (os.path.join('src', 'ebs', 'zif_cd_ebs_types.intf.abap'), 'gc_param_prefix-parser'):
        ('struct', os.path.join('src', 'ebs', 'zif_cd_ebs_types.intf.abap'), 'gc_format', None),
    (os.path.join('src', 'hck', 'zif_cd_hck_runtime_types.intf.abap'), 'gc_param_prefix-btc_info'):
        ('struct', os.path.join('src', 'ebs', 'zif_cd_ebs_types.intf.abap'), 'gc_scheme', None),
}

_RULE_BASE = os.path.join('src', 'ebs', 'zcl_cd_ebs_rule_base.clas.abap')
_SCORE = os.path.join('src', 'hck', 'zcl_cd_hck_score.clas.abap')
_PURGE = os.path.join('src', 'core', 'zcl_cd_ops_purge.clas.abap')
# Defaults the code delivers outside the gc_param_default / gc_default convention:
# name -> ('const', file, constant[, factor]) or ('regex', file, pattern with one group)
DEFAULTS = {
    'SLA_DAYS_DEFAULT': ('const', OPS_TYPES, 'gc_param_default-sla_days'),
    'EBS_DUP_LOOKBACK_DAYS': ('const', os.path.join('src', 'ebs', 'zcl_cd_ebs_r_r22_dup_history.clas.abap'),
                              'gc_default_days'),
    'EBS_KEYLEN_DOCNO': ('const', _RULE_BASE, 'gc_default_docno_length'),
    'EBS_KEYLEN_ZTNUM': ('const', _RULE_BASE, 'gc_default_ztnum_length'),
    'EBS_INFLIGHT_HOURS': ('const', _RULE_BASE, 'gc_default_inflight_hours'),
    'EBS_PARSER_BAI2': ('const', os.path.join('src', 'ebs', 'zif_cd_ebs_types.intf.abap'), 'gc_param_default-parser_bai2'),
    'EBS_PARSER_CAMT053': ('const', os.path.join('src', 'ebs', 'zif_cd_ebs_types.intf.abap'),
                           'gc_param_default-parser_camt'),
    'EBS_PARSER_CAMT054': ('const', os.path.join('src', 'ebs', 'zif_cd_ebs_types.intf.abap'),
                           'gc_param_default-parser_camt'),
    'FMON_TIME_ZONE': ('const', OPS_TYPES, 'gc_time_zone_utc'),
    'FMON_AGE_BASIS': ('const', os.path.join('src', 'fmon', 'zif_cd_fmon_types.intf.abap'), 'gc_age_basis-after_receipt'),
    'FMON_PRISM_MAX_BYTES': ('const', os.path.join('src', 'fmon', 'zif_cd_fmon_prism_types.intf.abap'),
                             'gc_default_max_bytes'),
    'FMON_PRISM_INSTANT': ('const', os.path.join('src', 'fmon', 'zif_cd_fmon_prism_types.intf.abap'),
                           'gc_default_instant'),
    'HCK_SUPPRESS_MAX_DAYS': ('const', os.path.join('src', 'hck', 'zif_cd_hck_suppress_types.intf.abap'),
                              'gc_default_max_days'),
    'HCK_FLAT_TOL_PCT': ('const', os.path.join('src', 'hck', 'zcl_cd_hck_threshold.clas.abap'),
                         'gc_default_flat_tol_pct'),
    'HCK_SCORE_GREEN_MIN': ('regex', _SCORE, r'rs_rules-green_min\s*=\s*(\d+)\.'),
    'HCK_SCORE_AMBER_MIN': ('regex', _SCORE, r'rs_rules-amber_min\s*=\s*(\d+)\.'),
    'HCK_WEIGHT_H': ('regex', _SCORE, r'rs_rules-weight_high\s*=\s*(\d+)\.'),
    'HCK_WEIGHT_M': ('regex', _SCORE, r'rs_rules-weight_medium\s*=\s*(\d+)\.'),
    'HCK_WEIGHT_L': ('regex', _SCORE, r'rs_rules-weight_low\s*=\s*(\d+)\.'),
    'RETENTION_DAYS_RUN': ('regex', _PURGE, r'gc_target-run\s+default_days\s*=\s*(\d+)'),
    'RETENTION_DAYS_ALERT_LOG': ('regex', _PURGE, r'gc_target-alert_log\s+default_days\s*=\s*(\d+)'),
    'RETENTION_DAYS_FMON_EVENT': ('regex', _PURGE, r'gc_target-fmon_event\s+default_days\s*=\s*(\d+)'),
    'RETENTION_DAYS_HCK_METRIC': ('regex', _PURGE, r'gc_target-hck_metric\s+default_days\s*=\s*(\d+)'),
    'RETENTION_DAYS_FMON_PRISM': ('regex', _PURGE, r'gc_target-fmon_prism\s+default_days\s*=\s*(\d+)'),
    'RETENTION_DAYS_HCK_RESULT': ('regex', _PURGE, r'gc_target-hck_result\s+default_days\s*=\s*(\d+)'),
    'RETENTION_DAYS_PAY_OUTCOME': ('regex', _PURGE, r'gc_target-pay_outcome\s+default_days\s*=\s*(\d+)'),
    # Stale thresholds (minutes): the values the dashboards' CDS literals hold (cds_abap_parity) -
    # FMON 3 x its 5-minute cadence, EBS / HCK = HCK_MAX_AGE_HOURS (26 h) in minutes
    'MON_STALE_AFTER_MIN_FMON': ('const', os.path.join('src', 'fmon', 'zif_cd_fmon_types.intf.abap'),
                                 'gc_dashboard-stale_after_min'),
    'MON_STALE_AFTER_MIN_EBS': ('const', os.path.join('src', 'hck', 'zif_cd_hck_types.intf.abap'),
                                'gc_param_default-max_age_hours', 60),
    'MON_STALE_AFTER_MIN_HCK': ('const', os.path.join('src', 'hck', 'zif_cd_hck_types.intf.abap'),
                                'gc_param_default-max_age_hours', 60),
}

TYPES_FILE = re.compile(r'zif_cd_\w*types\.intf\.abap$')
# Definitions per generated method (DEFINITIONS( ) collects the parts; abaplint method_length 120)
PART_ROWS = 100
TRUE_VALUES = ('X', 'abap_true')


# ------------------------------------------------------------------ reading
def _read(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def _code(text):
    """ABAP without comments (literals kept)."""
    out = []
    for line in text.splitlines():
        if line.lstrip().startswith('*'):
            out.append('')
            continue
        res, lit = [], None
        for ch in line:
            if lit:
                res.append(ch)
                if ch == lit:
                    lit = None
                continue
            if ch in "'`|":
                lit = ch
            elif ch == '"':
                break
            res.append(ch)
        out.append(''.join(res))
    return '\n'.join(out)


def _literal(raw):
    raw = raw.strip()
    if raw[:1] in "'`":
        return raw[1:-1].replace("''", "'").replace('``', '`').rstrip() if raw[:1] == "'" else raw[1:-1]
    return raw


def constants(path):
    """name (lower case; structure components as struct-comp) -> value of every constant of a file."""
    out = {}
    if not os.path.exists(path):
        return out
    struct = None
    for line in _code(_read(path)).splitlines():
        m = re.search(r'BEGIN\s+OF\s+(\w+)\s*,', line, re.I)
        if m:
            struct = m.group(1).lower()
            continue
        if struct and re.search(r'END\s+OF\s+' + struct + r'\b', line, re.I):
            struct = None
            continue
        m = re.match(r"^\s*(?:CONSTANTS\s*:?\s+)?(\w+)\s+TYPE\s+[^.,]*?\bVALUE\s+('(?:[^']|'')*'|`[^`]*`|[-\w=>]+)",
                     line, re.I)
        if not m:
            continue
        if struct:
            out[f'{struct}-{m.group(1).lower()}'] = _literal(m.group(2))
        elif re.match(r'^\s*CONSTANTS\b', line, re.I):
            out[m.group(1).lower()] = _literal(m.group(2))
    return out


def _resolve(root, value, path):
    """A constant whose value names another constant (zif_x=>gc_y-z or gc_y-z) -> its literal."""
    m = re.fullmatch(r'(?:(\w+)=>)?(\w+(?:-\w+)?)', value or '')
    if not m or not m.group(1) and '-' not in value:
        return value
    file = path
    if m.group(1):
        hits = [os.path.join(d, f) for d, _, fs in os.walk(os.path.join(root, 'src'))
                for f in fs if f.split('.')[0] == m.group(1).lower() and f.endswith('.intf.abap')]
        if not hits:
            return value
        file = hits[0]
    return constants(file).get(m.group(2).lower(), value)


def load_csv(root, rel, cols):
    path = os.path.join(root, rel)
    if not os.path.exists(path):
        return None, [f'{rel}: missing']
    with open(path, encoding='utf-8', newline='') as fh:
        reader = csv.DictReader(fh)
        rows = list(reader)
        header = reader.fieldnames or []
    if header != cols:
        return rows, [f'{rel}: header must be {",".join(cols)}']
    return rows, []


# ------------------------------------------------------------------ expected names
def _parts(root, spec):
    kind = spec[0]
    if kind == 'const':
        return [constants(os.path.join(root, spec[1])).get(spec[2], '')]
    if kind == 'list':
        return [p.strip() for p in constants(os.path.join(root, spec[1])).get(spec[2], '').split(',') if p.strip()]
    if kind == 'struct':
        consts = constants(os.path.join(root, spec[1]))
        prefix = spec[2] + '-'
        return [v for k, v in consts.items() if k.startswith(prefix) and (spec[3] is None or k[len(prefix):] in spec[3])]
    if kind == 'product':
        return ['_'.join(p) for p in itertools.product(_parts(root, spec[1]), _parts(root, spec[2]))]
    raise ValueError(spec)


def expected_names(root, runtime=None):
    """name -> (file, constant key, kind) of every parameter name the code reads."""
    runtime = RUNTIME if runtime is None else runtime
    names = {}
    src = os.path.join(root, 'src')
    for d, _, files in sorted(os.walk(src)):
        for f in sorted(files):
            if not f.endswith('.abap') or 'testclasses' in f:
                continue
            path = os.path.join(d, f)
            rel = os.path.relpath(path, root)
            for key, value in constants(path).items():
                struct = key.split('-')[0]
                if TYPES_FILE.search(f) and struct == 'gc_param' and '-' in key:
                    names[value] = (rel, key, 'constant')
                elif '-' not in key and re.fullmatch(r'gc_param_\w+', key) \
                        and not re.fullmatch(r'gc_param_(default|prefix|area\w*)', key) \
                        and re.search(r'\b' + key + r'\s+TYPE\s+\S*ty_param_name\b', _read(path), re.I):
                    names[value] = (rel, key, 'constant')
    for (rel, key), spec in runtime.items():
        prefix = constants(os.path.join(root, rel)).get(key)
        if prefix is None:
            continue
        for part in _parts(root, spec):
            names[prefix + part] = (rel, key, 'runtime')
    return names


def area_map(root):
    """[(prefix, area)] as ZCL_CD_OPS_PARAMS_CA derives the area from the name."""
    text = _code(_read(os.path.join(root, ADAPTER))) if os.path.exists(os.path.join(root, ADAPTER)) else ''
    consts = constants(os.path.join(root, OPS_TYPES))
    pairs = re.findall(r'prefix\s*=\s*zif_cd_ops_types=>(gc_param_area_prefix-\w+)\s+'
                       r'area\s*=\s*zif_cd_ops_types=>(gc_param_area-\w+)', text, re.I)
    return [(consts.get(p.lower(), ''), consts.get(a.lower(), '')) for p, a in pairs]


def code_default(root, name, ref, defaults=None):
    """The default the code delivers for a parameter ('' when it delivers none)."""
    defaults = DEFAULTS if defaults is None else defaults
    if name in defaults:
        spec = defaults[name]
        path = os.path.join(root, spec[1])
        if spec[0] == 'const':
            value = _resolve(root, constants(path).get(spec[2].lower(), '<missing ' + spec[2] + '>'), path)
            # ('const', file, constant, factor): an integer constant in another unit (e.g. hours -> minutes)
            return str(int(value) * spec[3]) if len(spec) > 3 and INT.match(value) else value
        m = re.search(spec[2], _code(_read(path))) if os.path.exists(path) else None
        return m.group(1) if m else '<missing ' + spec[2] + '>'
    rel, key, kind = ref
    if kind != 'constant' or '-' not in key:
        return ''
    consts = constants(os.path.join(root, rel))
    comp = key.split('-', 1)[1]
    for struct in ('gc_param_default', 'gc_default'):
        if f'{struct}-{comp}' in consts:
            return _resolve(root, consts[f'{struct}-{comp}'], os.path.join(root, rel))
    return ''


def _statements(root):
    """(file, statement) of the production code."""
    for d, _, files in sorted(os.walk(os.path.join(root, 'src'))):
        for f in sorted(files):
            if f.endswith('.abap') and 'testclasses' not in f and not TYPES_FILE.search(f):
                for stmt in _code(_read(os.path.join(d, f))).split('.\n'):
                    yield os.path.join(d, f), stmt


def flag_reads(root, names):
    """Names whose read is compared with abap_true / IS INITIAL, and names compared with 'N'."""
    flags, off_tokens = set(), set()
    refs = {}
    for name, (rel, key, kind) in names.items():
        if kind == 'constant':
            refs.setdefault(key, set()).add(name)
    for _, stmt in _statements(root):
        for key, nm in refs.items():
            if not re.search(r'\b' + re.escape(key) + r'\b(?!-)', stmt, re.I):
                continue
            if re.search(r"(=|<>)\s*abap_true\b|\bIS\s+(NOT\s+)?INITIAL\b", stmt, re.I):
                flags.update(nm)
            if re.search(r"(=|<>)\s*'N'", stmt):
                off_tokens.update(nm)
    return flags, off_tokens


# ------------------------------------------------------------------ format
def pattern_mismatch(d, value):
    """The element of value that ALLOWED_PCRE refuses (None: allowed or no pattern). Same rule as
    ZCL_CA_PARAM_VALIDATOR->CHECK_PATTERN: whole value, case ignored, each element of a LIST."""
    if not d['ALLOWED_PCRE'] or not value:
        return None
    elements = [e.strip() for e in value.split(',')] if d['VALUE_TYPE'] == 'LIST' else [value]
    try:
        pattern = re.compile(d['ALLOWED_PCRE'], re.IGNORECASE)
    except re.error:
        return None
    return next((e for e in elements if not pattern.fullmatch(e)), None)


def format_failures(areas, defs, values):
    fails = []
    area_ids = [a['AREA'] for a in areas]
    for a in areas:
        if not IDENT.match(a['AREA']) or len(a['AREA']) > 16:
            fails.append(f"{AREAS_CSV}: area {a['AREA']} is not an identifier of at most 16 characters")
        if len(a['DESCRIPTION']) > 60 or len(a['OWNER_TEAM']) > 30:
            fails.append(f"{AREAS_CSV}: {a['AREA']} description > 60 or owner team > 30 characters")
        if a['PROD_EDITABLE'] not in ('', 'X') or a['ACTIVE'] not in ('', 'X'):
            fails.append(f"{AREAS_CSV}: {a['AREA']} flags must be X or blank")
    seen = set()
    keys = []
    for d in defs:
        key = (d['AREA'], d['NAME'])
        keys.append(key)
        where = f"{DEFS_CSV}: {d['AREA']} / {d['NAME']}"
        vt = d['VALUE_TYPE']
        if key in seen:
            fails.append(f'{where}: defined twice')
        seen.add(key)
        if d['AREA'] not in area_ids:
            fails.append(f'{where}: area not in {AREAS_CSV}')
        if not IDENT.match(d['NAME']) or len(d['NAME']) > 30:
            fails.append(f'{where}: name is not an identifier of at most 30 characters')
        if d['KIND'] not in KINDS or vt not in VTYPES:
            fails.append(f'{where}: kind P / S and a framework value type expected')
        if vt == 'LIST' and d['KIND'] != 'P':
            fails.append(f'{where}: LIST needs kind P')
        if (d['MIN_VALUE'] or d['MAX_VALUE']) and vt not in ('INT', 'DEC', 'DATE', 'TIME'):
            fails.append(f'{where}: MIN / MAX only for INT, DEC, DATE, TIME')
        if d['INTERFACE_NAME'] and vt != 'CLASS':
            fails.append(f'{where}: interface only for CLASS')
        if d['ALLOWED_PCRE'] and vt == 'BOOL':
            fails.append(f'{where}: no allowed pattern for BOOL')
        if vt == 'INT':
            for col in ('MIN_VALUE', 'MAX_VALUE', 'DEFAULT_VALUE'):
                if d[col] and not INT.match(d[col]):
                    fails.append(f'{where}: {col} {d[col]} is not an integer')
            if d['MIN_VALUE'] and d['MAX_VALUE'] and int(d['MIN_VALUE']) > int(d['MAX_VALUE']):
                fails.append(f'{where}: MIN above MAX')
        if vt == 'BOOL' and d['DEFAULT_VALUE'] not in ('', 'X'):
            fails.append(f'{where}: BOOL default must be X or blank')
        if vt in ('CLASS', 'DDIC') and d['DEVELOPER_OWNED'] != 'X':
            fails.append(f'{where}: {vt} values are developer-owned')
        if d['MANDATORY'] not in ('', 'X') or d['DEVELOPER_OWNED'] not in ('', 'X'):
            fails.append(f'{where}: MANDATORY / DEVELOPER_OWNED must be X or blank')
        if len(d['DESCRIPTION']) > 60 or len(d['OWNER']) > 30 or not d['DESCRIPTION']:
            fails.append(f'{where}: description (1-60) or owner (30) length')
        if d['ALLOWED_PCRE']:
            try:
                re.compile(d['ALLOWED_PCRE'])
            except re.error:
                fails.append(f'{where}: allowed pattern does not compile')
        refused = pattern_mismatch(d, d['DEFAULT_VALUE'])
        if refused is not None:
            fails.append(f"{where}: default '{refused}' does not match the allowed pattern {d['ALLOWED_PCRE']}")
    order = {a: i for i, a in enumerate(area_ids)}
    if keys != sorted(keys, key=lambda k: (order.get(k[0], len(order)), k[1])):
        fails.append(f'{DEFS_CSV}: rows must be sorted by area (order of {AREAS_CSV}) and name')
    by_key = {(d['AREA'], d['NAME']): d for d in defs}
    for v in values or []:
        where = f"{VALUES_CSV}: {v['AREA']} / {v['NAME']} / {v['NUMB']}"
        d = by_key.get((v['AREA'], v['NAME']))
        if not d:
            fails.append(f'{where}: no definition')
            continue
        if d['KIND'] == 'P' and (v['NUMB'] != '1' or v['SIGN'] not in ('', 'I') or v['OPTI'] not in ('', 'EQ')
                                 or v['HIGH']):
            fails.append(f'{where}: kind P has one row NUMB 1, I / EQ, no HIGH')
        if d['VALUE_TYPE'] == 'INT' and v['LOW'] and not INT.match(v['LOW']):
            fails.append(f'{where}: {v["LOW"]} is not an integer')
        if d['VALUE_TYPE'] == 'BOOL' and v['LOW'] not in ('', 'X'):
            fails.append(f'{where}: BOOL value must be X or blank')
        refused = pattern_mismatch(d, v['LOW'])
        if refused is not None:
            fails.append(f"{where}: value '{refused}' does not match the allowed pattern {d['ALLOWED_PCRE']}")
    return fails


# ------------------------------------------------------------------ completeness
def completeness_failures(root, defs, runtime=None, defaults=None):
    fails = []
    names = expected_names(root, runtime)
    defined = {d['NAME']: d for d in defs}
    for name, (rel, key, kind) in sorted(names.items()):
        if name not in defined:
            fails.append(f'{DEFS_CSV}: {name} ({rel} {key}{", run time" if kind == "runtime" else ""}) has no definition')
    for name in sorted(defined):
        if name not in names:
            fails.append(f'{DEFS_CSV}: {name} is defined but read by no code (no parameter-name constant or '
                         f'enumerated run-time name)')
    amap = area_map(root)
    if not amap:
        fails.append(f'{ADAPTER}: no prefix / area table found')
    for name, d in sorted(defined.items()):
        area = next((a for p, a in amap if p and name.startswith(p)), None)
        if amap and area != d['AREA']:
            fails.append(f"{DEFS_CSV}: {name} is in area {d['AREA']}, ZCL_CD_OPS_PARAMS_CA reads it from {area}")
    for name in sorted(set(names) & set(defined)):
        expected = code_default(root, name, names[name], defaults)
        if expected in TRUE_VALUES:
            expected = 'X'
        if defined[name]['DEFAULT_VALUE'] != expected:
            fails.append(f"{DEFS_CSV}: {name} default '{defined[name]['DEFAULT_VALUE']}' differs from the code "
                         f"default '{expected}'")
    flags, off_tokens = flag_reads(root, names)
    for name in sorted(set(names) & set(defined)):
        is_bool = defined[name]['VALUE_TYPE'] == 'BOOL'
        flag = name in flags or code_default(root, name, names[name], defaults) in TRUE_VALUES
        if flag and not is_bool:
            fails.append(f'{DEFS_CSV}: {name} is a flag (X / blank) and must be value type BOOL')
        if is_bool and not flag:
            fails.append(f'{DEFS_CSV}: {name} is BOOL but the code neither delivers X nor compares it with abap_true')
    for name in sorted(off_tokens):
        fails.append(f"{name}: a parameter read is compared with 'N' - a BOOL is off with a blank value row")
    return fails


# ------------------------------------------------------------------ generator
def _abap(value):
    return "'" + value.replace("'", "''") + "'" if value else 'IS INITIAL'


GEN_HEADER = """*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_param_seed.clas.abap
*& Purpose:
*& Delivered parameter areas and definitions of the suite in the framework
*& ZCA_PARAM - GENERATED by tools/param_definitions.py from
*& config/param_areas.csv and config/param_definitions.csv; do not edit,
*& regenerate. areas( ) / definitions( ) feed the configuration check
*& PARAM_INVALID (every delivered name must be defined and readable). An
*& instance is the in-memory parameter store of the unit tests: a
*& ZCL_CA_PARAM_DAO_MEM with the delivered areas and definitions, set( )
*& maintains a value row, params( ) returns ZCL_CD_OPS_PARAMS_CA over the
*& real read logic ZCL_CA_PARAM. Production-safe: no database.
*& Modification log:
*& 2026-11-07 | Initial version (generated; parameters moved to ZCA_PARAM).
*& 2026-11-08 | DEFINITIONS( ) collects parts of at most 100 rows (method length; the table
*&            | consolidation moved settings of retired customizing tables into definitions).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - delivered parameter definitions</p>
"! Delivered areas and definitions (generated from config/param_*.csv) and the
"! in-memory parameter store of the unit tests over the real framework logic.
CLASS zcl_cd_ops_param_seed DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Delivered areas (config/param_areas.csv)
    CLASS-METHODS areas
      RETURNING
        VALUE(rt_areas) TYPE zif_ca_param_types=>tt_area_row.

    "! Delivered definitions (config/param_definitions.csv)
    CLASS-METHODS definitions
      RETURNING
        VALUE(rt_definitions) TYPE zif_ca_param_types=>tt_definition.

    "! In-memory store with the delivered areas and definitions and no value row
    METHODS constructor.

    "! Maintain the value row of a parameter (replaces the rows it had); visible at once
    METHODS set
      IMPORTING
        iv_name        TYPE zif_cd_ops_types=>ty_param_name
        iv_value       TYPE clike
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_cd_ops_param_seed.

    "! Remove the value rows of a parameter: the definition default applies again
    METHODS remove
      IMPORTING
        iv_name TYPE zif_cd_ops_types=>ty_param_name.

    "! The in-memory data access (e.g. for ZCL_CA_PARAM_INJECTOR=>INJECT_DAO)
    METHODS dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zcl_ca_param_dao_mem.

    "! The suite's parameter adapter over the real read logic
    METHODS params
      RETURNING
        VALUE(ro_params) TYPE REF TO zif_cd_ops_params.


  PRIVATE SECTION.
"""

GEN_FOOTER = """{decls}    DATA mo_dao TYPE REF TO zcl_ca_param_dao_mem.
    DATA mo_param TYPE REF TO zif_ca_param.
    DATA mo_params TYPE REF TO zif_cd_ops_params.

ENDCLASS.



CLASS zcl_cd_ops_param_seed IMPLEMENTATION.

  METHOD areas.
{areas}  ENDMETHOD.


  METHOD definitions.
{defs}  ENDMETHOD.

{parts}

  METHOD constructor.
    mo_dao = NEW #( ).
    LOOP AT areas( ) ASSIGNING FIELD-SYMBOL(<ls_area>).
      mo_dao->add_area( <ls_area> ).
    ENDLOOP.
    LOOP AT definitions( ) ASSIGNING FIELD-SYMBOL(<ls_definition>).
      mo_dao->add_definition( <ls_definition> ).
    ENDLOOP.
    mo_param = NEW zcl_ca_param( io_dao = mo_dao ).
  ENDMETHOD.


  METHOD set.
    DATA ls_value TYPE zif_ca_param_types=>ty_value_row.

    remove( iv_name ).
    ls_value-area = zcl_cd_ops_params_ca=>area_of( iv_name ).
    ls_value-name = iv_name.
    ls_value-numb = 1.
    ls_value-sign = zif_ca_param_types=>gc_sign-include.
    ls_value-opti = zif_ca_param_types=>gc_option-eq.
    ls_value-low  = iv_value.
    mo_dao->add_value( ls_value ).
    ro_self = me.
  ENDMETHOD.


  METHOD remove.
    mo_dao->remove_values( iv_area = zcl_cd_ops_params_ca=>area_of( iv_name )
                           iv_name = iv_name ).
    " the read logic buffers per area: the next read sees the change
    mo_param->refresh( ).
  ENDMETHOD.


  METHOD dao.
    ro_dao = mo_dao.
  ENDMETHOD.


  METHOD params.
    IF mo_params IS NOT BOUND.
      mo_params = NEW zcl_cd_ops_params_ca( io_param = mo_param ).
    ENDIF.
    ro_params = mo_params.
  ENDMETHOD.

ENDCLASS.
"""


def render(areas, defs):
    out = [GEN_HEADER]
    a_lines, d_lines = [], []
    for i, a in enumerate(areas, 1):
        n = f'gc_a{i:02d}'
        out.append(f'    CONSTANTS:\n      BEGIN OF {n},\n'
                   f"        area          TYPE zif_ca_param_types=>ty_area VALUE {_abap(a['AREA'])},\n"
                   f"        description   TYPE zif_ca_param_types=>ty_description VALUE {_abap(a['DESCRIPTION'])},\n"
                   f"        owner_team    TYPE zif_ca_param_types=>ty_owner VALUE {_abap(a['OWNER_TEAM'])},\n"
                   f"        prod_editable TYPE abap_bool VALUE {_abap(a['PROD_EDITABLE'])},\n"
                   f"        active        TYPE abap_bool VALUE {_abap(a['ACTIVE'])},\n"
                   f'      END OF {n}.\n')
        a_lines.append(f'    INSERT CORRESPONDING #( {n} ) INTO TABLE rt_areas.\n')
    for i, d in enumerate(defs, 1):
        n = f'gc_d{i:03d}'
        rows = [('area', 'zif_ca_param_types=>ty_area', 'AREA'), ('name', 'zif_ca_param_types=>ty_name', 'NAME'),
                ('kind', 'zif_ca_param_types=>ty_kind', 'KIND'),
                ('value_type', 'zif_ca_param_types=>ty_value_type', 'VALUE_TYPE'),
                ('min_value', 'zif_ca_param_types=>ty_value', 'MIN_VALUE'),
                ('max_value', 'zif_ca_param_types=>ty_value', 'MAX_VALUE'),
                ('default_value', 'zif_ca_param_types=>ty_value', 'DEFAULT_VALUE'),
                ('allowed_pcre', 'zif_ca_param_types=>ty_value', 'ALLOWED_PCRE'),
                ('interface_name', 'zif_ca_param_types=>ty_interface', 'INTERFACE_NAME'),
                ('mandatory', 'abap_bool', 'MANDATORY'), ('developer_owned', 'abap_bool', 'DEVELOPER_OWNED'),
                ('description', 'zif_ca_param_types=>ty_description', 'DESCRIPTION'),
                ('owner', 'zif_ca_param_types=>ty_owner', 'OWNER')]
        out.append(f'    CONSTANTS:\n      BEGIN OF {n},\n')
        for comp, typ, col in rows:
            out.append(f'        {comp:<15} TYPE {typ} VALUE {_abap(d[col])},\n')
        out.append(f'      END OF {n}.\n')
        d_lines.append(f'    INSERT CORRESPONDING #( {n} ) INTO TABLE rt_definitions.\n')
    # A method holds at most PART_ROWS definitions (abaplint method_length 120 statements):
    # DEFINITIONS( ) collects the parts
    decls, calls, parts = [], [], []
    for k, start in enumerate(range(0, len(d_lines), PART_ROWS), 1):
        chunk = d_lines[start:start + PART_ROWS]
        decls.append(f'    "! Delivered definitions {start + 1}-{start + len(chunk)} (at most {PART_ROWS} per method)\n'
                     f'    CLASS-METHODS definitions_part_{k}\n'
                     f'      RETURNING\n'
                     f'        VALUE(rt_definitions) TYPE zif_ca_param_types=>tt_definition.\n\n')
        calls.append(f'    INSERT LINES OF definitions_part_{k}( ) INTO TABLE rt_definitions.\n')
        parts.append(f'\n  METHOD definitions_part_{k}.\n{"".join(chunk)}  ENDMETHOD.\n\n')
    out.append(GEN_FOOTER.format(areas=''.join(a_lines), defs=''.join(calls), decls=''.join(decls),
                                 parts=''.join(parts)))
    return ''.join(out)


def load(root):
    areas, f1 = load_csv(root, AREAS_CSV, AREA_COLS)
    defs, f2 = load_csv(root, DEFS_CSV, DEF_COLS)
    values, f3 = load_csv(root, VALUES_CSV, VALUE_COLS) if os.path.exists(os.path.join(root, VALUES_CSV)) \
        else ([], [])
    return areas or [], defs or [], values or [], f1 + f2 + f3


def failures(root, runtime=None, defaults=None):
    """Every failure of the portable check param_definitions_complete."""
    areas, defs, values, fails = load(root)
    if fails:
        return fails
    fails += format_failures(areas, defs, values)
    fails += completeness_failures(root, defs, runtime, defaults)
    seed = os.path.join(root, SEED)
    if not os.path.exists(seed) or _read(seed) != render(areas, defs):
        fails.append(f'{SEED}: not generated from the seed files - run python3 tools/param_definitions.py')
    return fails


def counts(root):
    _, defs, _, _ = load(root)
    out = {}
    for d in defs:
        out.setdefault(d['AREA'], {}).setdefault(d['VALUE_TYPE'], 0)
        out[d['AREA']][d['VALUE_TYPE']] += 1
    return out


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--check' in sys.argv:
        fails = failures(root)
        for f in fails:
            print('FAIL ' + f)
        print(f'param_definitions_complete: {len(fails)} failure(s)')
        sys.exit(1 if fails else 0)
    areas, defs, values, fails = load(root)
    fails += format_failures(areas, defs, values)
    if fails:
        for f in fails:
            print('FAIL ' + f)
        sys.exit(1)
    text = render(areas, defs)
    path = os.path.join(root, SEED)
    old = _read(path) if os.path.exists(path) else ''
    if old != text:
        with io.open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
    print(f'{SEED}: {"written" if old != text else "up to date"} ({len(areas)} areas, {len(defs)} definitions)')


if __name__ == '__main__':
    main()
