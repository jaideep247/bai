#!/usr/bin/env python3
"""Versioned pack manifest of the product (parameter framework + operations framework): validation against the
repository, blank-slate rules, object inventory, collision and namespace report, import order, generated document.

First principle: a release is a list of what ships, in which order, on what it stands and what it must never carry;
every claim of that list is checked against the serialized sources, so the list cannot drift from the code.
Analogy: a packing list checked at the loading bay - every box on the list is on the pallet, every box on the pallet
is on the list exactly once, the heavy boxes go first, and nothing addressed to the previous customer is on board.

Manifest (JSON, e.g. ops-framework/release/manifest.json; paths relative to the repository root):
  release, date, name             product release and its date
  supported_releases              [{id, product, status target|reference, software_components [{name, release,
                                  verify}], proof, note}]
  components                      [{id, folder, version, version_source {file, constant}, requires [{component,
                                  min_version, min_version_source}]}] - abapGit components; the version is read from
                                  the constant of the source and must equal the manifest
  prerequisites                   software, basis steps, standard_tables_file, fica {pattern, verify}
  licensing                       enforce_parameter {area, name, file, delivered}, modules, statement
  default_pack                    pack of every licence module and plug-in contract no pack names
  packs                           [{id, name, status release|later, required, production, requires [pack],
                                  objects {component, folders [folder under src/, '' = src], names [regex]},
                                  catalogue {package, file, processes}, license_modules, source_contracts,
                                  seed_keys {package, prefix, area, layer}, seed_files, open_items [{id, tokens, text}],
                                  activation [{by, text}], fixtures [{path, kind, text}]}]
  import_order                    the packs in install order (checked against requires)
  seed                            files [{file, table, key, kind package|prefix|area|layer | loader}]
  source_contracts                {file, mechanism}: the plug-in points of the extension inventory
  checks                          {registry, monitoring}: the check rows (class names) of the product
  service_bindings, manual_objects  objects abapGit does not serialize (bindings, SLG0, SMTG, roles)
  blank_slate                     scan, skip_dirs, example_dirs, email_domains, customer_columns, neutral_values,
                                  foreign_object_pattern, append_field_pattern
  namespace                       registered, product_patterns, proposal, limits_file, rename_rules, collision_groups
  distribution                    exclude [path]: not part of the distributable set

Membership is derived from rules: an object belongs to the pack whose name rule matches it, otherwise to the pack
that names its folder; a seed row to the pack whose seed key matches its key column; a licence module or plug-in
contract no pack names belongs to default_pack. A new object, row, module or contract therefore needs no edit of
the manifest unless it belongs elsewhere.

Checks (check(); each returns failures, empty = valid):
  structure        packs, import order, requires, components and their versions (constants of the sources)
  objects          every object of a component's src/ (abapGit file names) in exactly one pack of its component, no
                   duplicate across components, every name a product name (namespace.product_patterns) and Z / Y /
                   a registered namespace, within its length limit (limits_file), no collision inside a group of
                   object types sharing one name space (tables, data elements and CDS entities; classes and
                   interfaces)
  order            import order valid; no object refers to an object of a pack that is not its prerequisite
  licensing        modules known and in at most one pack, module prerequisites reachable, enforcement delivered W
  catalogue        package and qualified processes of a pack exist; the package's licence module is reachable
  contracts        plug-in contracts named by a pack exist and their interface is a product object
  checks           every class of a check row of a pack is a product object whose module the pack reaches
  seed             every seed file exists, targets a product table (or a loader class), every row in exactly one pack
  open_items       no object of the packs a pack stands on contains a blocked token (e.g. a table of an open VERIFY)
  fixtures         every fixture path exists
  blank_slate      no e-mail address outside example domains; customer columns of the delivered CSV files empty,
                   neutral, a placeholder or a product name; no reference to a foreign Z object and no append field
                   (ZZ) in production code or delivered configuration (worked examples of a fictitious customer
                   excepted)
  document         the generated document is up to date

Usage (through a component wrapper, e.g. ops-framework/tools/release_manifest.py):
  --check             validate, exit 1 on a failure
  (no option)         regenerate the document
  --report DIR        write objects.csv, namespace.md and report.md (inventory, packs, prerequisites, order)
  --namespace /NS/    print the namespace report for that namespace (default: namespace.proposal)

Offline evidence only - SAP activation, ABAP Unit, ATC and the collision test in a system are the harness's
(tools/qualify).

Modification log:
2026-11-15 | Initial version (build M: clean install and release baseline).
"""
import csv
import io
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))

SOURCE_SUFFIXES = ('.abap', '.asddls', '.asdcls', '.asddlxs', '.asbdef', '.srvdsrv')
CDS_SUFFIXES = ('.asddls', '.asdcls', '.asddlxs', '.asbdef', '.srvdsrv')
XML_REF = re.compile(r'<(ROLLNAME|DOMNAME|PRECFIELD|CHECKTABLE|REFTABLE|ENTITYTAB|REFCLASS|CLSNAME)>([^<]+)<')
TOKEN = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
EMAIL = re.compile(r'[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})\b')
PLACEHOLDER = re.compile(r'^\s*(‹[^›]*›|<[^>]*>)\s*$')
TEXT_SUFFIXES = ('.py', '.json', '.md', '.yml', '.yaml', '.csv', '.txt', '.abap', '.asddls', '.asdcls', '.asddlxs',
                 '.asbdef', '.srvdsrv', '.xml', '.ddl', '.tpl', '.ps1')


class ManifestError(Exception):
    pass


# ------------------------------------------------------------------------------------------------ reading
def _read(path):
    try:
        with open(path, encoding='utf-8') as handle:
            return handle.read()
    except (OSError, UnicodeDecodeError):
        return None


def _rows(path):
    text = _read(path)
    if text is None:
        return None
    return list(csv.DictReader(io.StringIO(text)))


def load(path):
    text = _read(path)
    if text is None:
        raise ManifestError(f'{path}: not found')
    try:
        return json.loads(text)
    except ValueError as error:
        raise ManifestError(f'{path}: not valid JSON ({error})')


