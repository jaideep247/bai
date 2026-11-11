# Changelog

All notable changes of the parameter framework (`param-framework/` in jaideep247/bai).

## [Unreleased] - 2026-11-11 (customer wording)

Release constant unchanged: no ABAP object changed.

### Changed
- `config/customer_terms.txt`: the same terms as the operations framework's list (more middleware, feeder,
  bank, finance-system, field and status names, the consumer's object prefixes) in the shared format with
  the flags `case`, `prefix` and `text` (check `customer_terms` of the shared tools).

## [Unreleased] - 2026-11-10 (tooling)

Release constant unchanged (`GC_VERSION` 1.1.0): no ABAP object changed.

### Changed
- Tooling: the serializer and the common house checks are the repository's shared tools
  (`../tools/abaptools`); `tools/` holds thin wrappers (message rows with a constant column are the
  setting `message_class.columns = 3` of `config/repository.json`). Generated XML unchanged.
- Checks added: `method_names`, `abapgit_up_to_date`, `customer_terms` (`config/customer_terms.txt`) and
  `packaging` (no file names the operations framework's or a consumer's folder; this component depends
  on SAP standard only). README and ONBOARDING reworded accordingly.

## [1.1.0] - 2026-11-10

### Added
- `ZIF_CA_PARAM_TYPES=>GC_VERSION` (`1.1.0`): release of the framework; consumers compare it with the
  release they need (the operations framework ZCA_OPS needs 1.1.0 and checks it at startup).
- `ZIF_CA_PARAM=>CHECK_AREA` / `ZCL_CA_PARAM`: the area exists and is active (messages 001 / 002, same
  buffer as the reads) - ZCA_PARAM_AREA is the one area register of ZCA_OPS and its consumers (user
  decision 2026-11-10). Test `check_area_known_and_active`.
- Object class `ZCA` and field `ZCA_PARAR` are also used by the operations framework's object `ZCA_OPS`
  (defined there, `ops-framework/config/authorizations.json`).

### Changed
- `ZCL_CA_PARAM`: a conversion error is kept as `PREVIOUS` of the raised `ZCX_CA_PARAM`
  (helper `RAISE` has `IX_PREVIOUS`).
- `ZCL_CA_PARAM_SYSTEM=>READ_CLIENT` stays fail closed but returns the error text of the
  business configuration API (`TY_CLIENT-CUST_REASON`); the app shows it with message 048
  instead of 044 (`ZCL_CA_PARAM_MAINT=>CHECK_CONFIG_CHANGE`, test `client_check_reason_shown`).

## [1.0.0] - 2026-11-07 (first release, never activated)

### Added
- Repository scaffold: abapGit settings (starting folder `/src/`, folder logic PREFIX),
  abaplint configuration (v758), CI workflow (`ci/abaplint.yml`), house checks
  (`tools/checks.py`) and the abapGit serializer (`tools/abapgit_serialize.py`) with tests.
- DDIC: tables ZCA_PARAM_AREA, ZCA_PARAM_DEF, ZCA_PARAM_VAL (delivery class C, table
  logging, foreign keys), draft tables, domains and data elements, message class
  ZCA_PARAM, authorization object ZCA_PARAM (field ZCA_PARAR, ACTVT).
- Read API `ZIF_CA_PARAM` (get_value, get_int, get_dec, get_bool, get_date, get_time,
  get_list, get_range, is_set, get_definition, refresh), types `ZIF_CA_PARAM_TYPES`,
  checked exception `ZCX_CA_PARAM`, validation rules `ZCL_CA_PARAM_VALIDATOR`.
- Read logic `ZCL_CA_PARAM` (validation on every read, per-area buffer with refresh),
  data access `ZCL_CA_PARAM_DAO`, in-memory `ZCL_CA_PARAM_DAO_MEM`, test data builder
  `ZCL_CA_PARAM_BUILDER`, `ZCL_CA_PARAM_FACTORY` / `ZCL_CA_PARAM_INJECTOR`.
- Maintenance app: RAP BO `ZR_CA_PARAMAREA` (Area -> Definition -> Value, managed, draft),
  projections, UI annotations, display DCLs, value helps, service definition
  `ZUI_CA_PARAM`; gate `ZCL_CA_PARAM_MAINT`, policy `ZCL_CA_PARAM_MAINT_POLICY`, system
  boundary `ZIF_CA_PARAM_SYSTEM` / `ZCL_CA_PARAM_SYSTEM`.
- ABAP Unit: 104 tests in six test classes (not yet executed - `docs/VERIFY.md` A19).
- Documentation: README, DESIGN, ONBOARDING, OPERATIONS, VERIFY.

### Offline evidence (2026-11-07)
- abaplint 2.120.92 (`abaplint.json`, v758): 0 issues.
- `tools/checks.py`: 9/9 checks passed; tool tests green; serializer check up to date.
- Not proven offline: activation, DDIC, RAP runtime, ABAP Unit, ATC (`docs/VERIFY.md`).
