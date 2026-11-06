# Audit response — HCK and core / alerting (Phase 6)

> **First principle:** every finding gets a verdict, a fix you can point to, a test that would fail without
> the fix, and an honest residual.
>
> **Analogy:** a garage job card — what was wrong, what was replaced, how it was road-tested, what still
> needs a workshop visit.

Scope: `src/hck`, `ddic/hck`, `src/core`, `ddic/core`, `cds/`, the navigation annotations of the EBS release
DDLX, `tools/git-sync`. Offline build: tests are written and lint-clean but were **not executed** on an SAP
system (no ABAP Unit run, no activation). Release-specific syntax carries `VERIFY-ADT`, DDIC assumptions
`VERIFY-DDIC`.

| Finding | Verdict | Fix | Tests | Residual |
|---|---|---|---|---|
| A06 | Confirmed: hung runs and an empty check selection looked green | Store `get_stale_runs`; per-area HCK_MAX_RUN_MIN → red RUN_HUNG self-check; no executed business check → red CHECKS_NOT_CONFIGURED; only green closes as SUCCESS | `hung_run_fails_self`, `own_run_is_not_hung`, `empty_selection_is_red`, `self_check_alone_not_green`, `stale_running_run_is_found` | Thresholds per area to be confirmed with the batch schedule |
| A17 | Confirmed: no idempotency, carried-forward exceptions re-alerted every run | Intent key (SHA-1 rule/run/channel/destination/subject) claimed as status C and committed before the send, completed after; unique index INT (intent, attempt); carried-forward findings filtered (status R) unless escalating | `second_claim_is_refused`, `failed_intent_can_retry`, `repeat_keys_only_carried`, `claim_precedes_delivery`, `claimed_elsewhere_not_sent`, `carried_exception_no_realert` | Index INT is a manual SE11 step; a claim orphaned by a dump blocks the intent until cleared |
| A18 | Confirmed: TIMEOUT_SEC measured only | `ZCL_CD_HCK_BUDGET`; engine passes deadline/budget in the context; item-wise checks (generic aggregate, drift) stop between items with BUDGET_EXHAUSTED | `within_budget_continues`, `past_deadline_stops`, `no_deadline_never_stops`, `check_receives_time_budget` | One long SQL still cannot be interrupted (separate job step) |
| A42 | Confirmed: job cycle matched by name only, retries and late starts lost | Program/variant match (TBTCP step 1, VERIFY-DDIC); deciding attempt (first finished, else latest running, else latest aborted); STEP_RETRIED / STEP_LATE; unresolved jobs of any date; JOB_READ_CAPPED when 5000 rows are hit | `retry_success_supersedes`, `other_variant_not_matched`, `late_success_is_flagged`, `job_run_carries_variant`, `unresolved_jobs_any_date` | Real job names behind the wiki placeholders |
| A43 | Confirmed: any BKPF with the AWKEY counted, across company codes | Gap per FIKEY + BUKRS; NOT EXISTS a non-reversed BKPF of AWTYP (PARAM4, default FKKSU); metric = total gaps | `gl_gap_per_company_and_type` | AWTYP / AWKEY length VERIFY-DDIC |
| A44 | Confirmed: job reads silently capped | Cap constant 5000 and a JOB_READ_CAPPED finding (tech jobs, job cycle) | covered by A42 tests + lint | — |
| A45 | Confirmed: silent success paths | `send( )` without recipient / on inactive channel logs F and raises (021 / 007); BCS send result checked (026); SLG1 log written in part = status P (025) | `send_without_recipient_fails`, `send_inactive_channel_fails` | BCS / BAL behaviour not executed offline |
| A46 | Confirmed: escalation counted sent rows, throttle could suppress it | Consecutive runs from the area's run history (a run without the rule ends the series); ESC_OVERRIDE passes the throttle | `healthy_run_breaks_series`, `escalation_beats_throttle` | ESC_OVERRIDE values to agree per rule (seed suggestion) |
| A47 | Confirmed: amount without currency semantics | Amount DECFLOAT34 with `@Semantics.amount.currencyCode`, currency CUKY; cube never adds currencies | CDS parser rule (abaplint) | VERIFY-ADT: DECFLOAT34 amount semantics on 2023 |
| A56 | Confirmed: raw query structures accepted by the DAO | Queries carry their definition; DAO rebuilds through the builders (whitelist re-checked) | `raw_aggregate_is_rejected`, `raw_value_query_is_rejected` | — |
| A57 | Confirmed: concatenated hash ambiguous (`A|B` vs `A`,`B`) | `ZCL_CD_HCK_CANONICAL` length-prefixed fields, hash version 2, cursor closed on error; outdated baseline reported | `separator_values_differ`, `same_row_same_text`, `field_is_length_prefixed` | Baselines must be retaken once (CONFIG_BASELINE_OUTDATED) |
| A58 | Confirmed: flat history (σ = 0) never an outlier | Flat tolerance HCK_FLAT_TOL_PCT on the adverse side | `flat_unchanged_passes`, `flat_adverse_change_flagged`, `flat_favourable_change_ok` | Tolerance to tune per metric |
| A59 | Confirmed: history mixed test / unfinished runs and later points | One point per finished, non-test run, as of the report date | `history_one_point_per_run`, `history_skips_unfinished_runs`, `history_as_of_excludes_later` | — |
| A60 | Confirmed: backdated reports used today's history | `history_as_of` = end of the report date | covered by A59 tests | — |
| A61 | Confirmed: partial CSV could replace a complete one | `ZIF_CD_HCK_FILE` / `ZCL_CD_HCK_DATASET`; temp file first, target only when complete; cleanup on failure | `complete_write_publishes`, `temp_failure_keeps_target`, `target_failure_removes_it` | Rename is a copy (no atomic rename in DATASET) |
| A62 | Confirmed: CREATE OBJECT before the interface check | `GET_PLUGIN` takes the interface; RTTI (classic EXCEPTIONS, 033) and `APPLIES_TO_CLASS` before CREATE OBJECT; doubles held to `APPLIES_TO`; router and HCK engine pass their interface | `unrelated_class_not_created` (probe constructor count 0), `matching_interface_creates`, `unknown_interface_refused`, `double_must_match_interface` | EBS / FMON callers still pass none (merge note) |
| A63 | Confirmed: cap took the first N, blocker could be cut | Ranking B > E > W > I, ties by rule/check/object/position; digest severity from the full selection; held-back count in text and HTML | `blocker_after_cap_is_kept`, `per_finding_blocker_first`, `cap_order_is_stable` | — |
| A64 | Confirmed: parameter cache lived for the session | `refresh_params`; `start_run` takes a fresh snapshot; HCK baseline refreshes | `next_run_sees_changed_param`, `param_stable_within_run` | EBS `validate_for_posting` must call `refresh_params` (merge note) |
| A87 | Confirmed: negative and closed-history days past due | DaysPastDue only for O/A items past due, else 0 | CDS parser rule | — |
| A88 | Confirmed: one SUM over volumes, durations and rates | ZCD_HCK_METRIC KIND (V/L/R) and WEIGHT; checks classify (SLG1 error rate weighted by messages; lock / overdue ages are levels); cube VolumeValue SUM, LevelMax / average, weighted rate | `metric_kind_and_weight_saved`; CDS parser rule | VERIFY-ADT: DECFLOAT34 product, query formulas, hidden measures |
| SLG1 | Confirmed: external ID = rule only, logs kept in memory | External ID `<area>/<run>/<rule>`; BAL_LOG_REFRESH after BAL_DB_SAVE | lint only (no BAL double) | Not executed against BAL |
| FEBAN / FPCPL | Gap: no navigation from the operations apps | Intent navigation `ZCDBankStatement-reprocess` (FEBAN) and `ZCDPaymentLot-clarify` (FPCPL) in the exceptions and EBS release DDLX | CDS parser rule | VERIFY-ADT; target mappings in the launchpad catalog |
| A48 | Confirmed: scheduled task pushed by default, abort result unchecked | `-Push` opt-in (default pull only, AHEAD logged); abort only when a rebase is in progress, then HEAD/branch verified, else ERROR | Scripted conflict in a scratch repo: pull exit 1, rebase in progress, abort 0, HEAD and branch restored, abort without rebase 128 | PowerShell not run (no pwsh in the build container) |

