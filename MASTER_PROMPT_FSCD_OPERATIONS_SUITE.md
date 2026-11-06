# Consolidated Master Prompt — SAP FSCD/FICA Production Health Check, File Monitoring, EBS Validation & Job Cycle Frameworks

This is the single, end-to-end prompt consolidating everything: the health check framework, custom-table file monitoring, CAMT/BAI BTC-code EBS validation, the Control-M fallback job cycle tool, LOB volume tracking, and the dashboard. Copy the prompt block below (from "ROLE" to "ACCEPTANCE TESTS") into your AI assistant, development team brief, or RFP. Run it phase by phase as instructed — do not ask for all deliverables in one shot. Attach `btc-validation-matrix.xlsx` as the seed data for the BTC tables.

---

## THE PROMPT

> ### ROLE
> You are a principal SAP architect with 15+ years in SAP for Insurance, specializing in FS-CD (Collections & Disbursements for Insurance, built on FI-CA Contract Accounts Receivable/Payable), production operations, high-volume mass-run performance engineering, and treasury/bank-statement processing. You have built monitoring and validation frameworks for insurers processing millions of premium, claim disbursement, commission, and direct-debit transactions per day.
>
> ### MISSION
> Design and build a **single, configuration-driven framework suite** for our SAP FSCD/FICA production landscape, consisting of four integrated frameworks sharing one engine, one result/exception store, one alert router, one authorization model, and one real-time dashboard:
> 1. **Health Check Framework** — configurable checks across the FSCD/FICA stack with statistics, exceptions, and trends.
> 2. **File Monitoring Framework** — custom-table based, tracking every file through the SAP → PRISM (middleware) → bank → SAP chain.
> 3. **EBS Validation Framework** — bank statement validation for CAMT (053/054) and BAI2 formats, driven by a BTC (bank transaction code) rule engine.
> 4. **Job Cycle Monitoring & Retrigger Tool** — configurable job cycles in SAP with monitoring and in-SAP retrigger as a Control-M fallback.
>
> ### OUR LANDSCAPE (GROUND TRUTH — DESIGN AGAINST THIS)
> - **SAP is the payment engine.** Source systems send payment requests for different lines of business and payment methods; SAP creates the master data, runs **VYSPA** to generate subledger (FSCD) documents, and executes payment runs (**FPY1**) to collect or disburse money.
> - **Inbound sources (today, extensible):** PCLM, BASE, ALPA, ALPL, HAL, ORCI, DIS. **Payment methods (today, extensible):** Wire, Check, EFT (ACH); international payments in scope.
> - **Outbound flow:** SAP → **PRISM (middleware)** → bank. Every file sent from SAP to PRISM must be monitored: did PRISM pick it up and forward it to the bank, and did the bank acknowledge it (per file and payment method)?
> - **Inbound bank flow:** bank statements in **BAI and CAMT formats**; **returns files** from the bank (ACH returns and NOC — Notification of Change) must be fully processed: every transaction accounted for, NOC entries applied, returns lots created (FP09).
> - **Processes in scope today (extensible):** VYSPA, FPY1, F.13, write-off processes, FP09 (returns), FPCRL, FPCPL (clarifications), FP45, FEBP, FPB7, FPB17.
> - **Existing custom tables already capture file/ack events (extend and unify — do not replace):** ZCDT_REGUT, ZCD_CHECK_HIST, ZCD_ACH_RTRV_LOG, ZCD_ACH_ACK, ZCD_WIRE_ACK, ZCD_STRP_POUT_LOG, and others.
> - **Scheduling runs on Control-M.** We need an in-SAP fallback to define, monitor, and retrigger job cycles when Control-M has issues.
>
> ### DESIGN PRINCIPLES (NON-NEGOTIABLE)
> 1. **Configuration-driven, not code-driven.** Every check, file expectation, BTC mapping, validation rule, threshold, severity, schedule, alert route, and job cycle step lives in customizing tables. A functional administrator adds or changes any of them with zero code changes (transportable customizing + where-needed CTS). New source systems, LOBs, payment methods, interfaces, BTC codes, banks, or job steps are table entries, never programs.
> 2. **Performance-optimized.** All processing runs against millions of open items (DFKKOP-class volumes) without impacting online or mass-run performance: package-size processing, parallelization via parallel RFC/server groups with max-worker limits, secondary indexes, aggregation-first reads (COUNT/SUM at DB level), HANA code-pushdown/CDS where available, time-boxed windows, incremental/delta modes. Every run is measured (runtime, records, DB time) and stored for trending.
> 3. **Robust and self-monitoring.** A failing check never crashes the framework: full exception handling, retries with backoff, run-state persistence, timeouts and kill of runaway workers, idempotent re-runs, and a "health check of the health check" that alerts when anything has not run on schedule.
> 4. **Auditable.** Every result, threshold change, exception disposition, NOC application, and retrigger action is persisted with timestamps and user IDs — supporting SOX/audit and NACHA compliance evidence.
> 5. **No silent suspense.** Any unmapped code, unassigned item, or unprocessed file transaction raises a typed, owned exception with an aging SLA. Nothing is silently posted to suspense or dropped.
>
> ### FRAMEWORK 1 — HEALTH CHECK FRAMEWORK
> **Check engine:** a generic runner executing check classes defined in customizing. Each check = metadata (check ID, category, class/BAdI implementation, selection parameters, schedule, package size, parallel degree, timeout) + threshold table (green/yellow/red, dynamic per company code or volume band) + result schema (check ID, run ID, timestamp, key figures, exception count, top-N exception items, severity).
> **Check catalog (each a configurable check class; minimum set):**
> - **A. Financial integrity:** subledger-to-GL reconciliation (period and cumulative, per company code/currency); posting interface errors between source systems and FSCD and FSCD to GL; open item aging and composition; clearing differences, unassigned cash, cash journal balances; return-debit volume and aging vs. submissions.
> - **B. Mass-run health:** status, duration, throughput (items/hour), interval/parallel-job completion for FPY1, dunning, correspondence, interest, GL transfers; deviation vs. rolling baseline (same weekday/period, last 4–8 runs); SLG1 error-rate analysis per mass run.
> - **C. Exception queues:** PPO backlog by type/age/owner; clarification worklist aging (FPCPL); payment and correspondence exception aging.
> - **D. Master data & config drift:** contract partner/account anomalies (missing payment data, invalid bank details, blocked accounts, duplicates); control-parameter completeness; config drift vs. golden baseline snapshot of productive customizing.
> - **E. Technical health:** background job status (cancelled/long-running/missed), update/lock errors, short dumps, interface errors, data volume vs. archiving progress.
> **Statistics & analytics:** rolling baselines (mean, median, std dev, percentiles) per KPI; automatic outlier detection (z-score or rolling IQR) instead of static thresholds only; PPO backlog and mass-run duration forecasting; month-end vs. mid-month profile awareness.
>
> ### FRAMEWORK 2 — FILE MONITORING FRAMEWORK (CUSTOM TABLES, NOT AIF)
> **File registry & event chain.** Extend ZCDT_REGUT (or build a unifying registry layer over the existing ZCD_* tables). Every file registered with: direction, interface/file type, source/target system, payment method, LOB, file name, timestamp, record count, control total, status. Status model:
> - Outbound: GENERATED_IN_SAP → SENT_TO_PRISM → FORWARDED_TO_BANK → ACK_RECEIVED (ACH acks in ZCD_ACH_ACK, wire acks in ZCD_WIRE_ACK) or NACK/REJECTED.
> - Inbound: FILE_RECEIVED (statement/returns/NOC) → FILE_LOADED → FULLY_PROCESSED / PARTIALLY_PROCESSED (with unprocessed count) / FAILED.
> Every transition timestamped and auditable; a reconciliation view keeps the registry and legacy ZCD_* tables consistent.
> **Expected-file configuration:** interface calendar (expected files per business day type — normal, month-end, holiday, ACH returns cycle days), SLA windows per direction/payment method (e.g., "wire ack within 30 minutes"), naming patterns, min/max size, expected record counts/control totals.
> **Checks:** file missing, late, no PRISM handoff, no bank ack within SLA, negative ack, ack mismatch (count/amount), returns/NOC file not fully processed, unprocessed transactions remaining, duplicate file, zero-byte, checksum mismatch, archive failure — all flowing into the shared health check store with RAG thresholds, drill-down, and alert routing.
> **NOC & returns completeness:** every transaction in a returns/NOC file reconciles to a processing outcome — returns lot created (FP09 with return reason), NOC correction applied to master data, or an open owned exception. A file is processed only when zero transactions are unaccounted for.
>
> ### FRAMEWORK 3 — EBS VALIDATION FRAMEWORK (BAI + CAMT, BTC-CODE RULE ENGINE)
> **Statement/file-level checks (run first, per file):** opening balance = prior statement closing; opening + credits − debits = closing (CAMT OPBD/CLBD; BAI2 opening/closing); statement number continuity against FEBKO (no gaps/duplicates); account & currency valid; date sanity; file control totals; duplicate statement detection; file expected per calendar and registered (non-zero, non-duplicate); 100% BTC mapping coverage; completeness — every entry = posted + on-account + open exception.
> **BTC rule engine (core).** Validate and route every statement line by its bank transaction code — CAMT structured Domain > Family > Sub-family in BkTxCd (plus proprietary codes), or BAI2 type code — via two customizing tables:
> - **ZCD_BTC_MAP:** format + BTC code (or BAI type code) + BANK_KEY → semantic category, direction, expected flow, payment method, SAP posting rule, FI-CA return reason mapping.
> - **ZCD_BTC_RULE:** per category or code group, validation rules with parameters (tolerances, windows, lookbacks), severity (E/W/I), and action (AUTO_POST / EXCEPTION / BLOCK / NOTIFY / ON_ACCOUNT).
> **Reference matrix (seed data provided in btc-validation-matrix.xlsx — implement these categories at minimum):**
>
> | ID | Category | CAMT (Domn/Fmly/SubFmly) | BAI2 | Expected SAP processing |
> |---|---|---|---|---|
> | C01 | ACH collection settlement | PMNT/IDDT/PADD | 165 | Auto-clear vs FPY1 debit memo items via trace/E2E |
> | C02 | ACH collection return | PMNT/IDDT/UPDD | 557 | Returns lot FP09 + FI-CA return reason; separate fee |
> | C03/C04 | ACH reject / reversal | PMNT/IDDT/UPDD · AREV | 561 · 558 | Returns lot / matched reversal |
> | D01 | ACH disbursement settlement | PMNT/ICDT/ACDT | 447 | Auto-clear vs payment run; reconcile file + PRISM ack |
> | D02–D04 | Disbursement return / reject / reversal | PMNT/ICDT/ARET · AREV | 257 · 261 · 258 | Re-credit, notify source system |
> | I01/I02 | Inbound ACH receipt / return | PMNT/RCDT/ACDT · ARET | 142 · 557 | Auto-clear via interpretation; else FPCPL clarification |
> | W01/W02 | Wire out domestic / cross-border | PMNT/ICDT/DMCT · XICT | 495 | Match ZCD_WIRE_ACK; FX/charges validation |
> | W03/W06 | Wire returns | PMNT/ICDT|IRCT/RRTN | 266 | Re-credit / reverse; notify source |
> | W04/W05 | Wire in domestic / cross-border | PMNT/RCDT/DMCT · XICT | 195 | Auto-clear if identifiable; else clarification |
> | K01 | Check issued & paid | PMNT/ICHQ/CCHQ | 475 | Match check number to check register; auto-clear |
> | K02 | Check return / stop | PMNT/ICHQ/CQRV | 255 | Re-credit; PPO |
> | K03–K05 | Check/lockbox deposit, deposit return, redeposit | PMNT/RCHQ/CCHQ · CQRV | 175/115 · 555 · 176/268 | Payment lot / returns lot with reason |
> | N01 | NOC (non-monetary, C01–C07) | per NACHA camt.053 guide or proprietary | separate NOC file | Update BP bank details; 6-banking-day NACHA SLA; never post |
> | F01–F05 | Fees / interest (+ reversals) | ACMT/MCOP|MDOP/FEES · INTR · CHRG | 698 · 398 · 354/359 · 654 · 977 | Post per posting rule; fee-schedule tolerance |
> | T01/T02 | Book transfer / sweep | PMNT/RCDT|ICDT/BOOK · RCCN|ICCN/ICCT | 195/495 · 275/575 | Post both legs |
> | M01/M02 | Misc credit / debit | PMNT/RCDT|ICDT/ADJT | 399 · 699 | On-account / review; never suspense |
> | X01 | Unmapped BTC | any code absent from ZCD_BTC_MAP | any | BLOCK + exception — never auto-post |
>
> **Field-level rule catalog (seed data in the workbook — R01–R18):** amount sign vs. direction (R01); amount bounds (R02); currency match (R03); required reference present — E2E ID / trace number / check number per category (R04); valid return reason NACHA R01–R85 and NOC C01–C07 mapped to FI-CA reasons (R05); NOC 6-banking-day SLA (R06); match to outbound record in payment files / ZCD_ACH_ACK / ZCD_WIRE_ACK / check register (R07); return/reversal amount matches original within tolerance (R08); duplicate entry detection (R09); value date window (R10); fee/charge tolerance vs. fee schedule (R11); batch/settlement total = FPY1 run total (R12); reversal window (R13); unmapped BTC → block + exception, never suspense (R14); posting rule resolves (R15); NOC master data applied and differs from original (R16); statement debit matches prior positive ack via PRISM (R17); post-posting bank GL balance = statement closing balance (R18).
> **Leverage standard objects:** FF_5/RFEBKA00 import; posting rules and interpretation algorithms; BAdI FIEB_CHANGE_BS_DATA as the injection point for pre-posting validation; FEBKO/FEBEP/FEBRE/FEBCL for all analytics; FI-CA returns processing (returns lots auto-created from bank statement data, FP09 with return reasons).
> **Exception handling:** every validation failure creates a typed, owned exception item with aging SLAs; reprocessing path (re-import, re-validate, re-post) is idempotent and audited. NOC aging is a compliance exception, not just operational.
>
> ### FRAMEWORK 4 — JOB CYCLE MONITORING & RETRIGGER (CONTROL-M FALLBACK)
> **Cycle definition (config tables):** cycle = ordered steps (job name, variant, job class, predecessor, on-success/on-failure/skippable flags, max runtime, expected start window, business calendar). Model at least: source file intake → master data creation → VYSPA → FPY1 → DME/payment medium → send to PRISM → ack wait → statement load (FEBP) → returns processing (FP09) → clarifications (FPCPL/FPCRL) → write-offs (FP45) → GL clearing (F.13, FPB7, FPB17).
> **Monitoring:** read TBTCO/TBTCP plus ZCD_CHECK_HIST for real-time cycle state (NOT_STARTED / RUNNING / COMPLETED / FAILED / STUCK / MISSED); alert on steps not started within window, overruns, failures, stuck chains; visualize as step timeline on the dashboard.
> **Retrigger from SAP:** authorized users restart a failed step, resume a cycle from a step, or run a full cycle manually — replicating Control-M chain semantics via event-based scheduling (BP_EVENT_RAISE / SM36 after-event) or direct job submission. Idempotent (no duplicate runs of completed steps unless forced), fully audited, explicit "Control-M outage mode" toggle. Detect Control-M/SAP divergence (chain believed run vs. jobs missing) and alert.
>
> ### VOLUME & LOB STATISTICS (PAYMENT ENGINE KPIs)
> Track and trend, slicable by LOB × source × payment method × day/week/month: payment requests received; master data created; VYSPA documents generated; FPY1 items collected/disbursed; files sent to PRISM; acks received (by method); statements loaded (BAI vs. CAMT); returns by reason; NOC received/applied; clarifications created/cleared; write-offs; GL clearing volumes. These volumes feed the baselines and outlier detection in Framework 1.
>
> ### DASHBOARD (PRODUCTION SUPPORT IT — REAL TIME)
> One real-time operational dashboard: (a) health scorecard (RAG by category); (b) file status board — per interface/source/method, event-chain progress, SLA countdowns; (c) EBS validation results as statements arrive — pass/fail by BTC rule, drill-down to line items; (d) job cycle board — step status, timeline, retrigger buttons with authorization; (e) exception queue with aging and owners; (f) volume/LOB statistics and trends. Auto-refresh/push, role-based views (IT support vs. management), export. Propose the best technical fit (Fiori over CDS views / embedded analytics / standalone web via OData) with a recommendation.
>
> ### DELIVERABLES
> 1. Solution architecture for the full suite (components, data flow between the four frameworks, PRISM/bank interfaces, sizing).
> 2. Customizing table design for all frameworks (fields, keys, maintenance views, transport strategy) — including ZCD_BTC_MAP and ZCD_BTC_RULE per the seed workbook.
> 3. Check engine + BTC rule engine design, class model, BAdI points, and reference implementations: at least 5 health checks (one per category A–E), the full BTC matrix (C01–X01) with rules R01–R18, and statement checks S01–S12.
> 4. File monitoring registry/event-chain design mapped onto the existing ZCD_* tables.
> 5. Job cycle definitions for the modeled cycles plus the retrigger/audit design.
> 6. Dashboard spec and wireframes (pages, charts, drill-downs, deep links, roles/authorizations).
> 7. Performance test plan: stability and acceptable runtime at 10M+ open items and peak mass-run windows (targets: aggregate check < 2 min, detail check < 10 min, < 5% DB load).
> 8. Rollout plan: pilot → tune → expand, plus the **extension guide** showing exactly which customizing entries to add for each common future change (new source, LOB, payment method, bank, BTC code, check, rule, cycle step).
>
> ### IMPLEMENTATION PHASES (FOLLOW THIS ORDER)
> - **Phase 0 — Discovery:** confirm landscape facts, inventory existing ZCD_* table structures (SE11), obtain each bank's BAI2/CAMT code sheet and sample files, catalog current Control-M chains.
> - **Phase 1 — Architecture & table design:** Deliverables 1–2 for review before any build.
> - **Phase 2 — Core engine:** health check engine + result store + alert router (Framework 1).
> - **Phase 3 — File monitoring:** registry, event chain, expected-file config, checks (Framework 2).
> - **Phase 4 — EBS validation:** statement checks + BTC rule engine + NOC/returns completeness (Framework 3).
> - **Phase 5 — Job cycles:** cycle config, monitoring, retrigger (Framework 4).
> - **Phase 6 — Dashboard & statistics.**
> - **Phase 7 — Performance testing** against volume targets.
> - **Phase 8 — Pilot:** 2–3 health checks + one file interface + one bank's EBS validation + one job cycle in production; tune thresholds; then expand.
> - **Phase 9 — Hypercare & extension guide:** knowledge transfer to IT support, runbook, and the configuration-only extension guide.
>
> ### CONSTRAINTS & CONTEXT (FILL IN BEFORE STARTING)
> - [System release / DB] | [Daily transaction volumes by source and LOB] | [Banks and their statement formats and code sheets] | [Current monitoring landscape] | [Dashboard platform preference] | [Control-M version and interface to SAP]
>
> ### WORKING STYLE
> Ask clarifying questions only where the answer materially changes the architecture; otherwise state assumptions and proceed. Benchmark against market practice (SAP Focused Run, Solution Manager/Cloud ALM, SAP AIF, Avantra-class observability, NACHA/ISO 20022 standards) and explain where the custom suite adds value beyond them.
>
> ### ACCEPTANCE TESTS (THE BUILD PASSES ONLY IF ALL HOLD)
> 1. Add a new health check ("return debits aging > 10 days by company code") using only customizing.
> 2. Add a new source system and LOB using only customizing.
> 3. Add a new BTC code with validation rules (e.g., a code a new bank uses) using only customizing.
> 4. Add a validation rule ("reject statements where closing balance deviates > 0.01 from prior opening") using only customizing.
> 5. Add a new step to an existing job cycle using only customizing.
> 6. Prove at 10M+ open items: no check exceeds its runtime target and DB load stays under 5%.
> 7. Prove an unmapped BTC code can never post to suspense — it always produces a blocked exception.
> 8. Prove a returns/NOC file with an unprocessed transaction stays PARTIALLY_PROCESSED and alerts.

---

## How to use this prompt

1. **Fill in the Constraints block first** — system release, volumes, banks, dashboard preference, and Control-M version change the architecture.
2. **Run it phase by phase** (Phase 0 → 9). Ask for Phase 0 and 1 outputs first, review the table designs, then proceed. Requesting all eight deliverables at once produces shallow output.
3. **Attach `btc-validation-matrix.xlsx`** (the BTC seed data: 32 matrix rows, rules R01–R18, statement checks S01–S12, ZCD table layouts) and this document together.
4. **Have ready for Phase 0:** SE11 structures of the existing ZCD_* tables, one sample BAI2 and CAMT.053/054 file per bank, each bank's transaction code sheet, and a current Control-M chain export.
5. **Market context to attach if the implementer needs it:** SAP Focused Run and AIF cover technical/interface monitoring but not FSCD business semantics; Solution Manager is end-of-maintenance 2027; NACHA rules (NOC C01–C07 within 6 banking days; returns cycle one banking day after processing) make NOC aging a compliance requirement, not just an operational KPI.
