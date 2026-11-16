#!/usr/bin/env python3
"""Upgrade notes between two revisions of the product: objects added, changed and removed per pack, dictionary
changes of the tables, data elements and domains (with the ones that need a conversion flagged), changed seed files,
component versions and the rollback guidance of each change (docs/RELEASE_AND_INSTALL.md, upgrade and rollback).

First principle: an upgrade is safe when every change is known before the import and every change has a way back;
the dictionary is the one place where the way back can lose data, so it is read field by field.
Analogy: a moving company's inventory between two flats - which boxes are new, which are gone, which furniture
changed size and no longer fits through the door (a table conversion).

Reads the repository with git only (git ls-tree / git show of the two revisions; nothing is checked out, nothing is
written to the repository). The components and packs come from the manifest of the new revision (the old one's when
the new has none, the working tree's for revisions older than the manifest); the manifest file is given relative to
the repository root.

Classification of a table change (VERIFY V206 on the target release):
  adjust      new non-key field, longer CHAR / NUMC field, new table - SE14 adjusts without conversion (expected)
  convert     key changed, field removed, type or decimals changed, field shorter - SE14 conversion; data at risk:
              export the table before the import, plan the conversion window
  drop        table removed - the data is lost with the table: export first or keep the table (decision)
  settings    data class, delivery class or table category changed

Usage: release_diff.py <old revision> <new revision> [--out FILE]   (through a component wrapper)

Modification log:
2026-11-15 | Initial version (build M: upgrade replay and rollback).
"""
import json
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))


class DiffError(Exception):
    pass


def git(repo, *args):
    result = subprocess.run(['git', '-C', repo] + list(args), capture_output=True, text=True, encoding='utf-8')
    if result.returncode != 0:
        raise DiffError(f'git {" ".join(args)}: {result.stderr.strip()}')
    return result.stdout


def show(repo, rev, path):
    try:
        return git(repo, 'show', f'{rev}:{path}')
    except DiffError:
        return None


def listing(repo, rev, folders):
    """{path: blob} of the files under the folders at the revision."""
    out = {}
    text = git(repo, 'ls-tree', '-r', rev, '--', *folders) if folders else ''
    for line in text.splitlines():
        meta, path = line.split('\t', 1)
        out[path] = meta.split()[2]
    return out


def manifest_at(repo, rev, path):
    text = show(repo, rev, path)
    return json.loads(text) if text else None


def objects_at(repo, rev, manifest):
    """{(component, type, name): {'folder', 'files': {path: blob}}} of the components' src/ at the revision."""
    out = {}
    for comp in manifest['components']:
        base = comp['folder'] + '/src/'
        repo_cfg = show(repo, rev, comp['folder'] + '/config/repository.json')
        packages = {k: v[0] for k, v in (json.loads(repo_cfg).get('packages', {}) if repo_cfg else {}).items()}
        for path, blob in listing(repo, rev, [comp['folder'] + '/src']).items():
            rel = path[len(base):]
            folder, _, f = rel.rpartition('/')
            parts = f.split('.')
            if f == 'package.devc.xml':
                name, kind = packages.get(folder, folder.upper() or comp['id']), 'devc'
            elif len(parts) >= 3:
                name, kind = parts[0].replace('#', '/').upper(), parts[1].lower()
            else:
                continue
            entry = out.setdefault((comp['id'], kind, name), {'folder': folder, 'files': {}})
            entry['files'][path] = blob
    return out


def pack_of(key, entry, manifest):
    obj = {'component': key[0], 'type': key[1], 'name': key[2], 'folder': entry['folder'], 'pack': None}
    for p in manifest['packs']:
        rules = p.get('objects', {})
        if rules.get('component') == key[0] and any(re.fullmatch(rx, key[2], re.I) for rx in rules.get('names', [])):
            return p['id']
    hits = [p['id'] for p in manifest['packs'] if p.get('objects', {}).get('component') == key[0]
            and obj['folder'] in p['objects'].get('folders', [])]
    return hits[0] if len(hits) == 1 else '(no pack)'


def _tag(text, tag):
    m = re.search(f'<{tag}>([^<]*)</{tag}>', text or '')
    return m.group(1) if m else ''


def table_fields(xml):
    fields = {}
    for block in re.findall(r'<DD03P>(.*?)</DD03P>', xml or '', re.S):
        name = _tag(block, 'FIELDNAME')
        if name == '.INCLUDE':
            name = '.INCLUDE ' + _tag(block, 'PRECFIELD')
        fields[name] = {'key': _tag(block, 'KEYFLAG') == 'X', 'rollname': _tag(block, 'ROLLNAME'),
                        'datatype': _tag(block, 'DATATYPE'), 'leng': int(_tag(block, 'LENG') or 0),
                        'decimals': int(_tag(block, 'DECIMALS') or 0)}
    return fields


