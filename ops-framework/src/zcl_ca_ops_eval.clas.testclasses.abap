*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_eval.clas.testclasses.abap
*& Purpose:
*& Tests of the evaluation state rules (pure, no database): every result
*& class from the earlier vocabularies (build K's day results, build N's
*& evaluations) and the display state (completeness first: not evaluated,
*& stale, partial before anything green); the defaults of a check that
*& reports nothing new (no exception = OK, exception = FINDINGS, PARTIAL =
*& partial, raised = not evaluated); a stale source and a closed period
*& never give OK; an error never hides behind a zero; a check that mixes
*& evaluated and unevaluated rules is partial; a record of a check not run.
*& The expected states are those of tools/abaptools/evaluation.py and
*& config/evaluation/fixtures.json (same scenarios). Does not prove live
*& SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build O: evaluation state of every control).
*&---------------------------------------------------------------------*
CLASS ltc_eval DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        check TYPE c LENGTH 20 VALUE 'ZT_CHECK',
        today TYPE d VALUE '20261116',
        now   TYPE timestampl VALUE '20261116080000.0000000',
      END OF gc.

    METHODS input
      RETURNING
        VALUE(rs_input) TYPE zif_ca_ops_eval_types=>ty_derive_input.
    METHODS finding
      IMPORTING
        iv_severity       TYPE zif_ca_ops_types=>ty_severity
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    METHODS every_term_maps         FOR TESTING.
    METHODS display_unknown_first   FOR TESTING.
    METHODS legacy_no_finding_ok    FOR TESTING.
    METHODS legacy_finding          FOR TESTING.
    METHODS legacy_partial          FOR TESTING.
    METHODS legacy_raised           FOR TESTING.
    METHODS period_closed           FOR TESTING.
    METHODS period_keeps_findings   FOR TESTING.
    METHODS stale_source            FOR TESTING.
    METHODS error_not_behind_zero   FOR TESTING.
    METHODS mixed_terms_partial     FOR TESTING.
    METHODS only_unevaluated        FOR TESTING.
    METHODS day_results_of_k        FOR TESTING.
    METHODS not_run_record          FOR TESTING.
    METHODS scope_defaults          FOR TESTING.
ENDCLASS.


