*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_alert_dao.clas.testclasses.abap
*& Purpose:
*& SQL tests of the alert DAO claim / repeat-key logic on cl_osql_test_environment
*& doubles; does not prove live SAP runtime behavior (the unique index INT that
*& rejects parallel inserts exists only in the target system).
*& Modification log:
*& 2026-11-06 | Initial version (audit A17).
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
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCD_OPS_ALERT_LOG' )
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
        SELECT MAX( attempt ) FROM zcd_ops_alert_log WHERE intent_key = @gc_intent INTO @DATA(lv_attempt).
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
