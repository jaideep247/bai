#!/usr/bin/env python3
"""Generate the abapGit metadata of one component folder (folder logic PREFIX).

Shared engine (tools/abaptools); each component calls it from its wrapper
<component>/tools/abapgit_serialize.py with its settings (config/repository.json or a dict).

Inputs (all paths relative to the component folder):
  config/repository.json        settings (below)
  <message class source>.md     message class rows  '| 001 | text |' or, with
                                message_class.columns = 3, '| 001 | constant | text |'
  config/authorizations.json    authorization object classes, fields and objects (optional)
  docs/text_elements/*.texts.md text pools of programs and classes (title, text symbols,
                                selection texts; optional)
  ddic/dictionary.json          domains and data elements (optional)
  ddic/[<folder>/]*.tabl.ddl    tables (ADT DDL source); <folder> = target sub-folder of src/
  src/**                        ABAP and RAP sources (classes, interfaces, programs, CDS, BDEF, SRVD, DCL)

Settings:
  starting_folder, master_language, packages {sub-folder: [package, text]}, ddic_package_folder,
  message_class {name, text, source, folder, columns 2|3, truncate (cut texts at 73 instead of
  refusing them)}, abapgit_xml (path of .abapgit.xml, default .abapgit.xml), ignore (IGNORE list,
  default /.gitignore /LICENSE /README.md /CHANGELOG.md), secondary_indexes (serialize the DDL
  comment lines '// @index <ID> [UNIQUE]: F1, F2' as DD12V / DD17V; default off).

Outputs:
  .abapgit.xml, src/**/package.devc.xml, src/**/*.xml (CLAS, INTF, PROG, TABL, DTEL, DOMA,
  MSAG, AUTH, SUSO, SUSC, DDLS, DDLX, BDEF, SRVD, DCLS).

Every output is staged in memory and validated first; files are written only when
every input was serialized cleanly (exit 1 and nothing written otherwise). Unchanged
files are never rewritten.   Usage:  python3 tools/abapgit_serialize.py [--check]
--check writes nothing and exits 1 when a generated file is missing or out of date.

Modification log:
2026-11-07 | Initial version (parameter framework).
2026-11-10 | Operations framework: message rows without a constant column, programs, text pools.
2026-11-10 | One engine for every component (tools/abaptools): message columns, .abapgit.xml path and
           | IGNORE list, secondary indexes and message truncation are settings; output unchanged.
"""
import json
import os
import re
from xml.sax.saxutils import escape

HEAD = '<?xml version="1.0" encoding="utf-8"?>\n'


def wrap(serializer, body):
    return (HEAD + f'<abapGit version="v1.0.0" serializer="{serializer}" serializer_version="v1.0.0">\n'
            ' <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n  <asx:values>\n'
            + body + '  </asx:values>\n </asx:abap>\n</abapGit>\n')


def tag(name, value, indent=4):
    return ' ' * indent + f'<{name}>{escape(str(value))}</{name}>\n'


class Stage:
    """Collects outputs and problems; flushes only when there is no problem."""

    def __init__(self, root):
        self.root = root
        self.pending = {}
        self.problems = []

    def write(self, rel, text):
        self.pending[os.path.normpath(os.path.join(self.root, rel))] = text

    def changed(self):
        out = []
        for path, text in self.pending.items():
            if not os.path.exists(path) or read(path) != text:
                out.append(os.path.relpath(path, self.root))
        return sorted(out)

    def flush(self):
        for path, text in self.pending.items():
            if not os.path.exists(path) or read(path) != text:
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, 'w', encoding='utf-8', newline='\n') as handle:
                    handle.write(text)


