#!/usr/bin/env python3
"""
Artifact: tools/abaptools/param_definitions.py (shared engine)
Purpose:  Runtime parameters in the framework ZCA_PARAM, for the operations framework ZCA_OPS
          (area CA_OPS) and every consumer: each component's wrapper tools/param_definitions.py
          loads its own instance (abaptools.fresh) and calls configure( ) with its profile (seed
          class, adapter, types files, prefix sources, run-time names, code defaults, templates).
          Reads the seed files
          config/param_areas.csv, config/param_definitions.csv and config/param_values.csv
          (format: param-framework/docs/ONBOARDING.md section 6), checks their format,
          generates the seed class (the delivered areas and definitions in ABAP, for a
          configuration check and the unit tests) and checks the definitions against the code
          (check param_definitions_complete):
            - every parameter name the code reads has a definition: gc_param constants,
              standalone gc_param_* constants and every name completed at run time
              (gc_param_prefix + the enumerated parts in RUNTIME, taken from code constants);
            - every definition is such a name (nothing defined that no code reads);
            - the AREA of a definition is the one ZCL_CA_OPS_PARAMS derives from the longest
              name prefix (framework prefixes + the consumer's, AREA_SOURCES);
            - DEFAULT_VALUE equals the default the code delivers (gc_param_default / gc_default
              constant of the same key, or the source named in DEFAULTS; none = blank);
            - flags (default X, or the read compared with abap_true / IS INITIAL) are BOOL,
              every BOOL is such a flag, and no parameter read is compared with an off token 'N';
            - the delivered default and every value row match ALLOWED_PCRE (whole value, case
              ignored, every element of a LIST - the framework validator's rule), so a value
              the framework would refuse never ships;
            - the generated class is up to date.
Usage:    python3 tools/param_definitions.py           -> regenerate the seed class
          python3 tools/param_definitions.py --check   -> report drift / incompleteness, exit 1
Modification log:
2026-11-07 | Initial version (parameters moved to ZCA_PARAM).
2026-11-07 | Default and value rows checked against ALLOWED_PCRE (design review: queue scope C).
2026-11-07 | RETENTION_DAYS_PAY_OUTCOME default from the purge target (canonical payment outcome).
2026-11-08 | Table consolidation: generated DEFINITIONS( ) in parts of PART_ROWS rows; DEFAULTS may scale
           | a constant ('const', file, constant, factor - e.g. hours to minutes).
2026-11-08 | MON_STALE_AFTER_MIN_CORE: snapshot lag threshold of the payment outcome (core freshness row).
2026-11-10 | Moved to ops-framework/tools and made configurable (configure( ): paths, seed class, types
           | files, prefix sources, run-time names, code defaults, templates): one generator for the
           | framework's seed ZCL_CA_OPS_PARAM_SEED (profile FRAMEWORK, this file) and a consumer's
           | (ops-suite/tools/param_definitions.py); longest prefix decides the area; areas of other
           | components allowed in the definitions (EXTRA_AREAS_CSV); DEFAULTS kind 'definition'.
2026-11-10 | Moved to the shared tools (tools/abaptools): the engine only; the framework's profile is
           | ops-framework/tools/param_definitions.py, every consumer has its own wrapper.
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
# Profile settings (configure( ), set by each component's wrapper tools/param_definitions.py):
# SEED seed class; ADAPTER parameter adapter class; OPS_TYPES types interface of the adapter;
# EXTRA_AREAS_CSV / EXTRA_DEFS_CSV areas / definitions of other components a definition / value row
# may name (validated, not generated); AREA_SOURCES (file with the adapter's prefix -> area pairs,
# types file, prefix pattern); RUNTIME names completed at run time: prefix constant -> the enumerated
# parts (from code constants: ('const', file, name) one value; ('struct', file, structure,
# [components] or None = all); ('list', file, name) comma list; ('product', part, part) joined with
# '_'); DEFAULTS defaults the code delivers outside the gc_param_default / gc_default convention
# (name -> ('const', file, constant[, factor]) or ('regex', file, pattern with one group) or
# ('definition',) - the definition is the single source); TYPES_FILE pattern of the profile's types
# interfaces; GEN_HEADER / GEN_FOOTER templates of the seed class.
SEED = None
ADAPTER = None
OPS_TYPES = None
EXTRA_AREAS_CSV = []
EXTRA_DEFS_CSV = []
AREA_SOURCES = []
RUNTIME = {}
DEFAULTS = {}
TYPES_FILE = None
GEN_HEADER = None
GEN_FOOTER = None

AREA_COLS = ['AREA', 'DESCRIPTION', 'OWNER_TEAM', 'PROD_EDITABLE', 'ACTIVE']
DEF_COLS = ['AREA', 'NAME', 'KIND', 'VALUE_TYPE', 'MIN_VALUE', 'MAX_VALUE', 'DEFAULT_VALUE', 'ALLOWED_PCRE',
            'INTERFACE_NAME', 'MANDATORY', 'DEVELOPER_OWNED', 'DESCRIPTION', 'OWNER']
VALUE_COLS = ['AREA', 'NAME', 'NUMB', 'SIGN', 'OPTI', 'LOW', 'HIGH']
KINDS = ('P', 'S')
VTYPES = ('INT', 'DEC', 'CHAR', 'BOOL', 'DATE', 'TIME', 'LIST', 'PCRE', 'DDIC', 'CLASS')
IDENT = re.compile(r'^[A-Z][A-Z0-9_]*$')
INT = re.compile(r'^[+-]?[0-9]+$')

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
    """[(prefix, area)] as ZCL_CA_OPS_PARAMS derives the area from the name (every source of
    AREA_SOURCES; the longest prefix that starts a name decides)."""
    pairs = []
    for rel, types_rel, pattern in AREA_SOURCES:
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            continue
        consts = constants(os.path.join(root, types_rel))
        for p, a in re.findall(pattern, _code(_read(path)), re.I):
            pairs.append((consts.get(p.lower(), ''), consts.get(a.lower(), '')))
    return pairs


def area_of(amap, name):
    """Area of the longest prefix of amap that starts name (None: no prefix)."""
    hits = [(len(p), a) for p, a in amap if p and name.startswith(p)]
    return max(hits)[1] if hits else None


def code_default(root, name, ref, defaults=None):
    """The default the code delivers for a parameter ('' when it delivers none)."""
    defaults = DEFAULTS if defaults is None else defaults
    if name in defaults:
        spec = defaults[name]
        if spec[0] == 'definition':
            return None
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


def format_failures(areas, defs, values, extra_areas=(), extra_defs=()):
    fails = []
    area_ids = [a['AREA'] for a in areas]
    known_areas = area_ids + list(extra_areas)
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
        if d['AREA'] not in known_areas:
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
    order = {a: i for i, a in enumerate(area_ids + [x for x in extra_areas if x not in area_ids])}
    if keys != sorted(keys, key=lambda k: (order.get(k[0], len(order)), k[1])):
        fails.append(f'{DEFS_CSV}: rows must be sorted by area (order of {AREAS_CSV}) and name')
    by_key = {(d['AREA'], d['NAME']): d for d in list(extra_defs) + list(defs)}
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
        area = area_of(amap, name)
        if amap and area != d['AREA']:
            fails.append(f"{DEFS_CSV}: {name} is in area {d['AREA']}, ZCL_CA_OPS_PARAMS reads it from {area}")
    for name in sorted(set(names) & set(defined)):
        expected = code_default(root, name, names[name], defaults)
        if expected is None:
            continue
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


def configure(**settings):
    """Switch the module to a consumer's profile (module-level settings of the same names:
    SEED, ADAPTER, OPS_TYPES, AREA_SOURCES, EXTRA_AREAS_CSV, RUNTIME, DEFAULTS, TYPES_FILE,
    GEN_HEADER, GEN_FOOTER)."""
    unknown = [k for k in settings if k not in globals()]
    if unknown:
        raise KeyError(unknown)
    globals().update(settings)


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


def extra_areas(root):
    """Area IDs of other components (EXTRA_AREAS_CSV) a definition may name."""
    out = []
    for rel in EXTRA_AREAS_CSV:
        rows, _ = load_csv(root, rel, AREA_COLS)
        out += [r['AREA'] for r in rows or []]
    return out


def extra_definitions(root):
    """Definitions of other components (EXTRA_DEFS_CSV) a value row may name."""
    out = []
    for rel in EXTRA_DEFS_CSV:
        rows, _ = load_csv(root, rel, DEF_COLS)
        out += rows or []
    return out


def failures(root, runtime=None, defaults=None):
    """Every failure of the check param_definitions_complete."""
    areas, defs, values, fails = load(root)
    if fails:
        return fails
    fails += format_failures(areas, defs, values, extra_areas(root), extra_definitions(root))
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


def main(root):
    """Command line of a wrapper: regenerate the seed class of the component root, or --check."""
    if '--check' in sys.argv:
        fails = failures(root)
        for f in fails:
            print('FAIL ' + f)
        print(f'param_definitions_complete: {len(fails)} failure(s)')
        sys.exit(1 if fails else 0)
    areas, defs, values, fails = load(root)
    fails += format_failures(areas, defs, values, extra_areas(root), extra_definitions(root))
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
