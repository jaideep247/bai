*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_coverage.clas.testclasses.abap
*& Purpose:
*& Tests of the monitor coverage check with doubles (check registry,
*& evaluation records, licence service, catalogue, in-memory parameters):
*& a licensed check that ran (no finding), one refused by the licence
*& (E), one under a licence warning (W), one disabled by configuration (no
*& finding, shown), one switched off by its business process (disabled),
*& one impaired (W) and one never evaluated (E - a gap, never silence);
*& the coverage check leaves itself out. Does not prove live SAP runtime
*& behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build O: monitor coverage state).
*&---------------------------------------------------------------------*
CLASS ltd_check_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check_dao PARTIALLY IMPLEMENTED.
    DATA mt_registry TYPE zif_ca_ops_chk_types=>tt_check.
ENDCLASS.

CLASS ltd_check_dao IMPLEMENTATION.
  METHOD zif_ca_ops_check_dao~get_registry.
    rt_checks = mt_registry.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_eval_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_eval_dao PARTIALLY IMPLEMENTED.
    DATA mt_latest TYPE zif_ca_ops_eval_types=>tt_eval.
ENDCLASS.

CLASS ltd_eval_dao IMPLEMENTATION.
  METHOD zif_ca_ops_eval_dao~latest.
    rt_eval = mt_latest.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_license DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_license PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_license IMPLEMENTATION.
  METHOD zif_ca_ops_license~modules_of_check.
    " the module is named after the check: ZT_REFUSED needs a refused module, ZT_WARNED a warned one
    CASE is_check-check_id.
      WHEN 'ZT_REFUSED'.
        rt_modules = VALUE #( ( CONV #( 'ZT_MOD_X' ) ) ).
      WHEN 'ZT_WARNED'.
        rt_modules = VALUE #( ( CONV #( 'ZT_MOD_W' ) ) ).
    ENDCASE.
  ENDMETHOD.
  METHOD zif_ca_ops_license~decide.
    rs_decision-module    = iv_module.
    rs_decision-allowed   = xsdbool( iv_module <> 'ZT_MOD_X' ).
    rs_decision-lic_state = zif_ca_ops_lic_types=>gc_lic_state-valid.
    rs_decision-state     = COND #( WHEN iv_module = 'ZT_MOD_W' THEN zif_ca_ops_lic_types=>gc_state-unlicensed
                                    ELSE zif_ca_ops_lic_types=>gc_state-licensed ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_catalog DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_catalog PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_catalog IMPLEMENTATION.
  METHOD zif_ca_ops_catalog~inactive_onboarded.
    rt_processes = VALUE #( ( CONV #( 'ZT_PROC_OFF' ) ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_coverage DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area   TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        now    TYPE timestampl VALUE '20261116090000.0000000',
        recent TYPE timestampl VALUE '20261116080000.0000000',
      END OF gc.

    DATA mo_checks TYPE REF TO ltd_check_dao.
    DATA mo_evals TYPE REF TO ltd_eval_dao.

    METHODS setup.
    METHODS teardown.
    METHODS register
      IMPORTING
        iv_check   TYPE clike
        iv_active  TYPE abap_bool DEFAULT abap_true
        iv_process TYPE clike OPTIONAL
        iv_state   TYPE clike OPTIONAL.
    METHODS state_of
      IMPORTING
        it_rows         TYPE zif_ca_ops_eval_types=>tt_cov_row
        iv_check        TYPE clike
      RETURNING
        VALUE(rv_state) TYPE zif_ca_ops_eval_types=>ty_cov_state.

    METHODS states_and_findings FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_coverage IMPLEMENTATION.

  METHOD setup.
    mo_checks = NEW #( ).
    mo_evals  = NEW #( ).
    zcl_ca_ops_injector=>inject_check_dao( mo_checks ).
    zcl_ca_ops_injector=>inject_eval_dao( mo_evals ).
    zcl_ca_ops_injector=>inject_license( NEW ltd_license( ) ).
    zcl_ca_ops_injector=>inject_catalog( NEW ltd_catalog( ) ).
    zcl_ca_ops_injector=>inject_params( NEW zcl_ca_ops_param_seed( )->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD register.
    INSERT VALUE #( area = gc-area check_id = iv_check process_id = iv_process class_name = 'ZCL_ZT_CHECK'
                    active = iv_active ) INTO TABLE mo_checks->mt_registry.
    IF iv_state IS NOT INITIAL.
      INSERT VALUE #( area = gc-area check_id = iv_check evaluated_at = gc-recent eval_state = iv_state )
             INTO TABLE mo_evals->mt_latest.
    ENDIF.
  ENDMETHOD.


  METHOD state_of.
    rv_state = it_rows[ check_id = iv_check ]-state.
  ENDMETHOD.


  " Rule: licensed / refused / warned / disabled / impaired / ran / not run - and only the gaps are exceptions
  METHOD states_and_findings.
    register( iv_check = 'ZT_RAN' iv_state = zif_ca_ops_eval_types=>gc_state-ok ).
    register( iv_check = 'ZT_REFUSED' iv_state = zif_ca_ops_eval_types=>gc_state-not_evaluated ).
    register( iv_check = 'ZT_WARNED' iv_state = zif_ca_ops_eval_types=>gc_state-findings ).
    register( iv_check = 'ZT_DISABLED' iv_active = abap_false ).
    register( iv_check = 'ZT_PROC_OFF' iv_process = 'ZT_PROC_OFF' iv_state = zif_ca_ops_eval_types=>gc_state-ok ).
    register( iv_check = 'ZT_IMPAIRED' iv_state = zif_ca_ops_eval_types=>gc_state-partial ).
    register( iv_check = 'ZT_NEVER' ).
    register( iv_check = 'COVERAGE' ).
    DATA(ls_check) = VALUE zif_ca_ops_chk_types=>ty_check( area = gc-area check_id = 'COVERAGE' ).
    DATA(ls_context) = VALUE zif_ca_ops_chk_types=>ty_context( area = gc-area today = '20261116' now = gc-now ).
    DATA(lo_cut) = NEW zcl_ca_ops_chk_coverage( ).
    DATA(lt_rows) = lo_cut->coverage( is_check = ls_check is_context = ls_context ).
    cl_abap_unit_assert=>assert_equals( act = state_of( it_rows = lt_rows iv_check = 'ZT_RAN' )
                                        exp = zif_ca_ops_eval_types=>gc_cov-ran msg = 'Licensed, ran' ).
    cl_abap_unit_assert=>assert_equals( act = state_of( it_rows = lt_rows iv_check = 'ZT_REFUSED' )
                                        exp = zif_ca_ops_eval_types=>gc_cov-refused msg = 'Refused' ).
    cl_abap_unit_assert=>assert_equals( act = state_of( it_rows = lt_rows iv_check = 'ZT_WARNED' )
                                        exp = zif_ca_ops_eval_types=>gc_cov-warned msg = 'Warned' ).
    cl_abap_unit_assert=>assert_equals( act = state_of( it_rows = lt_rows iv_check = 'ZT_DISABLED' )
                                        exp = zif_ca_ops_eval_types=>gc_cov-disabled msg = 'Disabled' ).
    cl_abap_unit_assert=>assert_equals( act = state_of( it_rows = lt_rows iv_check = 'ZT_PROC_OFF' )
                                        exp = zif_ca_ops_eval_types=>gc_cov-disabled msg = 'Process switched off' ).
    cl_abap_unit_assert=>assert_equals( act = state_of( it_rows = lt_rows iv_check = 'ZT_IMPAIRED' )
                                        exp = zif_ca_ops_eval_types=>gc_cov-impaired msg = 'Impaired' ).
    cl_abap_unit_assert=>assert_equals( act = state_of( it_rows = lt_rows iv_check = 'ZT_NEVER' )
                                        exp = zif_ca_ops_eval_types=>gc_cov-not_run msg = 'Never evaluated' ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_rows[ check_id = 'COVERAGE' ] ) )
                                       msg = 'Not judging itself' ).

    DATA(ls_result) = lo_cut->zif_ca_ops_check~run( is_check = ls_check is_context = ls_context ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 4
                                        msg = 'Refused, warned, impaired, never run' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ object_key = 'ZT_OPS_A/ZT_NEVER' ]-severity
                                        exp = zif_ca_ops_types=>gc_severity-error msg = 'A gap is an error' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ object_key = 'ZT_OPS_A/ZT_IMPAIRED' ]-severity
                                        exp = zif_ca_ops_types=>gc_severity-warning msg = 'Impaired is a warning' ).
  ENDMETHOD.

ENDCLASS.
