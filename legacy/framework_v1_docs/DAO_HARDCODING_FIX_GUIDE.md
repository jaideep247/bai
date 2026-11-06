# DAO Classes - Hardcoding Removal Guide

## Overview

This guide provides detailed instructions for removing hardcoded values from all 8 DAO (Data Access Object) classes.

---

## Classes to Fix

### Production DAOs (Priority: High)
1. `dao/zcl_cd_bank_val_dao_dfkkcr.clas.abap` - Check registry DAO
2. `dao/zcl_cd_bank_val_dao_dfkkrp.clas.abap` - Payment request DAO
3. `dao/zcl_cd_bank_val_dao_dpayh.clas.abap` - Payment history DAO
4. `dao/zcl_cd_bank_val_dao_retr_log.clas.abap` - Retrieval log DAO
5. `dao/zcl_cd_bank_val_dao_factory.clas.abap` - DAO factory

### Test Doubles (Priority: Low)
6. `dao/zcl_cd_bank_val_dao_dfkkcr_td.clas.abap` - Test double (acceptable hardcoding)
7. `dao/zcl_cd_bank_val_dao_dfkkrp_td.clas.abap` - Test double (acceptable hardcoding)
8. `dao/zcl_cd_bank_val_dao_dpayh_td.clas.abap` - Test double (acceptable hardcoding)

---

## Common Hardcoding Patterns in DAOs

### Pattern 1: WHERE Clause Status Values

**❌ Before**:
```abap
METHOD get_active_records.
  SELECT * FROM dfkkrp
    INTO TABLE rt_records
    WHERE status = 'ACTIVE'
      AND processed = 'X'.
ENDMETHOD.
```

**✅ After**:
```abap
METHOD get_active_records.
  SELECT * FROM dfkkrp
    INTO TABLE rt_records
    WHERE status = @zcl_cd_bank_val_constants=>gc_status-active
      AND processed = @abap_true.
ENDMETHOD.
```

### Pattern 2: Dynamic Table Names

**❌ Before**:
```abap
METHOD check_table_exists.
  SELECT SINGLE @abap_true FROM dd02l
    INTO @DATA(lv_exists)
    WHERE tabname = 'DFKKRP'
      AND as4local = 'A'.
ENDMETHOD.
```

**✅ After**:
```abap
METHOD check_table_exists.
  SELECT SINGLE @abap_true FROM dd02l
    INTO @DATA(lv_exists)
    WHERE tabname = @zcl_cd_bank_val_constants=>gc_table-dfkkrp
      AND as4local = @zcl_cd_bank_val_constants=>gc_dd_status-active.
ENDMETHOD.
```

### Pattern 3: Error Messages in DAOs

**❌ Before**:
```abap
METHOD get_by_key.
  SELECT SINGLE * FROM dfkkrp
    INTO @rs_record
    WHERE key_field = @iv_key.
    
  IF sy-subrc <> 0.
    RAISE EXCEPTION TYPE zcx_bank_val_dfkkrp_error
      EXPORTING textid = 'Record not found'.
  ENDIF.
ENDMETHOD.
```

**✅ After**:
```abap
METHOD get_by_key.
  SELECT SINGLE * FROM dfkkrp
    INTO @rs_record
    WHERE key_field = @iv_key.
    
  IF sy-subrc <> 0.
    RAISE EXCEPTION TYPE zcx_bank_val_dfkkrp_error
      EXPORTING textid = zcx_bank_val_dfkkrp_error=>record_not_found.
  ENDIF.
ENDMETHOD.
```

### Pattern 4: Field Name Checks

**❌ Before**:
```abap
METHOD validate_field_exists.
  DATA(lv_field) = 'BELNR'.
  
  SELECT SINGLE @abap_true FROM dd03l
    INTO @DATA(lv_exists)
    WHERE tabname = 'FEBEP'
      AND fieldname = @lv_field.
ENDMETHOD.
```

**✅ After**:
```abap
METHOD validate_field_exists.
  DATA(lv_field) = zcl_cd_bank_val_constants=>gc_field-belnr.
  
  SELECT SINGLE @abap_true FROM dd03l
    INTO @DATA(lv_exists)
    WHERE tabname = @zcl_cd_bank_val_constants=>gc_table-febep
      AND fieldname = @lv_field.
ENDMETHOD.
```

### Pattern 5: Status Filtering

**❌ Before**:
```abap
METHOD get_returned_payments.
  SELECT * FROM dpayh
    INTO TABLE @rt_payments
    WHERE status = 'RETURNED'
       OR status = 'FAILED'.
ENDMETHOD.
```

**✅ After**:
```abap
METHOD get_returned_payments.
  SELECT * FROM dpayh
    INTO TABLE @rt_payments
    WHERE status = @zcl_cd_bank_val_constants=>gc_payment_status-returned
       OR status = @zcl_cd_bank_val_constants=>gc_payment_status-failed.
ENDMETHOD.
```

---

## Required Constants to Add

Add these to `zcl_cd_bank_val_constants` if not already present:

```abap
CLASS zcl_cd_bank_val_constants DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CONSTANTS:
      " Data Dictionary Status
      BEGIN OF gc_dd_status,
        active TYPE as4local VALUE 'A',
        inactive TYPE as4local VALUE 'I',
      END OF gc_dd_status,

      " Database Operation Results
      BEGIN OF gc_db_result,
        success TYPE sysubrc VALUE 0,
        not_found TYPE sysubrc VALUE 4,
        error TYPE sysubrc VALUE 8,
      END OF gc_db_result,

      " Lock Object Names
      BEGIN OF gc_lock_object,
        febep TYPE viewname VALUE 'E_FEBEP',
        dfkkrp TYPE viewname VALUE 'E_DFKKRP',
      END OF gc_lock_object.
ENDCLASS.
```

