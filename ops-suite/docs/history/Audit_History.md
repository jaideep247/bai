# Audit history — findings, decisions and where they live now

> **First principle:** every finding keeps one line: what was decided, where the answer lives in the current suite, and what is still open.
> **Analogy:** a ship's logbook index — the voyage is over, but each entry still points to the chart and the part that was changed.

Sources consolidated here (2026-11-07): the principal consultant review and its runtime and EBS rule follow-ups (2026-11-06), and the static repository audit A01–A105 (snapshot `8cdfdce`, later checkpoint for A100–A105). Nothing listed was executed in SAP; release gates are in `../Release_Readiness.md`.

Decision key: **Fixed** — the defect existed and the code changed; **Decision** — business decision implemented; **Not applicable** — the finding does not hold for the suite; **Withdrawn** — the fix belonged to a capability removed with the read-only scope (user decision 2026-11-07: no pre-posting path, kill switch, posting disposition, blocked-line release, blocks-posting flag, FEBAN / FPCPL navigation or webhook channel).

## 1. Principal consultant review (first framework, answered for `ops-suite/`)

| Id | Decision | Where it lives now | Open residual |
|---|---|---|---|
| 1a Submodule gitlinks | Fixed | Repository root; history in `legacy/README.md` | — |
| 1b No abapGit metadata | Fixed | `/.abapgit.xml`, `package.devc.xml` per folder, object XML from `tools/abapgit_serialize.py` | First pull in DV1 (gate 1) |
| 1c Redundant root documents | Fixed | `legacy/framework_v1_docs/` | — |
| 3.1 FEBEP key | Not applicable | Lines keyed `FEB<KUKEY>/<ESNUM>` (`ZCL_CD_EBS_SRC_FEB`) | — |
| 3.2a Unique sorted keys on non-unique fields | Not applicable | DAO targets are STANDARD tables | — |
| 3.2b ZTNUM per house bank, DOC1R not unique | Fixed | `ZCL_CD_EBS_RULE_BASE=>REGISTER_MATCH` scoped to the house bank account; DPAYH without proposal runs | `XVORL` VERIFY-DDIC |
| 3.3 Factory proliferation, global doubles | Not applicable | One factory + injector per area; local `LTD_*` doubles | — |
| 3.4 Constants class, wrapped booleans | Not applicable | Types interface per area (`DEVELOPMENT_STANDARDS.md` §3) | — |
| 3.5a Custom cache | Fixed in part | Customizing tables fully buffered; one parameter snapshot per run | — |
| 3.5b Unbounded memory | Fixed | `EBS_RESULT_MAX` in `ZCL_CD_EBS_ENGINE` | — |
| 3.6 RAP LUW | Not applicable | LUW rule in `../ALERTING.md` (never dispatch from a RAP handler) | — |
| 3.7 Exceptions for business outcomes | Not applicable | Business failures are findings; `ZCX_CD_OPS_ERROR` for technical failure | — |
| B-P0 Rule that raises allowed posting | Fixed; posting part withdrawn | `PLUGIN_ERROR` with action BLOCK, lines unevaluated (`ZCL_CD_EBS_ENGINE`, A66) | — |
| B-P1 EVENT_NO collision, failed INSERT, partial persistence | Fixed | `ZCL_CD_FMON_DAO=>INSERT_EVENT` bounded retry; store `rollback( )`; run header committed at start | QA1 parallel-run case |
| B-P2 Alerts before the durable commit | Fixed | FMON, HCK and EBS commit before `dispatch( )` | — |
| B-P2 `VALUE #( … OPTIONAL )` with sy-subrc | Fixed | `READ TABLE … WITH TABLE KEY` | — |
| C R07 / R07L / R07R / R07C first-row reads | Fixed | Any row with an allowed status passes; R07C fails on any cancelled row (`ZCL_CD_EBS_R_*`) | — |
| C R12 counting | Decision (documented) | `ZCL_CD_EBS_R_R12_*`, parity D12 | — |
| C House-bank filter | Fixed | HOUSE_BANK_AMBIGUOUS (`ZCL_CD_EBS_RULE_BASE`) | DFKKCR key VERIFY-DDIC |
| C R18 silent skip | Fixed | GL_ACCOUNT_NOT_MAPPED | — |
| C R09 across packages | Not applicable | A package holds whole statements; repeats are S07 | — |

## 2. Static repository audit A01–A105

