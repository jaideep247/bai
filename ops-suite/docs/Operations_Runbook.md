# Operations runbook — payment engine operations suite

> **First principle:** check the effect, not the job status — a green job that validated nothing is a failure.
> **Analogy:** a pilot's checklist — the same steps in the same order every morning, so nothing depends on memory.

## 0. Start of every shift — the production-support overview page (L1 / L2)

Launchpad space **Production Support** → page *Overview* → *Production support overview* (read-only; `Dashboard_Production_Support.md`). Always in this order:

1. **Monitor freshness card first.** One row per batch monitor: FMON (stale after 15 min), EBS (26 h), HCK (26 h). A **red** row means that area's cards show old numbers — do not report "nothing failed" for it. Check the job of that monitor in SM37 (native SAP jobs for FMON and the morning report; Control-M for EBS) (`ZCD_FMON_MONITOR_ALL`, `ZCD_EBS_VALIDATE`, `ZCD_MORNING_REPORT`), escalate to the batch owner, then continue with the other areas. The transactions cards are live and never stale.
2. **Open critical exceptions card.** Open / assigned B and E exceptions of every area, overdue first. Tap → owned-exceptions app: assign an owner the same shift; overdue ones go to the team lead.
3. **Health checks card.** Overall RAG of the last morning report and the red / amber checks → §1 below and the health check dashboard (category → check → metric history → findings).
4. **Files card** (rejected, unprocessed, breached, latest failures) → §4b.
5. **EBS card** (failed / blocked lines, lines not evaluated, POSTING_INCOMPLETE, latest problems) → EBS validation dashboard: statement → lines → findings / returns and NOCs; POSTING_INCOMPLETE → §5c.
6. **Transactions card** (funnel posted → paid → settled, returned, open) and *errored / stuck* list → transactions dashboard → transaction → payment runs / returns and NOC lot items → payment trace (§4a) with the FIN (or clearing document). Returns are reported by DFKKRP reason, NOCs by DFKKNRP reason.
7. **Hand off** per area as in §4a / §4b: area, as of, object keys, check code, owner. The page and the dashboards change nothing — recovery stays with the owning team under its runbook.

## 1. Every morning (by 7:00)

1. Open the **morning report** e-mail (route MORNING) or run `ZCD_MORNING_REPORT` for today.
2. Read the scorecard: overall score, RAG per category A–E, payment engine area status EBS / FMON / HCK, health of the health check.
3. **Health of the health check red** → a payment engine area did not run or a run never closed (status R). Check the job in SM37 first (native SAP jobs for FMON, the morning report and purge; the Control-M job for EBS); nothing else on the report can be trusted until this is green.
4. Work the **top open exceptions** list (oldest due date first). Each row names payment engine area, object and check code — use the triage tables below.
5. Check **alert delivery** (category E): failed deliveries mean someone was not told.

## 2. Triage by payment engine area

| Payment engine area | Where to look | Playbook |
|---|---|---|
| EBS validation | EBS validation dashboard (`ZUI_CD_EBS_DASH_O4`); `ZCD_EBS_VALIDATE` (test mode to re-check), FEBAN/FPB7 for posting | `EBS_VALIDATION.md` §A3, `Dashboard_EBS_Validation.md` |
| File monitoring | File monitoring dashboard (launchpad, `ZUI_CD_FMON_FLOW_O4`) — §4b; `ZCD_FMON_MONITOR` file board | `FMON_FILE_MONITORING.md` part A, `Dashboard_File_Monitoring.md` |
| Health checks | Health check dashboard (`ZUI_CD_HCK_DASH_O4`); morning report drill-down | `HCK_MORNING_REPORT.md` part A, `Dashboard_Health_Check.md` |
| Transactions | Transactions dashboard (`ZUI_CD_TRX_DASH_O4`, live); payment trace §4a | `Dashboard_Transactions.md` |
| Alerts | SE16 ZCD_OPS_ALLOG by rule | `ALERTING.md` part A |

## 3. Owned exceptions

Every B/E/W finding is an exception in ZCD_OPS_FINDING with disposition O (open) and a due date (`SLA_DAYS_<pe_area>_<severity>`). Work them in the **Owned exceptions** app (`RAP_Ops_Apps.md`): *Assign* an owner (A), *Resolve* with a reason (R), or *Request waiver* (reason + end date) and have a **second person** *Approve waiver* (W). Every action is in the history of the exception. Overdue exceptions are a category C check on the morning report.

