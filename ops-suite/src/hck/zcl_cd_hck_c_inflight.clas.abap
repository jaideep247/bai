*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_inflight.clas.abap
*& Purpose:
*& Financial integrity: payments issued by payment runs (DPAYH) that are
*& still in flight, per flow (D disbursement / C collection,
*& TFK042Z-XEINZ) and method class (configuration ZCD_HCK_PMCLASS: payment
*& methods, ageing basis, calendar; ZCD_HCK_PMBANK: calendar per house
*& bank). What takes a payment out of flight is configuration
*& (ZCD_HCK_CLRRULE): per flow + class and purpose (VOIDED, RETURNED,
*& RETRIEVED, PENDING, CLEARED, IN_FLIGHT - the first purpose with evidence decides)
*& the rows name evidence plug-ins (ZIF_CD_HCK_EVIDENCE) that must hold
*& (X mandatory, indicates the purpose; C mandatory corroboration) or must
*& not hold (N, mandatory); blank rows are informational. All rows hold =
*& excluded (counted per purpose; IN_FLIGHT: stays in flight); some but not
*& all = CLEARING_INCONSISTENT / RETURN_INCONSISTENT naming what held; a
*& mandatory row whose kind is not configured or not usable leaves the
*& purpose undetermined (CLEARING_UNDETERMINED, no later purpose decides,
*& the payment stays in flight); an anomaly of an evidence (unexpected bank code sequence, returns
*& lot mismatch, pending outcome overdue, Stripe refund) is its own
*& finding. Payments without a decision are aged: VALUE_DATE classes in
*& business days after the value date (run date when missing), ISSUE_DATE
*& classes in calendar days after the run date. Reversed payments
*& (DFKKKO-STBEL) are excluded. One batch read per evidence kind; read-only.
*& The decision per payment is the canonical evaluator ZIF_CD_OPS_PAY_OUTCOME.
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
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - payments not cleared on the bank statement</p>
"! PARAM1 = factory calendar when the method class / house bank has none, PARAM2 = look-back
"! days of VALUE_DATE classes (default 10), PARAM3 = look-back days of ISSUE_DATE classes
"! (default 120), PARAM4 = payments listed per finding (default 10). Metrics per flow + class
"! (DIM1, e.g. DWIR): PAY_OPEN, AGE_OLDEST (level), OVER_WARN_CNT, OVER_CRIT_CNT,
"! OVER_WARN_AMT / OVER_CRIT_AMT (DIM2 currency, never summed across currencies),
"! PAY_EXCLUDED (DIM2 purpose) and PAY_INCONSISTENT. Warning / critical = AMBER / RED of
"! AGE_OLDEST in ZCD_HCK_THRESH (age at which the payment is late).
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
        excluded     TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PAY_EXCLUDED',
        inconsistent TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PAY_INCONSISTENT',
        "! Payments whose clearing cannot be determined (mandatory evidence unavailable): in flight
        undetermined TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PAY_UNDETERMINED',
        "! Payments in flight whose DPAYH status did not follow the bank evidence / ACK in time
        status_lag   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PAY_STATUS_LAG',
      END OF gc_metric.

  PRIVATE SECTION.
    "! A payment listed in an inconsistency or anomaly finding
    TYPES:
      BEGIN OF ty_listed,
        key      TYPE zif_cd_hck_runtime_types=>ty_flow_class,
        code     TYPE zif_cd_ops_types=>ty_check_code,
        severity TYPE zif_cd_ops_types=>ty_severity,
        laufd    TYPE d,
        doc1r    TYPE zif_cd_hck_runtime_types=>ty_docno,
        line     TYPE string,
      END OF ty_listed.
    TYPES tt_listed TYPE STANDARD TABLE OF ty_listed WITH EMPTY KEY.

    "! A payment not cleared, with its age (business or calendar days) and its verdict
    TYPES:
      BEGIN OF ty_open,
        key      TYPE zif_cd_hck_runtime_types=>ty_flow_class,
        age      TYPE i,
        doc1r    TYPE zif_cd_hck_runtime_types=>ty_docno,
        pymet    TYPE zif_cd_hck_runtime_types=>ty_pymet,
        laufd    TYPE d,
        ref_date TYPE d,
        no_valut TYPE abap_bool,
        amount   TYPE zif_cd_ops_types=>ty_amount,
        currency TYPE zif_cd_ops_types=>ty_currency,
        warn     TYPE abap_bool,
        crit     TYPE abap_bool,
      END OF ty_open.
    TYPES tt_open TYPE STANDARD TABLE OF ty_open WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_excluded,
        key     TYPE zif_cd_hck_runtime_types=>ty_flow_class,
        purpose TYPE zif_cd_hck_runtime_types=>ty_purpose,
        count   TYPE i,
      END OF ty_excluded.
    TYPES tt_excluded TYPE HASHED TABLE OF ty_excluded WITH UNIQUE KEY key purpose.

    TYPES:
      BEGIN OF ty_working_day,
        calendar TYPE zif_cd_hck_types=>ty_calendar,
        date     TYPE d,
        working  TYPE abap_bool,
      END OF ty_working_day.
    TYPES tt_working_day TYPE HASHED TABLE OF ty_working_day WITH UNIQUE KEY calendar date.

    "! A payment whose DPAYH status did not follow the bank evidence or the bank ACK in time
    TYPES:
      BEGIN OF ty_lag,
        doc1r   TYPE zif_cd_hck_runtime_types=>ty_docno,
        key     TYPE zif_cd_hck_runtime_types=>ty_flow_class,
        message TYPE string,
        detail  TYPE string,
      END OF ty_lag.
    TYPES tt_lag TYPE SORTED TABLE OF ty_lag WITH UNIQUE KEY doc1r.

    "! Oldest bank ACK of a payment (configured ACK source)
    TYPES:
      BEGIN OF ty_ack,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
        date  TYPE d,
        time  TYPE t,
        text  TYPE string,
      END OF ty_ack.
    TYPES tt_ack TYPE HASHED TABLE OF ty_ack WITH UNIQUE KEY doc1r.

    DATA mo_outcome TYPE REF TO zif_cd_ops_pay_outcome.
    DATA mt_classes TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    DATA mt_banks TYPE zif_cd_hck_runtime_types=>tt_pm_bank.
    DATA mt_methods TYPE zif_cd_ops_payout_types=>tt_method.
    DATA mt_rules TYPE zif_cd_hck_runtime_types=>tt_clr_rule.
    DATA mt_watched TYPE zif_cd_ops_payout_types=>tt_flow_class.
    DATA mt_working TYPE tt_working_day.
    DATA mt_listed TYPE tt_listed.
    DATA mt_excluded TYPE tt_excluded.
    DATA mv_calendar TYPE zif_cd_hck_types=>ty_calendar.
    DATA mv_cap TYPE i.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.

    METHODS load_configuration
      IMPORTING
        is_def    TYPE zif_cd_hck_types=>ty_check_def
      CHANGING
        cs_result TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.

    METHODS read_payments
      IMPORTING
        iv_basis           TYPE zif_cd_hck_runtime_types=>ty_age_basis
        iv_from            TYPE d
        iv_to              TYPE d
        is_def             TYPE zif_cd_hck_types=>ty_check_def
      RETURNING
        VALUE(rt_payments) TYPE zif_cd_hck_runtime_types=>tt_issued_payment.

    "! Calendar of the payment: house bank row, method class, PARAM1 of the check
    METHODS calendar_of
      IMPORTING
        is_payment         TYPE zif_cd_hck_runtime_types=>ty_issued_payment
      RETURNING
        VALUE(rv_calendar) TYPE zif_cd_hck_types=>ty_calendar.

    METHODS business_days
      IMPORTING
        iv_after       TYPE d
        iv_today       TYPE d
        iv_calendar    TYPE zif_cd_hck_types=>ty_calendar
      RETURNING
        VALUE(rv_days) TYPE i.

    METHODS report
      IMPORTING
        it_open       TYPE tt_open
        it_thresholds TYPE zif_cd_hck_types=>tt_threshold
        is_def        TYPE zif_cd_hck_types=>ty_check_def
      CHANGING
        cs_result     TYPE zif_cd_hck_types=>ty_check_result.

    "! Inconsistency and anomaly findings (one per flow / class and code, oldest payments first)
    METHODS report_listed
      IMPORTING
        is_def    TYPE zif_cd_hck_types=>ty_check_def
        iv_top_n  TYPE i
      CHANGING
        cs_result TYPE zif_cd_hck_types=>ty_check_result.

    "! PAY_STATUS_LAG: one finding per payment in flight whose DPAYH status did not follow the bank
    "! evidence (verdict STATUS_PENDING) or its bank ACK within HCK_PAY_STATUS_LAG_MIN; metric per
    "! watched flow + class. No read per payment (shared status read, one ACK read)
    METHODS report_status_lag
      IMPORTING
        it_payments   TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        is_evaluation TYPE zif_cd_ops_payout_types=>ty_evaluation
        is_def        TYPE zif_cd_hck_types=>ty_check_def
        is_context    TYPE zif_cd_hck_types=>ty_context
      CHANGING
        cs_result     TYPE zif_cd_hck_types=>ty_check_result.

    "! Oldest bank ACK (not a NACK, with a date) of each payment from the configured payment-level
    "! ACK source TRACE_SRC_ACK (the payment trace's link: KEY = clearing reference; DATE / TIME)
    METHODS acks_of
      IMPORTING
        it_payments    TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        is_def         TYPE zif_cd_hck_types=>ty_check_def
      EXPORTING
        ev_has_time    TYPE abap_bool
      CHANGING
        cs_result      TYPE zif_cd_hck_types=>ty_check_result
      RETURNING
        VALUE(rt_acks) TYPE tt_ack.

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
        iv_table TYPE clike
        is_def   TYPE zif_cd_hck_types=>ty_check_def.