| Id | Decision | Where it lives now | Open residual |
|---|---|---|---|
| A01 | Fixed | CI pinned to abaplint 2.120.92 (`.github/workflows/abaplint.yml`) | — |
| A02 | Withdrawn — pre-posting BAdI path removed | `../Release_Readiness.md` (read-only scope) | Enforcement is a later phase with its own design |
| A03 | Fixed | Configuration gaps RULE_GROUP_EMPTY / RULE_UNUSABLE, NONE rows (`ZCL_CD_EBS_ENGINE`, `ZCL_CD_EBS_CFG_DAO`) | NONE rows maintained for every rule-free group |
| A04 | Fixed | Version-checked registry save, PERSIST_CONFLICT (`ZCL_CD_FMON_DAO=>SAVE_FILES`) | FOR UPDATE in the OSQL environment VERIFY-ADT |
| A05 | Fixed | SQL error ends the FMON run failed (PERSIST_ERROR); unique index SRC | Index created on first pull |
| A06 | Fixed | Stale running runs, CHECKS_NOT_CONFIGURED (`ZCL_CD_HCK_ENGINE`) | Thresholds per area with the batch schedule |
| A07 | Fixed | Company code in the cheque match (`EBS_DFKKCR_BUKRS_FIELD`) | DFKKCR company-code field VERIFY-DDIC |
| A08 | Fixed | R12 on distinct register rows | — |
| A09, A10 | Fixed | Any-row semantics of R07 / R07L / R07R | — |
| A11 | Decision | BAI166D retrieval-log chain (R04, R07L, R07) | Retrieval status field (parity C4) VERIFY-DDIC |
| A12, A13, A19–A21, A29–A31, A36, A37, A53–A55, A70–A84 | Not applicable — legacy / first-framework code, not deployed | `../Legacy_Parity_Comparison.md` (comparison baseline only) | — |
| A14 | Decision | Rule R22 cross-statement duplicates (`EBS_DUP_LOOKBACK_DAYS`) | Statements without house bank identity not checked by R22 |
| A15 | Fixed | Nearest predecessor by date and number, canonical account key | — |
| A16 | Fixed | GL_ACCOUNT_NOT_MAPPED | — |
| A17 | Fixed | Durable alert claim, intent key, unique index INT (`ZCL_CD_OPS_ALERT_ROUTER`, `ZCL_CD_OPS_ALERT_DAO`) | A claim orphaned by a dump blocks its intent until cleared |
| A18 | Fixed | Time budget `ZCL_CD_HCK_BUDGET` | One long SQL cannot be interrupted |
| A22 | Fixed | ZCD_OPS activity 16 in every report | — |
| A23 | Fixed | Retention purge (400 days), exceptions app with four-eyes waivers | — |
| A24 | Fixed | ATC step requires a complete run (`tools/portable_checks.py`) | — |
| A25 | Fixed | Canonical account key (S01, S04, S07, R18) | — |
| A26 | Fixed | Map disposition NOT_POSTED for sweeps 275 / 575, honoured by S10 | — |
| A27 | Withdrawn — blocks-posting flag removed | Findings carry the configured action | — |
| A28 | Fixed (FEB part corrected 2026-11-06) | R05 reason from returns lot DFKKRP-RLGRD / NOC lot DFKKNRP-FLGRD; file source maps the NACHA code | RLGRD, FLGRD / INFOF VERIFY-SE11 |
| A32 | Fixed | POSTING_RULE_UNRESOLVED (R15) | — |
| A33 | Fixed | CURRENCY_MISSING, ACCOUNT_CURRENCY_MISSING | — |
| A34 | Fixed | Unknown sign kept unknown, gross totals in S02 | — |
| A35 | Fixed | Statement-keyed line access | No runtime measurement offline |
| A38 | Fixed | Truncated lot scan derives nothing (LOT_SCAN_TRUNCATED) | — |
| A39 | Fixed | Payment-level ACK de-duplication, cumulative counts, ACK_KNOWN | A bank's downward correction arrives as a NACK |
| A40 | Fixed | SLA met only by its own stage; later stages INFERRED | — |
| A41 | Fixed | `FMON_AGE_BASIS`; calendar failure = age unknown | CORRECT_OPTION of the calendar FM VERIFY-DDIC |
| A42 | Fixed | Job cycle by program / variant, deciding attempt, JOB_READ_CAPPED | Real job names from the Control-M export |
| A43 | Fixed | G/L gaps per FIKEY and company code | AWTYP / AWKEY length VERIFY-DDIC |
| A44 | Fixed | Job read cap 5000 with finding | — |
| A45 | Fixed | No silent success: BCS result, partial SLG1 log = P | BCS / BAL not executed offline |
| A46 | Fixed | Escalation over consecutive runs, ESC_OVERRIDE | ESC_OVERRIDE values per rule |
| A47 | Fixed | Amount with currency semantics in the HCK cube | DECFLOAT34 semantics VERIFY-ADT |
| A48 | Fixed | git-sync pulls by default, push opt-in (`tools/git-sync`) | PowerShell not run in the build container |
| A49 | Fixed | File identity includes the business date; FILE_REF_AMBIGUOUS | Non-generic adapters supply the business date |
| A50 | Fixed | Open-file evaluation bounded by the run date | — |
| A51 | Fixed | Approved tables ZCD_FMON_TABWL, S_TABU_NAM at the read boundary | Seeds per configured table; OSQL redirect of dynamic FROM VERIFY-ADT |
| A52 | Fixed | MALFORMED_SOURCE_ROW quarantine, half-open timestamp window | — |
| A56 | Fixed | DAO rebuilds HCK queries through the builders | — |
| A57 | Fixed | Length-prefixed hash version 2 (`ZCL_CD_HCK_CANONICAL`) | Baselines retaken once after transport |
| A58 | Fixed | Flat-baseline tolerance `HCK_FLAT_TOL_PCT` | Tolerance tuned per metric |
| A59, A60 | Fixed | One history point per finished run, as of the report date | — |
| A61 | Fixed | CSV written to a temp file first (`ZCL_CD_HCK_DATASET`) | No atomic rename in DATASET |
| A62 | Fixed | Plug-ins created only after the RTTI interface check (`ZCL_CD_OPS_FACTORY=>GET_PLUGIN`) | — |
| A63 | Fixed | Severity-ordered alert cap | — |
| A64 | Fixed (EBS posting part withdrawn) | Parameter snapshot per run (`refresh_params` at `start_run`) | — |
| A65 | Fixed | Document-key width from the key type; KEY_LENGTH_CONFIG, REF_TOO_LONG, REF_FORMAT | OPBEL / AUGBL / DOC1R CHAR 12 VERIFY-DDIC |
| A66 | Fixed | Unevaluated lines, technical circuit breaker | — |
| A67 | Fixed | Complete alert summaries beside the display cap | — |
| A68 | Fixed | Run status N (NO_DATA, grey), `EBS_EMPTY_FEED_OK` | — |
| A69 | Fixed | Server file read without ignored conversion errors (messages 530, 531) | Latin-1 file and unterminated last line in QA1 |
| A85 | Withdrawn — posting disposition removed | — | — |
| A86 | Fixed | TRAILER_FIELD_MISSING; a declared zero is compared | — |
| A87 | Fixed | Days past due only for open items | — |
| A88 | Fixed | Metric kind and weight in ZCD_HCK_METRIC; cube never sums mixed kinds | Query formulas VERIFY-ADT |
| A89 | Fixed | Serializer stages all output, writes nothing on error | — |
| A90 | Fixed | Event identity includes FILE_ID | — |
| A91 | Withdrawn — kill switch removed | — | — |
| A92 | Fixed | CAMT batch details only when they add up (CAMT_BATCH_MISMATCH) | — |
| A93 | Fixed | Only booked CAMT entries become lines (ENTRY_NOT_BOOKED) | Approved status profile is a parser constant |
| A94 | Fixed | CAMT namespace / version gate (CAMT_DOCUMENT) | Approved versions are a parser constant |
| A95 | Fixed | Missing BAI2 49 / 98 / 99 = MISSING_TRAILER (B) | — |
| A96 | Fixed | Funds-type layout validated (FUNDS_LAYOUT) | — |
| A97 | Fixed | End-to-end tests `e2e_config_only_code_routed`, `e2e_info_code_no_line` | — |
| A98 | Fixed | Contradictory blank / `*` map rows = MAP_CONFLICT | — |
| A99 | Fixed | Alert status S = submitted; delivery in SOST | SOST reconciliation at gate 3 |
| A100 | Fixed | Long file names: digest key verified against the full name | `cl_abap_message_digest` on 7.58 VERIFY-ADT |
| A101 | Fixed | HCK history per series incl. DIM2 | — |
| A102 | Fixed | Baseline warm-up grey, never green | — |
| A103 | Fixed | Expected groups ZCD_HCK_AGGGRP; a silent group measures 0 | Expected values per check with Treasury / operations |
| A104 | Fixed (documentation) | QA cases EBS-13 (FEB source) and EBS-13a (file source) | Whether a file-size limit is needed (QA1) |
| A105 | Fixed (documentation) | 195 parity corrected, legacy references pinned, case PAR-195 | CHECT layout and DPAYH-DOC1R length VERIFY-SE11 |

## 3. Review items outside the numbered findings

| Id | Decision | Where it lives now | Open residual |
|---|---|---|---|
| ZTNUM leading zeros | Fixed | `ztnum_canonical( )`, `EBS_ZTNUM_IGNORE_ZEROS` | — |
| In-flight grace | Decision | AWAITING_LOT_TRANSFER within `EBS_INFLIGHT_HOURS` | Time zone of statement creation times VERIFY |
| Secondary indexes | Fixed | `// @index` markers serialized into the TABL XML (`Implementation_Order.md` 1c.1) | Indexes active after the first pull |
| SLG1 external ID | Fixed | `<area>/<run>/<rule>`, BAL_LOG_REFRESH after save | Not executed against BAL |
| FEBAN / FPCPL navigation | Withdrawn — removed with the read-only scope | — | — |
