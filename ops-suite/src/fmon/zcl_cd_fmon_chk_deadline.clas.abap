*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_deadline.clas.abap
*& Purpose:
*& Plug-in check STAGE_DEADLINE_MISSED: the stage of a DEADLINE row of ZCD_FMON_SLA must be
*& reached by its clock time (FMON_TIME_ZONE) on a business day. One finding
*& per interface and business date naming the earliest missing step: not
*& received / received but not imported (accounts imported x of y) /
*& imported but not processed (entries not posted n of m), from the registry
*& and the statement evidence of the FEB adapter. Not raised on a holiday,
*& when ZCD_FMON_CAL expects no file or before the due time. Pure: context in,
*& findings out; no SQL, no application log.
*& Modification log:
*& 2026-11-07 | Initial version (BAI processing deadline, user requirement 2026-11-07).
*& 2026-11-08 | Table consolidation: deadline rows are ZCD_FMON_SLA rows of kind DEADLINE (ZCD_FMON_DEADL
*&            | merged); resolution day type, NORMAL, '*' unchanged.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - stage deadline by clock time</p>
"! Row choice per interface and stage: the day type of the expectation, MONTH_END / RETURNS_DAY
"! fall back to NORMAL, then '*'. Several stages missed: the latest due time is named, the
"! severity is the worst of the missed rows (row SEVERITY, else the check row's, else E).
"! Object key = interface/business date (ZCL_CD_FMON_UTIL=>IFACE_DAY_KEY): the next runs carry
"! the open exception forward (not alerted again); the engine reconciles it once the stage is met.
"! GROUP2 = condition (ZIF_CD_FMON_TYPES=>GC_DEADLINE_COND) for alert routing.
CLASS zcl_cd_fmon_chk_deadline DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

  PRIVATE SECTION.
    "! DEADLINE row of the interface and stage for the day type (* = any business day)
    METHODS pick_row
      IMPORTING
        it_deadlines       TYPE zif_cd_fmon_types=>tt_sla
        iv_iface_id        TYPE zif_cd_fmon_types=>ty_iface_id
        iv_stage           TYPE zif_cd_fmon_types=>ty_stage
        iv_day_type        TYPE zif_cd_fmon_types=>ty_day_type
      RETURNING
        VALUE(rs_deadline) TYPE zif_cd_fmon_types=>ty_sla.

    "! A file instance of the interface and day has reached the stage
    METHODS reached
      IMPORTING
        it_files          TYPE zif_cd_fmon_types=>tt_file
        iv_stage          TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_reached) TYPE abap_bool.

    "! Earliest missing step of an inbound file (GC_DEADLINE_COND)
    METHODS condition
      IMPORTING
        it_files       TYPE zif_cd_fmon_types=>tt_file
        is_evidence    TYPE zif_cd_fmon_types=>ty_stmt_evidence
      RETURNING
        VALUE(rv_cond) TYPE zif_cd_ops_types=>ty_group.

    METHODS message
      IMPORTING
        is_ctx         TYPE zif_cd_fmon_types=>ty_check_ctx
        is_deadline    TYPE zif_cd_fmon_types=>ty_sla
        iv_cond        TYPE zif_cd_ops_types=>ty_group
        is_evidence    TYPE zif_cd_fmon_types=>ty_stmt_evidence
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_cd_fmon_chk_deadline IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    DATA lt_day TYPE zif_cd_fmon_types=>tt_file.
    DATA ls_missed TYPE zif_cd_fmon_types=>ty_sla.
    DATA lv_severity TYPE zif_cd_ops_types=>ty_severity.
    DATA lv_stage TYPE zif_cd_fmon_types=>ty_stage.
    DATA lv_due TYPE timestampl.

    " A business day with expected files only: a holiday or a day expecting none never fires
    LOOP AT is_ctx-expects ASSIGNING FIELD-SYMBOL(<ls_expect>)
         WHERE expected_count > 0 AND day_type <> zif_cd_fmon_types=>gc_day_type-holiday.
      CLEAR: ls_missed, lv_severity, lv_stage.
      lt_day = VALUE #( FOR ls_file IN is_ctx-files USING KEY by_iface
                        WHERE ( iface_id = <ls_expect>-iface_id AND business_date = is_ctx-business_date )
                        ( ls_file ) ).
      LOOP AT is_ctx-slas ASSIGNING FIELD-SYMBOL(<ls_any>)
           WHERE iface_id = <ls_expect>-iface_id AND kind = zif_cd_fmon_types=>gc_sla_kind-deadline.
        " Rows are sorted by interface and stage: one evaluation per stage
        IF <ls_any>-stage = lv_stage.
          CONTINUE.
        ENDIF.
        lv_stage = <ls_any>-stage.
        DATA(ls_row) = pick_row( it_deadlines = is_ctx-slas
                                 iv_iface_id  = <ls_expect>-iface_id
                                 iv_stage     = lv_stage
                                 iv_day_type  = <ls_expect>-day_type ).
        IF ls_row IS INITIAL.
          CONTINUE.
        ENDIF.
        CONVERT DATE is_ctx-business_date TIME ls_row-due_time
          INTO TIME STAMP lv_due TIME ZONE is_ctx-time_zone.
        IF is_ctx-now < lv_due OR reached( it_files = lt_day iv_stage = lv_stage ) = abap_true.
          CONTINUE.
        ENDIF.
        DATA(lv_row_severity) = COND zif_cd_ops_types=>ty_severity(
                                  WHEN ls_row-severity IS NOT INITIAL THEN ls_row-severity
                                  WHEN is_check-severity IS NOT INITIAL THEN is_check-severity
                                  ELSE zif_cd_ops_types=>gc_severity-error ).
        IF zcl_cd_ops_util=>severity_rank( lv_row_severity ) > zcl_cd_ops_util=>severity_rank( lv_severity ).
          lv_severity = lv_row_severity.
        ENDIF.
        IF ls_missed IS INITIAL OR ls_row-due_time > ls_missed-due_time.
          ls_missed = ls_row.
        ENDIF.
      ENDLOOP.
      IF ls_missed IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_evidence) = VALUE #( is_ctx-statements[ iface_id      = <ls_expect>-iface_id
                                                      business_date = is_ctx-business_date ] OPTIONAL ).
      DATA(lv_direction) = VALUE #( is_ctx-ifaces[ iface_id = <ls_expect>-iface_id ]-direction OPTIONAL ).
      DATA(lv_cond) = COND zif_cd_ops_types=>ty_group(
                        WHEN lv_direction = zif_cd_fmon_types=>gc_direction-inbound
                         AND zcl_cd_fmon_status=>direction_of( ls_missed-stage ) = zif_cd_fmon_types=>gc_direction-inbound
                        THEN condition( it_files = lt_day is_evidence = ls_evidence )
                        ELSE zif_cd_fmon_types=>gc_deadline_cond-not_reached ).
      DATA(ls_finding) = zcl_cd_fmon_util=>new_key_finding(
                           iv_iface_id   = <ls_expect>-iface_id
                           iv_object_key = zcl_cd_fmon_util=>iface_day_key( iv_iface_id = <ls_expect>-iface_id
                                                                           iv_date     = is_ctx-business_date )
                           is_check      = is_check
                           iv_code       = zif_cd_fmon_types=>gc_check_code-deadline_missed
                           iv_severity   = lv_severity
                           iv_message    = message( is_ctx      = is_ctx
                                                    is_deadline = ls_missed
                                                    iv_cond     = lv_cond
                                                    is_evidence = ls_evidence ) ).
      ls_finding-group2 = lv_cond.
      INSERT ls_finding INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD pick_row.
    READ TABLE it_deadlines INTO rs_deadline
         WITH TABLE KEY iface_id = iv_iface_id stage = iv_stage kind = zif_cd_fmon_types=>gc_sla_kind-deadline
                        day_type = iv_day_type.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    " Same fallback as the expected files (ZCL_CD_FMON_RULES=>PICK_CALENDAR_ROW)
    IF iv_day_type = zif_cd_fmon_types=>gc_day_type-month_end
       OR iv_day_type = zif_cd_fmon_types=>gc_day_type-returns_day.
      READ TABLE it_deadlines INTO rs_deadline
           WITH TABLE KEY iface_id = iv_iface_id stage = iv_stage kind = zif_cd_fmon_types=>gc_sla_kind-deadline
                          day_type = zif_cd_fmon_types=>gc_day_type-normal.
      IF sy-subrc = 0.
        RETURN.
      ENDIF.
    ENDIF.
    READ TABLE it_deadlines INTO rs_deadline
         WITH TABLE KEY iface_id = iv_iface_id stage = iv_stage kind = zif_cd_fmon_types=>gc_sla_kind-deadline
                        day_type = zif_cd_fmon_types=>gc_wildcard.
    IF sy-subrc <> 0.
      CLEAR rs_deadline.
    ENDIF.
  ENDMETHOD.


  METHOD reached.
    LOOP AT it_files ASSIGNING FIELD-SYMBOL(<ls_file>).
      IF zcl_cd_fmon_status=>reaches( is_file = <ls_file> iv_stage = iv_stage ) = abap_true.
        rv_reached = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD condition.
    DATA(lv_received) = reached( it_files = it_files iv_stage = zif_cd_fmon_types=>gc_stage-received ).
    IF is_evidence IS NOT INITIAL.
      " Statement evidence decides the import: every payment engine account of the bank
      rv_cond = COND #( WHEN is_evidence-accounts_imported = 0 AND lv_received = abap_false
                        THEN zif_cd_fmon_types=>gc_deadline_cond-not_received
                        WHEN is_evidence-accounts_imported < is_evidence-accounts_expected
                        THEN zif_cd_fmon_types=>gc_deadline_cond-not_imported
                        ELSE zif_cd_fmon_types=>gc_deadline_cond-not_posted ).
      RETURN.
    ENDIF.
    " Without statement evidence the registry stage decides
    rv_cond = COND #( WHEN reached( it_files = it_files iv_stage = zif_cd_fmon_types=>gc_stage-loaded ) = abap_true
                      THEN zif_cd_fmon_types=>gc_deadline_cond-not_posted
                      WHEN lv_received = abap_true
                      THEN zif_cd_fmon_types=>gc_deadline_cond-not_imported
                      ELSE zif_cd_fmon_types=>gc_deadline_cond-not_received ).
  ENDMETHOD.


  METHOD message.
    DATA lv_tail TYPE string.
    DATA(lv_date) = |{ is_ctx-business_date DATE = ISO }|.
    DATA(lv_due) = |{ is_deadline-due_time TIME = ISO }|.
    DATA(lv_msgno) = SWITCH zif_cd_ops_types=>ty_msgno( iv_cond
                       WHEN zif_cd_fmon_types=>gc_deadline_cond-not_received THEN zif_cd_fmon_types=>gc_msg-deadline_not_received
                       WHEN zif_cd_fmon_types=>gc_deadline_cond-not_imported THEN zif_cd_fmon_types=>gc_msg-deadline_not_imported
                       WHEN zif_cd_fmon_types=>gc_deadline_cond-not_posted   THEN zif_cd_fmon_types=>gc_msg-deadline_not_posted
                       ELSE zif_cd_fmon_types=>gc_msg-deadline_stage ).
    IF is_evidence IS NOT INITIAL.
      lv_tail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-deadline_accounts
                                       iv_v1    = is_evidence-accounts_imported
                                       iv_v2    = is_evidence-accounts_expected ).
      IF iv_cond = zif_cd_fmon_types=>gc_deadline_cond-not_posted.
        lv_tail = COND #( WHEN is_evidence-truncated = abap_true OR is_evidence-posting_known = abap_false
                          THEN zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-deadline_not_proven
                                                      iv_tail  = lv_tail )
                          ELSE zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-deadline_lines_open
                                                      iv_v1    = is_evidence-lines_open
                                                      iv_v2    = is_evidence-lines_total
                                                      iv_tail  = lv_tail ) ).
      ENDIF.
      lv_tail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-deadline_statement
                                       iv_v1    = is_evidence-bank_key
                                       iv_v2    = |{ is_evidence-stmt_date DATE = ISO }|
                                       iv_tail  = lv_tail ).
    ENDIF.
    rv_text = zcl_cd_ops_util=>text( iv_msgno = lv_msgno
                                     iv_v1    = is_deadline-iface_id
                                     iv_v2    = lv_date
                                     iv_v3    = lv_due
                                     iv_v4    = is_deadline-stage
                                     iv_tail  = lv_tail ).
  ENDMETHOD.

ENDCLASS.
