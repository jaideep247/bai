# Control register and daily control review (ZCA_OPS)

> **First principle:** a control's status is read from the findings of the checks it covers; only the person's sign-off is stored.
> **Analogy:** a shift handover sheet where the gauges fill themselves in — the supervisor only initials each line, and a line turns red again if a gauge moves after the initials.

Status 2026-11-10: written and statically checked offline (abaplint 0 issues); **nothing activated, no ABAP Unit run**. Company-code slices added 2026-11-10 (§2a). Reusable: a consumer registers its controls as configuration rows and reads the derived rows for its own cards; the framework never names a consumer.

## 1. Objects

| Piece | Objects |
|---|---|
| Control register (customizing, delivery class C, transport from DV1) | `ZCA_OPS_CONTROL` (area, control ID, name, category, owner, backup, team, review cut-off, runbook link, active, sequence), `ZCA_OPS_CTLT` (guidance per language), `ZCA_OPS_CTLCHK` (checks covered: area of the findings, finding field `RULE_ID` / `CHECK_CODE` / `GROUP2`, exact value) — maintained in `ZUI_CA_OPS_CFG` (generated, *Settings & ownership*) |
| Sign-off (application data, the only stored part) | `ZCA_OPS_REVIEW` (area, control, business date; status at sign-off, result, evidence run, checked by, verified at UTC, observation, next action, ETag stamp) |
| Status texts | domain `ZCA_OPS_CTL_STATUS` (H *Healthy*, W *Watch*, A *Action required* — translatable fixed values), text view `ZI_CA_OpsCtlStatusT` |
| Derivation (CDS, `src/ui`) | `ZI_CA_OpsCtlTz` (time zone), `ZI_CA_OpsBusDay` (business dates, 31 days), `ZI_CA_OpsCtlRunDay`, `ZI_CA_OpsCtlFind`, `ZI_CA_OpsCtlFindDay`, `ZI_CA_OpsCtlArea`, `ZI_CA_OpsCtlRunMax`, `ZI_CA_OpsCtlEvid`, `ZI_CA_OpsCtlOpen`, `ZI_CA_OpsCtlDay`, `ZI_CA_OpsCtlState` |
| Review app | RAP BO `ZR_CA_OpsCtlReview` (managed, unmanaged save, unmanaged lock, ETag), projection `ZC_CA_OpsCtlReview` (+ DDLX, BDEF), action parameter `ZA_CA_CtlReview`, DCL `ZC_CA_OPSCTLREVIEW`, service `ZUI_CA_OPS_REV` (binding `ZUI_CA_OPS_REV_O4`), behaviour pool `ZBP_R_CA_OPSCTLREVIEW` |
| Logic and persistence | `ZCL_CA_OPS_REVIEW_POLICY` (rules, no database), `ZIF_CA_OPS_REVIEW_DAO` / `ZCL_CA_OPS_REVIEW_DAO` (lock + save; factory `GET_REVIEW_DAO`, injector `INJECT_REVIEW_DAO`), `ZIF_CA_OPS_CTL_TYPES`; field checks `ZCL_CA_OPS_CFG_CHECKS=>USER_VALID` / `TEAM_VALID` / `URL_VALID` (messages 437-439) |
| Retention | built-in purge target `REVIEW` (`RETENTION_DAYS_REVIEW`, 400 days) |
| Tests | `ZCL_CA_OPS_REVIEW_POLICY` (11), `ZCL_CA_OPS_REVIEW_DAO` (3), `ZCL_CA_OPS_CTL_CDS_TEST` (`ltc_find`, `ltc_state`, `ltc_review`), `ZCL_CA_OPS_CFG_CHECKS` (`ltc_control_check`), `ZCL_CA_OPS_PURGE_DAO` (`old_review_is_deleted`) |

## 2. Which findings belong to a control

A covered-check row selects findings of its **check area** whose `RULE_ID`, `CHECK_CODE` or `GROUP2` **equals** the value (one row per value; a family of checks is several rows). A check of the check registry (process onboarding, 2026-11-10) is covered by its **`GROUP2` = check ID** row: the generic runner stamps GROUP2 on every finding of the check, and the onboarding check counts only `GROUP2` rows of active controls as coverage. Exact values, not patterns: the status is joined in CDS for the review app and the consumers' overview cards, and a PCRE cannot be evaluated in a join (`Performance_Review.md` of the first consumer, §6b). Rows of one control must not overlap (a finding matching two rows is counted twice in the open exceptions).

## 2a. Slices per company code (company-code isolation, 2026-11-10)

