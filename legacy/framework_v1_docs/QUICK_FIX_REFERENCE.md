# Quick Fix Reference - Hardcoding Removal

## Quick Search & Replace Patterns

Use these patterns to quickly find and fix hardcoded values across all classes.

---

## 1. Status Code Patterns

### Find & Replace in ADT (Eclipse)

**Pattern 1: AP Status**
```
Find:    = 'AP'
Replace: = zcl_cd_bank_val_constants=>gc_retrieval_status-ap

Find:    = "AP"
Replace: = zcl_cd_bank_val_constants=>gc_retrieval_status-ap

Find:    WHEN 'AP'
Replace: WHEN zcl_cd_bank_val_constants=>gc_retrieval_status-ap
```

**Pattern 2: AF Status**
```
Find:    = 'AF'
Replace: = zcl_cd_bank_val_constants=>gc_retrieval_status-af

Find:    WHEN 'AF'
Replace: WHEN zcl_cd_bank_val_constants=>gc_retrieval_status-af
```

**Pattern 3: RETURNED Status**
```
Find:    = 'RETURNED'
Replace: = zcl_cd_bank_val_constants=>gc_payment_status-returned

Find:    WHEN 'RETURNED'
Replace: WHEN zcl_cd_bank_val_constants=>gc_payment_status-returned
```

**Pattern 4: ACTIVE Status**
```
Find:    = 'ACTIVE'
Replace: = zcl_cd_bank_val_constants=>gc_status-active

Find:    WHERE status = 'ACTIVE'
Replace: WHERE status = @zcl_cd_bank_val_constants=>gc_status-active
```

**Pattern 5: PROCESSED Status**
```
Find:    = 'PROCESSED'
Replace: = zcl_cd_bank_val_constants=>gc_status-processed
```

---

## 2. VORGC Code Patterns

```
Find:    = '166'
Replace: = zcl_cd_bank_val_constants=>gc_vorgc-vorgc_166

Find:    WHEN '166'
Replace: WHEN zcl_cd_bank_val_constants=>gc_vorgc-vorgc_166

Find:    = '168'
Replace: = zcl_cd_bank_val_constants=>gc_vorgc-vorgc_168

Find:    = '195'
Replace: = zcl_cd_bank_val_constants=>gc_vorgc-vorgc_195

Find:    = '275'
Replace: = zcl_cd_bank_val_constants=>gc_vorgc-vorgc_275

Find:    = '468'
Replace: = zcl_cd_bank_val_constants=>gc_vorgc-vorgc_468

Find:    = '575'
Replace: = zcl_cd_bank_val_constants=>gc_vorgc-vorgc_575

Find:    = '581'
Replace: = zcl_cd_bank_val_constants=>gc_vorgc-vorgc_581
```

---

## 3. Message ID Patterns

```
Find:    'ZMC_BANK_VALIDATION'
Replace: zcl_cd_bank_val_constants=>gc_message-msgid_bank_validation

Find:    MESSAGE e001(zmc_bank_validation)
Replace: MESSAGE ID zcl_cd_bank_val_constants=>gc_message-msgid_bank_validation
         TYPE zcl_cd_bank_val_constants=>gc_message_type-error
         NUMBER zcl_cd_bank_val_constants=>gc_message_no-msg_001_belnr_not_blank
```

---

## 4. Table Name Patterns

```
Find:    FROM dfkkrp
Replace: FROM dfkkrp  " (No change - table names in FROM clause are OK)

Find:    tabname = 'DFKKRP'
Replace: tabname = zcl_cd_bank_val_constants=>gc_table-dfkkrp

Find:    tabname = 'DPAYH'
Replace: tabname = zcl_cd_bank_val_constants=>gc_table-dpayh

Find:    tabname = 'FEBEP'
Replace: tabname = zcl_cd_bank_val_constants=>gc_table-febep
```

---

## 5. Result Code Patterns

```
Find:    = 'PASS'
Replace: = zcl_cd_bank_val_constants=>gc_result-pass

Find:    = 'FAIL'
Replace: = zcl_cd_bank_val_constants=>gc_result-fail

Find:    = 'SKIP'
Replace: = zcl_cd_bank_val_constants=>gc_result-skip

Find:    = 'WARN'
Replace: = zcl_cd_bank_val_constants=>gc_result-warn
```

---

## 6. Severity Patterns

```
Find:    = 'ERROR'
Replace: = zcl_cd_bank_val_constants=>gc_severity-error

Find:    = 'INFO'
Replace: = zcl_cd_bank_val_constants=>gc_severity-info

Find:    = 'WARNING'
Replace: = zcl_cd_bank_val_constants=>gc_severity-warning

Find:    = 'CRITICAL'
Replace: = zcl_cd_bank_val_constants=>gc_severity-critical
```

---

## 7. Audience Patterns

```
Find:    = 'BUSINESS'
Replace: = zcl_cd_bank_val_constants=>gc_audience-business

Find:    = 'TECHNICAL'
Replace: = zcl_cd_bank_val_constants=>gc_audience-technical

Find:    = 'BOTH'
Replace: = zcl_cd_bank_val_constants=>gc_audience-both
```

