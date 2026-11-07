*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_inflight.clas.abap
*& Purpose:
*& Financial integrity: payments issued by payment runs (DPAYH) that are
*& not yet cleared on the bank statement, per flow (D disbursement / C
*& collection, TFK042Z-XEINZ) and method class (wire, ACH, cheque; mapping
*& of payment methods in ZCA_PARAM). Wire / ACH: cleared = bank line with
*& FEBEP-CHECT = AUGBL (collections also: cleared G/L line with ZUONR =
*& AUGBL), aged in business days after the value date (run date when the
*& value date is missing). Cheques (disbursements): cleared = DFKKCR
*& encashment date or a bank line with CHECT = ZTNUM, aged in calendar
*& days from the run date. Returned (DFKKRP-SELW1) and reversed
*& (DFKKKO-STBEL) payments are excluded. Reads through the runtime DAO and
*& the payment trace repository; read-only, no posting, no clearing.
*& Modification log:
*& 2026-11-07 | Initial version (payments in flight, morning report).
*& 2026-11-07 | Both flows (D / C); wire / ACH aged from the value date in business days (user change).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - payments not cleared on the bank statement</p>
"! PARAM1 = factory calendar of the business days, PARAM2 = look-back days of wire / ACH
"! (default 10), PARAM3 = look-back days of cheques (default 120), PARAM4 = payments listed
"! per finding (default 10). Methods per class: HCK_INFLIGHT_WIRE_ / _ACH_ / _CHQ_METHODS.
"! Metrics per flow + class (DIM1 DWIR, DACH, DCHQ, CWIR, CACH): PAY_OPEN, AGE_OLDEST (level),
"! OVER_WARN_CNT, OVER_CRIT_CNT and OVER_WARN_AMT / OVER_CRIT_AMT (DIM2 currency). Warning /
"! critical = AMBER / RED of AGE_OLDEST in ZCD_HCK_THRESH (age at which the payment is late).
CLASS zcl_cd_hck_c_inflight DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS:
      BEGIN OF gc_metric,
        open        TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PAY_OPEN',
        age_oldest  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'AGE_OLDEST',
        warn_count  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OVER_WARN_CNT',
        crit_count  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OVER_CRIT_CNT',
        warn_amount TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OVER_WARN_AMT',
        crit_amount TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OVER_CRIT_AMT',
      END OF gc_metric.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_method,
        pymet TYPE zif_cd_hck_runtime_types=>ty_pymet,
        class TYPE zif_cd_hck_runtime_types=>ty_method_class,
      END OF ty_method.
    TYPES tt_method TYPE HASHED TABLE OF ty_method WITH UNIQUE KEY pymet.
    TYPES tt_key TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    TYPES tt_flow_class TYPE SORTED TABLE OF zif_cd_hck_runtime_types=>ty_flow_class WITH UNIQUE KEY table_line.

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
      BEGIN OF ty_working_day,
        date    TYPE d,
        working TYPE abap_bool,
      END OF ty_working_day.
    TYPES tt_working_day TYPE HASHED TABLE OF ty_working_day WITH UNIQUE KEY date.

    DATA mt_methods TYPE tt_method.
    DATA mt_watched TYPE tt_flow_class.
    DATA mt_working TYPE tt_working_day.
    DATA mv_calendar TYPE zif_cd_hck_types=>ty_calendar.
    DATA mv_cap TYPE i.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.

    METHODS load_methods
      IMPORTING
        is_def    TYPE zif_cd_hck_types=>ty_check_def
      CHANGING
        cs_result TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.

    METHODS add_methods
      IMPORTING
        iv_param    TYPE zif_cd_ops_types=>ty_param_name
        iv_default  TYPE string OPTIONAL
        iv_class    TYPE zif_cd_hck_runtime_types=>ty_method_class
        is_def      TYPE zif_cd_hck_types=>ty_check_def
      CHANGING
        cs_result   TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.

    METHODS methods_of
      IMPORTING
        it_classes        TYPE string_table
      RETURNING
        VALUE(rt_methods) TYPE zif_cd_hck_runtime_types=>tt_pymet.

    METHODS read_payments
      IMPORTING
        it_methods         TYPE zif_cd_hck_runtime_types=>tt_pymet
        iv_from            TYPE d
        iv_to              TYPE d
        is_def             TYPE zif_cd_hck_types=>ty_check_def
      RETURNING
        VALUE(rt_payments) TYPE zif_cd_hck_runtime_types=>tt_issued_payment.

    METHODS cleared_payments
      IMPORTING
        it_payments       TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        iv_from           TYPE d
        is_def            TYPE zif_cd_hck_types=>ty_check_def
      RETURNING
        VALUE(rt_cleared) TYPE tt_key.

    METHODS business_days
      IMPORTING
        iv_after       TYPE d
        iv_today       TYPE d
      RETURNING
        VALUE(rv_days) TYPE i.

    METHODS report
      IMPORTING
        it_open       TYPE tt_open
        it_thresholds TYPE zif_cd_hck_types=>tt_threshold
        is_def        TYPE zif_cd_hck_types=>ty_check_def
      CHANGING
        cs_result     TYPE zif_cd_hck_types=>ty_check_result.

    "! Read capped: listed once per read (findings of the reads are collected in MT_FINDINGS)
    METHODS capped
      IMPORTING
        iv_table TYPE clike
        is_def   TYPE zif_cd_hck_types=>ty_check_def.

    "! Payment document / cheque number without blanks and leading zeros (FEBEP-CHECT and
    "! ZUONR may carry the number with or without them - VERIFY in QA1)
    CLASS-METHODS ref_key
      IMPORTING
        iv_ref        TYPE clike
      RETURNING
        VALUE(rv_key) TYPE string.

    CLASS-METHODS flow_of
      IMPORTING
        is_payment     TYPE zif_cd_hck_runtime_types=>ty_issued_payment
      RETURNING
        VALUE(rv_flow) TYPE zif_cd_hck_runtime_types=>ty_flow.

