#!/usr/bin/env python3
"""Link registry of the operations framework ZCA_OPS: a declarative, layered model of business objects, their
fields and the links between them (offline engine; the runtime twin is ZCL_CA_OPS_LINK_REGISTRY / _WALKER).

First principle: the framework knows how SAP standard objects link; a customer only adds what is its own (custom
tables, custom fields on standard tables, its own links) on top, and may switch a standard link off or replace it.

Layers (one JSON spec per layer, ranked; a higher rank may extend and reference a lower one, never the reverse):
  S  product baseline   SAP standard objects of the core (released CDS views where available)
  I  industry package   SAP standard objects of an industry solution (e.g. contract accounting)
  C  customer overlay   the customer's own tables / views, custom fields on standard objects, its own links,
                        activation overrides and replacements of standard links

Spec (JSON) of a layer:
  layer       {id, kind S|I|C, rank, prefix, description, owner, active}
  objects     [{id, source, kind T|V, keys [..], description, active, fields [{name, data_element, sensitivity
              ''|M|H, evidence C|V, verify, description}]}]
  fields      [{object, name, ...}]      fields this layer adds to an object of a lower layer (custom fields)
  links       [{id, from, to, cardinality 11|1N|N1|NM, quality C|P, active, fallback_of, replaces, owner, verify,
              description, conditions [{kind EQ|CONST|NOTINIT|PREFER, from, to, value, transform, arg}]}]
  activation  [{kind L|K, id, active, reason, owner}]   switch a layer (L) or a link (K) of a lower layer
Ids of a layer's objects and links start with the layer's prefix. A field or source named with a placeholder in
angle quotes (U+2039 / U+203A) is PENDING: allowed only on inactive links, never seeded (the VERIFY item names it).

Validation (validate): ids, layer ranks and prefixes, every field a declared field of its object, fields present in
the DDIC metadata of the repository where available (DDL of the component tables, CDS sources), conditions
(kinds, transforms, values without quotes or statement characters), an active link uses CONFIRMED fields only,
cardinality consistent with the object keys (a "to one" side covers the keys or prefers one row), fallback chains
without cycles and with the same objects, replacements of a lower layer only, sensitive fields never as a constant
or preferred value and never a hidden key.

Outputs (generate / check): seed rows of the registry tables ZCA_OPS_LNKLYR, _LNKOBJ, _LNKFLD, _LINK, _LNKCND,
_LNKACT (CSV, rows of the component's own layers, maintained in the configuration app ZUI_CA_OPS_CFG), the lineage
diagram (Mermaid) with the custom field flows, the CDS join / association snippets of every link and the impact
report (field -> links, object keys, payment model sections, aggregate checks). --check fails on an invalid
registry or an out-of-date output. The payment model generator renders its joins from the same registry
(render_join).

Modification log:
2026-11-11 | Initial version (link registry: layered objects, fields and links; seed, lineage, snippets, impact).
"""
import csv
import io
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
# The product layers delivered with the framework (every consumer's registry starts with them)
PRODUCT_LAYERS = [os.path.join(REPO, 'ops-framework', 'config', 'links', 's4core.json'),
                  os.path.join(REPO, 'ops-framework', 'config', 'links', 'packages', 'contract_accounting.json')]

LAYER_KINDS = {'S': 'product baseline', 'I': 'industry package', 'C': 'customer overlay'}
SOURCE_KINDS = {'T': 'table', 'V': 'CDS view'}
COND_KINDS = ('EQ', 'CONST', 'NOTINIT', 'PREFER')
TRANSFORMS = ('', 'ALPHA', 'NOZERO', 'UPPER', 'LEFT', 'RIGHT', 'PREFIX', 'SUFFIX')
NUMERIC_ARG = ('ALPHA', 'LEFT', 'RIGHT')
TEXT_ARG = ('PREFIX', 'SUFFIX')
CARDINALITY = {'11': '[0..1]', '1N': '[0..*]', 'N1': '[0..1]', 'NM': '[0..*]'}
TO_ONE = ('11', 'N1')
FROM_ONE = ('11', '1N')
QUALITY = ('C', 'P')
EVIDENCE = ('C', 'V')
SENSITIVITY = ('', 'M', 'H')
ACT_KINDS = ('L', 'K')
JOIN_TYPES = ('inner join', 'left outer join')

ID = re.compile(r'^[A-Z][A-Z0-9_]{1,29}$')
LAYER_ID = re.compile(r'^[A-Z][A-Z0-9_]{1,9}$')
NAME = re.compile(r'^[A-Za-z/][A-Za-z0-9_/]{0,29}$')
ALIAS = re.compile(r'^[A-Za-z][A-Za-z0-9_]{0,29}$')
PLACEHOLDER = re.compile('‹[^›]*›')
# Values become quoted literals (CDS, ABAP SQL through cl_abap_dyn_prg): never a quote or a statement character
UNSAFE = re.compile(r"['`;{}]|//|/\*|\*/")
TEXT_MAX = 60

# Registry tables: (table, CSV columns) - the DDIC fields without MANDT and the administrative fields
TABLES = [
    ('zca_ops_lnklyr', ['LAYER_ID', 'LAYER_KIND', 'LAYER_RANK', 'ID_PREFIX', 'DESCRIPTION', 'OWNER', 'ACTIVE']),
    ('zca_ops_lnkobj', ['OBJECT_ID', 'LAYER_ID', 'SOURCE_NAME', 'SOURCE_KIND', 'KEY_FIELDS', 'DESCRIPTION',
                        'ACTIVE']),
    ('zca_ops_lnkfld', ['OBJECT_ID', 'FIELD_NAME', 'LAYER_ID', 'SOURCE_NAME', 'DATA_ELEMENT', 'SENSITIVITY',
                        'EVIDENCE', 'VERIFY_REF', 'DESCRIPTION']),
    ('zca_ops_link', ['LINK_ID', 'LAYER_ID', 'FROM_OBJECT', 'TO_OBJECT', 'CARDINALITY', 'QUALITY', 'FALLBACK_OF',
                      'REPLACES', 'ACTIVE', 'OWNER', 'VERIFY_REF', 'DESCRIPTION']),
    ('zca_ops_lnkcnd', ['LINK_ID', 'COND_NO', 'COND_KIND', 'FROM_REF', 'TO_REF', 'COND_VALUE', 'TRANSFORM',
                        'TRANSFORM_ARG']),
    ('zca_ops_lnkact', ['TARGET_KIND', 'TARGET_ID', 'LAYER_ID', 'ACTIVE', 'REASON', 'OWNER']),
]


