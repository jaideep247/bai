"""Offline validation of the bucket rules of the clearing-account break analysis (ZCA_OPS, build F).

The bucket model and its rules are configuration rows (ops-framework/docs/BREAK_ANALYSIS.md): buckets
(ZCA_OPS_BRKBKT), rules (ZCA_OPS_BRKRUL: area or *, ordered by SEQ, first match wins) and their conditions
(ZCA_OPS_BRKCND: FIELD of a journal line, GROUP value, DAYS window, LINK to an object of the link registry).
The product delivers buckets and generic rules (ops-framework/config/breaks); a consumer adds its overlay
(<consumer>/config/breaks) on top. This engine checks the seed files of the layers together, the same rules
the analysis applies at run time (ZCL_CA_OPS_BRK_RULES=>EFFECTIVE_RULES) plus the layering rules of a product:

  - every rule names an active bucket; every condition belongs to a rule; kind, operator and field are known for
    the kind (EX / NX only on LINK); a LINK condition names a link; an @ value names a defined parameter
  - a rule ID starts with the prefix of its layer (<LAYER>_; product layers S4CORE -> S4_, FICA -> FICA_)
  - a product folder holds rules of every area (*) only - a customer's area belongs to its overlay
  - sequences are unique per area (first match wins must be deterministic)
  - a link named by a condition exists in the given link IDs (when given)

Usage from a check:  problems = check_folders([('product', folder), ('overlay', folder)], params=..., links=...)
Modification log:
2026-11-11 | Initial version (build F: clearing-account break analysis).
"""
import csv
import os

FILES = {'buckets': 'zca_ops_brkbkt.csv', 'rules': 'zca_ops_brkrul.csv', 'conds': 'zca_ops_brkcnd.csv'}
KINDS = {'FIELD', 'GROUP', 'DAYS', 'LINK'}
OPS = {'EQ', 'NE', 'IN', 'NI', 'GE', 'LE', 'GT', 'LT', 'RX', 'BL', 'NB', 'EX', 'NX'}
LINK_ONLY = {'EX', 'NX'}
FIELDS = {
    'FIELD': {'POSTING_DATE', 'DOCUMENT_DATE', 'DOC_TYPE', 'DEBIT_CREDIT', 'ASSIGNMENT', 'REF_TYPE', 'RECON_KEY',
              'AMOUNT', 'CURRENCY'},
    'GROUP': {'LINES', 'DEBITS', 'CREDITS', 'NET_AMOUNT', 'AGE_DAYS', 'CLEARS_LATER', 'LATER_DOC_TYPE',
              'DAYS_TO_CLEAR'},
    'DAYS': {'PERIOD_END', 'KEY_DATE'},
}
PREFIX = {'S4CORE': 'S4_', 'FICA': 'FICA_'}
AREA_ANY = '*'


def read_csv(path):
    if not os.path.exists(path):
        return []
    with open(path, newline='', encoding='utf-8') as handle:
        return list(csv.DictReader(handle))


def load(folder):
    """The rows of one layer's folder: {'buckets': [...], 'rules': [...], 'conds': [...]}."""
    return {key: read_csv(os.path.join(folder, name)) for key, name in FILES.items()}


def prefix_of(layer):
    return PREFIX.get(layer, f'{layer}_')


def validate(layers, params=None, links=None, product=None):
    """Problems of the layers taken together (list of strings, empty = valid).

    layers   [(label, rows)] in order (product first)
    params   parameter names that may be named as @ values (None = not checked)
    links    link IDs a LINK condition may name (None = not checked)
    product  labels of product layers (their rules must be of every area)"""
    problems = []
    product = set(product or [])
    buckets, rules, conds = {}, {}, []
    for label, rows in layers:
        for row in rows['buckets']:
            buckets[row['BUCKET']] = (label, row)
        for row in rows['rules']:
            key = (row['AREA'], row['RULE_ID'])
            if key in rules:
                problems.append(f'{label}: rule {row["RULE_ID"]} of area {row["AREA"]} defined twice')
            rules[key] = (label, row)
            if label in product and row['AREA'] != AREA_ANY:
                problems.append(f'{label}: product rule {row["RULE_ID"]} must be of every area (*), not {row["AREA"]}')
        conds += [(label, row) for row in rows['conds']]
    if 'OTHER' not in buckets:
        problems.append('bucket OTHER (not explained) is not defined')
    seqs = {}
    for (area, rule_id), (label, row) in sorted(rules.items()):
        bucket = buckets.get(row['BUCKET'])
        if row.get('ACTIVE') == 'X' and (bucket is None or bucket[1].get('ACTIVE') != 'X'):
            problems.append(f'{label}: rule {rule_id}: bucket {row["BUCKET"]} is not defined or not active')
        if not rule_id.startswith(prefix_of(row['LAYER_ID'])):
            problems.append(f'{label}: rule {rule_id} does not start with the prefix {prefix_of(row["LAYER_ID"])} '
                            f'of layer {row["LAYER_ID"]}')
        if row.get('ACTIVE') == 'X':
            seq_key = (area, row['SEQ'])
            if seq_key in seqs:
                problems.append(f'{label}: rules {seqs[seq_key]} and {rule_id} of area {area} share sequence '
                                f'{row["SEQ"]} (first match wins must be deterministic)')
            seqs[seq_key] = rule_id
        if len(row.get('REASON', '')) > 120:
            problems.append(f'{label}: rule {rule_id}: reason longer than 120 characters')
    for label, row in conds:
        rule_id, kind, op, field = row['RULE_ID'], row['COND_KIND'], row['OPERATOR'], row['FIELD']
        where = f'{label}: rule {rule_id} condition {row["COND_NO"]}'
        if (row['AREA'], rule_id) not in rules:
            problems.append(f'{where}: the rule is not defined (area {row["AREA"]})')
        if kind not in KINDS:
            problems.append(f'{where}: kind {kind!r} is not one of {sorted(KINDS)}')
            continue
        if op not in OPS or (op in LINK_ONLY and kind != 'LINK'):
            problems.append(f'{where}: operator {op!r} is not allowed for kind {kind}')
        if kind == 'LINK':
            if not row['LINK_ID']:
                problems.append(f'{where}: a LINK condition names its link (LINK_ID)')
            elif links is not None and row['LINK_ID'] not in links:
                problems.append(f'{where}: link {row["LINK_ID"]} is not a link of the registry')
        else:
            if field not in FIELDS[kind]:
                problems.append(f'{where}: {field!r} is not a field of kind {kind}')
            if row['LINK_ID']:
                problems.append(f'{where}: LINK_ID must be blank for kind {kind}')
        value = row['COND_VALUE'].strip()
        if value.startswith('@') and params is not None and value[1:].upper() not in params:
            problems.append(f'{where}: parameter {value[1:]} is not defined')
        if op not in ('BL', 'NB', 'EX', 'NX') and not value:
            problems.append(f'{where}: operator {op} needs a value')
    return problems


def param_names(*paths):
    """Parameter names of param_definitions.csv files."""
    names = set()
    for path in paths:
        for row in read_csv(path):
            names.add(row['NAME'].upper())
    return names


def link_ids(*paths):
    """Link IDs of zca_ops_link.csv seed files of the link registry."""
    ids = set()
    for path in paths:
        for row in read_csv(path):
            ids.add(row['LINK_ID'])
    return ids


def check_folders(folders, params=None, links=None, product=None):
    """Problems of the seed folders [(label, folder)] (product first, then overlays)."""
    return validate([(label, load(folder)) for label, folder in folders], params=params, links=links,
                    product=product)
