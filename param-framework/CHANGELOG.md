# Changelog

All notable changes of the parameter framework (`param-framework/` in jaideep247/bai).

## [Unreleased]

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