class RegistryError(ValueError):
    """The registry is invalid (message lists every problem)."""


# ------------------------------------------------------------------------------------------------ load
def _flag(value, default=True):
    return default if value is None else bool(value)


def _upper(name):
    return name if PLACEHOLDER.search(name or '') else (name or '').upper()


class Registry:
    """Layers, objects, fields, links and activation overrides of one or more layer specs."""

    def __init__(self):
        self.layers = {}       # id -> layer dict (+ 'file')
        self.objects = {}      # id -> object dict
        self.fields = {}       # (object id, FIELD) -> field dict
        self.links = {}        # id -> link dict
        self.activation = []   # override dicts
        self.problems = []

    # ---- loading
    def add(self, spec, path=''):
        layer = dict(spec.get('layer') or {})
        lid = layer.get('id', '')
        if not lid:
            self.problems.append(f'{path}: layer id missing')
            return
        if lid in self.layers:
            self.problems.append(f'{path}: layer {lid} defined twice')
            return
        layer.setdefault('active', True)
        layer['file'] = path
        self.layers[lid] = layer
        for obj in spec.get('objects', []):
            obj = dict(obj)
            obj['layer'] = lid
            obj.setdefault('active', True)
            if obj.get('id') in self.objects:
                self.problems.append(f'{lid}: object {obj.get("id")} defined twice')
                continue
            for fld in obj.pop('fields', []):
                self._add_field(dict(fld, object=obj.get('id')), lid)
            self.objects[obj.get('id')] = obj
        for fld in spec.get('fields', []):
            self._add_field(dict(fld), lid)
        for link in spec.get('links', []):
            link = dict(link)
            link['layer'] = lid
            link.setdefault('active', True)
            link['conditions'] = [dict(c) for c in link.get('conditions', [])]
            if link.get('id') in self.links:
                self.problems.append(f'{lid}: link {link.get("id")} defined twice')
                continue
            self.links[link.get('id')] = link
        for act in spec.get('activation', []):
            self.activation.append(dict(act, layer=lid))

    def _add_field(self, fld, lid):
        fld['layer'] = lid
        key = (fld.get('object'), _upper(fld.get('name', '')))
        if key in self.fields:
            self.problems.append(f'{lid}: field {key[0]}-{key[1]} defined twice')
            return
        self.fields[key] = fld

    # ---- lookups
    def rank(self, layer_id):
        return int(self.layers.get(layer_id, {}).get('rank', 0))

    def field(self, obj_id, name):
        return self.fields.get((obj_id, _upper(name)))

    def object_fields(self, obj_id):
        return [f for (o, _), f in self.fields.items() if o == obj_id]

    def layer_active(self, layer_id):
        value = _flag(self.layers.get(layer_id, {}).get('active'))
        for act in self.activation:
            if act.get('kind') == 'L' and act.get('id') == layer_id:
                value = _flag(act.get('active'), False)
        return value

    def replaced_by(self, link_id):
        """The link of an active layer that replaces link_id (None when none does)."""
        for link in self.links.values():
            if link.get('replaces') == link_id and self.layer_active(link['layer']):
                return link
        return None

    def resolve(self, link_id):
        """The effective link for a reference: a replacement of an active layer wins (followed to its end)."""
        seen = set()
        link = self.links.get(link_id)
        while link is not None and link['id'] not in seen:
            seen.add(link['id'])
            nxt = self.replaced_by(link['id'])
            if nxt is None:
                return link
            link = nxt
        return link

    def is_pending(self, link):
        texts = [link.get('from', ''), link.get('to', '')]
        for cond in link['conditions']:
            texts += [cond.get('from') or '', cond.get('to') or '']
        for obj_id in (link.get('from'), link.get('to')):
            obj = self.objects.get(obj_id, {})
            texts += [obj.get('source', '')] + list(obj.get('keys', []))
        return any(PLACEHOLDER.search(t or '') for t in texts)

    def status(self, link):
        """Runtime status of a link as the walker sees it."""
        if self.is_pending(link):
            return 'pending (VERIFY)'
        if not self.layer_active(link['layer']):
            return 'layer off'
        rep = self.replaced_by(link['id'])
        if rep is not None:
            return f'replaced by {rep["id"]}'
        active = _flag(link.get('active'))
        for act in self.activation:
            if act.get('kind') == 'K' and act.get('id') == link['id']:
                return 'active' if _flag(act.get('active'), False) else f'switched off ({act.get("layer")})'
        if not active:
            return 'inactive (VERIFY)' if link.get('verify') else 'inactive'
        return 'active'

    def link_fields(self, link):
        """(object id, field name, role) of every field a link uses: its conditions and the target keys."""
        out = []
        for cond in link['conditions']:
            if cond.get('from'):
                out.append((link['from'], cond['from'], 'from'))
            if cond.get('to'):
                out.append((link['to'], cond['to'], 'to'))
        for key in self.objects.get(link['to'], {}).get('keys', []):
            out.append((link['to'], key, 'key'))
        return out


def load(paths, base=None):
    """Registry of the layer specs (paths relative to base, or absolute)."""
    reg = Registry()
    for path in paths:
        full = path if os.path.isabs(path) or base is None else os.path.join(base, path)
        with open(full, encoding='utf-8') as handle:
            reg.add(json.load(handle), os.path.relpath(full, REPO))
    return reg


