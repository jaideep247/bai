*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_payfile.clas.testclasses.abap
*& Purpose:
*& Tests of the payment file check through ZIF_CA_OPS_CHECK=>RUN with a
*& register double: the flagship (acceptance missing) is one finding per
*& currency - payments, gross amount in its currency, deadline, calendar,
*& stage reached, responsible owner from the configuration, evidence key
*& and typed evidence rows (no contract gap); a cancelled job is one
*& finding (never also "not generated"); a reissue after the original
*& reached the bank carries the duplicate exposure apart from the gross,
*& and a late answer for the original is recognised; a file whose source
*& is not evaluated gives no verdict and makes the check partial; a
*& missing file of a business day, a stale day; severity by the grace
*& minutes, by PF_BREACH_RED_MIN and by the amount limit of its currency
*& and company code. Every dependency is a local double. Does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
CLASS ltd_chk_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_dao PARTIALLY IMPLEMENTED.
    DATA mt_files TYPE zif_ca_ops_pf_types=>tt_file.
    DATA mt_ms TYPE zif_ca_ops_pf_types=>tt_ms.
    DATA mt_totals TYPE zif_ca_ops_pf_types=>tt_total.
    DATA mt_events TYPE zif_ca_ops_pf_types=>tt_event.
    DATA mt_payments TYPE zif_ca_ops_pf_types=>tt_payment.
    DATA mt_days TYPE zif_ca_ops_pf_types=>tt_day.
    DATA mt_sources TYPE zif_ca_ops_pf_types=>tt_source.
ENDCLASS.

CLASS ltd_chk_dao IMPLEMENTATION.
  METHOD zif_ca_ops_pf_dao~get_file_types.
    rt_types = VALUE #( ( area = iv_area file_type = 'PAYMENTS' process_id = 'ZT_PAY' calendar_id = 'ZT'
                          ack_level = zif_ca_ops_pf_types=>gc_ack_level-file open_days = 5 active = abap_true ) ).
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_stages.
    rt_stages = VALUE #( ( milestone = zif_ca_ops_pf_types=>gc_milestone-delivered grace_min = 15 active = abap_true ) ).
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_adapters.
    rt_adapters = VALUE #( ( role = zif_ca_ops_pf_types=>gc_role-ack source_id = 'ZTBANK' active = abap_true ) ).
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_maps.
    CLEAR rt_maps.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_source.
    rs_source = VALUE #( mt_sources[ source_id = iv_source_id ] OPTIONAL ).
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~files_since.
    rt_files = mt_files.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_milestones.
    rt_milestones = mt_ms.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_totals.
    rt_totals = mt_totals.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_events.
    rt_events = mt_events.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_payments.
    rt_payments = mt_payments.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_days.
    rt_days = mt_days.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_chk_owner DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_owner.
ENDCLASS.

CLASS ltd_chk_owner IMPLEMENTATION.
  METHOD zif_ca_ops_owner~resolve.
    rs_owner = VALUE #( user = 'ZT_OWNER' team = 'PAYOPS' source = zif_ca_ops_exc_contract=>gc_resp_source-control
                        ref = 'ZT_CTL' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_chk_catalog DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_catalog PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_chk_catalog IMPLEMENTATION.
  METHOD zif_ca_ops_catalog~inactive_onboarded.
    CLEAR rt_processes.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_chk_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_chk_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261117110000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261117'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '110000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_payfile DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_area TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_PF'.
    DATA mo_dao TYPE REF TO ltd_chk_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.
    DATA mv_f1 TYPE zif_ca_ops_pf_types=>ty_file_id VALUE '00000000000000000000000000000001'.
    DATA mv_f2 TYPE zif_ca_ops_pf_types=>ty_file_id VALUE '00000000000000000000000000000002'.

    METHODS setup.
    METHODS teardown.
    "! A file stopped before the bank's acceptance, overdue by iv_overdue minutes
    METHODS given_ack_missing
      IMPORTING
        iv_overdue TYPE i DEFAULT 60.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result.
    METHODS ms
      IMPORTING
        iv_file        TYPE zif_ca_ops_pf_types=>ty_file_id
        iv_milestone   TYPE zif_ca_ops_pf_types=>ty_milestone
        iv_status      TYPE zif_ca_ops_pf_types=>ty_ms_status
        iv_observed_at TYPE timestampl OPTIONAL.

    METHODS ack_missing_per_currency  FOR TESTING.
    METHODS contract_complete         FOR TESTING.
    METHODS job_failed_one_finding    FOR TESTING.
    METHODS reissue_exposure_apart    FOR TESTING.
    METHODS not_evaluated_no_verdict  FOR TESTING.
    METHODS day_missing_and_stale     FOR TESTING.
    METHODS severity_grace_and_limits FOR TESTING.
    METHODS amount_limit_scopes       FOR TESTING.
