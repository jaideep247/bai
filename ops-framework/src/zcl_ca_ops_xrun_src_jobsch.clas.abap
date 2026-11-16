*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_xrun_src_jobsch.clas.abap
*& Purpose:
*& Delivered expected-run source "expected by configuration" (docs/
*& EXPECTED_RUNS_AND_MASS_ACTIVITIES.md section 2.2): the plan of the
*& framework's own scheduler job configuration ZCA_OPS_JOBSCH (active
*& rows with run days) - for every requested day whose weekday the row
*& names, one expected run at the row's planned start with its late limit,
*& predecessor and the SAP job names it starts; a day the row's business
*& calendar does not expect is returned as "not expected" (holiday), a
*& day the calendar cannot answer as "unknown" (never a holiday), a row
*& whose run days are not seven characters X / blank as "invalid". The
*& calendar is the class of XRUN_CALENDAR_CLASS (ZIF_CA_OPS_XRUN_CALENDAR;
*& the FI-CA Cash Operations pack delivers one on the cash checks'
*& factory calendar). The configuration knows no scheduler state (blank)
*& and is as fresh as the read. Reads through the job monitor's data
*& access only; read-only.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - expected runs from scheduler rows</p>
CLASS zcl_ca_ops_xrun_src_jobsch DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_expected_run_src.

    "! ID of the source (evidence rows, evaluation record)
    CONSTANTS gc_id TYPE zif_ca_ops_xrun_types=>ty_source_id VALUE 'JOBSCH'.

    "! @parameter io_dao      | Data access of the job monitor (tests: a double)
    "! @parameter io_calendar | Business calendar (tests: a double; else XRUN_CALENDAR_CLASS)
    METHODS constructor
      IMPORTING
        io_dao      TYPE REF TO zif_ca_ops_job_dao OPTIONAL
        io_calendar TYPE REF TO zif_ca_ops_xrun_calendar OPTIONAL.

    "! Weekday of a date: 1 = Monday ... 7 = Sunday
    CLASS-METHODS weekday
      IMPORTING
        iv_date       TYPE d
      RETURNING
        VALUE(rv_day) TYPE i.

    "! X = the run days are seven characters, each X or blank
    CLASS-METHODS days_valid
      IMPORTING
        iv_days         TYPE zif_ca_ops_xrun_types=>ty_plan_days
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

  PRIVATE SECTION.
    "! A Monday: weekdays are counted from it
    CONSTANTS gc_monday TYPE d VALUE '19000101'.
    CONSTANTS gc_days_per_week TYPE i VALUE 7.

    DATA mo_dao TYPE REF TO zif_ca_ops_job_dao.
    DATA mo_calendar TYPE REF TO zif_ca_ops_xrun_calendar.

    "! The business calendar (created once from XRUN_CALENDAR_CLASS)
    "! @raising zcx_ca_ops_error | none configured (610) or the class is not usable
    METHODS calendar
      RETURNING
        VALUE(ro_calendar) TYPE REF TO zif_ca_ops_xrun_calendar
      RAISING
        zcx_ca_ops_error.

    "! The days of one row: expected runs, holidays, unknown days
    METHODS plan_row
      IMPORTING
        is_row     TYPE zif_ca_ops_job_types=>ty_sched
        is_request TYPE zif_ca_ops_xrun_types=>ty_request
      CHANGING
        cs_plan    TYPE zif_ca_ops_xrun_types=>ty_plan.

ENDCLASS.



