*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_alert_dao.clas.testclasses.abap
*& Purpose:
*& SQL tests of the alert DAO claim / repeat-key logic on cl_osql_test_environment
*& doubles; does not prove live SAP runtime behavior (the unique index INT that
*& rejects parallel inserts exists only in the target system).
*& Modification log:
*& 2026-11-06 | Initial version (audit A17).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCD_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-06 | ltc_alert_dao_reads: rules, channels, log read and insert (coverage gap closure).
*& 2026-11-07 | Second channel of the ordering test is APPLOG (webhook channel removed).
*&---------------------------------------------------------------------*
CLASS ltc_alert_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_intent TYPE zif_cd_ops_types=>ty_intent_key VALUE 'A17INTENT0000000000000000000000000000001'.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_alert_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS intent_log
      IMPORTING
        iv_alert_id   TYPE zif_cd_ops_types=>ty_run_id
      RETURNING
        VALUE(rs_log) TYPE zif_cd_ops_types=>ty_alert_log.

    METHODS second_claim_is_refused FOR TESTING.
    METHODS failed_intent_can_retry FOR TESTING.
    METHODS repeat_keys_only_carried FOR TESTING.

ENDCLASS.



CLASS ltc_alert_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCD_OPS_ALLOG' )
                                                                            ( 'ZCD_OPS_FINDING' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ops_alert_dao( ).
  ENDMETHOD.


  METHOD intent_log.
    rs_log-alert_id   = iv_alert_id.
    rs_log-rule_id    = 'EBS_BLOCK'.
    rs_log-intent_key = gc_intent.
    rs_log-status     = zif_cd_ops_types=>gc_alert_status-claimed.
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
        ls_first-status = zif_cd_ops_types=>gc_alert_status-failed.
        mo_cut->complete( ls_first ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->claim( intent_log( '000000000000000000000000000000E2' ) )
                                           msg = 'A failed intent must be claimable again' ).
        SELECT MAX( attempt ) FROM zcd_ops_allog WHERE intent_key = @gc_intent INTO @DATA(lv_attempt).
        cl_abap_unit_assert=>assert_equals( act = lv_attempt exp = 2 msg = 'The retry is attempt 2' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A17: only findings carried forward (OCCURRENCES > 1) are repeat keys
  METHOD repeat_keys_only_carried.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ops_finding.
    CONSTANTS lc_run TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000F1'.
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

ENDCLASS.


"! OSQL tests of the rule, channel and log reads and the log insert (ZCD_OPS_ALRULE,
"! ZCD_OPS_ALCHN and ZCD_OPS_ALLOG doubled)
CLASS ltc_alert_dao_reads DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        rule_ebs  TYPE zif_cd_ops_types=>ty_rule_id VALUE 'EBS_BLOCK',
        rule_any  TYPE zif_cd_ops_types=>ty_rule_id VALUE 'ANY_ABORT',
        rule_hck  TYPE zif_cd_ops_types=>ty_rule_id VALUE 'HCK_RED',
        rule_off  TYPE zif_cd_ops_types=>ty_rule_id VALUE 'EBS_OFF',
        any_area  TYPE zif_cd_ops_types=>ty_pe_area VALUE '*',
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
    DATA mo_cut TYPE REF TO zif_cd_ops_alert_dao.

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
      i_dependency_list = VALUE #( ( 'ZCD_OPS_ALRULE' ) ( 'ZCD_OPS_ALCHN' ) ( 'ZCD_OPS_ALLOG' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ops_alert_dao( ).
  ENDMETHOD.


  " Rule: active rules of the payment engine area plus the '*' rules; inactive and other areas excluded
  METHOD rules_of_area_and_any.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ops_alrule WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ops_alrule.
    TRY.
        ls_row-rule_id = gc_test-rule_ebs.
        ls_row-pe_area = zif_cd_ops_types=>gc_pe_area-ebs.
        ls_row-active  = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-rule_id = gc_test-rule_any.
        ls_row-pe_area = gc_test-any_area.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-rule_id = gc_test-rule_hck.
        ls_row-pe_area = zif_cd_ops_types=>gc_pe_area-health_check.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-rule_id = gc_test-rule_off.
        ls_row-pe_area = zif_cd_ops_types=>gc_pe_area-ebs.
        ls_row-active  = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_rules) = mo_cut->get_rules( zif_cd_ops_types=>gc_pe_area-ebs ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rules ) exp = 2 msg = 'EBS rule and * rule' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rules[ 1 ]-rule_id exp = gc_test-rule_any
                                            msg = 'Ordered by rule ID' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every channel row, ordered by channel
  METHOD channels_ordered.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ops_alchn WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ops_alchn.
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
    DATA lt_log TYPE zif_cd_ops_types=>tt_alert_log.
    DATA ls_log TYPE zif_cd_ops_types=>ty_alert_log.
    TRY.
        ls_log-alert_id = gc_test-alert_old.
        ls_log-rule_id  = gc_test-rule_ebs.
        ls_log-sent_at  = gc_test-early.
        INSERT ls_log INTO TABLE lt_log.
        ls_log-alert_id = gc_test-alert_new.
        ls_log-sent_at  = gc_test-late.
        INSERT ls_log INTO TABLE lt_log.
        mo_cut->insert_log( lt_log ).
        DATA(lt_read) = mo_cut->get_log( iv_rule_id = gc_test-rule_ebs iv_since = gc_test-since ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_read ) exp = 2 msg = 'Both rows inserted' ).
        cl_abap_unit_assert=>assert_equals( act = lt_read[ 1 ]-sent_at exp = gc_test-late msg = 'Newest first' ).
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->get_log( iv_rule_id = gc_test-rule_hck iv_since = gc_test-before )
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
          act = mo_cut->get_log( iv_rule_id = gc_test-rule_ebs iv_since = gc_test-before )
          msg = 'Nothing written' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
