#!/usr/bin/env python3
"""House checks of the operations framework ZCA_OPS that abaplint does not cover.

The common checks are the shared ones (../../tools/abaptools/checks.py, described there); this
file holds the framework's list and its own checks: messages used and defined, the seed class of
the parameters, layering (no reference to a consumer), customer wording and packaging.

Offline evidence of house-rule compliance only - not SAP activation, ATC or ABAP Unit.
Usage:  python3 tools/checks.py          (exit 1 when a check fails)

Checks
  name_lengths        SAP length limits (abapGit file names, declarations, DDL fields)
  method_names        methods snake_case, no data prefix, <= 30
  artifact_header     every ABAP source starts with '*& Artifact: <file name>' and has
                      Purpose and Modification log lines
  pcre_only           no POSIX regular expressions (regex =, FIND/REPLACE ... REGEX, CREATE_POSIX)
  no_cp_patterns      no CP / NP comparisons and no option 'CP' / 'NP'
  no_inline_texts     no user text as a literal in production code: MESSAGE with a text literal, or a
                      sentence-like literal outside declarations (test data of test includes allowed)
  no_select_star      explicit field lists in every SELECT
  final_classes       every public concrete class is FINAL
  test_classes        every test class has RISK LEVEL HARMLESS and DURATION SHORT
  messages            every ZCA_OPS message number the code raises or names (MESSAGE eNNN(zca_ops), gc_msg
                      constants of the types interfaces) has a row in config/zca_ops_messages.md, every
                      row is used by production code (000, the free-text message, excepted); texts <= 73
  abapgit_up_to_date  tools/abapgit_serialize.py --check (generated XML equals the sources)
  test_path           every class has a test include or a row in tools/test_path_register.csv
                      (covered by a test include that names it, or exempt with a reason)
  param_definitions   tools/param_definitions.py: definitions of area CA_OPS complete, seed class generated
  layering            no reference to a consumer object (the object prefixes of config/customer_terms.txt,
                      flag prefix) in src/
                      (the optional demo sub-package src/demo included) - only the modification log
                      line "Moved from ..." may name the former object
  customer_terms      none of the words of config/customer_terms.txt (whole words, case ignored, unless
                      the term's flags say otherwise) in any text file of the framework - src/, ddic/,
                      docs/, templates/, config/, tools/ (test fixtures excepted), README, CHANGELOG -
                      or of the shared tools tools/abaptools; single lines allowed by
                      config/customer_terms_allowed.txt (each with its reason, unused entries fail)
  packaging           self-contained: no file names a consumer's folder (Python imports, abaplint
                      dependency paths, document links); the parameter framework and the shared tools
                      are allowed; the change log may name where the framework came from
  process_onboarding  every registered business process of config/ (process_register.csv) is integrated
                      end to end: checks, control, alert rule, ownership, purge, authorisation; no active
                      row with a placeholder (shared engine tools/abaptools/onboarding.py)
  link_registry       the product layers of the link registry (config/links) and the worked example of a
                      customer overlay are valid and the generated seed rows, lineage, CDS snippets and impact
                      report are up to date (tools/link_registry.py, shared engine tools/abaptools/link_registry.py)
  process_catalogue   the product packages of the process catalogue (config/catalogue) and the worked example of a
                      customer layer are valid and the generated seed rows, monitoring rows and catalogue document are
                      up to date (tools/process_catalogue.py, shared engine tools/abaptools/process_catalogue.py)

Modification log:
2026-11-10 | Copied from the parameter framework's checks and extended for the framework.
2026-11-10 | Common checks from the shared tools (tools/abaptools/checks.py); method names and
           | packaging checks added.
2026-11-10 | process_onboarding (process onboarding framework: offline completeness of registered processes).
2026-11-11 | link_registry (link registry: product layers valid, generated outputs up to date).
2026-11-11 | process_catalogue (process catalogue: product packages valid, generated outputs up to date).
2026-11-11 | customer_terms reads every text file of the framework and the shared tools, with an allowlist
           | (customer-neutral product: customer names only in a consumer); layering takes the consumers'
           | object prefixes from config/customer_terms.txt instead of a list in this file.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
from abaptools import checks as _shared  # noqa: E402
from abaptools import onboarding as _onboarding  # noqa: E402
from abaptools.checks import (files, read, strip_comments, statements, check_test_path,  # noqa: E402,F401
                              check_name_lengths, check_method_names, check_artifact_header, check_pcre_only,
                              check_no_cp, check_no_select_star, check_final, check_test_classes)

DECLARATION = re.compile(r'^\s*(CONSTANTS|TYPES|DATA|CLASS-DATA|STATICS)\b', re.I)
LITERAL = re.compile(r"'(?:[^'\n]|'')*'|`(?:[^`\n]|``)*`")
WORDS = re.compile(r'[A-Za-z]{2,} +[A-Za-z]{2,}')


def check_no_inline_texts(root):
    """Production code only: test data of a test include is no user text (as in the suite's literal scan)."""
    failures = []
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        base = os.path.basename(path)
        if '.testclasses.' in base:
            continue
        for stmt in statements(strip_comments(read(path))):
            if re.search(r"\bMESSAGE\s+['`]", stmt, re.I):
                failures.append(f'{base}: MESSAGE with a text literal')
                continue
            if DECLARATION.match(stmt):
                continue
            for m in LITERAL.finditer(stmt):
                if WORDS.search(m.group(0)[1:-1]):
                    failures.append(f'{base}: {m.group(0)[:60]}')
    return failures


MSG_ROW = re.compile(r'^\| (\d{3}) \| (.*?) \|$', re.M)
RAISED = re.compile(r'\b[EWISAX](\d{3})\(zca_ops\)', re.I)
CONST = re.compile(r"(\w+)\s+TYPE\s+\S+\s+VALUE\s+'(\d{3})'", re.I)


def message_rows(root):
    return MSG_ROW.findall(read(_shared.message_source(root)))


def message_constants(root):
    """(file, name, number) of every gc_msg constant of the framework's types interfaces."""
    out = []
    for path in files(os.path.join(root, 'src'), ('types.intf.abap',)):
        block = re.search(r'BEGIN OF gc_msg,(.*?)END OF gc_msg', strip_comments(read(path)), re.S | re.I)
        if block:
            out += [(os.path.basename(path), n, nr) for n, nr in CONST.findall(block.group(1))]
    return out


def check_messages(root):
    rows = message_rows(root)
    defined = {nr for nr, _ in rows}
    failures = [f'message {nr}: text longer than 73' for nr, text in rows if len(text) > 73]
    used = set()
    production = ''
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        code = strip_comments(read(path))
        for nr in RAISED.findall(code):
            if nr not in defined:
                failures.append(f'{os.path.basename(path)}: message {nr} of ZCA_OPS is not defined')
        if '.testclasses.' not in path and not path.endswith('types.intf.abap'):
            production += code + '\n'
            used |= set(RAISED.findall(code))
    for base, name, nr in message_constants(root):
        if nr not in defined:
            failures.append(f'{base}: gc_msg-{name} = {nr} is not a message of ZCA_OPS')
        if re.search(r'gc_msg-' + name + r'\b', production, re.I):
            used.add(nr)
    for nr in sorted(defined - used - {'000'}):
        failures.append(f'message {nr}: raised by no production code')
    return failures


def check_abapgit(root):
    sys.path.insert(0, os.path.join(root, 'tools'))
    import abapgit_serialize  # noqa: E402
    stage, _ = abapgit_serialize.build(root)
    return list(stage.problems) + [f'{f}: out of date (run tools/abapgit_serialize.py)' for f in stage.changed()]


def check_param_definitions(root):
    sys.path.insert(0, os.path.join(root, 'tools'))
    import param_definitions  # noqa: E402
    return param_definitions.failures(root)


MOVED_LINE = re.compile(r'^\*& \d{4}-\d{2}-\d{2} \| Moved from Z\w+ to the reusable framework ZCA_OPS')


def consumer_pattern(root):
    """Objects of a consumer: a word that starts with an object prefix of config/customer_terms.txt (flag
    prefix) - the consumers' prefixes are configuration, not code of the framework."""
    prefixes = [term for term, flags in _shared.term_rules(root) if 'prefix' in flags]
    return re.compile(r'\b(' + '|'.join(re.escape(p) + r'\w*' for p in prefixes) + ')', re.I) if prefixes else None


def check_layering(root):
    pattern = consumer_pattern(root)
    return _shared.check_references(root, pattern, MOVED_LINE) if pattern else []


# customer_terms: the whole framework and the shared tools (test fixtures excepted, see TERM_SKIP_DIRS)
TERM_SCOPES = ('.', os.path.join('..', 'tools', 'abaptools'))
TERM_ALLOWLIST = 'config/customer_terms_allowed.txt'


def check_customer_terms(root):
    return _shared.check_customer_terms(root, MOVED_LINE, TERM_SCOPES, TERM_ALLOWLIST)


def check_packaging(root):
    return _shared.check_packaging(root, ('ops-suite',))  # packaging: forbidden folders


def check_process_onboarding(root):
    return _onboarding.failures(root, auth_docs=('docs/auth_zca_ops.md',), source_roots=('src',))


def check_link_registry(root):
    sys.path.insert(0, os.path.join(root, 'tools'))
    import link_registry  # noqa: E402
    return link_registry._engine.check(root, link_registry.PROFILE)



def check_process_catalogue(root):
    sys.path.insert(0, os.path.join(root, 'tools'))
    import process_catalogue  # noqa: E402
    return process_catalogue._engine.check(root, process_catalogue.PROFILE)


CHECKS = [
    ('name_lengths', check_name_lengths),
    ('method_names', check_method_names),
    ('artifact_header', check_artifact_header),
    ('pcre_only', check_pcre_only),
    ('no_cp_patterns', check_no_cp),
    ('no_inline_texts', check_no_inline_texts),
    ('no_select_star', check_no_select_star),
    ('final_classes', check_final),
    ('test_classes', check_test_classes),
    ('messages', check_messages),
    ('abapgit_up_to_date', check_abapgit),
    ('test_path', check_test_path),
    ('param_definitions', check_param_definitions),
    ('layering', check_layering),
    ('customer_terms', check_customer_terms),
    ('packaging', check_packaging),
    ('process_onboarding', check_process_onboarding),
    ('link_registry', check_link_registry),
    ('process_catalogue', check_process_catalogue),
]


def run(root=ROOT):
    return _shared.run(CHECKS, root)


def main():
    return _shared.report(run())


if __name__ == '__main__':
    sys.exit(main())
