# Operations runbook — payment engine operations suite

> **First principle:** check the effect, not the job status — a green job that validated nothing is a failure.
> **Analogy:** a pilot's checklist — the same steps in the same order every morning, so nothing depends on memory.

## 1. Every morning (by 7:00)

1. Open the **morning report** e-mail (route MORNING) or run `ZCD_MORNING_REPORT` for today.
2. Read the scorecard: overall score, RAG per category A–E, payment engine area status EBS / FMON / HCK, health of the health check.
3. **Health of the health check red** → a payment engine area did not run or a run never closed (status R). Check the Control-M job and SM37 first; nothing else on the report can be trusted until this is green.
4. Work the **top open exceptions** list (oldest due date first). Each row names payment engine area, object and check code — use the triage tables below.
5. Check **alert delivery** (category E): failed deliveries mean someone was not told.

## 2. Triage by payment engine area

| Payment engine area | Where to look | Playbook |
|---|---|---|
| EBS validation | `ZCD_EBS_VALIDATE` (test mode to re-check), FEBAN/FPB7 for posting | `EBS_VALIDATION.md` §A3 |
| File monitoring | `ZCD_FMON_MONITOR` file board | `FMON_FILE_MONITORING.md` part A |
| Health checks | Morning report drill-down | `HCK_MORNING_REPORT.md` part A |
| Alerts | SE16 ZCD_OPS_ALERT_LOG by rule | `ALERTING.md` part A |

## 3. Owned exceptions

Every B/E/W finding is an exception in ZCD_OPS_FINDING with disposition O (open) and a due date (`SLA_DAYS_<pe_area>_<severity>`). Work them in the **Owned exceptions** app (`RAP_Ops_Apps.md`): *Assign* an owner (A), *Resolve* with a reason (R), or *Request waiver* (reason + end date) and have a **second person** *Approve waiver* (W). Every action is in the history of the exception. Overdue exceptions are a category C check on the morning report.

| Situation | App | What you do | Second person? |
|---|---|---|---|
| A bank line is blocked (e.g. R14 unmapped code) and must be posted today | **Blocked line releases** | Create a release for the line and check code with reason and evidence; the approver approves; then post (FEBAN/FPB7). Fix the mapping afterwards so it does not recur | Yes (ZCD_OPS 85) |
| A known health-check finding for a planned outage or a known issue | **Health check suppressions** | Create with check, pattern / company code, period, reason; *End now* when fixed | Only for more than 7 days |
| PRISM / ACK / bank confirmed a file stage that SAP never recorded | **Monitored files — manual status** | *Set status manually* with stage, reason and evidence; only forward moves are possible | No |
| A PRISM payment request was handled outside SAP | **PRISM requests handled manually** | Record request, handling reference and reason; the exception closes. SAP re-sends nothing | No |

**Re-runs do not reset the queue.** When the next run raises the same exception (same payment engine area, object and check), the new row keeps the owner, due date and first-seen time and counts the occurrence; the earlier row becomes S (superseded) — so each exception is listed once. A valid waiver stays W. When a run evaluates the object again and the finding is gone, the exception is resolved automatically ("Passed on re-run …"). A run in which a rule, check or source failed (PLUGIN_ERROR) resolves nothing.

## 4. Emergency switches

| Situation | Action | Effect |
|---|---|---|
| EBS validation blocks postings wrongly | TVARVC `ZCD_EBS_VALIDATION_MODE` = `M` (or `O`) | Monitor only / off — no transport needed |
| Alert storm | Deactivate the rule in the Alerting & parameters app or raise THROTTLE_MIN | Immediate, logged |
| Change a threshold / SLA / rule parameter in production | Configuration app of the area → Edit → change the existing row → Save | No transport; logged in SCU3. New rows only in DV1 and by transport |
| A check or rule fails repeatedly (PLUGIN_ERROR) | Deactivate its row (ZCD_HCK_DEF / ZCD_BTC_RULE / ZCD_FMON_CHK) | Others keep running. **EBS in enforce mode:** a failing rule blocks posting of its packages (fail closed). Deactivating the rule removes that check — get the rule owner's approval, or switch to `M` for the affected period |
| Remove the suite | Unschedule the three jobs, set the switch to `O` | Back to previous behaviour in < 15 min |
| Job refused with RUN_LOCKED (message 040) | Check SM37 for the run named in the message; wait for it, or — only if that job is gone — delete the lock in SM12 (table ZCD_OPS_LOCK, argument client + payment engine area + variant) | One run per payment engine area + variant (FMON: one per system); the refusal is alerted (rule RUN_LOCKED) |

## 5. Re-running

All three reports are re-runnable: EBS and HCK create a new run; FMON registry events are idempotent (same source row, same stage = one event). Use test mode to check a fix before a productive re-run.

## 5a. Housekeeping

`ZCD_OPS_PURGE` (monthly, Control-M, test mode off) deletes the suite's own history older than the retention parameters (`RETENTION_DAYS_*`, never below 30 days): runs with their findings, alert log, FMON events, HCK metrics. Runs that still hold an open, assigned or validly waived exception are kept. Run it in test mode first after any parameter change; the job log shows one line per target (message 060).

## 6. Who to call

| Topic | Team |
|---|---|
| Bank codes, statements, balances | Treasury / bank relationship |
| PRISM hand-off, acks | Middleware (PRISM) support |
| Returns, NOC, clarifications | Disbursement and collections operations |
| Jobs, Control-M | SAP IT & Control-M team |
| Suite configuration and code | Payment engine RTB |
