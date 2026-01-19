# Activation Order - Bank Validation Framework

## Overview

This document defines the activation order for all objects in the bank validation framework. Follow this order to avoid dependency errors during activation.

---

## Phase 1: Database Tables (Prerequisites)

1. `database/zzcd_param_area.tabl.xml`
2. `database/zzcd_params.tabl.xml`
3. `database/zbank_val_result.tabl.xml`
4. `database/zbank_val_audit.tabl.xml`
5. `database/zbank_val_sum.tabl.xml`
6. `database/zbank_val_vorgc.tabl.xml`

## Phase 2: Data Elements

1. `database/zzparam_area.dtel.xml`
2. `database/zzcd_params_para.dtel.xml`

## Phase 3: Message Class

1. `msg/zmc_bank_validation.mc.xml`

## Phase 4: Interfaces (No Dependencies)

1. `types/zif_bank_val_types.intf.abap`
2. `validator/zif_bank_val_validator.intf.abap`
3. `cfg/zif_bank_val_config.intf.abap`
4. `factory/zif_bank_val_factory_base.intf.abap`
5. `dao/zif_bank_val_dao_retrieval_log.intf.abap`
6. `dao/zif_bank_val_dao_dfkkrp.intf.abap`
7. `dao/zif_bank_val_dao_dpayh.intf.abap`
8. `dao/zif_bank_val_dao_dfkkcr.intf.abap`
9. `util/zif_cd_utility_params_sql.intf.abap`
10. `types/zif_bank_val_system_variable.intf.abap`
11. `cache/zif_cd_bank_val_cache.intf.abap`
12. `monitor/zif_cd_bank_val_metrics.intf.abap`
13. `audit/zif_cd_bank_val_audit.intf.abap`
14. `util/zif_cd_bank_val_bal_wrapper.intf.abap`
15. `util/zif_cd_bank_val_msg_wrapper.intf.abap`
16. `log/zif_cd_bank_val_logger.intf.abap`
17. `processor/zif_bank_val_processor.intf.abap`

## Phase 5: Exception Classes (Depend on Interfaces Only)

1. `exc/zcx_bank_validation_base.clas.abap`
2. `exc/zcx_bank_validation_enhanced.clas.abap`
3. `exc/zcx_bank_val_belnr_error.clas.abap`
4. `exc/zcx_bank_val_dfkkrp_error.clas.abap`
5. `exc/zcx_bank_val_dpayh_error.clas.abap`
6. `exc/zcx_bank_val_dfkkcr_error.clas.abap`
7. `exc/zcx_bank_val_retrieval_error.clas.abap`
8. `exc/zcx_invalid_test_setup.clas.abap`

## Phase 6: CDS Views (Depend on Tables)

1. `ddic/zcds_febep.viev.xml`
2. `rap/zcds_val_results.viev.xml`
3. `rap/zcds_val_summary.viev.xml`

## Phase 7: Constants and Base Utilities

1. `cfg/zcl_cd_bank_val_constants.clas.abap`
2. `util/zcl_cd_utility_params_sql.clas.abap`
3. `util/zcl_cd_util_para_factory.clas.abap`
4. `util/zcl_cd_utility_params_sql_inj.clas.abap`
5. `util/zcl_cd_bank_val_param_loader.clas.abap`
6. `helper/zcl_cd_bank_val_field_helper.clas.abap`

## Phase 8: Singleton Base Classes

1. `cache/zcl_cd_bank_val_cache.clas.abap`
2. `log/zcl_cd_bank_val_logger.clas.abap`
3. `cfg/zcl_cd_bank_val_config.clas.abap`
4. `monitor/zcl_cd_bank_val_metrics.clas.abap`
5. `audit/zcl_cd_bank_val_audit.clas.abap`
6. `security/zcl_cd_bank_val_auth.clas.abap`
7. `monitor/zcl_cd_bank_val_health_check.clas.abap`
8. `monitor/zcl_cd_bank_val_perf_profiler.clas.abap`
9. `config/zcl_cd_bank_val_customizing.clas.abap`
10. `util/zcl_cd_bank_val_syst_vars.clas.abap`
11. `util/zcl_cd_bank_val_bal_wrapper.clas.abap`
12. `util/zcl_cd_bank_val_msg_wrapper.clas.abap`

## Phase 9: Factory Classes (Depend on Classes They Create)

1. `factory/zcl_cd_bank_val_cache_factory.clas.abap`
2. `factory/zcl_cd_bank_val_logger_factory.clas.abap`
3. `factory/zcl_cd_bank_val_config_factory.clas.abap`
4. `factory/zcl_cd_bank_val_metrics_factory.clas.abap`
5. `factory/zcl_cd_bank_val_audit_factory.clas.abap`
6. `factory/zcl_cd_bank_val_syst_var_fact.clas.abap`
7. `factory/zcl_cd_bank_val_sys_date_factory.clas.abap`
8. `factory/zcl_cd_bank_val_bal_wrapper_factory.clas.abap`
9. `factory/zcl_cd_bank_val_msg_wrapper_factory.clas.abap`

