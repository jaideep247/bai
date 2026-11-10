*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_alert_dao.clas.testclasses.abap
*& Purpose:
*& SQL tests of the alert DAO claim / repeat-key logic on cl_osql_test_environment
*& doubles; does not prove live SAP runtime behavior (the unique index INT that
*& rejects parallel inserts exists only in the target system).
*& Modification log:
*& 2026-11-06 | Initial version (audit A17).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-06 | ltc_alert_dao_reads: rules, channels, log read and insert (coverage gap closure).
*& 2026-11-07 | Second channel of the ordering test is APPLOG (webhook channel removed).
*& 2026-11-10 | Moved from ZCL_CD_OPS_ALERT_DAO to the reusable framework ZCA_OPS (test include).
*& 2026-11-10 | facts_of_open_exceptions: GET_EXCEPTION_FACTS reads the open / assigned exceptions of the run.
*&---------------------------------------------------------------------*
CLASS ltc_alert_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_intent TYPE zif_ca_ops_types=>ty_intent_key VALUE 'A17INTENT0000000000000000000000000000001'.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_alert_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS intent_log
      IMPORTING
        iv_alert_id   TYPE zif_ca_ops_types=>ty_run_id
      RETURNING
        VALUE(rs_log) TYPE zif_ca_ops_types=>ty_alert_log.

    METHODS second_claim_is_refused FOR TESTING.
    METHODS failed_intent_can_retry FOR TESTING.
    METHODS repeat_keys_only_carried FOR TESTING.
    METHODS facts_of_open_exceptions FOR TESTING.

ENDCLASS.