A row of the review is a **slice**: control, business date and company code (`ZI_CA_OpsCtlSlice`). The **area-level slice** (blank company code) exists for every active control and date and holds the findings without company code and the run evidence; a **company-code slice** exists where that company code has findings of the control on the date, open exceptions of the control now, or a sign-off of the date. Status, finding count, open exceptions and sign-off of a slice are those of its own company code only (`ZI_CA_OpsCtlFindDay`, `ZI_CA_OpsCtlOpen` per company code; `ZCA_OPS_REVIEW` key `BUKRS`). Each slice is signed off on its own, by a reviewer with `ZCA_OPS` 02 for the area and, for a company code, that `BUKRS`. The read DCL `ZC_CA_OPSCTLREVIEW` applies the company-code rule (`docs/auth_zca_ops.md` §3c) to the slice; the counters (`ControlCount`, `ReviewedCount`, ...) count slices, so a card of a user of one company code sums only the area-level slice and the slices of that company code. A central user with every company code sees one row per control and date plus one per company code with findings - the price of never mixing two company codes in one status. The evidence run is area-level (a run has no company code) and the same on every slice of the date.

## 3. Status of a control on a business date (derived, never stored)

- **Business date** = the local date of the run start in the time zone `CONTROL_TIME_ZONE` (area `CA_OPS`, default `UTC`; TTZZ zone, e.g. `CST`).
- **Live findings of the date** = findings of the non-test runs of that date, disposition open (O), assigned (A) or superseded (S: raised again by a later run). Resolved (R — also by a later run that no longer raised it, the auto-resolve of the store) and waived (W) findings and information findings do not count. So the **latest result of the date decides**: a check that went red at 07:00 and green at 09:00 is healthy at 09:30 (its 07:00 exception was resolved by the 09:00 run).
- **Status** = worst rank of the live findings: severity B / E → **Action required** (2), W → **Watch** (1), none → **Healthy** (0) (`ZCL_CA_OPS_REVIEW_POLICY=>STATUS_OF_SEVERITY`, the same rule in `ZI_CA_OpsCtlFind`). The texts are the domain's fixed values (translatable), never literals.
- **Exceptions** = open or assigned findings of severity B / E / W of the control's checks now, whatever run raised them (`ZI_CA_OpsCtlOpen`).
- **Evidence** = the latest run of the control's areas on the date (`ZI_CA_OpsCtlEvid`), stored with the sign-off.

## 4. Sign-off, awaiting review, overdue

- **Mark reviewed** (action `markReviewed`, ZCA_OPS **02** for the control's area): status, evidence run, user (`sy-uname`) and time (UTC, shown in `CONTROL_TIME_ZONE`) come from SAP. The reviewer may confirm the derived status or enter another result; **observation and next action are mandatory when the status or the result is Action required (076)**, an observation when the result differs from the derived status (077); a result must be H / W / A (078). No incident field (user decision 2026-11-10).
- **Awaiting review** = active control and (no sign-off for the date, or the status now **worse** than at the sign-off, or a finding raised **after** the sign-off). A better status keeps the sign-off.
- **Overdue** = awaiting and (the business date is over, or today past the control's cut-off — local time of `CONTROL_TIME_ZONE`; no cut-off = end of the day).
- **Concurrency**: one row per control and date; the action locks control + date (`ENQUEUE_E_TABLE` on `ZCA_OPS_REVIEW`, message 079 when another user holds it) and the ETag `LastChangedAt` refuses a sign-off on a version the user did not see (HTTP 412): the second of two reviewers refreshes, nothing is lost.

## 5. Review app (Fiori elements list report "Daily control review")

Service `ZUI_CA_OPS_REV`, entity `ControlReview`. Filters: current business date (default, `IsCurrentDay` = X - today in `CONTROL_TIME_ZONE`), business date, status, flagged (watch + action required), team, awaiting review, overdue, area; search by control name or ID. Columns: control, category, status (coloured), owner, team, cut-off, exceptions, awaiting, overdue, checked by, verified at (local). Object page: guidance, runbook link, status and evidence, sign-off. 31 business dates (window of `ZI_CA_OpsBusDay`).

## 6. How a consumer uses it

1. Rows of `ZCA_OPS_CONTROL`, `ZCA_OPS_CTLT`, `ZCA_OPS_CTLCHK` for its area(s) in `ZUI_CA_OPS_CFG` (DV1, transport); owner / backup are checked as users, the team against `CONTROL_TEAMS`, the runbook link as http(s).
2. A role with ZCA_OPS 03 (+ 02 for reviewers) for those areas; tile *Daily control review* (`ZUI_CA_OPS_REV_O4`).
3. Own cards: select from `ZR_CA_OpsCtlReview` (counters `ControlCount`, `ReviewedCount`, `AwaitingCount`, `OverdueCount`, `ActionRequiredCount`, `WatchCount`, `FlaggedCount`) — the same rows the review app shows.

## 7. VERIFY

V26-V33 of `VERIFY.md`; company-code slices V35, V37, V38, V40, V41.
