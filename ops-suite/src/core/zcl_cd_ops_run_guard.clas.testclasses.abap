*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_run_guard.clas.testclasses.abap
*& Purpose:
*& Tests of the refused run: a second run while the lock is held becomes an
*& aborted, red run with one RUN_LOCKED finding that is alerted once and is
*& recognisable by the reports. Written before the class. Does not prove live
*& SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (run lock).
*& 2026-11-06 | Modern-syntax sweep: no trailing RETURN.
*&---------------------------------------------------------------------*
CLASS ltd_alert DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert.
    DATA mv_dispatch_calls TYPE i.
    DATA mt_dispatched TYPE zif_cd_ops_types=>tt_finding.
ENDCLASS.

CLASS ltd_alert IMPLEMENTATION.
  METHOD zif_cd_ops_alert~send.
  ENDMETHOD.
  METHOD zif_cd_ops_alert~dispatch.
    mv_dispatch_calls += 1.
    mt_dispatched = it_findings.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = '20261106070000.0000000'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261106'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = '070000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_run_guard DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_holder TYPE syuname VALUE 'BATCH_OTHER'.
    DATA mo_alert TYPE REF TO ltd_alert.

    METHODS setup.
    METHODS teardown.
    METHODS refuse
      RETURNING
        VALUE(rs_refusal) TYPE zcl_cd_ops_run_guard=>ty_refusal.

    METHODS refusal_is_aborted_red_run FOR TESTING.
    METHODS refusal_is_alerted_once    FOR TESTING.
    METHODS refusal_is_recognised      FOR TESTING.
    METHODS normal_run_not_refused     FOR TESTING.
ENDCLASS.


CLASS ltc_run_guard IMPLEMENTATION.

  METHOD setup.
    mo_alert = NEW #( ).
    zcl_cd_ops_injector=>inject_alert( mo_alert ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_alert.
  ENDMETHOD.


  METHOD refuse.
    rs_refusal = zcl_cd_ops_run_guard=>refuse( iv_pe_area  = zif_cd_ops_types=>gc_pe_area-ebs
                                               iv_variant = 'DAILY'
                                               iv_holder  = gc_holder ).
  ENDMETHOD.


  " Rule: a refused run is visible as an aborted, red run - never as a green no-op
  METHOD refusal_is_aborted_red_run.
    TRY.
        DATA(ls_refusal) = refuse( ).
        cl_abap_unit_assert=>assert_equals( act = ls_refusal-run-status exp = zif_cd_ops_types=>gc_run_status-aborted
                                            msg = 'A refused run must be aborted' ).
        cl_abap_unit_assert=>assert_equals( act = ls_refusal-run-rag exp = zif_cd_ops_types=>gc_rag-red
                                            msg = 'A refused run must be red' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_refusal-findings ) exp = 1
                                            msg = 'Exactly one RUN_LOCKED finding is expected' ).
        cl_abap_unit_assert=>assert_equals( act = ls_refusal-findings[ 1 ]-check_code
                                            exp = zcl_cd_ops_run_guard=>gc_check_code
                                            msg = 'The finding must be RUN_LOCKED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: whoever runs the job is told once, through the alert router
  METHOD refusal_is_alerted_once.
    TRY.
        refuse( ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatch_calls exp = 1
                                            msg = 'The refusal must be dispatched once' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mt_dispatched[ 1 ]-check_code
                                            exp = zcl_cd_ops_run_guard=>gc_check_code
                                            msg = 'RUN_LOCKED must reach the alert router' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: reports recognise a refusal from the result's findings
  METHOD refusal_is_recognised.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_run_guard=>was_refused( refuse( )-findings )
                                          msg = 'The refusal must be recognised' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an ordinary result is not mistaken for a refusal
  METHOD normal_run_not_refused.
    DATA lt_findings TYPE zif_cd_ops_types=>tt_finding.
    DATA ls_finding TYPE zif_cd_ops_types=>ty_finding.
    ls_finding-check_code = 'PLUGIN_ERROR'.
    INSERT ls_finding INTO TABLE lt_findings.
    cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_run_guard=>was_refused( lt_findings )
                                       msg = 'Other findings are not a refusal' ).
  ENDMETHOD.

ENDCLASS.
