# Changelog

Changes of the ops suite (`ops-suite/`) from 2026-11-15 on; earlier changes are in the modification logs of the
objects, `docs/Class_Purpose_and_Modification_Log.md`, `docs/Implementation_Order.md` and `docs/history/`.

## 2026-11-16 - build R: pilot acceptance items of the five open daily controls (review finding 5)

Every check is built and delivered **inactive**; the open facts, activation steps and QA1 tests are in
`docs/Pilot_Acceptance.md`, the VERIFY items V240-V258 in `docs/VERIFY_Suite.md` §5, the control state in
`config/control_seed.md` §2c.

- **ECT pending (P3):** morning report check `C_ECT_PENDING` (`ZCL_CD_HCK_C_ECT_PENDING`) - count and age of the
  cheques whose latest valid status in `ZCD_CHECK_HIST` (`STATE` = space) is a pending `ZECT_STATUS` value (parameter,
  placeholder) and that are still open on `DFKKCR` (`BNKDT` initial, `STATE` blank); evidence cheque number, payment
  document, company code, amount, currency, age, deadline.
- **Missing check IDs (P6):** check `C_CHQ_NO_ID` (`ZCL_CD_HCK_C_CHQ_NO_ID`) - cheque payments of yesterday's runs
  without a cheque register row with a cheque number; one anti-join DPAYH / DFKKCR in the new data access
  `ZIF_CD_HCK_CHEQUE_DAO` / `ZCL_CD_HCK_CHEQUE_DAO` (fields of the reference system; factory getter
  `GET_CHEQUE_DAO`, injector `INJECT_CHEQUE_DAO`); cheque methods a parameter (placeholder).
- **Exposure:** `ZIF_CD_HCK_CHEQUE_TYPES`, `ZCL_CD_HCK_EXPOSURE` - count, amount, oldest age and deadline per currency
  (`EXPOSURE_PER_CURRENCY`, information), labelled context (deadline, age, control, evidence) on every item finding.
- **BlackLine (P4) and returns notification (P7):** FMON check `ZCL_CD_FMON_CHK_DUE_FILE` - an outbound file due on the
  n-th business day of the month (factory calendar) or on a returns day, by the due time of its DEADLINE row: missing,
  late, empty, or not evaluated (never green). Rows (`config/fmon_seed.md`, inactive): interfaces
  `BLACKLINE_COLL_OUT`, `BLACKLINE_DISB_OUT` (replace the example `BLACKLINE_OUT`), `RETURNS_NOTIF_OUT`, their DEADLINE
  rows, checks `F_BLKLINE`, `F_RETNOTIF`. No existing FMON class changed.
- **Base-rejected items (P2):** `ZCL_CD_COLL_C_NO_ANSWER` (R2) and `ZCL_CD_COLL_C_REFUND` (R3) complete in `src/core`
  with `ZCL_CD_COLL_RULES` and `ZIF_CD_COLL_TYPES`; sources and limits are the new parameters `COLL_*` (area CD_OPS,
  name prefix `COLL_` in `ZCL_CD_OPS_FACTORY=>PARAM_PREFIXES`, delivered blank); the skeleton folder of the scaffold
  removed, `config/processes/CD_COLL_BASE_REQ_LIFE.json` names the classes without skeleton.
- Covered-check rows (`config/control_checks.csv`): `ECT_PENDING` → `C_ECT_PENDING`, `MISSING_CHECK_IDS` →
  `C_CHQ_NO_ID`, `BLACKLINE` → `F_BLKLINE`, `RETURNS_NOTIF` → `F_RETNOTIF`; guidance texts of the four controls.
- Messages ZCD_OPS 900-921; parameter seed class regenerated; `config/hck_seed.md` rows and thresholds.

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
