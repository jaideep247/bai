*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_ops_policy.clas.testclasses.abap
*& Purpose:
*& Pure tests of the file-monitoring operations rules: manual status needs a
*& reason and a transition the state machine allows (design 6.4); a PRISM
*& request handled manually needs request, reference and reason (6.5).
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
CLASS ltc_ops_policy DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS sent_file
      RETURNING
        VALUE(rs_file) TYPE zif_cd_fmon_types=>ty_file.

    METHODS manual_needs_reason          FOR TESTING.
    METHODS manual_backward_is_refused   FOR TESTING.
    METHODS manual_forward_is_allowed    FOR TESTING.
    METHODS handled_needs_reference      FOR TESTING.
    METHODS handled_complete_is_accepted FOR TESTING.
ENDCLASS.


CLASS ltc_ops_policy IMPLEMENTATION.

  METHOD sent_file.
    rs_file-direction = zif_cd_fmon_types=>gc_direction-outbound.
    rs_file-stage     = zif_cd_fmon_types=>gc_stage-sent.
  ENDMETHOD.


  " Rule: nothing is set by hand without a reason
  METHOD manual_needs_reason.
    TRY.
        DATA(ls_decision) = zcl_cd_fmon_ops_policy=>check_manual( iv_stage  = zif_cd_fmon_types=>gc_stage-ack
                                                                  iv_reason = space
                                                                  is_file   = sent_file( ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = '062'
                                            msg = 'A manual status without reason must be refused (062)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a stage the state machine would not reach is refused by hand too
  METHOD manual_backward_is_refused.
    TRY.
        DATA(ls_decision) = zcl_cd_fmon_ops_policy=>check_manual( iv_stage  = zif_cd_fmon_types=>gc_stage-generated
                                                                  iv_reason = 'PRISM log missing'
                                                                  is_file   = sent_file( ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zcl_cd_fmon_ops_policy=>gc_msg-not_allowed
                                            msg = 'SENT -> GENERATED must be refused (230)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: SENT -> ACK_RECEIVED with a reason is allowed (ACK table row missing)
  METHOD manual_forward_is_allowed.
    TRY.
        cl_abap_unit_assert=>assert_true(
          act = zcl_cd_fmon_ops_policy=>check_manual( iv_stage  = zif_cd_fmon_types=>gc_stage-ack
                                                      iv_reason = 'Bank confirmed by e-mail'
                                                      is_file   = sent_file( ) )-allowed
          msg = 'SENT -> ACK_RECEIVED with reason must be allowed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (PRISM, record only): request, handling reference and reason are all required
  METHOD handled_needs_reference.
    TRY.
        DATA(ls_decision) = zcl_cd_fmon_ops_policy=>check_handled( iv_request_ref = 'PR-2026-000123'
                                                                   iv_reference   = space
                                                                   iv_reason      = 'Paid by manual cheque' ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zcl_cd_fmon_ops_policy=>gc_msg-incomplete
                                            msg = 'Handled manually without reference must be refused (232)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD handled_complete_is_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true(
          act = zcl_cd_fmon_ops_policy=>check_handled( iv_request_ref = 'PR-2026-000123'
                                                       iv_reference   = 'INC0012345'
                                                       iv_reason      = 'Paid by manual cheque' )-allowed
          msg = 'A complete handled-manually record must be accepted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
