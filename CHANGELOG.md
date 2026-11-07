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
