# Framework Directory Structure
## Complete Code Organization

---

## 📁 Root Directory Structure

All framework code is stored in the `src/` directory with the following organization:

```
src/
├── validator/          # Validation logic and validators
├── processor/          # Main processing classes
├── factory/            # Factory classes for dependency injection
├── injector/           # Dependency injector
├── dao/                # Data Access Objects (database abstraction)
├── exc/                # Exception classes
├── util/               # Utility classes and helpers
├── monitor/            # Monitoring and profiling tools
├── config/             # Configuration classes
├── cfg/                # Configuration classes (alternative)
├── log/                # Logging classes
├── security/           # Authorization classes
├── cache/              # Caching classes
├── audit/              # Audit trail classes
├── helper/             # Helper utilities
├── types/              # Type definitions
├── msg/                # Message classes
├── rap/                # RAP (Restful ABAP Programming) components
├── job/                # Background job classes
├── test/               # Unit test classes
├── ddic/               # Data Dictionary/CDS views
└── improvements/       # Improvement documentation
```

---

## 📂 Detailed File Locations

### **Validators** (`src/validator/`)
All validation logic for different VORGC codes:

- `zif_bank_val_validator.intf.abap` - Validator interface
- `zcl_bank_val_validator_base.clas.abap` - Base validator class
- `zcl_bank_val_vorgc_275.clas.abap` - VORGC 275 validator
- `zcl_bank_val_vorgc_575.clas.abap` - VORGC 575 validator
- `zcl_bank_val_vorgc_195.clas.abap` - VORGC 195 validator
- `zcl_bank_val_vorgc_166.clas.abap` - VORGC 166 validator
- `zcl_bank_val_vorgc_168.clas.abap` - VORGC 168 validator
- `zcl_bank_val_vorgc_468.clas.abap` - VORGC 468 validator
- `zcl_bank_val_vorgc_581.clas.abap` - VORGC 581 validator

---

### **Processor** (`src/processor/`)
Main orchestration and processing:

- `zcl_bank_val_processor.clas.abap` - Main processor class
- `zcl_bank_val_factory.clas.abap` - Old factory (legacy)
- `zcl_bank_val_bulk_processor.clas.abap` - Bulk processing optimizer
- `BULK_PROCESSING_USAGE.md` - Bulk processing guide

---

### **Factories** (`src/factory/`)
Factory classes for all components:

- `zif_bank_val_factory_base.intf.abap` - Base factory interface
- `zcl_bank_val_validator_factory.clas.abap` - Validator factory
- `zcl_bank_val_processor_factory.clas.abap` - Processor factory
- `zcl_bank_val_logger_factory.clas.abap` - Logger factory
- `zcl_bank_val_metrics_factory.clas.abap` - Metrics factory
- `zcl_bank_val_cache_factory.clas.abap` - Cache factory
- `zcl_bank_val_config_factory.clas.abap` - Config factory
- `zcl_bank_val_audit_factory.clas.abap` - Audit factory
- `FACTORY_INJECTOR_PATTERN.md` - Factory/injector documentation
- `USAGE_EXAMPLE.md` - Usage examples

---

### **Injector** (`src/injector/`)
Dependency injection:

- `zcl_bank_val_injector.clas.abap` - Central dependency injector

---

### **DAO (Data Access Objects)** (`src/dao/`)
Database abstraction layer:

**Interfaces:**
- `zif_bank_val_dao_retrieval_log.intf.abap` - Retrieval log DAO interface
- `zif_bank_val_dao_dfkkrp.intf.abap` - DFKKRP DAO interface
- `zif_bank_val_dao_dpayh.intf.abap` - DPAYH DAO interface
- `zif_bank_val_dao_dfkkcr.intf.abap` - DFKKCR DAO interface

**Implementations:**
- `zcl_bank_val_dao_retrieval_log.clas.abap` - Retrieval log DAO
- `zcl_bank_val_dao_dfkkrp.clas.abap` - DFKKRP DAO
- `zcl_bank_val_dao_dpayh.clas.abap` - DPAYH DAO
- `zcl_bank_val_dao_dfkkcr.clas.abap` - DFKKCR DAO
- `zcl_bank_val_dao_factory.clas.abap` - DAO factory

