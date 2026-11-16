*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_due_file.clas.abap
*& Purpose:
*& Plug-in check of an outbound file due on a business day by a clock time
*& (build R): the BlackLine extracts on the n-th business day of the month
*& (WHEN=BUSDAY;BUSDAY=2, control BLACKLINE, proposal P4) and the returns
*& notification to the source on a day with a returns file (WHEN=RETURNS,
*& control RETURNS_NOTIF, proposal P7). Interfaces from PARAMS IFACES; the
*& due time is the DEADLINE row of ZCD_FMON_SLA of the interface (day type
*& *, any stage), local time FMON_TIME_ZONE. On the due day: no file of the
*& interface by the due time + GRACE_MIN = DUE_FILE_MISSING (row severity),
*& a file first seen after the due time = DUE_FILE_LATE (W), only empty files
*& (size known and 0 bytes, or COUNT=X and 0 records) = DUE_FILE_EMPTY (E).
*& An interface that is not active, without DEADLINE row, or a calendar that
*& cannot be read = DUE_FILE_NOT_EVALUATED (E): never green. Object key
*& <interface>/<due date>. The only FMON check that reads the factory
*& calendar (through ZCL_CD_FMON_FACTORY, injectable); no SQL.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - outbound file due on a business day</p>
"! Params: IFACES=A,B;WHEN=BUSDAY;BUSDAY=2;CAL=US;GRACE_MIN=60;COUNT=X;CONTROL=BLACKLINE
"! or IFACES=..;WHEN=RETURNS;CONTROL=RETURNS_NOTIF
CLASS zcl_cd_fmon_chk_due_file DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

    CONSTANTS:
      BEGIN OF gc_code,
        missing       TYPE zif_ca_ops_types=>ty_check_code VALUE 'DUE_FILE_MISSING',
        late          TYPE zif_ca_ops_types=>ty_check_code VALUE 'DUE_FILE_LATE',
        empty         TYPE zif_ca_ops_types=>ty_check_code VALUE 'DUE_FILE_EMPTY',
        not_evaluated TYPE zif_ca_ops_types=>ty_check_code VALUE 'DUE_FILE_NOT_EVALUATED',
      END OF gc_code.
    CONSTANTS:
      BEGIN OF gc_when,
        busday  TYPE string VALUE `BUSDAY`,
        returns TYPE string VALUE `RETURNS`,
      END OF gc_when.

    "! The n-th working day of the month of iv_date (initial when the month has fewer)
    "! @raising zcx_ca_ops_error | the factory calendar cannot be read
    METHODS nth_working_day
      IMPORTING
        iv_date        TYPE d
        iv_n           TYPE i
        iv_calendar_id TYPE zif_cd_fmon_types=>ty_fcal_id
      RETURNING
        VALUE(rv_date) TYPE d
      RAISING
        zcx_ca_ops_error.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_param,
        ifaces  TYPE string VALUE `IFACES`,
        when    TYPE string VALUE `WHEN`,
        busday  TYPE string VALUE `BUSDAY`,
        cal     TYPE string VALUE `CAL`,
        count   TYPE string VALUE `COUNT`,
        control TYPE string VALUE `CONTROL`,
      END OF gc_param.
    CONSTANTS gc_default_busday TYPE i VALUE 2.
    CONSTANTS gc_max_month_days TYPE i VALUE 31.
    CONSTANTS gc_yes TYPE string VALUE `X`.
    CONSTANTS gc_first_day TYPE n LENGTH 2 VALUE '01'.

    CONSTANTS:
      BEGIN OF gc_msg,
        missing         TYPE zif_ca_ops_types=>ty_msgno VALUE '906',
        late            TYPE zif_ca_ops_types=>ty_msgno VALUE '907',
        empty           TYPE zif_ca_ops_types=>ty_msgno VALUE '908',
        not_evaluated   TYPE zif_ca_ops_types=>ty_msgno VALUE '909',
        ctx_deadline    TYPE zif_ca_ops_types=>ty_msgno VALUE '913',
        ctx_control     TYPE zif_ca_ops_types=>ty_msgno VALUE '915',
        ctx_evidence    TYPE zif_ca_ops_types=>ty_msgno VALUE '917',
        no_deadline_row TYPE zif_ca_ops_types=>ty_msgno VALUE '918',
        calendar        TYPE zif_ca_ops_types=>ty_msgno VALUE '919',
        not_active      TYPE zif_ca_ops_types=>ty_msgno VALUE '920',
        unknown_rule    TYPE zif_ca_ops_types=>ty_msgno VALUE '921',
      END OF gc_msg.

    "! Due date of the interface for the business date (initial = nothing due today)
    "! @raising zcx_ca_ops_error | the factory calendar cannot be read
    METHODS due_date
      IMPORTING
        is_ctx         TYPE zif_cd_fmon_types=>ty_check_ctx
        is_check       TYPE zif_cd_fmon_types=>ty_chk
      RETURNING
        VALUE(rv_date) TYPE d
      RAISING
        zcx_ca_ops_error.

    "! The interface's DEADLINE row (day type *, earliest due time); initial = none
    METHODS deadline_row
      IMPORTING
        it_slas       TYPE zif_cd_fmon_types=>tt_sla
        iv_iface_id   TYPE zif_cd_fmon_types=>ty_iface_id
      RETURNING
        VALUE(rs_sla) TYPE zif_cd_fmon_types=>ty_sla.

    METHODS finding
      IMPORTING
        is_check          TYPE zif_cd_fmon_types=>ty_chk
        iv_iface_id       TYPE zif_cd_fmon_types=>ty_iface_id
        iv_due            TYPE d
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
        iv_severity       TYPE zif_ca_ops_types=>ty_severity
        iv_message        TYPE string
        iv_due_time       TYPE t OPTIONAL
        is_file           TYPE zif_cd_fmon_types=>ty_file OPTIONAL
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