def read(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read()


# --------------------------------------------------------------------------- repository
DEFAULT_IGNORE = ['/.gitignore', '/LICENSE', '/README.md', '/CHANGELOG.md']


def repository(stage, cfg):
    ignore = ''.join(f'    <item>{item}</item>\n' for item in cfg.get('ignore', DEFAULT_IGNORE))
    stage.write(cfg.get('abapgit_xml', '.abapgit.xml'), HEAD +
                '<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n <asx:values>\n  <DATA>\n'
                f'   <MASTER_LANGUAGE>{cfg["master_language"]}</MASTER_LANGUAGE>\n'
                f'   <STARTING_FOLDER>{cfg["starting_folder"]}</STARTING_FOLDER>\n'
                '   <FOLDER_LOGIC>PREFIX</FOLDER_LOGIC>\n   <IGNORE>\n' + ignore +
                '   </IGNORE>\n  </DATA>\n </asx:values>\n</asx:abap>\n')
    for folder, (name, text) in cfg['packages'].items():
        if len(name) > 30 or len(text) > 60:
            stage.problems.append(f'package {name}: name > 30 or text > 60 characters')
        stage.write(os.path.join('src', folder, 'package.devc.xml'),
                    wrap('LCL_OBJECT_DEVC', '   <DEVC>\n' + tag('CTEXT', text) + '   </DEVC>\n'))


# --------------------------------------------------------------------------- text pools
def tpool(texts):
    """TPOOL of a program or class from docs/text_elements/<object>.texts.md (empty if none)."""
    if not os.path.exists(texts):
        return ''
    out = '   <TPOOL>\n'
    kinds = {'Title': 'R', 'Text symbol': 'I', 'Selection text': 'S'}
    for kind, key, text in re.findall(r'^\| (Title|Text symbol|Selection text) \| (\S+) \| (.*?) \|$',
                                      read(texts), re.M):
        entry = (' ' * 8 + text) if kinds[kind] == 'S' else text
        out += '    <item>\n' + tag('ID', kinds[kind], 5)
        if kinds[kind] != 'R':
            out += tag('KEY', key, 5)
        out += tag('ENTRY', entry, 5) + tag('LENGTH', len(entry), 5) + '    </item>\n'
    return out + '   </TPOOL>\n'


# --------------------------------------------------------------------------- classes, interfaces, RAP sources
def description(text, default):
    m = re.search(r'shorttext synchronized">([^<]*)<', text)
    return (m.group(1) if m else default)[:60]


def label_of(text, default):
    m = re.search(r"@EndUserText\.label\s*:\s*'([^']*)'", text)
    return (m.group(1) if m else default)[:60]


def sources(stage):
    src = os.path.join(stage.root, 'src')
    for d, _, files in os.walk(src):
        for f in sorted(files):
            p = os.path.join(d, f)
            rel = os.path.relpath(p, stage.root)
            name = f.split('.')[0].upper()
            low = f.split('.')[0].lower()
            if f.endswith('.clas.abap'):
                text = read(p)
                body = '   <VSEOCLASS>\n' + tag('CLSNAME', name) + tag('LANGU', 'E') + \
                       tag('DESCRIPT', description(text, name))
                behavior = re.search(r'FOR\s+BEHAVIOR\s+OF\s+(\w+)', text, re.I)
                if name.startswith('ZCX_'):
                    body += tag('CATEGORY', '40')
                elif behavior:
                    body += tag('CATEGORY', '06')
                elif re.search(r'^CLASS\s+\w+\s+DEFINITION[^.]*\bFOR\s+TESTING\b', text, re.I | re.M | re.S):
                    body += tag('CATEGORY', '05')
                body += tag('STATE', '1') + tag('CLSCCINCL', 'X') + tag('FIXPT', 'X') + tag('UNICODE', 'X')
                if behavior:
                    body += tag('CLSDEFINT', behavior.group(1).upper())
                if os.path.exists(p.replace('.clas.abap', '.clas.testclasses.abap')):
                    body += tag('WITH_UNIT_TESTS', 'X')
                body += '   </VSEOCLASS>\n'
                body += tpool(os.path.join(stage.root, 'docs', 'text_elements', f.replace('.clas.abap', '.clas.texts.md')))
                stage.write(rel.replace('.clas.abap', '.clas.xml'), wrap('LCL_OBJECT_CLAS', body))
            elif f.endswith('.prog.abap'):
                body = '   <PROGDIR>\n' + tag('NAME', name) + tag('SUBC', '1') + tag('RLOAD', 'E') + \
                       tag('FIXPT', 'X') + tag('UCCHECK', 'X') + '   </PROGDIR>\n'
                body += tpool(os.path.join(stage.root, 'docs', 'text_elements', f.replace('.prog.abap', '.prog.texts.md')))
                stage.write(rel.replace('.prog.abap', '.prog.xml'), wrap('LCL_OBJECT_PROG', body))
            elif f.endswith('.intf.abap'):
                text = read(p)
                body = '   <VSEOINTERF>\n' + tag('CLSNAME', name) + tag('LANGU', 'E') + \
                       tag('DESCRIPT', description(text, name)) + tag('EXPOSURE', '2') + tag('STATE', '1') + \
                       tag('UNICODE', 'X') + '   </VSEOINTERF>\n'
                stage.write(rel.replace('.intf.abap', '.intf.xml'), wrap('LCL_OBJECT_INTF', body))
            elif f.endswith('.ddls.asddls'):
                text = read(p)
                kind = ('A' if re.search(r'\bdefine\s+abstract\s+entity\b', text, re.I)
                        else 'P' if re.search(r'\bas\s+projection\s+on\b', text, re.I) else 'W')
                body = '   <DDLS>\n' + tag('DDLNAME', name) + tag('DDLANGUAGE', 'E') + \
                       tag('DDTEXT', label_of(text, name)) + tag('SOURCE_TYPE', kind) + '   </DDLS>\n'
                stage.write(rel.replace('.ddls.asddls', '.ddls.xml'), wrap('LCL_OBJECT_DDLS', body))
            elif f.endswith('.ddlx.asddlxs'):
                text = read(p)
                m = re.search(r'^//\s*UI annotations:\s*(.*)$', text, re.M)
                desc = (m.group(1) if m else name)[:60]
                body = '   <DDLX>\n    <METADATA>\n' + tag('NAME', name, 5) + tag('DESCRIPTION', desc, 5) + \
                       tag('MASTER_LANGUAGE', 'EN', 5) + '    </METADATA>\n   </DDLX>\n'
                stage.write(rel.replace('.ddlx.asddlxs', '.ddlx.xml'), wrap('LCL_OBJECT_DDLX', body))
            elif f.endswith('.bdef.asbdef'):
                text = read(p)
                m = re.search(r'^//\s*Behavior:\s*(.*)$', text, re.M)
                desc = (m.group(1) if m else f'Behavior for {name}')[:60]
                srcuri = f'./{low}/source/main'
                links = ''
                for href, rel_, typ, title in (
                        (f'{srcuri}/versions', 'http://www.sap.com/adt/relations/versions', None, 'Historic versions'),
                        (srcuri, 'http://www.sap.com/adt/relations/source', 'text/plain', 'Source Content'),
                        (srcuri, 'http://www.sap.com/adt/relations/source', 'text/html', 'Source Content (HTML)')):
                    links += '     <item>\n' + tag('HREF', href, 6) + tag('REL', rel_, 6) + \
                             (tag('TYPE', typ, 6) if typ else '') + tag('TITLE', title, 6) + '     </item>\n'
                body = '   <BDEF>\n' + tag('NAME', name) + tag('TYPE', 'BDEF/BDO') + \
                       tag('DESCRIPTION', desc) + tag('DESCRIPTION_TEXT_LIMIT', '60') + \
                       tag('LANGUAGE', 'EN') + '    <LINKS>\n' + links + '    </LINKS>\n' + \
                       tag('MASTER_LANGUAGE', 'EN') + tag('ABAP_LANGU_VERSION', 'X') + tag('SOURCE_URI', srcuri) + \
                       tag('SOURCE_TYPE', 'ABAP_SOURCE') + tag('SOURCE_FIXED_POINT_ARITHMETIC', 'true') + \
                       tag('SOURCE_UNICODE_CHECKS_ACTIVE', 'true') + '   </BDEF>\n'
                stage.write(rel.replace('.bdef.asbdef', '.bdef.xml'), wrap('LCL_OBJECT_BDEF', body))
            elif f.endswith('.srvd.srvdsrv'):
                text = read(p)
                body = '   <SRVD>\n' + tag('NAME', name) + tag('TYPE', 'SRVD/SRV') + \
                       tag('DESCRIPTION', label_of(text, name)) + tag('LANGUAGE', 'EN') + \
                       tag('MASTER_LANGUAGE', 'EN') + tag('SOURCE_URI', f'./{low}/source/main') + \
                       tag('SOURCE_TYPE', 'ABAP_SOURCE') + tag('SOURCE_ORIGIN_DESCRIPTION', 'ABAP Development Tools') + \
                       tag('SRVD_SOURCE_TYPE', 'S') + tag('SRVD_SOURCE_TYPE_DESC', 'Definition') + '   </SRVD>\n'
                stage.write(rel.replace('.srvd.srvdsrv', '.srvd.xml'), wrap('LCL_OBJECT_SRVD', body))
            elif f.endswith('.dcls.asdcls'):
                text = read(p)
                body = '   <DCLS>\n' + tag('DCLNAME', name) + tag('DESCRIPTION', label_of(text, name)) + '   </DCLS>\n'
                stage.write(rel.replace('.dcls.asdcls', '.dcls.xml'), wrap('LCL_OBJECT_DCLS', body))


# --------------------------------------------------------------------------- domains, data elements
BUILTIN_DOMAIN = {'CHAR': ('C', 2), 'NUMC': ('N', 2)}


def dictionary(stage, spec, folder):
    domains = {}
    for dom in spec.get('domains', []):
        name, dtype, length = dom['name'].upper(), dom['type'].upper(), int(dom['length'])
        domains[name] = dtype
        if len(name) > 30 or len(dom['text']) > 60 or dtype not in BUILTIN_DOMAIN:
            stage.problems.append(f'domain {name}: name > 30, text > 60 or type {dtype} not supported')
            continue
        body = ('   <DD01V>\n' + tag('DOMNAME', name) + tag('DDLANGUAGE', 'E') + tag('DATATYPE', dtype) +
                tag('LENG', f'{length:06d}') + tag('OUTPUTLEN', f'{length:06d}') +
                (tag('LOWERCASE', 'X') if dom.get('lowercase') else '') +
                (tag('VALEXI', 'X') if dom.get('values') else '') +
                (tag('ENTITYTAB', dom['value_table'].upper()) if dom.get('value_table') else '') +
                tag('DDTEXT', dom['text']) + tag('DOMMASTER', 'E') + '   </DD01V>\n')
        if dom.get('values'):
            body += '   <DD07V_TAB>\n'
            for pos, (value, text) in enumerate(dom['values'], start=1):
                if len(value) > length or len(text) > 60:
                    stage.problems.append(f'domain {name}: fixed value {value} too long or text > 60')
                body += ('    <DD07V>\n' + tag('DOMNAME', name, 5) + tag('VALPOS', f'{pos:04d}', 5) +
                         tag('DDLANGUAGE', 'E', 5) + tag('DOMVALUE_L', value, 5) + tag('DDTEXT', text, 5) +
                         '    </DD07V>\n')
            body += '   </DD07V_TAB>\n'
        stage.write(os.path.join('src', folder, name.lower() + '.doma.xml'), wrap('LCL_OBJECT_DOMA', body))
    limits = {'short': 10, 'medium': 20, 'long': 40, 'heading': 55, 'text': 60}
    for dtel in spec.get('data_elements', []):
        name = dtel['name'].upper()
        bad = [k for k, n in limits.items() if len(dtel[k]) > n]
        if len(name) > 30 or bad:
            stage.problems.append(f'data element {name}: name > 30 or label(s) too long: {bad}')
            continue
        body = ('   <DD04V>\n' + tag('ROLLNAME', name) + tag('DDLANGUAGE', 'E') +
                tag('DOMNAME', dtel['domain'].upper()) + tag('HEADLEN', '55') + tag('SCRLEN1', '10') +
                tag('SCRLEN2', '20') + tag('SCRLEN3', '40') + tag('DDTEXT', dtel['text']) +
                tag('REPTEXT', dtel['heading']) + tag('SCRTEXT_S', dtel['short']) +
                tag('SCRTEXT_M', dtel['medium']) + tag('SCRTEXT_L', dtel['long']) +
                tag('DTELMASTER', 'E') + tag('REFKIND', 'D') + '   </DD04V>\n')
        stage.write(os.path.join('src', folder, name.lower() + '.dtel.xml'), wrap('LCL_OBJECT_DTEL', body))
    return domains


# --------------------------------------------------------------------------- tables
BUILTIN = {  # type -> (INTTYPE, intlen(fn of len), DATATYPE, leng(fn of len))
    'char': ('C', lambda n: 2 * n, 'CHAR', lambda n: n),
    'numc': ('N', lambda n: 2 * n, 'NUMC', lambda n: n),
    'clnt': ('C', lambda n: 6, 'CLNT', lambda n: 3),
    'dats': ('D', lambda n: 16, 'DATS', lambda n: 8),
    'tims': ('T', lambda n: 12, 'TIMS', lambda n: 6),
    'int1': ('b', lambda n: 1, 'INT1', lambda n: 3),
    'int2': ('s', lambda n: 2, 'INT2', lambda n: 5),
    'int4': ('X', lambda n: 4, 'INT4', lambda n: 10),
    'int8': ('8', lambda n: 8, 'INT8', lambda n: 19),
    'string': ('g', lambda n: 8, 'STRG', lambda n: 0),
}
INCLUDE = re.compile(r'^"(%\w+)"\s*:\s*include\s+(\w+)$', re.I)
FIELD = re.compile(r'^(key\s+)?([a-z_0-9]+)\s*:\s*([a-z_0-9.]+)(?:\((\d+)(?:,(\d+))?\))?\s*(not null)?'
                   r'(?:\s+with\s+foreign\s+key\s+\[([^\]]*)\]\s+(\w+)\s+where\s+(.+))?$', re.I | re.S)
CONDITION = re.compile(r'(\w+)\s*=\s*(\w+)\.(\w+)', re.I)
# Secondary indexes: DDL comment lines '// @index <ID> [UNIQUE]: F1, F2' (setting secondary_indexes)
INDEX = re.compile(r'^\s*//\s*@index\s+(\w{1,3})\s*(UNIQUE)?\s*:\s*(.+?)\s*$', re.I | re.M)
CARDINALITY = {'0..*,1': ('CN', '1'), '1..*,1': ('N', '1'), '0..1,1': ('C', '1'), '1,1': ('1', '1')}


def statements(block):
    """Field statements of a DDL field block: comments and annotations dropped, joined to one line."""
    lines = []
    for line in block.splitlines():
        line = line.split('//')[0].strip()
        if line and not line.startswith('@'):
            lines.append(line)
    return [re.sub(r'\s+', ' ', s).strip() for s in ' '.join(lines).split(';') if s.strip()]


def parse_table(text, fname):
    """Returns (table, problems) - table = dict(name, label, dclass, maint, fields[])."""
    heads = (re.search(r'define table (\w+)', text),
             re.search(r"@EndUserText.label\s*:\s*'([^']*)'", text),
             re.search(r'deliveryClass\s*:\s*#(\w)', text),
             re.search(r'dataMaintenance\s*:\s*#(\w+)', text))
    if not all(heads) or '{' not in text or '}' not in text:
        return None, [f'{fname}: table name, label, delivery class, maintenance or field block missing']
    table = {'name': heads[0].group(1).upper(), 'label': heads[1].group(1), 'dclass': heads[2].group(1),
             'maint': heads[3].group(1), 'fields': [], 'indexes': INDEX.findall(text)}
    problems = []
    if len(table['name']) > 16:
        problems.append(f'{fname}: table name {table["name"]} longer than 16 characters')
    if len(table['label']) > 60:
        problems.append(f'{fname}: label longer than 60 characters')
    block = text.split('{', 1)[1].rsplit('}', 1)[0]
    for stmt in statements(block):
        inc = INCLUDE.match(stmt)
        if inc:
            table['fields'].append({'include': inc.group(2).upper(), 'group': inc.group(1).upper()})
            continue
        m = FIELD.match(stmt)
        if not m:
            problems.append(f'{fname}: cannot parse "{stmt}"')
            continue
        key, name, ftype, length, decimals, notnull, card, checktable, where = m.groups()
        field = {'name': name.upper(), 'key': bool(key), 'type': ftype.lower(), 'length': int(length or 0),
                 'decimals': int(decimals or 0), 'notnull': bool(notnull)}
        if len(field['name']) > 30:
            problems.append(f'{fname}: field {field["name"]} longer than 30 characters')
        if checktable:
            conds = CONDITION.findall(where)
            if card.replace(' ', '') not in CARDINALITY or not conds:
                problems.append(f'{fname}: foreign key of {field["name"]}: cardinality [{card}] or condition')
            field['fk'] = {'checktable': checktable.upper(), 'card': card.replace(' ', ''),
                           'conditions': [(c.upper(), t.upper(), f.upper()) for c, t, f in conds]}
            if any(t != table['name'] for _, t, _ in field['fk']['conditions']):
                problems.append(f'{fname}: foreign key of {field["name"]} must compare with {table["name"]} fields')
        table['fields'].append(field)
    names = {f['name'] for f in table['fields'] if 'name' in f}
    for f in table['fields']:
        for _, _, own in f.get('fk', {}).get('conditions', []):
            if own not in names:
                problems.append(f'{fname}: foreign key field {own} is not a field of {table["name"]}')
    return table, problems


def field_types(table, domains, dtel_domain):
    """DATATYPE and DOMNAME per field, for foreign key rows."""
    out = {}
    for f in table['fields']:
        if 'name' not in f:
            continue
        if f['type'].startswith('abap.'):
            kind = f['type'][5:]
            out[f['name']] = ('MANDT' if kind == 'clnt' else '', BUILTIN.get(kind, ('', '', kind.upper()))[2])
        else:
            dom = dtel_domain.get(f['type'].upper(), '')
            out[f['name']] = (dom, domains.get(dom, ''))
    return out


def index_xml(table, problems):
    """DD12V / DD17V of the secondary indexes of the DDL comment lines '// @index <ID> [UNIQUE]: F1, F2'
    (abapGit TABL layout, zcl_abapgit_object_tabl: one row element per line type)."""
    tab = table['name']
    names = {f['name'] for f in table['fields'] if 'name' in f}
    head, items = '', ''
    seen = set()
    for idx, unique, cols in table.get('indexes', []):
        cols_list = [c.strip().upper() for c in cols.split(',') if c.strip()]
        bad = [c for c in cols_list if c not in names]
        if idx.upper() in seen or not cols_list or bad:
            problems.append(f'{table.get("file", tab)}: index {idx} duplicate, empty or unknown field(s) {bad}')
            continue
        seen.add(idx.upper())
        head += ('    <DD12V>\n' + tag('SQLTAB', tab, 5) + tag('INDEXNAME', idx.upper(), 5) +
                 tag('AS4LOCAL', 'A', 5) + tag('DDLANGUAGE', 'E', 5) +
                 (tag('UNIQUEFLAG', 'X', 5) if unique else '') +
                 tag('DDTEXT', f'{tab}~{idx.upper()}', 5) + '    </DD12V>\n')
        for pos, col in enumerate(cols_list, start=1):
            items += ('    <DD17V>\n' + tag('SQLTAB', tab, 5) + tag('INDEXNAME', idx.upper(), 5) +
                      tag('POSITION', f'{pos:04d}', 5) + tag('AS4LOCAL', 'A', 5) +
                      tag('FIELDNAME', col, 5) + '    </DD17V>\n')
    if not head:
        return ''
    return '   <DD12V>\n' + head + '   </DD12V>\n   <DD17V>\n' + items + '   </DD17V>\n'


def table_xml(table, all_tables, domains, dtel_domain, indexes=False):
    """TABL XML of one parsed table; indexes = serialize its secondary indexes (setting)."""
    problems = []
    rows = []
    for f in table['fields']:
        if 'include' in f:
            rows.append('    <DD03P>\n' + tag('FIELDNAME', '.INCLUDE', 5) + tag('ADMINFIELD', '0', 5) +
                        tag('PRECFIELD', f['include'], 5) + tag('MASK', '      S', 5) +
                        tag('DDTEXT', 'Standard Include for Draft Administration (BDL Syntax Check)', 5) +
                        tag('COMPTYPE', 'S', 5) + tag('GROUPNAME', f['group'], 5) + '    </DD03P>\n')
            continue
        fx = '    <DD03P>\n' + tag('FIELDNAME', f['name'], 5)
        if f['key']:
            fx += tag('KEYFLAG', 'X', 5)
        notnull = f['key'] or f['notnull']
        if f['type'].startswith('abap.') and f['type'] != 'abap.dec':
            kind = f['type'][5:]
            if kind not in BUILTIN:
                problems.append(f'{table["name"]}: {f["name"]} type {f["type"]} not supported')
                continue
            inttype, intlen, datatype, leng = BUILTIN[kind]
            n = f['length']
            fx += tag('ADMINFIELD', '0', 5) + tag('INTTYPE', inttype, 5) + tag('INTLEN', f'{intlen(n):06d}', 5)
            if notnull:
                fx += tag('NOTNULL', 'X', 5)
            fx += tag('DATATYPE', datatype, 5) + tag('LENG', f'{leng(n):06d}', 5) + tag('MASK', f'  {datatype}', 5)
        elif f['type'] == 'abap.dec':
            n, dec = f['length'], f['decimals']
            fx += tag('ADMINFIELD', '0', 5) + tag('INTTYPE', 'P', 5) + tag('INTLEN', f'{n // 2 + 1:06d}', 5)
            if notnull:
                fx += tag('NOTNULL', 'X', 5)
            fx += tag('DATATYPE', 'DEC', 5) + tag('LENG', f'{n:06d}', 5) + \
                tag('DECIMALS', f'{dec:06d}', 5) + tag('MASK', '  DEC', 5)
        else:
            fx += tag('ROLLNAME', f['type'].upper(), 5)
            if 'fk' in f:
                fx += tag('CHECKTABLE', f['fk']['checktable'], 5)
            fx += tag('ADMINFIELD', '0', 5)
            if notnull:
                fx += tag('NOTNULL', 'X', 5)
            if 'fk' in f:
                fx += tag('SHLPORIGIN', 'P', 5)
            fx += tag('COMPTYPE', 'E', 5)
        rows.append(fx + '    </DD03P>\n')

    customizing = table['dclass'] == 'C'
    body = ('   <DD02V>\n' + tag('TABNAME', table['name']) + tag('DDLANGUAGE', 'E') + tag('TABCLASS', 'TRANSP') +
            tag('CLIDEP', 'X') + tag('DDTEXT', table['label']) +
            tag('MAINFLAG', 'X' if table['maint'].upper() == 'ALLOWED' else '') + tag('CONTFLAG', table['dclass']) +
            tag('EXCLASS', '1') + '   </DD02V>\n'
            '   <DD09L>\n' + tag('TABNAME', table['name']) + tag('AS4LOCAL', 'A') + tag('TABKAT', '0') +
            tag('TABART', 'APPL2' if customizing else 'APPL1') +
            # customizing: fully buffered by the kernel and change-logged (SCU3, rec/client)
            (tag('PUFFERUNG', 'X') if customizing else '') +
            (tag('PROTOKOLL', 'X') if customizing else '') +
            tag('BUFALLOW', 'X' if customizing else 'N') + '   </DD09L>\n'
            '   <DD03P_TABLE>\n' + ''.join(rows) + '   </DD03P_TABLE>\n')

    fks = [f for f in table['fields'] if 'fk' in f]
    if fks:
        own_types = field_types(table, domains, dtel_domain)
        dd05m, dd08v = '', ''
        for f in fks:
            check = all_tables.get(f['fk']['checktable'])
            if check is None:
                problems.append(f'{table["name"]}: check table {f["fk"]["checktable"]} of {f["name"]} not in ddic/')
                continue
            check_keys = [c['name'] for c in check['fields'] if c.get('key')]
            for checkfield, _, own in f['fk']['conditions']:
                if checkfield not in check_keys:
                    problems.append(f'{table["name"]}: {checkfield} is not a key field of {check["name"]}')
                    continue
                dom, dtype = own_types.get(own, ('', ''))
                dd05m += ('    <DD05M>\n' + tag('TABNAME', table['name'], 5) + tag('FIELDNAME', f['name'], 5) +
                          tag('FORTABLE', table['name'], 5) + tag('FORKEY', own, 5) +
                          tag('CHECKTABLE', check['name'], 5) + tag('CHECKFIELD', checkfield, 5) +
                          tag('PRIMPOS', f'{check_keys.index(checkfield) + 1:04d}', 5) +
                          tag('DOMNAME', dom, 5) + tag('DATATYPE', dtype, 5) + '    </DD05M>\n')
            card, cardleft = CARDINALITY.get(f['fk']['card'], ('CN', '1'))
            dd08v += ('    <DD08V>\n' + tag('TABNAME', table['name'], 5) + tag('FIELDNAME', f['name'], 5) +
                      tag('CHECKTABLE', f['fk']['checktable'], 5) + tag('FRKART', 'KEY', 5) +
                      tag('CARD', card, 5) + tag('CHECKFLAG', 'X', 5) + tag('CARDLEFT', cardleft, 5) +
                      '    </DD08V>\n')
        body += '   <DD05M_TABLE>\n' + dd05m + '   </DD05M_TABLE>\n   <DD08V_TABLE>\n' + dd08v + '   </DD08V_TABLE>\n'
    if indexes:
        body += index_xml(table, problems)
    return wrap('LCL_OBJECT_TABL', body), problems


def tables(stage, domains, dtel_domain, indexes=False):
    ddic = os.path.join(stage.root, 'ddic')
    parsed = {}
    for d, _, files in os.walk(ddic):
        for f in sorted(files):
            if not f.endswith('.tabl.ddl'):
                continue
            table, problems = parse_table(read(os.path.join(d, f)), f)
            stage.problems.extend(problems)
            if table:
                table['folder'] = os.path.relpath(d, ddic) if d != ddic else ''
                table['file'] = f
                parsed[table['name']] = table
    for table in parsed.values():
        xml, problems = table_xml(table, parsed, domains, dtel_domain, indexes)
        stage.problems.extend(problems)
        stage.write(os.path.join('src', table['folder'], table['file'].replace('.tabl.ddl', '.tabl.xml')), xml)
    return parsed


# --------------------------------------------------------------------------- message class
MESSAGE_ROW = re.compile(r'^\| (\d{3}) \| (.*?) \|$', re.M)
MESSAGE_ROW_CONST = re.compile(r'^\| (\d{3}) \| (\w+) \| (.*?) \|$', re.M)


def message_rows(root, msg):
    """(number, text) of every row of the message class source (columns 2: number, text;
    columns 3: number, constant name, text)."""
    text = read(os.path.join(root, msg['source']))
    if msg.get('columns', 2) == 3:
        return [(nr, txt) for nr, _, txt in MESSAGE_ROW_CONST.findall(text)]
    return MESSAGE_ROW.findall(text)


def messages(stage, cfg):
    msg = cfg['message_class']
    rows = message_rows(stage.root, msg)
    seen = set()
    body = '   <T100A>\n' + tag('ARBGB', msg['name']) + tag('MASTERLANG', 'E') + \
           tag('STEXT', msg['text']) + '   </T100A>\n   <T100>\n'
    for nr, text in rows:
        if msg.get('truncate'):
            text = text[:73]
        if nr in seen or len(text) > 73:
            stage.problems.append(f'message {nr}: duplicate or text longer than 73 characters')
        seen.add(nr)
        body += '    <T100>\n' + tag('SPRSL', 'E', 5) + tag('ARBGB', msg['name'], 5) + tag('MSGNR', nr, 5) + \
                tag('TEXT', text, 5) + '    </T100>\n'
    body += '   </T100>\n'
    stage.write(os.path.join('src', msg['folder'], msg['name'].lower() + '.msag.xml'), wrap('LCL_OBJECT_MSAG', body))
    return rows


# --------------------------------------------------------------------------- authorizations
def authorizations(stage, folder):
    path = os.path.join(stage.root, 'config', 'authorizations.json')
    if not os.path.exists(path):
        return
    spec = json.loads(read(path))
    for cls in spec.get('object_classes', []):
        name = cls['name'].upper()
        if len(name) > 4:
            stage.problems.append(f'object class {name} longer than 4 characters')
        body = '   <TOBC>\n' + tag('OCLSS', name) + '   </TOBC>\n   <TOBCT>\n' + tag('LANGU', 'E') + \
               tag('OCLSS', name) + tag('TTEXT', cls['text'][:60]) + '   </TOBCT>\n'
        stage.write(os.path.join('src', folder, name.lower() + '.susc.xml'), wrap('LCL_OBJECT_SUSC', body))
    for field in spec.get('fields', []):
        name = field['name'].upper()
        if len(name) > 10:
            stage.problems.append(f'authorization field {name} longer than 10 characters')
        body = '   <AUTHX>\n' + tag('FIELDNAME', name) + tag('ROLLNAME', field['data_element'].upper()) + '   </AUTHX>\n'
        stage.write(os.path.join('src', folder, name.lower() + '.auth.xml'), wrap('LCL_OBJECT_AUTH', body))
    for obj in spec.get('objects', []):
        name = obj['name'].upper()
        if len(name) > 10 or len(obj['fields']) > 10:
            stage.problems.append(f'authorization object {name}: name > 10 or more than 10 fields')
        body = '   <TOBJ>\n' + tag('OBJCT', name)
        for pos, fld in enumerate(obj['fields'], start=1):
            body += tag(f'FIEL{pos % 10}', fld.upper())
        body += tag('OCLSS', obj['class'].upper()) + '   </TOBJ>\n'
        body += '   <TOBJT>\n' + tag('LANGU', 'E') + tag('OBJECT', name) + tag('TTEXT', obj['text'][:60]) + '   </TOBJT>\n'
        body += '   <TOBJVORFLG>\n' + tag('OBJCT', name) + '   </TOBJVORFLG>\n'
        body += '   <TACTZ>\n'
        for actvt in obj.get('activities', []):
            body += '    <TACTZ>\n' + tag('BROBJ', name, 5) + tag('ACTVT', actvt, 5) + '    </TACTZ>\n'
        body += '   </TACTZ>\n'
        stage.write(os.path.join('src', folder, name.lower() + '.suso.xml'), wrap('LCL_OBJECT_SUSO', body))


# --------------------------------------------------------------------------- main
def settings(root):
    """The component's settings: config/repository.json."""
    return json.loads(read(os.path.join(root, 'config', 'repository.json')))


def build(root, cfg=None):
    """Stage every output of the component folder root; cfg = its settings (default
    config/repository.json). Returns (stage, message rows)."""
    stage = Stage(root)
    cfg = cfg if cfg is not None else settings(root)
    repository(stage, cfg)
    sources(stage)
    dictionary_json = os.path.join(root, 'ddic', 'dictionary.json')
    spec = json.loads(read(dictionary_json)) if os.path.exists(dictionary_json) else {}
    domains = dictionary(stage, spec, cfg.get('ddic_package_folder', ''))
    dtel_domain = {d['name'].upper(): d['domain'].upper() for d in spec.get('data_elements', [])}
    tables(stage, domains, dtel_domain, cfg.get('secondary_indexes', False))
    rows = messages(stage, cfg)
    authorizations(stage, cfg.get('ddic_package_folder', ''))
    return stage, rows


def main(argv, root, cfg=None):
    stage, rows = build(root, cfg)
    if stage.problems:
        print('NOT SERIALIZED - no file written:', *stage.problems, sep='\n  ')
        return 1
    changed = stage.changed()
    if '--check' in argv:
        if changed:
            print('Generated files out of date (run tools/abapgit_serialize.py):', *changed, sep='\n  ')
            return 1
        print(f'abapGit metadata up to date ({len(stage.pending)} files, {len(rows)} messages)')
        return 0
    stage.flush()
    print(f'{len(changed)} file(s) written/updated of {len(stage.pending)}; {len(rows)} messages')
    return 0

