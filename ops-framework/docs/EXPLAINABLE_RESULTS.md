# Explainable, versioned results

Release: 2026-11-11 (build F, gap 2). Component: operations framework `ZCA_OPS`. Read-only towards business data.

> **First principle:** a finding is evidence only when anyone can tell, later, *which rule* produced it and
> *with which settings*. A result whose settings may have changed since is a different result, even if it looks the same.
>
> **Analogy:** a laboratory report names the test method and the calibration of the instrument. If the lab recalibrates,
> yesterday's signed report is not wrong - but a new reading taken with the new calibration needs a new signature.

## 1. What every finding records

| Field (`ZCA_OPS_FINDING`) | Meaning | Set by |
|---|---|---|
| `GROUP2` | Check ID (registry row `ZCA_OPS_CHECK`) | runner (unchanged) |
| `RULE_ID` | Rule of the check (e.g. aggregate ID, `RUNNER`) | the check (unchanged) |
| `CFG_RULE` (new) | The configuration row inside the check that produced or explained the finding - aggregate ID of `ZCA_OPS_AGG`, bucket rule ID of the break analysis (`docs/BREAK_ANALYSIS.md`) | the check |
| `CFG_VERSION` (new) | Configuration version: SHA-1 (hex, 40 characters) of the effective configuration rows of the check in that run | runner (`ZCL_CA_OPS_CFG_VERSION`), unless the check set one itself |
| `BUS_DATE`, `EVENT_AT` (new) | Business date and event time the finding is about (pilot metrics, `docs/PILOT_PACK.md`) | the check (`TY_FINDING-BUSINESS_DATE`, `EVENT_AT`) |

**Effective configuration rows of a check** = its registry row (area, check ID, process, class, schedule group,
company-code flag, active - description and sequence left out: they change no result) plus the rows the check names
through the optional interface `ZIF_CA_OPS_CHECK_CONFIG`:

| Check | Its own rows |
|---|---|
| `ZCL_CA_OPS_CHK_AGG` (no-code aggregate) | every active `ZCA_OPS_AGG` row of the check (thresholds amber / red, window, conditions; description left out) |
| `ZCL_CA_OPS_CHK_BREAK` (unexplained breaks) | the version of the break snapshot it reads (bucket rules, conditions, accounts, `BRK_` parameters) and its own parameter `BRK_UNEXPLAINED_DAYS` |
| any other check | none until it implements `ZIF_CA_OPS_CHECK_CONFIG` - versioned by its registry row |

Lines are built with `ZCL_CA_OPS_CFG_VERSION=>LINE` (kind + values) and **sorted** before hashing: the order a check
lists its rows in never changes the version; one changed value always does. The version is **not inherited** by the
carry-forward - every row keeps the version of its own run, so "the same exception, produced under another
configuration" stays visible.

## 2. Where it shows

- **Exceptions app** (`ZUI_CA_OPS_EXC`): object page facet *Explanation* - check, rule, configuration rule,
  configuration version, business date, event time; columns and filters *Configuration rule* and *Version (short)*
  (first 8 characters).
- **Daily control review** (`ZUI_CA_OPS_REV`): *Sign-off reopened* with its reason (below).

## 3. Reopened sign-off

A signed-off slice (control, business date, company code; `ZCA_OPS_REVIEW`) is **REOPENED** - shown as awaiting
review again, with a reason - when, after the sign-off, a finding the control covers

| Reason (domain `ZCA_OPS_REOPEN`) | Rule (per finding recorded after `REVIEWED_AT`, compared with the row it replaced: same area, object type, key, check code, company code, `SUPERSEDED_BY` = the finding's run) |
|---|---|
| `NEW` | first seen after the sign-off (`FIRST_SEEN_AT` > `REVIEWED_AT`) |
| `STATUS` | severity differs from the replaced row |
| `AMOUNT` | amount or currency differs |
| `CONFIG` | produced by another configuration version (both versions known - rows written before this release have none and never reopen on CONFIG) |
| `WORSE` | no finding changed, but the derived status is worse than at the sign-off (the existing rule) |

The slice shows the first reason that applies in the order above and the number of changed findings per reason
(`ZI_CA_OpsCtlReopen` -> `ZI_CA_OpsCtlReopDay` -> `ZI_CA_OpsCtlState`; the same rules in
`ZCL_CA_OPS_REVIEW_POLICY=>REOPEN_REASON` / `REOPEN_REASON_OF_SLICE`, unit-tested). Nothing is stored: like the status,
the reopen state is derived from the findings each time it is shown. Signing off again moves `REVIEWED_AT` and clears it.

**Changed rule (decision for the user, D-F1):** before this release *any* finding recorded after the sign-off put the
control back to awaiting review - with hourly runs, every carry-forward of an unchanged exception did. Now a finding
raised again **unchanged** keeps the sign-off. Every other sign-off rule is unchanged (no sign-off -> awaiting; worse
status -> awaiting; better status keeps the sign-off; overdue; mandatory texts 076 / 077 / 078; lock and ETag).

## 4. Adding a check's rows to its version

```abap
CLASS zcl_xx_chk_example DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.
    INTERFACES zif_ca_ops_check_config.
ENDCLASS.
...
  METHOD zif_ca_ops_check_config~config_lines.
    " every row that can change a result: thresholds, lists, the parameter values the check reads
    INSERT zcl_ca_ops_cfg_version=>line( iv_kind = 'PARAM' is_row = |XX_LIMIT={ mv_limit }| ) INTO TABLE rt_lines.
  ENDMETHOD.
```

## 5. Verification

VERIFY V132 (table adjustment, CDS on 7.58, PlanViz CTL-09), V133 (ABAP Unit / CDS tests) - `docs/VERIFY.md`.
