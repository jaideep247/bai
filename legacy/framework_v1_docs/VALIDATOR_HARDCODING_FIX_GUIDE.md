# Validator Classes - Hardcoding Removal Guide

## Overview

This guide provides detailed instructions for removing hardcoded values from all 8 validator classes.

---

## Classes to Fix

1. `validator/zcl_cd_bank_val_validator_base.clas.abap` (Base class - fix first)
2. `validator/zcl_cd_bank_val_vorgc_166.clas.abap`
3. `validator/zcl_cd_bank_val_vorgc_168.clas.abap`
4. `validator/zcl_cd_bank_val_vorgc_195.clas.abap`
5. `validator/zcl_cd_bank_val_vorgc_275.clas.abap`
6. `validator/zcl_cd_bank_val_vorgc_468.clas.abap`
7. `validator/zcl_cd_bank_val_vorgc_575.clas.abap`
8. `validator/zcl_cd_bank_val_vorgc_581.clas.abap`

---

## Common Hardcoding Patterns in Validators

### Pattern 1: Status Code Checks

**❌ Before**:
```abap
METHOD validate_retrieval_log.
  IF ls_log-status = 'AP' OR ls_log-status = 'AF'.
    " Valid status
  ELSE.
    " Invalid status
    RAISE EXCEPTION TYPE zcx_bank_val_retrieval_error
      EXPORTING textid = 'Invalid status'.
  ENDIF.
ENDMETHOD.
```

**✅ After**:
```abap
METHOD validate_retrieval_log.
  IF ls_log-status = zcl_cd_bank_val_constants=>gc_status-ap OR 
     ls_log-status = zcl_cd_bank_val_constants=>gc_status-af.
    " Valid status
  ELSE.
    " Invalid status
    RAISE EXCEPTION TYPE zcx_bank_val_retrieval_error
      EXPORTING textid = zcx_bank_val_retrieval_error=>invalid_status.
  ENDIF.
ENDMETHOD.
```

### Pattern 2: VORGC Code Checks

**❌ Before**:
```abap
METHOD get_validator_for_vorgc.
  CASE iv_vorgc.
    WHEN '166'.
      ro_validator = NEW zcl_cd_bank_val_vorgc_166( ).
    WHEN '168'.
      ro_validator = NEW zcl_cd_bank_val_vorgc_168( ).
    WHEN '275'.
      ro_validator = NEW zcl_cd_bank_val_vorgc_275( ).
  ENDCASE.
ENDMETHOD.
```

**✅ After**:
```abap
METHOD get_validator_for_vorgc.
  CASE iv_vorgc.
    WHEN zcl_cd_bank_val_constants=>gc_vorgc-vorgc_166.
      ro_validator = NEW zcl_cd_bank_val_vorgc_166( ).
    WHEN zcl_cd_bank_val_constants=>gc_vorgc-vorgc_168.
      ro_validator = NEW zcl_cd_bank_val_vorgc_168( ).
    WHEN zcl_cd_bank_val_constants=>gc_vorgc-vorgc_275.
      ro_validator = NEW zcl_cd_bank_val_vorgc_275( ).
  ENDCASE.
ENDMETHOD.
```

### Pattern 3: Message Raising

**❌ Before**:
```abap
METHOD validate_belnr.
  IF is_febep-belnr IS NOT INITIAL.
    MESSAGE e001(zmc_bank_validation) INTO lv_msg.
    " or
    RAISE EXCEPTION TYPE zcx_bank_val_belnr_error
      EXPORTING textid = 'BELNR must be blank'.
  ENDIF.
ENDMETHOD.
```

**✅ After**:
```abap
METHOD validate_belnr.
  IF is_febep-belnr IS NOT INITIAL.
    MESSAGE ID zcl_cd_bank_val_constants=>gc_message-msgid_bank_validation
            TYPE zcl_cd_bank_val_constants=>gc_message_type-error
            NUMBER zcl_cd_bank_val_constants=>gc_message_no-msg_001_belnr_not_blank
            INTO lv_msg.
    " or
    RAISE EXCEPTION TYPE zcx_bank_val_belnr_error
      EXPORTING textid = zcx_bank_val_belnr_error=>belnr_must_be_blank.
  ENDIF.
ENDMETHOD.
```

### Pattern 4: Field Value Checks

**❌ Before**:
```abap
METHOD validate_payment_status.
  IF ls_dpayh-status = 'RETURNED'.
    lv_valid = abap_true.
  ELSEIF ls_dpayh-status = 'PROCESSED'.
    lv_valid = abap_true.
  ELSE.
    lv_valid = abap_false.
  ENDIF.
ENDMETHOD.
```

**✅ After**:
```abap
METHOD validate_payment_status.
  IF ls_dpayh-status = zcl_cd_bank_val_constants=>gc_payment_status-returned.
    lv_valid = abap_true.
  ELSEIF ls_dpayh-status = zcl_cd_bank_val_constants=>gc_payment_status-processed.
    lv_valid = abap_true.
  ELSE.
    lv_valid = abap_false.
  ENDIF.
ENDMETHOD.
```