ENDCLASS.



CLASS zcl_cd_hck_c_inflight IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_open TYPE tt_open.
    DATA lv_no_valut TYPE i.

    CLEAR: mt_classes, mt_banks, mt_methods, mt_rules, mt_watched, mt_working, mt_listed,
           mt_excluded, mt_findings.
    mv_calendar = to_upper( condense( is_def-param1 ) ).
    mv_cap = zcl_cd_hck_param=>row_cap( iv_name    = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows
                                        iv_default = zif_cd_hck_runtime_types=>gc_param_default-inflight_max_rows
                                        iv_ceiling = zif_cd_hck_runtime_types=>gc_max_inflight_rows ).
    " The canonical evaluator (shared with the payment trace and the transactions dashboard)
    mo_outcome = zcl_cd_ops_factory=>get_pay_outcome( ).
    load_configuration( EXPORTING is_def    = is_def
                        CHANGING  cs_result = rs_result ).
    DATA(lv_today) = is_context-now_date.
    DATA(lv_days) = nmax( val1 = 1
                          val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param2
                                                        iv_default = zif_cd_hck_runtime_types=>gc_check_default-inflight_days ) ).
    DATA(lv_issue_days) = nmax( val1 = 1
                                val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param3
                                                              iv_default = zif_cd_hck_runtime_types=>gc_check_default-cheque_days ) ).

    " Two bounded windows (one read each, never one per payment): by ageing basis
    DATA(lt_read) = read_payments( iv_basis = zif_cd_hck_runtime_types=>gc_age_basis-value_date
                                   iv_from  = CONV d( lv_today - lv_days )
                                   iv_to    = lv_today
                                   is_def   = is_def ).
    INSERT LINES OF read_payments( iv_basis = zif_cd_hck_runtime_types=>gc_age_basis-issue_date
                                   iv_from  = CONV d( lv_today - lv_issue_days )
                                   iv_to    = lv_today
                                   is_def   = is_def ) INTO TABLE lt_read.

    " One verdict per payment, in the order of the payments (reversed payments: not in flight)
    DATA(ls_evaluation) = mo_outcome->evaluate( lt_read ).
    INSERT LINES OF ls_evaluation-findings INTO TABLE mt_findings.

    LOOP AT lt_read ASSIGNING FIELD-SYMBOL(<ls_payment>).
      DATA(ls_verdict) = ls_evaluation-verdicts[ sy-tabix ].
      DATA(lv_key) = CONV zif_cd_hck_runtime_types=>ty_flow_class( |{ <ls_payment>-flow }{ <ls_payment>-class }| ).
      LOOP AT ls_verdict-listings ASSIGNING FIELD-SYMBOL(<ls_listing>).
        INSERT VALUE #( key      = lv_key
                        code     = <ls_listing>-code
                        severity = <ls_listing>-severity
                        laufd    = <ls_payment>-laufd
                        doc1r    = <ls_payment>-doc1r
                        line     = <ls_listing>-line ) INTO TABLE mt_listed.
      ENDLOOP.
      CASE ls_verdict-status.
        WHEN zif_cd_ops_payout_types=>gc_status-excluded.
          READ TABLE mt_excluded ASSIGNING FIELD-SYMBOL(<ls_excluded>)
               WITH TABLE KEY key = lv_key purpose = ls_verdict-purpose.
          IF sy-subrc <> 0.
            INSERT VALUE #( key = lv_key purpose = ls_verdict-purpose ) INTO TABLE mt_excluded ASSIGNING <ls_excluded>.
          ENDIF.
          <ls_excluded>-count = <ls_excluded>-count + 1.
          CONTINUE.
        WHEN zif_cd_ops_payout_types=>gc_status-open.
          " In flight (also undetermined): aged below
        WHEN OTHERS.
          " Inconsistent / anomalous (listed, not aged) or reversed (not in flight)
          CONTINUE.
      ENDCASE.
      DATA(ls_open) = VALUE ty_open( key      = lv_key
                                     doc1r    = <ls_payment>-doc1r
                                     pymet    = <ls_payment>-pymet
                                     laufd    = <ls_payment>-laufd
                                     amount   = abs( <ls_payment>-amount )
                                     currency = <ls_payment>-currency ).
      IF mt_classes[ flow = <ls_payment>-flow method_class = <ls_payment>-class ]-age_basis
         = zif_cd_hck_runtime_types=>gc_age_basis-issue_date.
        " Issue date basis (e.g. cheques): calendar days since issue (run date)
        ls_open-ref_date = <ls_payment>-laufd.
        ls_open-age      = nmax( val1 = 0 val2 = lv_today - <ls_payment>-laufd ).
      ELSE.
        " Value date basis (wire / ACH / card): business days after the value date; run date when missing
        ls_open-ref_date = <ls_payment>-valut.
        IF ls_open-ref_date IS INITIAL.
          ls_open-ref_date = <ls_payment>-laufd.
          ls_open-no_valut = abap_true.
          lv_no_valut = lv_no_valut + 1.
        ENDIF.
        ls_open-age = business_days( iv_after    = ls_open-ref_date
                                     iv_today    = lv_today
                                     iv_calendar = calendar_of( <ls_payment> ) ).
      ENDIF.
      INSERT ls_open INTO TABLE lt_open.
    ENDLOOP.

    report_status_lag( EXPORTING it_payments   = lt_read
                                 is_evaluation = ls_evaluation
                                 is_def        = is_def
                                 is_context    = is_context
                       CHANGING  cs_result     = rs_result ).
    INSERT LINES OF mt_findings INTO TABLE rs_result-findings.
    report( EXPORTING it_open       = lt_open
                      it_thresholds = it_thresholds
                      is_def        = is_def
            CHANGING  cs_result     = rs_result ).
    DATA(lv_top_n) = nmax( val1 = 1
                           val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param4
                                                         iv_default = zif_cd_hck_runtime_types=>gc_check_default-top_n ) ).
    report_listed( EXPORTING is_def    = is_def
                             iv_top_n  = lv_top_n
                   CHANGING  cs_result = rs_result ).
    " What the persisted verdict says about the run of this check (ZCD_HCK_RESULT)
    IF line_exists( rs_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-read_capped ] ).
      rs_result-completion = zif_cd_hck_types=>gc_completion-partial.
    ENDIF.
    IF ls_evaluation-evidence_partial = abap_true.
      rs_result-evidence = zif_cd_hck_types=>gc_evidence-partial.
    ENDIF.
    IF lv_no_valut > 0.
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-value_date_missing }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-value_date_missing
                      severity   = zif_cd_ops_types=>gc_severity-info
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-value_date_missing
                                                          iv_v1    = lv_no_valut
                                                          iv_v2    = is_def-check_id ) ) INTO TABLE rs_result-findings.
    ENDIF.
  ENDMETHOD.


  METHOD load_configuration.
    " Method classes, house bank calendars, rules: the evaluator's configuration (one copy)
    DATA(ls_config) = mo_outcome->load( iv_context  = is_def-check_id
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
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-inflight_config }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                      severity   = zif_cd_ops_types=>gc_severity-warning
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-no_calendar
                                                          iv_v1    = is_def-check_id ) ) INTO TABLE cs_result-findings.
    ENDIF.
  ENDMETHOD.


  METHOD read_payments.
    DATA lt_methods TYPE zif_cd_hck_runtime_types=>tt_pymet.
    LOOP AT mt_methods ASSIGNING FIELD-SYMBOL(<ls_method>).
      IF mt_classes[ flow = <ls_method>-flow method_class = <ls_method>-class ]-age_basis = iv_basis
         OR ( iv_basis = zif_cd_hck_runtime_types=>gc_age_basis-value_date
              AND mt_classes[ flow = <ls_method>-flow method_class = <ls_method>-class ]-age_basis
                  <> zif_cd_hck_runtime_types=>gc_age_basis-issue_date ).
        INSERT <ls_method>-pymet INTO TABLE lt_methods.
      ENDIF.
    ENDLOOP.
    IF lt_methods IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_read) = zcl_cd_hck_factory=>get_runtime_dao( )->get_issued_payments( it_methods  = lt_methods
                                                                                  iv_from     = iv_from
                                                                                  iv_to       = iv_to
                                                                                  iv_max_rows = mv_cap ).
    IF lines( lt_read ) >= mv_cap.
      capped( iv_table = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows
              is_def   = is_def ).
    ENDIF.
    " Flow and class by the evaluator; a method read for the other basis of the same letter
    " (other flow) is left to its own window
    LOOP AT mo_outcome->classify( lt_read ) ASSIGNING FIELD-SYMBOL(<ls_payment>).
      DATA(lv_basis) = mt_classes[ flow = <ls_payment>-flow method_class = <ls_payment>-class ]-age_basis.
      IF lv_basis <> zif_cd_hck_runtime_types=>gc_age_basis-issue_date.
        lv_basis = zif_cd_hck_runtime_types=>gc_age_basis-value_date.
      ENDIF.
      IF lv_basis = iv_basis.
        INSERT <ls_payment> INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD calendar_of.
    rv_calendar = VALUE #( mt_banks[ flow = is_payment-flow method_class = is_payment-class hbkid = is_payment-hbkid ]-calendar
                           OPTIONAL ).
    IF rv_calendar IS INITIAL.
      rv_calendar = VALUE #( mt_classes[ flow = is_payment-flow method_class = is_payment-class ]-calendar OPTIONAL ).
    ENDIF.
    IF rv_calendar IS INITIAL.
      rv_calendar = mv_calendar.
    ENDIF.
    rv_calendar = to_upper( rv_calendar ).
  ENDMETHOD.


  METHOD business_days.
    IF iv_today <= iv_after.
      RETURN.
    ENDIF.
    IF iv_calendar IS INITIAL.
      rv_days = iv_today - iv_after.
      RETURN.
    ENDIF.
    " Calendar reads are bounded (one per calendar, date and run, cached)
    DATA(lv_date) = CONV d( nmax( val1 = iv_after
                                  val2 = iv_today - zif_cd_hck_runtime_types=>gc_check_default-max_calendar ) ).
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    WHILE lv_date < iv_today.
      lv_date = lv_date + 1.
      READ TABLE mt_working ASSIGNING FIELD-SYMBOL(<ls_day>) WITH TABLE KEY calendar = iv_calendar date = lv_date.
      IF sy-subrc <> 0.
        INSERT VALUE #( calendar = iv_calendar
                        date     = lv_date
                        working  = lo_dao->is_working_day( iv_calendar = iv_calendar iv_date = lv_date ) )
          INTO TABLE mt_working ASSIGNING <ls_day>.
      ENDIF.
      IF <ls_day>-working = abap_true.
        rv_days = rv_days + 1.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.


  METHOD report.
    DATA lt_sorted TYPE tt_open.
    DATA lt_inconsistent TYPE tt_key.
    DATA lt_undetermined TYPE tt_key.
    DATA lt_details TYPE string_table.
    DATA(lv_top_n) = nmax( val1 = 1
                           val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param4
                                                         iv_default = zif_cd_hck_runtime_types=>gc_check_default-top_n ) ).
    LOOP AT mt_watched ASSIGNING FIELD-SYMBOL(<lv_key>).
      DATA(ls_limit) = zcl_cd_hck_threshold=>resolve( it_thresholds = it_thresholds
                                                      iv_metric     = gc_metric-age_oldest
                                                      iv_key        = <lv_key> ).
      ls_limit-baseline_mode = zif_cd_hck_types=>gc_baseline-none.
      DATA(lv_limits_set) = xsdbool( ls_limit-amber <> 0 OR ls_limit-red <> 0 ).
      IF lv_limits_set = abap_false.
        INSERT VALUE #( object_key = |{ is_def-check_id }/{ <lv_key> }|
                        check_code = zif_cd_hck_runtime_types=>gc_code-limits_missing
                        severity   = zif_cd_ops_types=>gc_severity-warning
                        action     = zif_cd_ops_types=>gc_action-notify
                        message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-limits_missing
                                                            iv_v1    = is_def-check_id
                                                            iv_v2    = |{ gc_metric-age_oldest }/{ <lv_key> }| ) )
               INTO TABLE cs_result-findings.
      ENDIF.

      DATA(lv_open) = 0.
      DATA(lv_oldest) = 0.
      DATA(lv_warn) = 0.
      DATA(lv_crit) = 0.
      CLEAR lt_sorted.
      LOOP AT it_open ASSIGNING FIELD-SYMBOL(<ls_open>) WHERE key = <lv_key>.
        lv_open   = lv_open + 1.
        lv_oldest = nmax( val1 = lv_oldest val2 = <ls_open>-age ).
        IF lv_limits_set = abap_false.
          CONTINUE.
        ENDIF.
        DATA(lv_rag) = zcl_cd_hck_threshold=>evaluate( iv_value     = <ls_open>-age
                                                       is_threshold = ls_limit
                                                       it_history   = VALUE #( ) )-rag.
        IF lv_rag <> zif_cd_ops_types=>gc_rag-red AND lv_rag <> zif_cd_ops_types=>gc_rag-amber.
          CONTINUE.
        ENDIF.
        DATA(ls_late) = <ls_open>.
        ls_late-warn = abap_true.
        ls_late-crit = xsdbool( lv_rag = zif_cd_ops_types=>gc_rag-red ).
        lv_warn = lv_warn + 1.
        IF ls_late-crit = abap_true.
          lv_crit = lv_crit + 1.
        ENDIF.
        INSERT ls_late INTO TABLE lt_sorted.
      ENDLOOP.

      " Zero is evidence: every watched flow / class measures its counts and oldest age
      INSERT VALUE #( metric = gc_metric-open dim1 = <lv_key> value = lv_open ) INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-age_oldest dim1 = <lv_key> value = lv_oldest
                      kind   = zif_cd_hck_types=>gc_metric_kind-level ) INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-warn_count dim1 = <lv_key> value = lv_warn ) INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-crit_count dim1 = <lv_key> value = lv_crit ) INTO TABLE cs_result-metrics.
      CLEAR: lt_inconsistent, lt_undetermined.
      LOOP AT mt_listed ASSIGNING FIELD-SYMBOL(<ls_inconsistent>) WHERE key = <lv_key>.
        " Undetermined payments stay in flight (aged): counted apart, not as inconsistent
        IF <ls_inconsistent>-code = zif_cd_hck_runtime_types=>gc_code-undetermined.
          INSERT CONV string( <ls_inconsistent>-doc1r ) INTO TABLE lt_undetermined.
        ELSE.
          INSERT CONV string( <ls_inconsistent>-doc1r ) INTO TABLE lt_inconsistent.
        ENDIF.
      ENDLOOP.
      INSERT VALUE #( metric = gc_metric-inconsistent dim1 = <lv_key> value = lines( lt_inconsistent ) )
             INTO TABLE cs_result-metrics.
      INSERT VALUE #( metric = gc_metric-undetermined dim1 = <lv_key> value = lines( lt_undetermined ) )
             INTO TABLE cs_result-metrics.
      LOOP AT mt_rules ASSIGNING FIELD-SYMBOL(<ls_rule>)
           WHERE flow = <lv_key>(1) AND method_class = <lv_key>+1(3)
           GROUP BY <ls_rule>-purpose ASSIGNING FIELD-SYMBOL(<lv_purpose>).
        INSERT VALUE #( metric = gc_metric-excluded dim1 = <lv_key> dim2 = <lv_purpose>
                        value  = VALUE #( mt_excluded[ key = <lv_key> purpose = <lv_purpose> ]-count OPTIONAL ) )
               INTO TABLE cs_result-metrics.
      ENDLOOP.
      " Amounts per currency (EUR / GBP alongside USD): never summed across currencies
      LOOP AT lt_sorted ASSIGNING FIELD-SYMBOL(<ls_amount>) GROUP BY <ls_amount>-currency ASSIGNING FIELD-SYMBOL(<ls_group>).
        DATA(lv_warn_amount) = VALUE zif_cd_hck_types=>ty_value( ).
        DATA(lv_crit_amount) = VALUE zif_cd_hck_types=>ty_value( ).
        LOOP AT GROUP <ls_group> ASSIGNING FIELD-SYMBOL(<ls_member>).
          lv_warn_amount = lv_warn_amount + <ls_member>-amount.
          IF <ls_member>-crit = abap_true.
            lv_crit_amount = lv_crit_amount + <ls_member>-amount.
          ENDIF.
        ENDLOOP.
        INSERT VALUE #( metric = gc_metric-warn_amount dim1 = <lv_key> dim2 = <ls_group>
                        value  = lv_warn_amount ) INTO TABLE cs_result-metrics.
        INSERT VALUE #( metric = gc_metric-crit_amount dim1 = <lv_key> dim2 = <ls_group>
                        value  = lv_crit_amount ) INTO TABLE cs_result-metrics.
      ENDLOOP.

      IF lv_warn = 0.
        CONTINUE.
      ENDIF.
      " Detail: the oldest late payments first (no bank account data is shown)
      SORT lt_sorted BY age DESCENDING laufd ASCENDING doc1r ASCENDING.
      CLEAR lt_details.
      LOOP AT lt_sorted ASSIGNING FIELD-SYMBOL(<ls_listed>) TO lv_top_n.
        DATA(lv_line) = zcl_cd_ops_util=>text(
                          iv_msgno = zif_cd_hck_runtime_types=>gc_msg-payment_line
                          iv_v1    = <ls_listed>-doc1r
                          iv_v2    = <ls_listed>-pymet
                          iv_v3    = |{ <ls_listed>-laufd DATE = ISO }|
                          iv_v4    = |{ <ls_listed>-ref_date DATE = ISO }|
                          iv_tail  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-payment_age
                                                           iv_v1    = <ls_listed>-age
                                                           iv_v2    = |{ <ls_listed>-amount STYLE = SIMPLE }|
                                                           iv_v3    = <ls_listed>-currency ) ).
        IF <ls_listed>-no_valut = abap_true.
          lv_line = |{ lv_line } { zcl_cd_ops_util=>text( zif_cd_hck_runtime_types=>gc_msg-run_date_used ) }|.
        ENDIF.
        INSERT lv_line INTO TABLE lt_details.
      ENDLOOP.
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ <lv_key> }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-payment_not_clear
                      severity   = COND #( WHEN lv_crit > 0 THEN zif_cd_ops_types=>gc_severity-error
                                           ELSE zif_cd_ops_types=>gc_severity-warning )
                      action     = zif_cd_ops_types=>gc_action-notify
                      reference  = <lv_key>
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-not_cleared
                                                          iv_v1    = <lv_key>
                                                          iv_v2    = lv_warn
                                                          iv_v3    = lv_crit
                                                          iv_v4    = lv_oldest )
                      details    = concat_lines_of( table = lt_details sep = cl_abap_char_utilities=>newline ) )
             INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD report_listed.
    DATA lt_details TYPE string_table.
    DATA(lt_listed) = mt_listed.
    SORT lt_listed BY key code laufd doc1r.
    LOOP AT lt_listed ASSIGNING FIELD-SYMBOL(<ls_first>)
         GROUP BY ( key = <ls_first>-key code = <ls_first>-code ) ASSIGNING FIELD-SYMBOL(<ls_group>).
      CLEAR lt_details.
      DATA(lv_count) = 0.
      DATA(lv_severity) = VALUE zif_cd_ops_types=>ty_severity( ).
      LOOP AT GROUP <ls_group> ASSIGNING FIELD-SYMBOL(<ls_member>).
        lv_count = lv_count + 1.
        IF zcl_cd_ops_util=>severity_rank( <ls_member>-severity ) > zcl_cd_ops_util=>severity_rank( lv_severity ).
          lv_severity = <ls_member>-severity.
        ENDIF.
        IF lv_count <= iv_top_n.
          INSERT <ls_member>-line INTO TABLE lt_details.
        ENDIF.
      ENDLOOP.
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ <ls_group>-key }/{ <ls_group>-code }|
                      check_code = <ls_group>-code
                      severity   = lv_severity
                      action     = zif_cd_ops_types=>gc_action-notify
                      reference  = <ls_group>-key
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-inconsistent
                                                          iv_v1    = <ls_group>-key
                                                          iv_v2    = lv_count
                                                          iv_v3    = <ls_group>-code )
                      details    = concat_lines_of( table = lt_details sep = cl_abap_char_utilities=>newline ) )
             INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD report_status_lag.
    DATA lt_open TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA lt_ack_due TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA lt_lag TYPE tt_lag.
    DATA lv_now TYPE timestamp.
    DATA lv_limit TYPE timestampl.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    DATA(lv_grace) = nmax( val1 = 0
                           val2 = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                              iv_name    = zif_cd_hck_runtime_types=>gc_param-status_lag_min
                                                              iv_default = zif_cd_hck_runtime_types=>gc_param_default-status_lag_min ) ).
    CONVERT DATE is_context-now_date TIME is_context-now_time INTO TIME STAMP lv_now TIME ZONE sy-zonlo.
    lv_limit = cl_abap_tstmp=>subtractsecs( tstmp = lv_now
                                            secs  = lv_grace * 60 ).

    " Payments in flight (also undetermined): a decided payment is not lagging
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF is_evaluation-verdicts[ sy-tabix ]-status = zif_cd_ops_payout_types=>gc_status-open.
        INSERT <ls_payment> INTO TABLE lt_open.
      ENDIF.
    ENDLOOP.
    IF lt_open IS NOT INITIAL.
      DATA(lt_status) = zcl_cd_hck_ev_support=>status_of( lt_open ).
      DATA(lt_ack_open) = zcl_cd_hck_ev_support=>tokens(
                            lo_params->get_param( iv_name    = zif_cd_hck_runtime_types=>gc_param-status_ack_open
                                                  iv_default = zif_cd_hck_runtime_types=>gc_param_default-status_ack_open ) ).
      DATA(lt_no_ack) = zcl_cd_hck_ev_support=>tokens( lo_params->get_param( zif_cd_ops_trace_types=>gc_param-no_ack_methods ) ).
    ENDIF.

    LOOP AT it_payments ASSIGNING <ls_payment>.
      DATA(ls_verdict) = is_evaluation-verdicts[ sy-tabix ].
      IF ls_verdict-status <> zif_cd_ops_payout_types=>gc_status-open.
        CONTINUE.
      ENDIF.
      DATA(lv_status) = VALUE #( lt_status[ doc1r = <ls_payment>-doc1r ]-status OPTIONAL ).
      DATA(lv_key) = CONV zif_cd_hck_runtime_types=>ty_flow_class( |{ <ls_payment>-flow }{ <ls_payment>-class }| ).
      IF ls_verdict-status_pending = abap_true.
        " (b) The bank evidence decides the purpose, the status job has not followed: the evidence day
        " (newest statement line; the run date when the kind has no date) plus the grace
        DATA(lv_since) = COND d( WHEN ls_verdict-evidence_date IS NOT INITIAL THEN ls_verdict-evidence_date
                                 ELSE <ls_payment>-laufd ).
        IF lag_due( iv_date = lv_since iv_time = VALUE #( ) iv_has_time = abap_false iv_limit = lv_limit ) = abap_true.
          INSERT VALUE #( doc1r   = <ls_payment>-doc1r
                          key     = lv_key
                          message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_bank
                                                           iv_v1    = <ls_payment>-doc1r
                                                           iv_v2    = lv_status
                                                           iv_v3    = ls_verdict-purpose
                                                           iv_v4    = |{ lv_since DATE = ISO }| )
                          detail  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_detail
                                                           iv_v1    = lv_grace
                                                           iv_tail  = CONV string( ls_verdict-evidence_ref ) ) )
            INTO TABLE lt_lag.
        ENDIF.
      ELSEIF <ls_payment>-flow = zif_cd_hck_runtime_types=>gc_flow-disbursement
             AND lv_status IS NOT INITIAL AND line_exists( lt_ack_open[ table_line = lv_status ] )
             AND NOT line_exists( lt_no_ack[ table_line = to_upper( CONV string( <ls_payment>-pymet ) ) ] ).
        " (a) candidate: disbursements are acknowledged per payment
        INSERT <ls_payment> INTO TABLE lt_ack_due.
      ENDIF.
    ENDLOOP.

    " (a) The bank ACK of the payment is older than the grace, the status still says ISSUED
    IF lt_ack_due IS NOT INITIAL.
      DATA(lt_acks) = acks_of( EXPORTING it_payments = lt_ack_due
                                         is_def      = is_def
                               IMPORTING ev_has_time = DATA(lv_has_time)
                               CHANGING  cs_result   = cs_result ).
      LOOP AT lt_ack_due ASSIGNING <ls_payment>.
        READ TABLE lt_acks ASSIGNING FIELD-SYMBOL(<ls_ack>) WITH TABLE KEY doc1r = <ls_payment>-doc1r.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        IF lag_due( iv_date = <ls_ack>-date iv_time = <ls_ack>-time iv_has_time = lv_has_time iv_limit = lv_limit ) = abap_false.
          CONTINUE.
        ENDIF.
        INSERT VALUE #( doc1r   = <ls_payment>-doc1r
                        key     = |{ <ls_payment>-flow }{ <ls_payment>-class }|
                        message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_ack
                                                         iv_v1    = <ls_payment>-doc1r
                                                         iv_v2    = VALUE #( lt_status[ doc1r = <ls_payment>-doc1r ]-status OPTIONAL )
                                                         iv_v3    = |{ <ls_ack>-date DATE = ISO } { <ls_ack>-time TIME = ISO }| )
                        detail  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_detail
                                                         iv_v1    = lv_grace
                                                         iv_tail  = <ls_ack>-text ) ) INTO TABLE lt_lag.
      ENDLOOP.
    ENDIF.

    " One finding per payment (default: no alert rule - warnings of the morning report and dashboard)
    LOOP AT lt_lag ASSIGNING FIELD-SYMBOL(<ls_lag>).
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-status_lag }/{ <ls_lag>-doc1r }|
                      group1     = <ls_lag>-key
                      check_code = zif_cd_hck_runtime_types=>gc_code-status_lag
                      severity   = zif_cd_ops_types=>gc_severity-warning
                      action     = zif_cd_ops_types=>gc_action-notify
                      reference  = <ls_lag>-doc1r
                      message    = <ls_lag>-message
                      details    = <ls_lag>-detail ) INTO TABLE cs_result-findings.
    ENDLOOP.
    " Zero is evidence: every watched flow + class measures its lagging payments
    LOOP AT mt_watched ASSIGNING FIELD-SYMBOL(<lv_key>).
      DATA(lv_count) = 0.
      LOOP AT lt_lag TRANSPORTING NO FIELDS WHERE key = <lv_key>.
        lv_count = lv_count + 1.
      ENDLOOP.
      INSERT VALUE #( metric = gc_metric-status_lag dim1 = <lv_key> value = lv_count ) INTO TABLE cs_result-metrics.
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
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-status_lag }/| &&
                                   |{ zif_cd_ops_trace_types=>gc_param-src_ack }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                      severity   = zif_cd_ops_types=>gc_severity-info
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_ack_unconfig
                                                          iv_v1    = zif_cd_ops_trace_types=>gc_param-src_ack ) )
             INTO TABLE cs_result-findings.
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
        INSERT VALUE #( object_key = |{ is_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-status_lag }/{ ls_source-table_name }|
                        check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                        severity   = zif_cd_ops_types=>gc_severity-warning
                        action     = zif_cd_ops_types=>gc_action-notify
                        message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-lag_ack_failed
                                                            iv_v1    = ls_source-table_name
                                                            iv_tail  = lx_error->get_text( ) ) )
               INTO TABLE cs_result-findings.
        RETURN.
    ENDTRY.
    IF lines( lt_rows ) >= mv_cap.
      capped( iv_table = ls_source-table_name is_def = is_def ).
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
    IF line_exists( mt_findings[ object_key = |{ is_def-check_id }/{ iv_table }| ] ).
      RETURN.
    ENDIF.
    INSERT VALUE #( object_key = |{ is_def-check_id }/{ iv_table }|
                    check_code = zif_cd_hck_runtime_types=>gc_code-read_capped
                    severity   = zif_cd_ops_types=>gc_severity-warning
                    action     = zif_cd_ops_types=>gc_action-notify
                    message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-read_capped
                                                        iv_v1    = iv_table
                                                        iv_v2    = mv_cap
                                                        iv_v3    = is_def-check_id ) ) INTO TABLE mt_findings.
  ENDMETHOD.

ENDCLASS.