def table_settings(xml):
    return {t: _tag(xml, t) for t in ('TABCLASS', 'CONTFLAG', 'TABART', 'PROTOKOLL')}


def table_changes(old_xml, new_xml):
    """[(class, text)] of the changes of one table between two .tabl.xml."""
    if old_xml is None:
        return [('adjust', 'new table')]
    if new_xml is None:
        return [('drop', 'table removed: its data is lost with it')]
    out = []
    old, new = table_fields(old_xml), table_fields(new_xml)
    for name in [n for n in new if n not in old]:
        out.append(('convert', f'new key field {name}') if new[name]['key'] else ('adjust', f'new field {name}'))
    for name in [n for n in old if n not in new]:
        out.append(('convert', f'field {name} removed (its values are lost)'))
    for name in [n for n in new if n in old]:
        a, b = old[name], new[name]
        if a['key'] != b['key']:
            out.append(('convert', f'field {name}: key {"added" if b["key"] else "removed"}'))
        if a['rollname'] != b['rollname'] or a['datatype'] != b['datatype']:
            out.append(('convert', f'field {name}: type {a["rollname"] or a["datatype"]} -> '
                                   f'{b["rollname"] or b["datatype"]}'))
        elif a['decimals'] != b['decimals'] or b['leng'] < a['leng']:
            out.append(('convert', f'field {name}: length {a["leng"]},{a["decimals"]} -> {b["leng"]},{b["decimals"]}'))
        elif b['leng'] > a['leng']:
            out.append(('adjust', f'field {name}: longer {a["leng"]} -> {b["leng"]}'))
    sa, sb = table_settings(old_xml), table_settings(new_xml)
    for tag in sa:
        if sa[tag] != sb[tag]:
            out.append(('settings', f'{tag} {sa[tag] or "-"} -> {sb[tag] or "-"}'))
    return out


def type_changes(kind, old_xml, new_xml):
    """[(class, text)] of a data element or domain: a shorter or other type converts the tables that use it."""
    if old_xml is None or new_xml is None:
        return []
    out = []
    for tag in ('DOMNAME', 'DATATYPE', 'LENG', 'DECIMALS', 'OUTPUTLEN'):
        a, b = _tag(old_xml, tag), _tag(new_xml, tag)
        if a != b:
            shorter = tag in ('LENG', 'DECIMALS') and a and b and int(b) < int(a)
            longer = tag in ('LENG', 'OUTPUTLEN') and a and b and int(b) > int(a)
            out.append(('adjust' if longer else 'convert', f'{tag} {a or "-"} -> {b or "-"}'
                        + (' (shorter: every table using it converts)' if shorter else '')))
    return out


ROLLBACK = {
    'added': 'delete the object with the rollback transport (or leave it inactive and unused: nothing refers to it '
             'in the previous release)',
    'changed': 'import the previous version (transport of copies made before the upgrade, or abapGit pull of the '
               'previous tag into the same packages) and activate',
    'removed': 'import the previous version of the object; references to it are restored with the previous release',
    'adjust': 'no data loss; the previous version ignores a new table or field (an added field stays empty)',
    'convert': 'export the table before the upgrade; a rollback is a second conversion - restore the export',
    'drop': 'export the table before the upgrade; restore it with the previous release',
    'settings': 're-import the previous technical settings',
}


def diff(repo, old, new, manifest_path):
    m_new = manifest_at(repo, new, manifest_path)
    m_old = manifest_at(repo, old, manifest_path)
    manifest = m_new or m_old
    if manifest is None and os.path.exists(os.path.join(repo, manifest_path)):
        # revisions older than the manifest: their components and packs are read with today's rules
        with open(os.path.join(repo, manifest_path), encoding='utf-8') as handle:
            manifest = json.load(handle)
    if manifest is None:
        raise DiffError(f'{manifest_path}: in neither revision nor in the working tree')
    a, b = objects_at(repo, old, manifest), objects_at(repo, new, manifest)
    changes = []
    for key in sorted(set(a) | set(b)):
        if key not in a:
            state = 'added'
        elif key not in b:
            state = 'removed'
        elif a[key]['files'] != b[key]['files']:
            state = 'changed'
        else:
            continue
        entry = b.get(key) or a[key]
        dictionary = []
        if key[1] in ('tabl', 'dtel', 'doma'):
            path = next((p for p in entry['files'] if p.endswith('.xml')), None)
            old_xml = show(repo, old, path) if key in a else None
            new_xml = show(repo, new, path) if key in b else None
            dictionary = table_changes(old_xml, new_xml) if key[1] == 'tabl' else type_changes(key[1], old_xml, new_xml)
        changes.append({'component': key[0], 'type': key[1], 'name': key[2], 'state': state,
                        'pack': pack_of(key, entry, manifest), 'dictionary': dictionary})
    seed = []
    folders = [c['folder'] + '/config' for c in manifest['components']] + \
        [c['folder'] + '/release/manifest.json' for c in manifest['components']]
    la, lb = listing(repo, old, folders), listing(repo, new, folders)
    for path in sorted(set(la) | set(lb)):
        if la.get(path) != lb.get(path):
            seed.append((path, 'added' if path not in la else 'removed' if path not in lb else 'changed'))
    versions = []
    for comp in manifest['components']:
        va = _version(repo, old, comp)
        vb = _version(repo, new, comp)
        versions.append((comp['id'], va, vb))
    return {'old': old, 'new': new, 'release_old': (m_old or {}).get('release'), 'release_new': (m_new or {}).get('release'),
            'versions': versions, 'changes': changes, 'config': seed, 'order': manifest.get('import_order', [])}