# ------------------------------------------------------------------------------------------------ DDIC metadata
DDL_TABLE = re.compile(r'define\s+table\s+(\w+)\s*\{(.*?)\}', re.S | re.I)
DDL_FIELD = re.compile(r'^\s*(?:key\s+)?([a-z_0-9/]+)\s*:', re.I | re.M)
CDS_ENTITY = re.compile(r'define\s+(?:root\s+)?view\s+entity\s+(\w+)', re.I)
CDS_ALIAS = re.compile(r'\bas\s+([A-Za-z_][A-Za-z0-9_]*)\s*,?\s*$', re.I | re.M)
CDS_PLAIN = re.compile(r'^\s*(?:key\s+)?[A-Za-z_][A-Za-z0-9_]*\.([A-Za-z_][A-Za-z0-9_]*)\s*,?\s*$', re.I | re.M)


def ddic_metadata(roots):
    """{SOURCE: set of FIELD names} of the DDL tables (*.tabl.ddl) and CDS view entities (*.ddls.asddls) under the
    given folders - the metadata the repository has; SAP standard objects are checked in the system."""
    meta = {}
    for root in roots:
        if not os.path.isdir(root):
            continue
        for d, dirs, names in os.walk(root):
            dirs[:] = sorted(x for x in dirs if x not in ('__pycache__', '.git'))
            for name in sorted(names):
                path = os.path.join(d, name)
                if name.endswith('.tabl.ddl'):
                    text = _read(path)
                    m = DDL_TABLE.search(re.sub(r'//[^\n]*', '', text))
                    if m:
                        meta[m.group(1).upper()] = {f.upper() for f in DDL_FIELD.findall(m.group(2))}
                elif name.endswith('.ddls.asddls'):
                    text = re.sub(r'//[^\n]*', '', _read(path))
                    m = CDS_ENTITY.search(text)
                    rest = text[m.end():] if m else ''
                    if '{' in rest:
                        body = rest.split('{', 1)[1].rsplit('}', 1)[0]
                        found = {a.upper() for a in CDS_ALIAS.findall(body)}
                        found |= {a.upper() for a in CDS_PLAIN.findall(body)}
                        meta[m.group(1).upper()] = found
    return meta


# ------------------------------------------------------------------------------------------------ validation
def _text_ok(value):
    return value is None or len(str(value)) <= TEXT_MAX


def validate(reg, ddic=None):
    """Problems of the registry (empty = valid). ddic: {SOURCE: fields} where the repository knows the object."""
    p = list(reg.problems)
    ddic = ddic or {}
    ranks = {}
    for lid, layer in reg.layers.items():
        if not LAYER_ID.match(lid):
            p.append(f'layer {lid}: id must be 2-10 upper-case letters, digits or _')
        if layer.get('kind') not in LAYER_KINDS:
            p.append(f'layer {lid}: kind {layer.get("kind")!r} is not one of {sorted(LAYER_KINDS)}')
        if not isinstance(layer.get('rank'), int) or layer.get('rank') <= 0:
            p.append(f'layer {lid}: rank must be a positive number')
        elif layer['rank'] in ranks:
            p.append(f'layer {lid}: rank {layer["rank"]} also used by {ranks[layer["rank"]]}')
        else:
            ranks[layer['rank']] = lid
        if not re.match(r'^[A-Z][A-Z0-9]{0,8}_$', layer.get('prefix', '')):
            p.append(f'layer {lid}: prefix must be upper-case letters / digits ending with _ (e.g. XX_)')
        if not _text_ok(layer.get('description')) or not _text_ok(layer.get('owner')):
            p.append(f'layer {lid}: description / owner longer than {TEXT_MAX}')
    _validate_objects(reg, ddic, p)
    _validate_fields(reg, ddic, p)
    for link in reg.links.values():
        _validate_link(reg, link, p)
    _validate_chains(reg, p)
    for act in reg.activation:
        kind, tid = act.get('kind'), act.get('id')
        if kind not in ACT_KINDS:
            p.append(f'activation {tid}: kind {kind!r} is not L (layer) or K (link)')
            continue
        target = reg.layers.get(tid) if kind == 'L' else reg.links.get(tid)
        if target is None:
            p.append(f'activation {kind} {tid}: no such {"layer" if kind == "L" else "link"}')
            continue
        target_layer = tid if kind == 'L' else target['layer']
        if reg.rank(target_layer) >= reg.rank(act['layer']):
            p.append(f'activation {kind} {tid}: a layer switches only a lower layer ({act["layer"]})')
        if not act.get('reason'):
            p.append(f'activation {kind} {tid}: reason missing')
    return p


def _validate_objects(reg, ddic, p):
    for oid, obj in reg.objects.items():
        layer = reg.layers.get(obj['layer'], {})
        if not ID.match(oid or ''):
            p.append(f'object {oid}: id must be 2-30 upper-case letters, digits or _')
        elif not oid.startswith(layer.get('prefix', '?')):
            p.append(f'object {oid}: id must start with the layer prefix {layer.get("prefix")}')
        source = obj.get('source', '')
        if not (NAME.match(source) or PLACEHOLDER.search(source)):
            p.append(f'object {oid}: source {source!r} is not a DDIC / CDS name')
        if obj.get('kind') not in SOURCE_KINDS:
            p.append(f'object {oid}: kind {obj.get("kind")!r} is not T (table) or V (CDS view)')
        keys = obj.get('keys') or []
        if not keys:
            p.append(f'object {oid}: keys missing (the fields that identify a row for the walker)')
        if len(','.join(keys)) > 255:
            p.append(f'object {oid}: key list longer than 255')
        for key in keys:
            fld = reg.field(oid, key)
            if fld is None:
                p.append(f'object {oid}: key {key} is not a field of the object')
            elif fld['layer'] != obj['layer']:
                p.append(f'object {oid}: key {key} must be a field of the object\'s own layer')
            elif fld.get('sensitivity') == 'H':
                p.append(f'object {oid}: key {key} is hidden (H) - a key is shown masked at most (M)')
        if not _text_ok(obj.get('description')):
            p.append(f'object {oid}: description longer than {TEXT_MAX}')