ENDCLASS.



CLASS zcl_cd_hck_c_inflight IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA lt_excluded TYPE tt_key.
    DATA lt_open TYPE tt_open.
    DATA lv_no_valut TYPE i.

    CLEAR: mt_methods, mt_watched, mt_working, mt_findings.
    load_methods( EXPORTING is_def    = is_def
                  CHANGING  cs_result = rs_result ).
    mv_calendar = to_upper( condense( is_def-param1 ) ).
    IF mv_calendar IS INITIAL.
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ zif_cd_hck_runtime_types=>gc_code-inflight_config }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                      severity   = zif_cd_ops_types=>gc_severity-warning
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-no_calendar
                                                          iv_v1    = is_def-check_id ) ) INTO TABLE rs_result-findings.
    ENDIF.
    DATA(lv_today) = is_context-now_date.
    DATA(lv_days) = nmax( val1 = 1
                          val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param2
                                                        iv_default = zif_cd_hck_runtime_types=>gc_check_default-inflight_days ) ).
    DATA(lv_cheque_days) = nmax( val1 = 1
                                 val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param3
                                                               iv_default = zif_cd_hck_runtime_types=>gc_check_default-cheque_days ) ).
    mv_cap = zcl_cd_hck_param=>row_cap( iv_name    = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows
                                        iv_default = zif_cd_hck_runtime_types=>gc_param_default-inflight_max_rows
                                        iv_ceiling = zif_cd_hck_runtime_types=>gc_max_inflight_rows ).
    DATA(lv_bank_from)   = CONV d( lv_today - lv_days ).
    DATA(lv_cheque_from) = CONV d( lv_today - lv_cheque_days ).

    " Two bounded windows: wire / ACH and cheques (one read each, never one per payment)
    DATA(lt_bank_classes) = VALUE string_table( ( CONV #( zif_cd_hck_runtime_types=>gc_method_class-wire ) )
                                                ( CONV #( zif_cd_hck_runtime_types=>gc_method_class-ach ) ) ).
    DATA(lt_cheque_classes) = VALUE string_table( ( CONV #( zif_cd_hck_runtime_types=>gc_method_class-cheque ) ) ).
    DATA(lt_read) = read_payments( it_methods = methods_of( lt_bank_classes )
                                   iv_from    = lv_bank_from
                                   iv_to      = lv_today
                                   is_def     = is_def ).
    INSERT LINES OF read_payments( it_methods = methods_of( lt_cheque_classes )
                                   iv_from    = lv_cheque_from
                                   iv_to      = lv_today
                                   is_def     = is_def ) INTO TABLE lt_read.
    " Returned (DFKKRP-SELW1 = AUGBL) and reversed (DFKKKO-STBEL) payments are not in flight
    LOOP AT lt_read ASSIGNING FIELD-SYMBOL(<ls_read>).
      INSERT <ls_read>-doc1r INTO TABLE lt_docno.
    ENDLOOP.
    IF lt_docno IS NOT INITIAL.
      DATA(lo_trace) = zcl_cd_ops_factory=>get_trace_dao( ).
      LOOP AT lo_trace->get_doc_headers( lt_docno ) ASSIGNING FIELD-SYMBOL(<ls_header>) WHERE stbel IS NOT INITIAL.
        INSERT CONV string( <ls_header>-opbel ) INTO TABLE lt_excluded.
      ENDLOOP.
      LOOP AT lo_trace->get_returns( lt_docno ) ASSIGNING FIELD-SYMBOL(<ls_return>).
        INSERT CONV string( <ls_return>-selw1 ) INTO TABLE lt_excluded.
      ENDLOOP.
    ENDIF.
    LOOP AT lt_read ASSIGNING <ls_read>.
      " Cheques are watched for disbursements only
      IF mt_methods[ pymet = <ls_read>-pymet ]-class = zif_cd_hck_runtime_types=>gc_method_class-cheque
         AND flow_of( <ls_read> ) = zif_cd_hck_runtime_types=>gc_flow-collection.
        CONTINUE.
      ENDIF.
      IF NOT line_exists( lt_excluded[ table_line = CONV string( <ls_read>-doc1r ) ] ).
        INSERT <ls_read> INTO TABLE lt_payments.
      ENDIF.
    ENDLOOP.

    DATA(lt_cleared) = cleared_payments( it_payments = lt_payments
                                         iv_from     = lv_cheque_from
                                         is_def      = is_def ).

    LOOP AT lt_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF line_exists( lt_cleared[ table_line = CONV string( <ls_payment>-doc1r ) ] ).
        CONTINUE.
      ENDIF.
      DATA(lv_class) = mt_methods[ pymet = <ls_payment>-pymet ]-class.
      DATA(ls_open) = VALUE ty_open( key      = |{ flow_of( <ls_payment> ) }{ lv_class }|
                                     doc1r    = <ls_payment>-doc1r
                                     pymet    = <ls_payment>-pymet
                                     laufd    = <ls_payment>-laufd
                                     amount   = abs( <ls_payment>-amount )
                                     currency = <ls_payment>-currency ).
      IF lv_class = zif_cd_hck_runtime_types=>gc_method_class-cheque.
        " Cheque: calendar days since issue (run date)
        ls_open-ref_date = <ls_payment>-laufd.
        ls_open-age      = nmax( val1 = 0 val2 = lv_today - <ls_payment>-laufd ).
      ELSE.
        " Wire / ACH: business days after the value date; run date when it is missing
        ls_open-ref_date = <ls_payment>-valut.
        IF ls_open-ref_date IS INITIAL.
          ls_open-ref_date = <ls_payment>-laufd.
          ls_open-no_valut = abap_true.
          lv_no_valut = lv_no_valut + 1.
        ENDIF.
        ls_open-age = business_days( iv_after = ls_open-ref_date iv_today = lv_today ).
      ENDIF.
      INSERT ls_open INTO TABLE lt_open.
    ENDLOOP.

    INSERT LINES OF mt_findings INTO TABLE rs_result-findings.
    report( EXPORTING it_open       = lt_open
                      it_thresholds = it_thresholds
                      is_def        = is_def
            CHANGING  cs_result     = rs_result ).
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


  METHOD load_methods.
    add_methods( EXPORTING iv_param   = zif_cd_hck_runtime_types=>gc_param-inflight_wire
                           iv_class   = zif_cd_hck_runtime_types=>gc_method_class-wire
                           is_def     = is_def
                 CHANGING  cs_result  = cs_result ).
    add_methods( EXPORTING iv_param   = zif_cd_hck_runtime_types=>gc_param-inflight_ach
                           iv_class   = zif_cd_hck_runtime_types=>gc_method_class-ach
                           is_def     = is_def
                 CHANGING  cs_result  = cs_result ).
    add_methods( EXPORTING iv_param   = zif_cd_hck_runtime_types=>gc_param-inflight_cheque
                           iv_default = zif_cd_hck_runtime_types=>gc_param_default-inflight_cheque
                           iv_class   = zif_cd_hck_runtime_types=>gc_method_class-cheque
                           is_def     = is_def
                 CHANGING  cs_result  = cs_result ).
    IF mt_methods IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e384(zcd_ops) WITH is_def-check_id.
    ENDIF.
  ENDMETHOD.


  METHOD add_methods.
    DATA(lv_list) = zcl_cd_ops_factory=>get_params( )->get_param( iv_name    = iv_param
                                                                  iv_default = iv_default ).
    DATA(lt_methods) = zcl_cd_ops_util=>split_list( lv_list ).
    IF lt_methods IS INITIAL.
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ iv_class }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                      severity   = zif_cd_ops_types=>gc_severity-info
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-class_not_watched
                                                          iv_v1    = iv_class
                                                          iv_v2    = iv_param ) ) INTO TABLE cs_result-findings.
      RETURN.
    ENDIF.
    LOOP AT lt_methods ASSIGNING FIELD-SYMBOL(<lv_method>).
      DATA(lv_pymet) = CONV zif_cd_hck_runtime_types=>ty_pymet( to_upper( <lv_method> ) ).
      DATA(ls_known) = VALUE #( mt_methods[ pymet = lv_pymet ] OPTIONAL ).
      IF ls_known IS NOT INITIAL AND ls_known-class <> iv_class.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e385(zcd_ops) WITH lv_pymet ls_known-class iv_class.
      ENDIF.
      INSERT VALUE #( pymet = lv_pymet class = iv_class ) INTO TABLE mt_methods.
    ENDLOOP.
    " Wire and ACH are watched for both flows, cheques for disbursements only
    INSERT CONV zif_cd_hck_runtime_types=>ty_flow_class( |{ zif_cd_hck_runtime_types=>gc_flow-disbursement }{ iv_class }| )
      INTO TABLE mt_watched.
    IF iv_class <> zif_cd_hck_runtime_types=>gc_method_class-cheque.
      INSERT CONV zif_cd_hck_runtime_types=>ty_flow_class( |{ zif_cd_hck_runtime_types=>gc_flow-collection }{ iv_class }| )
        INTO TABLE mt_watched.
    ENDIF.
  ENDMETHOD.


  METHOD methods_of.
    LOOP AT mt_methods ASSIGNING FIELD-SYMBOL(<ls_method>).
      IF line_exists( it_classes[ table_line = CONV string( <ls_method>-class ) ] ).
        INSERT <ls_method>-pymet INTO TABLE rt_methods.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_payments.
    IF it_methods IS INITIAL.
      RETURN.
    ENDIF.
    rt_payments = zcl_cd_hck_factory=>get_runtime_dao( )->get_issued_payments( it_methods  = it_methods
                                                                                iv_from     = iv_from
                                                                                iv_to       = iv_to
                                                                                iv_max_rows = mv_cap ).
    IF lines( rt_payments ) >= mv_cap.
      capped( iv_table = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows
              is_def   = is_def ).
    ENDIF.
  ENDMETHOD.


  METHOD cleared_payments.
    DATA lt_refs TYPE zif_cd_ops_trace_types=>tt_ref.
    DATA lt_cheque_docs TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA lt_assignments TYPE zif_cd_hck_runtime_types=>tt_assignment.
    TYPES:
      BEGIN OF ty_ref_doc,
        ref   TYPE string,
        doc1r TYPE string,
      END OF ty_ref_doc.
    DATA lt_ref_doc TYPE HASHED TABLE OF ty_ref_doc WITH UNIQUE KEY ref.

    IF it_payments IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      DATA(lv_doc) = CONV string( <ls_payment>-doc1r ).
      DATA(lv_key) = ref_key( <ls_payment>-doc1r ).
      IF mt_methods[ pymet = <ls_payment>-pymet ]-class = zif_cd_hck_runtime_types=>gc_method_class-cheque.
        INSERT <ls_payment>-doc1r INTO TABLE lt_cheque_docs.
        CONTINUE.
      ENDIF.
      " Wire / ACH: FEBEP-CHECT = AUGBL, as stored and without leading zeros
      INSERT CONV #( <ls_payment>-doc1r ) INTO TABLE lt_refs.
      INSERT CONV #( lv_key ) INTO TABLE lt_refs.
      INSERT VALUE #( ref = lv_key doc1r = lv_doc ) INTO TABLE lt_ref_doc.
      " Collections: the clearing-account line with ZUONR = AUGBL, cleared by the statement posting
      IF flow_of( <ls_payment> ) = zif_cd_hck_runtime_types=>gc_flow-collection.
        INSERT VALUE #( bukrs = <ls_payment>-bukrs zuonr = <ls_payment>-doc1r ) INTO TABLE lt_assignments.
        INSERT VALUE #( bukrs = <ls_payment>-bukrs zuonr = lv_key ) INTO TABLE lt_assignments.
      ENDIF.
    ENDLOOP.

    DATA(lo_trace) = zcl_cd_ops_factory=>get_trace_dao( ).
    " Cheques: cashed in the register (encashment date) or bank line CHECT = ZTNUM
    IF lt_cheque_docs IS NOT INITIAL.
      LOOP AT lo_trace->get_checks_by_doc( lt_cheque_docs ) ASSIGNING FIELD-SYMBOL(<ls_check>).
        IF <ls_check>-bancd IS NOT INITIAL.
          INSERT CONV string( <ls_check>-doc1r ) INTO TABLE rt_cleared.
          CONTINUE.
        ENDIF.
        IF <ls_check>-ztnum IS INITIAL.
          CONTINUE.
        ENDIF.
        INSERT <ls_check>-ztnum INTO TABLE lt_refs.
        INSERT CONV #( ref_key( <ls_check>-ztnum ) ) INTO TABLE lt_refs.
        INSERT VALUE #( ref = ref_key( <ls_check>-ztnum ) doc1r = CONV string( <ls_check>-doc1r ) ) INTO TABLE lt_ref_doc.
      ENDLOOP.
    ENDIF.

    IF lt_refs IS NOT INITIAL.
      DATA(lt_lines) = lo_trace->get_bank_lines( it_ref      = lt_refs
                                                 iv_from     = iv_from
                                                 iv_max_rows = mv_cap ).
      IF lines( lt_lines ) >= mv_cap.
        capped( iv_table = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows
                is_def   = is_def ).
      ENDIF.
      LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
        DATA(ls_ref_doc) = VALUE #( lt_ref_doc[ ref = ref_key( <ls_line>-chect ) ] OPTIONAL ).
        IF ls_ref_doc IS NOT INITIAL.
          INSERT ls_ref_doc-doc1r INTO TABLE rt_cleared.
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF lt_assignments IS NOT INITIAL.
      LOOP AT zcl_cd_hck_factory=>get_runtime_dao( )->get_cleared_assignments( lt_assignments )
           ASSIGNING FIELD-SYMBOL(<ls_assignment>).
        ls_ref_doc = VALUE #( lt_ref_doc[ ref = ref_key( <ls_assignment>-zuonr ) ] OPTIONAL ).
        IF ls_ref_doc IS NOT INITIAL.
          INSERT ls_ref_doc-doc1r INTO TABLE rt_cleared.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD business_days.
    IF iv_today <= iv_after.
      RETURN.
    ENDIF.
    IF mv_calendar IS INITIAL.
      rv_days = iv_today - iv_after.
      RETURN.
    ENDIF.
    " Calendar reads are bounded (one per date and run, cached)
    DATA(lv_date) = CONV d( nmax( val1 = iv_after
                                  val2 = iv_today - zif_cd_hck_runtime_types=>gc_check_default-max_calendar ) ).
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    WHILE lv_date < iv_today.
      lv_date = lv_date + 1.
      READ TABLE mt_working ASSIGNING FIELD-SYMBOL(<ls_day>) WITH TABLE KEY date = lv_date.
      IF sy-subrc <> 0.
        INSERT VALUE #( date    = lv_date
                        working = lo_dao->is_working_day( iv_calendar = mv_calendar iv_date = lv_date ) )
          INTO TABLE mt_working ASSIGNING <ls_day>.
      ENDIF.
      IF <ls_day>-working = abap_true.
        rv_days = rv_days + 1.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.


  METHOD report.
    DATA lt_sorted TYPE tt_open.
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


  METHOD capped.
    INSERT VALUE #( object_key = |{ is_def-check_id }/{ iv_table }|
                    check_code = zif_cd_hck_runtime_types=>gc_code-read_capped
                    severity   = zif_cd_ops_types=>gc_severity-warning
                    action     = zif_cd_ops_types=>gc_action-notify
                    message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-read_capped
                                                        iv_v1    = iv_table
                                                        iv_v2    = mv_cap
                                                        iv_v3    = is_def-check_id ) ) INTO TABLE mt_findings.
  ENDMETHOD.


  METHOD ref_key.
    rv_key = condense( val = CONV string( iv_ref ) del = ` ` ).
    SHIFT rv_key LEFT DELETING LEADING '0'.
  ENDMETHOD.


  METHOD flow_of.
    rv_flow = COND #( WHEN is_payment-xeinz = abap_true THEN zif_cd_hck_runtime_types=>gc_flow-collection
                      ELSE zif_cd_hck_runtime_types=>gc_flow-disbursement ).
  ENDMETHOD.

ENDCLASS.