def limits(repo, manifest):
    rows = _rows(os.path.join(repo, manifest['namespace']['limits_file'])) or []
    return {r['TYPE']: r for r in rows}


def version_tuple(text):
    return tuple(int(x) for x in re.findall(r'\d+', text or '0'))


def constant_value(repo, folder, source):
    text = _read(os.path.join(repo, folder, source['file'])) or ''
    m = re.search(r'CONSTANTS\s+' + re.escape(source['constant']) + r"\s+TYPE\s+\S+\s+VALUE\s+[`']([^`']*)[`']",
                  text, re.I)
    return m.group(1) if m else None


def strip_abap_comments(text):
    out = []
    for line in text.splitlines():
        if line.lstrip().startswith('*'):
            continue
        quote = None
        for i, ch in enumerate(line):
            if quote:
                if ch == quote:
                    quote = None
            elif ch in ("'", '`', '|'):
                quote = ch
            elif ch == '"':
                line = line[:i]
                break
        out.append(line)
    return '\n'.join(out)


def strip_cds_comments(text):
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    return '\n'.join(re.sub(r'//.*$', '', line) for line in text.splitlines())


def strip_literals(text):
    return re.sub(r"'[^'\n]*'|`[^`\n]*`|\|[^|\n]*\|", "''", text)


def code_of(path, literals=True):
    """Code of a source file (comments removed; literals kept or blanked) or the reference values of an XML file."""
    text = _read(path) or ''
    if path.endswith('.xml'):
        return ' '.join(m.group(2) for m in XML_REF.finditer(text))
    code = strip_abap_comments(text) if path.endswith('.abap') else strip_cds_comments(text)
    return code if literals else strip_literals(code)


def tokens_of(paths, literals=True):
    found = set()
    for path in paths:
        if path.endswith(SOURCE_SUFFIXES) or path.endswith('.xml'):
            found |= {t.upper() for t in TOKEN.findall(code_of(path, literals))}
    return found


# ------------------------------------------------------------------------------------------------ inventory
def component_packages(repo, component):
    """{folder under src/ ('' = src): package} of a component (config/repository.json)."""
    cfg = json.loads(_read(os.path.join(repo, component['folder'], 'config', 'repository.json')) or '{}')
    return {folder: value[0] for folder, value in cfg.get('packages', {}).items()}


def inventory(repo, manifest):
    """(objects, problems): one dict per abapGit object of every component's src/ - name, type, component, folder,
    package, files (absolute), pack (None until assign())."""
    objects, problems, index = [], [], {}
    for comp in manifest['components']:
        base = os.path.join(repo, comp['folder'], 'src')
        if not os.path.isdir(base):
            problems.append(f'component {comp["id"]}: {comp["folder"]}/src not found')
            continue
        packages = component_packages(repo, comp)
        for d, dirs, names in os.walk(base):
            dirs[:] = sorted(x for x in dirs if not x.startswith('.'))
            folder = os.path.relpath(d, base).replace(os.sep, '/')
            folder = '' if folder == '.' else folder
            for f in sorted(names):
                parts = f.split('.')
                if f == 'package.devc.xml':
                    name, kind = packages.get(folder), 'devc'
                    if not name:
                        problems.append(f'{comp["folder"]}/src/{folder}: package of the folder not in config/repository.json')
                        continue
                elif len(parts) < 3:
                    problems.append(f'{comp["folder"]}/src/{folder}/{f}: not an abapGit file name')
                    continue
                else:
                    name, kind = parts[0].replace('#', '/').upper(), parts[1].lower()
                key = (comp['id'], kind, name)
                if key not in index:
                    index[key] = {'name': name, 'type': kind, 'component': comp['id'], 'folder': folder,
                                  'package': packages.get(folder, ''), 'files': [], 'pack': None}
                    objects.append(index[key])
                elif index[key]['folder'] != folder:
                    problems.append(f'{kind} {name}: in two folders of {comp["id"]}')
                index[key]['files'].append(os.path.join(d, f))
    return objects, problems


def assign(objects, manifest):
    """Pack of every object (name rules before folder rules); failures of objects in no pack or in two."""
    failures = []
    packs = manifest['packs']
    for obj in objects:
        own = [p for p in packs if p.get('objects', {}).get('component') == obj['component']]
        by_name = [p for p in own if any(re.fullmatch(rx, obj['name'], re.I) for rx in p['objects'].get('names', []))]
        hits = by_name or [p for p in own if obj['folder'] in p['objects'].get('folders', [])]
        if len(hits) == 1:
            obj['pack'] = hits[0]['id']
        elif not hits:
            failures.append(f'{obj["type"]} {obj["name"]} ({obj["component"]}, src/{obj["folder"]}): in no pack')
        else:
            failures.append(f'{obj["type"]} {obj["name"]}: in packs {", ".join(p["id"] for p in hits)}')
    return failures


def pack_index(manifest):
    return {p['id']: p for p in manifest['packs']}


def closure(manifest, pack_id):
    """The pack and every pack it stands on (requires, transitively)."""
    packs, seen, todo = pack_index(manifest), [], [pack_id]
    while todo:
        pid = todo.pop()
        if pid in seen or pid not in packs:
            continue
        seen.append(pid)
        todo += packs[pid].get('requires', [])
    return set(seen)


def derived_order(manifest):
    """Packs in a dependency order (requires first; manifest order between independent packs)."""
    packs, order, temp = pack_index(manifest), [], set()

    def visit(pid, path):
        if pid in order:
            return
        if pid in temp:
            raise ManifestError('cycle in pack requires: ' + ' -> '.join(path + [pid]))
        temp.add(pid)
        for req in packs.get(pid, {}).get('requires', []):
            visit(req, path + [pid])
        temp.discard(pid)
        order.append(pid)

    for p in manifest['packs']:
        visit(p['id'], [])
    return order


# ------------------------------------------------------------------------------------------------ licensing
def modules_spec(repo, manifest):
    return json.loads(_read(os.path.join(repo, manifest['licensing']['modules'])) or '{"modules": []}')


