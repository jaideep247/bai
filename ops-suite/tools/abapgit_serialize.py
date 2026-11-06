#!/usr/bin/env python3
"""Generate abapGit metadata for ops-suite/src so the repository can be pulled
with abapGit (folder logic PREFIX, starting folder /ops-suite/src/).

Creates / refreshes:
  ../.abapgit.xml                          repository settings (repo root)
  src/package.devc.xml, src/<mod>/...      packages ZCD_OPS, ZCD_OPS_<MOD>
  src/**/<obj>.clas.xml|intf.xml|prog.xml  object metadata (description = ABAP Doc shorttext)
  src/<mod>/<tab>.tabl.xml                 tables, from ddic/<mod>/<tab>.tabl.ddl
  src/core/zcd_ops.msag.xml                message class, from config/zcd_ops_messages.md

Re-run after adding objects, tables or messages:  python3 tools/abapgit_serialize.py
Secondary indexes are NOT generated (create them per the comments in the DDL).
"""
import os, re, sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
HEAD = '<?xml version="1.0" encoding="utf-8"?>\n'
PACKAGES = {'': ('ZCD_OPS', 'Payment engine operations suite'),
            'core': ('ZCD_OPS_CORE', 'Ops suite: store, alerting, factory'),
            'ebs': ('ZCD_OPS_EBS', 'Ops suite: EBS validation (BAI2 / CAMT)'),
            'fmon': ('ZCD_OPS_FMON', 'Ops suite: file monitoring'),
            'hck': ('ZCD_OPS_HCK', 'Ops suite: health check, morning report')}

def wrap(serializer, body):
    return (HEAD + f'<abapGit version="v1.0.0" serializer="{serializer}" serializer_version="v1.0.0">\n'
            ' <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n  <asx:values>\n'
            + body + '  </asx:values>\n </asx:abap>\n</abapGit>\n')

def tag(name, value, indent=4):
    return ' ' * indent + f'<{name}>{escape(str(value))}</{name}>\n'

def write(path, text):
    if not os.path.exists(path) or open(path, encoding='utf-8').read() != text:
        open(path, 'w', encoding='utf-8', newline='\n').write(text)
        return 1
    return 0

def description(text, default):
    m = re.search(r'shorttext synchronized">([^<]*)<', text)
    return (m.group(1) if m else default)[:60]

changed = 0
# repository settings
changed += write(os.path.join(os.path.dirname(ROOT), '.abapgit.xml'), HEAD +
    '<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n <asx:values>\n  <DATA>\n'
    '   <MASTER_LANGUAGE>E</MASTER_LANGUAGE>\n   <STARTING_FOLDER>/ops-suite/src/</STARTING_FOLDER>\n'
    '   <FOLDER_LOGIC>PREFIX</FOLDER_LOGIC>\n   <IGNORE>\n    <item>/.gitignore</item>\n'
    '    <item>/LICENSE</item>\n    <item>/README.md</item>\n   </IGNORE>\n  </DATA>\n </asx:values>\n</asx:abap>\n')

# packages
for folder, (_, text) in PACKAGES.items():
    path = os.path.join(SRC, folder, 'package.devc.xml')
    changed += write(path, wrap('LCL_OBJECT_DEVC', '   <DEVC>\n' + tag('CTEXT', text) + '   </DEVC>\n'))