def _validate_fields(reg, ddic, p):
    for (oid, name), fld in reg.fields.items():
        obj = reg.objects.get(oid)
        where = f'field {oid}-{name}'
        if obj is None:
            p.append(f'{where}: no such object')
            continue
        if reg.rank(fld['layer']) < reg.rank(obj['layer']):
            p.append(f'{where}: a layer adds fields to its own or a lower layer\'s object only')
        pending = bool(PLACEHOLDER.search(name))
        if not (pending or NAME.match(name)):
            p.append(f'{where}: not a DDIC / CDS field name')
        if fld.get('evidence') not in EVIDENCE:
            p.append(f'{where}: evidence {fld.get("evidence")!r} is not C (confirmed) or V (VERIFY)')
        if fld.get('evidence') == 'V' and not fld.get('verify'):
            p.append(f'{where}: a VERIFY field names its VERIFY item')
        if pending and fld.get('evidence') != 'V':
            p.append(f'{where}: a placeholder is a VERIFY field')
        if fld.get('sensitivity', '') not in SENSITIVITY:
            p.append(f'{where}: sensitivity {fld.get("sensitivity")!r} is not blank, M (masked) or H (hidden)')
        if fld.get('data_element') and not NAME.match(fld['data_element']):
            p.append(f'{where}: data element {fld["data_element"]!r} is not a DDIC name')
        if len(str(fld.get('verify') or '')) > 20:
            p.append(f'{where}: VERIFY reference longer than 20')
        if not _text_ok(fld.get('description')):
            p.append(f'{where}: description longer than {TEXT_MAX}')
        known = ddic.get(obj.get('source', '').upper())
        if known is not None and not pending and name.upper() not in known:
            p.append(f'{where}: not a field of {obj["source"]} (DDIC metadata of the repository)')


def _validate_link(reg, link, p):
    lid = link.get('id', '')
    where = f'link {lid}'
    layer = reg.layers.get(link['layer'], {})
    if not ID.match(lid):
        p.append(f'{where}: id must be 2-30 upper-case letters, digits or _')
    elif not lid.startswith(layer.get('prefix', '?')):
        p.append(f'{where}: id must start with the layer prefix {layer.get("prefix")}')
    src, dst = reg.objects.get(link.get('from')), reg.objects.get(link.get('to'))
    if src is None or dst is None:
        p.append(f'{where}: from / to object not defined ({link.get("from")} / {link.get("to")})')
        return
    rank = reg.rank(link['layer'])
    if max(reg.rank(src['layer']), reg.rank(dst['layer'])) > rank:
        p.append(f'{where}: links an object of a higher layer')
    if link.get('cardinality') not in CARDINALITY:
        p.append(f'{where}: cardinality {link.get("cardinality")!r} is not one of {sorted(CARDINALITY)}')
    if link.get('quality') not in QUALITY:
        p.append(f'{where}: quality {link.get("quality")!r} is not C (confirmed) or P (probable)')
    for text in ('owner', 'description'):
        if not _text_ok(link.get(text)):
            p.append(f'{where}: {text} longer than {TEXT_MAX}')
    conds = link['conditions']
    if not any(c.get('kind') == 'EQ' for c in conds):
        p.append(f'{where}: at least one EQ condition (a link joins fields)')
    if len(conds) > 99:
        p.append(f'{where}: at most 99 conditions')
    to_eq, from_eq, prefer = set(), set(), False
    for no, cond in enumerate(conds, start=1):
        _validate_cond(reg, link, no, cond, p)
        if cond.get('kind') in ('EQ', 'CONST'):
            to_eq.add(_upper(cond.get('to', '')))
        if cond.get('kind') == 'EQ':
            from_eq.add(_upper(cond.get('from', '')))
        prefer = prefer or cond.get('kind') == 'PREFER'
    card = link.get('cardinality')
    if card in TO_ONE and not prefer and not {_upper(k) for k in dst.get('keys', [])} <= to_eq:
        p.append(f'{where}: cardinality {card} needs the key fields of {dst["id"]} on the to side (EQ or '
                 f'CONST) or a PREFER condition')
    if card in FROM_ONE and not {_upper(k) for k in src.get('keys', [])} <= from_eq:
        p.append(f'{where}: cardinality {card} needs the key fields of {src["id"]} on the from side')
    if _flag(link.get('active')):
        for oid, name, role in reg.link_fields(link):
            fld = reg.field(oid, name)
            if fld is not None and fld.get('evidence') != 'C':
                p.append(f'{where}: active, but {role} field {oid}-{name} is VERIFY ({fld.get("verify")}) - '
                         'deliver the link inactive')
        if not (_flag(src.get('active')) and _flag(dst.get('active'))):
            p.append(f'{where}: active, but an object is inactive')
    elif not link.get('verify') and reg.is_pending(link):
        p.append(f'{where}: a pending link names its VERIFY item')
    for fld_name in ('fallback_of', 'replaces'):
        target = link.get(fld_name)
        if not target:
            continue
        other = reg.links.get(target)
        if other is None:
            p.append(f'{where}: {fld_name} {target} is not a link')
            continue
        if (other['from'], other['to']) != (link['from'], link['to']):
            p.append(f'{where}: {fld_name} {target} must link the same objects')
        if fld_name == 'replaces' and reg.rank(other['layer']) >= rank:
            p.append(f'{where}: replaces {target} - only a link of a lower layer can be replaced')
        if fld_name == 'fallback_of' and reg.rank(other['layer']) > rank:
            p.append(f'{where}: fallback of {target} of a higher layer')