def module_packs(repo, manifest):
    """{module code: pack}: the pack that names it, else default_pack."""
    named = {}
    for p in manifest['packs']:
        for code in p.get('license_modules', []):
            named.setdefault(code, []).append(p['id'])
    out = {}
    for m in modules_spec(repo, manifest)['modules']:
        out[m['code']] = named.get(m['code'], [manifest['default_pack']])[0]
    return out, named


def contract_points(repo, manifest):
    spec = manifest.get('source_contracts') or {}
    inv = json.loads(_read(os.path.join(repo, spec.get('file', ''))) or '{"points": []}')
    return {p['id']: p for p in inv.get('points', []) if p.get('mechanism') == spec.get('mechanism', 'plugin')}


def contract_packs(repo, manifest):
    named = {}
    for p in manifest['packs']:
        for cid in p.get('source_contracts', []):
            named.setdefault(cid, []).append(p['id'])
    return {cid: named.get(cid, [manifest['default_pack']])[0] for cid in contract_points(repo, manifest)}, named


# ------------------------------------------------------------------------------------------------ seed
def seed_assignment(repo, manifest):
    """({file: {pack: rows}}, failures): every seed row in exactly one pack."""
    failures, result = [], {}
    whole = {}
    for p in manifest['packs']:
        for f in p.get('seed_files', []):
            whole.setdefault(f, []).append(p['id'])
    listed = {s['file'] for s in manifest['seed']['files']}
    for f in sorted(set(whole) - listed):
        failures.append(f'seed file {f} of pack {whole[f][0]}: not in seed.files')
    for spec in manifest['seed']['files']:
        rows = _rows(os.path.join(repo, spec['file']))
        if rows is None:
            failures.append(f'seed file {spec["file"]}: not found')
            continue
        counts = {}
        owners = whole.get(spec['file'], [])
        if 'key' in spec:
            if owners:
                failures.append(f'seed file {spec["file"]}: keyed by {spec["key"]} and named by pack {owners[0]}')
            for no, row in enumerate(rows, start=2):
                if spec['key'] not in row:
                    failures.append(f'seed file {spec["file"]}: no column {spec["key"]}')
                    break
                value = (row[spec['key']] or '').strip()
                hits = [p['id'] for p in manifest['packs']
                        if _seed_match(spec['kind'], value, p.get('seed_keys', {}).get(spec['kind'], []))]
                if len(hits) != 1:
                    failures.append(f'{spec["file"]}:{no}: {spec["key"]} {value or "(blank)"} in '
                                    f'{"no pack" if not hits else "packs " + ", ".join(hits)}')
                    continue
                counts[hits[0]] = counts.get(hits[0], 0) + 1
        elif len(owners) != 1:
            failures.append(f'seed file {spec["file"]}: without key it needs exactly one pack (seed_files), has {owners}')
        else:
            counts[owners[0]] = len(rows)
        result[spec['file']] = counts
    return result, failures


def _seed_match(kind, value, keys):
    if kind == 'prefix':
        return any(value.startswith(k) for k in keys)
    return value in keys


# ------------------------------------------------------------------------------------------------ checks
def check_structure(repo, manifest):
    failures = []
    ids = [p['id'] for p in manifest['packs']]
    if len(ids) != len(set(ids)):
        failures.append('pack ids not unique')
    packs = pack_index(manifest)
    if manifest.get('default_pack') not in packs:
        failures.append(f'default_pack {manifest.get("default_pack")} is not a pack')
    comps = {c['id']: c for c in manifest['components']}
    for p in manifest['packs']:
        for req in p.get('requires', []):
            if req not in packs:
                failures.append(f'pack {p["id"]}: requires unknown pack {req}')
        comp = p.get('objects', {}).get('component')
        if comp not in comps:
            failures.append(f'pack {p["id"]}: unknown component {comp}')
        if p.get('status') not in ('release', 'later'):
            failures.append(f'pack {p["id"]}: status must be release or later')
    for c in manifest['components']:
        if not os.path.isdir(os.path.join(repo, c['folder'])):
            failures.append(f'component {c["id"]}: folder {c["folder"]} not found')
            continue
        actual = constant_value(repo, c['folder'], c['version_source'])
        if actual != c['version']:
            failures.append(f'component {c["id"]}: version {c["version"]} in the manifest, '
                            f'{actual} in {c["version_source"]["file"]} ({c["version_source"]["constant"]})')
        for req in c.get('requires', []):
            if req['component'] not in comps:
                failures.append(f'component {c["id"]}: requires unknown component {req["component"]}')
                continue
            src = req.get('min_version_source')
            if src and constant_value(repo, c['folder'], src) != req['min_version']:
                failures.append(f'component {c["id"]}: minimum {req["component"]} {req["min_version"]} in the '
                                f'manifest, {constant_value(repo, c["folder"], src)} in {src["file"]}')
            if version_tuple(comps[req['component']]['version']) < version_tuple(req['min_version']):
                failures.append(f'component {c["id"]}: needs {req["component"]} {req["min_version"]}, the release '
                                f'ships {comps[req["component"]]["version"]}')
    for r in manifest.get('supported_releases', []):
        if r.get('status') not in ('target', 'reference'):
            failures.append(f'supported release {r.get("id")}: status must be target or reference')
    if not any(r.get('status') == 'target' for r in manifest.get('supported_releases', [])):
        failures.append('no supported release with status target')
    return failures