# classes, interfaces, programs
for d, _, files in os.walk(SRC):
    for f in sorted(files):
        p = os.path.join(d, f)
        name = f.split('.')[0].upper()
        if f.endswith('.clas.abap'):
            text = open(p, encoding='utf-8').read()
            body = '   <VSEOCLASS>\n' + tag('CLSNAME', name) + tag('LANGU', 'E') + \
                   tag('DESCRIPT', description(text, name))
            if name.startswith('ZCX_'):
                body += tag('CATEGORY', '40')
            body += tag('STATE', '1') + tag('CLSCCINCL', 'X') + tag('FIXPT', 'X') + tag('UNICODE', 'X')
            if os.path.exists(p.replace('.clas.abap', '.clas.testclasses.abap')):
                body += tag('WITH_UNIT_TESTS', 'X')
            body += '   </VSEOCLASS>\n'
            changed += write(p.replace('.clas.abap', '.clas.xml'), wrap('LCL_OBJECT_CLAS', body))
        elif f.endswith('.intf.abap'):
            text = open(p, encoding='utf-8').read()
            body = '   <VSEOINTERF>\n' + tag('CLSNAME', name) + tag('LANGU', 'E') + \
                   tag('DESCRIPT', description(text, name)) + tag('EXPOSURE', '2') + tag('STATE', '1') + \
                   tag('UNICODE', 'X') + '   </VSEOINTERF>\n'
            changed += write(p.replace('.intf.abap', '.intf.xml'), wrap('LCL_OBJECT_INTF', body))
        elif f.endswith('.prog.abap'):
            body = '   <PROGDIR>\n' + tag('NAME', name) + tag('SUBC', '1') + tag('RLOAD', 'E') + \
                   tag('FIXPT', 'X') + tag('UCCHECK', 'X') + '   </PROGDIR>\n'
            texts = os.path.join(ROOT, 'docs', 'text_elements', f.replace('.prog.abap', '.prog.texts.md'))
            if os.path.exists(texts):
                body += '   <TPOOL>\n'
                kinds = {'Title': 'R', 'Text symbol': 'I', 'Selection text': 'S'}
                for kind, key, text in re.findall(r'^\| (Title|Text symbol|Selection text) \| (\S+) \| (.*?) \|$',
                                                  open(texts, encoding='utf-8').read(), re.M):
                    entry = (' ' * 8 + text) if kinds[kind] == 'S' else text
                    body += '    <item>\n' + tag('ID', kinds[kind], 5)
                    if kinds[kind] != 'R':
                        body += tag('KEY', key, 5)
                    body += tag('ENTRY', entry, 5) + tag('LENGTH', len(entry), 5) + '    </item>\n'
                body += '   </TPOOL>\n'
            changed += write(p.replace('.prog.abap', '.prog.xml'), wrap('LCL_OBJECT_PROG', body))