---

## Class-by-Class Quick Checklist

### Validators (8 classes)
```
For each validator:
1. Open class in ADT
2. Ctrl+F → Find: = '
3. Review each occurrence
4. Replace status codes with constants
5. Replace VORGC codes with constants
6. Replace message IDs with constants
7. Save and activate
8. Run unit tests
```

### DAOs (8 classes)
```
For each DAO:
1. Open class in ADT
2. Find: WHERE status = '
3. Replace with: WHERE status = @zcl_cd_bank_val_constants=>gc_status-
4. Find: tabname = '
5. Replace with: tabname = zcl_cd_bank_val_constants=>gc_table-
6. Save and activate
7. Test database operations
```

### Utilities (6 classes)
```
For each utility:
1. Open class in ADT
2. Search for string literals
3. Categorize: config, status, message, etc.
4. Replace with appropriate constants
5. Save and activate
6. Run tests
```

---

## Common Mistakes to Avoid

### ❌ DON'T Change These

**1. DEFAULT Parameter Values**
```abap
" ✅ KEEP AS IS - ABAP requires literals
METHOD my_method
  IMPORTING iv_flag TYPE abap_bool DEFAULT 'X'.
```

**2. Exception Class CONSTANTS**
```abap
" ✅ KEEP AS IS - Exception classes require literals
CONSTANTS: BEGIN OF error_001,
  msgid TYPE symsgid VALUE 'ZMC',
  msgno TYPE symsgno VALUE '001',
END OF error_001.
```

**3. Test Data in Test Doubles**
```abap
" ✅ KEEP AS IS - Test data can be hardcoded
METHOD setup_test_data.
  ls_test-value = 'TEST123'.
ENDMETHOD.
```

**4. Comments**
```abap
" ✅ KEEP AS IS - Comments can have any text
" This checks if status is 'AP' or 'AF'
```

---

## Verification Script

After making changes, verify with this checklist:

```abap
" 1. Check for remaining hardcoded values
" Search for: = '
" Exclude: DEFAULT, CONSTANTS, test doubles, comments

" 2. Check for hardcoded message IDs
" Search for: MESSAGE e
" Search for: MESSAGE w
" Search for: MESSAGE i

" 3. Check for hardcoded status codes
" Search for: = 'AP'
" Search for: = 'AF'
" Search for: = 'RETURNED'
" Search for: = 'ACTIVE'

" 4. Check for hardcoded VORGC codes
" Search for: = '166'
" Search for: = '168'
" Search for: = '275'
" etc.

" 5. Run all unit tests
" 6. Check syntax errors
" 7. Activate all classes
```

---

## Time Estimates

| Class Type | Count | Time per Class | Total Time |
|------------|-------|----------------|------------|
| Validators | 8 | 1-2 hours | 8-16 hours |
| DAOs | 8 | 1-2 hours | 8-16 hours |
| Utilities | 6 | 1 hour | 6 hours |
| Monitors | 2 | 1 hour | 2 hours |
| RAP | 3 | 1 hour | 3 hours |
| Jobs | 1 | 2 hours | 2 hours |
| Other | 13 | 30 min | 6.5 hours |
| **TOTAL** | **41** | - | **35-51 hours** |

**With 2 developers**: 2.5-3.5 weeks
**With 1 developer**: 4-6 weeks

---

## Daily Progress Tracking

### Week 1
- [ ] Monday: Job class + VORGC 166, 168
- [ ] Tuesday: VORGC 195, 275
- [ ] Wednesday: VORGC 468, 575, 581
- [ ] Thursday: Validator base class
- [ ] Friday: Testing and fixes

### Week 2
- [ ] Monday: DAO factory + DFKKCR DAO
- [ ] Tuesday: DFKKRP DAO + DPAYH DAO
- [ ] Wednesday: Retrieval log DAO + remaining DAOs
- [ ] Thursday: Utility classes (3)
- [ ] Friday: Utility classes (3) + testing

### Week 3
- [ ] Monday: Monitor classes
- [ ] Tuesday: RAP classes
- [ ] Wednesday: Other classes
- [ ] Thursday: Complete testing
- [ ] Friday: Code review and documentation

---

## Support Resources

- **Main Guide**: `COMPLETE_HARDCODING_REMOVAL_GUIDE.md`
- **Validator Guide**: `VALIDATOR_HARDCODING_FIX_GUIDE.md`
- **DAO Guide**: `DAO_HARDCODING_FIX_GUIDE.md`
- **Constants Template**: `CONSTANTS_CLASS_COMPLETE_TEMPLATE.md`
- **Examples**: `HARDCODED_VALUES_FIXES_COMPLETE.md`

---

**Quick Start**: 
1. Read this guide
2. Update constants class with template
3. Start with validators
4. Use search & replace patterns
5. Test after each class
6. Track progress daily
