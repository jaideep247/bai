# Tool landscape - who watches what (decision document, no code)

> **First principle:** every signal has exactly one owner tool; a second tool may *show* it, never re-derive it.
> **Analogy:** an airport - the tower (technical monitoring) watches the runway, the departure board (Control-M SLA) predicts delays, the airline's own desk (the suite) proves each passenger boarded with the right ticket; nobody repaints the runway lights at the check-in desk.

Status 2026-11-11: proposal for decision. Nothing here is built; the suite stays read-only (no restart, no retrigger, no posting, no incident in SAP).

## 1. Responsibilities

| Concern | Owner tool | What it answers | What the suite does |
|---|---|---|---|
| Technical monitoring: system availability, work processes, dumps, update errors, RFC / qRFC / bgRFC queues, generic job status, interface technical errors, alerting to Basis | **SAP Cloud ALM** (default for S/4HANA 2023 customers with an Enterprise Support contract) **or Focused Run or Avantra** - whichever the customer licenses (**decision D-TL1**) | "Is the system healthy?" | Keeps only the payment-specific checks it already has (E_SYSTEM, E_QUEUES, E_JOBS for `ZCD_*` jobs) as evidence of the morning report; does **not** add generic job-status checks; when the chosen tool watches the same, the suite check is reduced to a link (§4) |
| Batch timing prediction and SLA of the critical chains | **Control-M SLA Management** (BMC Control-M Batch Impact Manager / SLA Management service) | "Will the chain finish before its deadline?" - prediction from history while the chain runs | Monitors after the fact: job cycles `ZCD_JOB_CYCLE` / `ZCD_JOB_STEP` (B_CYCLE_*, B_CLEAR_*), build J's job failure monitor; no prediction, no restart |
| Restart / rerun / self-healing | **Control-M** (operators) | "Restart the step" | **Out of scope** (read-only; user decision). The suite shows the evidence and the runbook link (build A) |
| Payment evidence, reconciliation, daily sign-off | **The suite** (ZCA_OPS + ops suite) | "Did every payment, file, statement and G/L transfer happen - and who signed it off?" | Owner: file monitoring, EBS validation, in-flight, three-way reconciliation, controls and review, payment model, service health |
| Alert routing | **SO23 distribution lists** today (framework alert rules `ZCA_OPS_ALRULE`, channel EMAIL) | "Who must know?" | Unchanged. Optional later: ServiceNow or PagerDuty as an additional alert channel class (`ZIF_CA_OPS_ALERT_CHANNEL`, outbound HTTP) - **decision D-TL2**; the user decision "no incidents in SAP" stays: an incident lives in the external tool, never as a table or field in SAP |

## 2. Critical chains for Control-M SLA Management

| Chain | Steps (Control-M folder `JQ4SP*`, SAP jobs `ZCD_<function>_<ENTITY>` - names VERIFY with the scheduling team) | Define in Control-M |
|---|---|---|
| **Disbursement payment run -> file -> PRISM** | payment run (FPY1 / `RFKK_MA_SCHEDULER`) -> payment media / file generation -> file transfer to PRISM (`ZICD_CALL_SM69_COMMAND_NEW`) -> PRISM delivery to the bank (outside Control-M: FMON stage `PRISM_DELIVERED`) | Service with the deadline of the bank cut-off per bank (JPMC / BOA / PNC); the 2-minute PRISM throttle per bank queue added to the expected duration; alert at "will be late" to the payments team; the suite's FMON SLA stays the after-the-fact evidence |
| **Collections run (ACH, card) -> file -> PRISM** | FPY1 collections -> file -> PRISM | As above, collection cut-offs |
| **Clearing** | bank statement import -> postprocessing -> clearing job (control *Clearing job*, cycle `CLEARING`) | Service "clearing done by 08:30 CST" (cut-off of the control); history-based prediction; the suite's B_CLEAR_TODAY / PRIOR stay the evidence of the sign-off |
| **BlackLine extract** | G/L transfer (FPG1 / reconciliation keys) -> BlackLine extract job -> file transfer | Service with the BlackLine import deadline; the suite proves the keys reached the G/L (A_GL_TRANSFER) and - proposal P4 - the extract file (FMON interface) |

Per chain in Control-M: the ordered jobs, the deadline (time zone America/Chicago, holiday calendar = the factory calendar of the payment engine), the expected run time from history, the notification target (same SO23 lists as the suite's alert rules), and the escalation. The suite's job cycle configuration (`config/hck_seed.md` §7) is the list to start from.

## 3. Cloud ALM coexistence

- **No duplication:** generic job status (cancelled / long-running jobs of every name) belongs to the technical monitoring tool; the suite's `E_JOBS` stays limited to `ZCD_.*` and is switched off when the tool covers the same jobs with an alert to the same team (decision per landscape, recorded in `config/hck_seed.md` §2).
- **Optional forwarding:** error findings (severity E / B) could be forwarded to Cloud ALM event processing (or the chosen tool) as an alert channel class of the framework - **VERIFY the Cloud ALM API** (event / health monitoring inbound API, authentication, payload limits) before any design; outbound call = a change to the read-only principle that needs its own approval (**decision D-TL3**).
- **One link back:** the tool's alert carries the finding key and the suite's exceptions app intent, so the operator lands on the evidence.

## 4. Decisions for the user

| ID | Question | Proposal |
|---|---|---|
| D-TL1 | Which technical monitoring tool is licensed (Cloud ALM, Focused Run, Avantra)? | Cloud ALM if no other contract; the suite keeps only payment evidence |
| D-TL2 | ServiceNow / PagerDuty as alert channel later? | Not now; the channel interface exists; incidents stay outside SAP |
| D-TL3 | Forward E findings to the monitoring tool's event processing? | Only after the API is verified and an outbound-call exception is approved |
| D-TL4 | Control-M SLA services for the four chains of §2 | Yes - owned by the scheduling team; deadlines from the controls' cut-offs |
| D-TL5 | Self-healing (automatic restart) | Out of scope (read-only); restarts stay with Control-M operators |
