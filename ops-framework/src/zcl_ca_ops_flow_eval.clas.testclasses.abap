*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_eval.clas.testclasses.abap
*& Purpose:
*& Tests of the account flow evaluation through its public seam
*& EVALUATE( ): one evaluation per flow saved and committed with the items
*& of every evaluated account (role, company code, category, class, sign
*& rule), OUTSIDE accounts without a row, an account without a class or
*& with a class that is not a source, fails or answers nothing recorded
*& as not evaluated (partial, never zero), configuration problems make it
*& partial, test mode writes nothing, a flow of a business process not in
*& effect is skipped, the retention removes old evaluations, another rule
*& is another configuration version, the authorisation is checked. Every
*& dependency is a local double (data access, sources, catalogue,
*& authorisation, clock; parameters in memory); no test reads or writes
*& the database. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
CLASS ltd_flow_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_flow_dao PARTIALLY IMPLEMENTED.
    DATA mt_flows TYPE zif_ca_ops_flow_types=>tt_flow.
    DATA ms_config TYPE zif_ca_ops_flow_types=>ty_config.
    DATA mt_saved TYPE STANDARD TABLE OF zif_ca_ops_flow_types=>ty_eval WITH EMPTY KEY.
    DATA mt_items TYPE zif_ca_ops_flow_types=>tt_eval_item.
    DATA mv_commits TYPE i.
    DATA mv_before TYPE d.
ENDCLASS.

CLASS ltd_flow_dao IMPLEMENTATION.
  METHOD zif_ca_ops_flow_dao~get_flows.
    rt_flows = mt_flows.
  ENDMETHOD.
  METHOD zif_ca_ops_flow_dao~get_config.
    rs_config = ms_config.
    rs_config-flow = is_flow.
  ENDMETHOD.
  METHOD zif_ca_ops_flow_dao~save_evaluation.
    INSERT is_eval INTO TABLE mt_saved.
    INSERT LINES OF it_items INTO TABLE mt_items.
  ENDMETHOD.
  METHOD zif_ca_ops_flow_dao~delete_evaluations.
    mv_before = iv_before.
    rv_count = 2.
  ENDMETHOD.
  METHOD zif_ca_ops_flow_dao~commit.
    mv_commits += 1.
  ENDMETHOD.
ENDCLASS.


"! A source that answers a fixed set of rows, or fails
CLASS ltd_flow_source DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_flow_source.
    DATA mt_rows TYPE zif_ca_ops_flow_types=>tt_source_row.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_flow_source IMPLEMENTATION.
  METHOD zif_ca_ops_flow_source~accounted_for.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e010(zca_ops) WITH 'DFKKOP'.
    ENDIF.
    rt_rows = mt_rows.
  ENDMETHOD.
ENDCLASS.


"! Not a source: does not implement ZIF_CA_OPS_FLOW_SOURCE
CLASS ltd_flow_no_source DEFINITION FINAL FOR TESTING.
ENDCLASS.

CLASS ltd_flow_no_source IMPLEMENTATION.
ENDCLASS.


CLASS ltd_flow_catalog DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_catalog PARTIALLY IMPLEMENTED.
    DATA mt_off TYPE zif_ca_ops_cat_types=>tt_process_ids.
ENDCLASS.

CLASS ltd_flow_catalog IMPLEMENTATION.
  METHOD zif_ca_ops_catalog~inactive_onboarded.
    rt_processes = mt_off.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_flow_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_allowed TYPE abap_bool VALUE abap_true.
ENDCLASS.

CLASS ltd_flow_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~check.
    IF mv_allowed = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e041(zca_ops) WITH zif_ca_ops_auth=>gc_object iv_activity.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_flow_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_flow_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261115060000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261115'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '060000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_flow_eval DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        flow     TYPE zif_ca_ops_flow_types=>ty_flow_id VALUE 'DISB',
        process  TYPE c LENGTH 20 VALUE 'ZT_DISB',
        key_date TYPE d VALUE '20261115',
        source   TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZT_FLOW_SOURCE',
        failing  TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZT_FLOW_FAILING',
        wrong    TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZT_FLOW_WRONG',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_flow_dao.
    DATA mo_source TYPE REF TO ltd_flow_source.
    DATA mo_failing TYPE REF TO ltd_flow_source.
    DATA mo_catalog TYPE REF TO ltd_flow_catalog.
    DATA mo_auth TYPE REF TO ltd_flow_auth.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS given_sample_flow.
    METHODS evaluate
      IMPORTING
        iv_test_mode      TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rt_results) TYPE zif_ca_ops_flow_types=>tt_result
      RAISING
        zcx_ca_ops_error.

    METHODS evaluation_saved_per_flow   FOR TESTING.
    METHODS outside_has_no_row          FOR TESTING.
    METHODS no_class_not_evaluated      FOR TESTING.
    METHODS wrong_class_not_evaluated   FOR TESTING.
    METHODS failing_source_recorded     FOR TESTING.
    METHODS empty_answer_not_evaluated  FOR TESTING.
    METHODS config_problem_partial      FOR TESTING.
    METHODS test_mode_writes_nothing    FOR TESTING.
    METHODS inactive_process_skipped    FOR TESTING.
    METHODS retention_removes_old       FOR TESTING.
    METHODS changed_rule_new_version    FOR TESTING.
    METHODS not_authorised_raises       FOR TESTING.
