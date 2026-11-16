*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cash_ctx.clas.testclasses.abap
*& Purpose:
*& Tests of the run context of a cash check: the window of the business
*& calendar (working and non-working days), no calendar = an error (never
*& "every day"), the next cutoff today before the control's cutoff time and
*& the next working day after it, an unknown cutoff without cutoff time, a
*& finding completed with owner, cutoff and age, a pending value and a cap
*& that make the check partial; the exception contract of a finding (no
*& gap, evidence key and typed evidence rows). Doubles: cash data access;
*& parameters in memory. Pure logic, no database.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*& 2026-11-16 | FINDING_MEETS_CONTRACT (exception contract, build K merge).
*&---------------------------------------------------------------------*
CLASS ltd_ctx_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cash_dao PARTIALLY IMPLEMENTED.
    DATA mt_holidays TYPE SORTED TABLE OF d WITH UNIQUE KEY table_line.
    DATA ms_owner TYPE zif_ca_ops_cash_types=>ty_owner.
ENDCLASS.

CLASS ltd_ctx_dao IMPLEMENTATION.
  METHOD zif_ca_ops_cash_dao~working_day.
    rv_working = xsdbool( NOT line_exists( mt_holidays[ table_line = iv_date ] ) ).
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~owner.
    rs_owner = ms_owner.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_cash_ctx DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        check TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_CASH',
        today TYPE d VALUE '20261116',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_ctx_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS ctx
      IMPORTING
        iv_now        TYPE timestampl OPTIONAL
      RETURNING
        VALUE(ro_ctx) TYPE REF TO zcl_ca_ops_cash_ctx.

    METHODS window_marks_holidays     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS no_calendar_is_error      FOR TESTING.
    METHODS cutoff_today_before_time  FOR TESTING.
    METHODS cutoff_next_working_day   FOR TESTING.
    METHODS cutoff_unknown_no_time    FOR TESTING.
    METHODS finding_completed         FOR TESTING.
    METHODS finding_meets_contract    FOR TESTING.
    METHODS pending_makes_partial     FOR TESTING.
    METHODS cap_makes_partial         FOR TESTING.
    METHODS factory_double_and_reset  FOR TESTING.
ENDCLASS.