| Situation | App | What you do | Second person? |
|---|---|---|---|
| A known health-check finding for a planned outage or a known issue | **Health check suppressions** | Create with check, pattern / company code, period, reason; *End now* when fixed | Only for more than 7 days |
| PRISM / ACK / bank confirmed a file stage that SAP never recorded | **Monitored files — manual status** | *Set status manually* with stage, reason and evidence; only forward moves are possible | No |
| A PRISM payment request was handled outside SAP | **PRISM requests handled manually** | Record request, handling reference and reason; the exception closes. SAP re-sends nothing | No |

**Re-runs do not reset the queue.** When the next run raises the same exception (same payment engine area, object and check), the new row keeps the owner, due date and first-seen time and counts the occurrence; the earlier row becomes S (superseded) — so each exception is listed once. A valid waiver stays W. When a run evaluates the object again and the finding is gone, the exception is resolved automatically ("Passed on re-run …"). A run in which a rule, check or source failed (PLUGIN_ERROR) resolves nothing.

## 4. Emergency switches

| Situation | Action | Effect |
|---|---|---|
| Alert storm | Deactivate the rule in the Alerting & monitor freshness app or raise THROTTLE_MIN | Immediate, logged |
| Change a threshold / SLA / rule parameter in production | Configuration app of the area → Edit → change the existing row → Save | No transport; logged in SCU3. New rows only in DV1 and by transport |
| A check or rule fails repeatedly (PLUGIN_ERROR) | Deactivate its row (ZCD_HCK_DEF / ZCD_BTC_RULE / ZCD_FMON_CHK) | Others keep running. Deactivating the rule removes that check — get the rule owner's approval |
| Remove the suite | Unschedule the three jobs | Back to previous behaviour in < 15 min |
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

## 4b. File monitoring dashboard — "are the files flowing?" (L1 / L2)

Launchpad space **Production Support** → *File monitoring dashboard* (read-only; details `Dashboard_File_Monitoring.md`). Work it in this order, every time:

1. **Stale monitor first.** Header / tile *Stale monitor*: as of = end of the last completed FMON run. **Stale (red, older than 15 min or no run)** → nothing else on the page is current. Check SM37 job `ZCD_FMON_MONITOR_ALL` (SM36 periodic job every 5 minutes — aborted? RUN_LOCKED? not released?) and the morning report category *health of the health check*; escalate to the batch owner. Do not report "no rejected files" from a stale page.
2. **Breached SLA.** Filter SLA status = BREACHED (tile *Breached SLA*). Each file missed an SLA stage (NO_PRISM_HANDOFF, NO_BANK_ACK, …): open the file → *Open exceptions* → follow `FMON_FILE_MONITORING.md` §A5 for the check code. Then tile *Missing files* (FILE_MISSING has no file row).
3. **Rejected / errored.** Flow bucket REJECTED (tile *Rejected today*): NACK from the bank, inbound processing FAILED, or PRISM_FAILED (PRISM status API, §4c). Open the file → *Events* shows who said so and when.
4. **Unprocessed / partial.** Tile *Unprocessed* or bucket PARTIAL: returns / NOC items not yet accounted for (LOT_UNPROCESSED); work the lot (FP09 / NOC application) and wait for the next run.
5. **Drill to the file → events → open exceptions → payment trace.** Events = the evidence timeline of the file; open exceptions = what the monitor concluded (work them in the owned-exceptions app, never here). For a payment inside the file, run `ZCD_OPS_PAYMENT_TRACE` with the FIN / document from the incident (the trace does not take a file reference yet — navigation is proposed).
6. **Hand off.** Copy business date, interface, file name, bucket, SLA status, as of and the check code into the ticket. Recovery (re-send, re-load, manual status) is done by the owning team under its runbook; the dashboard changes nothing. Never type personal data into manual-status reasons — they are shown on the dashboard's events.

UNKNOWN bucket → a stage the dashboard does not map yet: tell the suite admin (mapping table in the dashboard doc §3). Only interfaces with a `ZCD_FMON_IFACE` row are shown — an absent interface is not a healthy one (`Interface_Inventory.md`).

