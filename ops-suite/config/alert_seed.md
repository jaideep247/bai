# Alert configuration — example rows (confirm before transport)

> **First principle:** who hears about a problem, how fast and how loud is configuration, never code.
> **Analogy:** a building's fire panel — zones (rules) are wired to sirens, pagers or the control room (channels) by the installer, not by the fire.

## ZCD_OPS_ALERT_CHN

| CHANNEL | CLASS_NAME | DESTINATION | ACTIVE |
|---|---|---|---|
| EMAIL | ZCL_CD_OPS_CHN_EMAIL | *(blank — rule gives recipients)* | X |
| APPLOG | ZCL_CD_OPS_CHN_APPLOG | ZCD_OPS/ALERT | X |
| HTTP | ZCL_CD_OPS_CHN_HTTP | ZCD_OPS_WEBHOOK *(SM59 destination, created by Basis)* | |

## ZCD_OPS_ALERT_RULE

| RULE_ID | MODULE | MIN_SEVERITY | RULE_PATTERN | CHECK_PATTERN | MIN_RAG | ON_ABORT | CHANNEL | DESTINATION | DIGEST | MAX_ITEMS | THROTTLE_MIN | QUIET | ESCALATE_AFTER / DEST |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| EBS_BLOCK | EBS | B | | | | | EMAIL | payment-ops DL | X | 50 | 0 | — | 3 / RTB lead DL |
| EBS_ERROR | EBS | E | | | A | X | EMAIL | payment-ops DL | X | 50 | 60 | 22:00–06:00 | — |
| EBS_LOG | EBS | W | | | | | APPLOG | ZCD_OPS/EBS | X | 500 | 0 | — | — |
| FMON_PART | FMON | E | | *PARTIAL* | | | EMAIL | returns-ops DL | X | 50 | 0 | — | 2 / RTB lead DL |
| FMON_SLA | FMON | E | | *SLA* | | | EMAIL | payment-ops DL | X | 50 | 30 | — | 3 / RTB lead DL |
| NOC_AGING | FMON | E | | NOC_AGING* | | | EMAIL | compliance DL | X | 100 | 1440 | — | — |
| HCK_RED | HCK | E | | | R | X | EMAIL | RTB support DL | X | 50 | 60 | 22:00–06:00 | 2 / RTB lead DL |
| ALL_ABORT | * | B | | | | X | HTTP | ZCD_OPS_WEBHOOK | X | 20 | 15 | — | — |

ZCD_OPS_PARAM for reports sent with `send( )`: `ALERT_MORNING` (morning report distribution list), `ALERT_DEFAULT` (fallback), `ALERT_ESCALATION_WINDOW_H` (default 24).

Rules of behaviour (proved by `ZCL_CD_OPS_ALERT_POLICY` / `ZCL_CD_OPS_ALERT_ROUTER` unit tests):
- Severity **B** (blocked, never posted) ignores quiet hours.
- Throttled (T) and quiet-hour (Q) decisions are logged in ZCD_OPS_ALERT_LOG — nothing is silently dropped.
- A failing channel is logged as F and never aborts the run; the morning report's "alert delivery health" check counts F rows.
- Test-mode runs never alert.
