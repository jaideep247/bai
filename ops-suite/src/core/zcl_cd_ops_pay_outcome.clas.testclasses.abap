*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_outcome.clas.testclasses.abap
*& Purpose:
*& Unit tests of the canonical payment outcome evaluator on the shared
*& negative fixtures (ZCL_CD_OPS_PAY_FIXTURE) with the delivered evidence
*& plug-ins: a retrieval is RETRIEVED (never RETURNED), a bank line without
*& clearing is INCONSISTENT (never settled), the latest of two DPAYH runs
*& decides, a FIN in two sources is AMBIGUOUS (never one picked), a SUCCESS
*& row older than 30 days keeps one source, every fixture gives its
*& expected outcome, reversed documents, unwatched methods, an unconfigured
*& request source fails closed. Runtime DAO, payment trace repository and
*& clock are doubles from the injectors, parameters the delivered in-memory
*& definitions; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (one canonical payment outcome model).
*&---------------------------------------------------------------------*
CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    DATA mt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA mt_classes TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    DATA mt_rules TYPE zif_cd_hck_runtime_types=>tt_clr_rule.
    DATA mt_roles TYPE zif_cd_hck_runtime_types=>tt_btc_role.
    DATA mt_outcomes TYPE zif_cd_hck_runtime_types=>tt_seq_outcome.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
  METHOD zif_cd_hck_runtime_dao~get_issued_payments_by_doc.
    LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF line_exists( it_docno[ table_line = <ls_payment>-doc1r ] ).
        INSERT <ls_payment> INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_pm_classes.
    rt_classes = mt_classes.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_pm_banks.
    CLEAR rt_banks.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_clearing_rules.
    rt_rules = mt_rules.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_btc_roles.
    rt_roles = mt_roles.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_seq_outcomes.
    rt_outcomes = mt_outcomes.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_evidence_settings.
    CLEAR rt_settings.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_headers TYPE zif_cd_ops_trace_types=>tt_doc_header.
    DATA mt_lines TYPE zif_cd_ops_trace_types=>tt_bank_line.
    DATA mt_returns TYPE zif_cd_ops_trace_types=>tt_return.
    DATA mt_runs TYPE zif_cd_ops_trace_types=>tt_payment_run.
    DATA mt_requests TYPE zif_cd_ops_trace_types=>tt_cfg_row.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_doc_headers.
    LOOP AT mt_headers ASSIGNING FIELD-SYMBOL(<ls_header>).
      IF line_exists( it_docno[ table_line = <ls_header>-opbel ] ).
        INSERT <ls_header> INTO TABLE rt_headers.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_bank_lines.
    LOOP AT mt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF line_exists( it_ref[ table_line = <ls_line>-chect ] ).
        INSERT <ls_line> INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_returns.
    LOOP AT mt_returns ASSIGNING FIELD-SYMBOL(<ls_return>).
      IF line_exists( it_docno[ table_line = <ls_return>-selw1 ] ).
        INSERT <ls_return> INTO TABLE rt_returns.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_payment_runs.
    LOOP AT mt_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      IF line_exists( it_docno[ table_line = <ls_run>-doc1r ] ).
        INSERT <ls_run> INTO TABLE rt_runs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_checks_by_doc.
    CLEAR rt_checks.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~read_configured_set.
    LOOP AT mt_requests ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF line_exists( it_keys[ table_line = <ls_row>-key1 ] ).
        INSERT <ls_row> INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock PARTIALLY IMPLEMENTED.
    CONSTANTS gc_today TYPE d VALUE '20261111'.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~today.
    rv_date = gc_today.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_outcome DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_context TYPE zif_cd_hck_types=>ty_check_id VALUE 'PAY_OUTCOME'.
    CONSTANTS gc_cap TYPE i VALUE 1000.
    CONSTANTS gc_unwatched TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'Z'.
    CONSTANTS gc_reversal TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000990001'.
    CONSTANTS gc_request_spec TYPE string VALUE `TABLE=ZCD_PAYM_REQ_LOG;KEY=ZZ_FIN_TRANS_NUM;KEY2=SOURCE;STATUS=ZZ_STATUS`.

    DATA mo_fixture TYPE REF TO zcl_cd_ops_pay_fixture.
    DATA mo_runtime TYPE REF TO ltd_runtime_dao.
    DATA mo_trace TYPE REF TO ltd_trace_dao.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.

    METHODS retrieval_is_not_a_return FOR TESTING.
    METHODS line_without_clearing     FOR TESTING.
    METHODS latest_run_decides        FOR TESTING.
    METHODS fin_in_two_sources        FOR TESTING.
    METHODS old_success_one_source    FOR TESTING.
    METHODS every_fixture_as_expected FOR TESTING.
    METHODS reversed_document         FOR TESTING.
    METHODS unwatched_method_no_verdict FOR TESTING.
    METHODS request_source_fails_closed FOR TESTING.

    "! Serve one fixture scenario from the doubles
    METHODS load
      IMPORTING
        iv_id              TYPE zcl_cd_ops_pay_fixture=>ty_scenario_id
      RETURNING
        VALUE(rs_scenario) TYPE zcl_cd_ops_pay_fixture=>ty_scenario.

    METHODS verdict_of
      IMPORTING
        iv_doc            TYPE zif_cd_ops_trace_types=>ty_docno
      RETURNING
        VALUE(rs_verdict) TYPE zif_cd_ops_payout_types=>ty_verdict
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_outcome IMPLEMENTATION.

  METHOD setup.
    mo_fixture = NEW #( ltd_clock=>gc_today ).
    mo_runtime = NEW #( ).
    mo_runtime->mt_classes  = mo_fixture->classes( ).
    mo_runtime->mt_rules    = mo_fixture->rules( ).
    mo_runtime->mt_roles    = mo_fixture->roles( ).
    mo_runtime->mt_outcomes = mo_fixture->outcomes( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_runtime ).
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    mo_params = NEW #( ).
    mo_params->set( iv_name = zif_cd_ops_trace_types=>gc_param-src_request iv_value = gc_request_spec ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_fixture, mo_runtime, mo_trace, mo_params.
  ENDMETHOD.


  METHOD load.
    rs_scenario = mo_fixture->scenario( iv_id ).
    INSERT LINES OF mo_fixture->issued_payments( rs_scenario ) INTO TABLE mo_runtime->mt_payments.
    INSERT LINES OF mo_fixture->payment_runs( rs_scenario ) INTO TABLE mo_trace->mt_runs.
    INSERT LINES OF rs_scenario-lines INTO TABLE mo_trace->mt_lines.
    INSERT LINES OF rs_scenario-returns INTO TABLE mo_trace->mt_returns.
    LOOP AT rs_scenario-requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      INSERT VALUE #( key1 = <ls_request>-fin key2 = <ls_request>-source status = <ls_request>-status )
        INTO TABLE mo_trace->mt_requests.
    ENDLOOP.
  ENDMETHOD.


  METHOD verdict_of.
    DATA(lo_cut) = zcl_cd_ops_factory=>get_pay_outcome( ).
    lo_cut->load( iv_context = gc_context iv_max_rows = gc_cap ).
    DATA(ls_evaluation) = lo_cut->evaluate_documents( VALUE #( ( iv_doc ) ) ).
    rs_verdict = VALUE #( ls_evaluation-verdicts[ KEY by_doc doc1r = iv_doc ] OPTIONAL ).
  ENDMETHOD.


  " Rule: a manual retrieval (466 -> 166) without returns lot is RETRIEVED - a retrieval is not a return
  METHOD retrieval_is_not_a_return.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-retrieval ).
        DATA(ls_verdict) = verdict_of( ls_scenario-augbl ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-retrieved
                                            msg = 'Retrieval: RETRIEVED' ).
        cl_abap_unit_assert=>assert_differs( act = ls_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-returned
                                             msg = 'A retrieval is never RETURNED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-status exp = zif_cd_ops_payout_types=>gc_status-excluded
                                            msg = 'Consistent purpose: out of flight' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a statement line alone never clears a wire (rule 1 needs the DPAYH status too): INCONSISTENT
  METHOD line_without_clearing.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-bank_line ).
        DATA(ls_verdict) = verdict_of( ls_scenario-augbl ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-inconsistent
                                            msg = 'Line without status: INCONSISTENT, not cleared' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-finding exp = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                            msg = 'Finding CLEARING_INCONSISTENT' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: of two DPAYH runs of one document the latest (run date, then run ID) is judged
  METHOD latest_run_decides.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-two_runs ).
        DATA(ls_verdict) = verdict_of( ls_scenario-augbl ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-cleared
                                            msg = 'Latest run CLEARED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-laufd exp = ls_scenario-expected_laufd
                                            msg = 'Run date of the latest run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-laufi exp = ls_scenario-expected_laufi
                                            msg = 'Run ID of the latest run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a FIN with SUCCESS rows in two sources is AMBIGUOUS for each - never attributed to one
  METHOD fin_in_two_sources.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-two_sources ).
        DATA(lo_cut) = zcl_cd_ops_factory=>get_pay_outcome( ).
        lo_cut->load( iv_context = gc_context iv_max_rows = gc_cap ).
        DATA(ls_evaluation) = lo_cut->evaluate_documents( VALUE #( ( ls_scenario-augbl ) ) ).
        DATA(ls_verdict) = ls_evaluation-verdicts[ 1 ].
        DATA(lt_sources) = lo_cut->sources_of( VALUE #( ( ls_scenario-fin ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_sources ) exp = 2 msg = 'Both sources kept' ).
        LOOP AT lt_sources ASSIGNING FIELD-SYMBOL(<ls_source>).
          DATA(ls_final) = lo_cut->for_source( is_verdict = ls_verdict is_source = <ls_source> ).
          cl_abap_unit_assert=>assert_equals( act = ls_final-outcome exp = ls_scenario-expected
                                              msg = |{ <ls_source>-source }: AMBIGUOUS| ).
          cl_abap_unit_assert=>assert_equals( act = ls_final-finding exp = zif_cd_ops_payout_types=>gc_code-source_ambiguous
                                              msg = 'Finding PAY_SOURCE_AMBIGUOUS' ).
        ENDLOOP.
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = ls_scenario-evaluated
                                            msg = 'The evidence itself says CLEARED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: SUCCESS 40 days ago with a failed retry today is one source (SUCCESS row rule, no window)
  METHOD old_success_one_source.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        DATA(lo_cut) = zcl_cd_ops_factory=>get_pay_outcome( ).
        DATA(lt_sources) = lo_cut->sources_of( VALUE #( ( ls_scenario-fin ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_sources ) exp = 1 msg = 'One source' ).
        cl_abap_unit_assert=>assert_equals( act = lt_sources[ 1 ]-source exp = zcl_cd_ops_pay_fixture=>gc_source-pclm
                                            msg = 'The SUCCESS source' ).
        cl_abap_unit_assert=>assert_equals( act = verdict_of( ls_scenario-augbl )-outcome exp = ls_scenario-expected
                                            msg = 'Cleared' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Agreement: every shared fixture, evaluated together, gives its expected outcome
  METHOD every_fixture_as_expected.
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA lt_fin TYPE zif_cd_ops_payout_types=>tt_fin.
    TRY.
        LOOP AT mo_fixture->scenarios( ) ASSIGNING FIELD-SYMBOL(<ls_scenario>).
          load( <ls_scenario>-id ).
          INSERT <ls_scenario>-augbl INTO TABLE lt_docno.
          INSERT <ls_scenario>-fin INTO TABLE lt_fin.
        ENDLOOP.
        DATA(lo_cut) = zcl_cd_ops_factory=>get_pay_outcome( ).
        lo_cut->load( iv_context = gc_context iv_max_rows = gc_cap ).
        DATA(ls_evaluation) = lo_cut->evaluate_documents( lt_docno ).
        DATA(lt_sources) = lo_cut->sources_of( lt_fin ).
        LOOP AT mo_fixture->scenarios( ) ASSIGNING <ls_scenario>.
          DATA(ls_verdict) = ls_evaluation-verdicts[ KEY by_doc doc1r = <ls_scenario>-augbl ].
          ls_verdict = lo_cut->for_source( is_verdict = ls_verdict
                                           is_source  = lt_sources[ fin = <ls_scenario>-fin ] ).
          cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = <ls_scenario>-expected
                                              msg = |{ <ls_scenario>-id }: expected outcome| ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a reversed payment document (DFKKKO-STBEL) is REVERSED and its evidence is not judged
  METHOD reversed_document.
    DATA ls_header TYPE zif_cd_ops_trace_types=>ty_doc_header.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-two_runs ).
        ls_header-opbel = ls_scenario-augbl.
        ls_header-stbel = gc_reversal.
        INSERT ls_header INTO TABLE mo_trace->mt_headers.
        DATA(ls_verdict) = verdict_of( ls_scenario-augbl ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-reversed
                                            msg = 'Reversed document' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-status exp = zif_cd_ops_payout_types=>gc_status-reversed
                                            msg = 'Not in flight' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment whose method is in no watched class has no verdict (never a guessed outcome)
  METHOD unwatched_method_no_verdict.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-two_runs ).
        LOOP AT mo_runtime->mt_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
          <ls_payment>-pymet = gc_unwatched.
        ENDLOOP.
        cl_abap_unit_assert=>assert_initial( act = verdict_of( ls_scenario-augbl ) msg = 'No verdict' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without a request source the attribution is not possible - it raises, nothing is guessed
  METHOD request_source_fails_closed.
    DATA lx_expected TYPE REF TO zcx_cd_ops_error.
    DATA(lo_params) = NEW zcl_cd_ops_param_seed( ).
    zcl_cd_ops_injector=>inject_params( lo_params->params( ) ).
    TRY.
        zcl_cd_ops_factory=>get_pay_outcome( )->sources_of(
          VALUE #( ( mo_fixture->scenario( zcl_cd_ops_pay_fixture=>gc_scenario-two_sources )-fin ) ) ).
      CATCH zcx_cd_ops_error INTO lx_expected.
    ENDTRY.
    cl_abap_unit_assert=>assert_bound( act = lx_expected msg = 'Unconfigured request source raises' ).
  ENDMETHOD.

ENDCLASS.
