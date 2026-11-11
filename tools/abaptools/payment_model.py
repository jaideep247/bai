#!/usr/bin/env python3
"""Generator of a consumer's payment model from the product templates of the operations framework ZCA_OPS.

The product (ops-framework/templates/payment_model, framework tables ZCA_OPS_PMDIM / ZCA_OPS_FEEDER and their
CDS ZI_CA_PaymDimText / ZI_CA_PaymFeeder) defines a canonical payment-fact CONTRACT: the fields every consumer
delivers for a payment, the link payment <-> request, a request, its attempts and its timeline (hops feeder ->
middleware -> request -> payment -> status back). CDS cannot read a table name from configuration at run time,
so the customer-specific bottom layer is generated: a MAPPING SPEC (JSON in the consumer folder) names for each
contract field the source expression (table field, join path / linkage, constant or derivation) and its VERIFY
state; this generator writes

  ZI_<P>_PaymFact / _PaymReqLink / _PaymReqFact / _PaymAttempt / _PaymEvent    adapter views (from the spec)
  everything above them, from the product templates: cube, daily totals, trend, payment, link, request, attempt,
  timeline, exceptions per day (R and C views, metadata extensions with the persona cards), the DCL, the service
  definition, the CDS unit test holder class and the package

into the consumer's package folder. A section of the contract is
  "active"  - generated into the package (imported by abapGit),
  "pending" - generated into the pending folder of the spec (not imported: the code waits for a VERIFY item, e.g.
              an SE11 field name; placeholders in angle quotes stay visible), the navigation to it is left out,
  absent    - not generated; the dependent navigation is left out.
Generated files are never edited by hand: `--check` fails when one is out of date (house rule).

Spec (JSON): model {prefix, area, areas, consumer, service, package_folder, pending_folder, package_text, since,
window_days, trend_days, peak_day_min, intents {trace, exceptions, job: [semantic object, action]}},
sections payment / payment_request / request / request_attempt / request_event: {status, reason, from, joins [..],
where [..], fields {<contract field>: {expr | null, verify}}}. A field mapped null is delivered as a typed blank
(the contract type) - e.g. a dimension not yet named in SE11 - and its "verify" text goes into the view header.

Usage (from a consumer wrapper): generate(root, spec_path) / check(root, spec_path) -> list of out-of-date files.

Ledger and document-change sections (2026-11-11, optional): ledger_item (subledger items of a payment with the
subledger batch key of its clearing), ledger_batch (subledger summary records per batch key / account / currency
with the G/L reference key of the batch), recon_account (accounts of the group reconciliation), recon_result (stored
reconciliation results per business date / account - reused, never recomputed), recon_bank_line (bank statement
lines with the G/L account they reconcile against and the key of their G/L clearing line), document_event (reversal,
clearing reset, re-clearing, void, reissue of a payment's documents). The product templates add the standard
universal-journal part (the G/L documents of a batch key found by G/L reference type + key, their journal lines by
the journal's primary key in the ledger the model names). Model keys for them: ledger {area, parameter, default}
(the ledger parameter of the parameter framework) and gl_reference_type (reference type of the G/L documents of a
batch key).

Modification log:
2026-11-11 | Initial version (payment model product layer + customer mapping).
2026-11-11 | Ledger drill-down to the universal journal, batch-key level, group reconciliation, document-change events
           | (sections ledger_item, ledger_batch, recon_account, recon_result, recon_bank_line, document_event; flags
           | LEDGER, RECON, RESULT, BANK, CHANGES; composite conditions A+B in OUTPUTS / EXPOSE).
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TEMPLATES = os.path.join(REPO, 'ops-framework', 'templates', 'payment_model')

# Contract: section -> [(field, blank type, key, required)]; the order is the element order of the adapter view
CONTRACT = {
    'payment': [
        ('BusinessDate', 'abap.dats', True, True),
        ('PaymentRun', 'abap.char( 10 )', True, True),
        ('PaymentDocument', 'abap.char( 20 )', True, True),
        ('CompanyCode', 'abap.char( 4 )', False, True),
        ('CompanyCurrency', 'abap.cuky', False, False),
        ('Flow', 'abap.char( 1 )', False, True),
        ('Source', 'abap.char( 10 )', False, False),
        ('TransactionType', 'abap.char( 20 )', False, False),
        ('RequestStatus', 'abap.char( 20 )', False, False),
        ('PaymentStatus', 'abap.char( 20 )', False, True),
        ('PaymentMethod', 'abap.char( 1 )', False, True),
        ('MethodClass', 'abap.char( 3 )', False, False),
        ('HouseBank', 'abap.char( 5 )', False, False),
        ('HouseBankAccount', 'abap.char( 5 )', False, False),
        ('Outcome', 'abap.char( 20 )', False, False),
        ('Finding', 'abap.char( 30 )', False, False),
        ('IsLate', 'abap_boolean', False, False),
        ('Currency', 'abap.cuky', False, True),
        ('Amount', 'abap.curr( 23, 2 )', False, True),
    ],
    'payment_request': [
        ('PaymentDocument', 'abap.char( 20 )', True, True),
        ('RequestReference', 'abap.char( 40 )', True, True),
        ('CompanyCode', 'abap.char( 4 )', False, True),
    ],
    'request': [
        ('RequestReference', 'abap.char( 40 )', True, True),
        ('BusinessDate', 'abap.dats', False, True),
        ('ReceivedAt', 'abap.dec( 21, 7 )', False, False),
        ('CompanyCode', 'abap.char( 4 )', False, True),
        ('Source', 'abap.char( 10 )', False, True),
        ('TransactionType', 'abap.char( 20 )', False, False),
        ('FeederReference', 'abap.char( 40 )', False, False),
        ('RequestStatus', 'abap.char( 20 )', False, False),
        ('ProcessingStatus', 'abap.char( 20 )', False, False),
        ('Currency', 'abap.cuky', False, False),
        ('Amount', 'abap.curr( 23, 2 )', False, False),
    ],
    'request_attempt': [
        ('RequestReference', 'abap.char( 40 )', True, True),
        ('AttemptNumber', 'abap.numc( 10 )', True, True),
        ('CompanyCode', 'abap.char( 4 )', False, True),
        ('ProcessingStatus', 'abap.char( 20 )', False, True),
        ('ReceivedAt', 'abap.dec( 21, 7 )', False, False),
        ('IsAccepted', 'abap_boolean', False, True),
    ],
    'request_event': [
        ('RequestReference', 'abap.char( 40 )', True, True),
        ('EventSequence', 'abap.int4', True, True),
        ('CompanyCode', 'abap.char( 4 )', False, True),
        ('EventAt', 'abap.dec( 21, 7 )', False, True),
        ('Hop', 'abap.char( 12 )', False, True),
        ('EventStatus', 'abap.char( 20 )', False, False),
        ('EventReference', 'abap.char( 70 )', False, False),
    ],
    # Subledger items a payment cleared, with the batch key under which the clearing reached the G/L
    'ledger_item': [
        ('PaymentDocument', 'abap.char( 20 )', True, True),
        ('SubledgerDocument', 'abap.char( 20 )', True, True),
        ('SubledgerItem', 'abap.char( 20 )', True, True),
        ('CompanyCode', 'abap.char( 4 )', False, True),
        ('BatchKey', 'abap.char( 20 )', False, True),
        ('GlAccount', 'abap.char( 10 )', False, True),
        ('Currency', 'abap.cuky', False, True),
        ('Amount', 'abap.curr( 23, 2 )', False, True),
        ('PostingDate', 'abap.dats', False, False),
        ('MainTransaction', 'abap.char( 4 )', False, False),
        ('MainTransactionText', 'abap.char( 40 )', False, False),
        ('SubTransaction', 'abap.char( 4 )', False, False),
        ('SubTransactionText', 'abap.char( 40 )', False, False),
        ('ContractAccount', 'abap.char( 20 )', False, False),
        ('BusinessPartner', 'abap.char( 20 )', False, False),
        ('ClearingDocument', 'abap.char( 20 )', False, False),
        ('ClearingDate', 'abap.dats', False, False),
        ('ClearingReason', 'abap.char( 4 )', False, False),
        ('RequestReference', 'abap.char( 40 )', False, False),
    ],
    # Subledger summary records: one row per batch key, company code, G/L account and currency
    'ledger_batch': [
        ('BatchKey', 'abap.char( 20 )', True, True),
        ('CompanyCode', 'abap.char( 4 )', True, True),
        ('GlAccount', 'abap.char( 10 )', True, True),
        ('Currency', 'abap.cuky', True, True),
        ('GlReferenceKey', 'abap.char( 20 )', False, True),
        ('PostingDate', 'abap.dats', False, True),
        ('BatchStatus', 'abap.char( 12 )', False, False),
        ('Amount', 'abap.curr( 23, 2 )', False, True),
        ('LineCount', 'abap.int4', False, False),
    ],
    # Accounts of the group reconciliation (clearing / transit accounts)
    'recon_account': [
        ('CompanyCode', 'abap.char( 4 )', True, True),
        ('GlAccount', 'abap.char( 10 )', True, True),
        ('Currency', 'abap.cuky', True, True),
        ('AccountKind', 'abap.char( 10 )', False, False),
        ('Description', 'abap.char( 60 )', False, False),
    ],
    # Stored results of the consumer's reconciliation check per business date and account (reused, never recomputed)
    'recon_result': [
        ('BusinessDate', 'abap.dats', True, True),
        ('CompanyCode', 'abap.char( 4 )', True, True),
        ('GlAccount', 'abap.char( 10 )', True, True),
        ('Currency', 'abap.cuky', True, True),
        ('BankAmount', 'abap.dec( 31, 4 )', False, False),
        ('GlAmount', 'abap.dec( 31, 4 )', False, False),
        ('SubledgerAmount', 'abap.dec( 31, 4 )', False, False),
        ('BankGlDifference', 'abap.dec( 31, 4 )', False, False),
        ('GlSubledgerDifference', 'abap.dec( 31, 4 )', False, False),
        ('Tolerance', 'abap.dec( 31, 4 )', False, False),
        ('ResultStatus', 'abap.char( 16 )', False, True),
        ('Bucket', 'abap.char( 30 )', False, False),
        ('MeasuredAt', 'abap.dec( 21, 7 )', False, False),
    ],
    # Bank statement lines of the reconciled accounts, the subledger clearing document a line references and the key
    # of its G/L clearing line (how a line finds them is the consumer's rule)
    'recon_bank_line': [
        ('StatementKey', 'abap.char( 20 )', True, True),
        ('StatementLine', 'abap.char( 10 )', True, True),
        ('CompanyCode', 'abap.char( 4 )', False, True),
        ('GlAccount', 'abap.char( 10 )', False, True),
        ('Currency', 'abap.cuky', False, True),
        ('BookingDate', 'abap.dats', False, True),
        ('Amount', 'abap.curr( 23, 2 )', False, True),
        ('DebitCredit', 'abap.char( 1 )', False, False),
        ('HouseBank', 'abap.char( 5 )', False, False),
        ('HouseBankAccount', 'abap.char( 5 )', False, False),
        ('StatementNumber', 'abap.char( 10 )', False, False),
        ('StatementDate', 'abap.dats', False, False),
        ('TransactionCode', 'abap.char( 27 )', False, False),
        ('BankReference', 'abap.char( 35 )', False, False),
        ('ReferenceText', 'abap.char( 35 )', False, False),
        ('ValueDate', 'abap.dats', False, False),
        ('IsPostedArea1', 'abap_boolean', False, False),
        ('IsPostedArea2', 'abap_boolean', False, False),
        ('ClearingDocument', 'abap.char( 20 )', False, False),
        ('ClearingChanged', 'abap_boolean', False, False),
        ('GlFiscalYear', 'abap.numc( 4 )', False, False),
        ('GlDocument', 'abap.char( 10 )', False, False),
        ('GlLineItem', 'abap.numc( 3 )', False, False),
    ],
    # Document-change events of a payment: REVERSAL, CLEARING_RESET, RECLEARING, VOID, REISSUE (the product adds
    # GL_REVERSAL of the G/L documents of the payment's batch keys)
    'document_event': [
        ('PaymentDocument', 'abap.char( 20 )', True, True),
        ('EventType', 'abap.char( 16 )', True, True),
        ('EventDocument', 'abap.char( 20 )', True, True),
        ('CompanyCode', 'abap.char( 4 )', False, True),
        ('OriginalDocument', 'abap.char( 20 )', False, False),
        ('NewDocument', 'abap.char( 20 )', False, False),
        ('ReversalDocument', 'abap.char( 20 )', False, False),
        ('EventDate', 'abap.dats', False, True),
        ('EventTime', 'abap.tims', False, False),
        ('EventUser', 'abap.char( 12 )', False, False),
        ('Reason', 'abap.char( 4 )', False, False),
        ('EventSource', 'abap.char( 10 )', False, True),
    ],
}
ADAPTER = {'payment': 'PaymFact', 'payment_request': 'PaymReqLink', 'request': 'PaymReqFact',
           'request_attempt': 'PaymAttempt', 'request_event': 'PaymEvent', 'ledger_item': 'LedgItem',
           'ledger_batch': 'LedgBatch', 'recon_account': 'LedgAcct', 'recon_result': 'LedgRcRes',
           'recon_bank_line': 'LedgBankLn', 'document_event': 'DocEvent'}
LABEL = {'payment': 'payment fact', 'payment_request': 'payment to request link', 'request': 'payment request',
         'request_attempt': 'request attempt', 'request_event': 'request timeline',
         'ledger_item': 'subledger item of a payment', 'ledger_batch': 'subledger summary record',
         'recon_account': 'reconciled account', 'recon_result': 'stored reconciliation result',
         'recon_bank_line': 'bank statement line', 'document_event': 'document-change event'}
# Flags of the templates (#if NAME): the sections each one needs (all of them active)
FLAGS = {'LINK': ('payment_request',), 'REQUEST': ('request',), 'ATTEMPT': ('request_attempt',),
         'EVENT': ('request_event',), 'LEDGER': ('ledger_item', 'ledger_batch'),
         'RECON': ('ledger_item', 'ledger_batch', 'recon_account'),
         'RESULT': ('ledger_item', 'ledger_batch', 'recon_account', 'recon_result'),
         'BANK': ('ledger_item', 'ledger_batch', 'recon_account', 'recon_bank_line'),
         'CHANGES': ('document_event',)}
# Sections that are active only with others active: (section, needed sections)
NEEDS = (('request_attempt', ('request',)), ('request_event', ('request',)),
         ('ledger_item', ('ledger_batch',)), ('ledger_batch', ('ledger_item',)),
         ('recon_account', ('ledger_item', 'ledger_batch')), ('recon_result', ('recon_account',)),
         ('recon_bank_line', ('recon_account',)))
# Ledger parameter names and the G/L reference type are plain names (they become CDS literals)
PLAIN = re.compile(r'^[A-Z0-9_]{1,30}$')
HOPS = ('FEEDER', 'MIDDLEWARE', 'REQUEST', 'PAYMENT', 'STATUS_BACK')
STATES = ('active', 'pending', 'absent')
# Spec text must never smuggle a statement terminator or a comment into the generated CDS
UNSAFE = re.compile(r';|//|/\*|\*/|\{|\}')
NAME = re.compile(r'^[A-Z][A-Z0-9]{1,3}$')
PLACEHOLDER = re.compile('‹[^›]*›')


class SpecError(ValueError):
    """The mapping spec breaks the contract (message names the section and field)."""


def load(path):
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def state(spec, section):
    sec = spec.get(section)
    if not sec:
        return 'absent'
    value = sec.get('status', 'active')
    if value not in STATES:
        raise SpecError(f'{section}: status {value!r} is not one of {STATES}')
    return value


def validate(spec):
    """Contract checks of the spec; raises SpecError with every problem."""
    problems = []
    model = spec.get('model', {})
    for key in ('prefix', 'area', 'consumer', 'service', 'package_folder', 'pending_folder', 'since',
                'window_days', 'trend_days', 'peak_day_min', 'intents', 'areas'):
        if key not in model:
            problems.append(f'model: {key} missing')
    if model.get('prefix') and not NAME.match(model['prefix']):
        problems.append('model: prefix must be 2-4 upper-case letters / digits (object names <= 30 characters)')
    if state(spec, 'payment') != 'active':
        problems.append('payment: the payment section is required and must be active')
    for section, fields in CONTRACT.items():
        st = state(spec, section)
        if st == 'absent':
            continue
        sec = spec[section]
        if not sec.get('from'):
            problems.append(f'{section}: from missing')
        if st == 'pending' and not sec.get('reason'):
            problems.append(f'{section}: a pending section names its reason (the VERIFY item it waits for)')
        mapping = sec.get('fields', {})
        for name in mapping:
            if name not in [f[0] for f in fields]:
                problems.append(f'{section}: {name} is not a contract field')
        for name, _, key, required in fields:
            if name not in mapping:
                problems.append(f'{section}: contract field {name} not mapped (map it, or null with a verify note)')
                continue
            expr = mapping[name].get('expr')
            if expr is None and (key or required):
                problems.append(f'{section}: {name} is required and cannot be null')
            if expr is None and not mapping[name].get('verify'):
                problems.append(f'{section}: {name} is null without a verify note')
            texts = [expr or '', sec.get('from', '')] + list(sec.get('joins', [])) + list(sec.get('where', []))
            for text in texts:
                if UNSAFE.search(text):
                    problems.append(f'{section}: {text!r} contains ; // /* */ or braces')
            if st == 'active' and PLACEHOLDER.search(expr or ''):
                problems.append(f'{section}: {name} has a placeholder - the section must be pending')
        if st == 'active':
            for text in [sec.get('from', '')] + list(sec.get('joins', [])) + list(sec.get('where', [])):
                if PLACEHOLDER.search(text):
                    problems.append(f'{section}: placeholder in an active section: {text!r}')
    for dep, needed in NEEDS:
        for needs in needed:
            if state(spec, dep) == 'active' and state(spec, needs) != 'active':
                problems.append(f'{dep}: active only with an active {needs} section')
    if state(spec, 'ledger_item') != 'absent' or state(spec, 'ledger_batch') != 'absent':
        ledger = model.get('ledger', {})
        for key in ('area', 'parameter', 'default'):
            if not ledger.get(key):
                problems.append(f'model: ledger {key} missing (the ledger parameter of the journal reads)')
        if not model.get('gl_reference_type'):
            problems.append('model: gl_reference_type missing (reference type of the G/L documents of a batch key)')
        for text in [str(v) for v in ledger.values()] + [str(model.get('gl_reference_type', 'X'))]:
            if not PLAIN.match(text):
                problems.append(f'model: {text!r} is not a plain name (upper-case letters, digits, underscore)')
    if problems:
        raise SpecError('\n'.join(problems))


def _blank(cds_type):
    if cds_type == 'abap_boolean':
        return "cast( ' ' as abap_boolean )"
    if cds_type.startswith(('abap.int', 'abap.dec', 'abap.curr', 'abap.numc')):
        return f'cast( 0 as {cds_type} )'
    if cds_type == 'abap.dats':
        return "cast( '00000000' as abap.dats )"
    return f"cast( '' as {cds_type} )"


def adapter(spec, section):
    """Source of the adapter view of a section."""
    model = spec['model']
    sec = spec[section]
    p = model['prefix']
    name = f"ZI_{p}_{ADAPTER[section]}"
    lines = [f'// Artifact: {name.lower()}.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, '
             'regenerate)',
             f"// Purpose: Payment model of the {model['consumer']} - ADAPTER of the {LABEL[section]}: the contract "
             'fields of the product',
             '//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec '
             f"{model.get('spec_name', 'mapping.json')}."]
    for text in sec.get('notes', []):
        lines.append(f'//          {text}')
    lines.append(f"// Modification log: {model['since']} | Generated from the mapping spec (payment model).")
    if sec.get('status') == 'pending':
        lines.append(f"// PENDING (not imported): {sec['reason']}")
    for fname, *_ in CONTRACT[section]:
        verify = sec['fields'][fname].get('verify')
        if verify:
            lines.append(f'// {fname}: {verify}')
    lines += ['@AccessControl.authorizationCheck: #NOT_REQUIRED',
              f"@EndUserText.label: 'Payment model - adapter {LABEL[section]}'",
              '@Metadata.ignorePropagatedAnnotations: true',
              '@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }',
              f'define view entity {name}',
              f"  as select from {sec['from']}"]
    lines += [f'    {j}' for j in sec.get('joins', [])]
    lines.append('{')
    elements = []
    for fname, cds_type, key, _ in CONTRACT[section]:
        expr = sec['fields'][fname].get('expr')
        text = expr if expr is not None else _blank(cds_type)
        if fname == 'Amount':
            elements.append("      @Semantics.amount.currencyCode: 'Currency'")
        elements.append(f"{'  key ' if key else '      '}{text} as {fname}")
    for i, element in enumerate(elements):
        is_last = i == len(elements) - 1
        lines.append(element + ('' if is_last or element.lstrip().startswith('@') else ','))
    lines.append('}')
    where = sec.get('where', [])
    if where:
        lines.append('where')
        lines.append('      ' + '\n  and '.join(where))
    group = sec.get('group_by')
    if group:
        lines.append('group by')
        lines.append('  ' + ',\n  '.join(group))
    return name, '\n'.join(lines) + '\n'


def _flag_state(spec, flag):
    """active (every section active), pending (each active or pending, one pending) or absent."""
    states = [state(spec, section) for section in FLAGS[flag]]
    if all(st == 'active' for st in states):
        return 'active'
    if all(st in ('active', 'pending') for st in states):
        return 'pending'
    return 'absent'


def _flags(spec):
    return {flag: _flag_state(spec, flag) == 'active' for flag in FLAGS}


def _need_state(spec, need):
    """State of an OUTPUTS / EXPOSE condition: None (always), a flag or flags joined by '+'."""
    if need is None:
        return 'active'
    states = [_flag_state(spec, flag) for flag in need.split('+')]
    for level in ('absent', 'pending'):
        if level in states:
            return level
    return 'active'


def render(text, values, flags, loops=None):
    """#if FLAG ... [#else ...] #endif (nestable), #for NAME ... #endfor, {{KEY}} values."""
    out = []
    keep = [True]
    conds = []
    loop = None
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith('#if '):
            conds.append(flags.get(stripped[4:].strip(), False))
            keep.append(keep[-1] and conds[-1])
            continue
        if stripped == '#else':
            keep[-1] = keep[-2] and not conds[-1]
            continue
        if stripped == '#endif':
            keep.pop()
            conds.pop()
            continue
        if stripped.startswith('#for '):
            loop = (stripped[5:].strip(), [])
            continue
        if stripped == '#endfor':
            name, body = loop
            for item in (loops or {}).get(name, []):
                for body_line in body:
                    out.append(_values(body_line, {**values, **item}))
            loop = None
            continue
        if not keep[-1]:
            continue
        if loop is not None:
            loop[1].append(line)
            continue
        out.append(_values(line, values))
    return '\n'.join(out) + '\n'


