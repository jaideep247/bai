*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_inflight.clas.abap
*& Purpose:
*& Financial integrity: payments issued by payment runs (DPAYH) that are
*& still in flight, per flow (D disbursement / C collection,
*& TFK042Z-XEINZ) and method class (configuration ZCD_HCK_PMCLASS: payment
*& methods, ageing basis, calendar; ZCD_HCK_PMBANK: calendar per house
*& bank). What takes a payment out of flight is configuration
*& (ZCD_HCK_CLRRULE): per flow + class and purpose (VOIDED, RETURNED,
*& PENDING, CLEARED, IN_FLIGHT - the first purpose with evidence decides)
*& the rows name evidence plug-ins (ZIF_CD_HCK_EVIDENCE) that must hold
*& (X, indicates the purpose; C, condition only) or must not hold (N).
*& All rows hold = excluded (counted per purpose; IN_FLIGHT: stays in
*& flight); some but not all = CLEARING_INCONSISTENT / RETURN_INCONSISTENT
*& naming what held; an anomaly of an evidence (unexpected bank code sequence, returns
*& lot mismatch, pending outcome overdue, Stripe refund) is its own
*& finding. Payments without a decision are aged: VALUE_DATE classes in
*& business days after the value date (run date when missing), ISSUE_DATE
*& classes in calendar days after the run date. Reversed payments
*& (DFKKKO-STBEL) are excluded. One batch read per evidence kind; read-only.
*& Modification log:
*& 2026-11-07 | Initial version (payments in flight, morning report).
*& 2026-11-07 | Both flows (D / C); wire / ACH aged from the value date in business days (user change).
*& 2026-11-07 | Clearing / return evidence by rules and plug-ins (user rules 1-5); method classes, ageing
*&            | basis and calendars (class, house bank) from configuration; inconsistency / anomaly
*&            | findings; DFKKRP and BSAS reads moved into evidence plug-ins.
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
      END OF gc_metric.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_method,
        flow  TYPE zif_cd_hck_runtime_types=>ty_flow,
        pymet TYPE zif_cd_hck_runtime_types=>ty_pymet,
        class TYPE zif_cd_hck_runtime_types=>ty_method_class,
      END OF ty_method.
    TYPES tt_method TYPE HASHED TABLE OF ty_method WITH UNIQUE KEY flow pymet.
    TYPES tt_key TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    TYPES tt_flow_class TYPE SORTED TABLE OF zif_cd_hck_runtime_types=>ty_flow_class WITH UNIQUE KEY table_line.

    "! One evidence kind with its parameters, collected once for every payment that needs it
    TYPES:
      BEGIN OF ty_group,
        evidence_class TYPE zif_cd_ops_types=>ty_class_name,
        param1         TYPE zif_cd_hck_runtime_types=>ty_rule_param,
        param2         TYPE zif_cd_hck_runtime_types=>ty_rule_param,
        param3         TYPE zif_cd_hck_runtime_types=>ty_rule_param,
        "! The kind could not be used (class, parameters, read): its purposes are not judged
        invalid        TYPE abap_bool,
        "! The kind's settings are not maintained: its rows are ignored
        unconfigured   TYPE abap_bool,
        evidence       TYPE zif_cd_hck_runtime_types=>tt_evidence,
      END OF ty_group.
    TYPES tt_group TYPE SORTED TABLE OF ty_group WITH UNIQUE KEY evidence_class param1 param2 param3.

    "! Decision about one payment
    TYPES ty_status TYPE c LENGTH 1.
    CONSTANTS:
      BEGIN OF gc_status,
        open         TYPE ty_status VALUE 'O',
        excluded     TYPE ty_status VALUE 'X',
        inconsistent TYPE ty_status VALUE 'I',
      END OF gc_status.

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

    DATA mt_classes TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    DATA mt_banks TYPE zif_cd_hck_runtime_types=>tt_pm_bank.
    DATA mt_methods TYPE tt_method.
    DATA mt_rules TYPE zif_cd_hck_runtime_types=>tt_clr_rule.
    DATA mt_groups TYPE tt_group.
    DATA mt_watched TYPE tt_flow_class.
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

    "! Each evidence kind of the rules collected once for the payments of its flow / classes
    METHODS collect_evidence
      IMPORTING
        it_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        is_def      TYPE zif_cd_hck_types=>ty_check_def.

    "! Decision of one payment from its rules (purposes in order) and evidence anomalies
    METHODS decide
      IMPORTING
        is_payment       TYPE zif_cd_hck_runtime_types=>ty_issued_payment
      RETURNING
        VALUE(rv_status) TYPE ty_status.

    METHODS group_of
      IMPORTING
        is_rule         TYPE zif_cd_hck_runtime_types=>ty_clr_rule
      RETURNING
        VALUE(rs_group) TYPE ty_group.

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

    "! Read capped: listed once per read (findings of the reads are collected in MT_FINDINGS)
    METHODS capped
      IMPORTING
        iv_table TYPE clike
        is_def   TYPE zif_cd_hck_types=>ty_check_def.

    METHODS config_finding
      IMPORTING
        iv_object   TYPE clike
        iv_severity TYPE zif_cd_ops_types=>ty_severity DEFAULT zif_cd_ops_types=>gc_severity-info
        iv_code     TYPE zif_cd_ops_types=>ty_check_code DEFAULT zif_cd_hck_runtime_types=>gc_code-inflight_config
        iv_message  TYPE string
        is_def      TYPE zif_cd_hck_types=>ty_check_def.

    "! Label of a rule row in a finding: SEQ and description (or class)
    CLASS-METHODS label
      IMPORTING
        is_rule        TYPE zif_cd_hck_runtime_types=>ty_clr_rule
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS payment_line
      IMPORTING
        is_payment     TYPE zif_cd_hck_runtime_types=>ty_issued_payment
        iv_what        TYPE clike
        iv_tail        TYPE string
      RETURNING
        VALUE(rv_line) TYPE string.