ENDCLASS.


CLASS ltc_flow_eval IMPLEMENTATION.

  METHOD setup.
    mo_dao     = NEW #( ).
    mo_source  = NEW #( ).
    mo_failing = NEW #( ).
    mo_failing->mv_fail = abap_true.
    mo_catalog = NEW #( ).
    mo_auth    = NEW #( ).
    mo_seed    = NEW #( ).
    zcl_ca_ops_injector=>inject_flow_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_catalog( mo_catalog ).
    zcl_ca_ops_injector=>inject_auth( mo_auth ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_flow_clock( ) ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-source io_instance = mo_source ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-failing io_instance = mo_failing ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-wrong io_instance = NEW ltd_flow_no_source( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  " The sample disbursement flow: payable and clearing evaluated by the source double, cash without a class,
  " an expense outside the control chain
  METHOD given_sample_flow.
    INSERT VALUE #( area = gc-area flow_id = gc-flow process_id = gc-process active = abap_true )
           INTO TABLE mo_dao->mt_flows.
    mo_dao->ms_config-accounts = VALUE #(
      ( flow_acct = 'PAYABLE' role = zif_ca_ops_flow_types=>gc_role-payable bukrs = 'ZT01' line_source = 'F'
        eval_class = gc-source eval_category = zif_ca_ops_flow_types=>gc_category-open active = abap_true )
      ( flow_acct = 'CLEARING' role = zif_ca_ops_flow_types=>gc_role-clearing bukrs = 'ZT01' line_source = 'G'
        eval_class = gc-source eval_category = zif_ca_ops_flow_types=>gc_category-transit active = abap_true )
      ( flow_acct = 'CASH' role = zif_ca_ops_flow_types=>gc_role-cash bukrs = 'ZT01' line_source = 'G'
        active = abap_true )
      ( flow_acct = 'EXPENSE' role = zif_ca_ops_flow_types=>gc_role-outside bukrs = 'ZT01' line_source = 'G'
        active = abap_true ) ).
    mo_dao->ms_config-stages = VALUE #( ( stage_id = 'PAYRUN' seq = 20 active = abap_true ) ).
    mo_dao->ms_config-rules = VALUE #( ( rule_seq = '0020' rule_id = 'FICA_PAYRUN' stage_id = 'PAYRUN'
                                         line_source = 'F' origin = 'ZP' active = abap_true ) ).
    mo_source->mt_rows = VALUE #( ( currency = 'USD' amount = '-300.00' item_count = 1
                                    status = zif_ca_ops_flow_types=>gc_item_status-evaluated ) ).
  ENDMETHOD.


  METHOD evaluate.
    rt_results = NEW zcl_ca_ops_flow_eval( )->evaluate( iv_area      = gc-area
                                                        iv_key_date  = gc-key_date
                                                        iv_test_mode = iv_test_mode ).
  ENDMETHOD.


  " Rule: one evaluation per flow, saved and committed, with one item per evaluated account and currency
  METHOD evaluation_saved_per_flow.
    given_sample_flow( ).
    DATA(lt_results) = evaluate( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_saved ) exp = 1 msg = 'One evaluation' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_commits exp = 1 msg = 'Committed per flow' ).
    DATA(ls_eval) = mo_dao->mt_saved[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_eval-key_date exp = gc-key_date msg = 'Key date' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-acct_count exp = 3 msg = 'Three accounts in the chain' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_eval-cfg_version msg = 'Configuration version' ).
    DATA(ls_item) = mo_dao->mt_items[ flow_acct = 'CLEARING' ].
    cl_abap_unit_assert=>assert_equals( act = ls_item-amount exp = '-300.00' msg = 'Signed amount kept' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-category exp = zif_ca_ops_flow_types=>gc_category-transit
                                        msg = 'Category of the account' ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-source_class exp = gc-source msg = 'Source class' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_results ) exp = 1 msg = 'One result' ).
  ENDMETHOD.


  " Rule: an account outside the control chain has no evaluation row (the dashboard shows "no control point")
  METHOD outside_has_no_row.
    given_sample_flow( ).
    evaluate( ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( mo_dao->mt_items[ flow_acct = 'EXPENSE' ] ) )
                                       msg = 'No row for the expense' ).
  ENDMETHOD.


  " Rule: an account without a source class is not evaluated - grey with a reason, never zero; the evaluation partial
  METHOD no_class_not_evaluated.
    given_sample_flow( ).
    evaluate( ).
    DATA(ls_item) = mo_dao->mt_items[ flow_acct = 'CASH' ].
    cl_abap_unit_assert=>assert_equals( act = ls_item-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                                        msg = 'Not evaluated' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_item-reason msg = 'Reason given' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-status
                                        exp = zif_ca_ops_flow_types=>gc_status-partial msg = 'Partial' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-not_evaluated exp = 1 msg = 'One not evaluated' ).
  ENDMETHOD.


  " Rule: a class that is not a source is reported on the account, the others are still evaluated
  METHOD wrong_class_not_evaluated.
    given_sample_flow( ).
    mo_dao->ms_config-accounts[ flow_acct = 'CASH' ]-eval_class = gc-wrong.
    evaluate( ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_items[ flow_acct = 'CASH' ]-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                                        msg = 'Wrong class: not evaluated' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_items[ flow_acct = 'PAYABLE' ]-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-evaluated
                                        msg = 'Other accounts evaluated' ).
  ENDMETHOD.


  " Rule: a source that fails is recorded as not evaluated with its message - the run goes on
  METHOD failing_source_recorded.
    given_sample_flow( ).
    mo_dao->ms_config-accounts[ flow_acct = 'CASH' ]-eval_class = gc-failing.
    evaluate( ).
    DATA(ls_item) = mo_dao->mt_items[ flow_acct = 'CASH' ].
    cl_abap_unit_assert=>assert_equals( act = ls_item-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-not_evaluated msg = 'Failed' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_item-reason sub = 'DFKKOP' ) >= 0 )
                                      msg = 'Message of the source' ).
  ENDMETHOD.


  " Rule: a source that answers nothing has not evaluated the account
  METHOD empty_answer_not_evaluated.
    given_sample_flow( ).
    CLEAR mo_source->mt_rows.
    evaluate( ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_items[ flow_acct = 'PAYABLE' ]-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                                        msg = 'Empty answer: not evaluated' ).
  ENDMETHOD.


  " Rule: a configuration problem makes the evaluation partial and is returned - no figure changes
  METHOD config_problem_partial.
    given_sample_flow( ).
    mo_dao->ms_config-accounts[ flow_acct = 'CASH' ]-eval_class = gc-source.
    mo_dao->ms_config-rules[ 1 ]-stage_id = 'NO_SUCH_STAGE'.
    DATA(lt_results) = evaluate( ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( lt_results[ 1 ]-problems[ msgno = zif_ca_ops_flow_types=>gc_msg-rule_stage ] ) )
      msg = 'Problem returned' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-status
                                        exp = zif_ca_ops_flow_types=>gc_status-partial msg = 'Partial' ).
  ENDMETHOD.


  " Rule: test mode evaluates but writes and commits nothing
  METHOD test_mode_writes_nothing.
    given_sample_flow( ).
    DATA(lt_results) = evaluate( iv_test_mode = abap_true ).
    cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_saved msg = 'Nothing saved' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_commits exp = 0 msg = 'No commit' ).
    cl_abap_unit_assert=>assert_not_initial( act = lt_results[ 1 ]-items msg = 'Items returned' ).
  ENDMETHOD.


  " Rule: a flow whose business process is not in effect is skipped (323), nothing written
  METHOD inactive_process_skipped.
    given_sample_flow( ).
    INSERT CONV #( gc-process ) INTO TABLE mo_catalog->mt_off.
    DATA(lt_results) = evaluate( ).
    cl_abap_unit_assert=>assert_true( act = lt_results[ 1 ]-skipped msg = 'Skipped' ).
    cl_abap_unit_assert=>assert_equals( act = lt_results[ 1 ]-problems[ 1 ]-msgno
                                        exp = zif_ca_ops_flow_types=>gc_msg-process_off msg = 'Message 323' ).
    cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_saved msg = 'Nothing saved' ).
  ENDMETHOD.


  " Rule: evaluations older than FLOW_RETENTION_DAYS before the key date are removed with the save
  METHOD retention_removes_old.
    given_sample_flow( ).
    mo_seed->set( iv_name = zif_ca_ops_flow_types=>gc_param-retention iv_value = '30' ).
    DATA(lt_results) = evaluate( ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_before exp = CONV d( gc-key_date - 30 ) msg = 'Cut-off' ).
    cl_abap_unit_assert=>assert_equals( act = lt_results[ 1 ]-purged exp = 2 msg = 'Removed count' ).
  ENDMETHOD.


  " Rule: another stage rule is another configuration version
  METHOD changed_rule_new_version.
    given_sample_flow( ).
    evaluate( ).
    mo_dao->ms_config-rules[ 1 ]-origin = 'ZQ'.
    evaluate( ).
    cl_abap_unit_assert=>assert_differs( act = mo_dao->mt_saved[ 2 ]-cfg_version
                                         exp = mo_dao->mt_saved[ 1 ]-cfg_version
                                         msg = 'Changed rule, changed version' ).
  ENDMETHOD.


  " Rule: without ZCA_OPS 16 for the area nothing is evaluated
  METHOD not_authorised_raises.
    given_sample_flow( ).
    mo_auth->mv_allowed = abap_false.
    TRY.
        evaluate( ).
        cl_abap_unit_assert=>fail( msg = 'Authorisation not checked' ).
      CATCH zcx_ca_ops_error.
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_saved msg = 'Nothing saved' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
