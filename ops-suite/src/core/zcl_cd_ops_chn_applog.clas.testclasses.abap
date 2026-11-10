*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_chn_applog.clas.testclasses.abap
*& Purpose:
*& Unit tests of the application log alert channel through its test seams:
*& delivered log, log not created, log not saved, partial log (A45) and a
*& refresh failure that is not an error. Every BAL call is replaced by
*& TEST-INJECTION, nothing is written; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-10 | Create and save failures: own messages 800 / 801 with the return code.
*&---------------------------------------------------------------------*
CLASS ltc_chn_applog DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_rule TYPE zif_cd_ops_types=>ty_rule_id VALUE 'EBS_BLOCK'.
    CONSTANTS gc_destination TYPE zif_cd_ops_types=>ty_alert_dest VALUE 'ZCD_OPS/EBS'.
    CONSTANTS gc_msgno_not_created TYPE symsgno VALUE '800'.
    CONSTANTS gc_msgno_not_saved TYPE symsgno VALUE '801'.
    CONSTANTS gc_save_subrc TYPE sysubrc VALUE 2.
    CONSTANTS gc_msgno_partial TYPE symsgno VALUE '025'.

    TYPES:
      BEGIN OF ty_flags,
        create_fails  TYPE abap_bool,
        log_full      TYPE abap_bool,
        save_fails    TYPE abap_bool,
        refresh_fails TYPE abap_bool,
      END OF ty_flags.

    DATA mo_cut TYPE REF TO zif_cd_ops_alert_channel.

    METHODS setup.
    METHODS teardown.
    METHODS saved_log_is_delivered FOR TESTING.
    METHODS create_failure_raises_800 FOR TESTING.
    METHODS save_failure_raises_801 FOR TESTING.
    METHODS partial_log_raises_025 FOR TESTING.
    METHODS refresh_failure_is_ignored FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RAISING
        zcx_cd_ops_error.
    METHODS assert_raises
      IMPORTING
        iv_msgno TYPE symsgno
      RETURNING
        VALUE(rx_error) TYPE REF TO zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_chn_applog IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_cd_ops_chn_applog( ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.


  " Every BAL call is injected in every scenario - no test reaches the real function modules
  METHOD configure_scenario.
    IF is_flags-create_fails = abap_true.
      TEST-INJECTION bal_create.
        lv_subrc = 1.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION bal_create.
        lv_subrc = 0.
      END-TEST-INJECTION.
    ENDIF.
    IF is_flags-log_full = abap_true.
      " the first line is added, the second finds the log full
      TEST-INJECTION bal_add.
        lv_subrc = COND #( WHEN lv_added = 0 THEN 0 ELSE 3 ).
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION bal_add.
        lv_subrc = 0.
      END-TEST-INJECTION.
    ENDIF.
    IF is_flags-save_fails = abap_true.
      TEST-INJECTION bal_save.
        lv_save_subrc = gc_save_subrc.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION bal_save.
        lv_save_subrc = 0.
      END-TEST-INJECTION.
    ENDIF.
    IF is_flags-refresh_fails = abap_true.
      TEST-INJECTION bal_refresh.
        lv_subrc = 1.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION bal_refresh.
        lv_subrc = 0.
      END-TEST-INJECTION.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    DATA ls_message TYPE zif_cd_ops_types=>ty_alert_message.
    ls_message-rule_id     = gc_rule.
    ls_message-destination = gc_destination.
    ls_message-severity    = zif_cd_ops_types=>gc_severity-error.
    ls_message-text        = |first line{ cl_abap_char_utilities=>newline }second line|.
    mo_cut->deliver( ls_message ).
  ENDMETHOD.


  METHOD assert_raises.
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Delivery must raise' ).
      CATCH zcx_cd_ops_error INTO rx_error.
        cl_abap_unit_assert=>assert_equals( act = rx_error->if_t100_message~t100key-msgno
                                            exp = iv_msgno
                                            msg = 'Raised with the expected message' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a created, filled and saved log is a delivered alert (no exception)
  METHOD saved_log_is_delivered.
    TRY.
        configure_scenario( VALUE #( ) ).
        act( ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Delivered without exception' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a log that cannot be created is a failed delivery (800, own number)
  METHOD create_failure_raises_800.
    configure_scenario( VALUE #( create_fails = abap_true ) ).
    assert_raises( gc_msgno_not_created ).
  ENDMETHOD.


  " Rule: a log that cannot be saved is a failed delivery (801), never logged as sent;
  " the message carries the return code of BAL_DB_SAVE
  METHOD save_failure_raises_801.
    configure_scenario( VALUE #( save_fails = abap_true ) ).
    DATA(lx_error) = assert_raises( gc_msgno_not_saved ).
    cl_abap_unit_assert=>assert_equals( act = condense( CONV string( lx_error->if_t100_dyn_msg~msgv3 ) )
                                        exp = condense( CONV string( gc_save_subrc ) )
                                        msg = 'The return code of BAL_DB_SAVE is kept in the message' ).
  ENDMETHOD.


  " Rule (A45): a log that stopped adding lines is saved but reported as partial (025)
  METHOD partial_log_raises_025.
    configure_scenario( VALUE #( log_full = abap_true ) ).
    assert_raises( gc_msgno_partial ).
  ENDMETHOD.


  " Rule: a failed memory refresh after a successful save is not a delivery failure
  METHOD refresh_failure_is_ignored.
    TRY.
        configure_scenario( VALUE #( refresh_fails = abap_true ) ).
        act( ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Delivered despite refresh failure' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
