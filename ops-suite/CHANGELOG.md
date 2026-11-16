# Changelog

Changes of the ops suite (`ops-suite/`) from 2026-11-15 on; earlier changes are in the modification logs of the
objects, `docs/Class_Purpose_and_Modification_Log.md`, `docs/Implementation_Order.md` and `docs/history/`.

## 2026-11-15 - build L: source per purpose and typed product mapping tables

Product review 2026-11-15: a typed product mapping table behind the existing reader contract is the portable route; the
FI-CA customer posting area stays an adapter where its layout fits (user decision 2026-11-08 kept for those purposes).
**User decision 2026-11-15: ZBTM, including its disposition, uses the typed table** (`POSTAREA_SOURCE_BTM` ships `T`).

### Added
- Source per purpose: parameters `POSTAREA_SOURCE_RSN` / `_PMC` / `_BTM` / `_BTR` (CHAR `[PT]`, developer-owned;
  delivered P, P, T, T - ZRSN / ZPMC fit TFK033D's 8 keys, 6 results, CHAR 12; ZBTM has 7 results and keys of 35 / 15,
  ZBTR keys of 35 and a role of 15) and the active mapping version `POSTAREA_VERSION_*` (INT 1-9999, delivered 1, not
  developer-owned: rollback = the previous number in QA1 / PS4).
- Typed tables `ZCD_OPS_MAPRSN`, `ZCD_OPS_MAPPMC`, `ZCD_OPS_MAPBTM`, `ZCD_OPS_MAPBTR` (delivery class C, key `VERSION` +
  the layout keys, typed results, ZBTM `DISPOSITION` required) with drafts and the entities `MapReason`,
  `MapMethodClass`, `MapBtcCode`, `MapBtcRole` of the core configuration app `ZUI_CD_OPS_CFG` (generated; `*` refused
  where the reader cannot apply it - new generator check kind `generic` in `tools/abaptools/rap_generate.py`, message 427;
  duplicate key sets refused by the table key).
- `ZIF_CD_OPS_PAMAP_DAO` / `ZCL_CD_OPS_PAMAP_DAO` (typed repository behind the same reader: entries in the posting area
  shape, so `ENTRIES` / `FIND` / `AREA` and every consumer are unchanged), `ZCL_CD_OPS_POSTAREA_LAYOUT` (layouts moved
  from `ZCL_CD_OPS_CFG_CHECKS`; fit to TFK033D), `ZIF_CD_OPS_POSTAREA~SOURCE` / `~VERSION`, factory `GET_TYPED_DAO`,
  injector `INJECT_TYPED_DAO` / `RENEW_READER`, in-memory double for both sources (`ADD_TYPED`).
- Migration: report `ZCD_OPS_POSTAREA_COPY` / `ZCL_CD_OPS_POSTAREA_COPY` - copies the FQC0 entries of a purpose
  (TFK033D read-only) into an unused version; test mode default; ZBTM copied as `POSTED`.
- Configuration check: source P with a layout TFK033D cannot hold (440 / 441, nothing read), duplicate key sets (442),
  blank ZBTM disposition (443), empty active version (444); messages 445-447 of the migration.
- Tests: precedence on the typed source, P / T parity, misfit refused, version rollback, duplicates, disposition, the
  typed repository (OSQL doubles), the layouts and the migration.
- `docs/VERIFY_Suite.md` §5: V190-V192.

### Changed
- `ZCL_CD_OPS_POSTAREA_DAO` no longer reads `TFK033D-FUN07` (V161 closed, row removed from `ddic/open_fields.csv`);
  `ZIF_CD_OPS_POSTAREA_TYPES` without `FUN08`; `ZI_CD_PayMethodCls` reads the typed table when `POSTAREA_SOURCE_PMC` = T
  (`ZI_CD_PostAreaCfg` with source and version); `config/postarea_zbtm.csv` is the seed of version 1 of
  `ZCD_OPS_MAPBTM`, every row with its disposition (`POSTED` / `NOT_POSTED`); `GC_DISPOSITION-POSTED`.
- Tests of the ZBTM / ZBTR consumers add typed rows (EBS configuration DAO, HCK runtime / reconciliation DAOs).
- `docs/FICA_Posting_Areas.md` §0 / §6 (source per purpose, typed tables, validations, versions, rollback, migration),
  `Implementation_Order.md` (build L), `Release_Readiness.md`.

## 2026-11-15 - returned amount from DFKKRP-BETRR

