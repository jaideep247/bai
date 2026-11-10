#!/usr/bin/env python3
"""Name checks of the ops suite (portable, no SAP system): SAP length limits, the house method
naming rule, PCRE only and no CP / NP patterns. Used by tools/portable_checks.py (checks
name_lengths, method_names, pcre_only, no_cp_patterns).

Wrapper of the shared engine ../../tools/abaptools/name_checks.py (limits and rules described
there; tests in ../../tools/tests); the same checks run in both frameworks.

Modification log:
2026-11-10 | The engine moved to the shared tools (tools/abaptools); this file is the wrapper.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'tools'))
from abaptools.name_checks import (name_length_failures, method_name_failures,  # noqa: E402,F401
                                   posix_regex_failures, cp_pattern_failures)
