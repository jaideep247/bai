*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_coverage.clas.abap
*& Purpose:
*& Rule of the monitor coverage state of a registered check (docs/
*& EVALUATION_AND_COVERAGE.md section 5), without database: DISABLED (the
*& check or its business process is switched off by configuration),
*& REFUSED (the licence refuses a module it needs, LIC_ENFORCE = X),
*& NOT_RUN (expected, but no evaluation within its schedule window - a
*& monitor gap, never silence), IMPAIRED (its latest evaluation is not
*& evaluated, stale or partial), WARNED (it runs, but under a licence
*& warning: LIC_ENFORCE = W and the module not covered), RAN. The CDS view
*& ZR_CA_OpsCoverage applies the same rule to the stored records; the
*& coverage check ZCL_CA_OPS_CHK_COVERAGE applies it with the licence read
*& through ZIF_CA_OPS_LICENSE today.
*& Modification log:
*& 2026-11-16 | Initial version (build O: monitor coverage state).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - monitor coverage rule</p>
CLASS zcl_ca_ops_coverage DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Coverage state, worst first: DISABLED, REFUSED, NOT_RUN, IMPAIRED, WARNED, RAN
    CLASS-METHODS state
      IMPORTING
        is_input        TYPE zif_ca_ops_eval_types=>ty_cov_input
      RETURNING
        VALUE(rv_state) TYPE zif_ca_ops_eval_types=>ty_cov_state.

    "! X = the latest evaluation lies within the schedule window (0 minutes = any evaluation counts)
    CLASS-METHODS in_window
      IMPORTING
        iv_evaluated_at  TYPE timestampl
        iv_now           TYPE timestampl
        iv_window_min    TYPE i
      RETURNING
        VALUE(rv_inside) TYPE abap_bool.

    "! A gap support must act on: REFUSED, NOT_RUN, IMPAIRED (WARNED and DISABLED are shown, not gaps)
    CLASS-METHODS is_gap
      IMPORTING
        iv_state      TYPE zif_ca_ops_eval_types=>ty_cov_state
      RETURNING
        VALUE(rv_gap) TYPE abap_bool.

ENDCLASS.



CLASS zcl_ca_ops_coverage IMPLEMENTATION.

  METHOD state.
    IF is_input-active = abap_false.
      rv_state = zif_ca_ops_eval_types=>gc_cov-disabled.
    ELSEIF is_input-lic_allowed = abap_false.
      rv_state = zif_ca_ops_eval_types=>gc_cov-refused.
    ELSEIF is_input-has_eval = abap_false
        OR in_window( iv_evaluated_at = is_input-evaluated_at
                      iv_now          = is_input-now
                      iv_window_min   = is_input-window_min ) = abap_false.
      rv_state = zif_ca_ops_eval_types=>gc_cov-not_run.
    ELSEIF zcl_ca_ops_eval=>is_unknown( is_input-eval_state ) = abap_true.
      rv_state = zif_ca_ops_eval_types=>gc_cov-impaired.
    ELSEIF is_input-lic_warned = abap_true.
      rv_state = zif_ca_ops_eval_types=>gc_cov-warned.
    ELSE.
      rv_state = zif_ca_ops_eval_types=>gc_cov-ran.
    ENDIF.
  ENDMETHOD.


  METHOD in_window.
    IF iv_evaluated_at IS INITIAL.
      RETURN.
    ENDIF.
    IF iv_window_min <= 0.
      rv_inside = abap_true.
      RETURN.
    ENDIF.
    rv_inside = xsdbool( zcl_ca_ops_eval=>is_stale( iv_newest_at = iv_evaluated_at
                                                    iv_now       = iv_now
                                                    iv_stale_min = iv_window_min ) = abap_false ).
  ENDMETHOD.


  METHOD is_gap.
    rv_gap = xsdbool( iv_state = zif_ca_ops_eval_types=>gc_cov-refused
                      OR iv_state = zif_ca_ops_eval_types=>gc_cov-not_run
                      OR iv_state = zif_ca_ops_eval_types=>gc_cov-impaired ).
  ENDMETHOD.

ENDCLASS.
