#!/usr/bin/env python3
"""Customer extensions of the operations framework ZCA_OPS: the inventory of the product's extension points and the
generator of a customer's CDS extensions (offline engine; docs/EXTENDING_WITH_CUSTOMER_DATA.md of the framework).

First principle: the product reads SAP standard data; a customer adds its own data on top only through declared
extension points, never by changing a product object.

1. Inventory (ops-framework/config/extension_points.json): every extension point of the product - module, standard
   data source, mechanism (config row, link registry, generated from a spec, plug-in class, CDS extension), product
   object, example. A CDS extension point names its views (the base view the customer extends, the views the new
   elements are passed on to: projection, cube, analytical query) and its anchors - the stable elements a customer's
   data may be joined on:
     link  the row of the view is a row of a standard object of the link registry (element map field -> element);
           the customer names a registry link leaving that object
     key   the customer names an object of its own registry layer and maps every key field of it to an element
           (optionally with the value of a discriminator element, e.g. the object type of a finding)
   check_inventory: files and documents exist, every view of a point carries exactly the extensibility annotations of
   the inventory and its anchor elements, no other product view is extensible, the document's matrix is current.

2. Pack (config/extensions of a customer folder): pack.json {prefix, layer, links [registry layer specs], since,
   package_folder, pending_folder, package_text, report} and one or more files {"extensions": [...]}; an extension
   {id, point, anchor, link | object + keys (+ discriminator), association, also [optional views], fields [{field,
   element, label, sensitivity}], status active | pending | blocked, reason, verify, description}.
   Rules (analyse): the point is a CDS extension point of the inventory and the anchor one of its anchors; IDs, element
   and association names carry the customer's prefix (ID <P>_, element ZZ<P>_ / YY<P>_, association _ZZ<P>); a link
   leaves the anchor's object, is "to one" (11 / N1 - a "to many" link would repeat the product's rows) and reads
   only fields the anchor provides; a key object is the customer's own and every key field is mapped; every field is a
   registry field of the target; a hidden field (H) is never added, a masked one (M) is rendered masked and cannot be
   declared weaker; the quota of the view is kept. Status: active only when the registry link is active, no field is
   VERIFY or a placeholder and the declaration names no open VERIFY item - otherwise pending (generated into the
   pending folder for review, never imported); blocked = declared with its reason (point and anchor checked),
   listed in the report, not generated.

3. Outputs: extend view entity sources per view (all extensions of a point in one object Z<P>_X_<code>), copies of an
   analytical query with the new elements (ZC_<P>_..., the fallback while extending a query is VERIFY), the package,
   a report; for the framework the matrix block of the document and the rendered worked example. --check fails on a
   problem or an out-of-date / superfluous file.

Modification log:
2026-11-15 | Initial version (build H: one customer extension contract, extensible product views, generator).
"""
import importlib.util
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
FRAMEWORK = os.path.join(REPO, 'ops-framework')
INVENTORY = os.path.join(FRAMEWORK, 'config', 'extension_points.json')

MECHANISMS = {'config': 'configuration row', 'registry': 'link registry (customer layer)',
              'generated': 'generated from a customer spec', 'plugin': 'plug-in class',
              'extension': 'CDS extension (generated)'}
VIEW_KINDS = ('select', 'projection', 'query')
ANCHOR_KINDS = ('link', 'key')
STATES = ('active', 'pending', 'blocked')
UI_KINDS = ('lineItem', 'identification')
UI_POSITION = 900

PREFIX = re.compile(r'^[A-Z][A-Z0-9]{1,3}$')
CODE = re.compile(r'^[A-Z][A-Z0-9_]{1,15}$')
PLACEHOLDER = re.compile('‹[^›]*›')
UNSAFE = re.compile(r"['`;{}]|//|/\*|\*/")
VALUE = re.compile(r'^[A-Za-z0-9_./-]{1,30}$')
TEXT_MAX = 60
BEGIN = '<!-- generated: extension points (tools/extensions.py; never edit this block) -->'
END = '<!-- end of generated block -->'
GENERATED_EXT = ('.asddls',)


class ExtensionError(ValueError):
    """The inventory or a pack is invalid (message names the point or extension)."""


