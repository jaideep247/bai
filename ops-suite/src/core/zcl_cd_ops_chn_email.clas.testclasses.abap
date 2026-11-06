*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_chn_email.clas.testclasses.abap
*& Purpose:
*& Unit tests of the e-mail alert channel through test seams BCS_SEND and
*& BCS_COMMIT: no recipient raises 021, a sent mail returns, a refused send
*& raises 026 (A45), a BCS exception becomes 020. Nothing is sent and
*& nothing is committed; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltc_chn_email DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_rule TYPE zif_cd_ops_types=>ty_rule_id VALUE 'EBS_BLOCK'.
    CONSTANTS gc_recipients TYPE zif_cd_ops_types=>ty_alert_dest VALUE 'ops@example.com; treasury@example.com'.
    CONSTANTS gc_msgno_no_recipient TYPE symsgno VALUE '021'.
    CONSTANTS gc_msgno_refused TYPE symsgno VALUE '026'.
    CONSTANTS gc_msgno_bcs_error TYPE symsgno VALUE '020'.

    TYPES:
      BEGIN OF ty_flags,
        no_recipient TYPE abap_bool,
        refused      TYPE abap_bool,
        bcs_error    TYPE abap_bool,
      END OF ty_flags.

    DATA mo_cut TYPE REF TO zif_cd_ops_alert_channel.
    DATA ms_message TYPE zif_cd_ops_types=>ty_alert_message.

    METHODS setup.
    METHODS teardown.
    METHODS sent_mail_returns FOR TESTING.
    METHODS no_recipient_raises_021 FOR TESTING.
    METHODS refused_send_raises_026 FOR TESTING.
    METHODS bcs_error_raises_020 FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS assert_raises
      IMPORTING
        iv_msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_chn_email IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_cd_ops_chn_email( ).
    CLEAR ms_message.
    ms_message-rule_id     = gc_rule.
    ms_message-destination = gc_recipients.
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.


  " Both seams are injected in every scenario - no test reaches BCS or COMMIT WORK
  METHOD configure_scenario.
    IF is_flags-no_recipient = abap_true.
      CLEAR ms_message-destination.
    ENDIF.
    IF is_flags-refused = abap_true.
      TEST-INJECTION bcs_send.
        lv_sent = abap_false.
      END-TEST-INJECTION.
    ELSEIF is_flags-bcs_error = abap_true.
      " BCS raised: the seam leaves its exception behind
      TEST-INJECTION bcs_send.
        lx_error = NEW cx_send_req_bcs( ).
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION bcs_send.
        lv_sent = abap_true.
      END-TEST-INJECTION.
    ENDIF.
    TEST-INJECTION bcs_commit.
    END-TEST-INJECTION.
  ENDMETHOD.


  METHOD assert_raises.
    TRY.
        mo_cut->deliver( ms_message ).
        cl_abap_unit_assert=>fail( msg = 'Delivery must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = iv_msgno
                                            msg = 'Raised with the expected message' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a mail BCS accepted is a delivered alert
  METHOD sent_mail_returns.
    TRY.
        configure_scenario( VALUE #( ) ).
        mo_cut->deliver( ms_message ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Delivered without exception' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a route without recipients is a configuration error (021), nothing is sent
  METHOD no_recipient_raises_021.
    configure_scenario( VALUE #( no_recipient = abap_true ) ).
    assert_raises( gc_msgno_no_recipient ).
  ENDMETHOD.


  " Rule (A45): a send BCS refused is not logged as sent (026)
  METHOD refused_send_raises_026.
    configure_scenario( VALUE #( refused = abap_true ) ).
    assert_raises( gc_msgno_refused ).
  ENDMETHOD.


  " Rule: a BCS exception is a failed delivery (020)
  METHOD bcs_error_raises_020.
    configure_scenario( VALUE #( bcs_error = abap_true ) ).
    assert_raises( gc_msgno_bcs_error ).
  ENDMETHOD.

ENDCLASS.
