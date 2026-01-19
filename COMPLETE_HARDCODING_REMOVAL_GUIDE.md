# Complete Hardcoding Removal Guide

## Executive Summary

This guide provides comprehensive instructions for removing ALL hardcoded values from the Bank Validation Framework. Based on the current status, **16 classes are complete** and **~41 classes remain**.

---

## Current Status Overview

### ✅ COMPLETED (16 classes - 27%)
- Core: processor, audit, security, customizing, cache, field_helper, logger, msg_formatter
- Factories: All 7 factory classes (clean)
- Monitor: health_check (partial)

### ⏳ REMAINING (41 classes - 73%)
- **Validators**: 8 classes
- **DAOs**: 8 classes  
- **Jobs**: 1 class (hardcoding confirmed)
- **Utilities**: 6 classes
- **Monitors**: 2 classes
- **RAP**: 3 classes
- **Other**: 13 classes

---

## Priority Order for Fixes

### 🔴 **CRITICAL PRIORITY** (Fix First)

#### 1. Job Classes (1 class)
**File**: `job/zcl_cd_bank_val_daily_job.clas.abap`

**Known Issues**:
- Hardcoded status values
- Hardcoded message texts
- Hardcoded configuration values

**Action**: Search for all string literals and replace with constants from `zcl_cd_bank_val_constants`

---

### 🟠 **HIGH PRIORITY** (Core Business Logic)

#### 2. Validator Classes (8 classes)

**Files**:
- `validator/zcl_cd_bank_val_validator_base.clas.abap`
- `validator/zcl_cd_bank_val_vorgc_166.clas.abap`
- `validator/zcl_cd_bank_val_vorgc_168.clas.abap`
- `validator/zcl_cd_bank_val_vorgc_195.clas.abap`
- `validator/zcl_cd_bank_val_vorgc_275.clas.abap`
- `validator/zcl_cd_bank_val_vorgc_468.clas.abap`
- `validator/zcl_cd_bank_val_vorgc_575.clas.abap`
- `validator/zcl_cd_bank_val_vorgc_581.clas.abap`

**Common Hardcoding Patterns to Find**:
```abap
" ❌ BAD - Hardcoded status values
IF ls_data-status = 'AP' OR ls_data-status = 'AF'.

" ✅ GOOD - Use constants
IF ls_data-status = zcl_cd_bank_val_constants=>gc_status-ap OR 
   ls_data-status = zcl_cd_bank_val_constants=>gc_status-af.

" ❌ BAD - Hardcoded message numbers
MESSAGE e001(zmc_bank_validation).

" ✅ GOOD - Use constants
MESSAGE ID zcl_cd_bank_val_constants=>gc_message-msgid_bank_validation
        TYPE 'E'
        NUMBER zcl_cd_bank_val_constants=>gc_message_no-msg_001_belnr_not_blank.

" ❌ BAD - Hardcoded field names
IF ls_data-vorgc = '166'.

" ✅ GOOD - Use constants
IF ls_data-vorgc = zcl_cd_bank_val_constants=>gc_vorgc-vorgc_166.

" ❌ BAD - Hardcoded table names
SELECT * FROM dfkkrp WHERE ...

" ✅ GOOD - Use constants (if table name is dynamic)
lv_table = zcl_cd_bank_val_constants=>gc_table-dfkkrp.
```

**Action for Each Validator**:
1. Open the validator class
2. Search for all string literals: `'TEXT'` or `"TEXT"`
3. Identify which are:
   - Status codes (AP, AF, RETURNED, etc.)
   - VORGC codes (166, 168, 195, etc.)
   - Message numbers (001, 002, 003, etc.)
   - Field names that should be constants
4. Add missing constants to `zcl_cd_bank_val_constants` if needed
5. Replace all hardcoded values with constants
6. Test the validator

---

#### 3. DAO Classes (8 classes)

**Files**:
- `dao/zcl_cd_bank_val_dao_dfkkcr.clas.abap`
- `dao/zcl_cd_bank_val_dao_dfkkrp.clas.abap`
- `dao/zcl_cd_bank_val_dao_dpayh.clas.abap`
- `dao/zcl_cd_bank_val_dao_retr_log.clas.abap`
- `dao/zcl_cd_bank_val_dao_factory.clas.abap`
- `dao/zcl_cd_bank_val_dao_dfkkcr_td.clas.abap` (test double - lower priority)
- `dao/zcl_cd_bank_val_dao_dfkkrp_td.clas.abap` (test double - lower priority)
- `dao/zcl_cd_bank_val_dao_dpayh_td.clas.abap` (test double - lower priority)

