*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_inflight.clas.abap
*& Purpose:
*& Financial integrity: payments issued by payment runs (DPAYH) that are
*& still in flight, per flow (D disbursement / C collection,
*& TFK042Z-XEINZ) and method class (configuration: posting area ZPMC, payment
*& methods, ageing basis, calendar; rows with HBKID: calendar per house
*& bank). The verdict of every payment is the canonical outcome of the
*& shared evaluator ZIF_CD_OPS_PAY_OUTCOME (rules ZCD_HCK_CLRRULE, evidence
*& plug-ins): CLEARED / RETURNED / RETRIEVED / VOIDED / PENDING left out,
*& IN_FLIGHT and UNDETERMINED aged, INCONSISTENT listed. The check counts
*& EVERY payment not yet final from the current rows of the payment
*& worklist ZCD_PAY_OUTCOME (open payments and exceptions only - a clean
*& payment has no row since 2026-11-08), aggregated on HANA with DPAYH by key
*& - no row cap and no look-back window for payments in flight, however old.
*& Ageing by the shared rule ZCL_CD_HCK_PAY_AGEING (the worklist marks late
*& payments with it): VALUE_DATE classes in business days after the value
*& date (run date when missing) by the house bank / class / PARAM1 calendar,
*& ISSUE_DATE classes in calendar days after the run date; the calendars are
*& read once per run into a day table per calendar and applied to the
*& groups, never per payment. Only payment documents the snapshot has not
*& reached yet (entered after the DOCUMENTS watermark) and
*& payments whose versions all say AMBIGUOUS are evaluated live, bounded by
*& HCK_INFLIGHT_MAX_ROWS (metric PAY_NOT_SNAPSHOT). A snapshot behind more
*& than MON_STALE_AFTER_MIN_CORE is said (PAY_SNAPSHOT_STALE, evidence
*& PARTIAL): never GREEN on stale data. Findings are aggregated: one per
*& flow + method class + finding code + payment run date with the count,
*& the amount per currency and the first PAYOUT_EXAMPLES payments (oldest
*& first). PAY_STATUS_LAG: (b) the version marked PAY_STATUS_PENDING longer
*& than HCK_PAY_STATUS_LAG_MIN, (a) the bank ACK of the payment or of the
*& file of its run older than the grace while the status is still ISSUED.
*& Read-only.
*& Modification log:
*& 2026-11-07 | Initial version (payments in flight, morning report).
*& 2026-11-07 | Both flows (D / C); wire / ACH aged from the value date in business days (user change).
*& 2026-11-07 | Clearing / return evidence by rules and plug-ins (user rules 1-5); method classes, ageing
*&            | basis and calendars (class, house bank) from configuration; inconsistency / anomaly
*&            | findings; DFKKRP and BSAS reads moved into evidence plug-ins.
*& 2026-11-07 | Design review: REQUIRED X / C / N mandatory - a mandatory kind not configured,
*&            | invalid or unreadable makes the purpose undetermined (CLEARING_UNDETERMINED,
*&            | PAY_UNDETERMINED, configuration finding W); only informational rows are skipped.
*& 2026-11-07 | Code review: every anomaly of an evidence is listed (TY_EVIDENCE-MORE); the shared
*&            | reads of the evidence kinds start per run (ZCL_CD_HCK_EV_SUPPORT=>START_COLLECTION).
*& 2026-11-07 | Persisted verdict: completion PARTIAL after a capped read, evidence PARTIAL when an evidence
*&            | kind of a mandatory row could not be used (ZCD_HCK_RESULT).
*& 2026-11-07 | Canonical payment outcome: configuration, reversal, evidence collection and the decision
*&            | per payment moved unchanged into the shared evaluator ZIF_CD_OPS_PAY_OUTCOME (core
*&            | factory GET_PAY_OUTCOME), which the payment trace and the 5-minute snapshot of the
*&            | transactions dashboard use too; this check keeps windows, ageing, metrics and findings.
*& 2026-11-08 | Status lag PAY_STATUS_LAG (W, one finding per payment in flight, metric per flow + class):
*&            | (b) the bank evidence decides but a payment status row waits for the hourly status job
*&            | (verdict STATUS_PENDING) longer than HCK_PAY_STATUS_LAG_MIN after the newest statement
*&            | line's day; (a) a disbursement's payment-level bank ACK (configured TRACE_SRC_ACK, the
*&            | link the payment trace uses) is older than the grace while the status is still in
*&            | HCK_PAY_STATUS_ACK_OPEN (ISSUED). Set-based: the shared status read and one ACK read.
*& 2026-11-08 | Status lag after a file-level ACK (user 2026-11-08: every payment goes through ISSUED and
*&            | CONFIRMED; collections are acknowledged per file): which ACK applies is configuration
*&            | (HCK_PAY_ACK_FILE_CLASSES, default CACH,CCRD; every other class per payment). Link: the
*&            | payment's DPAYH run (fields named by GROUP_FIELDS of the FMON source HCK_PAY_ACK_FILE_SRC)
*&            | -> generation group key (ZCL_CD_FMON_RULES=>GENERATION_KEY, as FMON builds it) -> the
*&            | latest generation of each interface of the group (a replaced file never counts) -> its
*&            | ACK_RECEIVED event; one FMON read for all candidates (ZIF_CD_FMON_DAO=>GET_GROUP_ACKS,
*&            | index GRP). Link not configured: one INFLIGHT_CONFIG W per run, nothing judged; no ACK at
*&            | all is FMON's finding, not a lag. Reads FMON through its factory only (one-way).
*& 2026-11-08 | Table consolidation: house-bank calendars are ZCD_HCK_PMCLASS rows with HBKID (ZCD_HCK_PMBANK
*&            | merged); resolution bank row, class row, PARAM1, none - unchanged.
*& 2026-11-08 | Scale (2 million payments a peak day, user 2026-11-08): every payment in flight counted from
*&            | the current versions of ZCD_PAY_OUTCOME grouped on HANA (ZIF_CD_OPS_PAY_OUTCOME_DAO=>
*&            | GET_OUTCOME_GROUPS) - no row cap, no look-back window for outcomes not final; calendars
*&            | as day tables per calendar and run; live evaluation only for documents not yet snapshotted
*&            | and AMBIGUOUS-only payments (PAY_NOT_SNAPSHOT); stale snapshot = PAY_SNAPSHOT_STALE W and
*&            | evidence PARTIAL (MON_STALE_AFTER_MIN_CORE); findings aggregated per flow + method class
*&            | + code + run date with count, amount per currency and the first PAYOUT_EXAMPLES payments
*&            | (PARAM4 retired); PAY_STATUS_LAG (b) from the version marker PAY_STATUS_PENDING (grace
*&            | from its VALID_FROM), (a) per file from the grouped runs, (a) per payment from the
*&            | candidates still ISSUED (bounded by HCK_INFLIGHT_MAX_ROWS).
*& 2026-11-08 | Comments: method classes / house-bank calendars are posting area ZPMC, bank code roles ZBTR
*&            | (were ZCD_HCK_PMCLASS / ZCD_HCK_BTCROLE, customer posting areas); no code change.
*& 2026-11-08 | Exceptions-only worklist (user decision 2026-11-08): reads only the worklist (open payments and
*&            | exceptions); PAY_EXCLUDED retired (it only counted clean payments, which have no row any more);
*&            | ageing by the shared rule ZCL_CD_HCK_PAY_AGEING (the snapshot marks late payments with it); not yet
*&            | snapshotted = entered after the DOCUMENTS watermark (a deleted clean payment is not re-evaluated
*&            | live).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - payments not cleared on the bank statement</p>
"! PARAM1 = factory calendar when the method class / house bank has none (also the calendar of
"! the due dates of payment requests), PARAM2 = look-back days of VALUE_DATE classes of the live
"! evaluation before the first snapshot (default 10), PARAM3 = the same for ISSUE_DATE classes
"! (default 120). Metrics per flow + class (DIM1, e.g. DWIR): PAY_OPEN, AGE_OLDEST (level),
"! OVER_WARN_CNT, OVER_CRIT_CNT, OVER_WARN_AMT / OVER_CRIT_AMT (DIM2 currency, never summed across
"! currencies), PAY_INCONSISTENT, PAY_UNDETERMINED, PAY_STATUS_LAG, PAY_NOT_SNAPSHOT. Warning /
"! critical = AMBER / RED of AGE_OLDEST in ZCD_HCK_THRESH.
CLASS zcl_cd_hck_c_inflight DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS:
      BEGIN OF gc_metric,
        open         TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PAY_OPEN',
        age_oldest   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'AGE_OLDEST',
        warn_count   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OVER_WARN_CNT',
        crit_count   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OVER_CRIT_CNT',
        warn_amount  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OVER_WARN_AMT',
        crit_amount  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OVER_CRIT_AMT',
        inconsistent TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PAY_INCONSISTENT',
        "! Payments whose clearing cannot be determined (mandatory evidence unavailable): in flight
        undetermined TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PAY_UNDETERMINED',
        "! Payments in flight whose DPAYH status did not follow the bank evidence / ACK in time
        status_lag   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PAY_STATUS_LAG',
        "! Payment documents the outcome snapshot has not reached yet: evaluated live in this run
        not_snapshot TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PAY_NOT_SNAPSHOT',
      END OF gc_metric.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_amount,
        currency TYPE zif_cd_ops_types=>ty_currency,
        amount   TYPE zif_cd_ops_types=>ty_amount,
      END OF ty_amount.
    TYPES tt_amount TYPE SORTED TABLE OF ty_amount WITH UNIQUE KEY currency.

    "! An example payment of a finding (oldest first: reference date, then payment document)
    TYPES:
      BEGIN OF ty_example,
        ref_date TYPE d,
        doc1r    TYPE zif_cd_hck_runtime_types=>ty_docno,
        line     TYPE string,
      END OF ty_example.
    TYPES tt_example TYPE STANDARD TABLE OF ty_example WITH EMPTY KEY.

    "! One aggregated finding: flow + method class, finding code, payment run date
    TYPES:
      BEGIN OF ty_cell,
        key      TYPE zif_cd_hck_runtime_types=>ty_flow_class,
        day      TYPE d,
        code     TYPE zif_cd_ops_types=>ty_check_code,
        severity TYPE zif_cd_ops_types=>ty_severity,
        payments TYPE i,
        "! Late payments: critical ones and the oldest age
        crit     TYPE i,
        oldest   TYPE i,
        amounts  TYPE tt_amount,
        examples TYPE tt_example,
      END OF ty_cell.
    TYPES tt_cell TYPE HASHED TABLE OF ty_cell WITH UNIQUE KEY key day code.

    "! Counts per flow + method class (metrics)
    TYPES:
      BEGIN OF ty_stat,
        key          TYPE zif_cd_hck_runtime_types=>ty_flow_class,
        open         TYPE i,
        oldest       TYPE i,
        warn         TYPE i,
        crit         TYPE i,
        inconsistent TYPE i,
        undetermined TYPE i,
        lag          TYPE i,
        live         TYPE i,
      END OF ty_stat.
    TYPES tt_stat TYPE HASHED TABLE OF ty_stat WITH UNIQUE KEY key.

    TYPES:
      BEGIN OF ty_late_amount,
        key      TYPE zif_cd_hck_runtime_types=>ty_flow_class,
        currency TYPE zif_cd_ops_types=>ty_currency,
        warn     TYPE zif_cd_hck_types=>ty_value,
        crit     TYPE zif_cd_hck_types=>ty_value,
      END OF ty_late_amount.
    TYPES tt_late_amount TYPE HASHED TABLE OF ty_late_amount WITH UNIQUE KEY key currency.

    "! Oldest bank ACK of a payment (configured ACK source)
    TYPES:
      BEGIN OF ty_ack,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
        date  TYPE d,
        time  TYPE t,
        text  TYPE string,
      END OF ty_ack.
    TYPES tt_ack TYPE HASHED TABLE OF ty_ack WITH UNIQUE KEY doc1r.

    TYPES tt_iface_id TYPE SORTED TABLE OF zif_cd_fmon_types=>ty_iface_id WITH UNIQUE KEY table_line.

    "! Link of a payment to the file of its payment run (file-level ACK): usable once the FMON source
    "! has GROUP_FIELDS that are DPAYH payment run fields and file-level interfaces exist
    TYPES:
      BEGIN OF ty_file_link,
        usable TYPE abap_bool,
        "! DPAYH payment run field of each GROUP_FIELDS position, in the configured order
        fields TYPE string_table,
        "! Interfaces whose files of the group are read (the source's, else outbound + ACK level FILE)
        ifaces TYPE tt_iface_id,
      END OF ty_file_link.

    "! ACK of a generation group: OPEN = a latest generation without ACK (FMON's finding, not judged)
    TYPES:
      BEGIN OF ty_group_time,
        gen_group TYPE zif_cd_fmon_types=>ty_file_ref,
        ack_at    TYPE timestampl,
        open      TYPE abap_bool,
        text      TYPE string,
      END OF ty_group_time.
    TYPES tt_group_time TYPE HASHED TABLE OF ty_group_time WITH UNIQUE KEY gen_group.

    "! Payments in flight still ISSUED of a run acknowledged per file (versioned groups and live payments)
    TYPES:
      BEGIN OF ty_run_part,
        key       TYPE zif_cd_hck_runtime_types=>ty_flow_class,
        laufd     TYPE d,
        laufi     TYPE c LENGTH 6,
        hbkid     TYPE zif_cd_hck_runtime_types=>ty_hbkid,
        currency  TYPE zif_cd_ops_types=>ty_currency,
        payments  TYPE i,
        amount    TYPE zif_cd_ops_types=>ty_amount,
        "! A live payment (its example line is written here)
        payment   TYPE zif_cd_hck_runtime_types=>ty_issued_payment,
        status    TYPE string,
        gen_group TYPE zif_cd_fmon_types=>ty_file_ref,
      END OF ty_run_part.
    TYPES tt_run_part TYPE STANDARD TABLE OF ty_run_part WITH EMPTY KEY.

    DATA mo_outcome TYPE REF TO zif_cd_ops_pay_outcome.
    DATA mo_dao TYPE REF TO zif_cd_ops_pay_outcome_dao.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.
    DATA mt_classes TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    "! Calendar overrides per house bank (posting area ZPMC entries with HBKID)
    DATA mt_banks TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    DATA mt_methods TYPE zif_cd_ops_payout_types=>tt_method.
    DATA mt_rules TYPE zif_cd_hck_runtime_types=>tt_clr_rule.
    DATA mt_watched TYPE zif_cd_ops_payout_types=>tt_flow_class.
    "! The shared ageing rule (calendars, AGE_OLDEST limits) - the worklist judges lateness with it too
    DATA mo_ageing TYPE REF TO zcl_cd_hck_pay_ageing.
    DATA mt_cells TYPE tt_cell.
    DATA mt_stats TYPE tt_stat.
    DATA mt_late_amounts TYPE tt_late_amount.
    DATA mt_run_parts TYPE tt_run_part.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.
    DATA ms_link TYPE ty_file_link.
    DATA mt_file_classes TYPE string_table.
    DATA mt_ack_open TYPE string_table.
    DATA mt_no_ack TYPE string_table.
    DATA mv_calendar TYPE zif_cd_hck_types=>ty_calendar.
    DATA mv_cap TYPE i.
    DATA mv_examples TYPE i.
    DATA mv_today TYPE d.
    DATA mv_value_from TYPE d.
    DATA mv_issue_from TYPE d.
    DATA mv_grace TYPE i.
    "! Instant before which a status evidence / ACK is overdue (now - grace)
    DATA mv_limit TYPE timestampl.
    DATA mv_no_valut TYPE i.
    DATA mv_ambiguous_live TYPE i.
    DATA mv_partial TYPE abap_bool.

    METHODS load_configuration
      CHANGING
        cs_result TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.

    "! Parameters of the run: examples, status-lag grace and ACK lists, windows, AGE_OLDEST limits
    METHODS read_settings
      IMPORTING
        is_context    TYPE zif_cd_hck_types=>ty_context
        it_thresholds TYPE zif_cd_hck_types=>tt_threshold.

    "! The snapshot lag: stale (or never run) = PAY_SNAPSHOT_STALE and evidence PARTIAL; returns the
    "! DOCUMENTS watermark (payment documents entered after it are not in the worklist yet), initial
    "! when none
    METHODS check_snapshot
      IMPORTING
        is_context          TYPE zif_cd_hck_types=>ty_context
      RETURNING
        VALUE(rs_watermark) TYPE zif_cd_ops_payout_types=>ty_watermark.

    "! Query of the aggregate reads: the watched methods, outcomes counted however old
    METHODS base_query
      RETURNING
        VALUE(rs_query) TYPE zif_cd_ops_payout_types=>ty_group_query.

    "! Every current worklist row of a payment grouped on HANA: aged, listed, lagging
    METHODS read_aggregate.

    "! Payment documents not yet snapshotted (entered after the DOCUMENTS watermark) and AMBIGUOUS-only
    "! payments: evaluated live, bounded
    METHODS read_live
      IMPORTING
        is_watermark TYPE zif_cd_ops_payout_types=>ty_watermark.

    "! (a) per payment: the versioned candidates still ISSUED and the live ones - bank ACK older than
    "! the grace; (a) per file: the runs of the classes acknowledged per file
    METHODS read_ack_lags
      IMPORTING
        it_live   TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        it_status TYPE zcl_cd_hck_ev_support=>tt_pay_status.

    "! The first PAYOUT_EXAMPLES payments of every finding from the current versions (one read)
    METHODS read_examples.

    "! A group of payments in flight aged: counts, late cell; the age is returned
    METHODS add_open
      IMPORTING
        iv_key         TYPE zif_cd_hck_runtime_types=>ty_flow_class
        iv_day         TYPE d
        iv_ref_date    TYPE d
        iv_no_valut    TYPE abap_bool
        iv_calendar    TYPE zif_cd_hck_types=>ty_calendar
        iv_payments    TYPE i
        iv_amount      TYPE zif_cd_ops_types=>ty_amount
        iv_currency    TYPE zif_cd_ops_types=>ty_currency
      RETURNING
        VALUE(rv_age)  TYPE i.

    METHODS add_cell
      IMPORTING
        iv_key      TYPE zif_cd_hck_runtime_types=>ty_flow_class
        iv_day      TYPE d
        iv_code     TYPE zif_cd_ops_types=>ty_check_code
        iv_severity TYPE zif_cd_ops_types=>ty_severity
        iv_payments TYPE i
        iv_amount   TYPE zif_cd_ops_types=>ty_amount
        iv_currency TYPE zif_cd_ops_types=>ty_currency.

    "! An example of an existing cell, kept when it is among the first PAYOUT_EXAMPLES (oldest first)
    METHODS add_example
      IMPORTING
        iv_key      TYPE zif_cd_hck_runtime_types=>ty_flow_class
        iv_day      TYPE d
        iv_code     TYPE zif_cd_ops_types=>ty_check_code
        iv_ref_date TYPE d
        iv_doc1r    TYPE zif_cd_hck_runtime_types=>ty_docno
        iv_line     TYPE string.

    METHODS stat
      IMPORTING
        iv_key         TYPE zif_cd_hck_runtime_types=>ty_flow_class
      RETURNING
        VALUE(rr_stat) TYPE REF TO ty_stat.

    "! Flow + method class of a method and flow indicator; blank when the class is not watched
    METHODS key_of
      IMPORTING
        iv_pymet      TYPE zif_cd_hck_runtime_types=>ty_pymet
        iv_xeinz      TYPE abap_bool
      RETURNING
        VALUE(rv_key) TYPE zif_cd_hck_runtime_types=>ty_flow_class.

    "! Detail line of a payment: document, method, run date, aged-from date, age, amount
    METHODS payment_line
      IMPORTING
        iv_doc1r       TYPE zif_cd_hck_runtime_types=>ty_docno
        iv_pymet       TYPE zif_cd_hck_runtime_types=>ty_pymet
        iv_laufd       TYPE d
        iv_ref_date    TYPE d
        iv_no_valut    TYPE abap_bool
        iv_age         TYPE i
        iv_amount      TYPE zif_cd_ops_types=>ty_amount
        iv_currency    TYPE zif_cd_ops_types=>ty_currency
      RETURNING
        VALUE(rv_line) TYPE string.

    METHODS report
      CHANGING
        cs_result TYPE zif_cd_hck_types=>ty_check_result.

    "! One finding per cell: count, amount per currency, examples, drill-down
    METHODS report_cells
      CHANGING
        cs_result TYPE zif_cd_hck_types=>ty_check_result.

    "! Oldest bank ACK (not a NACK, with a date) of each payment from the configured payment-level
    "! ACK source TRACE_SRC_ACK (the payment trace's link: KEY = clearing reference; DATE / TIME)
    METHODS acks_of
      IMPORTING
        it_payments    TYPE zif_cd_hck_runtime_types=>tt_issued_payment
      EXPORTING
        ev_has_time    TYPE abap_bool
      RETURNING
        VALUE(rt_acks) TYPE tt_ack.

    "! File-level ACK link of the run (FMON source HCK_PAY_ACK_FILE_SRC: GROUP_FIELDS -> DPAYH run
    "! fields; interfaces). Not usable: one INFLIGHT_CONFIG W per run (the case is not evaluable)
    METHODS file_ack_link
      RETURNING
        VALUE(rs_link) TYPE ty_file_link.

    "! The one finding of a file-level link that is not usable
    METHODS file_ack_unusable
      IMPORTING
        iv_message TYPE string.

    "! ACK of the files of generation groups: one FMON read for all groups, the latest generation of
    "! each interface of a group (a replaced file never counts) must have its ACK; the latest of these
    "! ACKs counts. A group without entry or OPEN = no ACK (FMON's finding)
    METHODS group_acks
      RETURNING
        VALUE(rt_acks) TYPE tt_group_time.

    "! Value of a DPAYH payment run field, unformatted as FMON reads a source field
    CLASS-METHODS run_value
      IMPORTING
        iv_laufd        TYPE d
        iv_laufi        TYPE clike
        iv_hbkid        TYPE clike
        iv_field        TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.

    "! The grace period after the evidence has passed: the evidence day without time counts from
    "! its end (the next day, 00:00), a time from that instant
    CLASS-METHODS lag_due
      IMPORTING
        iv_date       TYPE d
        iv_time       TYPE t
        iv_has_time   TYPE abap_bool
        iv_limit      TYPE timestampl
      RETURNING
        VALUE(rv_due) TYPE abap_bool.

    "! Read capped: listed once per read (findings of the reads are collected in MT_FINDINGS)
    METHODS capped
      IMPORTING
        iv_table TYPE clike.

