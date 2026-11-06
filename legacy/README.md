# Legacy snapshot (superseded — reference only)

> **First principle:** keep the evidence you replace. Every parity statement in `ops-suite/docs/Legacy_Parity_Comparison.md` points at a file in this folder.

| Folder | Source upload | What it is | Superseded by |
|---|---|---|---|
| `bai_validators_v4/` | `BAI_Validators_ABAP75_Refactor_Pack_v4_FIX195_DOC1R.zip` (29 Dec 2025) | Latest per-code BAI validators (166, 166 coll, 168, 195, 255, 275, 466, 468, 575, 581) | `ops-suite/src/ebs` rules R04–R20 + `config/zcd_btc_*.csv` |
| `bai_validation_framework_complete4/` | `bai-validation-framework-COMPLETE_4.tar.gz` | Mass validator, factory, DB layer, ZBAI_* tables, message class | `ops-suite/src/core` + `ops-suite/src/ebs` engine |
| `morning_report_v1/` | `Morning_Report.zip` | Z_HEALTH_CHECK_REPORT_FINAL main program and table definitions | `ops-suite/src/hck` + `ZCD_MORNING_REPORT` |
| `SAP_Job_Schedule_Wiki.md` | Refactor pack | Control-M / SAP job schedule (Oct 2025) | Seed for `ZCD_JOB_CYCLE` / `ZCD_JOB_STEP` |

Not copied (iterations of the same material, Excel/VBA tools, UI5 controllers, NOC Fiori app on non-existent tables): the remaining ~500 files of the refactor pack, earlier COMPLETE 1–3 tars, `ZFIR_BANK_POST_VALIDATION_V2`, the IRIS and PCLM packages (used only as documentation and test-document templates).

**Known defects** in these files are listed in `ops-suite/docs/Legacy_Parity_Comparison.md` §2–§3 — do not transport this code.