**Common Hardcoding Patterns in DAOs**:
```abap
" ❌ BAD - Hardcoded WHERE clause values
SELECT * FROM dfkkrp WHERE status = 'ACTIVE'.

" ✅ GOOD - Use constants
SELECT * FROM dfkkrp WHERE status = zcl_cd_bank_val_constants=>gc_status-active.

" ❌ BAD - Hardcoded error messages
RAISE EXCEPTION TYPE zcx_bank_val_dfkkrp_error
  EXPORTING textid = 'Record not found'.

" ✅ GOOD - Use message constants
RAISE EXCEPTION TYPE zcx_bank_val_dfkkrp_error
  EXPORTING textid = zcx_bank_val_dfkkrp_error=>record_not_found.
```

**Action for Each DAO**:
1. Search for hardcoded status values in WHERE clauses
2. Search for hardcoded field values
3. Search for hardcoded error messages
4. Replace with constants
5. Test database operations

---

### 🟡 **MEDIUM PRIORITY**

#### 4. Monitor Classes (2 classes)

**Files**:
- `monitor/zcl_cd_bank_val_metrics.clas.abap`
- `monitor/zcl_cd_bank_val_perf_profiler.clas.abap`

**Common Patterns**:
- Metric names
- Threshold values
- Timer names

#### 5. Utility Classes (6 classes)

**Files**:
- `util/zcl_cd_bank_val_query_bldr.clas.abap`
- `util/zcl_cd_bank_val_notif_service.clas.abap`
- Others

---

### 🟢 **LOW PRIORITY**

#### 6. RAP Classes (3 classes)
- `rap/zcl_cd_bank_val_rap_behavior.clas.abap`
- `rap/zcl_cd_bank_val_rap_service.clas.abap`
- `rap/zcl_cd_bank_val_rap_saver.clas.abap`

#### 7. Other Classes
- `injector/zcl_cd_bank_val_injector.clas.abap`
- `msg/zcl_cd_bank_val_messages.clas.abap`
- Test doubles (acceptable to have some hardcoding)

---

## Constants to Add to `zcl_cd_bank_val_constants`

### Status Codes
```abap
BEGIN OF gc_status,
  ap TYPE char2 VALUE 'AP',
  af TYPE char2 VALUE 'AF',
  returned TYPE char10 VALUE 'RETURNED',
  active TYPE char6 VALUE 'ACTIVE',
  inactive TYPE char8 VALUE 'INACTIVE',
  processed TYPE char9 VALUE 'PROCESSED',
  pending TYPE char7 VALUE 'PENDING',
END OF gc_status,
```

### VORGC Codes (if not already present)
```abap
BEGIN OF gc_vorgc,
  vorgc_166 TYPE vorgc VALUE '166',
  vorgc_168 TYPE vorgc VALUE '168',
  vorgc_195 TYPE vorgc VALUE '195',
  vorgc_275 TYPE vorgc VALUE '275',
  vorgc_468 TYPE vorgc VALUE '468',
  vorgc_575 TYPE vorgc VALUE '575',
  vorgc_581 TYPE vorgc VALUE '581',
END OF gc_vorgc,
```

### Table Names (if needed for dynamic access)
```abap
BEGIN OF gc_table,
  febep TYPE tabname VALUE 'FEBEP',
  dfkkrp TYPE tabname VALUE 'DFKKRP',
  dpayh TYPE tabname VALUE 'DPAYH',
  dfkkcr TYPE tabname VALUE 'DFKKCR',
  zcd_ach_rtrv_log TYPE tabname VALUE 'ZCD_ACH_RTRV_LOG',
  zbank_val_result TYPE tabname VALUE 'ZBANK_VAL_RESULT',
  zbank_val_audit TYPE tabname VALUE 'ZBANK_VAL_AUDIT',
  zbank_val_vorgc TYPE tabname VALUE 'ZBANK_VAL_VORGC',
END OF gc_table,
```

### Field Names (commonly used)
```abap
BEGIN OF gc_field,
  belnr TYPE fieldname VALUE 'BELNR',
  vorgc TYPE fieldname VALUE 'VORGC',
  status TYPE fieldname VALUE 'STATUS',
  chect TYPE fieldname VALUE 'CHECT',
  hkont TYPE fieldname VALUE 'HKONT',
  waers TYPE fieldname VALUE 'WAERS',
  kwbtr TYPE fieldname VALUE 'KWBTR',
  wrbtr TYPE fieldname VALUE 'WRBTR',
END OF gc_field,
```

---

## Step-by-Step Process for Each Class

### Step 1: Analyze the Class
```abap
" Open the class in ADT or SE24
" Use Find (Ctrl+F) to search for:
" 1. Single quotes: '
" 2. Double quotes: "
" Review each occurrence
```

### Step 2: Categorize Hardcoded Values

**Acceptable Hardcoding** (DO NOT change):
- DEFAULT parameter values: `iv_param TYPE string DEFAULT 'X'`
- Exception class CONSTANTS: `CONSTANTS: BEGIN OF error_001, msgid TYPE symsgid VALUE 'ZMC', ...`
- Test double mock data: `ls_test_data-value = 'TEST123'`
- Comments: `" This is a comment with 'text'`