def check_order(manifest, objects):
    failures = []
    order = manifest.get('import_order', [])
    if sorted(order) != sorted(p['id'] for p in manifest['packs']):
        failures.append(f'import_order {order} must name every pack once')
        return failures
    try:
        derived_order(manifest)
    except ManifestError as error:
        return [str(error)]
    position = {pid: i for i, pid in enumerate(order)}
    for p in manifest['packs']:
        for req in p.get('requires', []):
            if req in position and position[req] > position[p['id']]:
                failures.append(f'import_order: {p["id"]} before its prerequisite {req}')
    comp_order = {}
    for pid in order:
        comp_order.setdefault(pack_index(manifest)[pid]['objects']['component'], position[pid])
    comps = {c['id']: c for c in manifest['components']}
    for c in manifest['components']:
        for req in c.get('requires', []):
            if req['component'] in comp_order and c['id'] in comp_order \
                    and comp_order[req['component']] > comp_order[c['id']]:
                failures.append(f'import_order: component {c["id"]} before its prerequisite {req["component"]}')
    del comps
    # object references: only to objects of the pack itself or of a pack it stands on
    owner = {}
    for obj in objects:
        if obj['pack']:
            owner.setdefault(obj['name'], set()).add(obj['pack'])
    for obj in objects:
        if not obj['pack']:
            continue
        allowed = closure(manifest, obj['pack'])
        # string literals are runtime names (e.g. the generated licence map lists check class names), not an
        # activation dependency - only code references decide the import order
        for token in sorted(tokens_of(obj['files'], literals=False) - {obj['name']}):
            packs = owner.get(token)
            if packs and not packs & allowed:
                failures.append(f'{obj["type"]} {obj["name"]} ({obj["pack"]}) refers to {token} of pack '
                                f'{", ".join(sorted(packs))}, not a prerequisite')
    return failures


def check_objects(repo, manifest, objects):
    failures = []
    seen = {}
    for obj in objects:
        seen.setdefault((obj['type'], obj['name']), []).append(obj['component'])
    for (kind, name), comps in sorted(seen.items()):
        if len(comps) > 1:
            failures.append(f'{kind} {name}: delivered by {", ".join(comps)}')
    ns = manifest['namespace']
    product = [re.compile(rx, re.I) for rx in ns['product_patterns']]
    registered = [r.upper() for r in ns.get('registered', [])]
    lim = limits(repo, manifest)
    for obj in objects:
        name = obj['name']
        if not (name[:1] in ('Z', 'Y') or any(name.startswith(r) for r in registered)):
            failures.append(f'{obj["type"]} {name}: not in the customer (Z / Y) or a registered namespace')
        if not any(p.search(name) for p in product):
            failures.append(f'{obj["type"]} {name}: not a product name (namespace.product_patterns)')
        row = lim.get(obj['type'])
        if row is None:
            failures.append(f'{obj["type"]} {name}: no length limit for type {obj["type"]} in the limits file')
        elif len(name) > int(row['LIMIT']):
            failures.append(f'{obj["type"]} {name}: {len(name)} characters, limit {row["LIMIT"]}')
    for group in ns.get('collision_groups', []):
        names = {}
        for obj in objects:
            if obj['type'] in group:
                names.setdefault(obj['name'], set()).add(obj['type'])
        for name, kinds in sorted(names.items()):
            if len(kinds) > 1:
                failures.append(f'{name}: one name for {", ".join(sorted(kinds))} (one name space)')
    for m in manifest.get('manual_objects', []):
        if m['type'] not in lim:
            failures.append(f'manual object type {m["type"]}: no length limit in the limits file')
    return failures


def check_licensing(repo, manifest):
    failures = []
    spec = modules_spec(repo, manifest)
    known = {m['code']: m for m in spec['modules']}
    mapping, named = module_packs(repo, manifest)
    for code, packs in named.items():
        if code not in known:
            failures.append(f'licence module {code} of pack {packs[0]}: not in {manifest["licensing"]["modules"]}')
        if len(packs) > 1:
            failures.append(f'licence module {code}: in packs {", ".join(packs)}')
    for code, m in known.items():
        reach = {mapping[c] for c in mapping}
        allowed = closure(manifest, mapping[code])
        for req in m.get('requires', []):
            if req in mapping and mapping[req] not in allowed:
                failures.append(f'licence module {code} (pack {mapping[code]}) requires {req} of pack {mapping[req]}, '
                                'not a prerequisite')
        del reach
    always = [c for c, m in known.items() if m.get('always')]
    for code in always:
        if mapping.get(code) != manifest['default_pack']:
            failures.append(f'licence module {code} is always included: it belongs to {manifest["default_pack"]}')
    enforce = manifest['licensing']['enforce_parameter']
    rows = _rows(os.path.join(repo, enforce['file'])) or []
    row = next((r for r in rows if r.get('AREA') == enforce['area'] and r.get('NAME') == enforce['name']), None)
    if row is None:
        failures.append(f'parameter {enforce["area"]} / {enforce["name"]}: not delivered')
    elif (row.get('DEFAULT_VALUE') or '') != enforce['delivered']:
        failures.append(f'parameter {enforce["name"]}: delivered {row.get("DEFAULT_VALUE")}, the manifest says '
                        f'{enforce["delivered"]} (activation must never depend on a licence)')
    return failures


def check_catalogue(repo, manifest):
    failures = []
    mapping, _ = module_packs(repo, manifest)
    for p in manifest['packs']:
        cat = p.get('catalogue')
        if not cat:
            continue
        spec = json.loads(_read(os.path.join(repo, cat['file'])) or 'null')
        if not spec:
            failures.append(f'pack {p["id"]}: catalogue file {cat["file"]} not found')
            continue
        if spec['package']['id'] != cat['package']:
            failures.append(f'pack {p["id"]}: {cat["file"]} is package {spec["package"]["id"]}, not {cat["package"]}')
        module = spec['package'].get('license_module')
        if module and mapping.get(module) not in closure(manifest, p['id']):
            failures.append(f'pack {p["id"]}: module {module} of package {cat["package"]} is in pack '
                            f'{mapping.get(module)}, not reachable')
        ids = {proc['id'] for proc in spec.get('processes', [])}
        for pid in cat.get('processes', []):
            if pid not in ids:
                failures.append(f'pack {p["id"]}: process {pid} not in package {cat["package"]}')
    return failures


def check_contracts(repo, manifest, objects):
    failures = []
    points = contract_points(repo, manifest)
    _, named = contract_packs(repo, manifest)
    names = {o['name'] for o in objects}
    for cid, packs in named.items():
        if cid not in points:
            failures.append(f'source contract {cid} of pack {packs[0]}: no plug-in point of that id')
            continue
        if len(packs) > 1:
            failures.append(f'source contract {cid}: in packs {", ".join(packs)}')
    for cid, point in points.items():
        if point.get('object', '').upper() not in names:
            failures.append(f'source contract {cid}: interface {point.get("object")} is not a product object')
    return failures


