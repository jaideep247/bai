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
| Alert storm | Deactivate the rule in the Alerting & approved tables app or raise THROTTLE_MIN | Immediate, logged |
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

   The **OUTCOME** row (last row of a current attempt, 2026-11-07) is the payment's canonical outcome - the same as the morning report and the transactions dashboard (`§5n`). It never sets the first gap: a COMPLETE evidence chain can still have outcome INCONSISTENT, and AMBIGUOUS there means the FIN is in two sources (do not pick one).
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
| **PRISM_FAILED** (R) | PRISM gave up processing or delivering the file | SE16 `ZCD_FMON_PRISM` by file reference: `ERROR_CODE`, `ERROR_TEXT`, `PRISM_REF`, `COUNTERPARTY`; look the transfer up in the PRISM console. PRISM retries on its own — a later `DELIVERED` supersedes the failure and the next 5-minute run resolves the exception. If PRISM does not deliver, SAP **regenerates** the payment run's file under a new name (never re-send the same name: PRISM rejects a name it already has — confirmed by the user 2026-11-07); the regenerated file closes this exception (§4e) | Integration (PRISM) |
| **NO_PRISM_RECEIVED** / **PRISM_RECEIVED_LATE** — missing PRISM receipt | SAP handed the file over (SENT_TO_PRISM), PRISM did not confirm receipt within the SLA | 1) Is the API reachable? SE16 `ZCD_FMON_PRISM` — newest `RECEIVED_AT` of today; no rows at all for an hour = PRISM is not calling (ICF node inactive, credentials, network) → SICF / SMICM log, ask PRISM for their 4xx/5xx log. 2) Rows exist but not for this file → PRISM transfer job / OS command (`ZICD_CALL_SM69_COMMAND_NEW`), PRISM inbound queue | Integration (PRISM) / Basis |
| **PRISM_QUEUE_LONG** (A) — many bank files queued in PRISM | PRISM releases ACH and wire files one at a time, 2 minutes apart (user 2026-11-06). When PRISM received this file, more ACH / wire files were waiting ahead of it than `FMON_PRISM_QUEUE_MAX` (default 30) covers; the delivery SLA stops growing at that cap, so a later `PRISM_DELIVERED_LATE` / `NO_PRISM_DELIVERED` on the same files is the consequence, not a second problem | **Check PRISM, not SAP:** 1) SE16 `ZCD_FMON_PRISM` for the business date — are `DELIVERED` rows still arriving about every 2 minutes (queue moving, just long) or has the last `DELIVERED` stopped (queue jammed)? 2) PRISM console / PRISM operations: bank connection, throttle setting, a file stuck at the head of the queue. 3) Only if `RECEIVED` rows stop too: SAP hand-over (row above). Nothing to re-run in SAP; never re-send from SAP while PRISM still holds the files (duplicates). The queue is counted per bank (`FMON_PRISM_THROTTLE_SCOPE` = `C`, confirmed): a long queue at one bank never delays another bank's files; a scope question goes to the suite admin | Integration (PRISM) |
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

## 4e. Regenerated files — FILE_REPLACED, REGENERATION_MISSING, FILE_REGENERATED_NOT_FAILED, PRISM_DUPLICATE_NAME (L1 / L2)

Facts confirmed by the user 2026-11-07: PRISM rejects a file whose name it has already received; when PRISM cannot deliver a file (to the bank, or a cheque print file to IRIS when the PRISM → IRIS call fails) SAP generates **another file with a new name for the same payments** and PRISM delivers that one. FMON links the two by their payment run (generation group, `FMON_FILE_MONITORING.md` §A2 rule 9) — only where the source row has `GROUP_FIELDS`. Never change a payment file, job or routing from here; regeneration and stopping a transmission are done by the owning team under its own runbook.

| Finding | What it means | Next diagnostic check (no change to anything) | Owner |
|---|---|---|---|
| **FILE_REPLACED** (information, no exception) | The failed file was replaced by a regenerated file of the same payment run; the message names the new file. The failed file's PRISM_FAILED exception is resolved by the next 5-minute run ("Passed on re-run") | Nothing to do — follow the new file on the board; its SLA starts with its own generation | — |
| **REGENERATION_MISSING** (E) | PRISM could not deliver the file and no regenerated file of the same payment run exists `FMON_REGEN_WAIT_MIN` minutes (default 60) after the failure | 1) PRISM console: is PRISM still retrying (a later DELIVERED closes everything)? 2) If not: the payment run (date / ID in the message's generation key) needs its file regenerated in SAP by payment operations — **regenerate, do not re-send the old name** 3) After the regeneration the next run closes this exception | Payment operations / Integration (PRISM) |
| **FILE_REGENERATED_NOT_FAILED** (B, critical) | A second file of the same payment run exists although the first one did **not** fail — both delivered, or the first still in flight: **possible duplicate payment file to the bank / IRIS** | **Act at once:** 1) PRISM console: which of the two files did PRISM deliver to the bank / IRIS? 2) If the second is not yet at the bank / IRIS: PRISM operations stop it 3) If both reached the bank / IRIS: call the bank / IRIS operations, check for double payments / double printed cheques (payment trace, §4a) 4) Ask payment operations why the run was regenerated (a manual regeneration while PRISM was still retrying?) | Payment operations + Integration (PRISM), escalate to RTB lead |
| **PRISM_DUPLICATE_NAME** (E) | PRISM rejected the file because it already has that name (error code of `FMON_PRISM_DUP_NAME_CODES`) — SAP re-sent instead of regenerating | Do **not** re-send again. SE16 `ZCD_FMON_PRISM` by file reference (`ERROR_CODE`, `ERROR_TEXT`); payment operations regenerate the payment run's file (new name); the regenerated file turns the finding into FILE_REPLACED | Payment operations |

Codes of a duplicate-name rejection are maintained in ZCA_PARAM `FMON_PRISM_DUP_NAME_CODES` (app *Parameter areas*, area `CD_FMON`; delivered empty until PRISM confirms its codes — then such a rejection shows as PRISM_FAILED). A false FILE_REGENERATED_NOT_FAILED between two different files of one payment run means the generation group is too coarse (e.g. two house banks): the suite admin adds the distinguishing field to `GROUP_FIELDS` (DV1, transport).

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