def _values(line, values):
    def sub(match):
        key = match.group(1)
        if key not in values:
            raise SpecError(f'template value {key} not set')
        return str(values[key])
    return re.sub(r'\{\{(\w+)\}\}', sub, line)


def _template(name):
    with open(os.path.join(TEMPLATES, name), encoding='utf-8') as handle:
        return handle.read()


# (template, output name pattern, needed flag or None); {p} = lower prefix
OUTPUTS = [
    ('zr_paymcube.ddls.tpl', 'zr_{p}_paymcube.ddls.asddls', None),
    ('zc_paymcube.ddls.tpl', 'zc_{p}_paymcube.ddls.asddls', None),
    ('zc_paymcube.ddlx.tpl', 'zc_{p}_paymcube.ddlx.asddlxs', None),
    ('zi_paymtrendb.ddls.tpl', 'zi_{p}_paymtrendb.ddls.asddls', None),
    ('zi_paymday.ddls.tpl', 'zi_{p}_paymday.ddls.asddls', None),
    ('zr_paymtrend.ddls.tpl', 'zr_{p}_paymtrend.ddls.asddls', None),
    ('zc_paymtrend.ddls.tpl', 'zc_{p}_paymtrend.ddls.asddls', None),
    ('zc_paymtrend.ddlx.tpl', 'zc_{p}_paymtrend.ddlx.asddlxs', None),
    ('zr_payment.ddls.tpl', 'zr_{p}_payment.ddls.asddls', None),
    ('zc_payment.ddls.tpl', 'zc_{p}_payment.ddls.asddls', None),
    ('zc_payment.ddlx.tpl', 'zc_{p}_payment.ddlx.asddlxs', None),
    ('zr_paymreqlink.ddls.tpl', 'zr_{p}_paymreqlink.ddls.asddls', 'LINK'),
    ('zc_paymreqlink.ddls.tpl', 'zc_{p}_paymreqlink.ddls.asddls', 'LINK'),
    ('zc_paymreqlink.ddlx.tpl', 'zc_{p}_paymreqlink.ddlx.asddlxs', 'LINK'),
    ('zr_paymrequest.ddls.tpl', 'zr_{p}_paymrequest.ddls.asddls', 'REQUEST'),
    ('zc_paymrequest.ddls.tpl', 'zc_{p}_paymrequest.ddls.asddls', 'REQUEST'),
    ('zc_paymrequest.ddlx.tpl', 'zc_{p}_paymrequest.ddlx.asddlxs', 'REQUEST'),
    ('zr_paymattempt.ddls.tpl', 'zr_{p}_paymattempt.ddls.asddls', 'ATTEMPT'),
    ('zc_paymattempt.ddls.tpl', 'zc_{p}_paymattempt.ddls.asddls', 'ATTEMPT'),
    ('zr_paymevent.ddls.tpl', 'zr_{p}_paymevent.ddls.asddls', 'EVENT'),
    ('zc_paymevent.ddls.tpl', 'zc_{p}_paymevent.ddls.asddls', 'EVENT'),
    ('zi_paymexcrow.ddls.tpl', 'zi_{p}_paymexcrow.ddls.asddls', None),
    ('zi_paymexcday.ddls.tpl', 'zi_{p}_paymexcday.ddls.asddls', None),
    ('zr_paymexctrend.ddls.tpl', 'zr_{p}_paymexctrend.ddls.asddls', None),
    ('zc_paymexctrend.ddls.tpl', 'zc_{p}_paymexctrend.ddls.asddls', None),
    ('zi_ledgcfg.ddls.tpl', 'zi_{p}_ledgcfg.ddls.asddls', 'LEDGER'),
    ('zi_ledgjrnl.ddls.tpl', 'zi_{p}_ledgjrnl.ddls.asddls', 'LEDGER'),
    ('zr_ledgjrnl.ddls.tpl', 'zr_{p}_ledgjrnl.ddls.asddls', 'LEDGER'),
    ('zc_ledgjrnl.ddls.tpl', 'zc_{p}_ledgjrnl.ddls.asddls', 'LEDGER'),
    ('zc_ledgjrnl.ddlx.tpl', 'zc_{p}_ledgjrnl.ddlx.asddlxs', 'LEDGER'),
    ('zi_ledggldoc.ddls.tpl', 'zi_{p}_ledggldoc.ddls.asddls', 'LEDGER'),
    ('zi_ledgglkey.ddls.tpl', 'zi_{p}_ledgglkey.ddls.asddls', 'LEDGER'),
    ('zi_ledggltot.ddls.tpl', 'zi_{p}_ledggltot.ddls.asddls', 'LEDGER'),
    ('zr_ledgbatch.ddls.tpl', 'zr_{p}_ledgbatch.ddls.asddls', 'LEDGER'),
    ('zc_ledgbatch.ddls.tpl', 'zc_{p}_ledgbatch.ddls.asddls', 'LEDGER'),
    ('zc_ledgbatch.ddlx.tpl', 'zc_{p}_ledgbatch.ddlx.asddlxs', 'LEDGER'),
    ('zr_ledgitem.ddls.tpl', 'zr_{p}_ledgitem.ddls.asddls', 'LEDGER'),
    ('zc_ledgitem.ddls.tpl', 'zc_{p}_ledgitem.ddls.asddls', 'LEDGER'),
    ('zc_ledgitem.ddlx.tpl', 'zc_{p}_ledgitem.ddlx.asddlxs', 'LEDGER'),
    ('zi_ledgpaysum.ddls.tpl', 'zi_{p}_ledgpaysum.ddls.asddls', 'LEDGER'),
    ('zi_ledgpaybat.ddls.tpl', 'zi_{p}_ledgpaybat.ddls.asddls', 'LEDGER'),
    ('zr_paymledger.ddls.tpl', 'zr_{p}_paymledger.ddls.asddls', 'LEDGER'),
    ('zc_paymledger.ddls.tpl', 'zc_{p}_paymledger.ddls.asddls', 'LEDGER'),
    ('zc_paymledger.ddlx.tpl', 'zc_{p}_paymledger.ddlx.asddlxs', 'LEDGER'),
    ('zi_ledgacctday.ddls.tpl', 'zi_{p}_ledgacctday.ddls.asddls', 'RECON'),
    ('zi_ledgsubday.ddls.tpl', 'zi_{p}_ledgsubday.ddls.asddls', 'RECON'),
    ('zi_ledgbankday.ddls.tpl', 'zi_{p}_ledgbankday.ddls.asddls', 'BANK'),
    ('zi_ledgrckey.ddls.tpl', 'zi_{p}_ledgrckey.ddls.asddls', 'RECON'),
    ('zr_ledgrecon.ddls.tpl', 'zr_{p}_ledgrecon.ddls.asddls', 'RECON'),
    ('zc_ledgrecon.ddls.tpl', 'zc_{p}_ledgrecon.ddls.asddls', 'RECON'),
    ('zc_ledgrecon.ddlx.tpl', 'zc_{p}_ledgrecon.ddlx.asddlxs', 'RECON'),
    ('zi_ledgrccube.ddls.tpl', 'zi_{p}_ledgrccube.ddls.asddls', 'RECON'),
    ('zc_ledgrcqry.ddls.tpl', 'zc_{p}_ledgrcqry.ddls.asddls', 'RECON'),
    ('zr_ledgbankln.ddls.tpl', 'zr_{p}_ledgbankln.ddls.asddls', 'BANK'),
    ('zc_ledgbankln.ddls.tpl', 'zc_{p}_ledgbankln.ddls.asddls', 'BANK'),
    ('zc_ledgbankln.ddlx.tpl', 'zc_{p}_ledgbankln.ddlx.asddlxs', 'BANK'),
    ('zi_docevtall.ddls.tpl', 'zi_{p}_docevtall.ddls.asddls', 'CHANGES'),
    ('zr_paymchange.ddls.tpl', 'zr_{p}_paymchange.ddls.asddls', 'CHANGES'),
    ('zc_paymchange.ddls.tpl', 'zc_{p}_paymchange.ddls.asddls', 'CHANGES'),
    ('zc_paymchange.ddlx.tpl', 'zc_{p}_paymchange.ddlx.asddlxs', 'CHANGES'),
    ('zr_reqchange.ddls.tpl', 'zr_{p}_reqchange.ddls.asddls', 'REQUEST+CHANGES'),
    ('zc_reqchange.ddls.tpl', 'zc_{p}_reqchange.ddls.asddls', 'REQUEST+CHANGES'),
    ('zr_docevtcube.ddls.tpl', 'zr_{p}_docevtcube.ddls.asddls', 'CHANGES'),
    ('zc_docevtcube.ddls.tpl', 'zc_{p}_docevtcube.ddls.asddls', 'CHANGES'),
    ('zc_docevtcube.ddlx.tpl', 'zc_{p}_docevtcube.ddlx.asddlxs', 'CHANGES'),
    ('zcl_paym_cds_test.clas.tpl', 'zcl_{p}_paym_cds_test.clas.abap', None),
    ('zcl_paym_cds_test.testclasses.tpl', 'zcl_{p}_paym_cds_test.clas.testclasses.abap', None),
]
# Service entities: (C view name part, entity set alias, needed flag)
EXPOSE = [('PaymCube', 'PaymentCategory', None), ('PaymTrend', 'PaymentTrend', None),
          ('Payment', 'Payment', None), ('PaymReqLink', 'PaymentRequestLink', 'LINK'),
          ('PaymRequest', 'PaymentRequest', 'REQUEST'), ('PaymAttempt', 'PaymentRequestAttempt', 'ATTEMPT'),
          ('PaymEvent', 'PaymentRequestEvent', 'EVENT'), ('PaymExcTrend', 'ExceptionTrend', None),
          ('PaymLedger', 'PaymentLedger', 'LEDGER'), ('LedgBatch', 'SubledgerBatch', 'LEDGER'),
          ('LedgItem', 'SubledgerItem', 'LEDGER'), ('LedgJrnl', 'JournalLine', 'LEDGER'),
          ('LedgRecon', 'LedgerReconciliation', 'RECON'), ('LedgBankLn', 'BankStatementLine', 'BANK'),
          ('PaymChange', 'PaymentChange', 'CHANGES'), ('ReqChange', 'RequestChange', 'REQUEST+CHANGES'),
          ('DocEvtCube', 'DocumentChangeCategory', 'CHANGES')]