**Must Fix** (CHANGE these):
- Status values in logic: `IF status = 'AP'`
- VORGC codes in logic: `WHEN '166'`
- Message IDs/numbers: `MESSAGE e001(zmc_bank_validation)`
- Configuration values: `lv_batch = '1000'`
- Table/field names used dynamically
- Error messages: `RAISE EXCEPTION ... textid = 'Error occurred'`

### Step 3: Add Missing Constants

If a constant doesn't exist in `zcl_cd_bank_val_constants`:

1. Open `zcl_cd_bank_val_constants`
2. Find the appropriate structure (gc_status, gc_vorgc, gc_message, etc.)
3. Add the new constant:
```abap
BEGIN OF gc_status,
  ...
  new_status TYPE char10 VALUE 'NEW_STATUS',  " Add this
END OF gc_status,
```
4. Save and activate

### Step 4: Replace Hardcoded Values

**Before**:
```abap
IF ls_data-status = 'AP'.
  " Process AP status
ELSEIF ls_data-status = 'AF'.
  " Process AF status
ENDIF.
```

**After**:
```abap
IF ls_data-status = zcl_cd_bank_val_constants=>gc_status-ap.
  " Process AP status
ELSEIF ls_data-status = zcl_cd_bank_val_constants=>gc_status-af.
  " Process AF status
ENDIF.
```

### Step 5: Test the Changes

1. Activate the class
2. Run unit tests
3. Verify no syntax errors
4. Check that logic still works correctly

---

## Systematic Approach for All 41 Classes

### Week 1: Critical Priority
- [ ] Day 1: `job/zcl_cd_bank_val_daily_job.clas.abap`
- [ ] Day 2-3: Validator base class + VORGC 166, 168
- [ ] Day 4-5: VORGC 195, 275, 468

### Week 2: High Priority
- [ ] Day 1-2: VORGC 575, 581
- [ ] Day 3-5: All 8 DAO classes

### Week 3: Medium Priority
- [ ] Day 1-2: Monitor classes (2)
- [ ] Day 3-5: Utility classes (6)

### Week 4: Low Priority & Verification
- [ ] Day 1-2: RAP classes (3)
- [ ] Day 3: Other classes
- [ ] Day 4-5: Complete verification and testing

---

## Verification Checklist

After completing all fixes:

- [ ] All 41 classes reviewed
- [ ] No hardcoded status values remain
- [ ] No hardcoded VORGC codes remain
- [ ] No hardcoded message IDs/numbers remain
- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Code review completed
- [ ] Documentation updated

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Changing DEFAULT values
```abap
" DON'T change this - ABAP requires literal values for DEFAULT
METHOD my_method
  IMPORTING iv_flag TYPE abap_bool DEFAULT 'X'.  " ✅ This is OK
```

### ❌ Mistake 2: Changing exception class constants
```abap
" DON'T change this - Exception classes require literal CONSTANTS
CLASS zcx_my_exception DEFINITION.
  PUBLIC SECTION.
    CONSTANTS: BEGIN OF error_001,
      msgid TYPE symsgid VALUE 'ZMC',  " ✅ This is OK
      msgno TYPE symsgno VALUE '001',  " ✅ This is OK
    END OF error_001.
ENDCLASS.
```

### ❌ Mistake 3: Changing test data
```abap
" Test doubles can have hardcoded test data
METHOD setup_test_data.
  ls_test-value = 'TEST123'.  " ✅ This is OK for test doubles
ENDMETHOD.
```

### ✅ Correct: Changing business logic
```abap
" DO change this - Business logic should use constants
METHOD validate_status.
  IF iv_status = zcl_cd_bank_val_constants=>gc_status-ap.  " ✅ Correct
    " Process
  ENDIF.
ENDMETHOD.
```

---

## Benefits of Complete Hardcoding Removal

1. **Maintainability**: Change values in one place (constants class)
2. **Consistency**: Same values used everywhere
3. **Testability**: Easy to mock/change for testing
4. **Documentation**: Constants are self-documenting
5. **Refactoring**: Easy to find all usages
6. **Configuration**: Can move to parameter table later
7. **Quality**: Reduces magic numbers/strings
8. **Standards**: Follows ABAP best practices

---

## Next Steps

1. **Review this guide** with the development team
2. **Prioritize** which classes to fix first
3. **Assign** classes to developers
4. **Track progress** using the checklist
5. **Test thoroughly** after each change
6. **Update documentation** when complete

---

## Support

For questions or issues:
- Review `zcl_cd_bank_val_constants` for existing constants
- Check `HARDCODED_VALUES_FIXES_COMPLETE.md` for examples
- Refer to completed classes as templates
- Follow ABAP coding standards

---

**Status**: Ready for implementation
**Priority**: High
**Estimated Effort**: 3-4 weeks
**Risk**: Low (if tested properly)


