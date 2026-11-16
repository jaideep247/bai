*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_coverage.clas.testclasses.abap
*& Purpose:
*& Tests of the monitor coverage rule (pure): a licensed check that ran in
*& its window (RAN), one refused by the licence (REFUSED, before anything
*& else but configuration), one running under a licence warning (WARNED),
*& one switched off by configuration (DISABLED), one whose latest
*& evaluation is not evaluated / stale / partial (IMPAIRED) and one without
*& an evaluation in its window (NOT_RUN - a gap, never silence). The same
*& scenarios as config/evaluation/fixtures.json. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build O: monitor coverage state).
*&---------------------------------------------------------------------*
CLASS ltc_coverage DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_now TYPE timestampl VALUE '20261116080000.0000000'.

    "! A licensed, active check evaluated OK 10 minutes ago, window 60 minutes
    METHODS base
      RETURNING
        VALUE(rs_input) TYPE zif_ca_ops_eval_types=>ty_cov_input.

    METHODS licensed_ran      FOR TESTING.
    METHODS refused           FOR TESTING.
    METHODS warned            FOR TESTING.
    METHODS disabled          FOR TESTING.
    METHODS impaired          FOR TESTING.
    METHODS not_run_no_eval   FOR TESTING.
    METHODS not_run_old_eval  FOR TESTING.
    METHODS gaps              FOR TESTING.
ENDCLASS.


CLASS ltc_coverage IMPLEMENTATION.

  METHOD base.
    rs_input = VALUE #( active       = abap_true
                        lic_allowed  = abap_true
                        has_eval     = abap_true
                        evaluated_at = '20261116075000.0000000'
                        eval_state   = zif_ca_ops_eval_types=>gc_state-ok
                        now          = gc_now
                        window_min   = 60 ).
  ENDMETHOD.


  METHOD licensed_ran.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_coverage=>state( base( ) )
                                        exp = zif_ca_ops_eval_types=>gc_cov-ran msg = 'Ran' ).
  ENDMETHOD.


  METHOD refused.
    DATA(ls_input) = base( ).
    ls_input-lic_allowed = abap_false.
    CLEAR ls_input-has_eval.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_coverage=>state( ls_input )
                                        exp = zif_ca_ops_eval_types=>gc_cov-refused msg = 'Refused before not run' ).
  ENDMETHOD.


  METHOD warned.
    DATA(ls_input) = base( ).
    ls_input-lic_warned = abap_true.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_coverage=>state( ls_input )
                                        exp = zif_ca_ops_eval_types=>gc_cov-warned msg = 'Warned' ).
  ENDMETHOD.


  METHOD disabled.
    DATA(ls_input) = base( ).
    ls_input-active      = abap_false.
    ls_input-lic_allowed = abap_false.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_coverage=>state( ls_input )
                                        exp = zif_ca_ops_eval_types=>gc_cov-disabled msg = 'Configuration first' ).
  ENDMETHOD.


  METHOD impaired.
    DATA(ls_input) = base( ).
    ls_input-eval_state = zif_ca_ops_eval_types=>gc_state-partial.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_coverage=>state( ls_input )
                                        exp = zif_ca_ops_eval_types=>gc_cov-impaired msg = 'Partial' ).
    ls_input-eval_state = zif_ca_ops_eval_types=>gc_state-stale.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_coverage=>state( ls_input )
                                        exp = zif_ca_ops_eval_types=>gc_cov-impaired msg = 'Stale' ).
    ls_input-eval_state = zif_ca_ops_eval_types=>gc_state-not_evaluated.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_coverage=>state( ls_input )
                                        exp = zif_ca_ops_eval_types=>gc_cov-impaired msg = 'Not evaluated' ).
  ENDMETHOD.


  METHOD not_run_no_eval.
    DATA(ls_input) = base( ).
    CLEAR: ls_input-has_eval, ls_input-evaluated_at.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_coverage=>state( ls_input )
                                        exp = zif_ca_ops_eval_types=>gc_cov-not_run msg = 'Never evaluated' ).
  ENDMETHOD.


  METHOD not_run_old_eval.
    DATA(ls_input) = base( ).
    ls_input-evaluated_at = '20261115070000.0000000'.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_coverage=>state( ls_input )
                                        exp = zif_ca_ops_eval_types=>gc_cov-not_run msg = 'Outside its window' ).
  ENDMETHOD.


  METHOD gaps.
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_coverage=>is_gap( zif_ca_ops_eval_types=>gc_cov-not_run )
                                      msg = 'Not run is a gap' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_coverage=>is_gap( zif_ca_ops_eval_types=>gc_cov-disabled )
                                       msg = 'Disabled is shown, no gap' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_coverage=>is_gap( zif_ca_ops_eval_types=>gc_cov-warned )
                                       msg = 'Warned is shown, no gap' ).
  ENDMETHOD.

ENDCLASS.