def values(spec):
    model = spec['model']
    p = model['prefix']
    intents = model['intents']
    areas = model['areas']
    return {
        'P': p, 'p': p.lower(), 'AREA': model['area'], 'CONSUMER': model['consumer'],
        'SERVICE': model['service'], 'SERVICE_LOWER': model['service'].lower(), 'SINCE': model['since'],
        'WINDOW': model['window_days'], 'WINDOW_SECONDS': -int(model['window_days']) * 86400,
        'TREND': model['trend_days'], 'PEAK': model['peak_day_min'],
        'AREA_LIST': ', '.join(areas),
        'AREA_FILTER': ' or '.join(f"Fnd.area = '{a}'" for a in areas),
        'TRACE_SO': intents['trace'][0], 'TRACE_ACTION': intents['trace'][1],
        'EXC_SO': intents['exceptions'][0], 'EXC_ACTION': intents['exceptions'][1],
        'JOB_SO': intents['job'][0], 'JOB_ACTION': intents['job'][1],
        'LEDGER_AREA': model.get('ledger', {}).get('area', ''),
        'LEDGER_PARAM': model.get('ledger', {}).get('parameter', ''),
        'LEDGER_DEFAULT': model.get('ledger', {}).get('default', ''),
        'GL_REFTYPE': model.get('gl_reference_type', ''),
    }


