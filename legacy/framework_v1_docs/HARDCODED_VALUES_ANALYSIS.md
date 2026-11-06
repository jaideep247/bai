# Hardcoded Values Analysis - Complete Framework Review

## Status: **IN PROGRESS**

Checking all classes for hardcoded values that should use constants.

---

## Findings in `zcl_cd_bank_val_msg_formatter`

### Critical Hardcoded Values Found:

1. **Message ID**: `'ZMC_BANK_VALIDATION'` (Lines 19, 31, 42)
   - Should use: `zcl_cd_bank_val_constants=>gc_message-msgid_bank_validation`
   
2. **Audience Types**: `'BUSINESS'`, `'TECHNICAL'`, `'BOTH'` (Lines 110, 114, 143, 156)
   - Need to check if constants exist for these
   - If not, may need to add constants OR these may be acceptable as parameter values
   
3. **Message Numbers**: `'001'`, `'003'`, `'005'`, etc. (Lines 207-259, 268-287)
   - Should use: `zcl_cd_bank_val_constants=>gc_message_no-msg_001_*`, etc.
   
4. **Severity Levels**: `'ERROR'`, `'INFO'`, `'WARNING'`, `'CRITICAL'` (Lines 269-287)
   - Need to check if constants exist for these
   - May need to add to constants class

5. **Parse Markers**: `'Business:'`, `'Technical:'` (Lines 172, 175)
   - These are parsing delimiters - may be acceptable as-is

---

## Next Steps

1. Check if constants exist for audience types and severity levels
2. Replace all hardcoded message IDs with constants
3. Replace all hardcoded message numbers with constants
4. Add constants for severity levels if missing
5. Review audience types - may be acceptable as parameter values
6. Check all other classes for similar hardcoded values

---

## Classes to Check

- [x] msg/zcl_cd_bank_val_msg_formatter.clas.abap
- [ ] msg/zcl_cd_bank_val_messages.clas.abap
- [ ] All validator classes
- [ ] Processor class
- [ ] DAO classes
- [ ] Other utility classes
