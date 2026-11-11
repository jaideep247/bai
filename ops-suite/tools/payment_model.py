#!/usr/bin/env python3
"""
Artifact: tools/payment_model.py
Purpose:  The suite's payment model (first customer of the product layer of ZCA_OPS): generates src/paym and
          config/payment_model/pending from the mapping spec config/payment_model/mapping.json with the shared
          engine ../../tools/abaptools/payment_model.py and the framework's templates
          (ops-framework/templates/payment_model). Never edit a generated file - change the spec and regenerate,
          then run tools/abapgit_serialize.py for the abapGit XML.
Usage:    python3 tools/payment_model.py           -> regenerate
          python3 tools/payment_model.py --check   -> report out-of-date files, exit 1
Modification log:
2026-11-11 | Initial version (payment model: product contract + FS-CD mapping).
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, '..', '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('payment_model', 'ops_suite')

ROOT = os.path.dirname(_HERE)
SPEC = os.path.join('config', 'payment_model', 'mapping.json')

if __name__ == '__main__':
    sys.exit(_engine.main(ROOT, SPEC, sys.argv[1:]))