ENDCLASS.



CLASS zcl_cd_hck_c_inflight IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    CLEAR: mt_classes, mt_banks, mt_methods, mt_rules, mt_watched, mt_cells, mt_stats, mt_late_amounts,
           mt_run_parts, mt_findings, ms_link, mv_no_valut, mv_ambiguous_live, mv_partial, mo_ageing.
    ms_def = is_def.
    mv_today = is_context-now_date.
    mv_calendar = to_upper( condense( is_def-param1 ) ).
    mv_cap = zcl_cd_hck_param=>row_cap( iv_name    = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows
                                        iv_default = zif_cd_hck_runtime_types=>gc_param_default-inflight_max_rows
                                        iv_ceiling = zif_cd_hck_runtime_types=>gc_max_inflight_rows ).
    " The canonical evaluator (shared with the payment trace and the transactions dashboard) and the
    " current versions it wrote (5-minute snapshot)
    mo_outcome = zcl_cd_ops_factory=>get_pay_outcome( ).
    mo_dao     = zcl_cd_ops_factory=>get_pay_outcome_dao( ).
    load_configuration( CHANGING cs_result = rs_result ).
    read_settings( is_context    = is_context
                   it_thresholds = it_thresholds ).
    DATA(ls_watermark) = check_snapshot( is_context ).

    " Every payment not yet final from the snapshot (HANA groups), the rest live (bounded)
    read_aggregate( ).
    read_live( ls_watermark ).
    read_examples( ).

    INSERT LINES OF mt_findings INTO TABLE rs_result-findings.
    report( CHANGING cs_result = rs_result ).
    " What the persisted verdict says about the run of this check (ZCD_HCK_RESULT)
    IF line_exists( rs_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-read_capped ] ).
      rs_result-completion = zif_cd_hck_types=>gc_completion-partial.
    ENDIF.
    IF mv_partial = abap_true.
      rs_result-evidence = zif_cd_hck_types=>gc_evidence-partial.
    ENDIF.
  ENDMETHOD.


  METHOD load_configuration.
    " Method classes, house bank calendars, rules: the evaluator's configuration (one copy)
    DATA(ls_config) = mo_outcome->load( iv_context  = ms_def-check_id
                                        iv_max_rows = mv_cap ).
    mt_classes = ls_config-classes.
    mt_banks   = ls_config-banks.
    mt_rules   = ls_config-rules.
    mt_methods = ls_config-methods.
    mt_watched = ls_config-watched.
    INSERT LINES OF ls_config-findings INTO TABLE mt_findings.
    DATA(lv_calendar_missing) = abap_false.
    LOOP AT mt_classes TRANSPORTING NO FIELDS
         WHERE age_basis <> zif_cd_hck_runtime_types=>gc_age_basis-issue_date AND calendar IS INITIAL.
      lv_calendar_missing = abap_true.
    ENDLOOP.
    IF mv_calendar IS INITIAL AND lv_calendar_missing = abap_true.
      INSERT VALUE #( object_key = |{ ms_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-inflight_config }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                      severity   = zif_cd_ops_types=>gc_severity-warning
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-no_calendar
                                                          iv_v1    = ms_def-check_id ) ) INTO TABLE cs_result-findings.
    ENDIF.
  ENDMETHOD.


  METHOD read_settings.
    DATA lv_now TYPE timestamp.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    mv_examples = nmax( val1 = 1
                        val2 = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                           iv_name    = zif_cd_ops_payout_types=>gc_param-examples
                                                           iv_default = zif_cd_ops_payout_types=>gc_param_default-examples ) ).
    " Look-back windows of the live evaluation before the snapshot's first run
    DATA(lv_days) = zcl_cd_hck_param=>int( iv_value   = ms_def-param2
                                           iv_default = zif_cd_hck_runtime_types=>gc_check_default-inflight_days ).
    DATA(lv_issue_days) = zcl_cd_hck_param=>int( iv_value   = ms_def-param3
                                                 iv_default = zif_cd_hck_runtime_types=>gc_check_default-cheque_days ).
    mv_value_from = mv_today - nmax( val1 = 1 val2 = lv_days ).
    mv_issue_from = mv_today - nmax( val1 = 1 val2 = lv_issue_days ).
    " Status lag: grace after the bank evidence / ACK, statuses that must have changed, ACK level
    mv_grace = nmax( val1 = 0
                     val2 = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                        iv_name    = zif_cd_hck_runtime_types=>gc_param-status_lag_min
                                                        iv_default = zif_cd_hck_runtime_types=>gc_param_default-status_lag_min ) ).
    CONVERT DATE is_context-now_date TIME is_context-now_time INTO TIME STAMP lv_now TIME ZONE sy-zonlo.
    mv_limit = cl_abap_tstmp=>subtractsecs( tstmp = lv_now
                                            secs  = mv_grace * 60 ).
    mt_file_classes = zcl_cd_hck_ev_support=>tokens(
                        lo_params->get_param( iv_name    = zif_cd_hck_runtime_types=>gc_param-ack_file_classes
                                              iv_default = zif_cd_hck_runtime_types=>gc_param_default-ack_file_classes ) ).
    mt_ack_open = zcl_cd_hck_ev_support=>tokens(
                    lo_params->get_param( iv_name    = zif_cd_hck_runtime_types=>gc_param-status_ack_open
                                          iv_default = zif_cd_hck_runtime_types=>gc_param_default-status_ack_open ) ).
    mt_no_ack = zcl_cd_hck_ev_support=>tokens( lo_params->get_param( zif_cd_ops_trace_types=>gc_param-no_ack_methods ) ).
    " The file-level link is checked once per run as soon as a watched class is acknowledged per file
    LOOP AT mt_file_classes ASSIGNING FIELD-SYMBOL(<lv_file_class>).
      IF line_exists( mt_watched[ table_line = CONV zif_cd_hck_runtime_types=>ty_flow_class( <lv_file_class> ) ] ).
        ms_link = file_ack_link( ).
        EXIT.
      ENDIF.
    ENDLOOP.
    " Ageing: AGE_OLDEST limits once per watched flow + class (a key without limits is not judged -
    " warning), calendars as day tables - the one rule the worklist uses for late payments too
    mo_ageing = NEW #( it_classes    = mt_classes
                       it_banks      = mt_banks
                       it_watched    = mt_watched
                       iv_calendar   = mv_calendar
                       it_thresholds = it_thresholds
                       iv_today      = mv_today ).
  ENDMETHOD.


  METHOD check_snapshot.
    DATA lv_now TYPE timestampl.
    DATA(lt_watermarks) = mo_dao->get_watermarks( ).
    rs_watermark = VALUE #( lt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ] OPTIONAL ).
    CONVERT DATE is_context-now_date TIME is_context-now_time INTO TIME STAMP lv_now TIME ZONE sy-zonlo.
    DATA(ls_lag) = zcl_cd_ops_pay_snapshot=>lag( it_watermarks = lt_watermarks
                                                 iv_now        = lv_now ).
    DATA(lv_limit) = zcl_cd_ops_util=>param_int(
                       io_params  = zcl_cd_ops_factory=>get_params( )
                       iv_name    = CONV #( |{ zif_cd_ops_types=>gc_param_prefix-stale_after_min }| &&
                                            |{ zif_cd_ops_types=>gc_pe_area-core }| )
                       iv_default = zif_cd_ops_payout_types=>gc_param_default-stale_after_min ).
    IF ls_lag-known = abap_true AND ls_lag-minutes <= lv_limit.
      RETURN.
    ENDIF.
    " Stale or never run: the counts may miss the newest evidence - said, never green on stale data
    mv_partial = abap_true.
    INSERT VALUE #( object_key = |{ ms_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-snapshot_stale }|
                    check_code = zif_cd_hck_runtime_types=>gc_code-snapshot_stale
                    severity   = zif_cd_ops_types=>gc_severity-warning
                    action     = zif_cd_ops_types=>gc_action-notify
                    message    = COND #( WHEN ls_lag-known = abap_true
                                         THEN zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-snapshot_lag
                                                                     iv_v1    = ls_lag-minutes
                                                                     iv_v2    = lv_limit
                                                                     iv_v3    = ls_lag-source
                                                                     iv_v4    = |{ ls_lag-current_to TIMESTAMP = ISO }| )
                                         ELSE zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-snapshot_never
                                                                     iv_v1    = ms_def-check_id ) ) )
           INTO TABLE mt_findings.
  ENDMETHOD.


  METHOD base_query.
    LOOP AT mt_methods ASSIGNING FIELD-SYMBOL(<ls_method>).
      INSERT <ls_method>-pymet INTO TABLE rs_query-methods.
    ENDLOOP.
    rs_query-all_ages = VALUE #( sign   = zif_cd_ops_types=>gc_range-sign_include
                                 option = zif_cd_ops_types=>gc_range-option_equal
                                 ( low = zif_cd_ops_payout_types=>gc_outcome-in_flight )
                                 ( low = zif_cd_ops_payout_types=>gc_outcome-undetermined )
                                 ( low = zif_cd_ops_payout_types=>gc_outcome-inconsistent ) ).
    " No final outcome unless the caller asks (a run date never reached)
    rs_query-final_from = zif_cd_ops_payout_types=>gc_no_final_from.
    rs_query-lag_limit  = mv_limit.
  ENDMETHOD.


  METHOD read_aggregate.
    " The worklist holds only payments not final (open and exceptions, 2026-11-08): no clean payment
    " is counted any more (PAY_EXCLUDED retired)
    DATA(ls_query) = base_query( ).
    LOOP AT mo_dao->get_outcome_groups( ls_query ) ASSIGNING FIELD-SYMBOL(<ls_group>).
      DATA(lv_key) = key_of( iv_pymet = <ls_group>-pymet iv_xeinz = <ls_group>-xeinz ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.
      CASE <ls_group>-outcome.
        WHEN zif_cd_ops_payout_types=>gc_outcome-in_flight OR zif_cd_ops_payout_types=>gc_outcome-undetermined.
          " In flight (also undetermined): aged from the value date (run date when missing) or the run date
          DATA(lv_ref_date) = COND d( WHEN mo_ageing->is_issue_basis( lv_key ) = abap_true OR <ls_group>-valut IS INITIAL
                                        THEN <ls_group>-laufd ELSE <ls_group>-valut ).
          add_open( iv_key      = lv_key
                    iv_day      = <ls_group>-laufd
                    iv_ref_date = lv_ref_date
                    iv_no_valut = xsdbool( mo_ageing->is_issue_basis( lv_key ) = abap_false AND <ls_group>-valut IS INITIAL )
                    iv_calendar = mo_ageing->calendar_of( iv_key = lv_key iv_hbkid = <ls_group>-hbkid )
                    iv_payments = <ls_group>-payments
                    iv_amount   = <ls_group>-amount
                    iv_currency = <ls_group>-currency ).
          IF <ls_group>-outcome = zif_cd_ops_payout_types=>gc_outcome-undetermined.
            DATA(lr_stat) = stat( lv_key ).
            lr_stat->undetermined = lr_stat->undetermined + <ls_group>-payments.
            add_cell( iv_key      = lv_key
                      iv_day      = <ls_group>-laufd
                      iv_code     = zif_cd_hck_runtime_types=>gc_code-undetermined
                      iv_severity = zif_cd_ops_types=>gc_severity-warning
                      iv_payments = <ls_group>-payments
                      iv_amount   = <ls_group>-amount
                      iv_currency = <ls_group>-currency ).
          ELSEIF <ls_group>-finding = zif_cd_ops_payout_types=>gc_code-status_pending.
            " (b) The bank evidence decides, the status job has not followed: due after the grace
            IF <ls_group>-due = abap_true.
              add_cell( iv_key      = lv_key
                        iv_day      = <ls_group>-laufd
                        iv_code     = zif_cd_hck_runtime_types=>gc_code-status_lag
                        iv_severity = zif_cd_ops_types=>gc_severity-warning
                        iv_payments = <ls_group>-payments
                        iv_amount   = <ls_group>-amount
                        iv_currency = <ls_group>-currency ).
            ENDIF.
            CONTINUE.
          ENDIF.
          " (a) per file: a run of a class acknowledged per file with payments still ISSUED
          IF ms_link-usable = abap_true
             AND line_exists( mt_file_classes[ table_line = CONV string( lv_key ) ] )
             AND line_exists( mt_ack_open[ table_line = to_upper( condense( CONV string( <ls_group>-pay_status ) ) ) ] )
             AND NOT line_exists( mt_no_ack[ table_line = to_upper( CONV string( <ls_group>-pymet ) ) ] ).
            INSERT VALUE #( key      = lv_key
                            laufd    = <ls_group>-laufd
                            laufi    = <ls_group>-laufi
                            hbkid    = <ls_group>-hbkid
                            currency = <ls_group>-currency
                            payments = <ls_group>-payments
                            amount   = <ls_group>-amount
                            status   = condense( CONV string( <ls_group>-pay_status ) ) ) INTO TABLE mt_run_parts.
          ENDIF.
        WHEN zif_cd_ops_payout_types=>gc_outcome-inconsistent.
          " Inconsistent / anomalous: listed under the payment's primary finding, not aged
          lr_stat = stat( lv_key ).
          lr_stat->inconsistent = lr_stat->inconsistent + <ls_group>-payments.
          add_cell( iv_key      = lv_key
                    iv_day      = <ls_group>-laufd
                    iv_code     = COND #( WHEN <ls_group>-finding IS INITIAL
                                          THEN zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                          ELSE <ls_group>-finding )
                    iv_severity = COND #( WHEN <ls_group>-severity IS INITIAL
                                          THEN zif_cd_ops_types=>gc_severity-error
                                          ELSE <ls_group>-severity )
                    iv_payments = <ls_group>-payments
                    iv_amount   = <ls_group>-amount
                    iv_currency = <ls_group>-currency ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_live.
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA lt_latest TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA lt_open TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA lt_ack_due TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA lt_methods TYPE zif_cd_hck_runtime_types=>tt_pymet.
    LOOP AT mt_methods ASSIGNING FIELD-SYMBOL(<ls_method>).
      INSERT <ls_method>-pymet INTO TABLE lt_methods.
    ENDLOOP.
    " Not reached by the snapshot: payment documents entered after the DOCUMENTS watermark (a clean
    " payment has no worklist row, so "no row" no longer means "not reached" - 2026-11-08); before the
    " first snapshot run the runs of the look-back windows; bounded by HCK_INFLIGHT_MAX_ROWS as before
    DATA(lt_new) = mo_dao->get_unsnapshotted( it_methods = lt_methods
                                              is_after   = is_watermark
                                              iv_from    = COND #( WHEN mv_value_from < mv_issue_from
                                                                   THEN mv_value_from ELSE mv_issue_from )
                                              iv_max     = mv_cap ).
    IF lines( lt_new ) >= mv_cap.
      capped( zif_cd_ops_payout_types=>gc_table-outcome ).
    ENDIF.
    DATA(lt_ambiguous) = mo_dao->get_ambiguous_only( is_query = base_query( )
                                                     iv_max   = mv_cap ).
    IF lines( lt_ambiguous ) >= mv_cap.
      capped( zif_cd_ops_payout_types=>gc_table-outcome ).
    ENDIF.
    lt_docno = lt_new.
    INSERT LINES OF lt_ambiguous INTO TABLE lt_docno.
    IF lt_docno IS INITIAL.
      read_ack_lags( it_live = VALUE #( ) it_status = VALUE #( ) ).
      RETURN.
    ENDIF.

    " The latest payment run of each document, classified and judged by the evaluator (as the snapshot)
    DATA(lt_runs) = zcl_cd_hck_factory=>get_runtime_dao( )->get_issued_payments_by_doc(
                      it_docno    = lt_docno
                      iv_max_rows = nmax( val1 = mv_cap val2 = lines( lt_docno ) ) ).
    SORT lt_runs BY doc1r ASCENDING laufd DESCENDING laufi DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_runs COMPARING doc1r.
    INSERT LINES OF lt_runs INTO TABLE lt_latest.
    DATA(lt_payments) = mo_outcome->classify( lt_latest ).
    DATA(ls_evaluation) = mo_outcome->evaluate( lt_payments ).
    INSERT LINES OF ls_evaluation-findings INTO TABLE mt_findings.
    IF ls_evaluation-evidence_partial = abap_true.
      mv_partial = abap_true.
    ENDIF.
    " The live payment status of the payments in flight (one shared read of the run)
    LOOP AT lt_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF ls_evaluation-verdicts[ sy-tabix ]-status = zif_cd_ops_payout_types=>gc_status-open.
        INSERT <ls_payment> INTO TABLE lt_open.
      ENDIF.
    ENDLOOP.
    DATA(lt_status) = VALUE zcl_cd_hck_ev_support=>tt_pay_status( ).
    IF lt_open IS NOT INITIAL.
      lt_status = zcl_cd_hck_ev_support=>status_of( lt_open ).
    ENDIF.
    CLEAR lt_open.

    LOOP AT lt_payments ASSIGNING <ls_payment>.
      DATA(ls_verdict) = ls_evaluation-verdicts[ sy-tabix ].
      DATA(lv_key) = CONV zif_cd_hck_runtime_types=>ty_flow_class( |{ <ls_payment>-flow }{ <ls_payment>-class }| ).
      DATA(lr_stat) = stat( lv_key ).
      IF line_exists( lt_new[ table_line = <ls_payment>-doc1r ] ).
        lr_stat->live = lr_stat->live + 1.
      ELSE.
        mv_ambiguous_live = mv_ambiguous_live + 1.
      ENDIF.
      DATA(lv_amount) = CONV zif_cd_ops_types=>ty_amount( abs( <ls_payment>-amount ) ).
      " Every listing of the payment under its code (inconsistency, anomaly, undetermined)
      LOOP AT ls_verdict-listings ASSIGNING FIELD-SYMBOL(<ls_listing>).
        add_cell( iv_key      = lv_key
                  iv_day      = <ls_payment>-laufd
                  iv_code     = <ls_listing>-code
                  iv_severity = <ls_listing>-severity
                  iv_payments = 1
                  iv_amount   = lv_amount
                  iv_currency = <ls_payment>-currency ).
        add_example( iv_key      = lv_key
                     iv_day      = <ls_payment>-laufd
                     iv_code     = <ls_listing>-code
                     iv_ref_date = <ls_payment>-laufd
                     iv_doc1r    = <ls_payment>-doc1r
                     iv_line     = <ls_listing>-line ).
      ENDLOOP.
      CASE ls_verdict-status.
        WHEN zif_cd_ops_payout_types=>gc_status-open.
          " In flight (also undetermined): aged below
        WHEN zif_cd_ops_payout_types=>gc_status-inconsistent.
          lr_stat->inconsistent = lr_stat->inconsistent + 1.
          CONTINUE.
        WHEN OTHERS.
          " Reversed: not in flight
          CONTINUE.
      ENDCASE.
      IF ls_verdict-outcome = zif_cd_ops_payout_types=>gc_outcome-undetermined.
        lr_stat->undetermined = lr_stat->undetermined + 1.
      ENDIF.
      DATA(lv_no_valut) = xsdbool( mo_ageing->is_issue_basis( lv_key ) = abap_false AND <ls_payment>-valut IS INITIAL ).
      DATA(lv_ref_date) = COND d( WHEN mo_ageing->is_issue_basis( lv_key ) = abap_true OR <ls_payment>-valut IS INITIAL
                                    THEN <ls_payment>-laufd ELSE <ls_payment>-valut ).
      DATA(lv_age) = add_open( iv_key      = lv_key
                               iv_day      = <ls_payment>-laufd
                               iv_ref_date = lv_ref_date
                               iv_no_valut = lv_no_valut
                               iv_calendar = mo_ageing->calendar_of( iv_key = lv_key iv_hbkid = <ls_payment>-hbkid )
                               iv_payments = 1
                               iv_amount   = lv_amount
                               iv_currency = <ls_payment>-currency ).
      add_example( iv_key      = lv_key
                   iv_day      = <ls_payment>-laufd
                   iv_code     = zif_cd_hck_runtime_types=>gc_code-payment_not_clear
                   iv_ref_date = lv_ref_date
                   iv_doc1r    = <ls_payment>-doc1r
                   iv_line     = payment_line( iv_doc1r    = <ls_payment>-doc1r
                                               iv_pymet    = <ls_payment>-pymet
                                               iv_laufd    = <ls_payment>-laufd
                                               iv_ref_date = lv_ref_date
                                               iv_no_valut = lv_no_valut
                                               iv_age      = lv_age
                                               iv_amount   = lv_amount
                                               iv_currency = <ls_payment>-currency ) ).
      IF ls_verdict-status_pending = abap_true.
        " (b) The evidence day (newest statement line; the run date when the kind has no date) + grace
        DATA(lv_since) = COND d( WHEN ls_verdict-evidence_date IS NOT INITIAL THEN ls_verdict-evidence_date
                                 ELSE <ls_payment>-laufd ).
        IF lag_due( iv_date = lv_since iv_time = VALUE #( ) iv_has_time = abap_false iv_limit = mv_limit ) = abap_true.
          add_cell( iv_key      = lv_key
                    iv_day      = <ls_payment>-laufd
                    iv_code     = zif_cd_hck_runtime_types=>gc_code-status_lag
                    iv_severity = zif_cd_ops_types=>gc_severity-warning
                    iv_payments = 1
                    iv_amount   = lv_amount
                    iv_currency = <ls_payment>-currency ).
          add_example( iv_key      = lv_key
                       iv_day      = <ls_payment>-laufd
                       iv_code     = zif_cd_hck_runtime_types=>gc_code-status_lag
                       iv_ref_date = lv_ref_date
                       iv_doc1r    = <ls_payment>-doc1r
                       iv_line     = |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_bank
                                                               iv_v1    = <ls_payment>-doc1r
                                                               iv_v2    = VALUE #( lt_status[ doc1r = <ls_payment>-doc1r ]-status
                                                                                   OPTIONAL )
                                                               iv_v3    = ls_verdict-purpose
                                                               iv_v4    = |{ lv_since DATE = ISO }| ) } | &&
                                     |{ ls_verdict-evidence_ref }| ).
        ENDIF.
      ELSE.
        INSERT <ls_payment> INTO TABLE lt_open.
      ENDIF.
    ENDLOOP.

    " (a) Live payments in flight whose live status still says ISSUED
    LOOP AT lt_open ASSIGNING <ls_payment>.
      DATA(lv_status) = VALUE #( lt_status[ doc1r = <ls_payment>-doc1r ]-status OPTIONAL ).
      IF lv_status IS INITIAL OR NOT line_exists( mt_ack_open[ table_line = lv_status ] )
         OR line_exists( mt_no_ack[ table_line = to_upper( CONV string( <ls_payment>-pymet ) ) ] ).
        CONTINUE.
      ENDIF.
      lv_key = |{ <ls_payment>-flow }{ <ls_payment>-class }|.
      IF NOT line_exists( mt_file_classes[ table_line = CONV string( lv_key ) ] ).
        INSERT <ls_payment> INTO TABLE lt_ack_due.
      ELSEIF ms_link-usable = abap_true.
        INSERT VALUE #( key      = lv_key
                        laufd    = <ls_payment>-laufd
                        laufi    = <ls_payment>-laufi
                        hbkid    = <ls_payment>-hbkid
                        currency = <ls_payment>-currency
                        payments = 1
                        amount   = abs( <ls_payment>-amount )
                        payment  = <ls_payment>
                        status   = lv_status ) INTO TABLE mt_run_parts.
      ENDIF.
    ENDLOOP.
    read_ack_lags( it_live = lt_ack_due it_status = lt_status ).
  ENDMETHOD.


  METHOD read_ack_lags.
    DATA lt_due TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    " The live status of every candidate (live payments: the shared status read; versioned: the read)
    DATA(lt_due_status) = it_status.
    lt_due = it_live.
    " (a) per payment, versioned: payments in flight of the classes acknowledged per payment whose live
    " status still says ISSUED (one bounded read, oldest run first)
    IF mt_ack_open IS NOT INITIAL.
      DATA(ls_query) = base_query( ).
      CLEAR ls_query-methods.
      LOOP AT mt_methods ASSIGNING FIELD-SYMBOL(<ls_method>).
        IF NOT line_exists( mt_file_classes[ table_line = |{ <ls_method>-flow }{ <ls_method>-class }| ] )
           AND NOT line_exists( mt_no_ack[ table_line = to_upper( CONV string( <ls_method>-pymet ) ) ] ).
          INSERT <ls_method>-pymet INTO TABLE ls_query-methods.
        ENDIF.
      ENDLOOP.
      ls_query-all_ages = VALUE #( sign   = zif_cd_ops_types=>gc_range-sign_include
                                   option = zif_cd_ops_types=>gc_range-option_equal
                                   ( low = zif_cd_ops_payout_types=>gc_outcome-in_flight )
                                   ( low = zif_cd_ops_payout_types=>gc_outcome-undetermined ) ).
      ls_query-findings = VALUE #( ( sign   = zif_cd_ops_types=>gc_range-sign_exclude
                                     option = zif_cd_ops_types=>gc_range-option_equal
                                     low    = zif_cd_ops_payout_types=>gc_code-status_pending ) ).
      ls_query-statuses = VALUE #( FOR lv_open IN mt_ack_open ( sign   = zif_cd_ops_types=>gc_range-sign_include
                                                                option = zif_cd_ops_types=>gc_range-option_equal
                                                                low    = lv_open ) ).
      DATA(lt_rows) = COND zif_cd_ops_payout_types=>tt_outcome_example(
                        WHEN ls_query-methods IS NOT INITIAL
                        THEN mo_dao->get_outcome_rows( is_query = ls_query iv_max = mv_cap ) ).
      IF lines( lt_rows ) >= mv_cap.
        capped( zif_cd_ops_payout_types=>gc_table-outcome ).
      ENDIF.
      LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
        DATA(lv_key) = key_of( iv_pymet = <ls_row>-pymet iv_xeinz = <ls_row>-xeinz ).
        IF lv_key IS INITIAL OR line_exists( mt_file_classes[ table_line = CONV string( lv_key ) ] ).
          CONTINUE.
        ENDIF.
        INSERT VALUE #( doc1r    = <ls_row>-doc1r
                        laufd    = <ls_row>-laufd
                        laufi    = <ls_row>-laufi
                        bukrs    = <ls_row>-bukrs
                        pymet    = <ls_row>-pymet
                        hbkid    = <ls_row>-hbkid
                        valut    = <ls_row>-valut
                        amount   = <ls_row>-amount
                        currency = <ls_row>-currency
                        xeinz    = <ls_row>-xeinz
                        flow     = lv_key(1)
                        class    = lv_key+1(3) ) INTO TABLE lt_due.
        INSERT VALUE #( doc1r = <ls_row>-doc1r status = condense( CONV string( <ls_row>-pay_status ) ) )
          INTO TABLE lt_due_status.
      ENDLOOP.
    ENDIF.

    " (a) per payment: the bank ACK of the payment older than the grace while the status says ISSUED
    IF lt_due IS NOT INITIAL.
      DATA(lt_acks) = acks_of( EXPORTING it_payments = lt_due
                               IMPORTING ev_has_time = DATA(lv_has_time) ).
      LOOP AT lt_due ASSIGNING FIELD-SYMBOL(<ls_payment>).
        DATA(lv_status) = VALUE #( lt_due_status[ doc1r = <ls_payment>-doc1r ]-status OPTIONAL ).
        READ TABLE lt_acks ASSIGNING FIELD-SYMBOL(<ls_ack>) WITH TABLE KEY doc1r = <ls_payment>-doc1r.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        IF lag_due( iv_date = <ls_ack>-date iv_time = <ls_ack>-time iv_has_time = lv_has_time iv_limit = mv_limit ) = abap_false.
          CONTINUE.
        ENDIF.
        lv_key = |{ <ls_payment>-flow }{ <ls_payment>-class }|.
        add_cell( iv_key      = lv_key
                  iv_day      = <ls_payment>-laufd
                  iv_code     = zif_cd_hck_runtime_types=>gc_code-status_lag
                  iv_severity = zif_cd_ops_types=>gc_severity-warning
                  iv_payments = 1
                  iv_amount   = abs( <ls_payment>-amount )
                  iv_currency = <ls_payment>-currency ).
        add_example( iv_key      = lv_key
                     iv_day      = <ls_payment>-laufd
                     iv_code     = zif_cd_hck_runtime_types=>gc_code-status_lag
                     iv_ref_date = <ls_ack>-date
                     iv_doc1r    = <ls_payment>-doc1r
                     iv_line     = |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_ack
                                                             iv_v1    = <ls_payment>-doc1r
                                                             iv_v2    = lv_status
                                                             iv_v3    = |{ <ls_ack>-date DATE = ISO } { <ls_ack>-time TIME = ISO }| ) } | &&
                                   |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_detail
                                                             iv_v1    = mv_grace
                                                             iv_tail  = <ls_ack>-text ) }| ).
      ENDLOOP.
    ENDIF.

    " (a) per file: the ACK of the file of the payment run older than the grace while still ISSUED
    IF mt_run_parts IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_groups) = group_acks( ).
    LOOP AT mt_run_parts ASSIGNING FIELD-SYMBOL(<ls_part>).
      READ TABLE lt_groups ASSIGNING FIELD-SYMBOL(<ls_group>) WITH TABLE KEY gen_group = <ls_part>-gen_group.
      " No ACK of the file: FMON's own finding (NO_BANK_ACK / missing), never a status lag here
      IF sy-subrc <> 0 OR <ls_group>-open = abap_true OR <ls_group>-ack_at IS INITIAL OR <ls_group>-ack_at > mv_limit.
        CONTINUE.
      ENDIF.
      add_cell( iv_key      = <ls_part>-key
                iv_day      = <ls_part>-laufd
                iv_code     = zif_cd_hck_runtime_types=>gc_code-status_lag
                iv_severity = zif_cd_ops_types=>gc_severity-warning
                iv_payments = <ls_part>-payments
                iv_amount   = <ls_part>-amount
                iv_currency = <ls_part>-currency ).
      IF <ls_part>-payment IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_date) = VALUE d( ).
      DATA(lv_time) = VALUE t( ).
      CONVERT TIME STAMP <ls_group>-ack_at TIME ZONE sy-zonlo INTO DATE lv_date TIME lv_time.
      add_example( iv_key      = <ls_part>-key
                   iv_day      = <ls_part>-laufd
                   iv_code     = zif_cd_hck_runtime_types=>gc_code-status_lag
                   iv_ref_date = lv_date
                   iv_doc1r    = <ls_part>-payment-doc1r
                   iv_line     = |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_file_ack
                                                           iv_v1    = <ls_part>-payment-doc1r
                                                           iv_v2    = <ls_part>-status
                                                           iv_v3    = |{ lv_date DATE = ISO } { lv_time TIME = ISO }| ) } | &&
                                 |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_detail
                                                           iv_v1    = mv_grace
                                                           iv_tail  = <ls_group>-text ) }| ).
    ENDLOOP.
    " Versioned payments of a lagging run: the examples read (one per partition) carries them
    DELETE mt_run_parts WHERE payment IS NOT INITIAL.
    LOOP AT mt_run_parts ASSIGNING <ls_part>.
      READ TABLE lt_groups ASSIGNING <ls_group> WITH TABLE KEY gen_group = <ls_part>-gen_group.
      IF sy-subrc <> 0 OR <ls_group>-open = abap_true OR <ls_group>-ack_at IS INITIAL OR <ls_group>-ack_at > mv_limit.
        <ls_part>-gen_group = space.
      ELSE.
        <ls_part>-status = <ls_group>-text.
      ENDIF.
    ENDLOOP.
    DELETE mt_run_parts WHERE gen_group IS INITIAL.
  ENDMETHOD.


  METHOD read_examples.
    DATA lt_days TYPE zif_cd_ops_payout_types=>tt_date_range.
    LOOP AT mt_cells ASSIGNING FIELD-SYMBOL(<ls_cell>).
      IF NOT line_exists( lt_days[ low = <ls_cell>-day ] ).
        INSERT VALUE #( sign   = zif_cd_ops_types=>gc_range-sign_include
                        option = zif_cd_ops_types=>gc_range-option_equal
                        low    = <ls_cell>-day ) INTO TABLE lt_days.
      ENDIF.
    ENDLOOP.
    IF lt_days IS INITIAL.
      RETURN.
    ENDIF.
    " The first PAYOUT_EXAMPLES payments of each partition of the run dates with a finding (HANA,
    " ROW_NUMBER): a cell's examples are the oldest of the partitions it is made of
    DATA(ls_query) = base_query( ).
    ls_query-days = lt_days.
    LOOP AT mo_dao->get_outcome_examples( is_query = ls_query iv_rows = mv_examples ) ASSIGNING FIELD-SYMBOL(<ls_example>).
      DATA(lv_key) = key_of( iv_pymet = <ls_example>-pymet iv_xeinz = <ls_example>-xeinz ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_no_valut) = xsdbool( mo_ageing->is_issue_basis( lv_key ) = abap_false AND <ls_example>-valut IS INITIAL ).
      DATA(lv_ref_date) = COND d( WHEN mo_ageing->is_issue_basis( lv_key ) = abap_true OR <ls_example>-valut IS INITIAL
                                    THEN <ls_example>-laufd ELSE <ls_example>-valut ).
      DATA(lv_age) = COND i( WHEN mo_ageing->is_issue_basis( lv_key ) = abap_true
                               THEN nmax( val1 = 0 val2 = mv_today - lv_ref_date )
                             ELSE mo_ageing->business_days( iv_after    = lv_ref_date
                                                 iv_calendar = mo_ageing->calendar_of( iv_key = lv_key iv_hbkid = <ls_example>-hbkid ) ) ).
      DATA(lv_line) = payment_line( iv_doc1r    = <ls_example>-doc1r
                                    iv_pymet    = <ls_example>-pymet
                                    iv_laufd    = <ls_example>-laufd
                                    iv_ref_date = lv_ref_date
                                    iv_no_valut = lv_no_valut
                                    iv_age      = lv_age
                                    iv_amount   = <ls_example>-amount
                                    iv_currency = <ls_example>-currency ).
      IF <ls_example>-outcome = zif_cd_ops_payout_types=>gc_outcome-inconsistent.
        add_example( iv_key      = lv_key
                     iv_day      = <ls_example>-laufd
                     iv_code     = COND #( WHEN <ls_example>-finding IS INITIAL
                                           THEN zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                           ELSE <ls_example>-finding )
                     iv_ref_date = lv_ref_date
                     iv_doc1r    = <ls_example>-doc1r
                     iv_line     = |{ lv_line } { <ls_example>-evidence_ref }| ).
        CONTINUE.
      ENDIF.
      " In flight: late, undetermined, status lag
      DATA(lv_rag) = mo_ageing->rag_of( iv_key = lv_key iv_age = lv_age ).
      IF lv_rag = zif_cd_ops_types=>gc_rag-red OR lv_rag = zif_cd_ops_types=>gc_rag-amber.
        add_example( iv_key      = lv_key
                     iv_day      = <ls_example>-laufd
                     iv_code     = zif_cd_hck_runtime_types=>gc_code-payment_not_clear
                     iv_ref_date = lv_ref_date
                     iv_doc1r    = <ls_example>-doc1r
                     iv_line     = lv_line ).
      ENDIF.
      IF <ls_example>-outcome = zif_cd_ops_payout_types=>gc_outcome-undetermined.
        add_example( iv_key      = lv_key
                     iv_day      = <ls_example>-laufd
                     iv_code     = zif_cd_hck_runtime_types=>gc_code-undetermined
                     iv_ref_date = lv_ref_date
                     iv_doc1r    = <ls_example>-doc1r
                     iv_line     = |{ lv_line } { <ls_example>-evidence_ref }| ).
      ELSEIF <ls_example>-finding = zif_cd_ops_payout_types=>gc_code-status_pending AND <ls_example>-due = abap_true.
        add_example( iv_key      = lv_key
                     iv_day      = <ls_example>-laufd
                     iv_code     = zif_cd_hck_runtime_types=>gc_code-status_lag
                     iv_ref_date = lv_ref_date
                     iv_doc1r    = <ls_example>-doc1r
                     iv_line     = |{ lv_line } { <ls_example>-evidence_ref }| ).
      ELSE.
        " A payment of a lagging run acknowledged per file, status still ISSUED
        READ TABLE mt_run_parts ASSIGNING FIELD-SYMBOL(<ls_part>)
             WITH KEY key = lv_key laufd = <ls_example>-laufd laufi = <ls_example>-laufi hbkid = <ls_example>-hbkid.
        IF sy-subrc = 0 AND line_exists( mt_ack_open[ table_line = to_upper( condense( CONV string( <ls_example>-pay_status ) ) ) ] ).
          add_example( iv_key      = lv_key
                       iv_day      = <ls_example>-laufd
                       iv_code     = zif_cd_hck_runtime_types=>gc_code-status_lag
                       iv_ref_date = lv_ref_date
                       iv_doc1r    = <ls_example>-doc1r
                       iv_line     = |{ lv_line } { <ls_part>-status }| ).
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_open.
    DATA(lr_stat) = stat( iv_key ).
    rv_age = COND #( WHEN mo_ageing->is_issue_basis( iv_key ) = abap_true
                       " Issue date basis (e.g. cheques): calendar days since issue (run date)
                       THEN nmax( val1 = 0 val2 = mv_today - iv_ref_date )
                     " Value date basis (wire / ACH / card): business days after the value date
                     ELSE mo_ageing->business_days( iv_after = iv_ref_date iv_calendar = iv_calendar ) ).
    lr_stat->open   = lr_stat->open + iv_payments.
    lr_stat->oldest = nmax( val1 = lr_stat->oldest val2 = rv_age ).
    IF iv_no_valut = abap_true.
      mv_no_valut = mv_no_valut + iv_payments.
    ENDIF.
    DATA(lv_rag) = mo_ageing->rag_of( iv_key = iv_key iv_age = rv_age ).
    IF lv_rag <> zif_cd_ops_types=>gc_rag-red AND lv_rag <> zif_cd_ops_types=>gc_rag-amber.
      RETURN.
    ENDIF.
    DATA(lv_crit) = COND i( WHEN lv_rag = zif_cd_ops_types=>gc_rag-red THEN iv_payments ).
    lr_stat->warn = lr_stat->warn + iv_payments.
    lr_stat->crit = lr_stat->crit + lv_crit.
    " Amounts per currency (EUR / GBP alongside USD): never summed across currencies
    READ TABLE mt_late_amounts ASSIGNING FIELD-SYMBOL(<ls_late>) WITH TABLE KEY key = iv_key currency = iv_currency.
    IF sy-subrc <> 0.
      INSERT VALUE #( key = iv_key currency = iv_currency ) INTO TABLE mt_late_amounts ASSIGNING <ls_late>.
    ENDIF.
    <ls_late>-warn = <ls_late>-warn + iv_amount.
    IF lv_crit > 0.
      <ls_late>-crit = <ls_late>-crit + iv_amount.
    ENDIF.
    add_cell( iv_key      = iv_key
              iv_day      = iv_day
              iv_code     = zif_cd_hck_runtime_types=>gc_code-payment_not_clear
              iv_severity = COND #( WHEN lv_crit > 0 THEN zif_cd_ops_types=>gc_severity-error
                                    ELSE zif_cd_ops_types=>gc_severity-warning )
              iv_payments = iv_payments
              iv_amount   = iv_amount
              iv_currency = iv_currency ).
    READ TABLE mt_cells ASSIGNING FIELD-SYMBOL(<ls_cell>)
         WITH TABLE KEY key = iv_key day = iv_day code = zif_cd_hck_runtime_types=>gc_code-payment_not_clear.
    IF sy-subrc = 0.
      <ls_cell>-crit   = <ls_cell>-crit + lv_crit.
      <ls_cell>-oldest = nmax( val1 = <ls_cell>-oldest val2 = rv_age ).
    ENDIF.
  ENDMETHOD.


  METHOD add_cell.
    READ TABLE mt_cells ASSIGNING FIELD-SYMBOL(<ls_cell>) WITH TABLE KEY key = iv_key day = iv_day code = iv_code.
    IF sy-subrc <> 0.
      INSERT VALUE #( key = iv_key day = iv_day code = iv_code ) INTO TABLE mt_cells ASSIGNING <ls_cell>.
    ENDIF.
    <ls_cell>-payments = <ls_cell>-payments + iv_payments.
    IF zcl_cd_ops_util=>severity_rank( iv_severity ) > zcl_cd_ops_util=>severity_rank( <ls_cell>-severity ).
      <ls_cell>-severity = iv_severity.
    ENDIF.
    READ TABLE <ls_cell>-amounts ASSIGNING FIELD-SYMBOL(<ls_amount>) WITH TABLE KEY currency = iv_currency.
    IF sy-subrc <> 0.
      INSERT VALUE #( currency = iv_currency ) INTO TABLE <ls_cell>-amounts ASSIGNING <ls_amount>.
    ENDIF.
    <ls_amount>-amount = <ls_amount>-amount + iv_amount.
    IF iv_code = zif_cd_hck_runtime_types=>gc_code-status_lag.
      DATA(lr_stat) = stat( iv_key ).
      lr_stat->lag = lr_stat->lag + iv_payments.
    ENDIF.
  ENDMETHOD.


  METHOD add_example.
    READ TABLE mt_cells ASSIGNING FIELD-SYMBOL(<ls_cell>) WITH TABLE KEY key = iv_key day = iv_day code = iv_code.
    IF sy-subrc <> 0 OR line_exists( <ls_cell>-examples[ doc1r = iv_doc1r ] ).
      RETURN.
    ENDIF.
    INSERT VALUE #( ref_date = iv_ref_date doc1r = iv_doc1r line = iv_line ) INTO TABLE <ls_cell>-examples.
    " Deterministic: oldest first (reference date, then payment document), the first N kept
    SORT <ls_cell>-examples BY ref_date ASCENDING doc1r ASCENDING.
    DATA(lv_first_over) = mv_examples + 1.
    IF lines( <ls_cell>-examples ) >= lv_first_over.
      DELETE <ls_cell>-examples FROM lv_first_over.
    ENDIF.
  ENDMETHOD.


  METHOD stat.
    READ TABLE mt_stats REFERENCE INTO rr_stat WITH TABLE KEY key = iv_key.
    IF sy-subrc <> 0.
      INSERT VALUE #( key = iv_key ) INTO TABLE mt_stats REFERENCE INTO rr_stat.
    ENDIF.
  ENDMETHOD.


  METHOD key_of.
    DATA(lv_flow) = COND zif_cd_hck_runtime_types=>ty_flow( WHEN iv_xeinz = abap_true
                                                              THEN zif_cd_hck_runtime_types=>gc_flow-collection
                                                            ELSE zif_cd_hck_runtime_types=>gc_flow-disbursement ).
    DATA(lv_class) = VALUE #( mt_methods[ flow = lv_flow pymet = iv_pymet ]-class OPTIONAL ).
    IF lv_class IS NOT INITIAL AND line_exists( mt_watched[ table_line = |{ lv_flow }{ lv_class }| ] ).
      rv_key = |{ lv_flow }{ lv_class }|.
    ENDIF.
  ENDMETHOD.


  METHOD payment_line.
    rv_line = zcl_cd_ops_util=>text(
                iv_msgno = zif_cd_hck_runtime_types=>gc_msg-payment_line
                iv_v1    = iv_doc1r
                iv_v2    = iv_pymet
                iv_v3    = |{ iv_laufd DATE = ISO }|
                iv_v4    = |{ iv_ref_date DATE = ISO }|
                iv_tail  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-payment_age
                                                 iv_v1    = iv_age
                                                 iv_v2    = |{ iv_amount STYLE = SIMPLE }|
                                                 iv_v3    = iv_currency ) ).
    IF iv_no_valut = abap_true.
      rv_line = |{ rv_line } { zcl_cd_ops_util=>text( zif_cd_hck_runtime_types=>gc_msg-run_date_used ) }|.
    ENDIF.
  ENDMETHOD.


  METHOD report.
    LOOP AT mt_watched ASSIGNING FIELD-SYMBOL(<lv_key>).
      DATA(ls_stat) = VALUE #( mt_stats[ key = <lv_key> ] OPTIONAL ).
      " Zero is evidence: every watched flow / class measures its counts and oldest age
      INSERT VALUE #( metric = gc_metric-open dim1 = <lv_key> value = ls_stat-open ) INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-age_oldest dim1 = <lv_key> value = ls_stat-oldest
                      kind   = zif_cd_hck_types=>gc_metric_kind-level ) INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-warn_count dim1 = <lv_key> value = ls_stat-warn ) INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-crit_count dim1 = <lv_key> value = ls_stat-crit ) INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-inconsistent dim1 = <lv_key> value = ls_stat-inconsistent )
             INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-undetermined dim1 = <lv_key> value = ls_stat-undetermined )
             INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-status_lag dim1 = <lv_key> value = ls_stat-lag ) INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-not_snapshot dim1 = <lv_key> value = ls_stat-live ) INTO TABLE cs_result-metrics.
      " Amounts per currency (EUR / GBP alongside USD): never summed across currencies
      LOOP AT mt_late_amounts ASSIGNING FIELD-SYMBOL(<ls_late>) WHERE key = <lv_key>.
        INSERT VALUE #( metric = gc_metric-warn_amount dim1 = <lv_key> dim2 = <ls_late>-currency
                        value  = <ls_late>-warn ) INTO TABLE cs_result-metrics.
        INSERT VALUE #( metric = gc_metric-crit_amount dim1 = <lv_key> dim2 = <ls_late>-currency
                        value  = <ls_late>-crit ) INTO TABLE cs_result-metrics.
      ENDLOOP.
      IF mo_ageing->limits_set( <lv_key> ) = abap_false.
        INSERT VALUE #( object_key = |{ ms_def-check_id }/{ <lv_key> }|
                        check_code = zif_cd_hck_runtime_types=>gc_code-limits_missing
                        severity   = zif_cd_ops_types=>gc_severity-warning
                        action     = zif_cd_ops_types=>gc_action-notify
                        message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-limits_missing
                                                            iv_v1    = ms_def-check_id
                                                            iv_v2    = |{ gc_metric-age_oldest }/{ <lv_key> }| ) )
               INTO TABLE cs_result-findings.
      ENDIF.
    ENDLOOP.
    report_cells( CHANGING cs_result = cs_result ).

    IF mv_no_valut > 0.
      INSERT VALUE #( object_key = |{ ms_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-value_date_missing }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-value_date_missing
                      severity   = zif_cd_ops_types=>gc_severity-info
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-value_date_missing
                                                          iv_v1    = mv_no_valut
                                                          iv_v2    = ms_def-check_id ) ) INTO TABLE cs_result-findings.
    ENDIF.
    " Not yet snapshotted: metric PAY_NOT_SNAPSHOT per flow + class; payments whose versions all say
    " AMBIGUOUS (no stored outcome to count) are evaluated live too and said here
    DATA(lv_live) = REDUCE i( INIT lv_sum = 0 FOR ls_live IN mt_stats NEXT lv_sum = lv_sum + ls_live-live ).
    IF mv_ambiguous_live > 0.
      INSERT VALUE #( object_key = |{ ms_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-evaluated_live }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-evaluated_live
                      severity   = zif_cd_ops_types=>gc_severity-info
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evaluated_live
                                                          iv_v1    = lv_live
                                                          iv_v2    = mv_ambiguous_live ) ) INTO TABLE cs_result-findings.
    ENDIF.
    " Payments whose clearing cannot be determined (mandatory evidence unavailable at the evaluation)
    IF REDUCE i( INIT lv_count = 0 FOR ls_und IN mt_stats NEXT lv_count = lv_count + ls_und-undetermined ) > 0.
      mv_partial = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD report_cells.
    DATA lt_details TYPE string_table.
    DATA lt_amounts TYPE string_table.
    DATA lt_sorted TYPE SORTED TABLE OF ty_cell WITH UNIQUE KEY key code day.
    lt_sorted = mt_cells.
    LOOP AT lt_sorted ASSIGNING FIELD-SYMBOL(<ls_cell>).
      CLEAR: lt_details, lt_amounts.
      LOOP AT <ls_cell>-amounts ASSIGNING FIELD-SYMBOL(<ls_amount>).
        INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-amount_currency
                                      iv_v1    = |{ <ls_amount>-amount STYLE = SIMPLE }|
                                      iv_v2    = <ls_amount>-currency ) INTO TABLE lt_amounts.
      ENDLOOP.
      INSERT concat_lines_of( table = lt_amounts sep = ` | ` ) INTO TABLE lt_details.
      INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-examples_head
                                    iv_v1    = lines( <ls_cell>-examples )
                                    iv_v2    = <ls_cell>-payments ) INTO TABLE lt_details.
      LOOP AT <ls_cell>-examples ASSIGNING FIELD-SYMBOL(<ls_example>).
        INSERT <ls_example>-line INTO TABLE lt_details.
      ENDLOOP.
      INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-drill_down
                                    iv_v1    = <ls_cell>-code
                                    iv_v2    = |{ <ls_cell>-day DATE = ISO }| ) INTO TABLE lt_details.
      DATA(lv_where) = |{ <ls_cell>-key } { <ls_cell>-day DATE = ISO }|.
      " One finding per flow + method class + code + run date; the key is stable across runs
      INSERT VALUE #( object_key = |{ ms_def-check_id }/{ <ls_cell>-key }/{ <ls_cell>-code }/{ <ls_cell>-day }|
                      group1     = <ls_cell>-key
                      check_code = <ls_cell>-code
                      severity   = <ls_cell>-severity
                      action     = zif_cd_ops_types=>gc_action-notify
                      amount     = COND #( WHEN lines( <ls_cell>-amounts ) = 1 THEN <ls_cell>-amounts[ 1 ]-amount )
                      currency   = COND #( WHEN lines( <ls_cell>-amounts ) = 1 THEN <ls_cell>-amounts[ 1 ]-currency )
                      reference  = <ls_cell>-key
                      message    = COND #( WHEN <ls_cell>-code = zif_cd_hck_runtime_types=>gc_code-payment_not_clear
                                           THEN zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-not_cleared
                                                                       iv_v1    = lv_where
                                                                       iv_v2    = <ls_cell>-payments
                                                                       iv_v3    = <ls_cell>-crit
                                                                       iv_v4    = <ls_cell>-oldest )
                                           ELSE zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-inconsistent
                                                                       iv_v1    = lv_where
                                                                       iv_v2    = <ls_cell>-payments
                                                                       iv_v3    = <ls_cell>-code ) )
                      details    = concat_lines_of( table = lt_details sep = cl_abap_char_utilities=>newline ) )
             INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD acks_of.
    DATA lt_keys TYPE zif_cd_ops_trace_types=>tt_key_value.
    DATA lt_ref_doc TYPE zcl_cd_hck_ev_support=>tt_ref_doc.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    DATA(ls_source) = zcl_cd_ops_trace_engine=>parse_source(
                        iv_param = zif_cd_ops_trace_types=>gc_param-src_ack
                        iv_spec  = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-src_ack ) ).
    " Without table, key or date the ACK time is unknown: the case is not evaluated (said once)
    IF ls_source-table_name IS INITIAL OR ls_source-key_field IS INITIAL OR ls_source-date_field IS INITIAL.
      INSERT VALUE #( object_key = |{ ms_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-status_lag }/| &&
                                   |{ zif_cd_ops_trace_types=>gc_param-src_ack }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                      severity   = zif_cd_ops_types=>gc_severity-info
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_ack_unconfig
                                                          iv_v1    = zif_cd_ops_trace_types=>gc_param-src_ack ) )
             INTO TABLE mt_findings.
      RETURN.
    ENDIF.
    ev_has_time = xsdbool( ls_source-time_field IS NOT INITIAL ).
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      " The clearing reference as stored and without leading zeros (one comparable form)
      INSERT CONV #( <ls_payment>-doc1r ) INTO TABLE lt_keys.
      DATA(lv_ref) = zcl_cd_hck_ev_support=>ref_key( <ls_payment>-doc1r ).
      INSERT CONV #( lv_ref ) INTO TABLE lt_keys.
      INSERT VALUE #( ref = lv_ref raw = <ls_payment>-doc1r doc1r = <ls_payment>-doc1r ) INTO TABLE lt_ref_doc.
    ENDLOOP.
    TRY.
        DATA(lt_rows) = zcl_cd_ops_factory=>get_trace_dao( )->read_configured_set( is_source   = ls_source
                                                                                  it_keys     = lt_keys
                                                                                  iv_max_rows = mv_cap ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        INSERT VALUE #( object_key = |{ ms_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-status_lag }/{ ls_source-table_name }|
                        check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                        severity   = zif_cd_ops_types=>gc_severity-warning
                        action     = zif_cd_ops_types=>gc_action-notify
                        message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_ack_failed
                                                            iv_v1    = ls_source-table_name
                                                            iv_tail  = lx_error->get_text( ) ) )
               INTO TABLE mt_findings.
        RETURN.
    ENDTRY.
    IF lines( lt_rows ) >= mv_cap.
      capped( ls_source-table_name ).
    ENDIF.
    DATA(lt_nack) = zcl_cd_hck_ev_support=>tokens(
                      lo_params->get_param( iv_name    = zif_cd_ops_trace_types=>gc_param-ack_nack_values
                                            iv_default = zif_cd_ops_trace_types=>gc_default-ack_nack_values ) ).
    " The oldest ACK of each payment starts the grace; a NACK or a row without date is no ACK time
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      READ TABLE lt_ref_doc ASSIGNING FIELD-SYMBOL(<ls_doc>) WITH TABLE KEY ref = zcl_cd_hck_ev_support=>ref_key( <ls_row>-key1 ).
      IF sy-subrc <> 0 OR line_exists( lt_nack[ table_line = to_upper( condense( CONV string( <ls_row>-status ) ) ) ] ).
        CONTINUE.
      ENDIF.
      DATA(ls_ack) = VALUE ty_ack( doc1r = <ls_doc>-doc1r
                                   date  = zcl_cd_ops_trace_engine=>to_date( <ls_row>-ev_date )
                                   time  = zcl_cd_ops_trace_engine=>to_time( <ls_row>-ev_time )
                                   text  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_status
                                                                  iv_v1    = ls_source-table_name
                                                                  iv_v2    = <ls_row>-status ) ).
      IF ls_ack-date IS INITIAL.
        CONTINUE.
      ENDIF.
      READ TABLE rt_acks ASSIGNING FIELD-SYMBOL(<ls_known>) WITH TABLE KEY doc1r = ls_ack-doc1r.
      IF sy-subrc <> 0.
        INSERT ls_ack INTO TABLE rt_acks.
      ELSEIF ls_ack-date < <ls_known>-date OR ( ls_ack-date = <ls_known>-date AND ls_ack-time < <ls_known>-time ).
        <ls_known> = ls_ack.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD file_ack_link.
    DATA(lo_fmon) = zcl_cd_fmon_factory=>get_dao( ).
    DATA(lv_src_id) = CONV zif_cd_fmon_types=>ty_src_id( to_upper( condense(
                        zcl_cd_ops_factory=>get_params( )->get_param(
                          iv_name    = zif_cd_hck_runtime_types=>gc_param-ack_file_src
                          iv_default = zif_cd_hck_runtime_types=>gc_param_default-ack_file_src ) ) ) ).
    " The generating source and its GROUP_FIELDS (the payment run of a file, FMON rule 9)
    DATA(lt_sources) = lo_fmon->get_sources( ).
    DATA(ls_src) = VALUE zif_cd_fmon_types=>ty_src( lt_sources[ src_id = lv_src_id ] OPTIONAL ).
    IF ls_src-group_fields IS INITIAL.
      file_ack_unusable( zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-file_ack_unconfig
                                                iv_v1    = lv_src_id ) ).
      RETURN.
    ENDIF.
    " Each group field must be a DPAYH payment run field: the payment's value of the same name
    LOOP AT zcl_cd_ops_util=>split_list( ls_src-group_fields ) ASSIGNING FIELD-SYMBOL(<lv_field>).
      DATA(lv_field) = to_upper( condense( <lv_field> ) ).
      IF lv_field <> zif_cd_hck_runtime_types=>gc_run_field-laufd
         AND lv_field <> zif_cd_hck_runtime_types=>gc_run_field-laufi
         AND lv_field <> zif_cd_hck_runtime_types=>gc_run_field-hbkid.
        file_ack_unusable( zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-file_ack_field
                                                  iv_v1    = lv_field
                                                  iv_v2    = lv_src_id ) ).
        CLEAR rs_link.
        RETURN.
      ENDIF.
      INSERT lv_field INTO TABLE rs_link-fields.
    ENDLOOP.
    " The interfaces of the source's files: its own, else every outbound interface acknowledged per file
    IF ls_src-iface_id IS NOT INITIAL.
      INSERT ls_src-iface_id INTO TABLE rs_link-ifaces.
    ELSE.
      LOOP AT lo_fmon->get_ifaces( ) ASSIGNING FIELD-SYMBOL(<ls_iface>)
           WHERE direction    = zif_cd_fmon_types=>gc_direction-outbound
             AND ack_expected = abap_true
             AND ack_level    = zif_cd_fmon_types=>gc_ack_level-file.
        INSERT <ls_iface>-iface_id INTO TABLE rs_link-ifaces.
      ENDLOOP.
    ENDIF.
    IF rs_link-ifaces IS INITIAL.
      file_ack_unusable( zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-file_ack_no_iface
                                                iv_v1    = zif_cd_fmon_types=>gc_ack_level-file ) ).
      CLEAR rs_link.
      RETURN.
    ENDIF.
    rs_link-usable = abap_true.
  ENDMETHOD.


  METHOD file_ack_unusable.
    INSERT VALUE #( object_key = |{ ms_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-status_lag }/| &&
                                 |{ zif_cd_hck_runtime_types=>gc_param-ack_file_src }|
                    check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                    severity   = zif_cd_ops_types=>gc_severity-warning
                    action     = zif_cd_ops_types=>gc_action-notify
                    message    = iv_message ) INTO TABLE mt_findings.
  ENDMETHOD.


  METHOD group_acks.
    DATA lt_keys TYPE zif_cd_fmon_types=>tt_group_key.
    DATA lt_values TYPE string_table.
    DATA lt_files TYPE zif_cd_fmon_types=>tt_file.
    DATA lt_file_ack TYPE HASHED TABLE OF zif_cd_fmon_types=>ty_group_ack WITH UNIQUE KEY file_id.
    DATA lv_since TYPE d.

    " Generation group key of each payment run, built from the values FMON reads from the source row
    LOOP AT mt_run_parts ASSIGNING FIELD-SYMBOL(<ls_part>).
      CLEAR lt_values.
      LOOP AT ms_link-fields ASSIGNING FIELD-SYMBOL(<lv_field>).
        INSERT run_value( iv_laufd = <ls_part>-laufd
                          iv_laufi = <ls_part>-laufi
                          iv_hbkid = <ls_part>-hbkid
                          iv_field = <lv_field> ) INTO TABLE lt_values.
      ENDLOOP.
      <ls_part>-gen_group = zcl_cd_fmon_rules=>generation_key( lt_values ).
      IF <ls_part>-gen_group IS INITIAL.
        CONTINUE.
      ENDIF.
      LOOP AT ms_link-ifaces ASSIGNING FIELD-SYMBOL(<lv_iface>).
        INSERT VALUE #( iface_id = <lv_iface> gen_group = <ls_part>-gen_group ) INTO TABLE lt_keys.
      ENDLOOP.
      IF lv_since IS INITIAL OR <ls_part>-laufd < lv_since.
        lv_since = <ls_part>-laufd.
      ENDIF.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.
    SORT lt_keys BY iface_id gen_group.
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING iface_id gen_group.
    " One read for all runs: the files of the groups since the day before the earliest run (the file's
    " business date is in FMON's time zone) with their ACK events
    DATA(lt_rows) = zcl_cd_fmon_factory=>get_dao( )->get_group_acks( it_keys  = lt_keys
                                                                     iv_since = CONV d( lv_since - 1 ) ).
    " The generations and the earliest ACK of each file
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF NOT line_exists( lt_files[ KEY by_id file_id = <ls_row>-file_id ] ).
        INSERT CORRESPONDING #( <ls_row> ) INTO TABLE lt_files.
      ENDIF.
      IF <ls_row>-ack_at IS INITIAL.
        CONTINUE.
      ENDIF.
      READ TABLE lt_file_ack ASSIGNING FIELD-SYMBOL(<ls_file_ack>) WITH TABLE KEY file_id = <ls_row>-file_id.
      IF sy-subrc <> 0.
        INSERT <ls_row> INTO TABLE lt_file_ack.
      ELSEIF <ls_row>-ack_at < <ls_file_ack>-ack_at.
        <ls_file_ack>-ack_at = <ls_row>-ack_at.
      ENDIF.
    ENDLOOP.
    " Per group: the latest generation of each interface (FMON's order; a replaced file never counts)
    " must have its ACK - the latest of these ACKs is the group's (the payment's file is one of them)
    LOOP AT lt_files ASSIGNING FIELD-SYMBOL(<ls_file>).
      IF zcl_cd_fmon_rules=>next_generation( is_file = <ls_file> it_generations = lt_files ) IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      READ TABLE rt_acks ASSIGNING FIELD-SYMBOL(<ls_group>) WITH TABLE KEY gen_group = <ls_file>-gen_group.
      IF sy-subrc <> 0.
        INSERT VALUE #( gen_group = <ls_file>-gen_group ) INTO TABLE rt_acks ASSIGNING <ls_group>.
      ENDIF.
      READ TABLE lt_file_ack ASSIGNING <ls_file_ack> WITH TABLE KEY file_id = <ls_file>-file_id.
      IF sy-subrc <> 0.
        <ls_group>-open = abap_true.
      ELSEIF <ls_file_ack>-ack_at > <ls_group>-ack_at.
        <ls_group>-ack_at = <ls_file_ack>-ack_at.
        <ls_group>-text   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_file_detail
                                                   iv_v1    = <ls_file>-gen_group
                                                   iv_v2    = <ls_file>-iface_id
                                                   iv_tail  = CONV string( <ls_file>-file_name ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD run_value.
    " Unformatted as the FMON reader converts a source field (dates YYYYMMDD)
    CASE iv_field.
      WHEN zif_cd_hck_runtime_types=>gc_run_field-laufd.
        rv_value = |{ iv_laufd }|.
      WHEN zif_cd_hck_runtime_types=>gc_run_field-laufi.
        rv_value = iv_laufi.
      WHEN zif_cd_hck_runtime_types=>gc_run_field-hbkid.
        rv_value = iv_hbkid.
    ENDCASE.
    rv_value = condense( rv_value ).
  ENDMETHOD.


  METHOD lag_due.
    DATA lv_basis TYPE timestamp.
    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_date) = iv_date.
    DATA(lv_time) = iv_time.
    IF iv_has_time = abap_false.
      lv_date = lv_date + 1.
      CLEAR lv_time.
    ENDIF.
    CONVERT DATE lv_date TIME lv_time INTO TIME STAMP lv_basis TIME ZONE sy-zonlo.
    rv_due = xsdbool( lv_basis <= iv_limit ).
  ENDMETHOD.


  METHOD capped.
    IF line_exists( mt_findings[ object_key = |{ ms_def-check_id }/{ iv_table }| ] ).
      RETURN.
    ENDIF.
    INSERT VALUE #( object_key = |{ ms_def-check_id }/{ iv_table }|
                    check_code = zif_cd_hck_runtime_types=>gc_code-read_capped
                    severity   = zif_cd_ops_types=>gc_severity-warning
                    action     = zif_cd_ops_types=>gc_action-notify
                    message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-read_capped
                                                        iv_v1    = iv_table
                                                        iv_v2    = mv_cap
                                                        iv_v3    = ms_def-check_id ) ) INTO TABLE mt_findings.
  ENDMETHOD.

ENDCLASS.
