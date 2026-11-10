#!/usr/bin/env python3
"""House checks of the parameter framework that abaplint does not cover.

Offline evidence of house-rule compliance only - not SAP activation, ATC or ABAP Unit.
Usage:  python3 tools/checks.py          (exit 1 when a check fails)

The common checks are the shared ones (../../tools/abaptools/checks.py, described there); this
file holds the framework's list and its own checks.

Checks
  name_lengths        SAP length limits (abapGit file names, declarations, DDL fields)
  method_names        methods snake_case, no data prefix, <= 30
  artifact_header     every ABAP source starts with '*& Artifact: <file name>' and has
                      Purpose and Modification log lines
  pcre_only           no POSIX regular expressions (regex =, FIND/REPLACE ... REGEX, CREATE_POSIX)
  no_cp_patterns      no CP / NP comparisons and no option 'CP' / 'NP'
  no_inline_texts     no user text as a literal: MESSAGE with a text literal, or a sentence-like
                      literal outside declarations (test classes may use literals in msg = )
  no_select_star      explicit field lists in every SELECT
  final_classes       every public concrete class is FINAL
  test_classes        every test class has RISK LEVEL HARMLESS and DURATION SHORT
  messages            every ZIF_CA_PARAM_TYPES=>GC_MSG constant has a message row with the same
                      number and name; texts <= 73
  abapgit_up_to_date  tools/abapgit_serialize.py --check (generated XML equals the sources)
  customer_terms      none of the words of config/customer_terms.txt in src/, the message texts or the
                      text elements (whole words, case ignored)
  packaging           self-contained: no file names the operations framework's or a consumer's
                      folder (the framework is the base layer; the change log may name them)

Modification log:
2026-11-10 | Common checks from the shared tools (tools/abaptools/checks.py); method names, abapGit
           | metadata, customer wording and packaging checks added.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
from abaptools import checks as _shared  # noqa: E402
from abaptools.checks import (files, read, strip_comments, statements,  # noqa: E402,F401
                              check_name_lengths, check_method_names, check_artifact_header, check_pcre_only,
                              check_no_cp, check_no_select_star, check_final, check_test_classes,
                              check_customer_terms)

DECLARATION = re.compile(r'^\s*(CONSTANTS|TYPES|DATA|CLASS-DATA|STATICS)\b', re.I)
SENTENCE = re.compile(r"'([^'\n]*[A-Za-z]{2,}\s+[A-Za-z]{2,}[^'\n]*)'|`([^`\n]*[A-Za-z]{2,}\s+[A-Za-z]{2,}[^`\n]*)`")


def check_no_inline_texts(root):
    failures = []
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        base = os.path.basename(path)
        test = '.testclasses.' in base
        for stmt in statements(strip_comments(read(path))):
            if re.search(r"\bMESSAGE\s+['`]", stmt, re.I):
                failures.append(f'{base}: MESSAGE with a text literal')
                continue
            if DECLARATION.match(stmt):
                continue
            for m in SENTENCE.finditer(stmt):
                prefix = stmt[:m.start()]
                if test and re.search(r'\b(msg|quit)\s*=\s*$', prefix, re.I):
                    continue
                failures.append(f'{base}: {m.group(0)[:60]}')
    return failures


def check_messages(root):
    rows = re.findall(r'^\| (\d{3}) \| (\w+) \| (.*?) \|$', read(_shared.message_source(root)), re.M)
    by_name = {name: nr for nr, name, _ in rows}
    failures = [f'message {nr}: text longer than 73' for nr, _, text in rows if len(text) > 73]
    types = os.path.join(root, 'src', 'zif_ca_param_types.intf.abap')
    if not os.path.exists(types):
        return failures
    block = re.search(r'BEGIN OF gc_msg,(.*?)END OF gc_msg', read(types), re.S | re.I)
    if not block:
        return failures + ['ZIF_CA_PARAM_TYPES: constant structure gc_msg missing']
    for name, nr in re.findall(r'(\w+)\s+TYPE\s+symsgno\s+VALUE\s+\'(\d{3})\'', block.group(1), re.I):
        if by_name.get(name.lower()) != nr:
            failures.append(f'gc_msg-{name} = {nr}: no message row "| {nr} | {name.lower()} |"')
    return failures


def check_abapgit(root):
    sys.path.insert(0, os.path.join(root, 'tools'))
    import abapgit_serialize  # noqa: E402
    stage, _ = abapgit_serialize.build(root)
    return list(stage.problems) + [f'{f}: out of date (run tools/abapgit_serialize.py)' for f in stage.changed()]


def check_packaging(root):
    return _shared.check_packaging(root, ('ops-framework', 'ops-suite'))  # packaging: forbidden folders


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
    ('customer_terms', check_customer_terms),
    ('packaging', check_packaging),
]


def run(root=ROOT):
    return _shared.run(CHECKS, root)


def main():
    return _shared.report(run())


if __name__ == '__main__':
    sys.exit(main())