def pack_checks(repo, manifest):
    """{pack: {class name}} of the product's check rows (registry file by its pack, monitoring rows by area)."""
    out = {}
    seeds, _ = seed_assignment(repo, manifest)
    files = {s['file']: s for s in manifest['seed']['files']}
    for key in ('registry', 'monitoring'):
        path = manifest['checks'][key]
        spec = files.get(path)
        for row in _rows(os.path.join(repo, path)) or []:
            if spec and 'key' in spec:
                value = row.get(spec['key'], '')
                pack = next((p['id'] for p in manifest['packs']
                             if _seed_match(spec['kind'], value, p.get('seed_keys', {}).get(spec['kind'], []))), None)
            else:
                pack = next(iter(seeds.get(path, {})), None)
            if pack and row.get('CLASS_NAME'):
                out.setdefault(pack, set()).add(row['CLASS_NAME'].upper())
    return out


def check_checks(repo, manifest, objects):
    failures = []
    names = {o['name'] for o in objects if o['type'] == 'clas'}
    mapping, _ = module_packs(repo, manifest)
    class_module = {}
    for m in modules_spec(repo, manifest)['modules']:
        for cls in m.get('check_classes', []):
            class_module[cls.upper()] = m['code']
    for pack, classes in sorted(pack_checks(repo, manifest).items()):
        for cls in sorted(classes):
            if cls not in names:
                failures.append(f'pack {pack}: check class {cls} is not a product class')
                continue
            module = class_module.get(cls)
            if module is None:
                failures.append(f'pack {pack}: check class {cls} is in no licence module')
            elif mapping.get(module) not in closure(manifest, pack):
                failures.append(f'pack {pack}: check class {cls} needs module {module} of pack {mapping.get(module)}')
    return failures


def check_seed(repo, manifest, objects):
    _, failures = seed_assignment(repo, manifest)
    tables = {o['name'] for o in objects if o['type'] == 'tabl'}
    classes = {o['name'] for o in objects if o['type'] == 'clas'}
    for spec in manifest['seed']['files']:
        if spec['table'].upper() not in tables:
            failures.append(f'seed file {spec["file"]}: table {spec["table"]} is not a product table')
        if spec.get('loader') and spec['loader'].upper() not in classes:
            failures.append(f'seed file {spec["file"]}: loader {spec["loader"]} is not a product class')
    return failures


def check_open_items(manifest, objects):
    failures = []
    for p in manifest['packs']:
        for item in p.get('open_items', []):
            scope = closure(manifest, p['id'])
            for obj in objects:
                if obj['pack'] in scope:
                    hit = tokens_of(obj['files']) & {t.upper() for t in item['tokens']}
                    if hit:
                        failures.append(f'pack {p["id"]}: {obj["type"]} {obj["name"]} uses {", ".join(sorted(hit))} '
                                        f'(open item {item["id"]})')
    return failures


def check_fixtures(repo, manifest):
    return [f'pack {p["id"]}: fixture {f["path"]} not found' for p in manifest['packs']
            for f in p.get('fixtures', []) if not os.path.exists(os.path.join(repo, f['path']))]


def scan_files(repo, manifest):
    """Text files of the blank-slate scan: the scanned folders minus skipped folders and the excluded paths."""
    bs = manifest['blank_slate']
    excluded = {os.path.normpath(os.path.join(repo, p)) for p in manifest['distribution']['exclude']}
    for top in bs['scan']:
        for d, dirs, names in os.walk(os.path.join(repo, top)):
            dirs[:] = sorted(x for x in dirs if x not in bs['skip_dirs'] and not x.startswith('.')
                             and os.path.normpath(os.path.join(d, x)) not in excluded)
            for f in sorted(names):
                path = os.path.join(d, f)
                if f.endswith(TEXT_SUFFIXES) and os.path.normpath(path) not in excluded:
                    yield path


def is_example(path, manifest):
    parts = set(os.path.normpath(path).split(os.sep))
    return bool(parts & set(manifest['blank_slate']['example_dirs']))


def check_blank_slate(repo, manifest, objects):
    bs = manifest['blank_slate']
    failures = []
    product = [re.compile(rx, re.I) for rx in manifest['namespace']['product_patterns']]
    foreign = re.compile(bs['foreign_object_pattern'], re.I)
    append = re.compile(bs['append_field_pattern'], re.I)
    domains = {d.lower() for d in bs['email_domains']}
    columns = set(bs['customer_columns'])
    neutral = set(bs['neutral_values'])
    for path in scan_files(repo, manifest):
        rel = os.path.relpath(path, repo).replace(os.sep, '/')
        text = _read(path)
        if text is None:
            continue
        for no, line in enumerate(text.splitlines(), start=1):
            for m in EMAIL.finditer(line):
                if m.group(1).lower() not in domains:
                    failures.append(f'{rel}:{no}: e-mail address outside the example domains')
        if path.endswith('.csv') and not is_example(path, manifest):
            for no, row in enumerate(csv.DictReader(io.StringIO(text)), start=2):
                for col in sorted(columns & set(row)):
                    value = (row[col] or '').strip()
                    if value in neutral or PLACEHOLDER.match(value) or any(p.search(value) for p in product):
                        continue
                    failures.append(f'{rel}:{no}: {col} = {value} (customer value in delivered configuration)')
                for col, value in row.items():
                    if col and isinstance(value, str) and append.fullmatch(value.strip()):
                        failures.append(f'{rel}:{no}: {col} = {value} (append field in delivered configuration)')
    for obj in objects:
        for path in obj['files']:
            if not path.endswith(SOURCE_SUFFIXES) or '.testclasses.' in os.path.basename(path):
                continue
            rel = os.path.relpath(path, repo).replace(os.sep, '/')
            for token in sorted({t.upper() for t in TOKEN.findall(code_of(path, literals=False))}):
                if foreign.match(token) and not any(p.search(token) for p in product):
                    failures.append(f'{rel}: refers to {token} (not a product object)')
                if append.fullmatch(token):
                    failures.append(f'{rel}: names the append field {token}')
    return failures