def outputs(root, spec):
    """{relative path: content} of every generated file (package and pending folder)."""
    validate(spec)
    model = spec['model']
    vals = values(spec)
    flags = _flags(spec)
    pkg = model['package_folder']
    pending = model['pending_folder']
    files = {}
    for section in CONTRACT:
        st = state(spec, section)
        if st == 'absent':
            continue
        name, text = adapter(spec, section)
        folder = pkg if st == 'active' else pending
        files[os.path.join(folder, name.lower() + '.ddls.asddls')] = text
    for template, pattern, need in OUTPUTS:
        out = pattern.format(p=vals['p'])
        st = _need_state(spec, need)
        if st == 'active':
            files[os.path.join(pkg, out)] = render(_template(template), vals, flags)
        elif st == 'pending':
            # the code of a pending section is generated as if it were active, for review
            forced = {**flags, **{flag: True for flag in need.split('+')}}
            files[os.path.join(pending, out)] = render(_template(template), vals, forced)
    exposed = [e for e in EXPOSE if _need_state(spec, e[2]) == 'active']
    loops = {'EXPOSE': [{'ENTITY': f"ZC_{vals['P']}_{e[0]}", 'ALIAS': e[1]} for e in exposed],
             'ENTITY': [{'ENTITY': f"ZC_{vals['P']}_{e[0]}"} for e in exposed]}
    files[os.path.join(pkg, f"zc_{vals['p']}_paym.dcls.asdcls")] = render(_template('zc_paym.dcls.tpl'), vals, flags, loops)
    files[os.path.join(pkg, f"{vals['SERVICE_LOWER']}.srvd.srvdsrv")] = render(_template('zui_paym.srvd.tpl'), vals,
                                                                              flags, loops)
    files[os.path.join(pkg, 'package.devc.xml')] = PACKAGE.format(text=model.get('package_text', 'Payment model'))
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