**Test Doubles:**
- `zcl_bank_val_dao_retrieval_log_test_double.clas.abap`
- `zcl_bank_val_dao_dfkkrp_test_double.clas.abap`
- `zcl_bank_val_dao_dpayh_test_double.clas.abap`
- `zcl_bank_val_dao_dfkkcr_test_double.clas.abap`

**Documentation:**
- `DAO_TESTING_GUIDE.md` - Testing guide
- `VALIDATOR_MIGRATION_EXAMPLE.md` - Migration example

---

### **Exceptions** (`src/exc/`)
Exception classes:

- `zcx_bank_validation_base.clas.abap` - Base exception class
- `zcx_bank_val_belnr_error.clas.abap` - BELNR error exception
- `zcx_bank_val_retrieval_error.clas.abap` - Retrieval error exception
- `zcx_bank_val_dfkkrp_error.clas.abap` - DFKKRP error exception
- `zcx_bank_val_dpayh_error.clas.abap` - DPAYH error exception
- `zcx_bank_val_dfkkcr_error.clas.abap` - DFKKCR error exception
- `zcx_bank_validation_enhanced.clas.abap` - Enhanced exception with context

---

### **Utilities** (`src/util/`)
Utility classes and helpers:

**Parameter Management:**
- `zcl_cd_utility_params_sql.clas.abap` - Parameter utility
- `zcl_cd_util_para_sql_factory.clas.abap` - Parameter factory
- `zcl_cd_util_para_injector.clas.abap` - Parameter injector
- `zcl_cd_util_para_test_double.clas.abap` - Parameter test double
- `zcl_bank_val_param_loader.clas.abap` - Parameter loader
- `zcl_bank_val_param_wrapper.clas.abap` - Parameter wrapper

**Builders & Handlers:**
- `zcl_bank_val_result_builder.clas.abap` - Result builder
- `zcl_bank_val_error_context_builder.clas.abap` - Error context builder
- `zcl_bank_val_exception_factory.clas.abap` - Exception factory
- `zcl_bank_val_retry_handler.clas.abap` - Retry handler
- `zif_bank_val_callable.intf.abap` - Callable interface

**Services:**
- `zcl_bank_val_notification_service.clas.abap` - Notification service
- `zcl_bank_val_cache_enhanced.clas.abap` - Enhanced cache
- `zcl_bank_val_query_builder.clas.abap` - Query builder

**Documentation:**
- `PARAMETER_USAGE_EXAMPLE.md`
- `PARAMETER_FACTORY_SUMMARY.md`
- `PARAMETER_MIGRATION_GUIDE.md`
- `BUILDER_PATTERN_USAGE.md`
- `ENHANCED_EXCEPTIONS_GUIDE.md`
- `RETRY_MECHANISM_USAGE.md`
- `NOTIFICATION_SERVICE_USAGE.md`

---

### **Monitoring** (`src/monitor/`)
Performance and health monitoring:

- `zcl_bank_val_metrics.clas.abap` - Metrics class
- `zcl_bank_val_performance_profiler.clas.abap` - Performance profiler
- `zcl_bank_val_health_check.clas.abap` - Health check service
- `PERFORMANCE_PROFILER_USAGE.md` - Profiler guide
- `HEALTH_CHECK_USAGE.md` - Health check guide

---

### **Configuration** (`src/cfg/` or `src/config/`)
Configuration management:

**In src/cfg/:**
- `zif_bank_val_config.intf.abap` - Config interface
- `zcl_bank_val_config.clas.abap` - Config implementation
- `zcl_bank_val_constants.clas.abap` - Constants (legacy - use parameters)

**In src/config/:**
- `zcl_bank_val_customizing.clas.abap` - Customizing class

---

### **Logging** (`src/log/`)
Application logging:

- `zcl_bank_val_logger.clas.abap` - Logger class

---

### **Security** (`src/security/`)
Authorization:

- `zcl_bank_val_auth.clas.abap` - Authorization class

---

### **Caching** (`src/cache/`)
Caching layer:

- `zcl_bank_val_cache.clas.abap` - Cache class