def _validate_cond(reg, link, no, cond, p):
    where = f'link {link.get("id")} condition {no}'
    kind = cond.get('kind')
    if kind not in COND_KINDS:
        p.append(f'{where}: kind {kind!r} is not one of {COND_KINDS}')
        return
    need_from = kind == 'EQ'
    need_value = kind in ('CONST', 'PREFER')
    if bool(cond.get('from')) != need_from:
        p.append(f'{where}: {kind} {"needs" if need_from else "takes no"} from field')
    if not cond.get('to'):
        p.append(f'{where}: to field missing')
    if bool(cond.get('value')) != need_value:
        p.append(f'{where}: {kind} {"needs" if need_value else "takes no"} value')
    transform, arg = cond.get('transform', '') or '', str(cond.get('arg', '') or '')
    if transform not in TRANSFORMS:
        p.append(f'{where}: transform {transform!r} is not one of {TRANSFORMS}')
    elif transform and kind != 'EQ':
        p.append(f'{where}: a transform applies to an EQ condition only')
    elif transform in NUMERIC_ARG and not re.match(r'^[1-9][0-9]?$', arg):
        p.append(f'{where}: {transform} needs a length 1-99 as argument')
    elif transform in TEXT_ARG and not arg:
        p.append(f'{where}: {transform} needs the text as argument')
    elif not transform and arg:
        p.append(f'{where}: argument without transform')
    for text in (str(cond.get('value') or ''), arg):
        if UNSAFE.search(text):
            p.append(f'{where}: {text!r} contains a quote or a statement character')
        if len(text) > 70:
            p.append(f'{where}: value longer than 70')
    for side, oid in (('from', link.get('from')), ('to', link.get('to'))):
        name = cond.get(side)
        if not name:
            continue
        fld = reg.field(oid, name)
        if fld is None:
            p.append(f'{where}: {side} field {name} is not a field of {oid}')
            continue
        if reg.rank(fld['layer']) > reg.rank(link['layer']):
            p.append(f'{where}: {side} field {name} belongs to a higher layer ({fld["layer"]})')
        if kind in ('CONST', 'PREFER') and fld.get('sensitivity'):
            p.append(f'{where}: sensitive field {name} as a constant or preferred value')


def _validate_chains(reg, p):
    successors = {}
    for link in reg.links.values():
        if link.get('fallback_of'):
            successors.setdefault(link['fallback_of'], []).append(link['id'])
    for head, nxt in successors.items():
        if len(nxt) > 1:
            p.append(f'link {head}: more than one fallback ({", ".join(sorted(nxt))}) - a chain, not a tree')
    for link in reg.links.values():
        seen, cur = [], link
        while cur is not None and cur.get('fallback_of'):
            if cur['id'] in seen:
                p.append(f'link {link["id"]}: fallback chain is cyclic ({" -> ".join(seen + [cur["id"]])})')
                break
            seen.append(cur['id'])
            cur = reg.links.get(cur['fallback_of'])


def chains(reg):
    """{head link id: [links in fallback order]} of every chain (a link without fallback_of is a head)."""
    succ = {link['fallback_of']: link for link in reg.links.values() if link.get('fallback_of')}
    out = {}
    for link in sorted(reg.links.values(), key=lambda x: x['id']):
        if link.get('fallback_of'):
            continue
        chain, cur, seen = [], link, set()
        while cur is not None and cur['id'] not in seen:
            seen.add(cur['id'])
            chain.append(cur)
            cur = succ.get(cur['id'])
        out[link['id']] = chain
    return out


# ------------------------------------------------------------------------------------------------ seed rows
def _x(value):
    return 'X' if value else ''


def _ref(reg, oid, name):
    obj = reg.objects[oid]
    return f'{obj["source"].upper()}-{_upper(name)}'


def seed_rows(reg, layer_ids):
    """{table: [rows]} of the given layers; pending objects / fields / links (placeholders) are not seeded."""
    rows = {table: [] for table, _ in TABLES}
    for lid in layer_ids:
        layer = reg.layers[lid]
        rows['zca_ops_lnklyr'].append([lid, layer['kind'], str(layer['rank']), layer['prefix'],
                                       layer.get('description', ''), layer.get('owner', ''),
                                       _x(layer.get('active', True))])
    for oid, obj in sorted(reg.objects.items()):
        if obj['layer'] not in layer_ids or PLACEHOLDER.search(obj['source'] + ''.join(obj.get('keys', []))):
            continue
        rows['zca_ops_lnkobj'].append([oid, obj['layer'], obj['source'].upper(), obj['kind'],
                                       ','.join(_upper(k) for k in obj['keys']), obj.get('description', ''),
                                       _x(obj.get('active', True))])
    for (oid, name), fld in sorted(reg.fields.items()):
        obj = reg.objects.get(oid)
        if fld['layer'] not in layer_ids or obj is None or PLACEHOLDER.search(name + obj['source']):
            continue
        rows['zca_ops_lnkfld'].append([oid, name, fld['layer'], obj['source'].upper(), fld.get('data_element', ''),
                                       fld.get('sensitivity', ''), fld.get('evidence', ''), fld.get('verify', ''),
                                       fld.get('description', '')])
    for lid, link in sorted(reg.links.items()):
        if link['layer'] not in layer_ids or reg.is_pending(link):
            continue
        rows['zca_ops_link'].append([lid, link['layer'], link['from'], link['to'], link['cardinality'],
                                     link['quality'], link.get('fallback_of') or '', link.get('replaces') or '',
                                     _x(link.get('active', True)), link.get('owner', ''), link.get('verify', ''),
                                     link.get('description', '')])
        for no, cond in enumerate(link['conditions'], start=1):
            rows['zca_ops_lnkcnd'].append([
                lid, f'{no:03d}', cond['kind'],
                _ref(reg, link['from'], cond['from']) if cond.get('from') else '',
                _ref(reg, link['to'], cond['to']), str(cond.get('value') or ''), cond.get('transform', '') or '',
                str(cond.get('arg', '') or '')])
    for act in reg.activation:
        if act['layer'] in layer_ids:
            rows['zca_ops_lnkact'].append([act['kind'], act['id'], act['layer'], _x(act.get('active')),
                                           act.get('reason', ''), act.get('owner', '')])
    return rows


