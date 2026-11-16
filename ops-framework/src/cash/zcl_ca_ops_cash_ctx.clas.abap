*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cash_ctx.clas.abap
*& Purpose:
*& Run context of one FI-CA cash check: the check's parameters (CASH_*),
*& the evaluation window of the business calendar (working days and days
*& the calendar does not expect output), the owner of the check from the
*& control register / process register, the next cutoff (next working day
*& at the control's cutoff time, time zone CONTROL_TIME_ZONE), the row cap and
*& the partial flag. It completes a typed exception with owner, cutoff and
*& age and maps it through ZCL_CA_OPS_CASH_EXC (one mapping), and builds
*& the findings of expected / observed / unknown that every check shares:
*& not evaluated (value pending, read failed, calendar unknown - never
*& green, the check partial) and result capped. Reads only through the
*& cash data access and the framework's parameters.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*& 2026-11-16 | Exception contract (build K merge): FINDING sets the evidence key of the finding (area, check ID,
*&            | object key, company code) and collects its typed evidence rows (EVIDENCE, returned by every cash
*&            | check in TY_RESULT-EVIDENCE); the cutoff names its business calendar.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash operations - run context of a check</p>
CLASS zcl_ca_ops_cash_ctx DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        is_check   TYPE zif_ca_ops_chk_types=>ty_check
        is_context TYPE zif_ca_ops_chk_types=>ty_context.

    METHODS dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_ca_ops_cash_dao.

    METHODS today
      RETURNING
        VALUE(rv_today) TYPE d.

    "! Integer parameter (the code default when not maintained or not a number)
    METHODS param_int
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

    "! Character parameter, condensed (BOOL: X or blank)
    METHODS param_text
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
        iv_default      TYPE string OPTIONAL
      RETURNING
        VALUE(rv_value) TYPE string.

    "! List parameter as a range (empty = not maintained)
    METHODS param_range
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
      RETURNING
        VALUE(rt_range) TYPE zif_ca_ops_types=>tt_param_range.

    "! Most objects a rule reads (CASH_MAX_ROWS)
    METHODS max_rows
      RETURNING
        VALUE(rv_max) TYPE i.

    "! The days from today - CASH_LOOKBACK_DAYS to today - iv_lag with their working-day flag
    "! @raising zcx_ca_ops_error | no business calendar (523) or the calendar cannot be read (522)
    METHODS window_days
      IMPORTING
        iv_lag         TYPE i
      RETURNING
        VALUE(rt_days) TYPE zif_ca_ops_cash_types=>tt_day
      RAISING
        zcx_ca_ops_error.

    METHODS owner
      RETURNING
        VALUE(rs_owner) TYPE zif_ca_ops_cash_types=>ty_owner.

    METHODS cutoff
      RETURNING
        VALUE(rs_cutoff) TYPE zif_ca_ops_cash_types=>ty_cutoff.

    "! The finding of an exception: owner, cutoff and age completed, mapped by ZCL_CA_OPS_CASH_EXC
    METHODS finding
      IMPORTING
        is_exc            TYPE zif_ca_ops_cash_types=>ty_exception
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! The typed evidence rows of every finding built so far (exception contract; the check returns them)
    METHODS evidence
      RETURNING
        VALUE(rt_evidence) TYPE zif_ca_ops_exc_contract=>tt_evidence.

    "! A rule that could not be evaluated: warning CASH_NOT_EVALUATED, the check partial (never green)
    "! @parameter iv_reason | Reason text (a message of 520 - 523 or the text of a caught exception)
    METHODS not_evaluated
      IMPORTING
        iv_stage          TYPE zif_ca_ops_cash_types=>ty_stage
        iv_source         TYPE zif_ca_ops_types=>ty_reference
        iv_param          TYPE zif_ca_ops_types=>ty_param_name OPTIONAL
        iv_reason         TYPE string
        ix_error          TYPE REF TO cx_root OPTIONAL
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! A rule whose status value parameter is not maintained (value pending - VERIFY)
    METHODS pending
      IMPORTING
        iv_stage          TYPE zif_ca_ops_cash_types=>ty_stage
        iv_source         TYPE zif_ca_ops_types=>ty_reference
        iv_param          TYPE zif_ca_ops_types=>ty_param_name
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! A read that failed: not evaluated with the error's text, its trace in the details
    METHODS read_failed
      IMPORTING
        iv_stage          TYPE zif_ca_ops_cash_types=>ty_stage
        iv_source         TYPE zif_ca_ops_types=>ty_reference
        iv_param          TYPE zif_ca_ops_types=>ty_param_name OPTIONAL
        ix_error          TYPE REF TO cx_root
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! A rule that read CASH_MAX_ROWS objects: warning CASH_RESULT_CAPPED in rt_findings, the check partial
    METHODS cap
      IMPORTING
        iv_stage    TYPE zif_ca_ops_cash_types=>ty_stage
        iv_source   TYPE zif_ca_ops_types=>ty_reference
        iv_rows     TYPE i
      CHANGING
        ct_findings TYPE zif_ca_ops_types=>tt_finding.

    "! X = a rule was not evaluated or capped: the runner keeps the earlier exceptions open
    METHODS partial
      RETURNING
        VALUE(rv_partial) TYPE abap_bool.

    METHODS set_partial.

  PRIVATE SECTION.
    DATA ms_check TYPE zif_ca_ops_chk_types=>ty_check.
    DATA ms_context TYPE zif_ca_ops_chk_types=>ty_context.
    DATA mo_dao TYPE REF TO zif_ca_ops_cash_dao.
    DATA mo_params TYPE REF TO zif_ca_ops_params.
    DATA mv_partial TYPE abap_bool.
    DATA mv_owner_read TYPE abap_bool.
    DATA ms_owner TYPE zif_ca_ops_cash_types=>ty_owner.
    DATA mv_cutoff_read TYPE abap_bool.
    DATA ms_cutoff TYPE zif_ca_ops_cash_types=>ty_cutoff.
    DATA mt_evidence TYPE zif_ca_ops_exc_contract=>tt_evidence.

    "! The next cutoff (KNOWN blank when the calendar, the cutoff time or a calendar read is missing)
    METHODS next_cutoff
      RETURNING
        VALUE(rs_cutoff) TYPE zif_ca_ops_cash_types=>ty_cutoff.

