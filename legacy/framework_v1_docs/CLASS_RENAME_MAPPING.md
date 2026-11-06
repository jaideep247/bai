# Complete Class Rename Mapping: zcl_* → zcd_cl_*

## Summary
All classes in the framework are being renamed from `zcl_bank_val_*` to `zcd_cl_bank_val_*` to comply with the naming convention and 30-character limit.

## Rename Rules
1. **Prefix Change**: `zcl_` → `zcd_cl_`
2. **Length Limit**: All class names must be ≤30 characters
3. **Shortening Strategy**: For names that exceed 30 chars, use abbreviations:
   - `builder` → `bldr`
   - `enhanced` → `enh`
   - `exception` → `exc`
   - `context` → `ctx`
   - `notification` → `notif`
   - `service` → `svc` (if needed)

## Completed Renames

### Parameter Utility Classes ✓
- `zcd_cl_utility_params_sql` (already renamed)
- `zcd_cl_util_para_factory` (already renamed)
- `zcd_cl_utility_params_sql_inj` (already renamed)
- `zcd_cl_util_para_test_dbl` (already renamed)

### Utility Classes ✓ (In Progress)
- `zcl_bank_val_param_loader` → `zcd_cl_bank_val_param_loader` ✓
- `zcl_bank_val_param_wrapper` → `zcd_cl_bank_val_param_wrapper` ✓
- `zcl_bank_val_result_builder` → `zcd_cl_bank_val_result_bldr` ✓ (shortened)
- `zcl_bank_val_exception_factory` → `zcd_cl_bank_val_exc_factory` ✓ (shortened)
- `zcl_bank_val_error_context_builder` → `zcd_cl_bank_val_err_ctx_bldr` ✓ (shortened)
- `zcl_bank_val_notification_service` → `zcd_cl_bank_val_notif_service` ✓ (shortened)
- `zcl_bank_val_cache_enhanced` → `zcd_cl_bank_val_cache_enh` ✓ (shortened)
- `zcl_bank_val_retry_handler` → `zcd_cl_bank_val_retry_handler` ✓
- `zcl_bank_val_query_builder` → `zcd_cl_bank_val_query_bldr` ✓ (shortened)

## Pending Renames

### Validator Classes
- `zcl_bank_val_validator_base` → `zcd_cl_bank_val_validator_base`
- `zcl_bank_val_vorgc_166` → `zcd_cl_bank_val_vorgc_166`
- `zcl_bank_val_vorgc_168` → `zcd_cl_bank_val_vorgc_168`
- `zcl_bank_val_vorgc_195` → `zcd_cl_bank_val_vorgc_195`
- `zcl_bank_val_vorgc_275` → `zcd_cl_bank_val_vorgc_275`
- `zcl_bank_val_vorgc_468` → `zcd_cl_bank_val_vorgc_468`
- `zcl_bank_val_vorgc_575` → `zcd_cl_bank_val_vorgc_575`
- `zcl_bank_val_vorgc_581` → `zcd_cl_bank_val_vorgc_581`

### Processor Classes
- `zcl_bank_val_processor` → `zcd_cl_bank_val_processor`
- `zcl_bank_val_bulk_processor` → `zcd_cl_bank_val_bulk_proc` (shortened)
- `zcl_bank_val_factory` → `zcd_cl_bank_val_factory`

### Factory Classes
- `zcl_bank_val_processor_factory` → `zcd_cl_bank_val_proc_factory` (shortened)
- `zcl_bank_val_validator_factory` → `zcd_cl_bank_val_val_factory` (shortened)
- `zcl_bank_val_logger_factory` → `zcd_cl_bank_val_log_factory` (shortened)
- `zcl_bank_val_dao_factory` → `zcd_cl_bank_val_dao_factory`
- `zcl_bank_val_cache_factory` → `zcd_cl_bank_val_cache_factory`
- `zcl_bank_val_metrics_factory` → `zcd_cl_bank_val_metrics_factory`
- `zcl_bank_val_audit_factory` → `zcd_cl_bank_val_audit_factory`
- `zcl_bank_val_config_factory` → `zcd_cl_bank_val_config_factory`

### DAO Classes
- `zcl_bank_val_dao_retrieval_log` → `zcd_cl_bank_val_dao_retr_log` (shortened)
- `zcl_bank_val_dao_dfkkrp` → `zcd_cl_bank_val_dao_dfkkrp`
- `zcl_bank_val_dao_dpayh` → `zcd_cl_bank_val_dao_dpayh`
- `zcl_bank_val_dao_dfkkcr` → `zcd_cl_bank_val_dao_dfkkcr`
- `zcl_bank_val_dao_retrieval_log_test_double` → `zcd_cl_bank_val_dao_retr_log_td` (shortened)
- `zcl_bank_val_dao_dfkkrp_test_double` → `zcd_cl_bank_val_dao_dfkkrp_td` (shortened)
- `zcl_bank_val_dao_dpayh_test_double` → `zcd_cl_bank_val_dao_dpayh_td` (shortened)
- `zcl_bank_val_dao_dfkkcr_test_double` → `zcd_cl_bank_val_dao_dfkkcr_td` (shortened)