- `DFKKRP` has no `BETRW` (user); the returned amount of a returns lot item is `BETRR`. `ZCL_CD_EBS_SAP_DAO=>GET_RETURN_ITEMS`
  (morning report `A_INFLIGHT`, payment trace) reads it; test double and type comments updated. V160 closed, row removed
  from `ddic/open_fields.csv`.

## 2026-11-15 - cheque status from DFKKCR-STATE

- `DFKKCR` has no `CRSTATUS` (user); the cheque status is `STATE` (B cashed, V voided, blank open). `ZCL_CD_EBS_SAP_DAO`,
  `ZCL_CD_OPS_TRACE_DAO`, the trace engine and their types read `STATE`; rule R07C forbids `V` by default (legacy 99 =
  cancelled), BTC rule `BAI255D` PARAM1 `V`; tests on `V` / `B`. V159 closed, row removed from `ddic/open_fields.csv`.

## [Unreleased] - 2026-11-15 (build I: field references checked against a reference system)

Evidence: `ddic/a4h` - the dictionary of 46 SAP standard tables of a reference system (S/4HANA 2025 with FI-CA). A
field present there is used (noted as seen on the reference system); a field missing there is treated as wrong.

### Added
- Portable check `ddic_fields` (`tools/portable_checks.py`): the link registry, process catalogue and code field
  references (ABAP SQL, typed structures, CDS) exist in every table export of `ddic/`
  (`tools/abaptools/ddic_export.py`); `ddic/open_fields.csv` lists the fields that stay read under a VERIFY item.
- `docs/VERIFY_Suite.md` §4: V159 (`DFKKCR-CRSTATUS`), V160 (`DFKKRP-BETRW`), V161 (`TFK033D-FUN07`, ZBTM layout).
- `docs/Performance_Review.md` §17: the indexes of the reference system for the suite's access paths
  (recommendations only).

### Fixed
- `DPAYH-BUKRS` / `DPAYH-PYMET` do not exist: the paying company code `BBUKR` and the method `RZAWE` are read
  (under the old result names) in `ZCL_CD_OPS_PAY_OUTCOME_DAO`, `ZCL_CD_JOB_DAO`, `ZCL_CD_HCK_RUNTIME_DAO`,
  `ZCL_CD_HCK_RECON_DAO`, `ZCL_CD_HCK_DOCCHG_DAO`, `ZI_CD_PayLifeRun`, `ZI_CD_PayWorkItem`; test doubles,
  `config/payment_model/mapping.json` (regenerated `ZI_CD_PaymFact` notes), `config/hck_seed.md` (`B_VOL_PAYRUN`).
- The G/L transfer totals were read from `DFKKSUMC` (the reconciliation key and its status, without company code,
  account, currency, posting date or amount): `ZCL_CD_HCK_DAO` (G/L transfer gaps), `ZCL_CD_HCK_RECON_DAO=>
  GET_FICA_DAYS` (amount signed by `SHKZG`, H = credit), `ZCL_CD_OPS_TRACE_DAO=>GET_SUMMARY_KEYS` and the batch
  adapter `ZI_CD_LedgBatch` now read `DFKKSUM`; OSQL doubles, message 732, trace source table constant
  `GC_TABLE-DFKKSUM`; a credit total in the test of `GET_FICA_DAYS`.
- The returns lot `DFKKRK` was joined on `OPBEL`, which it does not have: joined on its key `KEYR1`
  (`ZCL_CD_EBS_SAP_DAO=>GET_RETURN_ITEMS`, `ZI_CD_ReturnItem`).
- DPAYH test doubles set `PYORD` / `PYKEY` (not DPAYH fields): they set the key field `PAYNO`.
- `ZCL_CD_OPS_POSTAREA_DAO` no longer reads `TFK033D-FUN08` (not a field; nothing used it).

### Changed
- Link registry overlay and process catalogue outputs regenerated with the product's corrected FICA layer
  (`FICA_SUMMARY_TOTALS`, `DPAYH-BBUKR` / `RZAWE`).
- Documents record the reference system's facts on the VERIFY items they hold (`USAA_Known_Tables.md` V101 / V102 /
  V107 / V108, `VERIFY_Suite.md` V87 / V88, `Release_Readiness.md` incl. V68, `HCK_MORNING_REPORT.md` §15,
  `Payment_Trace.md` §9, `FICA_Posting_Areas.md`); `ddic/README.md` lists the `a4h` folder.