`ZCD_OPS_PURGE` (monthly, native SAP job, test mode off) deletes the suite's own history older than the retention parameters (`RETENTION_DAYS_*`, never below 30 days): runs with their findings and the action history of those findings (`ZCD_OPS_EXC_HIST`, 2026-11-10 - it was left behind before), alert log, FMON events, HCK metrics, PRISM status events, HCK verdicts, payment outcome history and the FMON file registry (`ZCD_FMON_FILE` by business date, `RETENTION_DAYS_FMON_FILE` 400 days; a file an open, assigned or validly waived exception refers to is kept). Runs that still hold an open, assigned or validly waived exception are kept. Run it in test mode first after any parameter change; the job log shows one line per target (message 060). With these targets no other housekeeping job is needed for the suite's tables; expired application logs of object `ZCD_OPS` are deleted with the standard SLG2 job.

## 5a-1. Aborted runs, job link and failed alerts (2026-11-10)

- **A run that stops after it started** (an error of the suite or of the database) is no longer left in status R and the job no longer ends green: the engine (EBS, FMON, HCK) rolls back what was not saved, closes the run with status **A** (aborted, red) and one finding **RUN_ABORTED** (message 804) whose DETAILS hold the exception chain (class, message, source position of every link) and whose ERROR_CLASS says TRANSIENT (lock, timeout, database - re-run), CONFIG, CODE or DATA (route to the owner). The run is saved before the alert router runs, so alert rules with *on abort* fire. In background the job then ends with an error message (Control-M red); in dialog the message is shown.
- **Job link.** `ZCD_OPS_RUN` carries JOBNAME / JOBCOUNT / SYSID of the batch job (`ZCL_CD_OPS_UTIL=>JOB_LINK`; filled by the store at the start of the run). The alert e-mail starts its subject with the system ID and names run ID, job name and count and the exceptions app (message 803): SM37 → job name + count finds the job log directly.
- **ALERT_FAILED** is recorded for every area when the alert router itself fails (also EBS and the refused run, which were silent before); the morning report check `E_ALERT_DELIVERY` also reports alert-log rows still **claimed** (status C) `HCK_ALERT_CLAIM_MIN` minutes (30) after the claim (`ALERT_CLAIM_STUCK`): the dispatcher stopped between claim and send - check SOST / SLG1 and re-run the job if the alert was not delivered.
- **Exception chains.** Every catch boundary (rule, source, lot reader, check, plug-in, alert delivery) keeps the exception trace in ZCD_OPS_FINDING-DETAILS (alert log: ERROR, cut at 255 characters) - read it in the exceptions app instead of reproducing the error.

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
3. **DV1 — route the alert.** App *Alerting and approved tables* → *Alert rules* (same or a second customizing request): an existing rule with check pattern `STAGE_DEADLINE_MISSED` and a group1 pattern that matches the interface already routes it (e.g. extend `FMON_BAIDL`'s group1 pattern), or a new rule: payment engine area FMON, minimum severity E, check pattern `STAGE_DEADLINE_MISSED`, group1 pattern `ACH_RET_PNC_IN`, channel EMAIL, destination an **SO23 shared list** (e.g. `ZCD_RETOPS`), escalate after 6 runs to `ZCD_RTBLEAD`, active. E-mail only — never an APPLOG rule (SLG1 kept to a minimum). The SO23 list itself is client-specific: create it in QA1 and PS4 by hand (§5f).
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
1. Framework app *Parameter areas* (`ZUI_CA_PARAM_O4`), area `CD_OPS` → parameter `MON_STALE_AFTER_MIN_<area>` (FMON, EBS, HCK; table consolidation 2026-11-08, was the `ZCD_OPS_MONCFG` row) → value row in minutes (INT, at least 1; the framework refuses 0 and non-numbers). Delivered definition defaults: FMON 15, EBS 1560, HCK 1560 (`config/alert_seed.md`).
2. A value of a released parameter may be adjusted where the framework allows it (production-editable area `CD_OPS`, change-logged); otherwise maintain it in DV1 on a customizing request and transport. `HCK_MAX_AGE_H_<area>` / `HCK_MAX_AGE_HOURS` are only the fallback of the self-check when `MON_STALE_AFTER_MIN_<area>` cannot be read (`D_PARAM_INVALID`).
3. Check: the overview page (*Monitor freshness*) shows the new threshold in `StaleAfterMinutes`; the next morning report's self-check uses the same value (`PE_AREA_STALE`).
4. Delete the value row to return to the delivered definition default (dashboards and self-check alike).

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



## 5o. POSTAREA_INVALID — an entry of a customer posting area the suite cannot use (morning report, check D_POSTAREA_INVALID, 2026-11-08)

The bank transaction codes (ZBTM), return / NOC reasons (ZRSN), payment method classes (ZPMC) and bank code roles (ZBTR) are FI-CA customer posting areas maintained by the FI-CA team in FQC0 (`FICA_Posting_Areas.md`). FQC0 checks only the domains of the values; every other rule of the suite is checked here, the morning after the transport.

| Message (ZCD_OPS) | Meaning | Fix (FI-CA team, FQC0 in DV1, customizing request) |
|---|---|---|
| 427 `*` not supported | `*` in a key whose reader needs exact values (scheme / code of ZBTM, flow / payment method of ZPMC, any ZBTR key) - the entry is not used | Enter the values one by one |
| 428 longer than | A value longer than the field the suite reads it into - the entry would be truncated, so it is reported | Shorten the value (VERIFY item: posting area field lengths) |
| 429 blank | A key that must be a value or `*` (ZBTM bank key / flow, ZPMC house bank) | Enter the value or `*` |
| 432 no entries (W) | The posting area is empty in this client - nothing is mapped (EBS: every line R14; `A_INFLIGHT`: no class watched) | Import the entries' transport; check `POSTAREA_*` names the right posting area |
| 385 / 431 / 433 | ZPMC: a payment method in two classes; a house-bank entry without the `*` entry of its payment method; classes whose entries disagree on ageing basis / calendar | Align the entries of the payment method / class |
| 413 / 416 / 422-425 / 430 | Value not allowed, rule group without active rule (ZCD_BTC_RULE, EBS configuration app), field required / to leave blank for the scheme or usage, role of the other usage, LIFECYCLE scope form, method class of the scope not in ZPMC | Correct the entry (or add the rule group / class first) |

Until fixed, the readers skip what they cannot use (`*` in an exact key, an entry without class) or use the entry as it is; the finding closes when the next morning report finds the entry valid. Production cannot change FQC0 entries (client not changeable): every fix is a transport from DV1.

## 5i. E_NUMRANGE — number range nearly exhausted (morning report, check E_NUMRANGE)

**What it means.** An internal interval of a configured number range object (PARAM1, SNRO names) has used at least the amber share (seed 85 %) of its numbers; red (seed 95 %) is an e-mail through `HCK_RED`. At 100 % every posting that draws a number from the object stops with a number range error — payment runs, returns, document postings of the payment engine.

| Finding | Where to look | Who acts | What to do |
|---|---|---|---|
| `NR_USAGE_HIGH` W / E (object, interval, usage %, numbers left) | SNRO → object → *Intervals* (status = current level); the metric trend `NR_USED_PCT` on the health check dashboard shows how fast it fills | Payment engine support with the functional owner of the object; Basis for the transport | Plan an extension: a new interval (or the next year's interval for a year-dependent object) in DV1 and transport it DV1 → QA1 → PS4 before red. Never change NRLEVEL or an interval directly in production, never from the suite (it is read-only). |
| `NR_NO_INTERVAL` W | SNRO for the object and year | Payment engine support | Wrong object name in PARAM1 → correct the ZCD_HCK_DEF row by transport. Year-dependent object without an interval for this / next year → create it before 1 January (transport). Only external intervals → remove the object from PARAM1 (external numbers are not counted). |
| `NR_NOT_NUMERIC` W | SNRO interval limits | Payment engine support | Limits or level are not plain digits; the interval is not measured. Confirm the interval is internal; otherwise drop it from the list. |
| `LIMITS_NOT_CONFIGURED` / `TECH_READ_CAPPED` W | ZCD_HCK_THRESH `E_NUMRANGE / NR_USED_PCT / *`; parameter `HCK_MAX_TECH_ROWS` | Payment engine support | Add the threshold row by transport; raise the cap only after a QA1 runtime check. |

## 5j. E_QUEUES — qRFC / bgRFC queues in error or stuck (morning report, check E_QUEUES)

**What it means.** Entries of an outbound (QOUT, SMQ1) or inbound (QIN, SMQ2) qRFC queue, or of the configured bgRFC table (BGRF, SBGRFCMON), are in an error state (`HCK_QUEUE_ERR_STATES`, seed SYSFAIL, CPICERR → E), held (`HCK_QUEUE_HOLD_STATES`, seed STOP, WAITSTOP → W) or waiting longer than PARAM3 minutes (`HCK_QUEUE_WAIT_STATES`, seed READY, RUNNING → STUCK, W). The finding names source, queue, destination, state, entries, the oldest age and the transaction. Data behind a stuck queue has not reached its receiver (e.g. a status update to PRISM).

| Finding | Where to look | Who acts | What to do |
|---|---|---|---|
| `QUEUE_ERROR` E | The transaction in the finding (SMQ1 / SMQ2 / SBGRFCMON), queue name → error text of the first entry; SM59 for the destination | Basis / middleware support; the owning application team for a data error | Find the cause first (receiver down, authorisation, data error). Restart, unlock or delete only by the team that owns the queue, after the cause is fixed and documented — never from the suite. |
| `QUEUE_HOLD` W | SMQ1 / SMQ2: who stopped the queue and when | Basis | A stop during a release or an outage is expected; otherwise ask the owner before the queue is unlocked. |
| `QUEUE_STUCK` W | SMQ1 / SMQ2 / SBGRFCMON; QIN scheduler (SMQR) / QOUT scheduler (SMQS) | Basis | Scheduler not registered or no free work processes; the receiver is slow. Check the scheduler status; re-check on the next run. |
| `QUEUE_CONFIG_INVALID` W / `QUEUE_NOT_MONITORED` I | Message text (field / table name) | Developer | A delivered qRFC name does not exist on this release (VERIFY-DDIC, constants of `ZIF_CD_HCK_RUNTIME_TYPES`) → code change by transport; the bgRFC table has no ZCD_OPS_TABWL row HCK / READ or PARAM4 is blank → configure by transport. Until then the source measures nothing (never zero). |

## 5k. A_INFLIGHT — payments sent but not cleared on the bank statement (morning report, check A_INFLIGHT)

**Since 2026-11-08 (scale, `HCK_MORNING_REPORT.md` §7b-7).** The check counts **every payment not yet final, however old**, from the payment worklist the outcome snapshot keeps (`ZCD_PAY_OUTCOME`: open payments and exceptions only, §5n) - no look-back window and no row cap for payments in flight; the documents the snapshot has not reached are judged live (metric `PAY_NOT_SNAPSHOT`). Every finding is **one per flow + method class + code + payment run date** with the count, the amount per currency and the first `PAYOUT_EXAMPLES` (10) payments oldest first. **Full list:** transactions dashboard (date kind RUN = the day of the finding, finding = the code, flow + method class), or `ZCD_PAY_OUTCOME` in SE16H with VALID_TO = 99991231235959, LAUFD = the day, FINDING / OUTCOME; each payment document in the payment trace. Limits (user 2026-11-08, `config/hck_seed.md` §3): wire 1 / 2 business days (next business day), ACH both flows and card 3 / 4, international ACH 7 / 8, cheques no limit (counted, never late). If `PAY_SNAPSHOT_STALE` is on the same report, the counts may miss the newest evidence: get the snapshot back first (§5n).


**What it means.** Payments of payment runs (DPAYH) whose bank statement evidence is missing past the limit, per flow (**D** disbursement / **C** collection, TFK042Z-XEINZ) and method class (posting area `ZPMC` in FQC0: wire WIR, ACH, cheque CHQ, card CRD …). VALUE_DATE classes are aged in business days (calendar of the house bank, of the class, else PARAM1) after the value date: seed (user 2026-11-08) wire late 1 / critical 2, ACH (both flows) and card 3 / 4, international ACH 7 / 8 business days. Cheques (ISSUE_DATE) are aged in calendar days since the run date and have no limit (no stale-cheque policy): counted and shown in `PAY_OPEN` / `AGE_OLDEST`, never late. Cleared, returned, voided, pending (redeposit) and reversed payments are not listed - what counts as evidence is the rule table (`HCK_MORNING_REPORT.md` §7b). The finding (one per flow + class + run date) gives the count, the amount per currency and the oldest late payments (payment document, method, run date, aged-from date, age, amount).

| Finding | Where to look | Who acts | What to do |
|---|---|---|---|
| `PAYMENT_NOT_CLEARED` W / E, flow D wire / ACH | Payment trace (`ZCD_OPS_PAYMENT_TRACE`, §4a) with the payment document: file sent? ACK? bank line? FEBAN for the statement of the value date; EBS validation findings R07 / R14 for the account | Disbursement ops; Treasury when the bank has no record | Statement not loaded → FMON / EBS triage; line present but not matched (CHECT not the payment document, unmapped BAI code) → clarify in FEBAN; payment rejected by the bank → returns processing. The suite never clears or posts. |
| `PAYMENT_NOT_CLEARED`, flow C | Payment trace; G/L line with XREF2 = payment document (FB03 / FBL3N; ZUONR = AUGBL for ACH, Stripe descriptor for card); Stripe payout log; returns lot | Collections team | Collection not credited by the bank or F.13 not cleared yet → clarify with Treasury / rerun of F.13 by its owner; Stripe payout processed but F.13 not cleared → group of the descriptor against the 195 deposit (JPMC account ending 16650); returned debit not processed → returns lot (FP09). |
| `PAYMENT_NOT_CLEARED`, DCHQ | Cheque register (DFKKCR) for the payment document: cheque number, encashment date; cheque history (ZCD_CHECK_HIST) | Disbursement ops | Cheques have no limit (no stale-cheque policy, user 2026-11-08): a DCHQ `PAYMENT_NOT_CLEARED` appears only if a limit row is added to `ZCD_HCK_THRESH` by transport; then contact the payee / source per that policy (stop / reissue never from the suite). Cashed at the bank but DFKKCR-STATE still blank and no bank line → check the cheque-paid statement (BAI 475) and EBS rule R07C. |
| `VALUE_DATE_MISSING` I | Detail line "(no value date: run date used)" | Payment engine support | DPAYH carries no value date for these payments; ages are from the run date (earlier, so stricter). Confirm with the functional team whether the field is filled for that method. |
| `INFLIGHT_CONFIG` W / I, `LIMITS_NOT_CONFIGURED` W | Message: calendar, class without payment methods or without CLEARED rule, evidence kind not configured (Stripe settings); threshold key | Payment engine support | Maintain in the HCK configuration app by transport: calendar (class / house bank / PARAM1 - without any every day counts), payment methods of the class (posting area `ZPMC`, FI-CA team in FQC0), rules (`ZCD_HCK_CLRRULE`), Stripe settings after the SE11 check (ZCA_PARAM `HCK_STRIPE_*`, app *Parameter areas*), the `AGE_OLDEST` row of the flow + class in ZCD_HCK_THRESH. A method in two classes of one flow stops the check (PLUGIN_ERROR, message 385). |
| `CLEARING_RULE_INVALID` E | Evidence class and PARAM1 in the message, exception text | Payment engine support | The row cannot be used (class does not implement `ZIF_CD_HCK_EVIDENCE`, required parameter blank, invalid sequence pattern, unknown field): its purposes are not judged and the payments stay in flight (aged). Correct the row in DV1 and transport. |
| `TECH_READ_CAPPED` W | Parameter `HCK_INFLIGHT_MAX_ROWS` | Payment engine support | Since 2026-11-08 the counts of payments in flight are never capped (snapshot aggregate). The cap applies to the documents evaluated live (snapshot behind: first get the snapshot back, `PAY_SNAPSHOT_STALE`), to the bank ACK candidates of `PAY_STATUS_LAG` and to evidence reads. Raise it only after a QA1 runtime check. |
| `PAY_SNAPSHOT_STALE` W (evidence PARTIAL) | Message 761 (minutes behind, limit, source, processed up to) or 762 (never ran); freshness card row CORE; SM37 step 2 of `ZCD_FMON_MONITOR_ALL`; findings `PAY_OUTCOME_FAILED` / `PAY_OUTCOME_SERIAL` of the snapshot runs | Payment engine support / batch owner | The counts miss the newest evidence: never treat the check as green. Snapshot job not running → restart it; behind after a peak day → raise `PAYOUT_MAX_PACKAGES` / `PAYOUT_PARALLEL` (QA1-tested values, §5n); a failing package → its message. The finding resolves itself on the first report after the lag is below the limit |
| `PAY_EVALUATED_LIVE` I | Message 374 | — | Payments whose versions all say AMBIGUOUS (FIN in two sources) were judged live; the not-yet-snapshotted count is the metric `PAY_NOT_SNAPSHOT` per flow + class |

## 5k-1. A_INFLIGHT — PAY_STATUS_LAG: the DPAYH status did not follow the bank (2026-11-08)

**What it means.** One warning per payment in flight: the bank already decided (a 195 / 168 / 166 lifecycle with its returns lot, the bank ACK of a payment acknowledged per payment, or the ACK of the file of the payment run for classes acknowledged per file - collections), but DPAYH-ZZ_PAYMENT_STATUS is still `ISSUED` / `CONFIRMED` more than `HCK_PAY_STATUS_LAG_MIN` (120) minutes later. The hourly payment status job did not update it. The payment stays in flight (aged); nothing is posted or changed by the suite. No alert e-mail is sent by default.

| Message | Where to look | Who acts | What to do |
|---|---|---|---|
| 683 "DPAYH status still CONFIRMED, bank evidence RETURNED / RETRIEVED since <day>" + the deciding evidence | Payment trace of the document (stages BANK_LINE, RETURN, OUTCOME), DPAYH-ZZ_PAYMENT_STATUS, SM37 of the hourly payment status job (last runs, cancellations), `ZCD_SPE_EXCP_LOG` | Payment engine support (status job owner) | Job cancelled / not scheduled → restart it per its runbook; job ran but skipped the payment → status-job defect (ticket with the payment document); many payments of one day at once → the job ran before the statement import (timing; resolves with its next run). Never set the status from the suite |
| 684 "DPAYH status still ISSUED, bank ACK received <date time>" + ACK row | Payment trace stage BANK_ACK (same ACK source), FMON file board (ACK_RECEIVED), SM37 of the status job | Payment engine support | As above; an ACK of the wrong payment (reference) → check the ACK source configuration `TRACE_SRC_ACK` |
| 688 "DPAYH status still ISSUED, file ACK received <date time>" + "file of payment run <run date/run ID/house bank>, interface <id>: <file name>" (689) - classes acknowledged per file (`HCK_PAY_ACK_FILE_CLASSES`, collections ACH / card) | FMON file board / `ZC_CD_FMONFILE` for the file named (stage ACK_RECEIVED, generation: a regenerated file replaces a failed one), payment trace (stages FILE, BANK_ACK), DPAYH-ZZ_PAYMENT_STATUS, SM37 of the hourly payment status job | Payment engine support (status job owner) | The bank acknowledged the file of the payment run but the job did not move the payments to CONFIRMED: job cancelled / not scheduled → restart it; job ran but skipped the run's collections → status-job defect (ticket with payment run and file name); the file belongs to another run (wrong link) → check `GROUP_FIELDS` of the source and that the run fields match DPAYH (VERIFY-SE11). A file **without** ACK is not this finding - see the FMON findings `NO_BANK_ACK` / `REGENERATION_MISSING` of that file |
| `INFLIGHT_CONFIG` W "File ACK lag not evaluated: FMON source REGUT has no GROUP_FIELDS" (301) / "… group field X of source REGUT not in DPAYH run" (312) / "… no outbound interface with ACK level FILE" (346) | `ZCD_FMON_SRC` row of `HCK_PAY_ACK_FILE_SRC` (FMON configuration app), `ZCD_FMON_IFACE` ACK_EXPECTED / ACK_LEVEL, `config/fmon_seed.md` | Payment engine support | Expected until the ZCDT_REGUT payment run fields are confirmed in SE11; then maintain GROUP_FIELDS (LAUFD,LAUFI,HBKID) by transport. Until then the status lag of collections is not evaluated (one warning per run) |
| `INFLIGHT_CONFIG` I "Status lag after the bank ACK not evaluated: TRACE_SRC_ACK not configured" | ZCA_PARAM `TRACE_SRC_ACK` (needs TABLE, KEY and DATE) | Payment engine support | Expected until the ACK table fields are confirmed in SE11; then maintain the parameter (developer-owned, transport) |
| `INFLIGHT_CONFIG` W "… not evaluated (table): <error>" | Table / fields of `TRACE_SRC_ACK`, `ZCD_OPS_TABWL` (FMON / SOURCE), authorisation S_TABU_NAM | Payment engine support | Correct the configuration by transport |

The grace of the bank-evidence case starts at the end of the statement line's posting day (FEBEP has no time): a statement imported shortly before the report can show a lag that the next status job resolves - check the job's last run before escalating.

## 5l. A_INFLIGHT — inconsistent clearing / return evidence (CLEARING_INCONSISTENT, RETURN_INCONSISTENT, UNEXPECTED_SEQUENCE, PENDING_OUTCOME_MISSING)

**What it means.** Two pieces of evidence about one payment disagree, or the bank code sequence of the payment is not a known lifecycle. The payment is listed (oldest first, per flow + class) and not aged. Each detail line names the purpose (CLEARED, RETURNED, VOIDED, PENDING, IN_FLIGHT) and what held, what is missing and what must not hold, or the anomaly with its evidence (codes with dates, returns lot items, amounts). The suite never posts, clears, voids or changes a status.

| Detail | Where to look | Who acts | What to do |
|---|---|---|---|
| Wire / ACH disbursement: statement line (lifecycle CLEARED) held, DPAYH status not CLEARED | FEBAN (statement line with CHECT = payment document), DPAYH-ZZ_PAYMENT_STATUS (payment trace) | Disbursement ops / payment engine support | Status update from the bank / PRISM not processed → check the status interface (PRISM status API, `ZCD_SPE_EXCP_LOG`); never set the status from the suite |
| DPAYH status CLEARED, no statement line | FEBAN for the value date; FMON / EBS for the statement | Treasury / disbursement ops | Statement not loaded or reference not in CHECT → FMON / EBS triage |
| Cheque: state B without statement line; line while state blank or V | DFKKCR (state, ZTNUM), FEBAN (CHECT = last 13 characters of ZTNUM), cheque history | Disbursement ops | Register not updated (cashed but blank) or cheque cashed after void → stop / fraud process per policy; register cashed without bank evidence → Treasury |
| Collection: G/L line cleared without payout log row; payout processed but descriptor not set; assignment changed | BSEG by XREF2 (FB03), Stripe payout log, F.13 log | Collections team | Payout file processing incomplete or F.13 cleared by another assignment → check the payout file run (FMON STRIPE_PAYOUT_IN) and the F.13 variant |
| `RETURN_INCONSISTENT`: return line (168 / 195 / second 468) without returns lot, lot without return line, extra lot, amount differs | FEBEP lines of the payment reference, DFKKRP (FP09) by SELW1 = payment document, EBS findings R07R | Returns processing / collections | Returns lot missing → create it in FP09 (by the returns team); lot without line → check the statement; amount differs → partial return, clarify with Treasury |
| `UNEXPECTED_SEQUENCE`: codes and dates | FEBEP lines of the payment reference (FEBAN), bank advice | Treasury | Confirm the sequence with the bank; if legitimate, add an outcome row (`ZCD_HCK_SEQOUT`) in DV1 by transport (`HCK_MORNING_REPORT.md` §7b-2) |
| `CHEQUE_CLARIFICATION`: several 581 and / or 255 for one cheque (codes and dates, cheque number) | FEBAN (lines with CHECT = last 13 characters of the cheque number), clarification worklist of the statement postings, DFKKCR | Disbursement ops | Duplicate presentment or bank error: clarify the lines in the clarification worklist with Treasury / the bank; the register is not changed by the suite |
| `MANUAL_CLEARING_REQUIRED`: correction code (399 / 699) and register state not B | FEBAN (original 581 and the correction line), DFKKCR (cheque number, amount, state), bank advice | Payment engine support (cheque register) | The bank corrected cheque number or amount: verify the corrected values with the bank, then clear the cheque manually in FPCHR (cheque register: select the cheque by number, record encashment with the corrected values, save); the next morning report shows CLEARED_MANUAL (no finding) |
| `CHEQUE_AMOUNT_MISMATCH`: statement amount vs payment amount (DPAYH of the payment) | FEBAN 581 line, DFKKCR / DPAYH of the payment document, EBS finding R08 of the line | Payment engine support / Treasury | Bank paid a different amount: confirm with the bank (correction expected), clear manually in FPCHR once confirmed |
| `RETURN_INCONSISTENT` (cheque): 255 but the register still shows cashed, or a returns lot for a cheque | DFKKCR state, FEBEP 255 line, DFKKRP (FP09) | Disbursement ops | Register not updated after the return → update in FPCHR; a cheque has no returns lot - check why one was created |
| `PENDING_OUTCOME_MISSING`: redeposit pending longer than its maximum age (10 days) | FEBEP lines (one 468, no 166 / 143, no second 468), DFKKRP | Collections team | The bank did not report the redeposit outcome → ask the bank; second failure without returns lot → FP09 |
| `CLEARING_UNDETERMINED` (W): "not determinable (mandatory evidence unavailable)" with the purpose and the rows that are not configured / not usable; the payment stays in flight and is aged | `INFLIGHT_CONFIG` W ("not configured - mandatory") or `CLEARING_RULE_INVALID` E of the same run; HCK configuration app *Clearing / return evidence rules* and *Evidence settings* | Payment engine support (configuration owner) | Never clear by hand because of this finding. Maintain the missing settings (e.g. Stripe field names in the parameters `HCK_STRIPE_*` after SE11) or fix the rule in DV1 and transport; only the process owner may decide to make a row informational (REQUIRED blank, e.g. BSEG decides alone for cards) - a transported configuration choice with the trade-off of `config/hck_seed.md` §8c |
| `BTC_ROLE_MISSING` (E): a monetary statement line of the payment has a code without role - scheme, code, posting date, amount, flow / class in the detail; lifecycle INDETERMINATE (never cleared / returned) | FEBAN (lines of the payment reference), posting area `ZBTR` (FQC0), bank code sheet of the bank | Treasury + payment engine support | Confirm with Treasury what the code means for this flow / class; add the `ZBTR` entry in FQC0 (and the outcome rows it needs) in DV1 by transport - or, only when the code never concerns a payment, add it to `HCK_BTC_INFO_<scheme>` (ZCA_PARAM, transported) |
| `CHEQUE_LINK_AMBIGUOUS` (E): a statement line fits several cheques of the same house bank account (suffix of the cheque number) - none inherits the cashing | FEBAN (the line), DFKKCR (cheques of that house bank / account with the same last 13 characters), FEBKO of the statement | Disbursement ops / Treasury | Decide with the bank which cheque was paid; clear that cheque manually in FPCHR; check the cheque number layout (VERIFY: last 13 characters unique per account) |
| `CHEQUE_REGISTER_MISSING` (E): the matching outcome row needs the cheque register state, the payment has no register row for the rule's link | DFKKCR by DOC1R = payment document; the rule's PARAM2 (`ZTNUM` link) in the HCK configuration app | Payment engine support | Cheque missing in the register → register / payment run issue; a non-cheque rule with REG_STATE outcome rows → configuration error, fix in DV1 |
| `CLEARING_INCONSISTENT` (E) **"stopped cheque cashed"** (purpose VOIDED; held: DPAYH status STOPPED; must not hold: the cashed line 581 / manual clearing and / or register state B) - user decision 2026-11-08: a stopped cheque counts as voided | DPAYH-ZZ_PAYMENT_STATUS (payment trace), FEBAN 581 line (CHECT = last 13 characters of ZTNUM), DFKKCR state, the stop-payment request to the bank (positive pay / stop pay file in FMON) | Disbursement ops with Treasury | The bank paid a cheque that was stopped: confirm with the bank whether the stop reached it in time (stop-pay file delivered and acknowledged?) and claim the amount back under the stop-payment process; a **reissue** is a separate payment (new payment document / AUGBL and new cheque number, user 2026-11-08): it never makes the stopped payment "cashed" - if this finding names the reissue's cheque number under the stopped payment document, the register is wrong (ticket to payment operations). Never change the status or the register from the suite |
| Status RETURNED / RETRIEVED but no 195 / 168 / 166 on the statement (`RETURN_INCONSISTENT` / `CLEARING_INCONSISTENT`, held: the DPAYH status row) | FEBAN for the payment reference, EBS findings R07 of the statement | Disbursement ops / Treasury | Statement not imported or the line carries another reference → FMON / EBS triage; status set without bank evidence → status-job owner |


## 5m. A_RECON_3WAY — three-way reconciliation bank / G/L transit / payment engine (morning report, check A_RECON_3WAY)

**What it means.** Per company code + clearing (transit) account + currency + day the check compares three legs at group level (never line to line): the **bank** lines of the payment engine account of the set (FEBEP, scoped by the XBLNR account of `ZCD_EBS_ACCT` as EBS), the **G/L** postings of the payment engine transfer on the clearing account (ACDOCA, reference procedure FKKSU = `TRACE_GL_AWTYP`) and the payment engine **control total** (DFKKSUMC). A difference is first tested for timing (statement not yet loaded, or offset by the next days within `HCK_RECON_TIMING_DAYS`), then explained by the variance buckets of the bank codes (posting area `ZBTR` usage RECON: cut-off, pending redeposit, cheque, unmapped, other); what is left above the tolerance is a **break**. Stripe sets prove *descriptor group = BAI 195 deposit + fees*; ACH collection sets also list assignment groups F.13 has not cleared one-to-one. The detail of each finding gives the amounts; the metrics `RC_*` (dashboard / `ZI_CD_HckRecon`) give the difference per group and day and the bucket counts. The suite never posts, clears or changes anything.

| Finding | Where to look | Who acts | What to do |
|---|---|---|---|
| `RECON_BREAK` E (group, day, difference, unexplained) | FEBAN for the account and day (statement lines, posting status), FBL3N on the clearing account for the day (postings of the transfer, AWTYP FKKSU, and of the bank statement), reconciliation keys of the day; the payment trace for single payments | Payment engine support with Treasury (bank side) / GL accounting (clearing account) | Statement line not posted or posted to another account → EBS triage (posting rule, R18); transfer missing → `A_GL_TRANSFER` / rerun of the G/L transfer by its owner; manual posting on the clearing account (detail: other postings) → clarify with GL accounting. A recurring explained difference is a missing bank code role → row `RECON_VARIANCE` below |
| `RECON_BREAK` E, key `…/ACH` (n assignment groups of a day unmatched, amount, first assignment) | FBL3N on the ACH collection clearing account, open items by assignment (ZUONR = payment document); F.13 log | Collections team | F.13 did not clear one-to-one: bank credit missing (statement / EBS), assignment changed, partial amount → clarify; F.13 is run by its owner, never from the suite |
| `RECON_SUBLEDGER_BREAK` E (group, day, G/L, control total; detail: payment documents DPAYH) | DFKKSUMC of the day's reconciliation keys, BKPF with AWKEY = FIKEY (FB03), check `A_GL_TRANSFER` of the same report | Payment engine support / GL accounting | Key not transferred → G/L transfer (owner); key transferred to another account or currency → G/L account determination by transport; partial transfer → reconcile the key |
| `STRIPE_GROUP_BREAK` E (descriptor, charges, fees, deposit; amount = difference) | FBL3N on the Stripe clearing account by assignment = descriptor; the BAI 195 line on the JPMC account (FEBAN); Stripe payout report; payout log (`ZCD_STRP_POUT_LOG`) | Collections team with Treasury | Difference = the fees → fee posting of the payout missing; deposit not posted / not on the clearing account (key with the document) → posting rule of the 195 line; charges missing → payout file processing (FMON STRIPE_PAYOUT_IN). F.13 clears only a zero group |
| `RECON_TIMING` I (difference is TIMING / CUTOFF / REDEPOSIT) | — (listed only) | — | Expected: the statement or transfer of a later day, a return processed in the next period, a 468 waiting up to 10 days for its redeposit. It becomes a break when it is still open after the timing / redeposit days |
| `RECON_VARIANCE` W (difference explained by CHEQUE / UNMAPPED / OTHER; or "bank codes without reconciliation role" with the codes) | FEBAN lines of the codes; posting area `ZBTR` usage RECON (FQC0) | Payment engine support with Treasury | Cheque cashed later than issued → normal for the cheque clearing account, follow `A_INFLIGHT` DCHQ; new / unmapped code → confirm its meaning with Treasury and add the role row in DV1 by transport (or IGNORE); OTHER → confirm the code is expected |
| `RECON_NO_DATA` I (no bank, G/L or payment engine evidence in the window) | Statements of the account (FEBAN), postings of the clearing account | Payment engine support | No activity is unusual for a payment engine account over the look-back days: statement not imported (FMON / EBS), wrong set (account, currency), or the account is no longer used (switch the set ACTIVE off). When no set has evidence the check is grey (never green) |
| `RECON_CONFIG` W (set not evaluated: NO_ACCOUNT / DUPLICATE / NO_DEPOSIT) | HCK configuration app *Reconciliation clearing account sets*; EBS configuration app *House bank accounts* | Payment engine support | NO_ACCOUNT → the house bank account has no active `ZCD_EBS_ACCT` row with the XBLNR account; DUPLICATE → two sets for one company code / account / currency; NO_DEPOSIT → a STRIPE set without `DEPOSIT` code row. Fix by transport |
| `TECH_READ_CAPPED` W (key `…/ACH`) | Parameter `HCK_RECON_MAX_ROWS` | Payment engine support | More unmatched ACH groups than the cap: the list is incomplete. Clear the backlog first; raise the cap after a QA1 runtime check |

## 5n. Canonical payment outcome and the payment worklist — one verdict on the dashboard, the trace and the morning report (2026-11-07, worklist 2026-11-08)

**What it is.** One evaluator (`ZIF_CD_OPS_PAY_OUTCOME`, the A_INFLIGHT rules) decides each payment's outcome: CLEARED, RETURNED, RETRIEVED (a retrieval is not a return), VOIDED, PENDING, IN_FLIGHT, UNDETERMINED, INCONSISTENT, AMBIGUOUS (FIN in two sources), REVERSED; the request rule (`ZIF_CD_OPS_PAY_REQUEST`) decides whether a payment request was paid on its due date. The program `ZCD_OPS_PAY_SNAPSHOT` keeps the **payment worklist** `ZCD_PAY_OUTCOME` (user decision 2026-11-08): open payments and requests (one current row, changed in place) and exceptions (a finding: inconsistent, undetermined, ambiguous, status pending, late beyond AMBER / RED, request not paid - their versions are kept). A payment that ends clean (cleared, returned, retrieved, voided, reversed without finding) **leaves the worklist**: its row is deleted, or - after an exception - its history is closed and purged 90 days later. The dashboard shows the worklist; the payment trace finds any payment (FIN + source, payment document, payment reference / cheque number).

**Modes of `ZCD_OPS_PAY_SNAPSHOT`** (each with its own run lock, so they never block each other):

| Mode | Job | What it does | Bound |
|---|---|---|---|
| **FAST** (default) | Step 2 of the 5-minute SM36 job `ZCD_FMON_MONITOR_ALL` (variant `ZCD_PAY_FAST`) | New evidence since each source's watermark: DOCUMENTS, REVERSALS, STATEMENT, RETURNS, GL, **REQUESTS** (new SUCCESS payment requests), RECHECK (one package of status changes) | `PAYOUT_MAX_PACKAGES` per source |
| **NIGHTLY** | Own SM36 job `ZCD_PAY_NIGHTLY` once a night, after the hourly payment status job of about 01:00 and before the morning report (e.g. 02:30), variant `ZCD_PAY_NIGHTLY` (mode NIGHTLY) | Every current worklist row re-judged in key order (cursors NIGHTLY by payment document, NIGHTLYREQ by FIN): a payment becomes late, a request passes its due date - without new evidence | `PAYOUT_BATCH_MAX_PACKAGES` (1 000) packages per run; stopped earlier → `PAY_BATCH_INCOMPLETE` W, the next run continues from the cursor |
| **SWEEP** | On demand only (SE38 / one-off job), after an outage or a correction | Date range (from / to) and the sources chosen (not RECHECK): re-reads that range; only rows whose outcome, finding, severity, evidence kind, class or due date changed are written | `PAYOUT_BATCH_MAX_PACKAGES`; no watermark is moved |

| Symptom | Where to look | Who acts | What to do |
|---|---|---|---|
| Dashboard and trace disagree for a payment | Trace OUTCOME row (live) vs worklist row | L2 | The worklist is at most one FAST interval behind (late marking: one NIGHTLY run); check SM37. A payment not on the dashboard is finished clean - the trace shows its outcome. A disagreement after a completed run is a defect - ticket with the payment document |
| `PAY_NIGHTLY_MISSING` W on the morning report (A_PRQ_NOT_PAID, evidence PARTIAL) | SM37 job `ZCD_PAY_NIGHTLY`; `ZCD_PAY_OUTWM` source NIGHTLYREQ (CURRENT_TO) | Batch owner | The nightly re-evaluation did not finish since the start of the day: late payments and overdue requests may be missing. Restart the job (it continues from its cursor); the check is never green meanwhile |
| `PAY_BATCH_INCOMPLETE` W (776) on a NIGHTLY / SWEEP run | Run findings, `PAYOUT_BATCH_MAX_PACKAGES` | Payment engine support | The run stopped at its package limit: NIGHTLY continues next night from its cursor (start it again now if the morning report needs it); SWEEP → narrower date range or sources |
| Finding `PAY_OUTCOME_FAILED` (E) on the CORE run of variant `PAY_OUTCOME` (`PAY_OUTCOME_NIGHTLY`, `PAY_OUTCOME_SWEEP`) | Run findings (`ZCD_OPS_FINDING`), message 751 + text (e.g. message 379 "read capped") | Payment engine support | Nothing of the package was written and its watermark / cursor stayed: the next run retries. Capped evidence read → lower `PAYOUT_PACKAGE_SIZE` or raise `HCK_INFLIGHT_MAX_ROWS` after a QA1 runtime check; configuration error (e.g. 384 / 385, 703 request source not configured) → fix by transport |
| Finding `PAY_SOURCE_AMBIGUOUS` (W) | FIN and sources in the message (750); request log of the FIN | Source team / L2 | The same FIN has SUCCESS rows in two sources: one AMBIGUOUS row per source, never attributed to one. Clarify with the source teams; the suite changes nothing |
| `RUN_LOCKED` on the snapshot step | Lock holder in the finding | Batch owner | The previous run of the same mode is still going: check its runtime (SM37); a FAST run longer than 5 minutes → fewer packages per run (`PAYOUT_MAX_PACKAGES`) |
| Outcome looks stale for a payment whose DPAYH status changed | Recheck cursor (`ZCD_PAY_OUTWM`, source RECHECK) | Payment engine support | Status changes have no change stamp: open rows are rechecked one package per FAST run in AUGBL order, and every row by the NIGHTLY run |
| A payment that should be on the worklist after an outage is missing | `ZCD_PAY_OUTWM` of the sources, SM37 history of FAST | Payment engine support | Run SWEEP for the outage's dates and the affected sources (e.g. DOCUMENTS, RETURNS, REQUESTS) in test mode first, then for real |
| A payment cleared, then returned or reversed | Worklist row | — | Expected: the RETURNS / REVERSALS evidence brings the deleted payment back to the worklist when the new outcome needs attention (and deletes it again when final and clean) |

**Parallel packages and the snapshot lag (2026-11-08).** With `PAYOUT_PARALLEL` > 1 (default 4) a run first plans the packages of every source (key reads), then judges them in waves of bgPF units (process `ZCD_PAY_SNAPSHOT_PACKAGE`, SBGRFCMON; rows of the run in `ZCD_PAY_OUTPKG`: P planned, D done, F failed, A abandoned). Each unit commits its versions with its package status; the run advances a source's watermark **only to the end of the last contiguous done package** - a failed or abandoned package and everything after it is read again by the next run (writing nothing twice: an unchanged outcome writes nothing). `PAYOUT_PARALLEL` 1 = one package after the other, versions and watermark in one commit, as before.

| Symptom | Where to look | Who acts | What to do |
|---|---|---|---|
| Freshness card row CORE red, transactions dashboard header "Outcome snapshot lag" red, `PAY_SNAPSHOT_STALE` on the morning report | `ZCD_PAY_OUTWM` (CURRENT_TO per source: the one furthest behind), SM37 step 2 of `ZCD_FMON_MONITOR_ALL`, last snapshot run findings | Batch owner / payment engine support | Job not running → restart the step; running but behind after a peak day → it catches up `PAYOUT_MAX_PACKAGES` × `PAYOUT_PACKAGE_SIZE` documents per source and run; raise `PAYOUT_MAX_PACKAGES` and / or `PAYOUT_PARALLEL` only to the values tested in QA1 (`Test_and_Validation_Document.md` §11a) |
| `PAY_OUTCOME_FAILED` E "package … not finished in … s: abandoned" (763) | SBGRFCMON (process `ZCD_PAY_SNAPSHOT_PACKAGE`), `ZCD_PAY_OUTPKG` of the run | Basis | bgRFC inbound destination of bgPF not running or overloaded: the package is read again by the next run. Raise `PAYOUT_PARALLEL_WAIT_SEC` only if the units are slow, not stuck |
| `PAY_OUTCOME_SERIAL` W "parallel packages not available (bgPF)" (764) | Message tail (CX_BGMC text), SBGRFCCONF | Basis | bgPF not configured: the run judged the packages one by one (correct, slower). Configure the bgPF inbound destination (`Implementation_Order.md`) or set `PAYOUT_PARALLEL` 1 |
| `PAY_SOURCE_AMBIGUOUS` W per flow + class + run date (count, FIN / source examples) | Examples in the finding; request log of each FIN | Source team / L2 | As before; one finding per run date instead of one per FIN |


**Test mode.** `ZCD_OPS_PAY_SNAPSHOT` with *test mode* judges and counts (ALV: documents, evaluated, rows that would be written per source) and writes nothing - no row, no watermark. **Housekeeping (2026-11-08):** `ZCD_OPS_PURGE` (target PAY_OUTCOME, `RETENTION_DAYS_PAY_OUTCOME` = **90** days, never below 30) deletes the exception history closed before the cutoff (closed rows and the closing version of a finished exception). A current (open) row is never deleted, however old - `A_INFLIGHT` and `A_PRQ_NOT_PAID` count from it. Clean payments need no purge: the snapshot deletes their row when they finish.
