"""Offline validation of the account flow configuration of the operations framework (ZCA_OPS, build G).

An account flow (ops-framework/docs/ACCOUNT_FLOW.md) is configuration rows: flows (ZCA_OPS_FLOW), accounts by role
(ZCA_OPS_FLWACC), stages (ZCA_OPS_FLWSTG), tiles fed by stage rows (ZCA_OPS_FLWTIL), the checks that control a stage
(ZCA_OPS_FLWCTL) and the ordered stage rules (ZCA_OPS_FLWRUL: first match wins by sequence, unmatched lines go to the
row OTHER). The product delivers generic flows of SAP standard processes (ops-framework/config/flows); a consumer adds
its overlay (<consumer>/config/flows). This engine checks the seed files of the layers together - the rules the
evaluation applies at run time (ZCL_CA_OPS_FLOW_CONFIG=>VALIDATE) plus the layering rules of a product:

  - every account, stage, tile, control and rule belongs to a flow of the layers; roles, line sources, tiles, sides,
    categories, debit / credit are known values; reserved rows (OTHER, MOVEMENT, OPENING, CLOSING, UNEXPLAINED) are
    no stage, a rule names a stage of its flow or OTHER (never a position row)
  - a rule names only criteria of its line source (G journal: REF_TYPE, DOC_TYPE, DEBIT_CREDIT; F FI-CA: DOC_TYPE,
    ORIGIN, MAIN_TRANS, SUB_TRANS, DEBIT_CREDIT) and, when active, at least one (it would hide the row OTHER)
  - sequences are unique per flow (first match wins must be deterministic); stage sequences unique per flow
  - one account per role, company code and currency for a role that receives an expected counter-posting (EXPECT_TO);
    a role a stage (expected postings) or a tile names is held by an account of the flow (only when the layers hold accounts for it - a product template has none)
  - a product folder holds no account (accounts are a customer's), rule IDs of a product start with S4_ (journal) or
    FICA_ (FI-CA); a control of a product names a check of the given registries (when given)
  - every row of an inactive layer is delivered inactive (ACTIVE blank)

Usage from a check:  problems = check_folders([('product', folder), ('overlay', folder)], product=..., inactive=...)
Modification log:
2026-11-15 | Initial version (build G: account flow reconciliation).
"""
import csv
import os

FILES = {'flows': 'zca_ops_flow.csv', 'accounts': 'zca_ops_flwacc.csv', 'stages': 'zca_ops_flwstg.csv',
         'tiles': 'zca_ops_flwtil.csv', 'controls': 'zca_ops_flwctl.csv', 'rules': 'zca_ops_flwrul.csv'}
ROLES = {'RECEIVABLE', 'PAYABLE', 'OUTSIDE', 'SETTLEMENT', 'CLEARING', 'CASH', 'CLARIFICATION'}
RESERVED = {'OTHER', 'MOVEMENT', 'OPENING', 'CLOSING', 'UNEXPLAINED'}
SOURCES = {'G', 'F'}
CATEGORIES = {'', 'TRANSIT', 'CLARIFY', 'OPEN', 'BANK'}
TILES = {'REQUESTED', 'PAID', 'CLEARED'}
CRITERIA = {'G': ('REF_TYPE', 'DOC_TYPE', 'DEBIT_CREDIT'),
            'F': ('DOC_TYPE', 'ORIGIN', 'MAIN_TRANS', 'SUB_TRANS', 'DEBIT_CREDIT')}
ALL_CRITERIA = ('REF_TYPE', 'DOC_TYPE', 'ORIGIN', 'MAIN_TRANS', 'SUB_TRANS', 'DEBIT_CREDIT')
PRODUCT_PREFIX = {'G': 'S4_', 'F': 'FICA_'}


def read_csv(path):
    if not os.path.exists(path):
        return []
    with open(path, newline='', encoding='utf-8') as handle:
        return list(csv.DictReader(handle))


def load(folder):
    """The rows of one layer's folder: {'flows': [...], 'accounts': [...], ...}."""
    return {key: read_csv(os.path.join(folder, name)) for key, name in FILES.items()}


def _v(row, field):
    return (row.get(field) or '').strip()