CLASS ltc_cash_ctx IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_cash_injector=>inject_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-calendar iv_value = 'ZT' ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-lookback_days iv_value = '3' ).
    " the weekend 14 / 15 November and the holiday 17 November are not working days
    mo_dao->mt_holidays = VALUE #( ( '20261114' ) ( '20261115' ) ( '20261117' ) ).
    mo_dao->ms_owner = VALUE #( control_id = 'ZT_CTL' owner = 'ZT_OWNER' team = 'ZT_TEAM' cutoff_time = '100000' ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_cash_injector=>reset( ).
  ENDMETHOD.


  METHOD ctx.
    ro_ctx = NEW #( is_check   = VALUE #( area = gc-area check_id = gc-check bukrs_aware = abap_true )
                    is_context = VALUE #( area = gc-area today = gc-today now = iv_now ) ).
  ENDMETHOD.


  " Rule: today - lookback to today - lag, each day with its working-day flag
  METHOD window_marks_holidays.
    DATA(lt_days) = ctx( )->window_days( 1 ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_days[ 1 ] exp = VALUE zif_ca_ops_cash_types=>ty_day(
                                                                   date = '20261113' working = abap_true ) ).
    cl_abap_unit_assert=>assert_false( lt_days[ 2 ]-working ).
    cl_abap_unit_assert=>assert_false( lt_days[ 3 ]-working ).
  ENDMETHOD.


  " Rule: without a business calendar the expected days are unknown - an error, never "every day"
  METHOD no_calendar_is_error.
    mo_seed->remove( zif_ca_ops_cash_types=>gc_param-calendar ).
    TRY.
        ctx( )->window_days( 1 ).
        cl_abap_unit_assert=>fail( ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_true( xsdbool( lx_error->get_text( ) CS zif_ca_ops_cash_types=>gc_param-calendar ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: before the cutoff time of a working day the cutoff is today
  METHOD cutoff_today_before_time.
    DATA(ls_cutoff) = ctx( iv_now = '20261116080000.0000000' )->cutoff( ).

    cl_abap_unit_assert=>assert_true( ls_cutoff-known ).
    cl_abap_unit_assert=>assert_equals( act = ls_cutoff-date exp = '20261116' ).
    cl_abap_unit_assert=>assert_equals( act = ls_cutoff-time exp = '100000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_cutoff-time_zone exp = 'UTC' ).
  ENDMETHOD.


  " Rule: after the cutoff time the next working day (the holiday on the 17th skipped)
  METHOD cutoff_next_working_day.
    cl_abap_unit_assert=>assert_equals( act = ctx( iv_now = '20261116110000.0000000' )->cutoff( )-date
                                        exp = '20261118' ).
  ENDMETHOD.


  " Rule: a control without cutoff time gives no cutoff (said "unknown" in the finding)
  METHOD cutoff_unknown_no_time.
    CLEAR mo_dao->ms_owner-cutoff_time.

    cl_abap_unit_assert=>assert_false( ctx( iv_now = '20261116080000.0000000' )->cutoff( )-known ).
  ENDMETHOD.


  " Rule: the context completes owner, cutoff, age and evaluation before the one mapping
  METHOD finding_completed.
    DATA(ls_finding) = ctx( iv_now = '20261116080000.0000000' )->finding( VALUE #(
                         check_code = zif_ca_ops_cash_types=>gc_code-lot_not_posted
                         severity   = zif_ca_ops_types=>gc_severity-error
                         stage      = zif_ca_ops_cash_types=>gc_stage-posting
                         oldest     = '20261110'
                         msgno      = zif_ca_ops_cash_types=>gc_msg-lot_not_posted ) ).

    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'ZT_OWNER' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS '2026-11-16' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS zif_ca_ops_cash_types=>gc_evaluation-observed ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-business_date exp = '20261110' ).
  ENDMETHOD.


  " Rule: the finding meets the exception contract - deadline from the next cutoff in the calendar, owner of the
  " control, an evidence key of its identity - and its evidence rows are kept once per key for the check result
  METHOD finding_meets_contract.
    DATA(lo_ctx) = ctx( iv_now = '20261116080000.0000000' ).
    DATA(ls_exc) = VALUE zif_ca_ops_cash_types=>ty_exception(
                     check_code   = zif_ca_ops_cash_types=>gc_code-lot_not_posted
                     severity     = zif_ca_ops_types=>gc_severity-error
                     stage        = zif_ca_ops_cash_types=>gc_stage-posting
                     object_key   = 'LOT1'
                     company_code = 'ZT01'
                     currency     = 'EUR'
                     item_count   = 2
                     amount       = '25.00'
                     evidence     = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-lot value = 'LOT1' ) )
                     msgno        = zif_ca_ops_cash_types=>gc_msg-lot_not_posted ).

    DATA(ls_finding) = lo_ctx->finding( ls_exc ).
    lo_ctx->finding( ls_exc ).

    cl_abap_unit_assert=>assert_initial( zcl_ca_ops_exc_contract=>missing( ls_finding ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-calendar_id exp = 'ZT' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-resp_source exp = zif_ca_ops_exc_contract=>gc_resp_source-control ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-evid_key
                                        exp = zcl_ca_ops_exc_contract=>evidence_key( iv_area       = gc-area
                                                                                     iv_check_id   = gc-check
                                                                                     iv_object_key = 'LOT1'
                                                                                     iv_bukrs      = 'ZT01' ) ).
    DATA(lt_evidence) = lo_ctx->evidence( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_evidence ) exp = 1 msg = 'The same finding twice: rows once' ).
    cl_abap_unit_assert=>assert_equals( act = lt_evidence[ 1 ]-evid_key exp = ls_finding-evid_key ).
  ENDMETHOD.


  " Rule: a pending value is "not evaluated" (warning, notification) and makes the check partial
  METHOD pending_makes_partial.
    DATA(lo_ctx) = ctx( ).
    DATA(ls_finding) = lo_ctx->pending( iv_stage  = zif_ca_ops_cash_types=>gc_stage-posting
                                        iv_source = zif_ca_ops_cash_types=>gc_source-lots
                                        iv_param  = zif_ca_ops_cash_types=>gc_param-lot_done_status ).

    cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code exp = zif_ca_ops_cash_types=>gc_code-not_evaluated ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-warning ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-cfg_rule exp = zif_ca_ops_cash_types=>gc_param-lot_done_status ).
    cl_abap_unit_assert=>assert_true( lo_ctx->partial( ) ).
  ENDMETHOD.


  " Rule: as many rows as CASH_MAX_ROWS = the result may be cut: a capped warning, the check partial
  METHOD cap_makes_partial.
    DATA lt_findings TYPE zif_ca_ops_types=>tt_finding.
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-max_rows iv_value = '2' ).
    DATA(lo_ctx) = ctx( ).

    lo_ctx->cap( EXPORTING iv_stage = zif_ca_ops_cash_types=>gc_stage-posting iv_source = 'DFKKZK' iv_rows = 1
                 CHANGING ct_findings = lt_findings ).
    cl_abap_unit_assert=>assert_initial( lt_findings ).
    cl_abap_unit_assert=>assert_false( lo_ctx->partial( ) ).
    lo_ctx->cap( EXPORTING iv_stage = zif_ca_ops_cash_types=>gc_stage-posting iv_source = 'DFKKZK' iv_rows = 2
                 CHANGING ct_findings = lt_findings ).
    cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-check_code exp = zif_ca_ops_cash_types=>gc_code-capped ).
    cl_abap_unit_assert=>assert_true( lo_ctx->partial( ) ).
  ENDMETHOD.

  " Rule: the factory returns the injected double; after the reset a new production instance
  METHOD factory_double_and_reset.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_cash_factory=>get_dao( ) exp = mo_dao ).
    zcl_ca_ops_cash_injector=>reset( ).
    cl_abap_unit_assert=>assert_false( xsdbool( zcl_ca_ops_cash_factory=>get_dao( ) = mo_dao ) ).
  ENDMETHOD.

ENDCLASS.
