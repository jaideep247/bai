# Release readiness — gates, evidence and owners

> **First principle:** a positive result — *post this line*, *file fully processed*, *health green*, *alert sent* — is issued only when the evidence for it exists; missing or unknown evidence is its own visible status.
> **Analogy:** a pilot's go/no-go — every gauge must be read, not assumed; a dark gauge is a no-go, not a green one.

Source: principal architecture review and the static repository audit (findings A01–A99, snapshot `8cdfdce` on `main`; A100–A105 from the later checkpoint). Code status refers to branch `claude/loving-albattani-qexsjc`; per-finding detail is in `Review_Response_2026-11-06.md` and `Audit_Response_EBS.md` / `_FMON.md` / `_HCK_CORE.md`.

## 1. "No positive result without evidence" — where the code now enforces it

| Positive result | Gap found | Now in code | Proof still needed (gate) |
|---|---|---|---|
| **Posting allowed** (enforce mode — **switched off, not in this release**) | Failed rule allowed posting; missing rules vanished; map actions lost; blank/missing trailers self-satisfied; kill-switch read could dump | Per-rule *blocks posting* flag (A27); missing/unusable required rules block (A03); typed disposition per line AUTO_POST / EXCEPTION / ON_ACCOUNT / BLOCK / NOT_POSTED (A85); BAI2 trailers never self-satisfied, missing trailers block (A86, A95); CAMT detail sums, entry status and structure (A92–A94); kill switch falls back to MONITOR with a diagnostic (A91); plug-in or validation failure is BLOCK (fail closed) | Future enforcement phase — through the real posting entry point (A02, deferred) |
| **File fully processed** | Capped lot scan could prove completion; SLA met by another phase's event; overlapping runs overwrote newer state | Truncated scan is indeterminate (A38); SLA met only by its own stage, later stages are *inferred* (A40); per-payment ACK de-duplication (A39); version-checked registry writes (A04); file instance includes business date (A49, A90); long file names keep their identity, digest verified against the full name (A100) | Gate 3 — shadow run with real PRISM / ACK feeds |
| **Health green** | Empty selection green; hung run hidden; flat baselines passed changes; partial G/L transfer evidence accepted | Empty or self-check-only selection is a configuration finding (A60); stale running runs detected independently (A06); flat-baseline tolerance (A59); G/L gaps per company with full population (A43); NO_DATA distinct from success (A68); baselines per series incl. DIM2 (A101); baseline warm-up is grey WARM-UP, never GREEN (A102); a silent expected company / source measures 0, a failed query is never zero (A103) | Gate 3 |
| **Alert sent** | BCS result ignored; claim after send; blocker lost behind a cap | BCS result checked (A45); durable claim before send with unique intent index (A17); severity-ordered caps (A63); status **S = submitted**, mailbox delivery is in SOST (A99) | Gate 3 — SOST reconciliation for payment-critical routes |

**Scope of EBS in this release.** EBS validation runs **after** statement import, posting (FEBP) and payment clearing: a post-posting detective control (batch run `ZCD_EBS_VALIDATE`, FEB source). The pre-posting path — `VALIDATE_FOR_POSTING` / BAdI `FIEB_CHANGE_BS_DATA`, enforce mode, release of blocked lines — stays in the code, switched off, and is not part of this release; posting enforcement and release of blocked lines are outside this initiative (master prompt).

**LUW ownership (pre-posting path, future phase).** `ZCL_CD_EBS_ENGINE=>VALIDATE_FOR_POSTING` returns a decision only: it does not commit, save findings, start a run or send alerts (verified 2026-11-06: no `COMMIT WORK` in any EBS class). The SAP posting caller owns the LUW; findings for posted statements are recorded by the batch run `ZCD_EBS_VALIDATE`.

## 2. Release gates

