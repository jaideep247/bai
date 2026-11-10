*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_exc_policy.clas.testclasses.abap
*& Purpose:
*& Pure tests of the exception lifecycle rules (design 6.1): who may assign,
*& resolve, request and approve a waiver (four-eyes). No doubles.
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-10 | Moved from ZCL_CD_OPS_EXC_POLICY to the reusable framework ZCA_OPS (test include).
*&---------------------------------------------------------------------*
CLASS ltc_policy DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        requester TYPE syuname VALUE 'REQUESTER',
        approver  TYPE syuname VALUE 'APPROVER',
        owner     TYPE syuname VALUE 'OWNER',
        today     TYPE d VALUE '20261106',
        reason    TYPE zif_ca_ops_exc_types=>ty_reason VALUE 'Bank confirmed the duplicate',
      END OF gc_test.

    METHODS state
      IMPORTING
        iv_disposition  TYPE zif_ca_ops_types=>ty_disposition
        iv_requested_by TYPE syuname OPTIONAL
      RETURNING
        VALUE(rs_state) TYPE zif_ca_ops_exc_types=>ty_state.

    METHODS assign_needs_owner           FOR TESTING.
    METHODS assign_open_is_allowed       FOR TESTING.
    METHODS resolve_needs_reason         FOR TESTING.
    METHODS closed_cannot_be_resolved    FOR TESTING.
    METHODS waiver_end_not_in_past       FOR TESTING.
    METHODS second_request_is_refused    FOR TESTING.
    METHODS approve_needs_request        FOR TESTING.
    METHODS requester_cannot_approve     FOR TESTING.
    METHODS second_user_may_approve      FOR TESTING.
ENDCLASS.


CLASS ltc_policy IMPLEMENTATION.

  METHOD state.
    rs_state-disposition   = iv_disposition.
    rs_state-waiver_req_by = iv_requested_by.
  ENDMETHOD.


  " Rule: an exception is assigned to a named owner, never to nobody
  METHOD assign_needs_owner.
    TRY.
        DATA(ls_decision) = zcl_ca_ops_exc_policy=>can_assign( is_state = state( zif_ca_ops_types=>gc_disposition-open )
                                                               iv_owner = space ).
        cl_abap_unit_assert=>assert_false( act = ls_decision-allowed msg = 'Assign without owner must be refused' ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zif_ca_ops_exc_types=>gc_msg-owner_missing
                                            msg = 'The reason must be message 066' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: open and assigned exceptions can be (re)assigned
  METHOD assign_open_is_allowed.
    TRY.
        cl_abap_unit_assert=>assert_true(
          act = zcl_ca_ops_exc_policy=>can_assign( is_state = state( zif_ca_ops_types=>gc_disposition-open )
                                                   iv_owner = gc_test-owner )-allowed
          msg = 'An open exception must be assignable' ).
        cl_abap_unit_assert=>assert_true(
          act = zcl_ca_ops_exc_policy=>can_assign( is_state = state( zif_ca_ops_types=>gc_disposition-assigned )
                                                   iv_owner = gc_test-owner )-allowed
          msg = 'An assigned exception must be re-assignable' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: nothing is resolved without a reason (audit trail)
  METHOD resolve_needs_reason.
    TRY.
        DATA(ls_decision) = zcl_ca_ops_exc_policy=>can_resolve( is_state  = state( zif_ca_ops_types=>gc_disposition-assigned )
                                                                iv_reason = space ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zif_ca_ops_exc_types=>gc_msg-reason_missing
                                            msg = 'Resolve without reason must be refused with 062' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: resolved, waived and superseded exceptions are closed
  METHOD closed_cannot_be_resolved.
    TRY.
        DATA(ls_decision) = zcl_ca_ops_exc_policy=>can_resolve( is_state  = state( zif_ca_ops_types=>gc_disposition-resolved )
                                                                iv_reason = gc_test-reason ).
        cl_abap_unit_assert=>assert_false( act = ls_decision-allowed msg = 'A resolved exception is closed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zif_ca_ops_exc_types=>gc_msg-not_open
                                            msg = 'The reason must be message 061' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a waiver runs until a date that is not in the past
  METHOD waiver_end_not_in_past.
    TRY.
        DATA(ls_decision) = zcl_ca_ops_exc_policy=>can_request_waiver(
                              is_state    = state( zif_ca_ops_types=>gc_disposition-open )
                              iv_reason   = gc_test-reason
                              iv_valid_to = '20261105'
                              iv_today    = gc_test-today ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zif_ca_ops_exc_types=>gc_msg-date_in_past
                                            msg = 'A waiver ending yesterday must be refused with 065' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one waiver request at a time
  METHOD second_request_is_refused.
    TRY.
        DATA(ls_decision) = zcl_ca_ops_exc_policy=>can_request_waiver(
                              is_state    = state( iv_disposition  = zif_ca_ops_types=>gc_disposition-open
                                                   iv_requested_by = gc_test-requester )
                              iv_reason   = gc_test-reason
                              iv_valid_to = gc_test-today
                              iv_today    = gc_test-today ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zif_ca_ops_exc_types=>gc_msg-request_pending
                                            msg = 'A pending request must block a second one (067)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only a requested waiver can be approved
  METHOD approve_needs_request.
    TRY.
        DATA(ls_decision) = zcl_ca_ops_exc_policy=>can_approve_waiver(
                              is_state    = state( zif_ca_ops_types=>gc_disposition-open )
                              iv_approver = gc_test-approver ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zif_ca_ops_exc_types=>gc_msg-no_request
                                            msg = 'Approve without request must be refused with 064' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (four-eyes): the requester cannot approve their own waiver
  METHOD requester_cannot_approve.
    TRY.
        DATA(ls_decision) = zcl_ca_ops_exc_policy=>can_approve_waiver(
                              is_state    = state( iv_disposition  = zif_ca_ops_types=>gc_disposition-open
                                                   iv_requested_by = gc_test-requester )
                              iv_approver = gc_test-requester ).
        cl_abap_unit_assert=>assert_false( act = ls_decision-allowed msg = 'Self-approval must be refused' ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zif_ca_ops_exc_types=>gc_msg-same_user
                                            msg = 'The reason must be message 063' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (four-eyes): a second user approves the pending request
  METHOD second_user_may_approve.
    TRY.
        cl_abap_unit_assert=>assert_true(
          act = zcl_ca_ops_exc_policy=>can_approve_waiver(
                  is_state    = state( iv_disposition  = zif_ca_ops_types=>gc_disposition-assigned
                                       iv_requested_by = gc_test-requester )
                  iv_approver = gc_test-approver )-allowed
          msg = 'A different user must be able to approve' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