def check(repo, manifest_path, doc_path=None):
    """Failures of every check (empty = valid)."""
    try:
        manifest = load(manifest_path)
    except ManifestError as error:
        return [str(error)]
    objects, problems = inventory(repo, manifest)
    failures = list(problems)
    failures += check_structure(repo, manifest)
    failures += assign(objects, manifest)
    failures += check_objects(repo, manifest, objects)
    failures += check_order(manifest, objects)
    failures += check_licensing(repo, manifest)
    failures += check_catalogue(repo, manifest)
    failures += check_contracts(repo, manifest, objects)
    failures += check_checks(repo, manifest, objects)
    failures += check_seed(repo, manifest, objects)
    failures += check_open_items(manifest, objects)
    failures += check_fixtures(repo, manifest)
    failures += check_blank_slate(repo, manifest, objects)
    if doc_path and _read(doc_path) != document(repo, manifest):
        failures.append(f'{os.path.relpath(doc_path, repo)}: out of date (run tools/release_manifest.py)')
    return failures


# ------------------------------------------------------------------------------------------------ namespace
def rename(name, manifest, namespace):
    ns = namespace.strip('/')
    for pattern, target in manifest['namespace']['rename_rules']:
        if re.fullmatch(pattern, name, re.I):
            return re.sub(pattern, target.replace('{ns}', ns), name, flags=re.I).upper()
    return None


def namespace_rows(repo, manifest, objects, namespace):
    """[{type, name, new, length, limit, status}] of every object and named manual object under the namespace."""
    lim = limits(repo, manifest)
    items = [(o['type'], o['name']) for o in objects]
    items += [(m['type'], m['name']) for m in manifest.get('manual_objects', []) if m.get('name')]
    rows, targets = [], {}
    for kind, name in items:
        new = rename(name, manifest, namespace)
        limit = int(lim[kind]['LIMIT']) if kind in lim else None
        status = 'ok'
        if new is None:
            status = 'no rule'
        elif limit is not None and len(new) > limit:
            status = 'too long'
        rows.append({'type': kind, 'name': name, 'new': new or '', 'length': len(new or ''), 'limit': limit,
                     'status': status, 'verify': (lim.get(kind) or {}).get('STATUS') == 'VERIFY'})
        if new:
            targets.setdefault((_group(kind, manifest), new), []).append(name)
    for row in rows:
        clash = targets.get((_group(row['type'], manifest), row['new']), [])
        if row['new'] and len(clash) > 1 and row['status'] == 'ok':
            row['status'] = 'collision'
    return rows


def _group(kind, manifest):
    for group in manifest['namespace'].get('collision_groups', []):
        if kind in group:
            return tuple(group)
    return (kind,)


def namespace_report(repo, manifest, objects, namespace):
    rows = namespace_rows(repo, manifest, objects, namespace)
    ns_limit = int(limits(repo, manifest).get('namespace', {}).get('LIMIT', 10))
    out = [f'# Namespace report: {namespace}', '',
           'Preparation only: the product stays in the customer namespace with the prefix ZCA (decision R1-D1 of '
           '2026-11-15); nothing is renamed. If a namespace is registered later, every product name changes; this '
           f'report applies the rename rules of the manifest and the length limits of '
           f'`{manifest["namespace"]["limits_file"]}`.', '']
    if not (5 <= len(namespace) <= ns_limit and namespace.startswith('/') and namespace.endswith('/')):
        out += [f'**The namespace {namespace} is not 5-{ns_limit} characters between slashes (VERIFY).**', '']
    by_type = {}
    for r in rows:
        by_type.setdefault(r['type'], {'ok': 0, 'too long': 0, 'no rule': 0, 'collision': 0, 'limit': r['limit'],
                                       'verify': r['verify']})
        by_type[r['type']][r['status']] += 1
    out += ['| Type | Limit | Names | Stay valid | Too long | No rule | Collision |', '|---|---|---|---|---|---|---|']
    for kind in sorted(by_type):
        t = by_type[kind]
        total = t['ok'] + t['too long'] + t['no rule'] + t['collision']
        out.append(f'| {kind} | {t["limit"]}{" (VERIFY)" if t["verify"] else ""} | {total} | {t["ok"]} | '
                   f'{t["too long"]} | {t["no rule"]} | {t["collision"]} |')
    bad = [r for r in rows if r['status'] != 'ok']
    out += ['', f'{len(rows)} names, {len(rows) - len(bad)} stay within their limit, {len(bad)} need a decision.', '']
    if bad:
        out += ['| Type | Name | Under the namespace | Length | Limit | Status |', '|---|---|---|---|---|---|']
        out += [f'| {r["type"]} | `{r["name"]}` | `{r["new"]}` | {r["length"]} | {r["limit"]} | {r["status"]} |'
                for r in sorted(bad, key=lambda r: (r['type'], r['name']))]
    return '\n'.join(out) + '\n', rows


# ------------------------------------------------------------------------------------------------ reports
def standard_tables(repo, manifest):
    text = _read(os.path.join(repo, manifest['prerequisites']['standard_tables_file'])) or ''
    return {line.split('#')[0].strip().upper() for line in text.splitlines() if line.split('#')[0].strip()}


def pack_prerequisites(repo, manifest, objects):
    """{pack: {standard table: [objects]}}: SAP standard tables (of the standard tables file) the pack's objects name."""
    std = standard_tables(repo, manifest)
    out = {}
    for obj in objects:
        for table in tokens_of(obj['files']) & std:
            out.setdefault(obj['pack'], {}).setdefault(table, []).append(obj['name'])
    return out