| Gate | Exit evidence | Owner | Status |
|---|---|---|---|
| **1. Deployable SAP baseline (DV1)** | abapGit pull and activation on S/4HANA 2023 (SAP_BASIS 7.58); SAP ATC with the company variant (`ATC_Validation.md` §6); ABAP Unit with coverage (`Coverage_Run_Register.csv`); DDIC: every `VERIFY-DDIC` field in SE11, unique and secondary indexes active (now generated in the TABL XML), appends; CDS/DCL active; service bindings published; authorisation objects `ZCD_OPS` / `ZCD_PE_AREA` and roles; `rec/client` table logging; job variants. Release note: abaplint prints "v793 … on-premise 758" for the configured `v758` — the same S/4HANA 2023 release (A01), CI pinned to abaplint 2.120.92 | RTB development lead, Basis, security | Code ready; **not started in SAP** |
| **2. Financial decisions proven (QA1)** | Signed **decision matrix** by processing stage (§3) executed by `ZCD_EBS_VALIDATE` on imported, posted and cleared statements (FEB source), including invalid input, missing rules, ambiguous identity and technical failure; three-way comparison (consolidated vs observed legacy vs business-expected), keyed by bank account, statement and line — the legacy and `src` code are reference only, not fallback (A12, A29–A31, A70–A79) | Payment engine functional lead, Treasury, RTB | Functional sign-off §3 open (A02 moved to the future enforcement phase) |
| **3. Operational controls proven (QA1 shadow)** | File and payment reconciliation incl. no-ACK and partial-ACK; concurrent runs and replay; stale-job detection; SQL-failure recovery; alert delivery reconciled in SOST; holiday and month-end calendars; production-like volume with SQL traces (BSEG key reads, DFKKRP / DPAYH / DFKKCR, ACDOCA, FMON look-back, HCK history); an operator traces one discrepancy from the report to bank, PRISM and SAP evidence | RTB operations, Control-M team, Basis | Not started |
| **4. Controlled production rollout (PS4)** | Detective reporting first for one approved bank account / interface, then widened; rehearse switch-off (`ZCD_EBS_VALIDATION_MODE` = `O`) and recovery with named owners; reconcile in-flight statements, lots and payments before widening. ENFORCE is not used in this release | Change manager (CAB), Treasury, RTB | Not started |

## 3. Functional sign-off (gate 2)

| Area | Implemented behaviour | Evidence required in QA1 |
|---|---|---|
| 166 / 143 collections | 166C: FI document exists and is cleared (R19). 143: collections only, same as 166C (decision 2026-11-06); no payment-lot check (decision) | Cleared / uncleared / missing document cases per bank |
| 166 disbursements | Retrieval-log chain (decision 2026-11-06): retrieval AP passes; otherwise a returns-lot entry (DFKKRP by SELW1) **and** retrieval AF; then DPAYH `RETURNED` | AP, AF, missing retrieval, missing lot, competing retrieval / lot records, non-RETURNED |
| 168 / 468 / 452 returns and retrievals | Lot status, DPAYH RETURNED, retrieval AF; any matching record with an allowed status passes, ambiguous identity is reported; return reason from FEB, placeholder mappings rejected, NOC distinct from returns; 452 = 468 (decision) | Mixed-status logs, lot correlation, effective FI-CA return reason, NOC |
| 195 wires | DPAYH exists by DOC1R (v4 parity); no notification (the `src` wire notification was a placeholder) | Confirm wire identification and whether a notification is a required control |
| 255 / 466 | Register status / FI document lookups with company code, house bank and fiscal year where applicable | Both flow types, missing company code, actual FI document status |
| 275 / 575 sweeps | **Not validated** (decision 2026-11-06); mapped with disposition NOT_POSTED, honoured by S10 | Posted vs unposted sweep produces no exception |
| 581 checks | Register rows scoped to company code, house bank account; reissue / cancellation handled; count and total compared on independent populations; leading zeros normalised on both sides | Reissued and cancelled checks, repeated bank references, equal totals with unequal counts, currency and sign, package boundaries |
| New BAI / CAMT codes | Map row + rule group in the EBS configuration app; R21 generic lookup for a new table; parser change only for codes outside the bank profile (7xx–9xx informational codes never post) | End-to-end parser-to-engine case for one new code |
| Cash clearing and G/L transfer | HCK: DFKKSUMC-FIKEY = DFKKKO-FIKEY = BSEG-AWKEY with AWTYP and company; expected vs transferred population; timing differences classified separately | Month-end close sample reconciled with BlackLine buckets |

## 4. Configuration and exception control (production)

- Configuration changes: new entries by transport from DV1, existing entries edited in production with SCU3 change log and `ZCD_OPS` authorisation (configuration apps); effective-set checks reject missing required rules (A03) and colliding map rows (A98).
- Exceptions: assign / resolve / waive with reason, four-eyes for waivers and EBS releases, history per action (operations apps); owner and response window per critical control are maintained in the alert rules.
- Dynamic SQL: table / field allowlists enforced at the DAO execution boundary (FMON `ZCD_FMON_TABWL`, HCK whitelist re-validated at the SQL boundary); plug-in classes checked against their interface before instantiation (A62).

## 5. Open inputs

- A02 — SE18 signature of `FIEB_CHANGE_BS_DATA`: deferred with the pre-posting path to the future enforcement phase.
- A100–A105 — **fixed** (code A100–A103, documentation A104–A105); remaining confirmations are `VERIFY` items: `cl_abap_message_digest` on 7.58 (A100), expected group values per check with Treasury / operations (A103), whether a file-size limit is needed (A104, QA case EBS-13a), CHECT layout and DPAYH-DOC1R length (A105, PAR-195).
- Every other `VERIFY-DDIC` / `VERIFY-ADT` marker — gate 1.

**Status:** code complete for audit findings A01–A105 except A02 (deferred, see §5); gates 1–4 require SAP and business evidence and are **not passed**. Production promotion stays on hold until gate 2 is signed.