# tables from DDL
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
FIELD = re.compile(r'^\s*(key\s+)?([a-z_0-9]+)\s*:\s*([a-z_0-9.]+)(?:\((\d+)(?:,(\d+))?\))?\s*(not null)?\s*;', re.I)
unknown = []
for module in ('core', 'ebs', 'fmon', 'hck'):
    ddic = os.path.join(ROOT, 'ddic', module)
    if not os.path.isdir(ddic):
        continue
    for f in sorted(os.listdir(ddic)):
        if not f.endswith('.tabl.ddl'):
            continue
        text = open(os.path.join(ddic, f), encoding='utf-8').read()
        tab = re.search(r'define table (\w+)', text).group(1).upper()
        label = re.search(r"@EndUserText.label\s*:\s*'([^']*)'", text).group(1)[:60]
        dclass = re.search(r'deliveryClass\s*:\s*#(\w)', text).group(1)
        maint = re.search(r'dataMaintenance\s*:\s*#(\w+)', text).group(1)
        fields = []
        for line in text.split('{', 1)[1].split('}', 1)[0].splitlines():
            line = line.split('//')[0]
            m = FIELD.match(line)
            if not m:
                if line.strip():
                    unknown.append(f'{f}: {line.strip()}')
                continue
            key, fname, ftype, length, decimals, notnull = m.groups()
            fx = '    <DD03P>\n' + tag('FIELDNAME', fname.upper(), 5)
            if key:
                fx += tag('KEYFLAG', 'X', 5)
            if ftype.startswith('abap.') and ftype[5:] != 'dec':
                kind = ftype[5:]
                if kind not in BUILTIN:
                    unknown.append(f'{f}: {fname} {ftype}')
                    continue
                inttype, intlen, datatype, leng = BUILTIN[kind]
                n = int(length or 0)
                fx += tag('ADMINFIELD', '0', 5) + tag('INTTYPE', inttype, 5) + \
                      tag('INTLEN', f'{intlen(n):06d}', 5)
                if key or notnull:
                    fx += tag('NOTNULL', 'X', 5)
                fx += tag('DATATYPE', datatype, 5) + tag('LENG', f'{leng(n):06d}', 5) + \
                      tag('MASK', f'  {datatype}', 5)
            elif ftype == 'abap.dec':
                n, dec = int(length), int(decimals or 0)
                fx += tag('ADMINFIELD', '0', 5) + tag('INTTYPE', 'P', 5) + tag('INTLEN', f'{n // 2 + 1:06d}', 5)
                if key or notnull:
                    fx += tag('NOTNULL', 'X', 5)
                fx += tag('DATATYPE', 'DEC', 5) + tag('LENG', f'{n:06d}', 5) + \
                      tag('DECIMALS', f'{dec:06d}', 5) + tag('MASK', '  DEC', 5)
            else:  # data element
                fx += tag('ROLLNAME', ftype.upper(), 5) + tag('ADMINFIELD', '0', 5)
                if key or notnull:
                    fx += tag('NOTNULL', 'X', 5)
                fx += tag('COMPTYPE', 'E', 5)
            fields.append(fx + '    </DD03P>\n')
        customizing = dclass == 'C'
        body = ('   <DD02V>\n' + tag('TABNAME', tab) + tag('DDLANGUAGE', 'E') + tag('TABCLASS', 'TRANSP') +
                tag('CLIDEP', 'X') + tag('DDTEXT', label) +
                tag('MAINFLAG', 'X' if maint.upper() == 'ALLOWED' else '') + tag('CONTFLAG', dclass) +
                tag('EXCLASS', '1') + '   </DD02V>\n'
                '   <DD09L>\n' + tag('TABNAME', tab) + tag('AS4LOCAL', 'A') + tag('TABKAT', '0') +
                tag('TABART', 'APPL2' if customizing else 'APPL1') +
                # Review 3.5: customizing tables fully buffered by the kernel, not cached in ABAP
                (tag('PUFFERUNG', 'X') if customizing else '') +
                # SOX: changes to rules, maps, thresholds and alert routing are logged (SCU3);
                # needs profile parameter rec/client set by Basis
                (tag('PROTOKOLL', 'X') if customizing else '') +
                tag('BUFALLOW', 'X' if customizing else 'N') + '   </DD09L>\n'
                '   <DD03P_TABLE>\n' + ''.join(fields) + '   </DD03P_TABLE>\n')
        target = os.path.join(SRC, module, f.replace('.tabl.ddl', '.tabl.xml'))
        changed += write(target, wrap('LCL_OBJECT_TABL', body))

# message class
rows = re.findall(r'^\| (\d{3}) \| (.*?) \|$', open(os.path.join(ROOT, 'config', 'zcd_ops_messages.md'),
                                                     encoding='utf-8').read(), re.M)
body = '   <T100A>\n' + tag('ARBGB', 'ZCD_OPS') + tag('MASTERLANG', 'E') + \
       tag('STEXT', 'Payment engine operations suite') + '   </T100A>\n   <T100>\n'
for nr, text in rows:
    body += '    <T100>\n' + tag('SPRSL', 'E', 5) + tag('ARBGB', 'ZCD_OPS', 5) + tag('MSGNR', nr, 5) + \
            tag('TEXT', text[:73], 5) + '    </T100>\n'
body += '   </T100>\n'
changed += write(os.path.join(SRC, 'core', 'zcd_ops.msag.xml'), wrap('LCL_OBJECT_MSAG', body))

print(f'{changed} file(s) written/updated; {len(rows)} messages')
if unknown:
    print('NOT SERIALIZED (check):', *unknown, sep='\n  ')
    sys.exit(1)