def seed_files(reg, layer_ids, folder):
    """{relative path: CSV text} of the seed rows."""
    out = {}
    rows = seed_rows(reg, layer_ids)
    for table, columns in TABLES:
        buf = io.StringIO()
        writer = csv.writer(buf, lineterminator='\n')
        writer.writerow(columns)
        writer.writerows(rows[table])
        out[os.path.join(folder, f'{table}.csv')] = buf.getvalue()
    return out


# ------------------------------------------------------------------------------------------------ CDS rendering
def _cds_source(obj):
    return obj['source'].lower() if obj['kind'] == 'T' else obj['source']


def _cds_field(obj, fld_name, reg):
    if obj['kind'] == 'T':
        return fld_name.lower()
    fld = reg.field(obj['id'], fld_name)
    return fld['name'] if fld else fld_name


def _cds_operand(expr, cond):
    transform, arg = cond.get('transform', '') or '', str(cond.get('arg', '') or '')
    return {'': expr, 'UPPER': f'upper( {expr} )', 'LEFT': f'left( {expr}, {arg} )',
            'RIGHT': f'right( {expr}, {arg} )', 'PREFIX': f"concat( '{arg}', {expr} )",
            'SUFFIX': f"concat( {expr}, '{arg}' )", 'ALPHA': f"lpad( {expr}, {arg}, '0' )",
            'NOZERO': f"ltrim( {expr}, '0' )"}[transform]


def conditions_cds(reg, link, to_alias, from_alias):
    """[(left, operator, right)] of the CDS ON condition; a value list is one compound (text, None, None).
    PREFER is not a join condition (the consumer view applies it)."""
    src, dst = reg.objects[link['from']], reg.objects[link['to']]
    out = []
    for cond in link['conditions']:
        left = f"{to_alias}.{_cds_field(dst, cond['to'], reg)}"
        if cond['kind'] == 'EQ':
            out.append((left, '=', _cds_operand(f"{from_alias}.{_cds_field(src, cond['from'], reg)}", cond)))
        elif cond['kind'] == 'CONST':
            values = [v.strip() for v in str(cond['value']).split(',')]
            if len(values) == 1:
                out.append((left, '=', f"'{values[0]}'"))
            else:
                out.append(('( ' + ' or '.join(f"{left} = '{v}'" for v in values) + ' )', None, None))
        elif cond['kind'] == 'NOTINIT':
            out.append((left, '<>', "' '"))
    return out


def render_join(reg, link_id, join, alias, from_alias, layout=None):
    """Lines of a CDS join of the effective link (a replacement of an active layer wins); layout = None (compact:
    'and' under 'on', left operands padded to the longest of the join) or {source, alias, left} column widths."""
    link = reg.resolve(link_id)
    if link is None:
        raise RegistryError(f'link {link_id} is not in the registry')
    if reg.is_pending(link):
        raise RegistryError(f'link {link_id} is pending (placeholder) - it cannot be rendered')
    if join not in JOIN_TYPES or not ALIAS.match(alias or '') or not ALIAS.match(from_alias or ''):
        raise RegistryError(f'link {link_id}: join {join!r} / alias {alias!r} / from alias {from_alias!r} invalid')
    conds = conditions_cds(reg, link, alias, from_alias)
    source = _cds_source(reg.objects[link['to']])
    if layout:
        head = f"{join} {source.ljust(layout['source'])} as {alias.ljust(layout['alias'])} on"
        width, gap = layout['left'], '  '
    else:
        head = f'{join} {source} as {alias} on'
        width = max([len(c[0]) for c in conds if c[1]] or [0])
        gap = '  ' if len(conds) > 1 else ' '
    lines = []
    for i, (left, op, right) in enumerate(conds):
        text = left if op is None else f'{left.ljust(width)} {op} {right}'
        lines.append(head + gap + text if i == 0 else ' ' * (len(head) - 2) + 'and ' + text)
    return lines


def association(reg, link):
    """CDS association snippet of a link (from side elements named as in the source)."""
    src, dst = reg.objects[link['from']], reg.objects[link['to']]
    target = '_' + ''.join(part.capitalize() for part in link['to'].split('_')[1:])
    parts = []
    for cond in link['conditions']:
        left = f"{target}.{_cds_field(dst, cond['to'], reg)}"
        if cond['kind'] == 'EQ':
            parts.append(f"{left} = {_cds_operand('$projection.' + _cds_field(src, cond['from'], reg), cond)}")
        elif cond['kind'] == 'CONST':
            values = [v.strip() for v in str(cond['value']).split(',')]
            parts.append(f"{left} = '{values[0]}'" if len(values) == 1 else
                         '( ' + ' or '.join(f"{left} = '{v}'" for v in values) + ' )')
        elif cond['kind'] == 'NOTINIT':
            parts.append(f"{left} <> ' '")
    return (f"association {CARDINALITY[link['cardinality']]} to {_cds_source(dst)} as {target}\n"
            f"  on " + '\n  and '.join(parts))


# ------------------------------------------------------------------------------------------------ documents
def _layer_title(reg, lid):
    layer = reg.layers[lid]
    return f"{lid} - {LAYER_KINDS.get(layer['kind'], '?')} (rank {layer['rank']})"