ENDCLASS.



CLASS zcl_ca_ops_cash_ctx IMPLEMENTATION.

  METHOD constructor.
    ms_check   = is_check.
    ms_context = is_context.
    mo_dao     = zcl_ca_ops_cash_factory=>get_dao( ).
    mo_params  = zcl_ca_ops_factory=>get_params( ).
  ENDMETHOD.


  METHOD dao.
    ro_dao = mo_dao.
  ENDMETHOD.


  METHOD today.
    rv_today = ms_context-today.
  ENDMETHOD.


  METHOD param_int.
    rv_value = zcl_ca_ops_util=>param_int( io_params  = mo_params
                                           iv_name    = iv_name
                                           iv_default = iv_default ).
  ENDMETHOD.


  METHOD param_text.
    rv_value = condense( mo_params->get_param( iv_name = iv_name iv_default = iv_default ) ).
  ENDMETHOD.


  METHOD param_range.
    rt_range = mo_params->get_range( iv_name ).
  ENDMETHOD.


  METHOD max_rows.
    rv_max = nmax( val1 = 1
                   val2 = param_int( iv_name    = zif_ca_ops_cash_types=>gc_param-max_rows
                               iv_default = zif_ca_ops_cash_types=>gc_param_default-max_rows ) ).
  ENDMETHOD.


  METHOD window_days.
    DATA(lv_calendar) = param_text( zif_ca_ops_cash_types=>gc_param-calendar ).
    IF lv_calendar IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e523(zca_ops) WITH zif_ca_ops_cash_types=>gc_param-calendar.
    ENDIF.
    DATA(lv_lookback) = nmax( val1 = 1
                              val2 = param_int( iv_name    = zif_ca_ops_cash_types=>gc_param-lookback_days
                                          iv_default = zif_ca_ops_cash_types=>gc_param_default-lookback_days ) ).
    DATA(lv_day) = CONV d( ms_context-today - lv_lookback ).
    DATA(lv_last) = CONV d( ms_context-today - nmax( val1 = 0 val2 = iv_lag ) ).
    WHILE lv_day <= lv_last.
      INSERT VALUE #( date    = lv_day
                      working = mo_dao->working_day( iv_date = lv_day iv_calendar = lv_calendar ) ) INTO TABLE rt_days.
      lv_day = lv_day + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD owner.
    IF mv_owner_read = abap_false.
      ms_owner = mo_dao->owner( iv_area       = ms_check-area
                                iv_check_id   = ms_check-check_id
                                iv_process_id = ms_check-process_id ).
      mv_owner_read = abap_true.
    ENDIF.
    rs_owner = ms_owner.
  ENDMETHOD.


  METHOD cutoff.
    IF mv_cutoff_read = abap_false.
      ms_cutoff = next_cutoff( ).
      mv_cutoff_read = abap_true.
    ENDIF.
    rs_cutoff = ms_cutoff.
  ENDMETHOD.


  METHOD next_cutoff.
    DATA lv_date TYPE d.
    DATA lv_time TYPE t.

    DATA(ls_owner) = owner( ).
    DATA(lv_calendar) = param_text( zif_ca_ops_cash_types=>gc_param-calendar ).
    rs_cutoff-calendar_id = lv_calendar.
    IF ls_owner-cutoff_time IS INITIAL OR lv_calendar IS INITIAL.
      RETURN.
    ENDIF.
    " the time zone of the control review's business date and cut-off (one time zone for every cut-off)
    rs_cutoff-time_zone = param_text( iv_name    = zif_ca_ops_ctl_types=>gc_param-time_zone
                                      iv_default = CONV #( zif_ca_ops_ctl_types=>gc_param_default-time_zone ) ).
    IF ms_context-now IS INITIAL.
      lv_date = ms_context-today.
    ELSE.
      CONVERT TIME STAMP ms_context-now TIME ZONE rs_cutoff-time_zone INTO DATE lv_date TIME lv_time.
    ENDIF.
    " today counts while its cutoff has not passed; else the next working day
    IF lv_time >= ls_owner-cutoff_time.
      lv_date = lv_date + 1.
    ENDIF.
    TRY.
        DO zif_ca_ops_cash_types=>gc_cutoff_search_days TIMES.
          IF mo_dao->working_day( iv_date = lv_date iv_calendar = lv_calendar ) = abap_true.
            rs_cutoff = VALUE #( BASE rs_cutoff known = abap_true date = lv_date time = ls_owner-cutoff_time ).
            RETURN.
          ENDIF.
          lv_date = lv_date + 1.
        ENDDO.
      CATCH zcx_ca_ops_error.
        " a calendar that cannot be read: the cutoff stays unknown (the rule's own read reports the calendar)
        CLEAR rs_cutoff-known.
    ENDTRY.
  ENDMETHOD.


  METHOD finding.
    DATA(ls_exc) = is_exc.
    ls_exc-owner  = owner( ).
    ls_exc-cutoff = cutoff( ).
    IF ls_exc-age_days IS INITIAL.
      ls_exc-age_days = zcl_ca_ops_cash_exc=>age_days( iv_oldest = ls_exc-oldest iv_today = ms_context-today ).
    ENDIF.
    IF ls_exc-evaluation IS INITIAL.
      ls_exc-evaluation = zif_ca_ops_cash_types=>gc_evaluation-observed.
    ENDIF.
    rs_finding = zcl_ca_ops_cash_exc=>to_finding( ls_exc ).
    " exception contract: the evidence key of the exception's identity and its typed evidence rows
    rs_finding-evid_key = zcl_ca_ops_exc_contract=>evidence_key( iv_area       = ms_check-area
                                                                 iv_check_id   = ms_check-check_id
                                                                 iv_object_key = rs_finding-object_key
                                                                 iv_bukrs      = rs_finding-company_code ).
    DELETE mt_evidence WHERE evid_key = rs_finding-evid_key.
    INSERT LINES OF zcl_ca_ops_cash_exc=>evidence_rows( is_exc = ls_exc iv_evid_key = rs_finding-evid_key )
           INTO TABLE mt_evidence.
  ENDMETHOD.


  METHOD evidence.
    rt_evidence = mt_evidence.
  ENDMETHOD.


  METHOD not_evaluated.
    mv_partial = abap_true.
    rs_finding = finding( VALUE #(
      check_code  = zif_ca_ops_cash_types=>gc_code-not_evaluated
      severity    = zif_ca_ops_types=>gc_severity-warning
      stage       = iv_stage
      evaluation  = zif_ca_ops_cash_types=>gc_evaluation-not_evaluated
      object_type = zif_ca_ops_cash_types=>gc_object_type-rule
      object_key  = zcl_ca_ops_cash_exc=>object_key( iv_id = ms_check-check_id iv_sub = iv_stage )
      source      = iv_source
      rule_param  = iv_param
      msgno       = zif_ca_ops_cash_types=>gc_msg-not_evaluated
      msgv1       = iv_stage
      msgv2       = iv_reason
      note        = COND #( WHEN ix_error IS BOUND THEN zcl_ca_ops_util=>exception_trace( ix_error )
                            ELSE iv_reason ) ) ).
    IF ix_error IS BOUND.
      rs_finding-error_class = zcl_ca_ops_util=>error_class( ix_error ).
    ENDIF.
  ENDMETHOD.


  METHOD pending.
    rs_finding = not_evaluated( iv_stage  = iv_stage
                                iv_source = iv_source
                                iv_param  = iv_param
                                iv_reason = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-reason_param
                                                                   iv_v1    = iv_param ) ).
  ENDMETHOD.


  METHOD read_failed.
    rs_finding = not_evaluated( iv_stage  = iv_stage
                                iv_source = iv_source
                                iv_param  = iv_param
                                iv_reason = ix_error->get_text( )
                                ix_error  = ix_error ).
  ENDMETHOD.


  METHOD cap.
    DATA(lv_max) = max_rows( ).
    IF iv_rows < lv_max.
      RETURN.
    ENDIF.
    mv_partial = abap_true.
    INSERT finding( VALUE #( check_code  = zif_ca_ops_cash_types=>gc_code-capped
                             severity    = zif_ca_ops_types=>gc_severity-warning
                             stage       = iv_stage
                             evaluation  = zif_ca_ops_cash_types=>gc_evaluation-observed
                             object_type = zif_ca_ops_cash_types=>gc_object_type-rule
                             object_key  = zcl_ca_ops_cash_exc=>object_key( iv_id = ms_check-check_id iv_sub = iv_stage )
                             source      = iv_source
                             rule_param  = zif_ca_ops_cash_types=>gc_param-max_rows
                             msgno       = zif_ca_ops_cash_types=>gc_msg-capped
                             msgv1       = iv_stage
                             msgv2       = lv_max ) ) INTO TABLE ct_findings.
  ENDMETHOD.


  METHOD partial.
    rv_partial = mv_partial.
  ENDMETHOD.


  METHOD set_partial.
    mv_partial = abap_true.
  ENDMETHOD.

ENDCLASS.
