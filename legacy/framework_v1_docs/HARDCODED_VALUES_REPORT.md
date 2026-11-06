# Hardcoded Values Report - Complete Framework Review

## Summary

Comprehensive check for hardcoded values across all classes.

---

## Class: `zcl_cd_bank_val_msg_formatter`

### Hardcoded Values Found:

1. **Message ID** (3 occurrences):
   - Line 19: `DEFAULT 'ZMC_BANK_VALIDATION'`
   - Line 31: `DEFAULT 'ZMC_BANK_VALIDATION'`
   - Line 42: `DEFAULT 'ZMC_BANK_VALIDATION'`
   - **Fix**: Use `zcl_cd_bank_val_constants=>gc_message-msgid_bank_validation`

2. **Message Numbers** (many in CASE statements):
   - Lines 207-259: `'001'`, `'003'`, `'005'`, `'006'`, `'007'`, `'008'`, `'009'`, `'011'`, `'012'`, `'013'`, `'015'`, `'017'`, `'018'`, `'019'`
   - Lines 268-287: `'001'`, `'002'`, `'003'`, `'005'`, `'006'`, `'007'`, `'008'`, `'009'`, `'010'`, `'011'`, `'012'`, `'013'`, `'014'`, `'015'`, `'016'`, `'017'`, `'018'`, `'019'`, `'020'`, `'021'`, `'022'`, `'023'`
   - **Fix**: Use `zcl_cd_bank_val_constants=>gc_message_no-msg_001_*`, etc.
   - **Note**: ABAP CASE statements accept constants, so this is feasible

3. **Audience Types** (5 occurrences):
   - Line 25: `DEFAULT 'BOTH'`
   - Line 110: `WHEN 'BUSINESS'`
   - Line 114: `WHEN 'TECHNICAL'`
   - Line 143: `iv_audience = 'BUSINESS'`
   - Line 156: `iv_audience = 'TECHNICAL'`
   - **Status**: Need to add constants OR these may be acceptable as parameter values
   - **Decision**: These are method parameter values - may be acceptable as-is, but for consistency should use constants

4. **Severity Levels** (4 occurrences):
   - Line 269: `rv_severity = 'ERROR'`
   - Line 272: `rv_severity = 'INFO'`
   - Line 275: `rv_severity = 'WARNING'`
   - Line 281: `rv_severity = 'CRITICAL'`
   - **Status**: Need to add constants for severity levels
   - **Note**: These are different from message types (E, W, I, S, A)

5. **Parse Markers** (2 occurrences):
   - Line 172: `'Business:'`
   - Line 175: `'Technical:'`
   - **Status**: These are parsing delimiters - acceptable as-is

---

## Action Items

### Immediate Fixes:
1. ✅ Replace message ID with constant (3 occurrences)
2. ⚠️ Replace message numbers with constants (many occurrences) - Need to verify CASE syntax
3. ⚠️ Add constants for severity levels if missing
4. ⚠️ Consider adding constants for audience types

### Decisions Needed:
- Should audience types ('BUSINESS', 'TECHNICAL', 'BOTH') be constants?
- Should severity levels ('ERROR', 'INFO', 'WARNING', 'CRITICAL') be constants? (Different from message types)

---

## Next Steps

1. Fix message ID hardcoded values
2. Check if constants exist for severity levels, add if missing
3. Replace message numbers with constants
4. Decide on audience types (may be acceptable as-is)
5. Check all other classes
