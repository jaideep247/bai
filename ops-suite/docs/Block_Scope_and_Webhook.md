# Block scope and webhook correlation — decision record (2026-11-06)

> **First principle:** a control is designed for the moment it runs; a gate that runs after the money has moved is a detector, and is designed as one.
> **Analogy:** a smoke detector and a fire door are both fire controls, but you do not fit a door handle to the detector.

Source: latest architectural / operational review (zero-suspense paradox, LUW, webhook schema, server groups, runbook).

## 1. Block scope (EBS) — superseded

| | |
|---|---|
| Question | In enforce mode, when one bank statement line fails a business check: hold only that line (to FS-CD clarification) or block the whole statement? |
| Answer given | "Line to clarification": only the failing line is held, posting area 1 and clean lines post; the whole statement is blocked only for integrity failures (S02, S04, S07, BAI2 trailers / structure, CAMT structure). |
| Status | **Superseded by the post-posting operating model (2026-11-06) — redesign pending.** |
| Why | `ZCD_EBS_VALIDATE` runs **after** the statement import, the posting job (FEBP) and the payment clearing job have completed. It is a detective control over posted statements, not a pre-posting gate, so "hold the line vs block the statement" does not apply in its current form. |
| What was changed | Nothing in the engine: `must_block`, `dispositions` and `validate_for_posting` are unchanged. `Implementation_Order.md` Step 4 now states the post-posting dependency of `ZCD_EBS_VALIDATE_ALL`. |
| Open for the redesign | What a post-posting finding must trigger instead of a block (clarification worklist, reversal request, FEBAN re-processing, alert priority); whether `validate_for_posting` / the BAdI (A02) is still wanted at all; how the posting dispositions (A85) map to post-posting outcomes. Owner: payment engine functional lead with Treasury. |

## 2. Webhook correlation and de-duplication — implemented

`ZCL_CD_OPS_CHN_HTTP=>TO_JSON` keeps every existing key and adds `runId`, `dedupKey`, `eventAction` (`trigger`), `source` (`ZCD_OPS`), `system` (`<SID>/<client>`), `occurredAt` (UTC ISO 8601, `null` when unknown) and `correlation` (`runId`, `logId` = SLG1 external ID). `dedupKey` is the A17 alert intent key, so every attempt of one alert carries the same key; without a hash it falls back to `<area>/<run>/<rule>`. The router now hands the intent key and the claim time to the channel (`ty_alert_message-intent_key`, `-occurred_at`). Schema, receiver mapping and P1–P3 priority mapping: `ALERTING.md`; per seed rule: `config/alert_seed.md`.

Tests: `ZCL_CD_OPS_CHN_HTTP` — `run_and_dedup_key_sent`, `dedup_key_stable_per_intent`, `dedup_key_without_intent`, `event_fields_sent`, `occurred_at_is_utc_iso`, `unknown_time_is_null` (plus the existing escaping tests); `ZCL_CD_OPS_ALERT_ROUTER` — `claim_precedes_delivery` (delivered message carries the claimed intent key and claim time).

## 3. Operational documentation — implemented

| Topic | Where |
|---|---|
| Dedicated batch server group (RZ12 / SM61), job class, runtime limits, no competition with FPY1 / FPVA / FPVB / FEBP | `Implementation_Order.md` Step 4 |
| Reads without locks on standard tables (HANA MVCC, no ENQUEUE on DFKKOP / FEBEP) | `Implementation_Order.md` Step 4 |
| FMON re-run after a network / interface outage (idempotent, nothing to reset) | `Operations_Runbook.md` §5 |
| Housekeeping = `ZCD_OPS_PURGE` (+ SLG2 for the application log) | `Operations_Runbook.md` §5a |
| Not done (depends on the superseded posting-time model) | EBS block-scope precedence table, "posting area 1 vs 2", "BAdI contract (A02)", runbook "forcing an emergency statement through" |

## Merge notes

For the owners of files this change did not edit:

- **`Release_Readiness.md`** §1 row *Alert sent*: add "webhook carries `dedupKey` (alert intent), `runId`, `occurredAt`, `correlation` — receiver de-duplicates retries"; gate 3 exit evidence: "webhook receiver maps `dedupKey` (ServiceNow Message key / PagerDuty `dedup_key`); P1–P3 acknowledgement targets confirmed by RTB operations (`ALERTING.md`)". §1 row *Posting allowed* and the LUW note: mark the posting-time wording as "superseded by the post-posting operating model (2026-11-06) — redesign pending" (`ZCD_EBS_VALIDATE` runs after import, FEBP and payment clearing). Gate 2: A02 (BAdI) depends on that redesign.
- **`Review_Response_2026-11-06.md`**: add a part E for the latest review — webhook schema (fixed, this record §2), dynamic SQL (FMON binds its keys as host variables; the HCK aggregate query still builds IN lists of escaped literals — allowlists enforced at the DAO boundary; CVA note open), LUW (no commit in EBS classes — unchanged), server group / MVCC (documented, §3), zero-suspense block scope (superseded, §1), returns reason mapping and NOC → BUT0BK (future).
- **`Audit_Response_*.md`**: no finding number changes; optionally reference this record from the A17 row of `Audit_Response_HCK_CORE.md` ("intent key also sent as webhook `dedupKey`").
- **`Test_and_Validation_Document.md`**: QA1 case "webhook receiver de-duplicates a re-sent alert (same `dedupKey`) and opens a new incident for a new run".
- **`Legacy_Parity_Comparison.md`**: none.
- **Generated files**: `Class_Purpose_and_Modification_Log.md`, `Coverage_Run_Register.csv`, `Changed_Artifacts.csv` and `portable_checks.json` were regenerated by the tools; on conflict regenerate, do not hand-merge.
- **`TDD_Approach_and_Coverage.md` §4**: the `ZCL_CD_OPS_CHN_HTTP` row was updated by hand (9 methods); the section heading still says 648 methods / 51 includes — set it from `portable_checks.json` after both work packages are merged (661 methods at this commit).