ENDCLASS.



CLASS zcl_cd_hck_c_inflight IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA lt_reversed TYPE tt_key.
    DATA lt_open TYPE tt_open.
    DATA lv_no_valut TYPE i.

    CLEAR: mt_classes, mt_banks, mt_methods, mt_rules, mt_groups, mt_watched, mt_working, mt_listed,
           mt_excluded, mt_findings.
    mv_calendar = to_upper( condense( is_def-param1 ) ).
    load_configuration( EXPORTING is_def    = is_def
                        CHANGING  cs_result = rs_result ).
    DATA(lv_today) = is_context-now_date.
    DATA(lv_days) = nmax( val1 = 1
                          val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param2
                                                        iv_default = zif_cd_hck_runtime_types=>gc_check_default-inflight_days ) ).
    DATA(lv_issue_days) = nmax( val1 = 1
                                val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param3
                                                              iv_default = zif_cd_hck_runtime_types=>gc_check_default-cheque_days ) ).
    mv_cap = zcl_cd_hck_param=>row_cap( iv_name    = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows
                                        iv_default = zif_cd_hck_runtime_types=>gc_param_default-inflight_max_rows
                                        iv_ceiling = zif_cd_hck_runtime_types=>gc_max_inflight_rows ).

    " Two bounded windows (one read each, never one per payment): by ageing basis
    DATA(lt_read) = read_payments( iv_basis = zif_cd_hck_runtime_types=>gc_age_basis-value_date
                                   iv_from  = CONV d( lv_today - lv_days )
                                   iv_to    = lv_today
                                   is_def   = is_def ).
    INSERT LINES OF read_payments( iv_basis = zif_cd_hck_runtime_types=>gc_age_basis-issue_date
                                   iv_from  = CONV d( lv_today - lv_issue_days )
                                   iv_to    = lv_today
                                   is_def   = is_def ) INTO TABLE lt_read.
    " Reversed payments (DFKKKO-STBEL) are not in flight
    DATA(lt_docno) = zcl_cd_hck_ev_support=>docnos( lt_read ).
    IF lt_docno IS NOT INITIAL.
      LOOP AT zcl_cd_ops_factory=>get_trace_dao( )->get_doc_headers( lt_docno ) ASSIGNING FIELD-SYMBOL(<ls_header>)
           WHERE stbel IS NOT INITIAL.
        INSERT CONV string( <ls_header>-opbel ) INTO TABLE lt_reversed.
      ENDLOOP.
    ENDIF.
    LOOP AT lt_read ASSIGNING FIELD-SYMBOL(<ls_read>).
      IF NOT line_exists( lt_reversed[ table_line = CONV string( <ls_read>-doc1r ) ] ).
        INSERT <ls_read> INTO TABLE lt_payments.
      ENDIF.
    ENDLOOP.

    collect_evidence( it_payments = lt_payments is_def = is_def ).

    LOOP AT lt_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF decide( <ls_payment> ) <> gc_status-open.
        CONTINUE.
      ENDIF.
      DATA(ls_open) = VALUE ty_open( key      = |{ <ls_payment>-flow }{ <ls_payment>-class }|
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
    DATA(lo_dao) = zcl_cd_hck_factory=>get_runtime_dao( ).
    DATA(lt_classes) = lo_dao->get_pm_classes( ).
    mt_banks = lo_dao->get_pm_banks( ).
    mt_rules = lo_dao->get_clearing_rules( ).
    DATA(lv_calendar_missing) = abap_false.
    LOOP AT lt_classes ASSIGNING FIELD-SYMBOL(<ls_class>).
      DATA(lv_key) = CONV zif_cd_hck_runtime_types=>ty_flow_class( |{ <ls_class>-flow }{ <ls_class>-method_class }| ).
      DATA(lt_tokens) = zcl_cd_hck_ev_support=>tokens( <ls_class>-pay_methods ).
      IF lt_tokens IS INITIAL.
        config_finding( iv_object  = lv_key
                        iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-class_not_watched
                                                            iv_v1    = lv_key )
                        is_def     = is_def ).
        CONTINUE.
      ENDIF.
      " A class is watched only when it has rules that clear it (else nothing could ever clear it)
      IF NOT line_exists( mt_rules[ flow = <ls_class>-flow method_class = <ls_class>-method_class
                                    purpose = zif_cd_hck_runtime_types=>gc_purpose-cleared ] ).
        config_finding( iv_object  = lv_key
                        iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-no_cleared_rule
                                                            iv_v1    = lv_key )
                        is_def     = is_def ).
        CONTINUE.
      ENDIF.
      LOOP AT lt_tokens ASSIGNING FIELD-SYMBOL(<lv_method>).
        DATA(lv_pymet) = CONV zif_cd_hck_runtime_types=>ty_pymet( <lv_method> ).
        DATA(ls_known) = VALUE #( mt_methods[ flow = <ls_class>-flow pymet = lv_pymet ] OPTIONAL ).
        IF ls_known IS NOT INITIAL AND ls_known-class <> <ls_class>-method_class.
          RAISE EXCEPTION TYPE zcx_cd_ops_error
            MESSAGE e385(zcd_ops) WITH lv_pymet ls_known-class <ls_class>-method_class.
        ENDIF.
        INSERT VALUE #( flow = <ls_class>-flow pymet = lv_pymet class = <ls_class>-method_class ) INTO TABLE mt_methods.
      ENDLOOP.
      INSERT <ls_class> INTO TABLE mt_classes.
      INSERT lv_key INTO TABLE mt_watched.
      IF <ls_class>-age_basis <> zif_cd_hck_runtime_types=>gc_age_basis-issue_date AND <ls_class>-calendar IS INITIAL.
        lv_calendar_missing = abap_true.
      ENDIF.
    ENDLOOP.
    IF mt_methods IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e384(zcd_ops) WITH is_def-check_id.
    ENDIF.
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
    " Flow from the method (TFK042Z-XEINZ), class from the configuration; a method read for the
    " other basis of the same letter (other flow) is left to its own window
    LOOP AT lt_read ASSIGNING FIELD-SYMBOL(<ls_read>).
      DATA(ls_payment) = <ls_read>.
      ls_payment-flow = COND #( WHEN <ls_read>-xeinz = abap_true THEN zif_cd_hck_runtime_types=>gc_flow-collection
                                ELSE zif_cd_hck_runtime_types=>gc_flow-disbursement ).
      ls_payment-class = VALUE #( mt_methods[ flow = ls_payment-flow pymet = <ls_read>-pymet ]-class OPTIONAL ).
      IF ls_payment-class IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_basis) = mt_classes[ flow = ls_payment-flow method_class = ls_payment-class ]-age_basis.
      IF lv_basis <> zif_cd_hck_runtime_types=>gc_age_basis-issue_date.
        lv_basis = zif_cd_hck_runtime_types=>gc_age_basis-value_date.
      ENDIF.
      IF lv_basis = iv_basis.
        INSERT ls_payment INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD collect_evidence.
    DATA lt_need TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    " One group per evidence class + parameters across all flows / classes
    LOOP AT mt_rules ASSIGNING FIELD-SYMBOL(<ls_rule>).
      INSERT VALUE #( evidence_class = to_upper( condense( <ls_rule>-evidence_class ) )
                      param1         = <ls_rule>-param1
                      param2         = <ls_rule>-param2
                      param3         = <ls_rule>-param3 ) INTO TABLE mt_groups.
    ENDLOOP.
    LOOP AT mt_groups ASSIGNING FIELD-SYMBOL(<ls_group>).
      CLEAR lt_need.
      DATA(ls_rule) = VALUE zif_cd_hck_runtime_types=>ty_clr_rule( ).
      LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
        LOOP AT mt_rules ASSIGNING <ls_rule> WHERE flow = <ls_payment>-flow AND method_class = <ls_payment>-class.
          IF to_upper( condense( <ls_rule>-evidence_class ) ) = <ls_group>-evidence_class
             AND <ls_rule>-param1 = <ls_group>-param1 AND <ls_rule>-param2 = <ls_group>-param2
             AND <ls_rule>-param3 = <ls_group>-param3.
            INSERT <ls_payment> INTO TABLE lt_need.
            ls_rule = <ls_rule>.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
      IF lt_need IS INITIAL.
        CONTINUE.
      ENDIF.
      TRY.
          DATA(lo_evidence) = CAST zif_cd_hck_evidence(
                                zcl_cd_ops_factory=>get_plugin( iv_class_name = <ls_group>-evidence_class
                                                                iv_interface  = zif_cd_hck_runtime_types=>gc_evidence_intf ) ).
          DATA(ls_result) = lo_evidence->collect( it_payments = lt_need
                                                  is_rule     = ls_rule
                                                  iv_max_rows = mv_cap ).
          <ls_group>-evidence = ls_result-evidence.
          IF ls_result-capped = abap_true.
            capped( iv_table = ls_result-source is_def = is_def ).
          ENDIF.
          IF ls_result-unconfigured = abap_true.
            <ls_group>-unconfigured = abap_true.
            config_finding( iv_object  = |{ <ls_group>-evidence_class }/{ <ls_group>-param1 }|
                            iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_unconfig
                                                                iv_v1    = <ls_group>-evidence_class
                                                                iv_v2    = <ls_group>-param1 )
                            is_def     = is_def ).
          ENDIF.
        CATCH cx_root INTO DATA(lx_error).
          " Fail closed: the purposes of these rows are not judged (a payment stays in flight)
          <ls_group>-invalid = abap_true.
          config_finding( iv_object   = |{ <ls_group>-evidence_class }/{ <ls_group>-param1 }|
                          iv_severity = zif_cd_ops_types=>gc_severity-error
                          iv_code     = zif_cd_hck_runtime_types=>gc_code-clrrule_invalid
                          iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-rule_invalid
                                                               iv_v1    = <ls_group>-evidence_class
                                                               iv_v2    = <ls_group>-param1
                                                               iv_tail  = lx_error->get_text( ) )
                          is_def      = is_def ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD decide.
    DATA lt_held TYPE string_table.
    DATA lt_missing TYPE string_table.
    DATA lt_forbidden TYPE string_table.
    DATA lt_info TYPE string_table.
    DATA lt_seen TYPE SORTED TABLE OF zif_cd_ops_types=>ty_class_name WITH UNIQUE KEY table_line.
    DATA(lv_key) = CONV zif_cd_hck_runtime_types=>ty_flow_class( |{ is_payment-flow }{ is_payment-class }| ).
    rv_status = gc_status-open.

    " Anomalies of any evidence of the payment's rules are listed under their own code
    LOOP AT mt_rules ASSIGNING FIELD-SYMBOL(<ls_rule>) WHERE flow = is_payment-flow AND method_class = is_payment-class.
      DATA(ls_group) = group_of( <ls_rule> ).
      INSERT CONV #( |{ ls_group-evidence_class }{ ls_group-param1 }{ ls_group-param2 }{ ls_group-param3 }| )
        INTO TABLE lt_seen.
      IF sy-subrc <> 0 OR ls_group-invalid = abap_true OR ls_group-unconfigured = abap_true.
        CONTINUE.
      ENDIF.
      DATA(ls_evidence) = VALUE #( ls_group-evidence[ doc1r = is_payment-doc1r ] OPTIONAL ).
      IF ls_evidence-anomaly IS NOT INITIAL.
        INSERT VALUE #( key      = lv_key
                        code     = ls_evidence-anomaly
                        severity = ls_evidence-severity
                        laufd    = is_payment-laufd
                        doc1r    = is_payment-doc1r
                        line     = payment_line( is_payment = is_payment
                                                 iv_what    = ls_evidence-anomaly
                                                 iv_tail    = zcl_cd_ops_util=>text(
                                                                iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_anomaly
                                                                iv_v1    = label( <ls_rule> )
                                                                iv_tail  = ls_evidence-detail ) ) ) INTO TABLE mt_listed.
        rv_status = gc_status-inconsistent.
      ENDIF.
    ENDLOOP.

    " Purposes in order: the first one with evidence decides
    DATA(lt_purposes) = VALUE string_table( ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-voided ) )
                                            ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-returned ) )
                                            ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-pending ) )
                                            ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-cleared ) )
                                            ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-in_flight ) ) ).
    LOOP AT lt_purposes ASSIGNING FIELD-SYMBOL(<lv_purpose>).
      CLEAR: lt_held, lt_missing, lt_forbidden, lt_info.
      DATA(lv_indicated) = abap_false.
      DATA(lv_rows) = 0.
      DATA(lv_unusable) = abap_false.
      LOOP AT mt_rules ASSIGNING <ls_rule>
           WHERE flow = is_payment-flow AND method_class = is_payment-class AND purpose = <lv_purpose>.
        ls_group = group_of( <ls_rule> ).
        IF ls_group-unconfigured = abap_true.
          CONTINUE.
        ENDIF.
        IF ls_group-invalid = abap_true.
          lv_unusable = abap_true.
          CONTINUE.
        ENDIF.
        lv_rows = lv_rows + 1.
        ls_evidence = VALUE #( ls_group-evidence[ doc1r = is_payment-doc1r ] OPTIONAL ).
        DATA(lv_text) = COND string( WHEN ls_evidence-detail IS INITIAL THEN label( <ls_rule> )
                                     ELSE |{ label( <ls_rule> ) }: { ls_evidence-detail }| ).
        CASE <ls_rule>-required.
          WHEN zif_cd_hck_runtime_types=>gc_required-must_hold.
            IF ls_evidence-found = abap_true.
              INSERT lv_text INTO TABLE lt_held.
              lv_indicated = abap_true.
            ELSE.
              INSERT lv_text INTO TABLE lt_missing.
            ENDIF.
          WHEN zif_cd_hck_runtime_types=>gc_required-condition.
            " A condition must hold but never indicates the purpose on its own
            IF ls_evidence-found = abap_true.
              INSERT lv_text INTO TABLE lt_held.
            ELSE.
              INSERT lv_text INTO TABLE lt_missing.
            ENDIF.
          WHEN zif_cd_hck_runtime_types=>gc_required-must_not_hold.
            IF ls_evidence-found = abap_true.
              INSERT lv_text INTO TABLE lt_forbidden.
            ENDIF.
          WHEN OTHERS.
            IF ls_evidence-found = abap_true.
              INSERT lv_text INTO TABLE lt_info.
            ENDIF.
        ENDCASE.
      ENDLOOP.
      " Fail closed: a purpose with an unusable row is not judged; no evidence = next purpose
      IF lv_unusable = abap_true OR lv_rows = 0 OR lv_indicated = abap_false.
        CONTINUE.
      ENDIF.
      IF lt_missing IS INITIAL AND lt_forbidden IS INITIAL.
        " A consistent state in flight stays in flight (aged); other purposes exclude
        IF <lv_purpose> = zif_cd_hck_runtime_types=>gc_purpose-in_flight.
          RETURN.
        ENDIF.
        IF rv_status = gc_status-open.
          rv_status = gc_status-excluded.
          READ TABLE mt_excluded ASSIGNING FIELD-SYMBOL(<ls_excluded>) WITH TABLE KEY key = lv_key purpose = <lv_purpose>.
          IF sy-subrc <> 0.
            INSERT VALUE #( key = lv_key purpose = <lv_purpose> ) INTO TABLE mt_excluded ASSIGNING <ls_excluded>.
          ENDIF.
          <ls_excluded>-count = <ls_excluded>-count + 1.
        ENDIF.
        RETURN.
      ENDIF.
      " Some but not all: the finding names what held, what is missing and what must not hold
      DATA(lv_tail) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_held
                                             iv_tail  = concat_lines_of( table = lt_held sep = ` | ` ) ).
      IF lt_missing IS NOT INITIAL.
        lv_tail = |{ lv_tail } { zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_missing
                                                        iv_tail  = concat_lines_of( table = lt_missing sep = ` | ` ) ) }|.
      ENDIF.
      IF lt_forbidden IS NOT INITIAL.
        lv_tail = |{ lv_tail } { zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_forbidden
                                                        iv_tail  = concat_lines_of( table = lt_forbidden sep = ` | ` ) ) }|.
      ENDIF.
      IF lt_info IS NOT INITIAL.
        lv_tail = |{ lv_tail } { zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_info
                                                        iv_tail  = concat_lines_of( table = lt_info sep = ` | ` ) ) }|.
      ENDIF.
      INSERT VALUE #( key      = lv_key
                      code     = COND #( WHEN <lv_purpose> = zif_cd_hck_runtime_types=>gc_purpose-returned
                                         THEN zif_cd_hck_runtime_types=>gc_code-return_inconsist
                                         ELSE zif_cd_hck_runtime_types=>gc_code-clearing_inconsist )
                      severity = zif_cd_ops_types=>gc_severity-error
                      laufd    = is_payment-laufd
                      doc1r    = is_payment-doc1r
                      line     = payment_line( is_payment = is_payment iv_what = <lv_purpose> iv_tail = lv_tail ) )
             INTO TABLE mt_listed.
      rv_status = gc_status-inconsistent.
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD group_of.
    rs_group = VALUE #( mt_groups[ evidence_class = to_upper( condense( is_rule-evidence_class ) )
                                   param1         = is_rule-param1
                                   param2         = is_rule-param2
                                   param3         = is_rule-param3 ] OPTIONAL ).
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
      CLEAR lt_inconsistent.
      LOOP AT mt_listed ASSIGNING FIELD-SYMBOL(<ls_inconsistent>) WHERE key = <lv_key>.
        INSERT CONV string( <ls_inconsistent>-doc1r ) INTO TABLE lt_inconsistent.
      ENDLOOP.
      INSERT VALUE #( metric = gc_metric-inconsistent dim1 = <lv_key> value = lines( lt_inconsistent ) )
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


  METHOD config_finding.
    INSERT VALUE #( object_key = |{ is_def-check_id }/{ iv_code }/{ iv_object }|
                    check_code = iv_code
                    severity   = iv_severity
                    action     = zif_cd_ops_types=>gc_action-notify
                    message    = iv_message ) INTO TABLE mt_findings.
  ENDMETHOD.


  METHOD label.
    rv_text = |{ is_rule-seq } { COND string( WHEN is_rule-description IS NOT INITIAL THEN is_rule-description
                                              ELSE is_rule-evidence_class ) }|.
  ENDMETHOD.


  METHOD payment_line.
    rv_line = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_line
                                     iv_v1    = is_payment-doc1r
                                     iv_v2    = is_payment-pymet
                                     iv_v3    = |{ is_payment-laufd DATE = ISO }|
                                     iv_v4    = iv_what
                                     iv_tail  = iv_tail ).
  ENDMETHOD.

ENDCLASS.