CLASS ltc_eval IMPLEMENTATION.

  METHOD input.
    rs_input = VALUE #( area = gc-area check_id = gc-check today = gc-today now = gc-now source_stale_min = 60 ).
  ENDMETHOD.


  METHOD finding.
    rs_finding = VALUE #( object_key = 'OBJ-1' check_code = 'ZT_CODE' severity = iv_severity ).
  ENDMETHOD.


  " Rule: K's and N's terms map onto one vocabulary; PENDING and unknown terms add nothing
  METHOD every_term_maps.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>of_term( 'OK' )-state
                                        exp = zif_ca_ops_eval_types=>gc_state-ok msg = 'OK' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>of_term( iv_term = 'OBSERVED' iv_exception = abap_true )-state
                                        exp = zif_ca_ops_eval_types=>gc_state-findings msg = 'N observed with exception' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>of_term( 'OBSERVED' )-state
                                        exp = zif_ca_ops_eval_types=>gc_state-ok msg = 'N observed' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>of_term( 'ZERO_VOLUME' )-state
                                        exp = zif_ca_ops_eval_types=>gc_state-zero_ok msg = 'CASH_ZERO_VOLUME' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>of_term( 'ZERO_OK' )-state
                                        exp = zif_ca_ops_eval_types=>gc_state-zero_ok msg = 'K zero' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>of_term( 'NOT_EXPECTED' )-state
                                        exp = zif_ca_ops_eval_types=>gc_state-holiday msg = 'CASH_NOT_EXPECTED' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>of_term( 'HOLIDAY' )-state
                                        exp = zif_ca_ops_eval_types=>gc_state-holiday msg = 'K holiday' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>of_term( 'PER_CLOSED' )-state
                                        exp = zif_ca_ops_eval_types=>gc_state-period_closed msg = 'Closed period' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>of_term( 'STALE' )-state
                                        exp = zif_ca_ops_eval_types=>gc_state-stale msg = 'Stale' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>of_term( 'FINDINGS' )-state
                                        exp = zif_ca_ops_eval_types=>gc_state-findings msg = 'Findings' ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_eval=>of_term( 'NOT_EVALUATED' )-unevaluated
                                      msg = 'CASH_NOT_EVALUATED' ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_eval=>of_term( 'NOT_EVAL' )-unevaluated msg = 'K not evaluated' ).
    cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_eval=>of_term( 'PENDING' ) msg = 'Pending adds nothing' ).
  ENDMETHOD.


  " Rule: completeness first - not evaluated, then stale, then partial; only a complete evaluation shows its class
  METHOD display_unknown_first.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>display_state( iv_class = 'OK' iv_cmpl = 'N' )
                                        exp = zif_ca_ops_eval_types=>gc_state-not_evaluated msg = 'Not evaluated' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>display_state( iv_class = 'STALE' iv_cmpl = 'P' )
                                        exp = zif_ca_ops_eval_types=>gc_state-stale msg = 'Stale before partial' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>display_state( iv_class = 'OK' iv_cmpl = 'P' )
                                        exp = zif_ca_ops_eval_types=>gc_state-partial msg = 'Partial is never OK' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>display_state( iv_class = 'ZERO_OK' iv_cmpl = 'C' )
                                        exp = zif_ca_ops_eval_types=>gc_state-zero_ok msg = 'Complete shows its class' ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_eval=>is_unknown( 'PARTIAL' ) msg = 'Partial unknown' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_eval=>is_unknown( 'PER_CLOSED' ) msg = 'Closed period known' ).
  ENDMETHOD.


  " Rule: a check that reports nothing new and raises nothing: complete and OK
  METHOD legacy_no_finding_ok.
    DATA(ls_eval) = zcl_ca_ops_eval=>derive( is_input = input( ) is_result = VALUE #( item_count = 3 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-completeness exp = zif_ca_ops_eval_types=>gc_cmpl-complete
                                        msg = 'Complete' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-ok msg = 'OK' ).
    cl_abap_unit_assert=>assert_initial( act = ls_eval-reason msg = 'No reason needed' ).
  ENDMETHOD.


  " Rule: an owned exception (B / E / W) of a legacy check gives FINDINGS; information does not
  METHOD legacy_finding.
    DATA(ls_eval) = zcl_ca_ops_eval=>derive(
                      is_input  = input( )
                      is_result = VALUE #( findings = VALUE #( ( finding( 'W' ) ) ( finding( 'I' ) ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-findings
                                        msg = 'Findings' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-finding_cnt exp = 1 msg = 'Only the owned exception counts' ).
  ENDMETHOD.


  " Rule: TY_RESULT-PARTIAL gives a partial evaluation - shown PARTIAL, never OK, with its reason
  METHOD legacy_partial.
    DATA(ls_eval) = zcl_ca_ops_eval=>derive( is_input = input( ) is_result = VALUE #( partial = abap_true ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-completeness exp = zif_ca_ops_eval_types=>gc_cmpl-partial
                                        msg = 'Partial' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-partial
                                        msg = 'Shown partial' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-reason_code exp = zif_ca_ops_eval_types=>gc_reason-partial
                                        msg = 'Reason' ).
  ENDMETHOD.


  " Rule: a check that raised is not evaluated, whatever it returned
  METHOD legacy_raised.
    DATA(ls_input) = input( ).
    ls_input-raised     = abap_true.
    ls_input-error_text = 'read failed'.
    DATA(ls_eval) = zcl_ca_ops_eval=>derive( is_input = ls_input is_result = VALUE #( partial = abap_true ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-completeness exp = zif_ca_ops_eval_types=>gc_cmpl-not_evaluated
                                        msg = 'Not evaluated' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-not_evaluated
                                        msg = 'Shown not evaluated' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-reason_code exp = zif_ca_ops_eval_types=>gc_reason-check_raised
                                        msg = 'Reason' ).
  ENDMETHOD.


  " Rule: a closed accounting period turns OK into PER_CLOSED
  METHOD period_closed.
    DATA(ls_input) = input( ).
    ls_input-period_closed = abap_true.
    DATA(ls_eval) = zcl_ca_ops_eval=>derive( is_input = ls_input is_result = VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-period_closed
                                        msg = 'Period closed, not OK' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-period exp = '202611' msg = 'Period of the business date' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-reason_code exp = zif_ca_ops_eval_types=>gc_reason-period_closed
                                        msg = 'Reason' ).
  ENDMETHOD.


  " Rule: findings stay findings in a closed period (a closed period hides no exception)
  METHOD period_keeps_findings.
    DATA(ls_input) = input( ).
    ls_input-period_closed = abap_true.
    DATA(ls_eval) = zcl_ca_ops_eval=>derive( is_input  = ls_input
                                             is_result = VALUE #( findings = VALUE #( ( finding( 'E' ) ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-findings
                                        msg = 'Findings' ).
  ENDMETHOD.


  " Rule: a zero from a stale source is STALE; the freshness of the evaluation is its oldest source
  METHOD stale_source.
    DATA ls_result TYPE zif_ca_ops_chk_types=>ty_result.
    zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = 'ZERO_VOLUME' CHANGING cs_eval = ls_result-eval ).
    zcl_ca_ops_eval=>add_source( EXPORTING iv_source_id = 'FRESH' iv_newest_at = '20261116075500.0000000'
                                 CHANGING  cs_eval      = ls_result-eval ).
    zcl_ca_ops_eval=>add_source( EXPORTING iv_source_id = 'OLD' iv_newest_at = '20261115080000.0000000'
                                 CHANGING  cs_eval      = ls_result-eval ).
    DATA(ls_eval) = zcl_ca_ops_eval=>derive( is_input = input( ) is_result = ls_result ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-stale msg = 'Stale' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-fresh_source exp = 'OLD' msg = 'Oldest source' ).
    cl_abap_unit_assert=>assert_true( act = ls_eval-sources[ source_id = 'OLD' ]-is_stale msg = 'Old source stale' ).
    cl_abap_unit_assert=>assert_false( act = ls_eval-sources[ source_id = 'FRESH' ]-is_stale msg = 'Fresh source' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-reason_code exp = zif_ca_ops_eval_types=>gc_reason-source_stale
                                        msg = 'Reason' ).
  ENDMETHOD.


  " Rule: an error (B / E) never hides behind a zero volume or a holiday the check reported
  METHOD error_not_behind_zero.
    DATA ls_result TYPE zif_ca_ops_chk_types=>ty_result.
    zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = 'NOT_EXPECTED' CHANGING cs_eval = ls_result-eval ).
    ls_result-findings = VALUE #( ( finding( 'E' ) ) ).
    DATA(ls_eval) = zcl_ca_ops_eval=>derive( is_input = input( ) is_result = ls_result ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-findings
                                        msg = 'Findings' ).
  ENDMETHOD.


  " Rule: one rule evaluated, one not (CASH_NOT_EVALUATED): partial; the worse evaluated class wins
  METHOD mixed_terms_partial.
    DATA ls_result TYPE zif_ca_ops_chk_types=>ty_result.
    zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = 'ZERO_VOLUME' CHANGING cs_eval = ls_result-eval ).
    zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = 'OBSERVED' iv_exception = abap_true
                                 CHANGING  cs_eval = ls_result-eval ).
    zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = 'NOT_EVALUATED' CHANGING cs_eval = ls_result-eval ).
    DATA(ls_eval) = zcl_ca_ops_eval=>derive( is_input = input( ) is_result = ls_result ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-completeness exp = zif_ca_ops_eval_types=>gc_cmpl-partial
                                        msg = 'Partial' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-result_class exp = zif_ca_ops_eval_types=>gc_state-findings
                                        msg = 'Worse class wins' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-partial
                                        msg = 'Shown partial' ).
  ENDMETHOD.


  " Rule: only unevaluated terms: not evaluated (never OK)
  METHOD only_unevaluated.
    DATA ls_result TYPE zif_ca_ops_chk_types=>ty_result.
    zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = 'NOT_EVALUATED' CHANGING cs_eval = ls_result-eval ).
    DATA(ls_eval) = zcl_ca_ops_eval=>derive( is_input = input( ) is_result = ls_result ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-not_evaluated
                                        msg = 'Not evaluated' ).
  ENDMETHOD.


  " Rule: K's days - a holiday and a valid zero are known; a missing day is a finding; pending adds nothing
  METHOD day_results_of_k.
    DATA ls_result TYPE zif_ca_ops_chk_types=>ty_result.
    zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = 'HOLIDAY' CHANGING cs_eval = ls_result-eval ).
    zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = 'ZERO_OK' CHANGING cs_eval = ls_result-eval ).
    zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = 'PENDING' CHANGING cs_eval = ls_result-eval ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>derive( is_input = input( ) is_result = ls_result )-eval_state
                                        exp = zif_ca_ops_eval_types=>gc_state-holiday msg = 'Holiday ranks above zero' ).
    zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = 'MISSING' CHANGING cs_eval = ls_result-eval ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_eval=>derive( is_input = input( ) is_result = ls_result )-eval_state
                                        exp = zif_ca_ops_eval_types=>gc_state-findings msg = 'Missing day' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-evaluated exp = 3 msg = 'Pending not counted' ).
  ENDMETHOD.


  " Rule: a check not run (licence refused, process off) has a not-evaluated record with its reason
  METHOD not_run_record.
    DATA(ls_eval) = zcl_ca_ops_eval=>not_run( is_input       = input( )
                                              iv_reason_code = zif_ca_ops_eval_types=>gc_reason-license_refused
                                              iv_reason      = 'refused' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_eval_types=>gc_state-not_evaluated
                                        msg = 'Not evaluated' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-reason_code exp = zif_ca_ops_eval_types=>gc_reason-license_refused
                                        msg = 'Reason code' ).
  ENDMETHOD.


  " Rule: the expected scope defaults to the run's date and its month; a check's own scope wins
  METHOD scope_defaults.
    zcl_ca_ops_eval=>scope( EXPORTING is_eval     = VALUE #( period = '202610' )
                                      iv_today    = gc-today
                            IMPORTING ev_bus_date = DATA(lv_date)
                                      ev_period   = DATA(lv_period) ).
    cl_abap_unit_assert=>assert_equals( act = lv_date exp = gc-today msg = 'Run date' ).
    cl_abap_unit_assert=>assert_equals( act = lv_period exp = '202610' msg = 'Own period' ).
  ENDMETHOD.

ENDCLASS.
