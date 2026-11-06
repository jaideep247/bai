# Operations runbook — payment engine operations suite

> **First principle:** check the effect, not the job status — a green job that validated nothing is a failure.
> **Analogy:** a pilot's checklist — the same steps in the same order every morning, so nothing depends on memory.

## 1. Every morning (by 7:00)

1. Open the **morning report** e-mail (route MORNING) or run `ZCD_MORNING_REPORT` for today.
2. Read the scorecard: overall score, RAG per category A–E, module status EBS / FMON / HCK, health of the health check.
3. **Health of the health check red** → a module did not run or a run never closed (status R). Check the Control-M job and SM37 first; nothing else on the report can be trusted until this is green.
4. Work the **top open exceptions** list (oldest due date first). Each row names module, object and check code — use the triage tables below.
5. Check **alert delivery** (category E): failed deliveries mean someone was not told.

## 2. Triage by module

| Module | Where to look | Playbook |
|---|---|---|
| EBS validation | `ZCD_EBS_VALIDATE` (test mode to re-check), FEBAN/FPB7 for posting | `EBS_VALIDATION.md` §A3 |
| File monitoring | `ZCD_FMON_MONITOR` file board | `FMON_FILE_MONITORING.md` part A |
| Health checks | Morning report drill-down | `HCK_MORNING_REPORT.md` part A |
| Alerts | SE16 ZCD_OPS_ALERT_LOG by rule | `ALERTING.md` part A |

## 3. Owned exceptions

Every B/E/W finding is an exception in ZCD_OPS_FINDING with disposition O (open) and a due date (`SLA_DAYS_<module>_<severity>`). Assign an owner (disposition A), resolve with a reason (R) or waive with approval (W). Overdue exceptions are a category C check on the morning report.

## 4. Emergency switches

| Situation | Action | Effect |
|---|---|---|
| EBS validation blocks postings wrongly | TVARVC `ZCD_EBS_VALIDATION_MODE` = `M` (or `O`) | Monitor only / off — no transport needed |
| Alert storm | Deactivate the rule in ZCD_OPS_ALERT_RULE or raise THROTTLE_MIN | Immediate, logged |
| A check or rule fails repeatedly (PLUGIN_ERROR) | Deactivate its row (ZCD_HCK_DEF / ZCD_BTC_RULE / ZCD_FMON_CHK) | Others keep running. **EBS in enforce mode:** a failing rule blocks posting of its packages (fail closed). Deactivating the rule removes that check — get the rule owner's approval, or switch to `M` for the affected period |
| Remove the suite | Unschedule the three jobs, set the switch to `O` | Back to previous behaviour in < 15 min |

## 5. Re-running

All three reports are re-runnable: EBS and HCK create a new run; FMON registry events are idempotent (same source row, same stage = one event). Use test mode to check a fix before a productive re-run.

## 6. Who to call

| Topic | Team |
|---|---|
| Bank codes, statements, balances | Treasury / bank relationship |
| PRISM hand-off, acks | Middleware (PRISM) support |
| Returns, NOC, clarifications | Disbursement and collections operations |
| Jobs, Control-M | SAP IT & Control-M team |
| Suite configuration and code | Payment engine RTB |