### Pattern 5: Validation Result Codes

**❌ Before**:
```abap
METHOD set_validation_result.
  IF lv_valid = abap_true.
    ls_result-result_code = 'PASS'.
    ls_result-severity = 'INFO'.
  ELSE.
    ls_result-result_code = 'FAIL'.
    ls_result-severity = 'ERROR'.
  ENDIF.
ENDMETHOD.
```

**✅ After**:
```abap
METHOD set_validation_result.
  IF lv_valid = abap_true.
    ls_result-result_code = zcl_cd_bank_val_constants=>gc_result-pass.
    ls_result-severity = zcl_cd_bank_val_constants=>gc_severity-info.
  ELSE.
    ls_result-result_code = zcl_cd_bank_val_constants=>gc_result-fail.
    ls_result-severity = zcl_cd_bank_val_constants=>gc_severity-error.
  ENDIF.
ENDMETHOD.
```

---

## Required Constants to Add

Add these to `zcl_cd_bank_val_constants` if not already present:

```abap
CLASS zcl_cd_bank_val_constants DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CONSTANTS:
      " Payment Status
      BEGIN OF gc_payment_status,
        returned TYPE char10 VALUE 'RETURNED',
        processed TYPE char10 VALUE 'PROCESSED',
        pending TYPE char10 VALUE 'PENDING',
        failed TYPE char10 VALUE 'FAILED',
      END OF gc_payment_status,

      " Validation Results
      BEGIN OF gc_result,
        pass TYPE char4 VALUE 'PASS',
        fail TYPE char4 VALUE 'FAIL',
        skip TYPE char4 VALUE 'SKIP',
        warn TYPE char4 VALUE 'WARN',
      END OF gc_result,

      " Retrieval Log Status (if not present)
      BEGIN OF gc_retrieval_status,
        ap TYPE char2 VALUE 'AP',
        af TYPE char2 VALUE 'AF',
        pending TYPE char7 VALUE 'PENDING',
        completed TYPE char9 VALUE 'COMPLETED',
      END OF gc_retrieval_status.
ENDCLASS.
```

---

## Step-by-Step Process

### Step 1: Fix Base Validator First

**File**: `validator/zcl_cd_bank_val_validator_base.clas.abap`

**Why First**: All other validators inherit from this class. Fix common methods here first.

**Actions**:
1. Open the base validator class
2. Search for all string literals using Find: `'`
3. Review each occurrence:
   - Skip DEFAULT parameter values
   - Skip comments
   - Replace business logic hardcoding
4. Common methods to check:
   - `validate()` - Main validation method
   - `get_error_message()` - Error message formatting
   - `check_mandatory_fields()` - Field validation
   - `format_result()` - Result formatting

**Example Fix in Base Class**:
```abap
" Before
METHOD check_mandatory_fields.
  IF is_febep-chect IS INITIAL.
    RAISE EXCEPTION TYPE zcx_bank_validation_base
      EXPORTING textid = 'CHECT is mandatory'.
  ENDIF.
ENDMETHOD.

" After
METHOD check_mandatory_fields.
  IF is_febep-chect IS INITIAL.
    RAISE EXCEPTION TYPE zcx_bank_validation_base
      EXPORTING textid = zcx_bank_validation_base=>chect_mandatory.
  ENDIF.
ENDMETHOD.
```

### Step 2: Fix VORGC 166 Validator

**File**: `validator/zcl_cd_bank_val_vorgc_166.clas.abap`

**Business Logic**: 3-step payment processing validation
- Check retrieval log status (AP or AF)
- Verify DFKKRP entry exists
- Validate DPAYH status (RETURNED)

**Likely Hardcoded Values**:
- `'AP'`, `'AF'` - Retrieval log statuses
- `'RETURNED'` - Payment status
- `'166'` - VORGC code
- Message numbers for validation failures

**Search Pattern**:
```abap
" Find these patterns and replace:
IF status = 'AP'           → IF status = zcl_cd_bank_val_constants=>gc_status-ap
IF status = 'AF'           → IF status = zcl_cd_bank_val_constants=>gc_status-af
IF status = 'RETURNED'     → IF status = zcl_cd_bank_val_constants=>gc_payment_status-returned
WHEN '166'                 → WHEN zcl_cd_bank_val_constants=>gc_vorgc-vorgc_166
```

### Step 3: Fix VORGC 168 Validator

**File**: `validator/zcl_cd_bank_val_vorgc_168.clas.abap`

**Business Logic**: Similar to 275 but BELNR must be empty

**Likely Hardcoded Values**:
- `'168'` - VORGC code
- Status values
- Error messages about BELNR

### Step 4: Fix VORGC 195 Validator

**File**: `validator/zcl_cd_bank_val_vorgc_195.clas.abap`

**Business Logic**: Specific validation rules for VORGC 195

**Likely Hardcoded Values**:
- `'195'` - VORGC code
- Status codes
- Validation thresholds

### Step 5: Fix VORGC 275 Validator

**File**: `validator/zcl_cd_bank_val_vorgc_275.clas.abap`