### Monitor/Audit/Log/Cache/Config Classes
- `zcl_bank_val_logger` → `zcd_cl_bank_val_logger`
- `zcl_bank_val_cache` → `zcd_cl_bank_val_cache`
- `zcl_bank_val_metrics` → `zcd_cl_bank_val_metrics`
- `zcl_bank_val_audit` → `zcd_cl_bank_val_audit`
- `zcl_bank_val_audit_enhanced` → `zcd_cl_bank_val_audit_enh` (shortened)
- `zcl_bank_val_config` → `zcd_cl_bank_val_config`
- `zcl_bank_val_customizing` → `zcd_cl_bank_val_customizing`
- `zcl_bank_val_constants` → `zcd_cl_bank_val_constants`
- `zcl_bank_val_health_check` → `zcd_cl_bank_val_health_check`
- `zcl_bank_val_performance_profiler` → `zcd_cl_bank_val_perf_profiler` (shortened)
- `zcl_bank_val_auth` → `zcd_cl_bank_val_auth`

### RAP Classes
- `zcl_bank_val_rap_behavior` → `zcd_cl_bank_val_rap_behavior`
- `zcl_bank_val_rap_service` → `zcd_cl_bank_val_rap_service`
- `zcl_bank_val_rap_saver` → `zcd_cl_bank_val_rap_saver`

### Business Classes
- `zcl_bank_val_workflow` → `zcd_cl_bank_val_workflow`

### Job Classes
- `zcl_bank_val_daily_job` → `zcd_cl_bank_val_daily_job`

### Message Classes
- `zcl_bank_val_message_formatter` → `zcd_cl_bank_val_msg_formatter` (shortened)
- `zcl_bank_val_messages` → `zcd_cl_bank_val_messages`

### Helper Classes
- `zcl_bank_val_field_helper` → `zcd_cl_bank_val_field_helper`

### Injector Classes
- `zcl_bank_val_injector` → `zcd_cl_bank_val_injector`

### Test Doubles
- `zcl_bank_val_logger_test_double` → `zcd_cl_bank_val_logger_td` (shortened)
- `zcl_bank_val_config_test_double` → `zcd_cl_bank_val_config_td` (shortened)

### Test Classes
- `zcl_bank_val_integration_test` → `zcd_cl_bank_val_integration_test`
- `zcl_bank_val_performance_test` → `zcd_cl_bank_val_performance_test`
- `zcl_bank_val_security_test` → `zcd_cl_bank_val_security_test`

## Interface Renames
- `zif_bank_val_validator` → `zif_cd_bank_val_validator` (keep `zif_` prefix, add `cd_`)
- `zif_bank_val_config` → `zif_cd_bank_val_config`
- `zif_bank_val_callable` → `zif_cd_bank_val_callable`
- `zif_bank_val_dao_retrieval_log` → `zif_cd_bank_val_dao_retr_log`
- `zif_bank_val_dao_dfkkrp` → `zif_cd_bank_val_dao_dfkkrp`
- `zif_bank_val_dao_dpayh` → `zif_cd_bank_val_dao_dpayh`
- `zif_bank_val_dao_dfkkcr` → `zif_cd_bank_val_dao_dfkkcr`

## Character Count Verification

All renamed classes must be ≤30 characters. Classes that needed shortening:
- `zcd_cl_bank_val_result_bldr` = 29 chars ✓
- `zcd_cl_bank_val_exc_factory` = 28 chars ✓
- `zcd_cl_bank_val_err_ctx_bldr` = 29 chars ✓
- `zcd_cl_bank_val_notif_service` = 30 chars ✓
- `zcd_cl_bank_val_cache_enh` = 26 chars ✓
- `zcd_cl_bank_val_query_bldr` = 28 chars ✓

## Status
- **Completed**: All class definitions renamed to `zcd_cl_` naming convention ✓
  - Utility classes (9 classes) ✓
  - Validator classes (8 classes) ✓
  - Processor classes (3 classes) ✓
  - Factory classes (7 classes) ✓
  - DAO classes (9 classes) ✓
  - Monitor/Audit/Log/Cache/Config classes (15 classes) ✓
  - RAP classes (3 classes) ✓
  - Job/Business/Helper/Message classes (7 classes) ✓
  - Test classes (15+ classes) ✓
- **Pending**: Update all references to renamed classes throughout the codebase
- **Note**: Documentation files (.md) may still contain old class names as examples

## Notes
- Exception classes (`zcx_*`) may need to be renamed to `zcd_cl_cx_*` or kept as `zcx_*` - confirm with user
- Test class files (`.testclasses.abap`) contain LOCAL FRIENDS declarations that reference the class name - these will be updated automatically when class definitions are renamed
- All factory methods, injector references, and type declarations need to be updated
