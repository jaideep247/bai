#!/usr/bin/env python3
"""Name checks of the ops suite (portable, no SAP system): SAP length limits, the house method
naming rule, PCRE only, no CP / NP patterns and no inline declaration in IMPORTING of a functional
call. Used by tools/portable_checks.py (checks name_lengths, method_names, pcre_only, no_cp_patterns,
no_inline_in_call).

Wrapper of the shared engine ../../tools/abaptools/name_checks.py (limits and rules described
there; tests in ../../tools/tests); the same checks run in both frameworks.

Modification log:
2026-11-10 | The engine moved to the shared tools (tools/abaptools); this file is the wrapper.
2026-11-16 | inline_in_call_failures (house rule no_inline_in_call).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'tools'))
from abaptools.name_checks import (name_length_failures, method_name_failures,  # noqa: E402,F401
                                   posix_regex_failures, cp_pattern_failures, inline_in_call_failures)
