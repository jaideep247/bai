# Pilot pack - proof of value in shadow mode

Release: 2026-11-11 (build F, gap 3). One page for the pilot owner. Read-only metrics of data the framework already
holds - nothing is posted, cleared, changed or sent to a business user during the pilot.

> **First principle:** a pilot proves value only with numbers both sides accept before it starts - what was found,
> how early, how often it was wrong, how fast it was handled - measured the same way at the start and at the end.
>
> **Analogy:** a new smoke detector installed next to the old one for a month. It rings into a log, not into the
> building; at the end you compare: which fires did it smell first, how many times was it only toast.

## 1. Success criteria (agree before day 1)

| Measure | Where | Example target |
|---|---|---|
| Exceptions per day (by area, business process, check) | `ZUI_CA_OPS_PILOT` chart *Exceptions per day*; export DAY records | stable volume an operator can work (e.g. ≤ 50 / day / area) |
| False-positive rate = resolved with reason `NOT_AN_ISSUE` / resolved | `FalsePositiveCount` / `ResolvedCount`; query `ZC_CA_OpsPilotQry` *False-positive rate* | < 10 % after the tuning week |
| Time to detect = first seen - event time (else the business date) | `MinutesToDetect` (average) | below the baseline for ≥ 80 % of the checks |
| Against the previous detection time | `BaselineMinutes` per check (`ZCA_OPS_PILOTBL`), `MinutesEarlier`, `EarlierCount` | e.g. next-day reconciliation 1 440 min → same-day |
| Time to assign / resolve (MTTA / MTTR) | `MinutesToAssign`, `MinutesToResolve` (the response-time metrics, `ZUI_CA_OPS_MET`) | trend down over the pilot |
| Share of breaks explained = groups in a bucket other than OTHER / all groups | `ZUI_CA_OPS_PILOT` *BreakExplained*; export BREAK records | ≥ 90 % at month end |

## 2. Running in shadow mode in production - safely

1. **Read-only by construction**: checks and the break analysis only read business tables; the framework writes only
   its own tables (findings, snapshots). No action of the exceptions app changes a business object.
2. **No alerts to the business**: alert rules of the pilot areas only to the pilot team's SO23 list (or channel APPLOG);
   no escalation (`ESC_AFTER_MIN` blank) until the pilot ends.
3. **Roles**: pilot operators `ZCA_OPS` 03 (display) + 02 (classify / resolve) for the pilot areas; the job user 16
   (execute); nobody needs posting authorisations. Company-code isolation applies (`docs/auth_zca_ops.md` §3c).
4. **Classify every resolved exception**: `NOT_AN_ISSUE` for a false positive, `TIMING` / `INVESTIGATING` otherwise -
   an unclassified resolution is not counted as a false positive (the rate is a lower bound until classification is
   complete; report the unclassified share alongside).
5. **Baselines first**: one row per check in `ZCA_OPS_PILOTBL` (minutes after the event at which the issue was found
   before, and where that number comes from - incident history, month-end review). No baseline = no comparison.
6. **Event time**: checks that know the business event set `TY_FINDING-EVENT_AT` (else `BUSINESS_DATE`); a finding
   with neither is counted but not measured (`DetectKnownCount`).
7. **Freeze configuration during a measurement window** - or compare per configuration version (every finding carries
   it; `docs/EXPLAINABLE_RESULTS.md`).

## 3. What to export

Report `ZCA_OPS_PILOT_EXPORT` (area, from / to, file name; `ZCA_OPS` 03): one CSV (separator `;`) on the application
server in the logical path `PILOT_EXPORT_PATH` / logical file `PILOT_EXPORT_FILE` (transaction FILE), complete or
nothing. Records: `DAY` (per day, business process, check: raised, assigned, resolved, false positives and rate,
average minutes to detect / baseline / to assign / to resolve, detected earlier), `BREAK` (per account and key date:
breaks, explained, unexplained, share explained), `BASELINE` (check, previous detection minutes, source). **Figures
only** - no amount, no account number, no business partner, no document number leaves the system; the export is the
pilot evidence and may be shared. The Fiori lists add *Export to Spreadsheet* for ad-hoc views (same authorisation).
Never copy production rows into a repository or a ticket.

## 4. How to read the numbers

- Compare **like with like**: the same areas, checks and calendar days; month-end days separately.
- Rates divide **sums** by counts of the selection (never an average of daily averages); a blank rate means "no
  count", not zero.
- A falling false-positive rate with a stable exception volume = tuning works; a falling volume with a rising OTHER
  share = rules missing (look at the unexplained breaks by account).
- Time to detect below the baseline is the headline; MTTA / MTTR show whether the organisation used the early warning.
- Every number is reproducible: area, date range, configuration version and the export file name go into the pilot
  report.

Objects: `ZR_CA_OpsPilot` / `ZC_CA_OpsPilot` (analytical list page, service `ZUI_CA_OPS_PILOT`), `ZI_CA_OpsPilotCube` /
`ZC_CA_OpsPilotQry`, `ZR_CA_OpsPilotBrk`, `ZI_CA_OpsPilotDay`, `ZI_CA_OpsPilotEp`, `ZI_CA_OpsPilotCfg`; parameters
`PILOT_FP_REASON` (NOT_AN_ISSUE), `PILOT_WINDOW_DAYS` (30), `PILOT_EXPORT_PATH`, `PILOT_EXPORT_FILE`; reason code
`NOT_AN_ISSUE` in `EXC_REASON_CODES`. VERIFY V142, V143 (`docs/VERIFY.md`).
