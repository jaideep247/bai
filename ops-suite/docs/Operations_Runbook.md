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

## 4a. Payment trace — "where is this payment?" (L1 / L2)

`ZCD_OPS_PAYMENT_TRACE` (read-only; details `Payment_Trace.md`). Triage path: **search → correlate → inspect → hand off**.

1. **Search.** Enter the FIN ID and the source from the incident (e.g. PCLM). Without them: the clearing / payment document (FPL9, FPE3) or the cheque number.
2. **Correlate.** Check attempt 0 first: exactly one REQUEST row (SUCCESS) and the open item(s). AMBIGUOUS here (two SUCCESS rows, competing or mismatching partners) → stop and hand the candidates to L2 / the source team; do not pick one.
3. **Inspect.** Each further attempt is one clearing reference (HISTORICAL = reversed / reset, CURRENT = what DFKKOP shows today). Read the row flagged *1st gap*:

| First gap | Likely meaning | Next diagnostic check (no change to anything) | Owner |
|---|---|---|---|
| PAYMENT MISSING | Item not paid yet or payment run did not pick it | FPL9 item, payment lock, last FPY1 run of the partner interval | Payment operations |
| FILE_GENERATED MISSING / UNAVAILABLE | File not written, or ZCDT_REGUT link not configured | ZCDT_REGUT for LAUFD/LAUFI; `TRACE_SRC_REGUT` | Payment operations / suite admin |
| PRISM_HANDOFF MISSING / FILE_NOT_MONITORED | SAP wrote the file, PRISM receipt not seen | `ZCD_FMON_MONITOR` board for the business date | Integration (PRISM) |
| BANK_ACK MISSING / FAILED | No acknowledgement / NACK | FMON board, ACK table, bank portal | Treasury / bank liaison |
| SETTLEMENT MISSING | No bank statement line yet (timing) or reference mismatch | FEBAN for the date range and reference | Cash management |
| SETTLEMENT FAILED | Return lot, retrieval or terminal cheque status | FP09 / returns lot, ZCD_CHECK_HIST | Returns team |
| CLEAR_HISTORY REVERSAL_HISTORY_MISSING | Item was reversed / reset but its earlier clearing cannot be found | DFKKRAPT / FP08 history; confirm `TRACE_SRC_HISTORY` | L2 / suite admin |
| GL MISSING (NOT_SUMMARISED / GL_NOT_TRANSFERRED) | Reconciliation key not closed or not transferred | FPG1 / FPF3 for the FIKEY; morning report category | Finance close |
| UNAVAILABLE / NOT_AUTHORISED | You may not see that company code | Ask an authorised colleague; never report it as missing | — |

4. **Hand off.** Export the ALV (masked) and copy the summary line (message 700: verdict, first gap, attempt) into the ticket with the record keys of the last VERIFIED and the first-gap rows. Recovery (re-run, re-send, reversal, lock release) is done only by the owning team under its runbook — the trace never does it.

## 5. Re-running

All three reports are re-runnable: EBS and HCK create a new run; FMON registry events are idempotent (same source row, same stage = one event). Use test mode to check a fix before a productive re-run.

**FMON after a network or interface outage.** Once the connection is back (PRISM, bank SFTP, ACK feed), simply re-run `ZCD_FMON_MONITOR` for the affected business date — or wait for the next 30-minute cycle. The run reads the source tables again and writes each missing stage event once; events already registered are not duplicated (same source row + stage = one event), and SLA findings raised during the outage stay in that run's history — the re-run evaluates the late stage again (the exception carry-forward closes what is no longer found). For a business date older than the job variant's window, run it with that date in the selection. Nothing has to be deleted or reset first.

## 5b. Statuses introduced by the audit fixes

| Where | Status / finding | Meaning | Action |
|---|---|---|---|
| Run header | **N** (no data) | The source delivered nothing to evaluate; RAG grey, never green | Check the FEB date range or the file path; if an empty feed is normal for that variant set `EBS_EMPTY_FEED_OK` |
| EBS line | AWAITING_LOT_TRANSFER (warning) | Lookup not found while the statement is younger than `EBS_INFLIGHT_HOURS` — FPB7 / FP09 may still be running | None if it clears on the next run; otherwise investigate the lot transfer |
| EBS line | Disposition NOT_POSTED / ON_ACCOUNT / EXCEPTION / BLOCK | What the posting caller must do with the line | Follow the disposition; BLOCK lines need a release (EBS release app) or a fix |
| FMON file | PERSIST_CONFLICT | Another run (or a manual status) changed the file first; the newer state was kept | None unless it repeats |
| FMON file | LOT_SCAN_TRUNCATED / FILE_REF_AMBIGUOUS / MALFORMED_SOURCE_ROW | Completeness or identity could not be proven | Investigate the lot / source rows; nothing is marked complete meanwhile |
| Alert log | C older than its run | Delivery was interrupted (dump) | Re-send, then set to F |

## 5a. Housekeeping

`ZCD_OPS_PURGE` (monthly, Control-M, test mode off) deletes the suite's own history older than the retention parameters (`RETENTION_DAYS_*`, never below 30 days): runs with their findings, alert log, FMON events, HCK metrics. Runs that still hold an open, assigned or validly waived exception are kept. Run it in test mode first after any parameter change; the job log shows one line per target (message 060). No other housekeeping job is needed for the suite's tables; expired application logs of object `ZCD_OPS` are deleted with the standard SLG2 job.

## 6. Who to call

| Topic | Team |
|---|---|
| Bank codes, statements, balances | Treasury / bank relationship |
| PRISM hand-off, acks | Middleware (PRISM) support |
| Returns, NOC, clarifications | Disbursement and collections operations |
| Jobs, Control-M | SAP IT & Control-M team |
| Suite configuration and code | Payment engine RTB |