def _link_engine():
    """The shared link registry engine (loaded by path: this module is also loaded outside its package)."""
    spec = importlib.util.spec_from_file_location('abaptools_link_registry_ext',
                                                  os.path.join(HERE, 'link_registry.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


LR = _link_engine()


def _read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def _json(path):
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def _text_ok(value, required=True):
    if value in (None, ''):
        return not required
    return len(str(value)) <= TEXT_MAX and not UNSAFE.search(str(value))


# ------------------------------------------------------------------------------------------------ inventory
def load_inventory(path=INVENTORY):
    return _json(path)


def cds_points(inv):
    return [p for p in inv['points'] if p.get('mechanism') == 'extension']


def point(inv, point_id):
    return next((p for p in cds_points(inv) if p['id'] == point_id), None)


def view_of(pt, code):
    return next((v for v in pt['views'] if v['code'] == code), None)


def annotation_lines(inv, view):
    """The extensibility annotations a view of an extension point carries (exactly these lines)."""
    ann = inv['annotation']
    base = view.get('role') == 'base'
    lines = [f"@AbapCatalog.extensibility.extensible: {'true' if ann['extensible'] else 'false'}",
             f"@AbapCatalog.extensibility.elementSuffix: '{ann['element_suffix']}'",
             f"@AbapCatalog.extensibility.allowNewDatasources: {'true' if base and ann['allow_new_datasources'] else 'false'}"]
    if view.get('alias'):
        lines.append(f"@AbapCatalog.extensibility.dataSources: [ '{view['alias']}' ]")
    lines += [f"@AbapCatalog.extensibility.quota.maximumFields: {ann['max_fields']}",
              f"@AbapCatalog.extensibility.quota.maximumBytes: {ann['max_bytes']}"]
    return lines


def _strip_comments(text):
    return '\n'.join(re.sub(r'//.*$', '', line) for line in text.splitlines())


DEFINE = re.compile(r'define\s+(?:root\s+|transient\s+)?view\s+entity\s+(\w+)', re.I)


def element_block(text):
    """The element list of a view source (between the brace after the define statement and the last brace)."""
    code = _strip_comments(text)
    m = DEFINE.search(code)
    if not m:
        return ''
    start = code.find('{', m.end())
    end = code.rfind('}')
    return code[start + 1:end] if start >= 0 and end > start else ''


def has_element(text, element):
    return re.search(r'(?<![\w$])' + re.escape(element) + r'\b', element_block(text)) is not None


def check_inventory(root, inv, reg=None):
    """Problems of the inventory against the component folder (empty = consistent)."""
    p = []
    reg = reg or LR.load(LR.PRODUCT_LAYERS)
    ids, codes, listed = set(), set(), set()
    ann = inv.get('annotation', {})
    if not re.match(r'^[A-Z][A-Z0-9]{2}$', str(ann.get('element_suffix', ''))):
        p.append('annotation: element_suffix must be three upper-case letters / digits')
    for key in ('max_fields', 'max_bytes'):
        if not isinstance(ann.get(key), int) or ann.get(key) <= 0:
            p.append(f'annotation: {key} must be a positive number')
    for pt in inv.get('points', []):
        pid = pt.get('id', '')
        if not CODE.match(pid) or pid in ids:
            p.append(f'point {pid}: id missing, invalid or used twice')
        ids.add(pid)
        if pt.get('mechanism') not in MECHANISMS:
            p.append(f'point {pid}: mechanism {pt.get("mechanism")!r} is not one of {sorted(MECHANISMS)}')
        for key in ('module', 'standard', 'object', 'doc', 'description', 'example'):
            if not pt.get(key):
                p.append(f'point {pid}: {key} missing')
        doc = _read(os.path.join(root, pt.get('doc', '')))
        if doc is None:
            p.append(f'point {pid}: document {pt.get("doc")} missing')
        elif pt.get('object') and pt['object'] not in doc:
            p.append(f'point {pid}: document {pt["doc"]} does not mention {pt["object"]}')
        for rel in pt.get('evidence', []):
            if not os.path.exists(os.path.join(root, rel)):
                p.append(f'point {pid}: evidence {rel} missing')
        if pt.get('mechanism') == 'extension':
            p += _check_cds_point(root, inv, pt, reg, codes, listed)
    # no product view is extensible unless the inventory lists it (docs and code cannot drift)
    for folder, _, names in os.walk(os.path.join(root, 'src')):
        for name in sorted(names):
            if name.endswith('.ddls.asddls'):
                rel = os.path.relpath(os.path.join(folder, name), root)
                if '@AbapCatalog.extensibility' in (_read(os.path.join(folder, name)) or '') and rel not in listed:
                    p.append(f'{rel}: extensible but not a view of config/extension_points.json')
    return p


def _check_cds_point(root, inv, pt, reg, codes, listed):
    p = []
    pid = pt['id']
    views = pt.get('views', [])
    if not views or views[0].get('role') != 'base' or any(v.get('role') == 'base' for v in views[1:]):
        p.append(f'point {pid}: the first view (and only the first) is the base view')
        return p
    seen = []
    for view in views:
        code = view.get('code', '')
        if not CODE.match(code) or code in codes:
            p.append(f'point {pid}: view code {code!r} invalid or used twice')
        codes.add(code)
        if view.get('kind') not in VIEW_KINDS:
            p.append(f'point {pid} / {code}: kind {view.get("kind")!r} is not one of {VIEW_KINDS}')
        if view.get('kind') == 'query' and (view.get('role') == 'base' or '{P}' not in view.get('copy_name', '')):
            p.append(f'point {pid} / {code}: a query is copied (copy_name with {{P}}), never the base')
        if view.get('role') != 'base' and view.get('source') not in seen:
            p.append(f'point {pid} / {code}: source {view.get("source")!r} is not an earlier view of the point')
        if view.get('kind') == 'select' and not view.get('alias'):
            p.append(f'point {pid} / {code}: a select view names the alias of its data source')
        if any(u not in UI_KINDS for u in view.get('ui', [])):
            p.append(f'point {pid} / {code}: ui must be of {UI_KINDS}')
        seen.append(code)
        text = _read(os.path.join(root, view.get('file', '')))
        if text is None:
            p.append(f'point {pid} / {code}: file {view.get("file")} missing')
            continue
        m = DEFINE.search(_strip_comments(text))
        if not m or m.group(1) != view.get('view'):
            p.append(f'point {pid} / {code}: {view.get("file")} does not define {view.get("view")}')
        if view.get('kind') == 'query':
            if '@AbapCatalog.extensibility' in text:
                p.append(f'point {pid} / {code}: a copied query carries no extensibility annotation')
            continue
        listed.add(os.path.normpath(view['file']))
        for line in annotation_lines(inv, view):
            if not re.search(r'^' + re.escape(line) + r'\s*$', text, re.M):
                p.append(f'point {pid} / {code}: {view["file"]} lacks the annotation "{line}"')
        found = re.findall(r'^@AbapCatalog\.extensibility[^\n]*', text, re.M)
        if len(found) != len(annotation_lines(inv, view)):
            p.append(f'point {pid} / {code}: {view["file"]} has other extensibility annotations than the inventory')
    base_text = _read(os.path.join(root, views[0].get('file', ''))) or ''
    anchor_ids = set()
    for anchor in pt.get('anchors', []):
        aid = anchor.get('id', '')
        if not CODE.match(aid) or aid in anchor_ids:
            p.append(f'point {pid}: anchor id {aid!r} invalid or used twice')
        anchor_ids.add(aid)
        if anchor.get('kind') not in ANCHOR_KINDS:
            p.append(f'point {pid} / {aid}: kind {anchor.get("kind")!r} is not one of {ANCHOR_KINDS}')
            continue
        elements = list(anchor_elements(anchor))
        if anchor.get('discriminator'):
            elements.append(anchor['discriminator'])
        for element in elements:
            if not has_element(base_text, element):
                p.append(f'point {pid} / {aid}: {views[0]["view"]} has no element {element}')
        if anchor['kind'] == 'link':
            obj = reg.objects.get(anchor.get('object'))
            if obj is None or reg.layers.get(obj['layer'], {}).get('kind') == 'C':
                p.append(f'point {pid} / {aid}: {anchor.get("object")} is not an object of the product layers')
                continue
            for field in anchor.get('elements', {}):
                if reg.field(obj['id'], field) is None:
                    p.append(f'point {pid} / {aid}: {field} is not a registry field of {obj["id"]}')
    if not anchor_ids:
        p.append(f'point {pid}: no anchor')
    return p


def anchor_elements(anchor):
    els = anchor.get('elements', [])
    return list(els.values()) if isinstance(els, dict) else list(els)


# ------------------------------------------------------------------------------------------------ document matrix
def matrix(inv):
    """Markdown of the generated block of docs/EXTENDING_WITH_CUSTOMER_DATA.md."""
    out = [BEGIN, '', f'Inventory `config/extension_points.json` (release {inv.get("release", "")}): '
           f'{len(inv["points"])} extension points, {len(cds_points(inv))} of them CDS extension points.', '',
           '| Module | Standard data source | Extension point | Mechanism | Product object | Example |',
           '|---|---|---|---|---|---|']
    for pt in sorted(inv['points'], key=lambda x: (x['module'], x['mechanism'] != 'extension', x['id'])):
        out.append(f"| {pt['module']} | {pt['standard']} | `{pt['id']}` - {pt['description']} | "
                   f"{MECHANISMS[pt['mechanism']]} | `{pt['object']}` | {pt['example']} |")
    out += ['', '**CDS extension points** (the customer extends the base view; the generator passes the new elements on '
            'to the other views; an optional view only when the extension asks for it):', '',
            '| Point | Views (the base view first) | Anchors | VERIFY |', '|---|---|---|---|']
    for pt in cds_points(inv):
        views = []
        for v in pt['views']:
            text = f"`{v['view']}` ({v['kind']}"
            text += ', copied as `' + v['copy_name'] + '`' if v['kind'] == 'query' else ''
            text += f", reads `{view_of(pt, v['source'])['view']}`" if v.get('source') else ''
            text += ', optional)' if v.get('optional') else ')'
            views.append(text)
        anchors = []
        for a in pt['anchors']:
            if a['kind'] == 'link':
                pairs = ', '.join(f'{f} = {e}' for f, e in a['elements'].items())
                anchors.append(f"`{a['id']}` link from `{a['object']}` ({pairs})")
            else:
                text = f"`{a['id']}` key ({', '.join(a['elements'])})"
                anchors.append(text + (f", discriminator {a['discriminator']}" if a.get('discriminator') else ''))
        out.append(f"| `{pt['id']}` | {'; '.join(views)} | {'; '.join(anchors)} | {', '.join(pt.get('verify', []))} |")
    ann = inv['annotation']
    out += ['', f"Annotations of every extensible view: `extensible: true`, `elementSuffix: '{ann['element_suffix']}'`, "
            f"`allowNewDatasources` true on the base view (false on a view the elements are passed on to), "
            f"`dataSources` the alias of a select view's main source, `quota.maximumFields: {ann['max_fields']}`, "
            f"`quota.maximumBytes: {ann['max_bytes']}` ({ann['verify']}).", '', END]
    return '\n'.join(out)


def with_matrix(doc, inv):
    """The document with its generated block replaced (the markers must exist once)."""
    if doc.count(BEGIN) != 1 or doc.count(END) != 1 or doc.index(BEGIN) > doc.index(END):
        raise ExtensionError('document: the generated block markers are missing or doubled')
    return doc[:doc.index(BEGIN)] + matrix(inv) + doc[doc.index(END) + len(END):]


# ------------------------------------------------------------------------------------------------ packs
def load_pack(folder):
    """(pack settings, [extension]) of a customer's extension folder."""
    pack = _json(os.path.join(folder, 'pack.json'))
    exts = []
    for name in sorted(os.listdir(folder)):
        if name.endswith('.json') and name != 'pack.json':
            for ext in _json(os.path.join(folder, name)).get('extensions', []):
                exts.append(dict(ext, file=name))
    return pack, exts


def pack_registry(root, pack):
    reg = LR.load(LR.PRODUCT_LAYERS + [os.path.join(root, p) for p in pack.get('links', [])])
    return reg, LR.validate(reg)


def _verify_list(value):
    if not value:
        return []
    return [value] if isinstance(value, str) else list(value)


def analyse(pack, exts, inv, reg):
    """(problems, results): one result per extension {ext, status, reasons, ...} with what the renderer needs."""
    problems = []
    prefix = pack.get('prefix', '')
    if not PREFIX.match(prefix):
        problems.append('pack: prefix must be 2-4 upper-case letters / digits')
    layer = reg.layers.get(pack.get('layer'))
    if layer is None or layer.get('kind') != 'C':
        problems.append(f'pack: layer {pack.get("layer")!r} is not a customer layer of the registry')
    elif layer.get('prefix') != prefix + '_':
        problems.append(f'pack: the layer prefix {layer.get("prefix")} is not {prefix}_')
    for key in ('since', 'package_folder', 'pending_folder', 'report', 'package_text'):
        if not pack.get(key):
            problems.append(f'pack: {key} missing')
    results, ids, elements, assocs = [], set(), {}, {}
    for ext in exts:
        res, own = _analyse_one(pack, ext, inv, reg, prefix)
        problems += own
        eid = ext.get('id', '')
        if eid in ids:
            problems.append(f'{eid}: defined twice')
        ids.add(eid)
        if res is None:
            continue
        results.append(res)
        if res['status'] == 'blocked':
            continue
        for element in res['elements']:
            key = (res['point']['id'], element['name'].upper())
            if key in elements:
                problems.append(f'{eid}: element {element["name"]} also added by {elements[key]}')
            elements[key] = eid
        akey = (res['point']['id'], res['association'].upper())
        if akey in assocs:
            problems.append(f'{eid}: association {res["association"]} also used by {assocs[akey]}')
        assocs[akey] = eid
    # quota of every base view (active and pending together: what the view will carry)
    for pt in cds_points(inv):
        count = sum(len(r['elements']) for r in results if r['point'] is pt and r['status'] != 'blocked')
        if count > inv['annotation']['max_fields']:
            problems.append(f'point {pt["id"]}: {count} elements exceed the quota of {inv["annotation"]["max_fields"]}')
    return problems, results


def _analyse_one(pack, ext, inv, reg, prefix):
    p = []
    eid = ext.get('id', '')
    if not re.match(r'^' + re.escape(prefix) + r'_[A-Z0-9_]+$', eid) or len(eid) > 30:
        return None, [f'{eid or ext.get("file")}: id must start with {prefix}_ (upper case, at most 30 characters)']
    status = ext.get('status', 'active')
    if status not in STATES:
        p.append(f'{eid}: status {status!r} is not one of {STATES}')
    pt = point(inv, ext.get('point'))
    if pt is None:
        return None, p + [f'{eid}: {ext.get("point")!r} is not a CDS extension point of the inventory']
    anchor = next((a for a in pt['anchors'] if a['id'] == ext.get('anchor')), None)
    if anchor is None:
        return None, p + [f'{eid}: anchor {ext.get("anchor")!r} is not an anchor of {pt["id"]}']
    if not _text_ok(ext.get('description')):
        p.append(f'{eid}: description missing, longer than {TEXT_MAX} or with quotes / statement characters')
    res = {'ext': ext, 'id': eid, 'point': pt, 'anchor': anchor, 'status': status, 'reasons': [],
           'association': ext.get('association', ''), 'elements': [], 'on': [], 'target': '', 'joins': '',
           'views': [], 'verify': sorted(set(pt.get('verify', [])) | set(_verify_list(ext.get('verify'))))}
    if status in ('pending', 'blocked'):
        if not _text_ok(ext.get('reason')):
            p.append(f'{eid}: a {status} extension names its reason (at most {TEXT_MAX} characters)')
        res['reasons'].append(ext.get('reason', ''))
    if status == 'blocked':
        res['joins'] = ext.get('link') or ext.get('object') or ''
        return res, p
    assoc = res['association']
    if not re.match(r'^_(ZZ|YY)' + re.escape(prefix) + r'[A-Za-z0-9_]{1,24}$', assoc) or len(assoc) > 30:
        p.append(f'{eid}: association must be _ZZ{prefix}... (at most 30 characters)')
    # optional views of the point the extension asks for, with the views they read from
    also = ext.get('also', [])
    for code in also:
        view = view_of(pt, code)
        if view is None or not view.get('optional'):
            p.append(f'{eid}: {code} is not an optional view of {pt["id"]}')
    for view in pt['views']:
        if not view.get('optional') or view['code'] in also:
            res['views'].append(view['code'])
    for code in res['views']:
        source = view_of(pt, code).get('source')
        if source and source not in res['views']:
            p.append(f'{eid}: {code} needs {source} (add it to also)')
    target = _analyse_link(res, ext, anchor, reg, p) if anchor['kind'] == 'link' else \
        _analyse_key(res, ext, anchor, reg, pack, p)
    if target is None:
        return res, p
    _analyse_fields(res, ext, inv, reg, target, prefix, p)
    for ref in _verify_list(ext.get('verify')):
        res['reasons'].append(f'VERIFY {ref} of the declaration open')
    if res['reasons'] and res['status'] == 'active':
        res['status'] = 'pending'
    return res, p


def _analyse_link(res, ext, anchor, reg, p):
    eid = res['id']
    link_id = ext.get('link', '')
    if ext.get('object') or ext.get('keys'):
        p.append(f'{eid}: a link anchor names a link, not an object')
    link = reg.resolve(link_id) if link_id in reg.links else None
    if link is None:
        p.append(f'{eid}: link {link_id!r} is not in the registry')
        return None
    if link['from'] != anchor['object']:
        p.append(f'{eid}: link {link["id"]} leaves {link["from"]}, the anchor {anchor["id"]} is {anchor["object"]}')
        return None
    if link['cardinality'] not in LR.TO_ONE:
        p.append(f'{eid}: link {link["id"]} is {link["cardinality"]} - only a "to one" link (11, N1) adds a column '
                 'without repeating the product\'s rows')
        return None
    res['joins'] = link['id'] + (f' (replaces {link_id})' if link['id'] != link_id else '')
    status = reg.status(link)
    if status != 'active':
        res['reasons'].append(f'link {link["id"]} {status}')
    mapping = {f.upper(): e for f, e in anchor['elements'].items()}
    dst = reg.objects[link['to']]
    alias = res['association']
    for cond in link['conditions']:
        left = f'{alias}.{_cds_field(reg, dst, cond["to"])}'
        kind = cond['kind']
        if kind == 'EQ':
            element = mapping.get(LR._upper(cond['from']))
            if element is None:
                p.append(f'{eid}: link {link["id"]} reads {cond["from"]}, which anchor {anchor["id"]} does not provide')
                continue
            res['on'].append(f'{left} = {LR._cds_operand("$projection." + element, cond)}')
        elif kind == 'CONST':
            values = [v.strip() for v in str(cond['value']).split(',')]
            res['on'].append(f"{left} = '{values[0]}'" if len(values) == 1 else
                             '( ' + ' or '.join(f"{left} = '{v}'" for v in values) + ' )')
        elif kind == 'NOTINIT':
            res['on'].append(f"{left} <> ' '")
        elif kind == 'PREFER':
            # an association adds one column: the preferred row only (blank when there is none)
            res['on'].append(f"{left} = '{cond['value']}'")
    res['target'] = _cds_source(dst)
    if PLACEHOLDER.search(res['target']):
        res['reasons'].append(f'source of {dst["id"]} not named yet')
    return dst


def _analyse_key(res, ext, anchor, reg, pack, p):
    eid = res['id']
    if ext.get('link'):
        p.append(f'{eid}: a key anchor names an object of the customer layer, not a link')
    obj = reg.objects.get(ext.get('object'))
    if obj is None:
        p.append(f'{eid}: object {ext.get("object")!r} is not in the registry')
        return None
    if obj['layer'] != pack.get('layer'):
        p.append(f'{eid}: object {obj["id"]} is not of the customer layer {pack.get("layer")} (a key anchor joins '
                 'only on a key the customer owns)')
        return None
    keys = {LR._upper(k): e for k, e in (ext.get('keys') or {}).items()}
    allowed = anchor_elements(anchor)
    for key in obj['keys']:
        if LR._upper(key) not in keys:
            p.append(f'{eid}: key field {key} of {obj["id"]} is not mapped (all keys: one row per product row)')
    for key, element in keys.items():
        if key not in [LR._upper(k) for k in obj['keys']]:
            p.append(f'{eid}: {key} is not a key field of {obj["id"]}')
        if element not in allowed:
            p.append(f'{eid}: {element} is not an element of anchor {anchor["id"]} ({", ".join(allowed)})')
    alias = res['association']
    for key in obj['keys']:
        element = keys.get(LR._upper(key))
        if element:
            res['on'].append(f'{alias}.{_cds_field(reg, obj, key)} = $projection.{element}')
        if PLACEHOLDER.search(key):
            res['reasons'].append(f'key field {key} of {obj["id"]} not named yet')
    if anchor.get('discriminator'):
        value = ext.get('discriminator', '')
        if not VALUE.match(str(value)):
            p.append(f'{eid}: anchor {anchor["id"]} needs the value of {anchor["discriminator"]} (discriminator)')
        else:
            res['on'].append(f"$projection.{anchor['discriminator']} = '{value}'")
    elif ext.get('discriminator'):
        p.append(f'{eid}: anchor {anchor["id"]} has no discriminator')
    res['joins'] = f'{obj["id"]} by key'
    res['target'] = _cds_source(obj)
    if PLACEHOLDER.search(res['target']):
        res['reasons'].append(f'source of {obj["id"]} not named yet')
    if not obj.get('active', True):
        res['reasons'].append(f'object {obj["id"]} inactive')
    return obj


def _analyse_fields(res, ext, inv, reg, target, prefix, p):
    eid = res['id']
    suffix = inv['annotation']['element_suffix'] if inv['annotation'].get('suffix_in_names') else ''
    fields = ext.get('fields', [])
    if not fields:
        p.append(f'{eid}: no field')
    for fld in fields:
        name = fld.get('field', '')
        reg_fld = reg.field(target['id'], name)
        if reg_fld is None:
            p.append(f'{eid}: {name} is not a registry field of {target["id"]}')
            continue
        element = fld.get('element', '') + suffix
        if not re.match(r'^(ZZ|YY)' + re.escape(prefix) + r'_[A-Za-z0-9_]+$', element) or len(element) > 30:
            p.append(f'{eid}: element {element!r} must be ZZ{prefix}_... (at most 30 characters)')
        if not _text_ok(fld.get('label')):
            p.append(f'{eid}: label of {element} missing, longer than {TEXT_MAX} or with quotes')
        declared, registry = fld.get('sensitivity', ''), reg_fld.get('sensitivity', '')
        if declared not in ('', 'M', 'H'):
            p.append(f'{eid}: sensitivity {declared!r} of {name} is not blank, M or H')
        if 'H' in (declared, registry):
            p.append(f'{eid}: {name} is hidden (H) - a hidden field is never added to a view')
            continue
        if registry == 'M' and declared != 'M':
            p.append(f'{eid}: {name} is masked (M) in the registry - declare it M')
        if reg_fld.get('evidence') == 'V' or PLACEHOLDER.search(name):
            res['reasons'].append(f'field {name} VERIFY {reg_fld.get("verify") or "open"}')
        expr = f'{res["association"]}.{_cds_field(reg, target, name)}'
        masked = 'M' in (declared, registry)
        if masked:
            expr = f"concat( '****', right( {expr}, 4 ) )"
        res['elements'].append({'name': element, 'expr': expr, 'label': fld.get('label', ''), 'field': name,
                                'masked': masked})


def _cds_source(obj):
    return obj['source'] if PLACEHOLDER.search(obj['source']) else LR._cds_source(obj)


def _cds_field(reg, obj, name):
    return name if PLACEHOLDER.search(name) else LR._cds_field(obj, name, reg)


# ------------------------------------------------------------------------------------------------ rendering
def object_name(pack, view):
    if view['kind'] == 'query':
        return view['copy_name'].replace('{P}', pack['prefix'])
    return f'Z{pack["prefix"]}_X_{view["code"]}'


def _header(pack, name, lines, verify):
    out = [f'// Artifact: {name.lower()}.ddls.asddls']
    out += [('// Purpose: ' if i == 0 else '//          ') + text for i, text in enumerate(lines)]
    out += ['//          Generated by tools/extensions.py from config/extensions - never edit: change the declaration',
            '//          and regenerate (docs/EXTENDING_WITH_CUSTOMER_DATA.md of the framework).',
            f'// Modification log: {pack["since"]} | Generated (customer extensions of ZCA_OPS).']
    if verify:
        out.append(f'// VERIFY: {", ".join(verify)} (framework and this pack)')
    return out


def _annotations(element, view, position):
    out = [f"  @EndUserText.label: '{element['label']}'"]
    if 'lineItem' in view.get('ui', []):
        out.append(f'  @UI.lineItem: [ {{ position: {position}, importance: #LOW }} ]')
    if 'identification' in view.get('ui', []):
        out.append(f'  @UI.identification: [ {{ position: {position} }} ]')
    return out


def render_view(pack, pt, view, items):
    """(object name, source) of one view for the given analysed extensions (all of the same point)."""
    name = object_name(pack, view)
    verify = sorted({v for r in items for v in r['verify']} | ({view['verify']} if view.get('verify') else set()))
    elements = [(r, e) for r in items for e in r['elements']]
    ids = ', '.join(r['id'] for r in items)
    if view['kind'] == 'query':
        return name, _render_query(pack, view, name, elements, ids, verify)
    lines = _header(pack, name, [f'Customer extension of {view["view"]} (extension point {pt["id"]} of ZCA_OPS):',
                                 f'{ids}.'], verify)
    lines.append(f'// Extension: {pack["prefix"]} extension of {view["view"]}'[:63])
    lines.append(f'extend view entity {view["view"]} with')
    if view['role'] == 'base':
        for res in items:
            head = f'  association [0..1] to {res["target"]} as {res["association"]} on'
            for i, cond in enumerate(res['on']):
                gap = '  ' if len(res['on']) > 1 else ' '
                lines.append(head + gap + cond if i == 0 else ' ' * (len(head) - 2) + 'and ' + cond)
    lines.append('{')
    body = []
    for index, (res, element) in enumerate(elements):
        position = UI_POSITION + 10 * index
        text = _annotations(element, view, position)
        if view['role'] == 'base':
            text.append(f'  {element["expr"]} as {element["name"]}')
        elif view['kind'] == 'select':
            text.append(f'  {view["alias"]}.{element["name"]}')
        else:
            text.append(f'  {element["name"]}')
        body.append(text)
    for i, text in enumerate(body):
        if i < len(body) - 1:
            text[-1] += ','
        lines += text
    lines.append('}')
    return name, '\n'.join(lines) + '\n'


def _render_query(pack, view, name, elements, ids, verify):
    """A copy of the product's analytical query with the new elements as free dimensions."""
    source = _read(os.path.join(FRAMEWORK, view['file']))
    body = [line for line in source.splitlines() if not line.startswith('//')]
    text = '\n'.join(body)
    text = re.sub(r'(define\s+transient\s+view\s+entity\s+)' + re.escape(view['view']) + r'\b',
                  lambda m: m.group(1) + name, text, count=1)
    text = text.rstrip()
    if not text.endswith('}'):
        raise ExtensionError(f'{view["file"]}: the query does not end with its element list')
    head = text[:-1].rstrip()
    added = []
    for res, element in elements:
        added += [f"  @EndUserText.label: '{element['label']}'", '  @AnalyticsDetails.query.axis: #FREE',
                  f'  {element["name"]},']
    if added:
        head += ','
        added[-1] = added[-1].rstrip(',')
    lines = _header(pack, name, [f'Copy of the product query {view["view"]} with the customer\'s elements as free '
                                 'dimensions (fallback while', f'extending an analytical query is VERIFY): {ids}.',
                                 f'The VERIFY items of the product query apply as well ({view["file"]} of the '
                                 'framework).'], verify)
    return '\n'.join(lines) + '\n' + head + '\n' + '\n'.join(added) + '\n}\n'


def render_pack(pack, results):
    """{relative path: text} of the package and pending folder."""
    files = {}
    points = []
    for res in results:
        if res['status'] != 'blocked' and res['point'] not in points:
            points.append(res['point'])
    any_active = False
    for pt in points:
        mine = sorted((r for r in results if r['point'] is pt and r['status'] != 'blocked'), key=lambda r: r['id'])
        for view in pt['views']:
            active = [r for r in mine if r['status'] == 'active' and view['code'] in r['views']]
            full = [r for r in mine if view['code'] in r['views']]
            if active:
                name, text = render_view(pack, pt, view, active)
                files[os.path.join(pack['package_folder'], name.lower() + '.ddls.asddls')] = text
                any_active = True
            if len(full) > len(active):
                name, text = render_view(pack, pt, view, full)
                files[os.path.join(pack['pending_folder'], name.lower() + '.ddls.asddls')] = text
    if any_active:
        files[os.path.join(pack['package_folder'], 'package.devc.xml')] = PACKAGE.format(text=pack['package_text'])
    return files


PACKAGE = '''<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_DEVC" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <DEVC>
    <CTEXT>{text}</CTEXT>
   </DEVC>
  </asx:values>
 </asx:abap>
</abapGit>
'''


def report(pack, results, files, title, sources=False):
    """Markdown report of a pack: one row per extension; with sources = the generated code inline."""
    counts = {s: sum(1 for r in results if r['status'] == s) for s in STATES}
    out = [f'# {title}', '', 'Generated by `tools/extensions.py` from `config/extensions` - never edit; change the '
           'declaration and regenerate.', '',
           f'Pack prefix `{pack["prefix"]}`, registry layer `{pack["layer"]}`: {len(results)} extension(s) - '
           f'{counts["active"]} active, {counts["pending"]} pending, {counts["blocked"]} blocked.', '',
           '| Extension | Point / anchor | Joins | Elements (field) | Status | Why |', '|---|---|---|---|---|---|']
    for res in sorted(results, key=lambda r: r['id']):
        ext = res['ext']
        if res['status'] == 'blocked':
            elements = ', '.join(f"{f.get('element')} ({f.get('field')})" for f in ext.get('fields', []))
        else:
            elements = ', '.join(f"`{e['name']}` ({e['field']}{', masked' if e['masked'] else ''})"
                                 for e in res['elements'])
        why = '; '.join(x for x in res['reasons'] if x) or '-'
        out.append(f"| `{res['id']}` - {ext.get('description', '')} | {res['point']['id']} / {res['anchor']['id']} | "
                   f"{res['joins']} | {elements} | {res['status']} | {why} |")
    out += ['', '| File | Folder |', '|---|---|']
    for rel in sorted(files):
        if rel.endswith('.asddls'):
            folder = 'package (imported)' if rel.startswith(pack['package_folder']) else 'pending (review only)'
            out.append(f'| `{os.path.basename(rel)}` | {folder} |')
    if sources:
        for rel in sorted(files):
            if rel.endswith('.asddls'):
                out += ['', f'### `{os.path.basename(rel)}` ({"package" if rel.startswith(pack["package_folder"]) else "pending"})',
                        '', '```cds', files[rel].rstrip('\n'), '```']
    return '\n'.join(out) + '\n'


# ------------------------------------------------------------------------------------------------ profiles
def pack_outputs(root, folder, inv):
    """(problems, results, files, pack) of a pack folder (relative to root)."""
    pack, exts = load_pack(os.path.join(root, folder))
    reg, problems = pack_registry(root, pack)
    if problems:
        return [f'{folder}: registry: {x}' for x in problems], [], {}, pack
    more, results = analyse(pack, exts, inv, reg)
    problems = [f'{folder}: {x}' for x in more]
    files = render_pack(pack, results) if not problems else {}
    return problems, results, files, pack


def outputs(root, profile):
    """(problems, {relative path: text}, owned folders) of a component profile.
    Framework: inventory, doc (matrix block), examples [{pack, doc, title}]. Consumer: pack, title."""
    inv = load_inventory()
    problems, files, folders = [], {}, []
    if profile.get('inventory'):
        problems += check_inventory(root, inv)
        doc_path = os.path.join(root, profile['doc'])
        try:
            files[profile['doc']] = with_matrix(_read(doc_path) or '', inv)
        except ExtensionError as error:
            problems.append(f'{profile["doc"]}: {error}')
    for example in profile.get('examples', []):
        more, results, generated, pack = pack_outputs(root, example['pack'], inv)
        problems += more
        if not more:
            files[example['doc']] = report(pack, results, generated, example['title'], sources=True)
    if profile.get('pack'):
        more, results, generated, pack = pack_outputs(root, profile['pack'], inv)
        problems += more
        if not more:
            files.update(generated)
            files[pack['report']] = report(pack, results, generated, profile['title'])
            folders = [pack['package_folder'], pack['pending_folder']]
    return problems, files, folders


def _superfluous(root, folders, files):
    found = set()
    for folder in folders:
        path = os.path.join(root, folder)
        if os.path.isdir(path):
            for name in os.listdir(path):
                if name.endswith(GENERATED_EXT) or name == 'package.devc.xml':
                    found.add(os.path.join(folder, name))
    return sorted(found - set(files))


def check(root, profile):
    problems, files, folders = outputs(root, profile)
    stale = [f'{rel}: out of date (run tools/extensions.py)' for rel, text in sorted(files.items())
             if _read(os.path.join(root, rel)) != text]
    extra = [f'{rel}: superfluous (run tools/extensions.py)' for rel in _superfluous(root, folders, files)]
    return problems + stale + extra


def generate(root, profile):
    problems, files, folders = outputs(root, profile)
    if problems:
        raise ExtensionError('\n'.join(problems))
    written = []
    for rel, text in sorted(files.items()):
        path = os.path.join(root, rel)
        if _read(path) != text:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8') as handle:
                handle.write(text)
            written.append(rel)
    removed = []
    for rel in _superfluous(root, folders, files):
        os.remove(os.path.join(root, rel))
        xml = os.path.join(root, re.sub(r'\.asddls$', '.xml', rel))
        if xml.endswith('.ddls.xml') and os.path.exists(xml):
            os.remove(xml)
        removed.append(rel)
    return written, removed


def main(root, profile, argv):
    if '--check' in argv:
        failures = check(root, profile)
        if failures:
            print('Extensions invalid or out of date:')
            for line in failures:
                print('  ' + line)
            return 1
        print('extension points and customer extensions valid and up to date')
        return 0
    try:
        written, removed = generate(root, profile)
    except ExtensionError as error:
        print(error)
        return 1
    print(f'{len(written)} file(s) written, {len(removed)} removed')
    return 0