## Phase 10: Additional Utilities (Depend on Factories, Exceptions)

1. `util/zcl_cd_bank_val_query_bldr.clas.abap`
2. `util/zcl_cd_bank_val_notif_service.clas.abap`
3. `msg/zcl_cd_bank_val_messages.clas.abap`
4. `msg/zcl_cd_bank_val_msg_formatter.clas.abap`

## Phase 11: DAO Classes (Depend on Interfaces, Exceptions, Utilities)

1. `dao/zcl_cd_bank_val_dao_factory.clas.abap`
2. `dao/zcl_cd_bank_val_dao_retr_log.clas.abap`
3. `dao/zcl_cd_bank_val_dao_dfkkrp.clas.abap`
4. `dao/zcl_cd_bank_val_dao_dpayh.clas.abap`
5. `dao/zcl_cd_bank_val_dao_dfkkcr.clas.abap`

## Phase 12: Test Doubles (Depend on Interfaces, DAOs)

*Note: Test doubles are only used in test classes and should be activated together with test classes in Phase 21.*

1. `dao/zcl_cd_bank_val_dao_retr_log_td.clas.abap`
2. `dao/zcl_cd_bank_val_dao_dfkkrp_td.clas.abap`
3. `dao/zcl_cd_bank_val_dao_dpayh_td.clas.abap`
4. `dao/zcl_cd_bank_val_dao_dfkkcr_td.clas.abap`

## Phase 13: Injector (Depend on Factories)

1. `injector/zcl_cd_bank_val_injector.clas.abap`

## Phase 14: Base Validator (Depend on Interfaces, Exceptions, Utilities)

1. `validator/zcl_cd_bank_val_validator_base.clas.abap`

## Phase 15: Validator Factory (Depend on Validators, Base Validator)

1. `factory/zcl_cd_bank_val_val_factory.clas.abap`

## Phase 16: Specific Validators (Depend on Base Validator, DAOs, Factories)

1. `validator/zcl_cd_bank_val_vorgc_166.clas.abap`
2. `validator/zcl_cd_bank_val_vorgc_168.clas.abap`
3. `validator/zcl_cd_bank_val_vorgc_195.clas.abap`
4. `validator/zcl_cd_bank_val_vorgc_275.clas.abap`
5. `validator/zcl_cd_bank_val_vorgc_468.clas.abap`
6. `validator/zcl_cd_bank_val_vorgc_575.clas.abap`
7. `validator/zcl_cd_bank_val_vorgc_581.clas.abap`

## Phase 17: Processor Factory

1. `factory/zcl_cd_bank_val_proc_factory.clas.abap`

## Phase 18: Processor Classes (Depend on Validators, Factories, Utilities)

1. `processor/zcl_cd_bank_val_processor.clas.abap`

## Phase 19: RAP Classes (Depend on Processor, Factories, Messages)

1. `rap/zcl_cd_bank_val_rap_behavior.clas.abap`
2. `rap/zcl_cd_bank_val_rap_service.clas.abap`
3. `rap/zcl_cd_bank_val_rap_saver.clas.abap`
4. `rap/zbp_bank_val_results.bdef.xml`

## Phase 20: Job Classes and Programs (Depend on Processor, Logger, Audit, Metrics)

1. `job/zcl_cd_bank_val_daily_job.clas.abap`
2. `job/zbank_val_archive_job.prog.abap`
3. `job/zbank_val_daily_job_scheduler.prog.abap`
4. `job/zbank_val_daily_report.prog.abap`
5. `report/zbank_val_business_report.prog.abap`

## Phase 21: Test Classes (Depend on All Classes)

Activate test classes after all main classes are activated. All test classes are in the `test/` directory.

*Note: Test doubles (including those in `dao/` folder with `_td` suffix and test doubles in `test/` folder, as well as `util/zcl_cd_util_para_test_dbl.clas.abap`) should be activated together with test classes here, as they are only used in test code.*

---

## Activation Guidelines

1. **Activate in order**: Follow phases sequentially from 1 to 21
2. **Complete each phase**: Ensure all objects in a phase activate successfully before proceeding
3. **Verify activation**: Check for syntax and activation errors after each phase
4. **Dependencies**: Each phase depends on previous phases - do not skip phases
5. **Test classes**: Can be activated last, after all production classes are active

---

## Notes

- **Factory classes**: Must be activated after the classes they create
- **Validators**: Must be activated after the validator factory
- **RAP classes**: Depend on processor and message classes
- **Job classes**: Depend on processor, logger, and audit classes
- **Database tables**: Must be activated first as they are prerequisites
- **Interfaces**: All interfaces are in Phase 4 (no dependencies). New interfaces added:
  - `log/zif_cd_bank_val_logger.intf.abap` - Logger interface
  - `processor/zif_bank_val_processor.intf.abap` - Processor interface
- **Factory Pattern**: All factories now return interface types (consistent design pattern)