def lineage(reg, title, layer_ids):
    """Markdown: Mermaid diagram of the objects and links of the layers, link list, custom field flows, pending."""
    shown = [lid for lid in sorted(reg.layers, key=reg.rank) if lid in layer_ids]
    lines = [f'# {title}', '', '> Generated by `tools/link_registry.py` from the layer specs - never edit, regenerate.',
             '', 'Solid arrow = active link, dotted arrow = inactive (VERIFY item open, switched off or replaced); '
             'label = link ID and cardinality. Pending links (a field still a placeholder) are not drawn; the table '
             'of links lists them.', '', '```mermaid', 'flowchart LR']
    for lid in shown:
        lines.append(f'  subgraph {lid}["{_layer_title(reg, lid)}"]')
        for oid, obj in sorted(reg.objects.items()):
            if obj['layer'] == lid:
                lines.append(f'    {oid}["{oid}<br/>{obj["source"]}"]')
        lines.append('  end')
    for lid, link in sorted(reg.links.items()):
        if link['layer'] not in shown or reg.is_pending(link):
            continue
        if link['from'] not in reg.objects or link['to'] not in reg.objects:
            continue
        arrow = '-->' if reg.status(link) == 'active' else '-.->'
        lines.append(f'  {link["from"]} {arrow}|"{lid} {link["cardinality"]}"| {link["to"]}')
    lines += ['```', '', '## Links', '',
              '| Link | Layer | From | To | Cardinality | Quality | Conditions | Fallback of / replaces | Status |',
              '|---|---|---|---|---|---|---|---|---|']
    for lid, link in sorted(reg.links.items(), key=lambda x: (reg.rank(x[1]['layer']), x[0])):
        if link['layer'] not in shown:
            continue
        lines.append(f"| {lid} | {link['layer']} | {link['from']} | {link['to']} | {link['cardinality']} | "
                     f"{link['quality']} | {_cond_text(reg, link)} | "
                     f"{' / '.join(x for x in (link.get('fallback_of') or '', link.get('replaces') or '') if x) or '-'} | "
                     f"{reg.status(link)}{' ' + link['verify'] if link.get('verify') else ''} |")
    flows = _custom_flows(reg, shown)
    if flows:
        lines += ['', '## Custom field flows', '',
                  'Fields a customer layer added (to its own or a standard object) and the links they flow through.',
                  '', '| Field | Layer | Flows through | Into |', '|---|---|---|---|']
        lines += flows
    return '\n'.join(lines) + '\n'


def _cond_text(reg, link):
    parts = []
    for cond in link['conditions']:
        to = f"{reg.objects[link['to']]['source']}-{cond['to']}"
        if cond['kind'] == 'EQ':
            frm = f"{reg.objects[link['from']]['source']}-{cond['from']}"
            tr = f" ({cond['transform']} {cond.get('arg', '')})".replace(' )', ')') if cond.get('transform') else ''
            parts.append(f'{to} = {frm}{tr}')
        elif cond['kind'] == 'CONST':
            parts.append(f"{to} = '{cond['value']}'")
        elif cond['kind'] == 'NOTINIT':
            parts.append(f'{to} not initial')
        else:
            parts.append(f"prefer {to} = '{cond['value']}'")
    return '; '.join(parts).replace('|', '/')


def _custom_flows(reg, shown):
    out = []
    for (oid, name), fld in sorted(reg.fields.items()):
        layer = reg.layers.get(fld['layer'], {})
        if layer.get('kind') != 'C' or fld['layer'] not in shown:
            continue
        for lid, link in sorted(reg.links.items()):
            for cond in link['conditions']:
                if cond['kind'] != 'EQ':
                    continue
                if link['from'] == oid and _upper(cond['from']) == name:
                    out.append(f"| {reg.objects[oid]['source']}-{fld['name']} | {fld['layer']} | {lid} "
                               f"({reg.status(link)}) | {reg.objects[link['to']]['source']}-{cond['to']} |")
                elif link['to'] == oid and _upper(cond['to']) == name:
                    out.append(f"| {reg.objects[oid]['source']}-{fld['name']} | {fld['layer']} | {lid} "
                               f"({reg.status(link)}) | from {reg.objects[link['from']]['source']}-{cond['from']} |")
    return out


def snippets(reg, title, layer_ids):
    """Markdown: CDS join and association snippet of every link of the layers that can be rendered."""
    lines = [f'# {title}', '', '> Generated by `tools/link_registry.py` - never edit, regenerate. `To` is the alias '
             'of the target, `From` of the source; a payment model mapping names the link (`{"link": ...}`) and gets '
             'the join rendered with its own aliases. A transform renders as a CDS function (VERIFY-ADT on the '
             'release before a generated view uses one). PREFER is not a join condition: the consumer view applies '
             'it (e.g. a status filter or the newest row).', '']
    for lid, link in sorted(reg.links.items(), key=lambda x: (reg.rank(x[1]['layer']), x[0])):
        if link['layer'] not in layer_ids:
            continue
        lines += [f'## {lid}', '', f"{link.get('description', '')} - {link['cardinality']}, quality "
                  f"{link['quality']}, {reg.status(link)}{' ' + link['verify'] if link.get('verify') else ''}.", '']
        if reg.is_pending(link):
            lines += ['Pending: a field is still a placeholder - no snippet until the VERIFY item names it.', '']
            continue
        lines += ['```', *render_join(reg, lid, 'left outer join', 'To', 'From'), '', association(reg, link),
                  '```', '']
    return '\n'.join(lines)


def impact(reg, title, layer_ids, usages=None):
    """Markdown: for every field of the layers' objects, the links, keys and other usages that depend on it."""
    usages = usages or {}
    lines = [f'# {title}', '', '> Generated by `tools/link_registry.py` - never edit, regenerate. Read it before a '
             'field changes (renamed, removed, retyped, content changed): every row lists what must be checked again.',
             '', '| Field | Evidence | Object key of | Links | Other usages |', '|---|---|---|---|---|']
    index = {}
    for lid, link in reg.links.items():
        for oid, name, role in reg.link_fields(link):
            index.setdefault((oid, _upper(name)), []).append(f'{lid} ({role}, {reg.status(link)})')
    for (oid, name), fld in sorted(reg.fields.items(), key=lambda x: (reg.objects.get(x[0][0], {}).get('source', ''),
                                                                       x[0][1])):
        obj = reg.objects.get(oid)
        if obj is None or (fld['layer'] not in layer_ids and obj['layer'] not in layer_ids):
            continue
        source = obj['source'].upper()
        keys = oid if name in {_upper(k) for k in obj.get('keys', [])} else '-'
        uses = sorted(set(index.get((oid, name), [])))
        links = [x for x in uses if '(key,' not in x] + sorted({x.split(' ')[0] + ' (target key)'
                                                              for x in uses if '(key,' in x})
        other = sorted(set(usages.get((source, name), [])))
        evidence = 'confirmed' if fld.get('evidence') == 'C' else f"VERIFY {fld.get('verify', '')}"
        lines.append(f"| {source}-{fld['name']} | {evidence} | {keys} | {'<br/>'.join(links) or '-'} | "
                     f"{'<br/>'.join(other) or '-'} |")
    return '\n'.join(lines) + '\n'