def report(repo, manifest, objects, namespace):
    seeds, _ = seed_assignment(repo, manifest)
    lines = [f'# Release {manifest["release"]}: object and pack report', '',
             'Generated by `tools/release_manifest.py --report` (snapshot of the repository; not committed).', '',
             '## Components', '', '| Component | Version | Objects |', '|---|---|---|']
    for c in manifest['components']:
        lines.append(f'| {c["id"]} | {c["version"]} | {sum(1 for o in objects if o["component"] == c["id"])} |')
    lines += ['', '## Packs (import order)', '', '| Pack | Objects | By type | Seed rows | Check classes |',
              '|---|---|---|---|---|']
    checks = pack_checks(repo, manifest)
    for pid in manifest['import_order']:
        own = [o for o in objects if o['pack'] == pid]
        types = {}
        for o in own:
            types[o['type']] = types.get(o['type'], 0) + 1
        seed = sum(v.get(pid, 0) for v in seeds.values())
        lines.append(f'| {pid} | {len(own)} | {", ".join(f"{k} {v}" for k, v in sorted(types.items())) or "-"} | '
                     f'{seed} | {", ".join(sorted(checks.get(pid, []))) or "-"} |')
    mods, _ = module_packs(repo, manifest)
    cons, _ = contract_packs(repo, manifest)
    lines += ['', '## Licence modules and source contracts by pack', '', '| Pack | Modules | Contracts |', '|---|---|---|']
    for pid in manifest['import_order']:
        lines.append(f'| {pid} | {", ".join(sorted(c for c, p in mods.items() if p == pid)) or "-"} | '
                     f'{", ".join(sorted(c for c, p in cons.items() if p == pid)) or "-"} |')
    pre = pack_prerequisites(repo, manifest, objects)
    fica = re.compile(manifest['prerequisites']['fica']['pattern'])
    lines += ['', '## SAP standard tables named by the objects of a pack (activation prerequisites)', '',
              '| Pack | Table | FI-CA | Objects |', '|---|---|---|---|']
    for pid in manifest['import_order']:
        for table, objs in sorted(pre.get(pid, {}).items()):
            lines.append(f'| {pid} | {table} | {"yes" if fica.match(table) else ""} | {", ".join(sorted(objs)[:6])}'
                         f'{" ..." if len(objs) > 6 else ""} |')
    ns_text, ns_rows = namespace_report(repo, manifest, objects, namespace)
    bad = sum(1 for r in ns_rows if r['status'] != 'ok')
    lines += ['', f'## Namespace {namespace}', '', f'{len(ns_rows)} names, {bad} need a decision (namespace.md).', '']
    return '\n'.join(lines) + '\n', ns_text


def objects_csv(repo, manifest, objects):
    lim = limits(repo, manifest)
    out = io.StringIO()
    writer = csv.writer(out, lineterminator='\n')
    writer.writerow(['COMPONENT', 'PACKAGE', 'PACK', 'TYPE', 'NAME', 'LENGTH', 'LIMIT', 'FILES'])
    for o in sorted(objects, key=lambda o: (manifest['import_order'].index(o['pack']) if o['pack'] in
                                            manifest['import_order'] else 99, o['type'], o['name'])):
        writer.writerow([o['component'], o['package'], o['pack'] or '', o['type'], o['name'], len(o['name']),
                         (lim.get(o['type']) or {}).get('LIMIT', ''),
                         ' '.join(os.path.relpath(f, repo).replace(os.sep, '/') for f in o['files'])])
    return out.getvalue()


# ------------------------------------------------------------------------------------------------ document
def _cell(value):
    return str(value).replace('|', '/').replace('\n', ' ')