## 4c. PRISM status API — PRISM milestones (L1 / L2)

PRISM reports every file / message it receives, delivers or cannot deliver (`PRISM_Status_API.md`); FMON shows them as `PRISM_RECEIVED`, `PRISM_DELIVERED`, `PRISM_FAILED` within seconds (bgPF unit) and at the latest with the next 5-minute run. Never change a payment file, job or routing from here.

| Situation | What it means | Next diagnostic check (no change to anything) | Owner |
|---|---|---|---|
| **PRISM_FAILED** (R) | PRISM gave up processing or delivering the file | SE16 `ZCD_FMON_PRISM` by file reference: `ERROR_CODE`, `ERROR_TEXT`, `PRISM_REF`, `COUNTERPARTY`; look the transfer up in the PRISM console. PRISM retries on its own — a later `DELIVERED` supersedes the failure and the next 5-minute run resolves the exception. Re-send only by the owning team under its runbook | Integration (PRISM) |
| **NO_PRISM_RECEIVED** / **PRISM_RECEIVED_LATE** — missing PRISM receipt | SAP handed the file over (SENT_TO_PRISM), PRISM did not confirm receipt within the SLA | 1) Is the API reachable? SE16 `ZCD_FMON_PRISM` — newest `RECEIVED_AT` of today; no rows at all for an hour = PRISM is not calling (ICF node inactive, credentials, network) → SICF / SMICM log, ask PRISM for their 4xx/5xx log. 2) Rows exist but not for this file → PRISM transfer job / OS command (`ZICD_CALL_SM69_COMMAND_NEW`), PRISM inbound queue | Integration (PRISM) / Basis |
| **PRISM_QUEUE_LONG** (A) — many bank files queued in PRISM | PRISM releases ACH and wire files one at a time, 2 minutes apart (user 2026-11-06). When PRISM received this file, more ACH / wire files were waiting ahead of it than `FMON_PRISM_QUEUE_MAX` (default 30) covers; the delivery SLA stops growing at that cap, so a later `PRISM_DELIVERED_LATE` / `NO_PRISM_DELIVERED` on the same files is the consequence, not a second problem | **Check PRISM, not SAP:** 1) SE16 `ZCD_FMON_PRISM` for the business date — are `DELIVERED` rows still arriving about every 2 minutes (queue moving, just long) or has the last `DELIVERED` stopped (queue jammed)? 2) PRISM console / PRISM operations: bank connection, throttle setting, a file stuck at the head of the queue. 3) Only if `RECEIVED` rows stop too: SAP hand-over (row above). Nothing to re-run in SAP; never re-send from SAP while PRISM still holds the files (duplicates). A scope question (one queue for all banks or one per bank, `FMON_PRISM_THROTTLE_SCOPE`) goes to the suite admin | Integration (PRISM) |
| **PRISM_DELIVERED_LATE** on an ACH / wire file of a busy cycle | The allowance already includes 2 min × the ACH / wire files ahead in PRISM's queue (`FMON_FILE_MONITORING.md` §A3a) — this file waited longer than its position explains | Same as PRISM_QUEUE_LONG step 1–2. Positive pay / stop pay files are not throttled: their delivery SLA has no allowance | Integration (PRISM) |
| **PRISM_UNKNOWN_FILE** (A) | PRISM reported an outbound file SAP has no generation / send record of (after `GRACE_MIN`) | Compare `FILE_REF` with the SAP file name / key (`ZCDT_REGUT`): a renamed file, a manual transfer outside SAP, or PRISM sending another reference than FMON keys the flow by (`PRISM_Status_API.md` §8) | Integration / suite admin |
| **PRISM_NOT_LOADED** (A) | PRISM delivered an inbound file SAP has not received after `GRACE_MIN` | Load job of the flow (SM37), AL11 inbound directory, then the SAP-side evidence table | Payment operations |
| **UNMAPPED_FILE** with source `PRISM` (A) | A PRISM event whose reference matches no interface and carries no known `interfaceId` — never dropped, stays unprocessed and is reported every run | Add the interface row / name pattern (DV1, transport) or agree the `interfaceId` with PRISM; the events are applied by the next run after the transport | Suite admin |
| PRISM events stay unprocessed (`PROCESSED_AT` initial for more than 10 min) | The instant unit did not run or finish | **SBGRFCMON** — bgPF units of queue / destination for bgPF (name `ZCD_FMON_PRISM`): failed or waiting units, error text; restart or delete a failed unit there. The 5-minute run applies the events anyway (safety net), so the monitor stays complete — only the latency is lost | Basis / suite admin |
| PRISM receives 403 / 401 | The technical user lacks `Z_CD_OPS_PRISM` / S_ICF, or its certificate / password changed | SU53 / ST01 for the PRISM user; STRUST certificate mapping | Security / Basis |
| PRISM receives 409 | PRISM reused an event ID for another payload | Nothing on SAP side — the first event stays; PRISM defect | PRISM |