**Business Logic**: Standard validation flow

**Likely Hardcoded Values**:
- `'275'` - VORGC code
- Status values
- Field validation rules

### Step 6: Fix VORGC 468 Validator

**File**: `validator/zcl_cd_bank_val_vorgc_468.clas.abap`

**Business Logic**: BELNR must be empty (similar to 168)

**Likely Hardcoded Values**:
- `'468'` - VORGC code
- BELNR validation messages

### Step 7: Fix VORGC 575 Validator

**File**: `validator/zcl_cd_bank_val_vorgc_575.clas.abap`

**Business Logic**: Specific validation for VORGC 575

**Likely Hardcoded Values**:
- `'575'` - VORGC code
- Status codes

### Step 8: Fix VORGC 581 Validator

**File**: `validator/zcl_cd_bank_val_vorgc_581.clas.abap`

**Business Logic**: DFKKCR (check registry) matching
- DFKKCR entry must exist
- Amount must match
- Record count must match

**Likely Hardcoded Values**:
- `'581'` - VORGC code
- Match status values
- Error messages for mismatches

---

## Testing Each Validator

After fixing each validator:

### Unit Test Checklist
```abap
" 1. Activate the class
" 2. Run unit tests (if they exist)
" 3. Check for syntax errors
" 4. Verify constants are accessible

" Example test
METHOD test_validator_with_constants.
  DATA(lo_validator) = NEW zcl_cd_bank_val_vorgc_166( ).

  " Setup test data with constants
  ls_test_data-status = zcl_cd_bank_val_constants=>gc_status-ap.

  " Execute validation
  TRY.
      lo_validator->validate( ls_test_data ).
      cl_abap_unit_assert=>assert_true( act = abap_true ).
    CATCH zcx_bank_validation_base.
      cl_abap_unit_assert=>fail( 'Validation should pass' ).
  ENDTRY.
ENDMETHOD.
```

### Integration Test
1. Create test FEBEP records
2. Run validation through processor
3. Verify results are correct
4. Check that error messages are properly formatted

---

## Common Issues and Solutions

### Issue 1: Constant Not Found
**Error**: `Field "GC_STATUS-AP" is unknown`

**Solution**: Add the constant to `zcl_cd_bank_val_constants`:
```abap
BEGIN OF gc_status,
  ap TYPE char2 VALUE 'AP',  " Add this line
  ...
END OF gc_status,
```

### Issue 2: Type Mismatch
**Error**: `Type mismatch between CHAR2 and CHAR10`

**Solution**: Ensure constant type matches field type:
```abap
" If field is CHAR10, define constant as CHAR10
BEGIN OF gc_status,
  ap TYPE char10 VALUE 'AP',  " Use correct length
END OF gc_status,
```

### Issue 3: Performance Impact
**Concern**: "Will using constants slow down validation?"

**Answer**: No. Constants are resolved at compile time, not runtime. No performance impact.

### Issue 4: Too Many Constants
**Concern**: "The constants class is getting too large"

**Solution**: Group related constants together. Consider splitting into multiple constant classes if needed:
- `zcl_cd_bank_val_constants` - Core constants
- `zcl_cd_bank_val_status_const` - Status codes
- `zcl_cd_bank_val_msg_const` - Message constants

---

## Progress Tracking

Use this checklist to track progress:

- [ ] Base validator (`zcl_cd_bank_val_validator_base`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Constants added
  - [ ] Tested
  - [ ] Activated

- [ ] VORGC 166 (`zcl_cd_bank_val_vorgc_166`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Constants added
  - [ ] Tested
  - [ ] Activated

- [ ] VORGC 168 (`zcl_cd_bank_val_vorgc_168`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Constants added
  - [ ] Tested
  - [ ] Activated

- [ ] VORGC 195 (`zcl_cd_bank_val_vorgc_195`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Constants added
  - [ ] Tested
  - [ ] Activated

- [ ] VORGC 275 (`zcl_cd_bank_val_vorgc_275`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Constants added
  - [ ] Tested
  - [ ] Activated

- [ ] VORGC 468 (`zcl_cd_bank_val_vorgc_468`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Constants added
  - [ ] Tested
  - [ ] Activated

- [ ] VORGC 575 (`zcl_cd_bank_val_vorgc_575`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Constants added
  - [ ] Tested
  - [ ] Activated

- [ ] VORGC 581 (`zcl_cd_bank_val_vorgc_581`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Constants added
  - [ ] Tested
  - [ ] Activated

---

## Estimated Effort

- **Base Validator**: 2-3 hours
- **Each VORGC Validator**: 1-2 hours
- **Total**: 10-15 hours for all 8 validators

---

## Success Criteria

✅ All validators completed when:
1. No hardcoded status values in business logic
2. No hardcoded VORGC codes in business logic
3. No hardcoded message texts
4. All unit tests pass
5. Integration tests pass
6. Code review approved
7. All classes activated successfully

---

**Next**: After completing validators, proceed to DAO classes (see `DAO_HARDCODING_FIX_GUIDE.md`)

