*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_due_file.clas.testclasses.abap
*& Purpose:
*& Unit tests of the due-file check: the 2nd working day of the month skips
*& the weekend; on it, no file after due time + grace is DUE_FILE_MISSING,
*& before it nothing; a late file is DUE_FILE_LATE, an empty one
*& DUE_FILE_EMPTY; another day evaluates nothing; a missing DEADLINE row or
*& an unreadable calendar is DUE_FILE_NOT_EVALUATED (never green); the
*& returns rule is due only on a day with a returns file. The calendar is a
*& double (weekends off); does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
CLASS ltd_calendar DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_calendar PARTIALLY IMPLEMENTED.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_calendar IMPLEMENTATION.
  METHOD zif_cd_fmon_calendar~is_working_day.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e206(zcd_ops) WITH iv_calendar_id iv_date.
    ENDIF.
    " 1900-01-01 was a Monday: 6 and 7 are Saturday and Sunday
    rv_working = xsdbool( ( iv_date - CONV d( '19000101' ) ) MOD 7 < 5 ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_due_file DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        iface     TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'BLACKLINE_COLL_OUT',
        ret_iface TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_RET_PNC_IN',
        notif     TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'RETURNS_NOTIF_OUT',
        params    TYPE zif_cd_fmon_types=>ty_params VALUE 'IFACES=BLACKLINE_COLL_OUT;WHEN=BUSDAY;BUSDAY=2;CAL=US',
        ret_param TYPE zif_cd_fmon_types=>ty_params VALUE 'IFACES=RETURNS_NOTIF_OUT;WHEN=RETURNS',
        " Sunday 1 November 2026: Monday the 2nd is the 1st, Tuesday the 3rd the 2nd working day
        bd2       TYPE d VALUE '20261103',
        bd1       TYPE d VALUE '20261102',
        due       TYPE t VALUE '120000',
        tz        TYPE zif_cd_fmon_types=>ty_time_zone VALUE 'UTC',
        before    TYPE timestampl VALUE '20261103110000',
        after     TYPE timestampl VALUE '20261103140000',
        late_at   TYPE timestampl VALUE '20261103133000',
        early_at  TYPE timestampl VALUE '20261103090000',
        name      TYPE zif_cd_fmon_types=>ty_file_name VALUE 'BL_COLL_202610.csv',
      END OF gc.

    DATA mo_calendar TYPE REF TO ltd_calendar.
    DATA ms_ctx TYPE zif_cd_fmon_types=>ty_check_ctx.
    DATA ms_check TYPE zif_cd_fmon_types=>ty_chk.

    METHODS setup.
    METHODS teardown.
    METHODS second_working_day FOR TESTING.
    METHODS missing_after_due FOR TESTING.
    METHODS late_and_empty FOR TESTING.
    METHODS other_day_not_due FOR TESTING.
    METHODS not_evaluated_never_green FOR TESTING.
    METHODS returns_day_only FOR TESTING.

    METHODS act
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.
    METHODS file
      IMPORTING
        iv_iface TYPE zif_cd_fmon_types=>ty_iface_id
        iv_at    TYPE timestampl
        iv_size  TYPE i DEFAULT 100
        iv_type  TYPE zif_cd_fmon_types=>ty_file_type DEFAULT zif_cd_fmon_types=>gc_file_type-other.
ENDCLASS.


CLASS ltc_due_file IMPLEMENTATION.

  METHOD setup.
    mo_calendar = NEW #( ).
    zcl_cd_fmon_injector=>inject_calendar( mo_calendar ).
    ms_check = VALUE #( check_id = 'F_BLKLINE' class_name = 'ZCL_CD_FMON_CHK_DUE_FILE'
                        severity = zif_ca_ops_types=>gc_severity-error active = abap_true params = gc-params ).
    ms_ctx-business_date = gc-bd2.
    ms_ctx-now = gc-after.
    ms_ctx-time_zone = gc-tz.
    INSERT VALUE #( iface_id = gc-iface direction = zif_cd_fmon_types=>gc_direction-outbound active = abap_true )
      INTO TABLE ms_ctx-ifaces.
    INSERT VALUE #( iface_id = gc-notif direction = zif_cd_fmon_types=>gc_direction-outbound active = abap_true )
      INTO TABLE ms_ctx-ifaces.
    INSERT VALUE #( iface_id = gc-iface stage = zif_cd_fmon_types=>gc_stage-generated
                    kind = zif_cd_fmon_types=>gc_sla_kind-deadline day_type = zif_cd_fmon_types=>gc_wildcard
                    due_time = gc-due ) INTO TABLE ms_ctx-slas.
    INSERT VALUE #( iface_id = gc-notif stage = zif_cd_fmon_types=>gc_stage-generated
                    kind = zif_cd_fmon_types=>gc_sla_kind-deadline day_type = zif_cd_fmon_types=>gc_wildcard
                    due_time = gc-due ) INTO TABLE ms_ctx-slas.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_fmon_injector=>reset( ).
  ENDMETHOD.


  METHOD act.
    TRY.
        rt_findings = NEW zcl_cd_fmon_chk_due_file( )->zif_cd_fmon_check~execute( is_ctx = ms_ctx is_check = ms_check ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD file.
    DATA(lv_id) = CONV zif_cd_fmon_types=>ty_file_id( lines( ms_ctx-files ) + 1 ).
    INSERT VALUE #( file_id = lv_id iface_id = iv_iface business_date = ms_ctx-business_date
                    first_event_at = iv_at size_known = abap_true size_bytes = iv_size record_count = 1
                    file_type = iv_type file_name = gc-name ) INTO TABLE ms_ctx-files.
  ENDMETHOD.


  " Rule: the 2nd working day skips the weekend and the 1st working day
  METHOD second_working_day.
    TRY.
        DATA(lv_due) = NEW zcl_cd_fmon_chk_due_file( )->nth_working_day( iv_date = gc-bd1 iv_n = 2 iv_calendar_id = 'US' ).
        cl_abap_unit_assert=>assert_equals( act = lv_due exp = gc-bd2 msg = 'Tuesday 3 November' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no file after due time + grace on the due day = missing, before it nothing
  METHOD missing_after_due.
    DATA(lt_found) = act( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_found ) exp = 1 msg = 'One missing file' ).
    cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-check_code exp = zcl_cd_fmon_chk_due_file=>gc_code-missing
                                        msg = 'Missing' ).
    cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-business_date exp = gc-bd2 msg = 'Due date' ).
    ms_ctx-now = gc-before.
    cl_abap_unit_assert=>assert_initial( act = act( ) msg = 'Not yet due' ).
  ENDMETHOD.


  " Rule: a file after the due time is late; a file of 0 bytes is empty
  METHOD late_and_empty.
    file( iv_iface = gc-iface iv_at = gc-late_at iv_size = 0 ).
    DATA(lt_found) = act( ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_found[ check_code = zcl_cd_fmon_chk_due_file=>gc_code-late ] ) )
                                      msg = 'Late' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_found[ check_code = zcl_cd_fmon_chk_due_file=>gc_code-empty ] ) )
                                      msg = 'Empty' ).
    CLEAR ms_ctx-files.
    file( iv_iface = gc-iface iv_at = gc-early_at ).
    cl_abap_unit_assert=>assert_initial( act = act( ) msg = 'In time and filled: nothing' ).
  ENDMETHOD.


  " Rule: on any other day nothing is evaluated
  METHOD other_day_not_due.
    ms_ctx-business_date = gc-bd1.
    cl_abap_unit_assert=>assert_initial( act = act( ) msg = 'The 1st working day is not the due day' ).
  ENDMETHOD.


  " Rule: no DEADLINE row or an unreadable calendar is a not-evaluated finding, never silence
  METHOD not_evaluated_never_green.
    CLEAR ms_ctx-slas.
    DATA(lt_found) = act( ).
    cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-check_code
                                        exp = zcl_cd_fmon_chk_due_file=>gc_code-not_evaluated msg = 'No DEADLINE row' ).
    mo_calendar->mv_fail = abap_true.
    lt_found = act( ).
    cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-check_code
                                        exp = zcl_cd_fmon_chk_due_file=>gc_code-not_evaluated msg = 'Calendar' ).
    cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-error
                                        msg = 'Error' ).
  ENDMETHOD.


  " Rule: the returns notification is due only on a day with a returns file
  METHOD returns_day_only.
    ms_check-params = gc-ret_param.
    cl_abap_unit_assert=>assert_initial( act = act( ) msg = 'No returns file: nothing due' ).
    file( iv_iface = gc-ret_iface iv_at = gc-early_at iv_type = zif_cd_fmon_types=>gc_file_type-returns ).
    DATA(lt_found) = act( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_found ) exp = 1 msg = 'Notification missing' ).
    cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-group1 exp = gc-notif msg = 'Notification interface' ).
  ENDMETHOD.

ENDCLASS.
