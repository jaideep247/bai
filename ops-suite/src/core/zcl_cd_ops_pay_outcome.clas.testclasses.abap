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
*& Confirmed status values (2026-11-08): a wire return with status RETURNED
*& is RETURNED; the same return while the status is still CONFIRMED stays
*& IN_FLIGHT (status pending, never inconsistent); status RETURNED without
*& the bank line is RETURN_INCONSISTENT; cheques: V without STOPPED, STOPPED
*& with state blank, STOPPED and V are VOIDED; STOPPED and cashed is
*& CLEARING_INCONSISTENT "stopped cheque cashed"; a stopped payment and
*& its reissue (new payment document and cheque number) are judged apart.
*& Modification log:
*& 2026-11-07 | Initial version (one canonical payment outcome model).
*& 2026-11-08 | Status rows of RETURNED / RETRIEVED (pending statuses), cheques stopped = voided (user
*&            | decision); cheque register rows served by the trace double.
*& 2026-11-08 | Stop and reissue (user 2026-11-08: new payment document and cheque number): the stopped
*&            | payment (VOIDED) and its cashed reissue (CLEARED) judged apart (stop_reissue_judged_apart).
*& 2026-11-08 | Table consolidation: runtime DAO double without get_evidence_settings (Stripe settings are
*&            | ZCA_PARAM parameters HCK_STRIPE_*, delivered blank = not configured).
*& 2026-11-08 | Table consolidation: runtime DAO double without get_pm_banks (house-bank calendars are
*&            | ZCD_HCK_PMCLASS rows).
*& 2026-11-10 | Error classification (concurrency review): a configuration message (also chained) or a cast
*&            | to the evidence interface is a configuration error, a read or runtime error is not; the chain of
*&            | an error is its reason; an evidence class that does not exist is CLEARING_RULE_INVALID, never
*&            | PAY_EVIDENCE_FAILED.
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

  METHOD zif_cd_hck_runtime_dao~get_clearing_rules.
    rt_rules = mt_rules.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_btc_roles.
    rt_roles = mt_roles.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_seq_outcomes.
    rt_outcomes = mt_outcomes.
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
    DATA mt_checks TYPE zif_cd_ops_trace_types=>tt_check.
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
    LOOP AT mt_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
      IF line_exists( it_docno[ table_line = <ls_check>-doc1r ] ).
        INSERT <ls_check> INTO TABLE rt_checks.
      ENDIF.
    ENDLOOP.
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
    "! An evidence class that does not exist (configuration error 030)
    CONSTANTS gc_no_class TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_HCK_EV_NONE'.
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
    METHODS returned_with_status_returned FOR TESTING.
    METHODS return_status_lag_in_flight FOR TESTING.
    METHODS returned_status_without_line FOR TESTING.
    METHODS voided_cheque_without_stop  FOR TESTING.
    METHODS stopped_cheque_blank_voided FOR TESTING.
    METHODS stopped_and_voided_cheque   FOR TESTING.
    METHODS stopped_cheque_cashed       FOR TESTING.
    METHODS stop_reissue_judged_apart   FOR TESTING.
    METHODS config_message_is_config    FOR TESTING.
    METHODS read_error_is_not_config    FOR TESTING.
    METHODS chained_config_is_config    FOR TESTING.
    METHODS reason_chain_lists_origin   FOR TESTING.
    METHODS missing_class_rule_invalid  FOR TESTING.

    "! Verdict of a cheque scenario: VOIDED, consistent (excluded)
    METHODS assert_voided
      IMPORTING
        iv_id TYPE zcl_cd_ops_pay_fixture=>ty_scenario_id
      RAISING
        zcx_cd_ops_error.

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
    INSERT LINES OF rs_scenario-checks INTO TABLE mo_trace->mt_checks.
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
          cl_abap_unit_assert=>assert_equals( act = ls_verdict-status_pending exp = <ls_scenario>-status_pending
                                              msg = |{ <ls_scenario>-id }: status pending| ).
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
  " Rule (review 2026-11-10): a configuration message (032: class without the interface) and a cast to the
  " evidence interface are configuration errors - CLEARING_RULE_INVALID, fix by transport
  METHOD config_message_is_config.
    TRY.
        RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e032(zcd_ops) WITH gc_no_class gc_no_class.
      CATCH zcx_cd_ops_error INTO DATA(lx_config).
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_pay_outcome=>is_config_error( lx_config )
                                          msg = 'Message 032 is configuration' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_pay_outcome=>is_config_error( NEW cx_sy_move_cast_error( ) )
                                      msg = 'A plug-in not of its interface is configuration' ).
  ENDMETHOD.


  " Rule (review 2026-11-10): a read failure (012) or a runtime error is not a configuration error - its own
  " code PAY_EVIDENCE_FAILED, nobody changes a correct rule
  METHOD read_error_is_not_config.
    TRY.
        RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e012(zcd_ops) WITH gc_no_class.
      CATCH zcx_cd_ops_error INTO DATA(lx_read).
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_pay_outcome=>is_config_error( lx_read )
                                           msg = 'A read failure is no configuration error' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_pay_outcome=>is_config_error( NEW cx_sy_zerodivide( ) )
                                       msg = 'A runtime error is no configuration error' ).
  ENDMETHOD.


  " Rule (review 2026-11-10): a configuration error anywhere in the chain counts (703 wrapped in 751)
  METHOD chained_config_is_config.
    TRY.
        TRY.
            RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e703(zcd_ops) WITH zif_cd_ops_trace_types=>gc_param-src_request.
          CATCH zcx_cd_ops_error INTO DATA(lx_inner).
            RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e751(zcd_ops) WITH gc_context EXPORTING previous = lx_inner.
        ENDTRY.
      CATCH zcx_cd_ops_error INTO DATA(lx_outer).
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_pay_outcome=>is_config_error( lx_outer )
                                          msg = 'The chained 703 decides' ).
    ENDTRY.
  ENDMETHOD.


  " Rule (review 2026-11-10): the reason of an error is its text and the text of every error it chains,
  " the origin last
  METHOD reason_chain_lists_origin.
    TRY.
        TRY.
            RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e012(zcd_ops) WITH gc_no_class.
          CATCH zcx_cd_ops_error INTO DATA(lx_inner).
            RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e751(zcd_ops) WITH gc_context EXPORTING previous = lx_inner.
        ENDTRY.
      CATCH zcx_cd_ops_error INTO DATA(lx_outer).
        DATA(lv_reason) = zcl_cd_ops_pay_outcome=>reason_chain( lx_outer ).
        cl_abap_unit_assert=>assert_equals( act = lv_reason
                                            exp = |{ lx_outer->get_text( ) } - { lx_inner->get_text( ) }|
                                            msg = 'Outer text, then the origin' ).
    ENDTRY.
  ENDMETHOD.


  " Rule (review 2026-11-10): an evidence class that does not exist (030) is a configuration error of the
  " rule: CLEARING_RULE_INVALID, not PAY_EVIDENCE_FAILED; its purposes are not judged
  METHOD missing_class_rule_invalid.
    TRY.
        load( zcl_cd_ops_pay_fixture=>gc_scenario-two_runs ).
        LOOP AT mo_runtime->mt_rules ASSIGNING FIELD-SYMBOL(<ls_rule>).
          <ls_rule>-evidence_class = gc_no_class.
        ENDLOOP.
        DATA(lo_cut) = zcl_cd_ops_factory=>get_pay_outcome( ).
        lo_cut->load( iv_context = gc_context iv_max_rows = gc_cap ).
        DATA(ls_evaluation) = lo_cut->evaluate_documents(
                                VALUE #( ( mo_fixture->scenario( zcl_cd_ops_pay_fixture=>gc_scenario-two_runs )-augbl ) ) ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_evaluation-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-clrrule_invalid ] ) )
          msg = 'CLEARING_RULE_INVALID' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ls_evaluation-findings[ check_code = zif_cd_ops_payout_types=>gc_code-evidence_failed ] ) )
          msg = 'Not an evidence read failure' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


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


  " Confirmed status values 2026-11-08: wire 495 -> 195 with its returns lot and DPAYH status RETURNED
  " is RETURNED (status row next to the bank evidence)
  METHOD returned_with_status_returned.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-returned ).
        DATA(ls_verdict) = verdict_of( ls_scenario-augbl ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-returned
                                            msg = 'Returned with status RETURNED: RETURNED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-status exp = zif_cd_ops_payout_types=>gc_status-excluded
                                            msg = 'Out of flight' ).
        cl_abap_unit_assert=>assert_false( act = ls_verdict-status_pending msg = 'Nothing pending' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The return is on the bank statement but DPAYH still says CONFIRMED (status job not run yet): the
  " payment stays IN_FLIGHT with the status pending - never RETURN_INCONSISTENT; the deciding evidence
  " is dated by the newest statement line (basis of PAY_STATUS_LAG in the morning report)
  METHOD return_status_lag_in_flight.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-return_lag ).
        DATA(ls_verdict) = verdict_of( ls_scenario-augbl ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-in_flight
                                            msg = 'Status not updated yet: IN_FLIGHT' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-status exp = zif_cd_ops_payout_types=>gc_status-open
                                            msg = 'Stays in flight (aged)' ).
        cl_abap_unit_assert=>assert_true( act = ls_verdict-status_pending msg = 'Waiting for the status job' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-purpose exp = zif_cd_hck_runtime_types=>gc_purpose-returned
                                            msg = 'The bank evidence says RETURNED' ).
        cl_abap_unit_assert=>assert_initial( act = ls_verdict-finding msg = 'No inconsistency finding' ).
        cl_abap_unit_assert=>assert_initial( act = ls_verdict-listings msg = 'Nothing listed' ).
        DATA(lt_lines) = ls_scenario-lines.
        SORT lt_lines BY budat DESCENDING.
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-evidence_date exp = lt_lines[ 1 ]-budat
                                            msg = 'Dated by the 195 line' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Status RETURNED without the 195 on the statement is not a lag: RETURN_INCONSISTENT (rule 4)
  METHOD returned_status_without_line.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-returned ).
        CLEAR: mo_trace->mt_lines, mo_trace->mt_returns.
        DATA(ls_verdict) = verdict_of( ls_scenario-augbl ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-inconsistent
                                            msg = 'Status RETURNED without the bank line: INCONSISTENT' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-finding exp = zif_cd_hck_runtime_types=>gc_code-return_inconsist
                                            msg = 'Finding RETURN_INCONSISTENT' ).
        cl_abap_unit_assert=>assert_false( act = ls_verdict-status_pending msg = 'Not pending' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD assert_voided.
    DATA(ls_scenario) = load( iv_id ).
    DATA(ls_verdict) = verdict_of( ls_scenario-augbl ).
    cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-voided
                                        msg = |{ iv_id }: VOIDED| ).
    cl_abap_unit_assert=>assert_equals( act = ls_verdict-status exp = zif_cd_ops_payout_types=>gc_status-excluded
                                        msg = |{ iv_id }: out of flight| ).
    cl_abap_unit_assert=>assert_initial( act = ls_verdict-finding msg = |{ iv_id }: no finding| ).
  ENDMETHOD.


  " User decision 2026-11-08: register state V without a stop payment is VOIDED
  METHOD voided_cheque_without_stop.
    TRY.
        assert_voided( zcl_cd_ops_pay_fixture=>gc_scenario-chq_voided ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User decision 2026-11-08: DPAYH status STOPPED with the register state still blank is VOIDED
  METHOD stopped_cheque_blank_voided.
    TRY.
        assert_voided( zcl_cd_ops_pay_fixture=>gc_scenario-chq_stopped ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User decision 2026-11-08: STOPPED and V is VOIDED (either one is enough)
  METHOD stopped_and_voided_cheque.
    TRY.
        assert_voided( zcl_cd_ops_pay_fixture=>gc_scenario-chq_stop_void ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User decision 2026-11-08: a stopped cheque that was cashed (581, state B) is CLEARING_INCONSISTENT
  " and the listing says "stopped cheque cashed" - never VOIDED, never CLEARED
  METHOD stopped_cheque_cashed.
    TRY.
        DATA(ls_scenario) = load( zcl_cd_ops_pay_fixture=>gc_scenario-chq_stop_cash ).
        DATA(ls_verdict) = verdict_of( ls_scenario-augbl ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-inconsistent
                                            msg = 'Stopped and cashed: INCONSISTENT' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-finding exp = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                            msg = 'Finding CLEARING_INCONSISTENT' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-purpose exp = zif_cd_hck_runtime_types=>gc_purpose-voided
                                            msg = 'Judged as a voided (stopped) cheque' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( find( val = ls_verdict-listings[ 1 ]-line sub = zcl_cd_ops_pay_fixture=>gc_stopped_cashed ) >= 0 )
          msg = 'The detail says stopped cheque cashed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User fact 2026-11-08: a stop and reissue creates a new payment document (AUGBL) and a new cheque
  " number. The stopped payment keeps STOPPED (VOIDED) and its cashed reissue is CLEARED - evaluated
  " together, each on its own document; neither is "stopped cheque cashed"
  METHOD stop_reissue_judged_apart.
    TRY.
        DATA(ls_stopped) = load( zcl_cd_ops_pay_fixture=>gc_scenario-chq_stopped ).
        DATA(ls_reissue) = load( zcl_cd_ops_pay_fixture=>gc_scenario-chq_reissue ).
        cl_abap_unit_assert=>assert_differs( act = ls_reissue-augbl exp = ls_stopped-augbl
                                             msg = 'The reissue has its own payment document' ).
        cl_abap_unit_assert=>assert_differs( act = ls_reissue-checks[ 1 ]-ztnum exp = ls_stopped-checks[ 1 ]-ztnum
                                             msg = 'The reissue has its own cheque number' ).
        DATA(lo_cut) = zcl_cd_ops_factory=>get_pay_outcome( ).
        lo_cut->load( iv_context = gc_context iv_max_rows = gc_cap ).
        DATA(ls_evaluation) = lo_cut->evaluate_documents( VALUE #( ( ls_stopped-augbl ) ( ls_reissue-augbl ) ) ).
        DATA(ls_stop_verdict) = ls_evaluation-verdicts[ KEY by_doc doc1r = ls_stopped-augbl ].
        DATA(ls_reissue_verdict) = ls_evaluation-verdicts[ KEY by_doc doc1r = ls_reissue-augbl ].
        cl_abap_unit_assert=>assert_equals( act = ls_stop_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-voided
                                            msg = 'Stopped payment: VOIDED' ).
        cl_abap_unit_assert=>assert_initial( act = ls_stop_verdict-finding msg = 'Stopped payment: no finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_reissue_verdict-outcome exp = zif_cd_ops_payout_types=>gc_outcome-cleared
                                            msg = 'Reissue cashed: CLEARED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_reissue_verdict-status exp = zif_cd_ops_payout_types=>gc_status-excluded
                                            msg = 'Reissue out of flight' ).
        cl_abap_unit_assert=>assert_initial( act = ls_reissue_verdict-finding msg = 'Reissue: no finding' ).
        LOOP AT ls_evaluation-verdicts ASSIGNING FIELD-SYMBOL(<ls_verdict>).
          LOOP AT <ls_verdict>-listings ASSIGNING FIELD-SYMBOL(<ls_listing>).
            cl_abap_unit_assert=>assert_false(
              act = xsdbool( find( val = <ls_listing>-line sub = zcl_cd_ops_pay_fixture=>gc_stopped_cashed ) >= 0 )
              msg = |{ <ls_verdict>-doc1r }: never stopped cheque cashed| ).
          ENDLOOP.
        ENDLOOP.
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