---

## Step-by-Step Process

### Step 1: Fix DAO Factory First

**File**: `dao/zcl_cd_bank_val_dao_factory.clas.abap`

**Why First**: Factory creates all other DAOs. Fix factory patterns first.

**Actions**:
1. Search for hardcoded DAO class names (if any)
2. Search for hardcoded configuration values
3. Replace with constants

**Example**:
```abap
" Before
METHOD get_dao_for_table.
  CASE iv_table.
    WHEN 'DFKKRP'.
      ro_dao = NEW zcl_cd_bank_val_dao_dfkkrp( ).
    WHEN 'DPAYH'.
      ro_dao = NEW zcl_cd_bank_val_dao_dpayh( ).
  ENDCASE.
ENDMETHOD.

" After
METHOD get_dao_for_table.
  CASE iv_table.
    WHEN zcl_cd_bank_val_constants=>gc_table-dfkkrp.
      ro_dao = NEW zcl_cd_bank_val_dao_dfkkrp( ).
    WHEN zcl_cd_bank_val_constants=>gc_table-dpayh.
      ro_dao = NEW zcl_cd_bank_val_dao_dpayh( ).
  ENDCASE.
ENDMETHOD.
```

### Step 2: Fix DFKKCR DAO

**File**: `dao/zcl_cd_bank_val_dao_dfkkcr.clas.abap`

**Purpose**: Access DFKKCR (check registry) table

**Likely Hardcoded Values**:
- Status codes in WHERE clauses
- Error messages
- Field names for dynamic queries

**Search Pattern**:
```sql
-- Find SELECT statements with hardcoded values
SELECT * FROM dfkkcr WHERE status = 'ACTIVE'
SELECT * FROM dfkkcr WHERE processed = 'X'
```

### Step 3: Fix DFKKRP DAO

**File**: `dao/zcl_cd_bank_val_dao_dfkkrp.clas.abap`

**Purpose**: Access DFKKRP (payment request) table

**Likely Hardcoded Values**:
- Payment status codes
- Processing flags
- Error messages

### Step 4: Fix DPAYH DAO

**File**: `dao/zcl_cd_bank_val_dao_dpayh.clas.abap`

**Purpose**: Access DPAYH (payment history) table

**Likely Hardcoded Values**:
- `'RETURNED'` - Payment status
- `'PROCESSED'` - Processing status
- `'FAILED'` - Failure status

### Step 5: Fix Retrieval Log DAO

**File**: `dao/zcl_cd_bank_val_dao_retr_log.clas.abap`

**Purpose**: Access ZCD_ACH_RTRV_LOG table

**Likely Hardcoded Values**:
- `'AP'`, `'AF'` - Retrieval statuses
- Log status codes
- Error messages

---

## Testing Each DAO

### Unit Test Template
```abap
CLASS ltc_dao_test DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: mo_dao TYPE REF TO zcl_cd_bank_val_dao_dfkkrp.

    METHODS: setup,
             test_get_by_status FOR TESTING.
ENDCLASS.

CLASS ltc_dao_test IMPLEMENTATION.
  METHOD setup.
    mo_dao = NEW zcl_cd_bank_val_dao_dfkkrp( ).
  ENDMETHOD.

  METHOD test_get_by_status.
    " Test with constant instead of hardcoded value
    DATA(lt_records) = mo_dao->get_by_status(
      iv_status = zcl_cd_bank_val_constants=>gc_status-active
    ).
    
    cl_abap_unit_assert=>assert_not_initial( lt_records ).
  ENDMETHOD.
ENDCLASS.
```

---

## Test Doubles - Special Considerations

Test doubles (`*_td.clas.abap`) can have **acceptable hardcoding** for test data:

```abap
" ✅ ACCEPTABLE in test doubles
METHOD setup_test_data.
  ls_test_data-status = 'TEST_STATUS'.  " OK for test data
  ls_test_data-amount = '100.00'.        " OK for test data
  ls_test_data-key = 'TEST123'.          " OK for test data
ENDMETHOD.
```

However, still fix:
- Business logic constants (if any)
- Status codes used in logic (not test data)
- Error messages

---

## Progress Tracking

- [ ] DAO Factory (`zcl_cd_bank_val_dao_factory`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Tested
  - [ ] Activated

- [ ] DFKKCR DAO (`zcl_cd_bank_val_dao_dfkkcr`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Tested
  - [ ] Activated

- [ ] DFKKRP DAO (`zcl_cd_bank_val_dao_dfkkrp`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Tested
  - [ ] Activated

- [ ] DPAYH DAO (`zcl_cd_bank_val_dao_dpayh`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Tested
  - [ ] Activated

- [ ] Retrieval Log DAO (`zcl_cd_bank_val_dao_retr_log`)
  - [ ] Code reviewed
  - [ ] Hardcoding removed
  - [ ] Tested
  - [ ] Activated

---

## Estimated Effort

- **DAO Factory**: 1 hour
- **Each Production DAO**: 1-2 hours
- **Test Doubles**: 30 minutes each (optional)
- **Total**: 6-10 hours for all DAOs

---

**Next**: After completing DAOs, proceed to utility classes