def _read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def _generated(root, spec):
    """Files of the package / pending folder written by an earlier run (to remove what no longer belongs)."""
    model = spec['model']
    found = set()
    for folder in (model['package_folder'], model['pending_folder']):
        path = os.path.join(root, folder)
        if not os.path.isdir(path):
            continue
        for name in os.listdir(path):
            if name.endswith(('.asddls', '.asddlxs', '.asdcls', '.srvdsrv', '.abap')) or name == 'package.devc.xml':
                found.add(os.path.join(folder, name))
    return found


def generate(root, spec_path):
    """Write the generated files; returns (written, removed) relative paths."""
    spec = load(os.path.join(root, spec_path))
    spec['model'].setdefault('spec_name', spec_path)
    files = outputs(root, spec)
    written = []
    for rel, text in sorted(files.items()):
        path = os.path.join(root, rel)
        if _read(path) != text:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8') as handle:
                handle.write(text)
            written.append(rel)
    removed = []
    for rel in sorted(_generated(root, spec) - set(files)):
        os.remove(os.path.join(root, rel))
        xml = os.path.join(root, re.sub(r'\.(asddls|asddlxs|asdcls|srvdsrv)$', '.xml', rel))
        if xml != os.path.join(root, rel) and os.path.exists(xml):
            os.remove(xml)
        removed.append(rel)
    return written, removed


def check(root, spec_path):
    """Out-of-date or superfluous generated files (empty = up to date)."""
    spec = load(os.path.join(root, spec_path))
    spec['model'].setdefault('spec_name', spec_path)
    files = outputs(root, spec)
    stale = []
    for rel, text in sorted(files.items()):
        path = os.path.join(root, rel)
        if _read(path) != text:
            stale.append(rel)
    stale += sorted(_generated(root, spec) - set(files))
    return stale


def main(root, spec_path, argv):
    if '--check' in argv:
        stale = check(root, spec_path)
        if stale:
            print('Payment model out of date (run tools/payment_model.py):')
            for rel in stale:
                print('  ' + rel)
            return 1
        print('payment model up to date')
        return 0
    written, removed = generate(root, spec_path)
    print(f'{len(written)} file(s) written, {len(removed)} removed')
    return 0