def document(repo, manifest):
    m = manifest
    out = [f'# Release manifest {m["release"]} ({m["date"]})', '',
           '> Generated from `release/manifest.json` by `tools/release_manifest.py` - do not edit; change the manifest',
           '> and regenerate. Procedure, harness and evidence: `docs/RELEASE_AND_INSTALL.md`.', '',
           f'**{m["name"]}**', '', '## Supported releases', '',
           '| Id | Product | Status | Software components | Proof |', '|---|---|---|---|---|']
    for r in m['supported_releases']:
        comps = ', '.join(f'{c["name"]} {c["release"]}' + (f' ({c["verify"]})' if c.get('verify') else '')
                          for c in r['software_components'])
        out.append(f'| {r["id"]} | {_cell(r["product"])} | {r["status"]} | {_cell(comps)} | {r["proof"]} |')
    out += ['', '## Components', '', '| Component | Folder | Version | Version constant | Requires |', '|---|---|---|---|---|']
    for c in m['components']:
        req = ', '.join(f'{r["component"]} >= {r["min_version"]}' for r in c.get('requires', [])) or '-'
        out.append(f'| {c["id"]} | `{c["folder"]}` | {c["version"]} | `{c["version_source"]["constant"]}` of '
                   f'`{c["version_source"]["file"]}` | {req} |')
    pre = m['prerequisites']
    out += ['', '## Prerequisites', '']
    out += [f'- **{s["id"]}**: {s["text"]}' for s in pre['software']]
    out += [f'- **{s["id"]}** ({s["pack"]}): {s["text"]}' for s in pre['basis']]
    out += [f'- **SAP standard tables** the product reads: `{pre["standard_tables_file"]}`; FI-CA tables '
            f'(`{pre["fica"]["pattern"]}`): {pre["fica"]["text"]} ({pre["fica"]["verify"]}).',
            f'- **Licensing**: {m["licensing"]["statement"]}', '',
            '## Packs', '', '| Pack | Name | Status | Requires | Objects (rule) | Licence modules | Source contracts |',
            '|---|---|---|---|---|---|---|']
    for p in m['packs']:
        obj = p['objects']
        rule = ', '.join([f'src/{f}' if f else 'src' for f in obj.get('folders', [])] +
                         [f'names `{n}`' for n in obj.get('names', [])]) or 'none (content pack)'
        status = p['status'] + ('' if p.get('production', True) else ', never in production') + \
            (', required' if p.get('required') else '')
        out.append(f'| {p["id"]} | {_cell(p["name"])} | {status} | {", ".join(p.get("requires", [])) or "-"} | '
                   f'{obj["component"]}: {rule} | {", ".join(p.get("license_modules", [])) or "-"} | '
                   f'{", ".join(p.get("source_contracts", [])) or "-"} |')
    out += ['', f'Licence modules and plug-in contracts that no pack names belong to `{m["default_pack"]}`.', '',
            '## Catalogue, seed data, open items and fixtures per pack', '']
    for p in m['packs']:
        out += [f'### {p["id"]} - {p["name"]}', '']
        cat = p.get('catalogue')
        if cat:
            procs = ', '.join(cat.get('processes', [])) or 'every process of the package (none qualified in this release)'
            out.append(f'- Catalogue package `{cat["package"]}` (`{cat["file"]}`); processes qualified in this '
                       f'release: {procs}')
        keys = ', '.join(f'{k} {"/".join(v)}' for k, v in sorted(p.get('seed_keys', {}).items()) if v)
        if keys:
            out.append(f'- Seed rows by key: {keys}')
        if p.get('seed_files'):
            out.append(f'- Seed files: {", ".join(f"`{f}`" for f in p["seed_files"])}')
        for item in p.get('open_items', []):
            out.append(f'- Open item {item["id"]}: {item["text"]} (blocked: {", ".join(item["tokens"])})')
        for f in p.get('fixtures', []):
            out.append(f'- Fixture ({f["kind"]}): `{f["path"]}` - {f["text"]}')
        if p.get('activation'):
            out += ['', '| Step | By | Activation |', '|---|---|---|']
            out += [f'| {i} | {a["by"]} | {_cell(a["text"])} |' for i, a in enumerate(p['activation'], start=1)]
        out.append('')
    out += ['## Import order', '', ' -> '.join(m['import_order']), '',
            'Within a component the install harness follows the object order of `tools/qualify` (tables, interfaces, '
            'exception classes, CDS, access controls, metadata extensions, behaviour, services, classes, programs) '
            'and activates the component in one mass activation.', '',
            '## Seed files', '', '| File | Table | Key | Kind |', '|---|---|---|---|']
    for s in m['seed']['files']:
        out.append(f'| `{s["file"]}` | {s["table"]} | {s.get("key", "whole file")} | '
                   f'{s.get("kind") or ("loader " + s["loader"] if s.get("loader") else "pack")} |')
    bs = m['blank_slate']
    out += ['', '## Blank-slate rules', '',
            f'- Scanned: {", ".join(f"`{s}`" for s in bs["scan"])} minus the distribution exclusions and the folders '
            f'{", ".join(bs["skip_dirs"])}; worked examples (`{"`, `".join(bs["example_dirs"])}`) of a fictitious '
            'customer excepted from the column rule.',
            f'- E-mail addresses only of {", ".join(bs["email_domains"])}.',
            f'- Customer columns of delivered CSV files empty, neutral ({", ".join(repr(v) for v in bs["neutral_values"])}), '
            f'a placeholder or a product name: {", ".join(bs["customer_columns"])}.',
            f'- Production code names no foreign object (`{bs["foreign_object_pattern"]}` outside the product names) '
            f'and no append field (`{bs["append_field_pattern"]}`).',
            '- The first customer\'s deny list (objects, append fields, scheduler names, areas, roles, recipient '
            'lists) is built by the root test `tools/tests/test_blank_slate.py`, never stored in the product.', '',
            '## Namespace', '',
            f'- Product names: {", ".join(f"`{p}`" for p in m["namespace"]["product_patterns"])}; registered '
            f'namespaces: {", ".join(m["namespace"]["registered"]) or "none - decision R1-D1 (2026-11-15): stay in the Z namespace with the prefix ZCA; the namespace report is preparation only"}.',
            f'- Proposal `{m["namespace"]["proposal"]}`, limits `{m["namespace"]["limits_file"]}`, rename rules:', '']
    out += [f'  - `{a}` -> `{b}`' for a, b in m['namespace']['rename_rules']]
    out += ['', '## Objects abapGit does not serialize', '']
    for o in m['manual_objects']:
        out.append(f'- {o["type"]}: {o.get("name") or o.get("pattern") or o.get("rule")} - {o.get("text") or o.get("rule")}')
    out += ['', '## Distribution', '', 'Excluded from the distributable set:', '']
    out += [f'- `{p}`' for p in m['distribution']['exclude']]
    return '\n'.join(out) + '\n'


# ------------------------------------------------------------------------------------------------ main
def load_all(repo, manifest_path):
    """(manifest, objects with their pack, problems) - used by the install harness."""
    manifest = load(manifest_path)
    objects, problems = inventory(repo, manifest)
    problems += assign(objects, manifest)
    return manifest, objects, problems


def main(root, profile, argv):
    repo = os.path.dirname(os.path.abspath(root))
    manifest_path = os.path.join(root, profile['manifest'])
    doc_path = os.path.join(root, profile['doc'])
    if '--check' in argv:
        failures = check(repo, manifest_path, doc_path)
        for failure in failures[:200]:
            print(failure)
        print('release manifest: valid and up to date' if not failures
              else f'release manifest: {len(failures)} problem(s)')
        return 1 if failures else 0
    try:
        manifest, objects, problems = load_all(repo, manifest_path)
    except ManifestError as error:
        print(error)
        return 1
    namespace = argv[argv.index('--namespace') + 1] if '--namespace' in argv else manifest['namespace']['proposal']
    if '--report' in argv:
        folder = argv[argv.index('--report') + 1]
        os.makedirs(folder, exist_ok=True)
        text, ns_text = report(repo, manifest, objects, namespace)
        for name, body in (('report.md', text), ('namespace.md', ns_text),
                           ('objects.csv', objects_csv(repo, manifest, objects))):
            with open(os.path.join(folder, name), 'w', encoding='utf-8', newline='\n') as handle:
                handle.write(body)
        print(f'release manifest: report written to {folder}')
        return 1 if problems else 0
    if '--namespace' in argv:
        print(namespace_report(repo, manifest, objects, namespace)[0])
        return 0
    text = document(repo, manifest)
    if _read(doc_path) != text:
        os.makedirs(os.path.dirname(doc_path), exist_ok=True)
        with open(doc_path, 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(text)
    print('release manifest: document generated')
    return 0
