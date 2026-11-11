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

Modification log:
2026-11-11 | Initial version (payment model product layer + customer mapping).
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
}
ADAPTER = {'payment': 'PaymFact', 'payment_request': 'PaymReqLink', 'request': 'PaymReqFact',
           'request_attempt': 'PaymAttempt', 'request_event': 'PaymEvent'}
LABEL = {'payment': 'payment fact', 'payment_request': 'payment to request link', 'request': 'payment request',
         'request_attempt': 'request attempt', 'request_event': 'request timeline'}
# Flags of the templates (#if NAME): which section each one needs
FLAGS = {'LINK': 'payment_request', 'REQUEST': 'request', 'ATTEMPT': 'request_attempt', 'EVENT': 'request_event'}
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
    for dep, needs in (('request_attempt', 'request'), ('request_event', 'request')):
        if state(spec, dep) == 'active' and state(spec, needs) != 'active':
            problems.append(f'{dep}: active only with an active {needs} section')
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


def _flags(spec):
    return {flag: state(spec, section) == 'active' for flag, section in FLAGS.items()}


def render(text, values, flags, loops=None):
    """#if FLAG ... #endif (nesting not needed), #for NAME ... #endfor, {{KEY}} values."""
    out = []
    keep = [True]
    loop = None
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith('#if '):
            keep.append(keep[-1] and flags.get(stripped[4:].strip(), False))
            continue
        if stripped == '#endif':
            keep.pop()
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
    ('zcl_paym_cds_test.clas.tpl', 'zcl_{p}_paym_cds_test.clas.abap', None),
    ('zcl_paym_cds_test.testclasses.tpl', 'zcl_{p}_paym_cds_test.clas.testclasses.abap', None),
]
# Service entities: (C view name part, entity set alias, needed flag)
EXPOSE = [('PaymCube', 'PaymentCategory', None), ('PaymTrend', 'PaymentTrend', None),
          ('Payment', 'Payment', None), ('PaymReqLink', 'PaymentRequestLink', 'LINK'),
          ('PaymRequest', 'PaymentRequest', 'REQUEST'), ('PaymAttempt', 'PaymentRequestAttempt', 'ATTEMPT'),
          ('PaymEvent', 'PaymentRequestEvent', 'EVENT'), ('PaymExcTrend', 'ExceptionTrend', None)]


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
    for template, pattern, flag in OUTPUTS:
        out = pattern.format(p=vals['p'])
        text = render(_template(template), vals, flags)
        if flag is None or flags[flag]:
            files[os.path.join(pkg, out)] = text
        elif state(spec, FLAGS[flag]) == 'pending':
            # the code of a pending section is generated as if it were active, for review
            files[os.path.join(pending, out)] = render(_template(template), vals, {**flags, flag: True})
    exposed = [e for e in EXPOSE if e[2] is None or flags[e[2]]]
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