Switch off (emergency, e.g. a flood of calls): deactivate the SICF node `/sap/zcd_ops/prism_status` — PRISM then gets 403/404 and buffers; FMON keeps working from SAP's own evidence. Stopping only the instant units: ZCA_PARAM `FMON_PRISM_INSTANT` value row set to blank (BOOL off = registry only; app *Parameter areas*, area `CD_FMON`) or lock the bgPF destination in SBGRFCCONF (the 5-minute run takes over).

## 4d. BAI not processed by 10:00 — STAGE_DEADLINE_MISSED (L1 / L2)

Mail from rule `FMON_BAIDL` to `ZCD_PAYOPS` between 10:00 and 10:05 US Central (`FMON_FILE_MONITORING.md` §A3b). One finding per interface and business date; later runs do not mail again (ZCD_OPS_ALLOG status R) until the escalation to `ZCD_RTBLEAD` after 30 minutes. The message (and the finding's GROUP2) names the earliest missing step. Nothing in SAP is changed from here.

| GROUP2 / message | What it means | Next diagnostic check (no change to anything) | Owner |
|---|---|---|---|
| `NOT_RECEIVED` (272) | No statement file of the bank arrived, no statement of the date is in FEBKO | FMON board / dashboard for the interface (PRISM_DELIVERED?); PRISM console; Control-M statement job; bank portal | Integration (PRISM) / Treasury |
| `NOT_IMPORTED` (273, "x of y payment engine account(s) imported") | The file is there (PRISM delivered, or some accounts imported) but FEBKO lacks the statement of at least one payment engine account | **First** BANK_KEY consistency: `ZCD_EBS_ACCT-BANK_KEY` of the bank's accounts = `ZCD_FMON_IFACE-BANK_KEY` of the interface (same bank identifier as in the statement, EBS / FMON configuration apps) — a different value makes every account "not imported"; then FF.5 / FEBAN import log of the run; FEBKO by house bank (BUKRS / HBKID / HKTID of the missing accounts, statement date in the message); is an account new or inactive in ZCD_EBS_ACCT (EBS configuration app)? | Cash management (bank statement import) |
| `NOT_POSTED` (274, "n of m in-scope line(s) not posted") | Every account imported; lines that should post are not posted (same definition as EBS POSTING_INCOMPLETE; an unmapped code also counts here) | FEBAN post-processing for the statement date; the FEBP job in SM37; EBS dashboard POSTING_INCOMPLETE / UNMAPPED_BTC for the statements | Cash management / payment operations |
| "Posting state not read or statement read capped" (279) | Imported, but processing cannot be proven (EBS_FEB_POSTED_FIELDS OFF, or more statements than FMON_MAX_ROWS) | Parameter values (app *Parameter areas*); suite admin | Suite admin |

When the step is done the next 5-minute run resolves the exception automatically (no manual close). A false alert on a bank holiday: check the factory calendar of `ZCD_FMON_CAL` (HOLIDAY row with 0 files); every payment engine account receives a statement every business day (confirmed 2026-11-07), so a missing account statement is a real gap — ask the bank / Treasury, do not treat it as normal.

## 5. Re-running

All three reports are re-runnable: EBS and HCK create a new run; FMON registry events are idempotent (same source row, same stage = one event). Use test mode to check a fix before a productive re-run.

**FMON after a network or interface outage.** Once the connection is back (PRISM, bank SFTP, ACK feed), simply re-run `ZCD_FMON_MONITOR` for the affected business date — or wait for the next 30-minute cycle. The run reads the source tables again and writes each missing stage event once; events already registered are not duplicated (same source row + stage = one event), and SLA findings raised during the outage stay in that run's history — the re-run evaluates the late stage again (the exception carry-forward closes what is no longer found). For a business date older than the job variant's window, run it with that date in the selection. Nothing has to be deleted or reset first.

## 5c. EBS POSTING_INCOMPLETE — posting not complete when the validation ran

`ZCD_EBS_VALIDATE` runs after the statement import, the posting job (FEBP) and the payment clearing job (`EBS_VALIDATION.md` §A0). **POSTING_INCOMPLETE** (rule S13, one finding per statement, count and total of the lines; run message "… entries not evaluated (posting not complete)"; run amber or red, never green) means entries that should be posted were not posted when the run read FEBEP. Their posting-dependent checks (R07, R07L, R07R, R18, R19, R21, S10) were **not evaluated** — nothing was passed or failed for them, and their earlier exceptions stay open.

1. **Predecessors.** In Control-M (and SM37 for the SAP jobs) check that the statement import, FEBP and the payment clearing job for that business date ended successfully *before* the validation started. A predecessor still running, failed or started late → let it finish (or have its owner re-run it under its own runbook); the suite never starts or reruns it.
2. **Re-run the validation** once the predecessors have finished: start `ZCD_EBS_VALIDATE` with the same variant (Control-M rerun or SE38). The run is idempotent — it reads the statements again, raises an exception that is still true once (same owner, due date and first-seen time) and resolves POSTING_INCOMPLETE automatically when the lines are posted. Nothing has to be deleted first.
3. **Still incomplete after the predecessors finished** → the lines were left unposted: work them in FEBAN post-processing (and FPCPL for payment-lot clarification) under the cash-management runbook, then re-run step 2.
4. **Every statement of every run reports it** → check `EBS_FEB_POSTED_FIELDS` (VB1OK / VB2OK — the posted flags, confirmed 2026-11-07; if posting area 2 is not used and VB2OK stays blank on posted items, set `VB1OK`). A name that is not a FEBEP field stops the run with message 051.

## 5d. EBS statements out of scope — "n statements out of scope" in the run message

Since 2026-11-06 (user decision) `ZCD_EBS_VALIDATE` validates, and the EBS dashboard shows, an imported statement only when **every** line's FEBEP-XBLNR carries an active payment engine account: XBLNR = bank text + 10-character account + counter (`JPMC8XX1174412334` → `8XX1174412`), compared with `ACCOUNT_NO` of the active rows in the EBS configuration app (`EBS_VALIDATION.md` §A0a). Any other statement is skipped: no finding, not on the dashboard, its earlier exceptions stay open; the run message says *n statements out of scope (lines not all payment engine accounts)*.

0. **Run grey (NO_DATA) with "n statements out of scope"?** Nothing was in scope that day. If payment engine statements were expected, the account configuration is the first suspect: check that the 10-character accounts are maintained and active in the EBS configuration app (`ACCOUNT_NO`), then rerun.
1. **Expected?** Statements of house bank accounts that are not payment engine accounts, or genuinely mixed statements, are out of scope by design — nothing to do.
2. **A payment engine statement is missing from the dashboard / the count rose unexpectedly** → look at its lines in FEBAN / SE16 FEBEP (KUKEY): derive the account from each XBLNR (letters removed, first 10 characters).
   - Account not in the EBS configuration app, or the row is inactive → **maintain / activate the account** (`ZCD_EBS_ACCT`, field *Payment engine account (XBLNR, 10 characters)*, upper case, ACTIVE = X; new rows by transport from DV1, existing rows editable in production), then re-run the variant (idempotent).
   - A line with a blank or unexpected XBLNR → clarify with Treasury / the bank interpretation owner how the line was imported; the statement stays out of scope until every line carries an account.
   - The bank changed the XBLNR layout (account not 10 characters, digits in the bank text) → a change request: `GC_PE_ACCOUNT` and the dashboard view change together (`EBS_VALIDATION.md` §B6).
3. Exceptions of a statement that went out of scope stay open (a statement not evaluated resolves nothing): close them in the exceptions app with a reason if the account is intentionally no longer a payment engine account.

## 5b. Statuses introduced by the audit fixes

| Where | Status / finding | Meaning | Action |
|---|---|---|---|
| Run header | **N** (no data) | The source delivered nothing to evaluate; RAG grey, never green | Check the FEB date range or the file path; if an empty feed is normal for that variant set `EBS_EMPTY_FEED_OK` |
| EBS run message | *n statements out of scope* | Imported statements whose lines are not all payment engine accounts (XBLNR) were skipped — no finding, not on the dashboard | §5d: expected, or maintain / activate the account in the EBS configuration app |
| EBS statement | POSTING_INCOMPLETE (S13, warning) | Entries expected to post were not posted when the run read FEBEP; their posting-dependent checks were not evaluated | §5c: check the predecessor jobs, re-run `ZCD_EBS_VALIDATE` |
| EBS line | AWAITING_LOT_TRANSFER (warning) | Lookup not found while the statement is younger than `EBS_INFLIGHT_HOURS` — FPB7 / FP09 may still be running | None if it clears on the next run; otherwise investigate the lot transfer |
| FMON file | PERSIST_CONFLICT | Another run (or a manual status) changed the file first; the newer state was kept | None unless it repeats |
| FMON file | LOT_SCAN_TRUNCATED / FILE_REF_AMBIGUOUS / MALFORMED_SOURCE_ROW | Completeness or identity could not be proven | Investigate the lot / source rows; nothing is marked complete meanwhile |
| Alert log | C older than its run | Delivery was interrupted (dump) | Re-send, then set to F |

## 5a. Housekeeping

`ZCD_OPS_PURGE` (monthly, native SAP job, test mode off) deletes the suite's own history older than the retention parameters (`RETENTION_DAYS_*`, never below 30 days): runs with their findings, alert log, FMON events, HCK metrics, PRISM status events. Runs that still hold an open, assigned or validly waived exception are kept. Run it in test mode first after any parameter change; the job log shows one line per target (message 060). No other housekeeping job is needed for the suite's tables; expired application logs of object `ZCD_OPS` are deleted with the standard SLG2 job.

## 5e. Patterns — check what a pattern captures before activating it (PCRE)

All configured patterns (EBS flow, FMON file names, HCK job names and lists, suppression keys, alert rules) are **PCRE matched to the complete value, case ignored** (`DEVELOPMENT_STANDARDS.md` §3). Before saving or activating a pattern:

1. Run **`ZCD_OPS_PATTERN_CHECK`** (authorisation ZCD_OPS display for the area): pattern area, optional **ad-hoc pattern** (the new one, before it is saved), date window (default last 7 days), maximum values read (default 5 000).
2. The list shows problems first: **INVALID** patterns (do not compile), **NO_MATCH** values (real records of the window that no pattern captures — these would not come), **UNUSED** patterns (capture nothing in the window), then **MATCHED** rows (value, pattern, where it is maintained, count — a count above 1 means two patterns overlap).
3. The message line gives values read, values not captured, unused patterns. A capped read (message 747) may hide values: narrow the window or raise the cap.
4. Save the pattern only when the records that must be captured are MATCHED by it and nothing unwanted is.

Sources per area: EBS_FLOW = FEBEP-XBLNR of the configured accounts (FEBKO-AZDAT in the window), FMON_FILE = file names of ZCD_FMON_FILE (business date), HCK_JOB = TBTCO job names (planned or started in the window), HCK_SUPPR = object keys of HCK findings, ALERT_* = rule IDs / check codes / groups of findings (runs started in the window).

**Migration of existing rows (once, after the pull):** run **`ZCD_OPS_PATTERN_MIGRATE`** in **test mode** (default) in DV1: every pattern row with old → new and a status — CONVERT (CP wildcard → PCRE: metacharacters escaped, `*` → `.*`, `+` → `.`, `#x` → literal x), UNCHANGED (same in both), ALREADY_PCRE (left as it is — review it), INVALID / TOO_LONG (never written; shorten or rewrite the pattern in the app). Then run it in **update mode** with the customizing request: only CONVERT rows are written (change stamps set, customizing rows recorded on the request, one commit), the list shows WRITTEN. Transport the request to QA1 / PS4. ZCD_HCK_SUPPRESS (application data, not transported) is converted by running update mode in each system (ZCD_OPS change for HCK; the client must allow changes). Run `ZCD_OPS_PATTERN_CHECK` per area afterwards.

## 5f. Who receives alert e-mails — SO23 distribution lists (L1 / L2)

E-mail alerts go to **SAPoffice shared distribution lists** (transaction SO23), never to addresses kept in
the suite. The alert rule names the list (`config/alert_seed.md`: `ZCD_PAYOPS`, `ZCD_RETOPS`, `ZCD_COMPL`,
`ZCD_RTBSUP`, `ZCD_RTBLEAD`).

| Task | How |
|---|---|
| Add / remove a person | SO23 → shared distribution list → maintain contents (internet address or SAP user with an e-mail address in SU01). Takes effect with the next alert — no transport, no rule change |
| Check who would receive an alert | SO23 → display the list named in the rule's DESTINATION / ESCALATION_DEST |
| Alert logged F with message 027 | The list named in the rule no longer exists or is not shared — recreate it in SO23 (or correct the rule in the configuration app, which refuses an unknown list, 419) |
| Alert logged S but nobody received it | SOST for the send request: list empty, member without e-mail address, or SAPconnect (SCOT) queue not running |

SO23 lists are client-specific and not transported: keep members aligned in QA1 and PS4 by hand.

## 5h. Adding a deadline alert (or a similar alert) — DV1 → QA1 → PS4 (user decision 2026-11-07)

**A new configuration row reaches production only by customizing transport from DV1** — also a deadline, SLA, calendar row or alert rule (`RAP_Config_Apps.md` §2, design D-3). In PS4 the configuration apps offer no *Create* and no *Delete*.

Example — "alert if the PNC ACH returns file is not fully processed by 16:00":
1. **DV1 — check the interface and calendar.** App *File monitoring setup* (customizing request on the root) → *Interfaces*: the interface exists and is active (`ACH_RET_PNC_IN`). → *Expected files per day type*: a NORMAL row with expected count ≥ 1 exists (the deadline is evaluated only on business days the calendar expects a file; a HOLIDAY row with 0 keeps holidays silent). Missing: create the calendar row on the same request.
2. **DV1 — create the deadline.** *Stage deadlines (clock time)* → *Create*: interface `ACH_RET_PNC_IN`, stage `FULLY_PROCESSED` (allowed: FILE_RECEIVED, FILE_LOADED, FULLY_PROCESSED, GENERATED_IN_SAP, ACK_RECEIVED), day type `*` (or NORMAL / MONTH_END / RETURNS_DAY for a day-specific time), due time `16:00` (US Central: `FMON_TIME_ZONE` = CST, `FMON_FILE_MONITORING.md` §A3b), severity `E`, active `X`, description. Save on the customizing request.
3. **DV1 — route the alert.** App *Alerting and monitor freshness* → *Alert rules* (same or a second customizing request): an existing rule with check pattern `STAGE_DEADLINE_MISSED` and a group1 pattern that matches the interface already routes it (e.g. extend `FMON_BAIDL`'s group1 pattern), or a new rule: payment engine area FMON, minimum severity E, check pattern `STAGE_DEADLINE_MISSED`, group1 pattern `ACH_RET_PNC_IN`, channel EMAIL, destination an **SO23 shared list** (e.g. `ZCD_RETOPS`), escalate after 6 runs to `ZCD_RTBLEAD`, active. E-mail only — never an APPLOG rule (SLG1 kept to a minimum). The SO23 list itself is client-specific: create it in QA1 and PS4 by hand (§5f).
4. **QA1 — test.** Release the request, import into QA1. `ZCD_FMON_MONITOR` in test mode for a business day after the due time: the board shows the interface row with STAGE_DEADLINE_MISSED when the stage was not reached (nothing when it was); test mode sends no mail. Record the result in the change ticket.
5. **PS4 — transport.** Import the request into PS4 with the normal change approval. After the import run `ZCD_MORNING_REPORT` with **Take config baseline** (`config/hck_seed.md` §6), so that the morning report does not show the transported rows as drift.

**What support may do in PS4 (existing rows only).** Edit due time, severity, *Active* (switch a row off — never delete) and the SO23 list (DESTINATION / ESCALATION_DEST) of an existing row in the configuration apps. Who: ZCD_OPS ACTVT 02 for FMON (deadline, SLA, calendar) and CORE (alert rule) — the production key-user role. Every change is table-logged (SCU3) and carries *Last changed by / at*; the next morning report lists the table as `CONFIG_DRIFT` until the same change is made in DV1 on a customizing request and transported (then take the baseline again), so DV1, QA1 and PS4 stay identical.

## 6. Who to call

| Topic | Team |
|---|---|
| Bank codes, statements, balances | Treasury / bank relationship |
| PRISM hand-off, acks | Middleware (PRISM) support |
| Returns, NOC, clarifications | Disbursement and collections operations |
| Jobs, Control-M | SAP IT & Control-M team |
| Suite configuration and code | Payment engine RTB |

## Changing a stale threshold or a parameter safely (2026-11-07)

**Stale threshold of a monitor** (dashboards *and* morning report self-check):
1. Configuration app *Alerting and monitor freshness* → *Monitor freshness* → row of the area (FMON, EBS, HCK) → `STALE_AFTER_MIN` in minutes (> 0; the app refuses 0 and unknown areas). Delivered: FMON 15, EBS 1560, HCK 1560 (`config/alert_seed.md`).
2. Save in DV1, transport (the app records the change in a customizing request where the client allows it). Do not maintain stale thresholds as parameters: `HCK_MAX_AGE_H_<area>` / `HCK_MAX_AGE_HOURS` are only the fallback of the self-check when the area has no `ZCD_OPS_MONCFG` row.
3. Check: the overview page (*Monitor freshness*) shows the new threshold in `StaleAfterMinutes`; the next morning report's self-check uses the same value (`PE_AREA_STALE`).
4. Delete the row to return to the delivered value (dashboards: CDS fallback literal; self-check: hours parameters).

**Runtime parameter (framework `ZCA_PARAM`, app *Parameter areas* `ZUI_CA_PARAM_O4`)**:
1. Find the parameter: area by prefix (`ALERT_` `SLA_` `RETENTION_` `PURGE_` `TRACE_` → `CD_OPS`, `EBS_` → `CD_EBS`, `FMON_` → `CD_FMON`, `HCK_` → `CD_HCK`), definition (value type, min / max, allowed pattern, delivered default) in the app or `config/param_definitions.csv`.
2. Who may change what: in QA1 / PS4 only the **value row** of a parameter that is not developer-owned can be changed (areas are production-editable) — no new rows, no definitions; field / class names, the trace sources, debit / credit indicators and the ledger are developer-owned and change by transport from DV1. A parameter without a value row runs on its definition default; to make it adjustable in production, deliver a value row by transport.
3. Enter the value as the definition expects it: INT digits only (within min / max), LIST comma-separated, BOOL `X` = on and **blank = off** (a value row with blank value switches a flag off; deleting the row brings the default back). The app refuses a value the definition does not allow (same rules as the runtime).
4. Effect: parameters are read once per run (snapshot at `start_run`) — the change applies from the next run; dialog apps read them at once.
5. Afterwards: if a value nevertheless cannot be read (e.g. the definition changed by a later transport), the run falls back to the code default (no SLG1 entry) and the next morning report shows `PARAM_INVALID` (§5f). Audit: table logging of `ZCA_PARAM_VAL` (SCU3) shows who changed what.

## 5f. PARAM_INVALID — a parameter the framework refuses (morning report, check D_PARAM_INVALID)

| Message (ZCA_PARAM) | Meaning | Fix |
|---|---|---|
| 001 / 002 area does not exist / not active | Areas of the suite not imported or deactivated | Register / activate the area (`config/param_areas.csv`) by transport — every parameter of the area runs on code defaults until then |
| 003 not defined in area | The code reads a name the area does not define (definition missing in this client, e.g. a transport not imported) | Import the definition (row of `config/param_definitions.csv`) by transport |
| 004 mandatory value missing | A mandatory parameter has a blank value row | Enter the value or delete the row (the default applies) |
| 005 single value has several rows | Two value rows for one parameter | Delete the extra row |
| 006-013 invalid value / default | Not a number, outside min / max, pattern mismatch, class / DDIC name unknown or without the interface | Correct the value (app) or the definition (transport) |

Until fixed, each run uses the code default for that parameter; nothing stops and nothing is written to SLG1 (one report a day, in the morning report). The finding closes automatically when the next morning report reads the parameter without error.