def validate(layers, product=None, inactive=None, checks=None):
    """Problems of the layers taken together (list of strings, empty = valid).

    layers    [(label, rows)] in order (product first)
    product   labels of product layers (no accounts, rule prefixes S4_ / FICA_, controls of known checks)
    inactive  labels of layers whose rows must all be delivered inactive
    checks    (area, check ID) pairs a product control may name (None = not checked)"""
    product = set(product or [])
    inactive = set(inactive or [])
    problems = []
    flows, stages, seqs, rule_seqs, slots = {}, {}, {}, {}, {}
    accounts = []
    for label, rows in layers:
        for row in rows['flows']:
            key = (_v(row, 'AREA'), _v(row, 'FLOW_ID'))
            if key in flows:
                problems.append(f'{label}: flow {key[1]} of area {key[0]} defined twice')
            flows[key] = (label, row)
            if _v(row, 'DIRECTION') not in ('', 'D', 'C'):
                problems.append(f'{label}: flow {key[1]}: direction {_v(row, "DIRECTION")!r} is not D or C')
        for row in rows['stages']:
            key = (_v(row, 'AREA'), _v(row, 'FLOW_ID'))
            stage = _v(row, 'STAGE_ID')
            stages.setdefault(key, {})[stage] = (label, row)
            if stage in RESERVED:
                problems.append(f'{label}: flow {key[1]}: stage {stage} is a reserved row of the dashboard')
            seq_key = key + (_v(row, 'SEQ'),)
            if seq_key in seqs:
                problems.append(f'{label}: flow {key[1]}: stages {seqs[seq_key]} and {stage} share sequence '
                                f'{_v(row, "SEQ")}')
            seqs[seq_key] = stage
        accounts += [(label, row) for row in rows['accounts']]
    held = {}
    expect_to = {}
    for key, by_id in stages.items():
        expect_to[key] = {_v(row, 'EXPECT_TO') for _, row in by_id.values() if _v(row, 'EXPECT_TO')}
    for label, row in accounts:
        key = (_v(row, 'AREA'), _v(row, 'FLOW_ID'))
        where = f'{label}: flow {key[1]} account {_v(row, "FLOW_ACCT")}'
        if key not in flows:
            problems.append(f'{where}: the flow is not defined')
        if label in product:
            problems.append(f'{where}: a product layer holds no account (accounts are the customer\'s)')
        role = _v(row, 'ROLE')
        if role not in ROLES:
            problems.append(f'{where}: role {role!r} is not one of {sorted(ROLES)}')
        if _v(row, 'LINE_SOURCE') not in SOURCES:
            problems.append(f'{where}: line source {_v(row, "LINE_SOURCE")!r} is not G or F')
        if _v(row, 'EVAL_CATEGORY') not in CATEGORIES:
            problems.append(f'{where}: tile category {_v(row, "EVAL_CATEGORY")!r} is not one of '
                            f'{sorted(c for c in CATEGORIES if c)}')
        held.setdefault(key, set()).add(role)
        if role != 'OUTSIDE' and role in expect_to.get(key, set()):
            slot = key + (role, _v(row, 'BUKRS'), _v(row, 'CURRENCY'))
            if slot in slots:
                problems.append(f'{where}: role {role} of {_v(row, "BUKRS")} {_v(row, "CURRENCY")} is also held by '
                                f'{slots[slot]} (one account per role, company code and currency where an expected '
                                f'counter-posting lands)')
            slots[slot] = _v(row, 'FLOW_ACCT')

    def role_problem(label, key, role, what):
        if role and role not in ROLES:
            problems.append(f'{label}: flow {key[1]} {what}: role {role!r} is not one of {sorted(ROLES)}')
        elif role and key in held and role not in held[key]:
            problems.append(f'{label}: flow {key[1]} {what}: no account holds role {role}')

    for key, by_id in stages.items():
        if key not in flows:
            problems.append(f'{by_id[next(iter(by_id))][0]}: stages of flow {key[1]}: the flow is not defined')
        for stage, (label, row) in by_id.items():
            role_problem(label, key, _v(row, 'EXPECT_FROM'), f'stage {stage}')
            role_problem(label, key, _v(row, 'EXPECT_TO'), f'stage {stage}')
            if bool(_v(row, 'EXPECT_FROM')) != bool(_v(row, 'EXPECT_TO')):
                problems.append(f'{label}: flow {key[1]} stage {stage}: EXPECT_FROM and EXPECT_TO go together')
    for label, rows in layers:
        for row in rows['tiles']:
            key = (_v(row, 'AREA'), _v(row, 'FLOW_ID'))
            where = f'tile {_v(row, "TILE")} of stage {_v(row, "STAGE_ID")}'
            if _v(row, 'TILE') not in TILES:
                problems.append(f'{label}: flow {key[1]} {where}: tile is not one of {sorted(TILES)}')
            if _v(row, 'SIDE') not in ('D', 'C'):
                problems.append(f'{label}: flow {key[1]} {where}: side {_v(row, "SIDE")!r} is not D or C')
            if _v(row, 'STAGE_ID') not in stages.get(key, {}):
                problems.append(f'{label}: flow {key[1]} {where}: the stage is not defined')
            role_problem(label, key, _v(row, 'ROLE'), where)
        for row in rows['controls']:
            key = (_v(row, 'AREA'), _v(row, 'FLOW_ID'))
            where = f'{label}: flow {key[1]} control {_v(row, "CHECK_AREA")}/{_v(row, "CHECK_ID")}'
            if _v(row, 'STAGE_ID') not in stages.get(key, {}):
                problems.append(f'{where}: stage {_v(row, "STAGE_ID")} is not defined')
            if label in product and checks is not None \
                    and (_v(row, 'CHECK_AREA'), _v(row, 'CHECK_ID')) not in checks:
                problems.append(f'{where}: the check is not a check of the product registries')
        for row in rows['rules']:
            key = (_v(row, 'AREA'), _v(row, 'FLOW_ID'))
            rule_id, source, stage = _v(row, 'RULE_ID'), _v(row, 'LINE_SOURCE'), _v(row, 'STAGE_ID')
            where = f'{label}: flow {key[1]} rule {rule_id}'
            if key not in flows:
                problems.append(f'{where}: the flow is not defined')
            seq_key = key + (_v(row, 'RULE_SEQ').zfill(4),)
            if seq_key in rule_seqs:
                problems.append(f'{where}: sequence {_v(row, "RULE_SEQ")} is also rule {rule_seqs[seq_key]} '
                                f'(first match wins must be deterministic)')
            rule_seqs[seq_key] = rule_id
            if stage != 'OTHER' and stage not in stages.get(key, {}):
                problems.append(f'{where}: stage {stage!r} is not a stage of the flow')
            if source not in SOURCES:
                problems.append(f'{where}: line source {source!r} is not G or F')
                continue
            for field in ALL_CRITERIA:
                if _v(row, field) and field not in CRITERIA[source]:
                    problems.append(f'{where}: criterion {field} does not apply to lines of source {source}')
            if _v(row, 'DEBIT_CREDIT') not in ('', 'S', 'H'):
                problems.append(f'{where}: debit / credit {_v(row, "DEBIT_CREDIT")!r} is not S or H')
            if _v(row, 'ACTIVE') == 'X' and not any(_v(row, f) for f in CRITERIA[source]):
                problems.append(f'{where}: an active rule without a criterion would hide the row OTHER')
            if label in product and not rule_id.startswith(PRODUCT_PREFIX[source]):
                problems.append(f'{where}: a product rule of source {source} starts with {PRODUCT_PREFIX[source]}')
    for label, rows in layers:
        if label not in inactive:
            continue
        for kind, items in rows.items():
            for row in items:
                if _v(row, 'ACTIVE') == 'X':
                    problems.append(f'{label}: {FILES[kind]}: row {", ".join(_v(row, k) for k in list(row)[:3])} '
                                    f'must be delivered inactive')
    for label, rows in layers:
        for kind, items in rows.items():
            for row in items:
                if len(_v(row, 'DESCRIPTION')) > 60:
                    problems.append(f'{label}: {FILES[kind]}: description longer than 60 characters: '
                                    f'{_v(row, "DESCRIPTION")[:40]}...')
    return problems


def check_ids(*paths):
    """(area, check ID) pairs of zca_ops_check.csv / check_registry.csv files."""
    out = set()
    for path in paths:
        for row in read_csv(path):
            out.add((_v(row, 'AREA'), _v(row, 'CHECK_ID')))
    return out


def check_folders(folders, product=None, inactive=None, checks=None):
    """Problems of the seed folders [(label, folder)] (product first, then overlays)."""
    return validate([(label, load(folder)) for label, folder in folders], product=product, inactive=inactive,
                    checks=checks)