Totals after Phase 6 (this stream): 233 ABAP files, 511 unit test methods, portable checks 15/15,
abaplint 0 issues, ATC-equivalent only the two documented exemptions.

## Merge notes

For owners of shared files and other streams — not edited here:

1. **EBS stream:** pass `iv_interface = 'ZIF_CD_EBS_RULE'` in `ZCL_CD_EBS_ENGINE` (and the rule-base tests) to
   `ZCL_CD_OPS_FACTORY=>GET_PLUGIN` (A62); call `zcl_cd_ops_factory=>get_store( )->refresh_params( )` at the
   start of `validate_for_posting`, which runs without `start_run` (A64).
2. **FMON stream:** pass the adapter interface to `GET_PLUGIN` (A62).
3. **Messages:** core 025, 026, 033 and HCK 360–369 appended to `config/zcd_ops_messages.md`; regenerate the
   message class with `tools/abapgit_serialize.py` after merging other streams.
4. **DDIC (manual SE11):** unique index `ZCD_OPS_ALERT_LOG~INT` (MANDT, INTENT_KEY, ATTEMPT); new fields
   ZCD_OPS_ALERT_LOG-INTENT_KEY/ATTEMPT, ZCD_OPS_ALERT_RULE-ESC_OVERRIDE, ZCD_HCK_BASELINE-HASH_VERSION,
   ZCD_HCK_METRIC-KIND/WEIGHT.
5. **Shared docs** (`docs/ATC_Validation.md`, `docs/Class_Purpose_and_Modification_Log.md`, README): add
   `ZCL_CD_HCK_BUDGET`, `ZCL_CD_HCK_CANONICAL`, `ZCL_CD_HCK_DATASET`, `ZIF_CD_HCK_FILE`,
   `ZCL_CD_OPS_PLUGIN_PROBE` (test support, never configured); the ATC exemption line number in
   `ZCL_CD_HCK_DAO` (select_add_order_by) moved to line 176.
6. **Launchpad:** target mappings for `ZCDBankStatement-reprocess` → FEBAN and `ZCDPaymentLot-clarify` → FPCPL
   in the operations catalog.
7. **Operations:** retake HCK baselines once after transport (hash version 2); reinstall the git-sync task
   (`install-git-sync-task.ps1`, add `-Push` only if pushing is wanted).