---

### **Audit** (`src/audit/`)
Audit trail:

- `zcl_bank_val_audit.clas.abap` - Audit class

---

### **Helpers** (`src/helper/`)
Helper utilities:

- `zcl_bank_val_field_helper.clas.abap` - Field normalization helper

---

### **Types** (`src/types/`)
Type definitions:

- `zif_bank_val_types.intf.abap` - Global type definitions

---

### **Messages** (`src/msg/`)
Message classes:

- `zmc_bank_validation.mc.xml` - Message class XML
- `zcl_bank_val_messages.clas.abap` - Message helper class

---

### **Database Tables** (`src/database/`)
All database table definitions (consolidated):

- `zbank_val_result.tabl.xml` - Validation results table (XL size)
- `zbank_val_audit.tabl.xml` - Audit log table (L size)
- `zbank_val_vorgc.tabl.xml` - VORGC customizing table (S size)
- `DATABASE_TABLES_INDEX.md` - Complete table documentation
- `INDEX_RECOMMENDATIONS.md` - Database index recommendations
- `FEBEP_FIELD_MAPPING.md` - FEBEP field mapping documentation
- `FEBEP_FIELD_UPDATE_GUIDE.md` - Field update guide
- `FEBEP_FIELD_VERIFICATION.sql` - Verification queries

---

### **RAP Components** (`src/rap/`)
Restful ABAP Programming model:

- `zcds_febep.viev.xml` - FEBEP CDS view
- `zcds_val_results.viev.xml` - Validation results CDS view
- `zcds_val_summary.viev.xml` - Validation summary CDS view
- `zbp_bank_val_results.bdef.xml` - Behavior definition
- `zcl_bank_val_rap_behavior.clas.abap` - RAP behavior handler
- `zcl_bank_val_rap_saver.clas.abap` - RAP saver class
- `zcl_bank_val_rap_service.clas.abap` - RAP service class

*Note: Database tables are now consolidated in `database/` folder*

---

### **Background Jobs** (`src/job/`)
Daily validation jobs:

- `zcl_bank_val_daily_job.clas.abap` - Daily job class
- `zbank_val_daily_report.prog.abap` - Executable report
- `zbank_val_daily_job_scheduler.prog.abap` - Job scheduler
- `zcl_bank_val_daily_job.testclasses.abap` - Job unit tests
- `DAILY_VALIDATION_QUICK_START.md` - Quick start guide

---

### **Unit Tests** (`src/test/`)
Comprehensive unit test classes:

**Validator Tests:**
- `zcl_bank_val_vorgc_275.testclasses.abap`
- `zcl_bank_val_vorgc_275_enhanced.testclasses.abap`
- `zcl_bank_val_vorgc_575.testclasses.abap`
- `zcl_bank_val_vorgc_166.testclasses.abap`
- `zcl_bank_val_vorgc_168.testclasses.abap`
- `zcl_bank_val_vorgc_195.testclasses.abap`
- `zcl_bank_val_vorgc_468.testclasses.abap`
- `zcl_bank_val_vorgc_581.testclasses.abap`

**Core Component Tests:**
- `zcl_bank_val_config.testclasses.abap`
- `zcl_bank_val_factory.testclasses.abap`
- `zcl_bank_val_processor.testclasses.abap`
- `zcl_bank_val_logger.testclasses.abap`
- `zcl_bank_val_metrics.testclasses.abap`
- `zcl_bank_val_cache.testclasses.abap`
- `zcl_bank_val_field_helper.testclasses.abap`
- `zcl_bank_val_param_loader.testclasses.abap`

**Test Doubles:**
- `zcl_bank_val_logger_test_double.clas.abap`
- `zcl_bank_val_config_test_double.clas.abap`

**Documentation:**
- `COVERAGE_ANALYSIS.md`
- `COMPREHENSIVE_TEST_COVERAGE.md`

---

### **Improvements Documentation** (`src/improvements/`)
Improvement documentation:

- `ENHANCEMENTS.md` - Enhancement documentation
- `IMPROVEMENTS_SUMMARY.md` - Improvements summary
- `IMPROVEMENTS_COMPLETE.md` - Completed improvements
- `ADDITIONAL_IMPROVEMENTS_COMPLETE.md` - Additional improvements
- `ALL_IMPROVEMENTS_COMPLETE.md` - All improvements summary
- `FACTORY_INJECTOR_COMPLETE.md` - Factory/injector summary
- `NEXT_STEPS_AND_RECOMMENDATIONS.md` - Future recommendations

---

### **DDIC/CDS Views** (`src/ddic/`)
Data Dictionary and CDS views:

- `zcds_febep.viev.xml` - FEBEP CDS view

---

### **Root Documentation** (`src/`)
Framework-level documentation:

- `FRAMEWORK_REVIEW.md` - Comprehensive framework review

---

## 📊 File Count Summary

### By Category:

- **Validators**: ~9 files
- **Processors**: ~4 files
- **Factories**: ~9 files
- **DAO Classes**: ~13 files
- **Exceptions**: ~7 files
- **Utilities**: ~18 files
- **Monitoring**: ~5 files
- **Configuration**: ~4 files
- **Infrastructure**: ~5 files (logging, security, cache, audit)
- **RAP Components**: ~8 files
- **Background Jobs**: ~5 files
- **Unit Tests**: ~20+ files
- **Documentation**: ~30+ files

**Total**: ~140+ files

---

## 🔍 Quick Reference: Finding Code

### To find a specific component:

1. **Validators**: `src/validator/zcl_bank_val_vorgc_*.clas.abap`
2. **DAO Classes**: `src/dao/zcl_bank_val_dao_*.clas.abap`
3. **Factories**: `src/factory/zcl_bank_val_*_factory.clas.abap`
4. **Exceptions**: `src/exc/zcx_bank_val*.clas.abap`
5. **Utilities**: `src/util/zcl_bank_val_*.clas.abap`
6. **Tests**: `src/test/*.testclasses.abap`
7. **Documentation**: `src/*/*.md`

### Key Entry Points:

- **Main Processor**: `src/processor/zcl_bank_val_processor.clas.abap`
- **DAO Factory**: `src/dao/zcl_bank_val_dao_factory.clas.abap`
- **Injector**: `src/injector/zcl_bank_val_injector.clas.abap`
- **Config**: `src/cfg/zcl_bank_val_config.clas.abap`
- **Main Factory**: `src/factory/zcl_bank_val_validator_factory.clas.abap`

---

## 📝 File Naming Conventions

1. **Classes**: `zcl_bank_val_*.clas.abap`
2. **Interfaces**: `zif_bank_val_*.intf.abap`
3. **Exceptions**: `zcx_bank_val*.clas.abap`
4. **Test Classes**: `*.testclasses.abap`
5. **Programs**: `*.prog.abap`
6. **CDS Views**: `*.viev.xml`
7. **Tables**: `*.tabl.xml`
8. **Behaviors**: `*.bdef.xml`
9. **Message Classes**: `*.mc.xml`
10. **Documentation**: `*.md`

---

## 🌳 Complete Directory Tree

```
src/
│
├── validator/          (9 files - all VORGC validators)
├── processor/          (4 files - main processing)
├── factory/            (9 files - all factories)
├── injector/           (1 file - dependency injector)
├── dao/                (13 files - DAO layer + test doubles)
├── exc/                (7 files - exception classes)
├── util/               (18 files - utilities + docs)
├── monitor/            (5 files - monitoring tools)
├── cfg/                (3 files - configuration)
├── config/             (1 file - customizing)
├── log/                (1 file - logging)
├── security/           (1 file - authorization)
├── cache/              (1 file - caching)
├── audit/              (1 file - audit)
├── helper/             (1 file - field helper)
├── types/              (1 file - type definitions)
├── msg/                (2 files - messages)
├── rap/                (8 files - RAP components)
├── job/                (5 files - background jobs)
├── test/               (20+ files - unit tests)
├── ddic/               (1 file - CDS view)
├── improvements/       (7 files - documentation)
│
└── FRAMEWORK_REVIEW.md
└── FRAMEWORK_DIRECTORY_STRUCTURE.md (this file)
```

---

*Last Updated: 2024*