CLASS zcl_ca_ops_xrun_src_jobsch IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_job_dao( ) ).
    mo_calendar = io_calendar.
  ENDMETHOD.


  METHOD zif_ca_ops_expected_run_src~id.
    rv_id = gc_id.
  ENDMETHOD.


  METHOD zif_ca_ops_expected_run_src~read.
    " the configuration is as fresh as this read: it never makes the evaluation stale
    rs_plan-newest_at = is_request-now.
    LOOP AT mo_dao->scheduler_jobs( ) ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE plan_days IS NOT INITIAL.
      IF days_valid( <ls_row>-plan_days ) = abap_false.
        INSERT VALUE #( sched_folder = <ls_row>-sched_folder
                        sched_job    = <ls_row>-sched_job
                        reason       = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_xrun_types=>gc_msg-plan_days
                                                              iv_v1    = <ls_row>-sched_folder
                                                              iv_v2    = <ls_row>-sched_job
                                                              iv_v3    = <ls_row>-plan_days ) ) INTO TABLE rs_plan-invalid.
        CONTINUE.
      ENDIF.
      plan_row( EXPORTING is_row     = <ls_row>
                          is_request = is_request
                CHANGING  cs_plan    = rs_plan ).
      IF rs_plan-partial = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD plan_row.
    DATA lv_business TYPE abap_bool.

    DATA(lv_date) = is_request-from_date.
    WHILE lv_date <= is_request-to_date.
      DATA(lv_offset) = weekday( lv_date ) - 1.
      IF is_row-plan_days+lv_offset(1) <> zif_ca_ops_xrun_types=>gc_day_runs.
        lv_date = lv_date + 1.
        CONTINUE.
      ENDIF.
      IF is_row-calendar_id IS NOT INITIAL.
        TRY.
            lv_business = calendar( )->is_business_day( iv_calendar_id = is_row-calendar_id iv_date = lv_date ).
          CATCH zcx_ca_ops_error INTO DATA(lx_calendar).
            " a calendar that cannot answer leaves the day unknown - never a holiday, never expected in silence
            INSERT VALUE #( sched_folder = is_row-sched_folder
                            sched_job    = is_row-sched_job
                            plan_date    = lv_date
                            calendar_id  = is_row-calendar_id
                            reason       = lx_calendar->get_text( ) ) INTO TABLE cs_plan-unknown.
            lv_date = lv_date + 1.
            CONTINUE.
        ENDTRY.
        IF lv_business = abap_false.
          INSERT VALUE #( sched_folder = is_row-sched_folder
                          sched_job    = is_row-sched_job
                          plan_date    = lv_date
                          calendar_id  = is_row-calendar_id ) INTO TABLE cs_plan-not_expected.
          lv_date = lv_date + 1.
          CONTINUE.
        ENDIF.
      ENDIF.
      IF is_request-max > 0 AND lines( cs_plan-runs ) >= is_request-max.
        cs_plan-partial = abap_true.
        RETURN.
      ENDIF.
      INSERT VALUE #( source_id    = gc_id
                      sched_folder = is_row-sched_folder
                      sched_job    = is_row-sched_job
                      sap_pattern  = is_row-sap_pattern
                      plan_date    = lv_date
                      plan_time    = is_row-plan_time
                      late_min     = is_row-late_min
                      pred_folder  = is_row-pred_folder
                      pred_job     = is_row-pred_job
                      criticality  = is_row-criticality ) INTO TABLE cs_plan-runs.
      lv_date = lv_date + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD calendar.
    IF mo_calendar IS BOUND.
      ro_calendar = mo_calendar.
      RETURN.
    ENDIF.
    DATA(lv_class) = CONV zif_ca_ops_types=>ty_class_name( to_upper( condense(
                       zcl_ca_ops_factory=>get_params( )->get_param( zif_ca_ops_xrun_types=>gc_param-calendar ) ) ) ).
    IF lv_class IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e610(zca_ops) WITH zif_ca_ops_xrun_types=>gc_param-calendar.
    ENDIF.
    mo_calendar = CAST zif_ca_ops_xrun_calendar( zcl_ca_ops_factory=>get_plugin(
                    iv_class_name = lv_class
                    iv_interface  = zif_ca_ops_xrun_types=>gc_plugin_intf-calendar ) ).
    ro_calendar = mo_calendar.
  ENDMETHOD.


  METHOD weekday.
    rv_day = ( iv_date - gc_monday ) MOD gc_days_per_week + 1.
  ENDMETHOD.


  METHOD days_valid.
    " every character that is not blank is X (blanks inside the field are days without a run)
    rv_valid = xsdbool( replace( val = CONV string( iv_days ) sub = ` ` with = `` occ = 0 )
                        CO zif_ca_ops_xrun_types=>gc_day_runs ).
  ENDMETHOD.

ENDCLASS.