ENDCLASS.



CLASS zcl_cd_fmon_chk_due_file IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    DATA lv_due_date TYPE d.
    DATA lv_due_ts TYPE timestampl.
    DATA lv_grace_ts TYPE timestampl.
    DATA lt_files TYPE zif_cd_fmon_types=>tt_file.
    DATA lv_reason TYPE string.

    DATA(lv_grace) = zcl_cd_fmon_util=>param_int( iv_params  = is_check-params
                                                  iv_name    = zif_cd_fmon_types=>gc_check_param-grace_min
                                                  iv_default = zif_cd_fmon_types=>gc_check_param_default-grace_min ).
    DATA(lv_count_empty) = xsdbool( to_upper( zcl_cd_fmon_util=>param( iv_params = is_check-params
                                                                       iv_name   = gc_param-count ) ) = gc_yes ).
    DATA(lt_ifaces) = zcl_ca_ops_util=>split_list( zcl_cd_fmon_util=>param( iv_params = is_check-params
                                                                            iv_name   = gc_param-ifaces ) ).
    TRY.
        lv_due_date = due_date( is_ctx = is_ctx is_check = is_check ).
      CATCH zcx_ca_ops_error INTO DATA(lx_due).
        lv_reason = lx_due->get_text( ).
        lv_due_date = is_ctx-business_date.
    ENDTRY.
    IF lv_due_date IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_ifaces ASSIGNING FIELD-SYMBOL(<lv_iface>).
      DATA(lv_iface_id) = CONV zif_cd_fmon_types=>ty_iface_id( to_upper( condense( <lv_iface> ) ) ).
      DATA(ls_sla) = deadline_row( it_slas = is_ctx-slas iv_iface_id = lv_iface_id ).
      DATA(lv_not_evaluated) = COND string(
        WHEN lv_reason IS NOT INITIAL THEN lv_reason
        WHEN NOT line_exists( is_ctx-ifaces[ iface_id = lv_iface_id ] )
          THEN zcl_cd_ops_util=>text( iv_msgno = gc_msg-not_active )
        WHEN ls_sla IS INITIAL THEN zcl_cd_ops_util=>text( iv_msgno = gc_msg-no_deadline_row ) ).
      IF lv_not_evaluated IS NOT INITIAL.
        INSERT finding( is_check    = is_check
                        iv_iface_id = lv_iface_id
                        iv_due      = lv_due_date
                        iv_code     = gc_code-not_evaluated
                        iv_severity = zif_ca_ops_types=>gc_severity-error
                        iv_message  = zcl_cd_ops_util=>text( iv_msgno = gc_msg-not_evaluated
                                                             iv_v1    = lv_iface_id
                                                             iv_tail  = lv_not_evaluated ) ) INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.

      CONVERT DATE lv_due_date TIME ls_sla-due_time INTO TIME STAMP lv_due_ts TIME ZONE is_ctx-time_zone.
      lv_grace_ts = zcl_cd_fmon_util=>add_minutes( iv_timestamp = lv_due_ts iv_minutes = lv_grace ).
      " Files of the period: from the first day of the due month (BUSDAY) or of the day (RETURNS)
      DATA(lv_from) = COND d( WHEN to_upper( zcl_cd_fmon_util=>param( iv_params = is_check-params
                                                                       iv_name   = gc_param-when ) ) = gc_when-busday
                              THEN |{ lv_due_date(6) }{ gc_first_day }|
                              ELSE lv_due_date ).
      lt_files = VALUE #( FOR ls_file IN is_ctx-files USING KEY by_iface
                          WHERE ( iface_id = lv_iface_id AND business_date >= lv_from
                                  AND business_date <= is_ctx-business_date )
                          ( ls_file ) ).
      DATA(lv_severity) = COND zif_ca_ops_types=>ty_severity(
                            WHEN ls_sla-severity IS NOT INITIAL THEN ls_sla-severity
                            WHEN is_check-severity IS NOT INITIAL THEN is_check-severity
                            ELSE zif_ca_ops_types=>gc_severity-error ).
      IF lt_files IS INITIAL.
        IF is_ctx-now >= lv_grace_ts.
          INSERT finding( is_check    = is_check
                          iv_iface_id = lv_iface_id
                          iv_due      = lv_due_date
                          iv_due_time = ls_sla-due_time
                          iv_code     = gc_code-missing
                          iv_severity = lv_severity
                          iv_message  = zcl_cd_ops_util=>text( iv_msgno = gc_msg-missing
                                                               iv_v1    = lv_iface_id
                                                               iv_v2    = lv_due_date
                                                               iv_v3    = ls_sla-due_time ) ) INTO TABLE rt_findings.
        ENDIF.
        CONTINUE.
      ENDIF.

      SORT lt_files BY first_event_at.
      DATA(ls_first) = lt_files[ 1 ].
      DATA(lv_filled) = abap_false.
      LOOP AT lt_files ASSIGNING FIELD-SYMBOL(<ls_file>).
        IF NOT ( ( <ls_file>-size_known = abap_true AND <ls_file>-size_bytes <= 0 )
                 OR ( lv_count_empty = abap_true AND <ls_file>-record_count <= 0 ) ).
          lv_filled = abap_true.
        ENDIF.
      ENDLOOP.
      IF lv_filled = abap_false.
        INSERT finding( is_check    = is_check
                        iv_iface_id = lv_iface_id
                        iv_due      = lv_due_date
                        iv_due_time = ls_sla-due_time
                        iv_code     = gc_code-empty
                        iv_severity = zif_ca_ops_types=>gc_severity-error
                        is_file     = ls_first
                        iv_message  = zcl_cd_ops_util=>text( iv_msgno = gc_msg-empty
                                                             iv_v1    = lv_iface_id
                                                             iv_v2    = lv_due_date
                                                             iv_v3    = ls_first-file_name ) ) INTO TABLE rt_findings.
      ENDIF.
      IF ls_first-first_event_at > lv_due_ts.
        INSERT finding( is_check    = is_check
                        iv_iface_id = lv_iface_id
                        iv_due      = lv_due_date
                        iv_due_time = ls_sla-due_time
                        iv_code     = gc_code-late
                        iv_severity = zif_ca_ops_types=>gc_severity-warning
                        is_file     = ls_first
                        iv_message  = zcl_cd_ops_util=>text( iv_msgno = gc_msg-late
                                                             iv_v1    = lv_iface_id
                                                             iv_v2    = lv_due_date
                                                             iv_v3    = ls_sla-due_time
                                                             iv_v4    = ls_first-first_event_at ) ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD due_date.
    DATA(lv_when) = to_upper( zcl_cd_fmon_util=>param( iv_params  = is_check-params
                                                       iv_name    = gc_param-when
                                                       iv_default = gc_when-busday ) ).
    CASE lv_when.
      WHEN gc_when-busday.
        DATA(lv_due) = nth_working_day(
                         iv_date        = is_ctx-business_date
                         iv_n           = zcl_cd_fmon_util=>param_int( iv_params  = is_check-params
                                                                       iv_name    = gc_param-busday
                                                                       iv_default = gc_default_busday )
                         iv_calendar_id = CONV #( to_upper( zcl_cd_fmon_util=>param( iv_params = is_check-params
                                                                                     iv_name   = gc_param-cal ) ) ) ).
        rv_date = COND #( WHEN lv_due = is_ctx-business_date THEN lv_due ).
      WHEN gc_when-returns.
        " Due on a day with a returns file of the day (the notification reports its returns to the source)
        LOOP AT is_ctx-files TRANSPORTING NO FIELDS
             WHERE file_type = zif_cd_fmon_types=>gc_file_type-returns AND business_date = is_ctx-business_date.
          rv_date = is_ctx-business_date.
          EXIT.
        ENDLOOP.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e921(zcd_ops) WITH lv_when.
    ENDCASE.
  ENDMETHOD.


  METHOD nth_working_day.
    DATA lv_day TYPE d.
    DATA lv_found TYPE i.
    IF iv_n <= 0 OR iv_calendar_id IS INITIAL OR zcl_cd_hck_exposure=>is_unset( iv_calendar_id ) = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e919(zcd_ops) WITH iv_calendar_id.
    ENDIF.
    DATA(lo_calendar) = zcl_cd_fmon_factory=>get_calendar( ).
    lv_day = |{ iv_date(6) }{ gc_first_day }|.
    DO gc_max_month_days TIMES.
      IF lv_day+4(2) <> iv_date+4(2).
        RETURN.
      ENDIF.
      IF lo_calendar->is_working_day( iv_date = lv_day iv_calendar_id = iv_calendar_id ) = abap_true.
        lv_found = lv_found + 1.
        IF lv_found = iv_n.
          rv_date = lv_day.
          RETURN.
        ENDIF.
      ENDIF.
      lv_day = lv_day + 1.
    ENDDO.
  ENDMETHOD.


  METHOD deadline_row.
    LOOP AT it_slas ASSIGNING FIELD-SYMBOL(<ls_sla>)
         WHERE iface_id = iv_iface_id AND kind = zif_cd_fmon_types=>gc_sla_kind-deadline
           AND day_type = zif_cd_fmon_types=>gc_wildcard.
      IF rs_sla IS INITIAL OR <ls_sla>-due_time < rs_sla-due_time.
        rs_sla = <ls_sla>.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD finding.
    rs_finding = zcl_cd_fmon_util=>new_key_finding(
                   iv_iface_id      = iv_iface_id
                   iv_business_date = iv_due
                   iv_object_key    = zcl_cd_fmon_util=>iface_day_key( iv_iface_id = iv_iface_id iv_date = iv_due )
                   is_check         = is_check
                   iv_code          = iv_code
                   iv_message       = iv_message
                   iv_severity      = iv_severity ).
    rs_finding-item_count = is_file-record_count.
    rs_finding-amount     = is_file-control_total.
    rs_finding-reference  = is_file-file_ref.
    rs_finding-event_at   = is_file-first_event_at.
    rs_finding-context    = concat_lines_of(
                              sep   = cl_abap_char_utilities=>newline
                              table = VALUE string_table(
                                ( zcl_cd_ops_util=>text( iv_msgno = gc_msg-ctx_deadline
                                                         iv_v1    = |{ iv_due } { iv_due_time }| ) )
                                ( zcl_cd_ops_util=>text( iv_msgno = gc_msg-ctx_control
                                                         iv_v1    = zcl_cd_fmon_util=>param(
                                                                      iv_params  = is_check-params
                                                                      iv_name    = gc_param-control
                                                                      iv_default = CONV #( is_check-check_id ) ) ) )
                                ( zcl_cd_ops_util=>text( iv_msgno = gc_msg-ctx_evidence
                                                         iv_v1    = |{ iv_iface_id } { is_file-file_name }| ) ) ) ).
  ENDMETHOD.

ENDCLASS.
