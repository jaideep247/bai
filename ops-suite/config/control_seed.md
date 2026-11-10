# Daily controls of the control center — seed and mapping to the existing checks (confirm before transport)

> **First principle:** a control is a name, an owner and a list of the checks that already run — its status is read from their findings, never typed.
> **Analogy:** a pilot's checklist page: each line names an instrument already on the panel; a line without an instrument is a request to the avionics shop, not a tick box.

Status 2026-11-10: proposal for the control register of the operations framework (`ZCA_OPS_CONTROL`, `ZCA_OPS_CTLT`, `ZCA_OPS_CTLCHK`, app `ZUI_CA_OPS_CFG` → *Settings & ownership*) and the payment lifecycle stages of the suite (`ZCD_OPS_PAYSTAGE`, app `ZUI_CD_OPS_CFG`). Rows travel by transport from DV1 (`ops-framework/docs/CONTROL_REVIEW.md`). **Owners, backups and teams are left blank** — the support lead fills them in DV1 (no personal names in the repository). Nothing has run in SAP.

Seed files (one row per table row, header = field names):

| File | Table | Rows |
|---|---|---|
| `config/control_register.csv` | `ZCA_OPS_CONTROL` (area, control, name, category, owner, backup, team, cut-off, runbook link, active, sequence) | 12 controls (the mockup's 13 without *IDoc / interface checks*, user decision 2026-11-10: no IDocs in use) |
| `config/control_checks.csv` | `ZCA_OPS_CTLCHK` (control → area of the findings, finding field, exact value) | 53 covered checks |
| `config/control_guidance.csv` | `ZCA_OPS_CTLT` (language E: what the reviewer checks) | 12 |
| `config/pay_stages.csv` | `ZCD_OPS_PAYSTAGE` (payment lifecycle card) | 10 stages |

**Areas.** A control lives in the area of its checks (`CD_FMON`, `CD_EBS`, `CD_HCK`), so the area authorisation of the dashboards applies (`ZCA_OPS` / `ZCA_PARAR`) and the attention queue opens the exceptions app filtered by that area. **Cut-off** (local time of `CONTROL_TIME_ZONE`, delivered value row `CST` for America/Chicago — VERIFY the TTZZ zone name in STZAC): 08:30 for *Payment files* and *Clearing job*, 09:00 for the others (mockup). **Teams:** parameter `CONTROL_TEAMS` (`ONSITE,OFFSHORE`).

## 1. The twelve controls

| # | Control (`CONTROL_ID`) | Category | Area | Covered by (existing checks) | Coverage | Active |
|---|---|---|---|---|---|---|
| 1 | Payment files (`PAYMENT_FILES`) | Payments | CD_FMON | FMON checks by check ID (`RULE_ID`): `F_MISSING`, `F_LATE`, `F_REJECT`, `F_DUP`, `F_SIZE`, `F_REGEN`, `F_SLA`, `F_DEADLINE` (`config/fmon_seed.md`) | full | X |
| 2 | Clearing job (`CLEARING_JOB`) | Batch processing | CD_HCK | Health checks (`GROUP2` = check ID): `B_CYCLE_TODAY`, `B_CYCLE_PRIOR` (job cycles), `E_JOBS` (cancelled / late jobs) | **configuration**: the clearing job must be a step of a job cycle (`ZCD_JOB_CYCLE` / `ZCD_JOB_STEP`, HCK app) — proposal P1 | X |
| 3 | Base-rejected items (`BASE_REJECTS`) | Exceptions | CD_HCK | — | **gap** (reviewer) — proposal P2 | blank |
| 4 | ECT pending items (`ECT_PENDING`) | Disbursements | CD_HCK | — (`C_CHQ_STATUS` covers a cheque status that went backwards, not pending items) | **gap** (reviewer) — proposal P3 | blank |
| 5 | Outbound ZICD / ZCD (`OUTBOUND_IFACE`) | Interfaces | CD_FMON | FMON gateway stages: `F_PRISM`, `F_PRISMRCV`, `F_PRISMDLV`, `F_PRFAIL`, `F_PRFILE` | full for the interfaces configured in `ZCD_FMON_IFACE`; VERIFY that every ZICD / ZCD outbound interface has a row | X |
| 6 | BlackLine (`BLACKLINE`) | Reconciliation | CD_HCK | `A_GL_TRANSFER` (payment engine reconciliation keys reached the G/L) | **partial** — the extract file to BlackLine is not monitored: proposal P4 | X |
| 7 | BAI exceptions (`BAI_EXCEPTIONS`) | Banking | CD_EBS | Every EBS rule (`RULE_ID`): statement rules `S01`–`S13`, `R18`; line rules `R01`–`R22`; circuit breaker `CB`; engine `ENG` | full | X |
| 8 | Manual retrievals (`MANUAL_RETRIEVALS`) | Disbursements | CD_EBS | `R07L` (ACH retrieval: bank statement against the retrieval status) | **partial** — retrievals requested but not yet on a statement: proposal P5 | X |
| 9 | Missing check IDs (`MISSING_CHECK_IDS`) | Disbursements | CD_HCK | — | **gap** (reviewer) — proposal P6 | blank |
| 10 | Pending acknowledgements (`PENDING_ACKS`) | Interfaces | CD_FMON | `F_BANKACK` (ACK stage SLA, files acknowledged per file), `F_ACKMATCH` (ACK totals) | full for per-file ACKs; per-payment ACKs are judged by `A_INFLIGHT` (`PAY_STATUS_LAG`, area CD_HCK) — add a `CD_HCK` / `CHECK_CODE` row once the code is confirmed | X |
| 11 | Returns notifications (`RETURNS_NOTIF`) | Payments | CD_FMON | `F_LOT` (returns / NOC lots not processed), `F_NOCAGE` (NOC ageing) | **partial** (reviewer) — the notification back to the source is not checked: proposal P7 | X |
| 12 | Daily reconciliation (`DAILY_RECON`) | Reconciliation | CD_HCK | `A_RECON_3WAY` (three-way reconciliation; its variances are the *Open variances* card) | full | X |

A control with no covered check would always show *Healthy* — so the three gap controls are delivered **inactive**; activate each with its check row (or, by decision, as a manual-only control: then the reviewer's result and observation are the only evidence and the derived status stays *Healthy* — say so in its guidance).

**Mockup example → existing check (summary).** Payment files → FMON file checks; Clearing job → job cycle checks (configure the cycle); Base-rejected items → none (P2); ECT pending items → none (P3); Outbound interfaces → FMON gateway / interface stages; BlackLine → `A_GL_TRANSFER` (partial, P4); IDoc / interface checks → **dropped** (no IDocs in use; no proposal).

## 2. Proposals (not built in this change — configuration rows or new code, each needs a decision)

| ID | For | Proposal | Kind | Needs |
|---|---|---|---|---|
| P1 | Clearing job | Job cycle `CLEARING` with the clearing job as step (job name pattern, window, predecessor) in `ZCD_JOB_CYCLE` / `ZCD_JOB_STEP`; `B_CYCLE_TODAY` / `_PRIOR` then report it | configuration | job name and window (Control-M schedule) |
| P2 | Base-rejected items | Generic aggregate check row (`ZCL_CD_HCK_C_GENERIC_AGG`, `ZCD_HCK_AGG`: COUNT of rejected rows by rejection reason, AGE of the oldest) over the table that holds the Base rejects, approved in `ZCD_OPS_TABWL` (HCK, READ); thresholds amber / red; covered-check row `CD_HCK` / `GROUP2` = the new check ID | configuration | table, status field and value of a rejected item (VERIFY-SE11) |
| P3 | ECT pending items | Generic aggregate check row: COUNT and AGE of pending items in the ECT table (`ZECT_STATUS` pending values) | configuration | table / status values (VERIFY-SE11) |
| P4 | BlackLine | FMON outbound interface for the BlackLine extract file (`ZCD_FMON_IFACE` + `ZCD_FMON_SLA` deadline row); covered-check rows `CD_FMON` / `GROUP2` = interface | configuration | file name pattern, delivery deadline |
| P5 | Manual retrievals | Generic aggregate on the retrieval log (`ZCD_ACH_RTRV_LOG`): retrievals requested and not confirmed after n days | configuration | status field and values (VERIFY-SE11, as part B of the transactions dashboard) |
| P6 | Missing check IDs | Generic aggregate: cheque payments of the day without cheque number (DFKKCR / cheque history) — or a small check class if the condition needs a join | configuration or new code | the table and condition that mean "no check ID" |
| P7 | Returns notifications | FMON outbound interface of the returns notification to the source (PCLM) with its SLA, or a check on the request log status after a return | configuration (FMON) or new code | how the source is notified |

## 3. Payment lifecycle stages (`ZCD_OPS_PAYSTAGE`, `config/pay_stages.csv`)

| Stage | Seq | Source | Counted value | Active | Note |
|---|---|---|---|---|---|
| PENDING | 10 | REQUEST | worklist outcome `REQ_OPEN` (request due on the date, not yet in a payment run) | X | VERIFY the mockup's meaning of *Pending* with the business |
| NOT_PAID | 15 | REQUEST | worklist outcome `REQ_NOT_PAID` (not paid by the end of its due date) | X | the request stage (`PRQ_NO_ITEM` / `PRQ_PAYMENT_BLOCK` / `PRQ_NOT_IN_RUN`) can be its own stage (MATCH_VALUE = the stage) |
| SCHEDULED | 20 | REQUEST | — | blank | **VERIFY**: no confirmed SAP value; candidates: in a proposal run (DPAYH-XVORL), or a request with an open item not yet in a run (`PRQ_NOT_IN_RUN`) |
| SRCPOSTED | 30 | REQUEST | — | blank | **VERIFY**: "source posted" (request posted to FI-CA, item open) has no cheap live count today (DFKKOP by FIN per day is not indexed) |
| ISSUED / CONFIRMED / CLEARED / RETURNED / RETRIEVED / STOPPED | 40–90 | PAYRUN | DPAYH-ZZ_PAYMENT_STATUS (confirmed values, 2026-11-08) | X | newest non-proposal run row per payment document, run date = business date |