CLASS ltc_alert_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCA_OPS_ALLOG' )
                                                                            ( 'ZCA_OPS_FINDING' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_alert_dao( ).
  ENDMETHOD.


  METHOD intent_log.
    rs_log-alert_id   = iv_alert_id.
    rs_log-rule_id    = 'ZT_BLOCK'.
    rs_log-intent_key = gc_intent.
    rs_log-status     = zif_ca_ops_types=>gc_alert_status-claimed.
  ENDMETHOD.


  " Audit A17: a second dispatcher of the same intent finds the claim and does not send
  METHOD second_claim_is_refused.
    TRY.
        cl_abap_unit_assert=>assert_false( act = mo_cut->claim( intent_log( '000000000000000000000000000000E1' ) )
                                           msg = 'The first claim must succeed' ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->claim( intent_log( '000000000000000000000000000000E2' ) )
                                          msg = 'The same intent must not be claimed twice' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A17: after a failed delivery the intent may be retried (next attempt)
  METHOD failed_intent_can_retry.
    TRY.
        DATA(ls_first) = intent_log( '000000000000000000000000000000E1' ).
        mo_cut->claim( ls_first ).
        ls_first-status = zif_ca_ops_types=>gc_alert_status-failed.
        mo_cut->complete( ls_first ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->claim( intent_log( '000000000000000000000000000000E2' ) )
                                           msg = 'A failed intent must be claimable again' ).
        SELECT MAX( attempt ) FROM zca_ops_allog WHERE intent_key = @gc_intent INTO @DATA(lv_attempt).
        cl_abap_unit_assert=>assert_equals( act = lv_attempt exp = 2 msg = 'The retry is attempt 2' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A17: only findings carried forward (OCCURRENCES > 1) are repeat keys
  METHOD repeat_keys_only_carried.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_finding.
    CONSTANTS lc_run TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000F1'.
    TRY.
        ls_row-run_id      = lc_run.
        ls_row-finding_no  = 1.
        ls_row-object_type = 'LINE'.
        ls_row-object_key  = 'S0001/1'.
        ls_row-check_code  = 'UNMAPPED_BTC'.
        ls_row-occurrences = 3.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-finding_no  = 2.
        ls_row-object_key  = 'S0001/2'.
        ls_row-occurrences = 1.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_keys) = mo_cut->get_repeat_keys( lc_run ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_keys ) exp = 1 msg = 'Only the carried finding' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( lt_keys[ object_type = 'LINE' object_key = 'S0001/1' check_code = 'UNMAPPED_BTC' ] ) )
          msg = 'The carried finding is S0001/1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " E-mail context: occurrences, due date and owner of the open / assigned exceptions of the run only
  METHOD facts_of_open_exceptions.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_finding.
    CONSTANTS lc_run TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000F2'.
    TRY.
        ls_row-run_id      = lc_run.
        ls_row-finding_no  = 1.
        ls_row-object_type = 'LINE'.
        ls_row-object_key  = 'S0001/1'.
        ls_row-check_code  = 'UNMAPPED_BTC'.
        ls_row-occurrences = 2.
        ls_row-due_date    = '20261111'.
        ls_row-owner       = 'ZT_OWNER'.
        ls_row-disposition = zif_ca_ops_types=>gc_disposition-open.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-finding_no  = 2.
        ls_row-object_key  = 'S0001/2'.
        ls_row-disposition = zif_ca_ops_types=>gc_disposition-information.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_facts) = mo_cut->get_exception_facts( lc_run ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_facts ) exp = 1 msg = 'Only the open exception' ).
        DATA(ls_fact) = lt_facts[ object_type = 'LINE' object_key = 'S0001/1' check_code = 'UNMAPPED_BTC' ].
        cl_abap_unit_assert=>assert_equals( act = ls_fact-occurrences exp = 2 msg = 'Occurrences' ).
        cl_abap_unit_assert=>assert_equals( act = ls_fact-due_date exp = '20261111' msg = 'Due date' ).
        cl_abap_unit_assert=>assert_equals( act = ls_fact-owner exp = 'ZT_OWNER' msg = 'Owner' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! OSQL tests of the rule, channel and log reads and the log insert (ZCA_OPS_ALRULE,
"! ZCA_OPS_ALCHN and ZCA_OPS_ALLOG doubled)
CLASS ltc_alert_dao_reads DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        rule_first  TYPE zif_ca_ops_types=>ty_rule_id VALUE 'ZT_BLOCK',
        rule_any  TYPE zif_ca_ops_types=>ty_rule_id VALUE 'ANY_ABORT',
        rule_second  TYPE zif_ca_ops_types=>ty_rule_id VALUE 'ZT_RED',
        rule_off  TYPE zif_ca_ops_types=>ty_rule_id VALUE 'ZT_OFF',
        any_area  TYPE zif_ca_ops_types=>ty_area VALUE '*',
        mail      TYPE c LENGTH 10 VALUE 'EMAIL',
        applog    TYPE c LENGTH 10 VALUE 'APPLOG',
        alert_old TYPE sysuuid_x16 VALUE '000000000000000000000000000000C1',
        alert_new TYPE sysuuid_x16 VALUE '000000000000000000000000000000C2',
        since     TYPE timestampl VALUE '20261105000000.0000000',
        before    TYPE timestampl VALUE '20261104000000.0000000',
        early     TYPE timestampl VALUE '20261105080000.0000000',
        late      TYPE timestampl VALUE '20261105090000.0000000',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_alert_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS rules_of_area_and_any FOR TESTING.
    METHODS channels_ordered FOR TESTING.
    METHODS inserted_log_read_newest FOR TESTING.
    METHODS empty_log_inserts_nothing FOR TESTING.
ENDCLASS.


CLASS ltc_alert_dao_reads IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCA_OPS_ALRULE' ) ( 'ZCA_OPS_ALCHN' ) ( 'ZCA_OPS_ALLOG' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_alert_dao( ).
  ENDMETHOD.


  " Rule: active rules of the area plus the '*' rules; inactive and other areas excluded
  METHOD rules_of_area_and_any.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_alrule WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_alrule.
    TRY.
        ls_row-rule_id = gc_test-rule_first.
        ls_row-area = zcl_ca_ops_param_seed=>gc_test_area-first.
        ls_row-active  = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-rule_id = gc_test-rule_any.
        ls_row-area = gc_test-any_area.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-rule_id = gc_test-rule_second.
        ls_row-area = zcl_ca_ops_param_seed=>gc_test_area-second.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-rule_id = gc_test-rule_off.
        ls_row-area = zcl_ca_ops_param_seed=>gc_test_area-first.
        ls_row-active  = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_rules) = mo_cut->get_rules( zcl_ca_ops_param_seed=>gc_test_area-first ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rules ) exp = 2 msg = 'Area rule and * rule' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rules[ 1 ]-rule_id exp = gc_test-rule_any
                                            msg = 'Ordered by rule ID' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every channel row, ordered by channel
  METHOD channels_ordered.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_alchn WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_alchn.
    TRY.
        ls_row-channel = gc_test-mail.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-channel = gc_test-applog.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_channels) = mo_cut->get_channels( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_channels ) exp = 2 msg = 'Both channels' ).
        cl_abap_unit_assert=>assert_equals( act = lt_channels[ 1 ]-channel exp = gc_test-applog
                                            msg = 'Ordered by channel' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: inserted log rows are read back per rule since a time, newest first
  METHOD inserted_log_read_newest.
    DATA lt_log TYPE zif_ca_ops_types=>tt_alert_log.
    DATA ls_log TYPE zif_ca_ops_types=>ty_alert_log.
    TRY.
        ls_log-alert_id = gc_test-alert_old.
        ls_log-rule_id  = gc_test-rule_first.
        ls_log-sent_at  = gc_test-early.
        INSERT ls_log INTO TABLE lt_log.
        ls_log-alert_id = gc_test-alert_new.
        ls_log-sent_at  = gc_test-late.
        INSERT ls_log INTO TABLE lt_log.
        mo_cut->insert_log( lt_log ).
        DATA(lt_read) = mo_cut->get_log( iv_rule_id = gc_test-rule_first iv_since = gc_test-since ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_read ) exp = 2 msg = 'Both rows inserted' ).
        cl_abap_unit_assert=>assert_equals( act = lt_read[ 1 ]-sent_at exp = gc_test-late msg = 'Newest first' ).
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->get_log( iv_rule_id = gc_test-rule_second iv_since = gc_test-before )
          msg = 'Other rule has no log' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: an empty log list writes nothing
  METHOD empty_log_inserts_nothing.
    TRY.
        mo_cut->insert_log( VALUE #( ) ).
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->get_log( iv_rule_id = gc_test-rule_first iv_since = gc_test-before )
          msg = 'Nothing written' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