ENDCLASS.


CLASS ltc_chk_payfile IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_pf_injector=>inject_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_owner( NEW ltd_chk_owner( ) ).
    zcl_ca_ops_injector=>inject_catalog( NEW ltd_chk_catalog( ) ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_chk_clock( ) ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_pf_injector=>reset( ).
  ENDMETHOD.


  METHOD ms.
    INSERT VALUE #( area = gc_area file_id = iv_file milestone = iv_milestone required = abap_true status = iv_status
                    seq = zcl_ca_ops_pf_lifecycle=>rank( iv_milestone ) observed_at = iv_observed_at
                    due_at = '20261117100000.0000000' ) INTO TABLE mo_dao->mt_ms.
  ENDMETHOD.


  METHOD given_ack_missing.
    INSERT VALUE #( area = gc_area file_id = mv_f1 file_type = 'PAYMENTS' native_key = 'F1' bukrs = 'ZT01'
                    run_date = '20261116' run_id = 'ZT1' bus_date = '20261116' gen_job = 'ZT_MEDIUM' gen_jobcount = '00000001'
                    stage = zif_ca_ops_pf_types=>gc_milestone-receipt next_ms = zif_ca_ops_pf_types=>gc_milestone-accepted
                    state = zif_ca_ops_pf_types=>gc_state-open deadline_at = '20261117100000.0000000'
                    overdue_min = iv_overdue pay_count = 3 eval_state = zif_ca_ops_pf_types=>gc_eval-complete )
           INTO TABLE mo_dao->mt_files.
    ms( iv_file      = mv_f1
        iv_milestone = zif_ca_ops_pf_types=>gc_milestone-generated
        iv_status    = zif_ca_ops_pf_types=>gc_ms_status-reached ).
    ms( iv_file = mv_f1 iv_milestone = zif_ca_ops_pf_types=>gc_milestone-receipt iv_status = zif_ca_ops_pf_types=>gc_ms_status-reached ).
    ms( iv_file = mv_f1 iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted iv_status = zif_ca_ops_pf_types=>gc_ms_status-missing ).
    mo_dao->mt_totals = VALUE #( ( file_id = mv_f1 currency = 'EUR' pay_count = 1 amount = '200.00' )
                                 ( file_id = mv_f1 currency = 'USD' pay_count = 2 amount = '3500.50' ) ).
    mo_dao->mt_events = VALUE #( ( file_id = mv_f1 milestone = zif_ca_ops_pf_types=>gc_milestone-receipt
                                   outcome = zif_ca_ops_pf_types=>gc_outcome-ok source_type = zif_ca_ops_pf_types=>gc_source_type-bank
                                   source_event_id = 'ACK1' event_version = 1
                                   corr_quality = zif_ca_ops_exc_contract=>gc_quality-confirmed ) ).
    mo_dao->mt_payments = VALUE #( ( file_id = mv_f1 pay_key = 'P1' pay_doc = 'D1' currency = 'USD' amount = '1000.00' ) ).
  ENDMETHOD.


  METHOD run.
    TRY.
        rs_result = NEW zcl_ca_ops_chk_payfile( )->zif_ca_ops_check~run(
                      is_check   = VALUE #( area = gc_area check_id = 'FICA_PAYFILE_ACK' process_id = 'ZT_PAY' )
                      is_context = VALUE #( area = gc_area today = '20261117' now = '20261117110000.0000000' ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD ack_missing_per_currency.
    given_ack_missing( ).
    DATA(ls_result) = run( ).
    DATA(lt_ack) = VALUE zif_ca_ops_types=>tt_finding( FOR ls_f IN ls_result-findings
                                                         WHERE ( check_code = zif_ca_ops_pf_types=>gc_code-ack_missing ) ( ls_f ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_ack ) exp = 2 msg = 'One finding per currency' ).
    DATA(ls_usd) = lt_ack[ currency = 'USD' ].
    cl_abap_unit_assert=>assert_equals( act = ls_usd-item_count exp = 2 msg = 'Payments of the currency' ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-amount exp = '3500.50' msg = 'Gross in its currency' ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-severity exp = zif_ca_ops_types=>gc_severity-error msg = 'Past the grace' ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-stage exp = zif_ca_ops_pf_types=>gc_milestone-receipt msg = 'Stage reached' ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_usd-object_key exp = 'PAYMENTS/F1/USD' msg = 'Object key' ).
  ENDMETHOD.


  METHOD contract_complete.
    given_ack_missing( ).
    DATA(ls_result) = run( ).
    DATA(ls_finding) = ls_result-findings[ check_code = zif_ca_ops_pf_types=>gc_code-ack_missing currency = 'EUR' ].
    cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_exc_contract=>missing( ls_finding ) msg = 'No contract gap' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-resp_team exp = 'PAYOPS' msg = 'Owner team from the configuration' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-calendar_id exp = 'ZT' msg = 'Calendar' ).
    cl_abap_unit_assert=>assert_equals( act = CONV timestampl( ls_finding-deadline_at ) exp = '20261117100000.0000000'
                                        msg = 'Deadline' ).
    DATA(lt_rows) = VALUE zif_ca_ops_exc_contract=>tt_evidence( FOR ls_e IN ls_result-evidence
                                                                 WHERE ( evid_key = ls_finding-evid_key ) ( ls_e ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_rows[ kind = zif_ca_ops_exc_contract=>gc_kind-bank ] ) )
                                      msg = 'Bank record' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_rows[ ev_type = zif_ca_ops_exc_contract=>gc_type-pay_doc ] ) )
                                      msg = 'Payment document' ).
  ENDMETHOD.


  METHOD job_failed_one_finding.
    INSERT VALUE #( area = gc_area file_id = mv_f1 file_type = 'PAYMENTS' native_key = 'F1' bus_date = '20261116'
                    gen_job = 'ZT_MEDIUM' gen_jobcount = '00000001' state = zif_ca_ops_pf_types=>gc_state-failed
                    next_ms = zif_ca_ops_pf_types=>gc_milestone-generated eval_state = zif_ca_ops_pf_types=>gc_eval-complete )
           INTO TABLE mo_dao->mt_files.
    ms( iv_file = mv_f1 iv_milestone = zif_ca_ops_pf_types=>gc_milestone-generated iv_status = zif_ca_ops_pf_types=>gc_ms_status-failed ).
    ms( iv_file = mv_f1 iv_milestone = zif_ca_ops_pf_types=>gc_milestone-delivered iv_status = zif_ca_ops_pf_types=>gc_ms_status-missing ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One finding' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code exp = zif_ca_ops_pf_types=>gc_code-job_failed
                                        msg = 'The job failure' ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-findings[ 1 ]-reference exp = 'ZT_MEDIUM*' msg = 'Job as reference' ).
  ENDMETHOD.


  METHOD reissue_exposure_apart.
    INSERT VALUE #( area = gc_area file_id = mv_f1 file_type = 'PAYMENTS' native_key = 'F1' bus_date = '20261116'
                    state = zif_ca_ops_pf_types=>gc_state-replaced created_at = '20261116160000.0000000'
                    eval_state = zif_ca_ops_pf_types=>gc_eval-complete ) INTO TABLE mo_dao->mt_files.
    INSERT VALUE #( area = gc_area file_id = mv_f2 file_type = 'PAYMENTS' native_key = 'F2' bus_date = '20261116'
                    predecessor = mv_f1 state = zif_ca_ops_pf_types=>gc_state-done created_at = '20261116180000.0000000'
                    eval_state = zif_ca_ops_pf_types=>gc_eval-complete ) INTO TABLE mo_dao->mt_files.
    ms( iv_file = mv_f1 iv_milestone = zif_ca_ops_pf_types=>gc_milestone-delivered iv_status = zif_ca_ops_pf_types=>gc_ms_status-reached
        iv_observed_at = '20261116164500.0000000' ).
    ms( iv_file = mv_f1 iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted iv_status = zif_ca_ops_pf_types=>gc_ms_status-reached
        iv_observed_at = '20261117093000.0000000' ).
    ms( iv_file = mv_f2 iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted iv_status = zif_ca_ops_pf_types=>gc_ms_status-reached
        iv_observed_at = '20261117090000.0000000' ).
    mo_dao->mt_totals = VALUE #( ( file_id = mv_f1 currency = 'USD' pay_count = 1 amount = '700.00' dup_count = 1 dup_amount = '700.00' )
                                 ( file_id = mv_f2 currency = 'USD' pay_count = 1 amount = '700.00' dup_count = 1 dup_amount = '700.00' ) ).
    DATA(ls_result) = run( ).
    DATA(ls_dup) = ls_result-findings[ check_code = zif_ca_ops_pf_types=>gc_code-dup_exposure ].
    cl_abap_unit_assert=>assert_equals( act = ls_dup-amount exp = 0 msg = 'No gross on the exposure' ).
    cl_abap_unit_assert=>assert_equals( act = ls_dup-dup_amount exp = '700.00' msg = 'Exposure apart' ).
    cl_abap_unit_assert=>assert_equals( act = ls_dup-severity exp = zif_ca_ops_types=>gc_severity-block msg = 'Blocks' ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( ls_result-findings[ check_code = zif_ca_ops_pf_types=>gc_code-orig_ack ] ) )
      msg = 'Late answer for the original recognised' ).
  ENDMETHOD.


  METHOD not_evaluated_no_verdict.
    given_ack_missing( ).
    mo_dao->mt_files[ 1 ]-eval_state = zif_ca_ops_pf_types=>gc_eval-not_evaluated.
    mo_dao->mt_ms[ milestone = zif_ca_ops_pf_types=>gc_milestone-accepted ]-status = zif_ca_ops_pf_types=>gc_ms_status-unknown.
    mo_dao->mt_sources = VALUE #( ( source_id = 'ZTBANK' status = zif_ca_ops_pf_types=>gc_src_status-failed reason = 'down' ) ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_true( act = ls_result-partial msg = 'Partial: nothing auto-resolved' ).
    cl_abap_unit_assert=>assert_false(
      act = xsdbool( line_exists( ls_result-findings[ check_code = zif_ca_ops_pf_types=>gc_code-ack_missing ] ) )
      msg = 'No missing acceptance without its source' ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( ls_result-findings[ check_code = zif_ca_ops_pf_types=>gc_code-not_evaluated ] ) )
      msg = 'Not evaluated said' ).
  ENDMETHOD.


  METHOD day_missing_and_stale.
    mo_dao->mt_days = VALUE #( ( file_type = 'PAYMENTS' bus_date = '20261116' expected = 1 observed = 0
                                 result = zif_ca_ops_pf_types=>gc_day-missing )
                               ( file_type = 'PAYMENTS' bus_date = '20261117' result = zif_ca_ops_pf_types=>gc_day-stale )
                               ( file_type = 'PAYMENTS' bus_date = '20261114' result = zif_ca_ops_pf_types=>gc_day-holiday )
                               ( file_type = 'PAYMENTS' bus_date = '20261113' result = zif_ca_ops_pf_types=>gc_day-zero_ok ) ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 2 msg = 'Missing and stale only' ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( ls_result-findings[ check_code = zif_ca_ops_pf_types=>gc_code-file_missing ] ) )
      msg = 'File missing' ).
    cl_abap_unit_assert=>assert_true( act = ls_result-partial msg = 'A stale day is no verdict' ).
  ENDMETHOD.


  METHOD severity_grace_and_limits.
    given_ack_missing( iv_overdue = 10 ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ currency = 'USD' ]-severity
                                        exp = zif_ca_ops_types=>gc_severity-warning msg = 'Within the grace minutes' ).
    mo_dao->mt_files[ 1 ]-overdue_min = 300.
    ls_result = run( ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ currency = 'USD' ]-severity
                                        exp = zif_ca_ops_types=>gc_severity-block msg = 'From PF_BREACH_RED_MIN' ).
    mo_dao->mt_files[ 1 ]-overdue_min = 60.
    mo_seed->set( iv_name = zif_ca_ops_pf_types=>gc_param-amount_red iv_value = 'ZT01:EUR 100, USD 1000000' ).
    ls_result = run( ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ currency = 'EUR' ]-severity
                                        exp = zif_ca_ops_types=>gc_severity-block msg = 'EUR limit of the company code' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ currency = 'USD' ]-severity
                                        exp = zif_ca_ops_types=>gc_severity-error msg = 'USD below its own limit' ).
  ENDMETHOD.


  METHOD amount_limit_scopes.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_chk_payfile=>amount_limit( iv_list = 'USD 100, 1000:USD 50'
                                                                                    iv_currency = 'USD' iv_bukrs = '1000' )
                                        exp = 50 msg = 'Company code wins' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_chk_payfile=>amount_limit( iv_list = 'USD 100, 1000:USD 50'
                                                                                    iv_currency = 'USD' iv_bukrs = '2000' )
                                        exp = 100 msg = 'Currency entry' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_chk_payfile=>amount_limit( iv_list = 'USD 100'
                                                                                    iv_currency = 'EUR' iv_bukrs = '1000' )
                                        exp = 0 msg = 'Never across currencies' ).
  ENDMETHOD.

ENDCLASS.