def _version(repo, rev, comp):
    text = show(repo, rev, comp['folder'] + '/' + comp['version_source']['file']) or ''
    m = re.search(r'CONSTANTS\s+' + re.escape(comp['version_source']['constant']) +
                  r"\s+TYPE\s+\S+\s+VALUE\s+[`']([^`']*)[`']", text, re.I)
    return m.group(1) if m else None


def notes(result):
    r = result
    out = [f'# Upgrade notes {r["old"]} -> {r["new"]}', '',
           f'Release {r["release_old"] or "(no manifest)"} -> {r["release_new"] or "(no manifest)"}. '
           'Generated by `tools/release_diff.py` from git (nothing checked out).', '',
           '| Component | Old | New |', '|---|---|---|']
    out += [f'| {c} | {a or "-"} | {b or "-"} |' for c, a, b in r['versions']]
    for c, a, b in r['versions']:
        if a and b and a == b and any(x['component'] == c for x in r['changes']):
            out += ['', f'**{c} changed but its version constant did not: raise the version before the release.**']
    counts = {}
    for c in r['changes']:
        counts[c['state']] = counts.get(c['state'], 0) + 1
    out += ['', f'{len(r["changes"])} objects: ' + (', '.join(f'{v} {k}' for k, v in sorted(counts.items())) or 'none'), '']
    ddic = [(c, cls, text) for c in r['changes'] for cls, text in c['dictionary']]
    critical = [d for d in ddic if d[1] in ('convert', 'drop')]
    out += ['## Dictionary changes', '']
    if not ddic:
        out += ['None.', '']
    else:
        if critical:
            out += [f'**{len(critical)} change(s) need a conversion or drop data: export the tables first and plan the '
                    'window (VERIFY V206).**', '']
        out += ['| Class | Object | Change | Rollback |', '|---|---|---|---|']
        out += [f'| {cls} | {c["type"]} `{c["name"]}` | {text} | {ROLLBACK[cls]} |' for c, cls, text in
                sorted(ddic, key=lambda d: (['drop', 'convert', 'settings', 'adjust'].index(d[1]), d[0]['name']))]
        out.append('')
    out += ['## Objects by pack (import order)', '']
    order = r['order'] + sorted({c['pack'] for c in r['changes']} - set(r['order']))
    for pack in order:
        own = [c for c in r['changes'] if c['pack'] == pack]
        if not own:
            continue
        out += [f'### {pack}', '', '| State | Type | Object |', '|---|---|---|']
        out += [f'| {c["state"]} | {c["type"]} | `{c["name"]}` |' for c in own]
        out.append('')
    out += ['## Configuration and manifest files', '']
    out += [f'- {state}: `{path}`' for path, state in r['config']] or ['None.']
    out += ['', '## Rollback', '']
    out += [f'- **{state}**: {ROLLBACK[state]}' for state in ('added', 'changed', 'removed') if counts.get(state)]
    out += ['- **configuration**: switch back by effective-dated activation (catalogue activation rows, inactive '
            'monitoring rows), never by deleting history; transport the previous rows if a seed row changed.',
            '- **licensing**: `LIC_ENFORCE` back to `W` if a module is refused by mistake (CORE never is).']
    return '\n'.join(out) + '\n'


def main(repo, manifest_path, argv):
    args = [a for a in argv if not a.startswith('--')]
    if len(args) < 2 or '--help' in argv:
        print('usage: release_diff.py <old revision> <new revision> [--out FILE]')
        return 2
    out = argv[argv.index('--out') + 1] if '--out' in argv else None
    if out in args:
        args.remove(out)
    try:
        text = notes(diff(repo, args[0], args[1], manifest_path))
    except DiffError as error:
        print(error)
        return 1
    if out:
        with open(out, 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(text)
        print(f'upgrade notes written to {out}')
    else:
        print(text)
    return 0