# ------------------------------------------------------------------------------------------------ usages
ALIAS_DECL = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)\s+as\s+([A-Za-z_][A-Za-z0-9_]*)', re.I)
ALIAS_USE = re.compile(r'\b([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\b')


def payment_model_usages(reg, mapping):
    """{(SOURCE, FIELD): [usage]} of a payment model mapping spec: the fields its sections read (from, literal
    joins, where, group by, field expressions) and the registry links it names."""
    out = {}
    for section, sec in mapping.items():
        if section == 'model' or not isinstance(sec, dict) or 'from' not in sec:
            continue
        status = sec.get('status', 'active')
        texts = [sec.get('from', '')]
        aliases = {}
        for join in sec.get('joins', []):
            if isinstance(join, dict):
                link = reg.resolve(join['link'])
                if link is None:
                    continue
                aliases[join['alias']] = reg.objects[link['to']]['source']
                for oid, name, role in reg.link_fields(link):
                    if role != 'key':
                        out.setdefault((reg.objects[oid]['source'].upper(), _upper(name)), []).append(
                            f"payment model {section} ({status}): join {join['link']}")
            else:
                texts.append(join)
        texts += list(sec.get('where', [])) + list(sec.get('group_by', []))
        texts += [f.get('expr') or '' for f in sec.get('fields', {}).values()]
        for text in texts[:1] + [t for t in texts[1:] if 'join' in t]:
            for src, alias in ALIAS_DECL.findall(text):
                if src.lower() not in ('join', 'as'):
                    aliases[alias] = src
        for text in texts:
            for alias, name in ALIAS_USE.findall(text):
                if alias in aliases:
                    out.setdefault((aliases[alias].upper(), name.upper()), []).append(
                        f'payment model {section} ({status})')
    return out


def aggregate_usages(paths):
    """{(TABLE, FIELD): [usage]} of aggregate check rows (CSV of ZCA_OPS_AGG columns)."""
    out = {}
    for path in paths:
        if not os.path.exists(path):
            continue
        with open(path, encoding='utf-8') as handle:
            for row in csv.DictReader(handle):
                table = (row.get('TABNAME') or '').upper()
                for col in ('DATE_FIELD', 'BUKRS_FIELD', 'STATUS_FIELD', 'COND_FIELD'):
                    if row.get(col):
                        out.setdefault((table, row[col].upper()), []).append(
                            f"aggregate check {row.get('AREA')}/{row.get('CHECK_ID')}/{row.get('AGG_ID')}")
    return out


# ------------------------------------------------------------------------------------------------ profile runner
def outputs(root, profile):
    """(registry, problems, {relative path: text}) of a component profile:
    own [layer spec paths, seeded], base [paths loaded first, not seeded], examples [validated with the own layers,
    neither seeded nor documented], seed_folder, docs_folder, ddic [folders], title, payment_model (spec path or
    None), aggregates [CSV paths]."""
    base = [p if os.path.isabs(p) else os.path.join(root, p) for p in profile.get('base', [])]
    own = [os.path.join(root, p) for p in profile['own']]
    reg = load(base + own)
    ddic = ddic_metadata([os.path.join(root, d) for d in profile.get('ddic', [])])
    problems = validate(reg, ddic)
    for example in profile.get('examples', []):
        sample = load(base + own + [os.path.join(root, example)])
        problems += [f'{example}: {x}' for x in validate(sample, ddic) if x not in problems]
    own_ids = [lid for lid, layer in reg.layers.items()
               if os.path.normpath(os.path.join(REPO, layer['file'])) in [os.path.normpath(p) for p in own]]
    files = {}
    if problems:
        return reg, problems, files
    files.update(seed_files(reg, own_ids, profile['seed_folder']))
    usages = {}
    if profile.get('payment_model'):
        with open(os.path.join(root, profile['payment_model']), encoding='utf-8') as handle:
            for key, value in payment_model_usages(reg, json.load(handle)).items():
                usages.setdefault(key, []).extend(value)
    for key, value in aggregate_usages([os.path.join(root, p) for p in profile.get('aggregates', [])]).items():
        usages.setdefault(key, []).extend(value)
    shown = list(reg.layers) if profile.get('show_all') else own_ids
    docs = profile['docs_folder']
    title = profile['title']
    files[os.path.join(docs, 'lineage.md')] = lineage(reg, f'{title} - lineage', shown)
    files[os.path.join(docs, 'cds_snippets.md')] = snippets(reg, f'{title} - CDS snippets', own_ids)
    files[os.path.join(docs, 'impact.md')] = impact(reg, f'{title} - field impact', shown, usages)
    return reg, problems, files


def _read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def check(root, profile):
    """Problems of the registry plus out-of-date outputs (empty = valid and up to date)."""
    _, problems, files = outputs(root, profile)
    stale = [f'{rel}: out of date (run tools/link_registry.py)' for rel, text in sorted(files.items())
             if _read(os.path.join(root, rel)) != text]
    return problems + stale


def generate(root, profile):
    _, problems, files = outputs(root, profile)
    if problems:
        raise RegistryError('\n'.join(problems))
    written = []
    for rel, text in sorted(files.items()):
        path = os.path.join(root, rel)
        if _read(path) != text:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8') as handle:
                handle.write(text)
            written.append(rel)
    return written


def main(root, profile, argv):
    if '--check' in argv:
        failures = check(root, profile)
        if failures:
            print('Link registry invalid or out of date:')
            for line in failures:
                print('  ' + line)
            return 1
        print('link registry valid and up to date')
        return 0
    try:
        written = generate(root, profile)
    except RegistryError as error:
        print(error)
        return 1
    print(f'{len(written)} file(s) written')
    return 0
