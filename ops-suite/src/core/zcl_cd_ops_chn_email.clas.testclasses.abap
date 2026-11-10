*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_chn_email.clas.testclasses.abap
*& Purpose:
*& Unit tests of the e-mail alert channel through test seams DLI_READ, BCS_SEND
*& and BCS_COMMIT: no recipient raises 021, a name that is not a shared SO23
*& list raises 027 before anything is sent, a sent mail returns, a refused send
*& raises 026 (A45), a BCS exception becomes 020; CHECK_DESTINATION lists the
*& unknown and over-long names. Nothing is read from SAPoffice, sent or
*& committed; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-07 | Recipients are SO23 shared lists: seam DLI_READ, 027 and CHECK_DESTINATION tests.
*& 2026-11-10 | commit_failure_raises_806: a failed COMMIT WORK AND WAIT is a failed delivery.
*&---------------------------------------------------------------------*
CLASS ltc_chn_email DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_rule TYPE zif_cd_ops_types=>ty_rule_id VALUE 'EBS_BLOCK'.
    "! Two shared SO23 lists, semicolon and blank tolerated, any case
    CONSTANTS gc_recipients TYPE zif_cd_ops_types=>ty_alert_dest VALUE 'ZCD_RTBSUP; zcd_rtblead'.
    "! The only name the injected SAPoffice lookup does not know
    CONSTANTS gc_unknown_list TYPE string VALUE `ZCD_NOLIST`.
    "! Longer than SO_OBJ_NAM: must never resolve to a truncated list
    CONSTANTS gc_long_list TYPE string VALUE `ZCD_RTB_SUPPORT_LIST`.
    CONSTANTS gc_msgno_no_recipient TYPE symsgno VALUE '021'.
    CONSTANTS gc_msgno_unknown_list TYPE symsgno VALUE '027'.
    CONSTANTS gc_msgno_refused TYPE symsgno VALUE '026'.
    CONSTANTS gc_msgno_bcs_error TYPE symsgno VALUE '020'.
    CONSTANTS gc_msgno_commit_failed TYPE symsgno VALUE '806'.

    TYPES:
      BEGIN OF ty_flags,
        no_recipient TYPE abap_bool,
        refused      TYPE abap_bool,
        bcs_error    TYPE abap_bool,
        unknown_list TYPE abap_bool,
        commit_fails TYPE abap_bool,
      END OF ty_flags.

    DATA mo_cut TYPE REF TO zif_cd_ops_alert_channel.
    DATA ms_message TYPE zif_cd_ops_types=>ty_alert_message.

    METHODS setup.
    METHODS teardown.
    METHODS sent_mail_returns FOR TESTING.
    METHODS no_recipient_raises_021 FOR TESTING.
    METHODS refused_send_raises_026 FOR TESTING.
    METHODS bcs_error_raises_020 FOR TESTING.
    METHODS unknown_list_raises_027 FOR TESTING.
    METHODS known_lists_are_valid FOR TESTING.
    METHODS unknown_and_long_listed FOR TESTING.
    METHODS commit_failure_raises_806 FOR TESTING.

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
    IF is_flags-unknown_list = abap_true.
      ms_message-destination = |{ gc_recipients },{ gc_unknown_list }|.
    ENDIF.
    " SAPoffice: every list is shared except the one unknown name
    TEST-INJECTION dli_read.
      lv_found = xsdbool( lv_dli <> 'ZCD_NOLIST' ).
    END-TEST-INJECTION.
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
    IF is_flags-commit_fails = abap_true.
      TEST-INJECTION bcs_commit.
        " SAP update task failed (COMMIT WORK AND WAIT return code 4)
        lv_commit_subrc = 4.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION bcs_commit.
        lv_commit_subrc = 0.
      END-TEST-INJECTION.
    ENDIF.
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

  " Rule: a name that is not a shared SO23 list stops the route before BCS (027)
  METHOD unknown_list_raises_027.
    configure_scenario( VALUE #( unknown_list = abap_true ) ).
    assert_raises( gc_msgno_unknown_list ).
  ENDMETHOD.


  " Rule (B18): a send request whose commit failed is not logged as sent (806)
  METHOD commit_failure_raises_806.
    configure_scenario( VALUE #( commit_fails = abap_true ) ).
    assert_raises( gc_msgno_commit_failed ).
  ENDMETHOD.


  " Rule: shared lists are deliverable - nothing reported
  METHOD known_lists_are_valid.
    configure_scenario( VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( act = mo_cut->check_destination( gc_recipients )
                                         msg = 'Shared SO23 lists are valid' ).
  ENDMETHOD.


  " Rule: unknown and over-long names are listed as given, known ones are not
  METHOD unknown_and_long_listed.
    configure_scenario( VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->check_destination( CONV #( |{ gc_recipients },{ gc_unknown_list },{ gc_long_list }| ) )
      exp = |{ gc_unknown_list },{ gc_long_list }|
      msg = 'Unknown and over-long list names reported' ).
  ENDMETHOD.

ENDCLASS.
