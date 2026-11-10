*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_exc_policy.clas.testclasses.abap
*& Purpose:
*& Pure tests of the exception lifecycle rules (design 6.1): who may assign,
*& resolve, request and approve a waiver (four-eyes). No doubles.
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-10 | Moved from ZCL_CD_OPS_EXC_POLICY to the reusable framework ZCA_OPS (test include).
*& 2026-11-10 | Classification: allowed codes only (case ignored), open exceptions only.
*& 2026-11-10 | Company-code isolation (MAY_ACT): a user of one company code acts on its exceptions and on
*&            | area-level ones, never on another company code's or another area's (injected authorisations).
*&---------------------------------------------------------------------*
"! Authorisations of the simulated user: rows of ZCA_OPS (activity, area, company code; BUKRS DUMMY when
"! the caller passes no company code = any row of the area)
CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
    TYPES:
      BEGIN OF ty_grant,
        activity TYPE zif_ca_ops_auth=>ty_activity,
        area     TYPE zif_ca_ops_types=>ty_area,
        bukrs    TYPE bukrs,
      END OF ty_grant.
    DATA mt_grants TYPE STANDARD TABLE OF ty_grant WITH EMPTY KEY.
ENDCLASS.


CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~is_allowed.
    IF iv_bukrs IS INITIAL.
      rv_allowed = xsdbool( line_exists( mt_grants[ activity = iv_activity area = iv_area ] ) ).
      RETURN.
    ENDIF.
    rv_allowed = xsdbool( line_exists( mt_grants[ activity = iv_activity area = iv_area bukrs = iv_bukrs ] ) ).
  ENDMETHOD.
ENDCLASS.


"! MAY_ACT: user A has ZCA_OPS 02 for area ZT_OPS_A with BUKRS ZT01 only
CLASS ltc_isolation DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area       TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        other_area TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_B',
        own        TYPE bukrs VALUE 'ZT01',
        other      TYPE bukrs VALUE 'ZT02',
      END OF gc.
    DATA mo_auth TYPE REF TO ltd_auth.

    METHODS setup.
    METHODS act
      IMPORTING
        iv_area           TYPE zif_ca_ops_types=>ty_area
        iv_bukrs          TYPE bukrs
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    METHODS own_company_code_allowed    FOR TESTING.
    METHODS other_company_code_refused  FOR TESTING.
    METHODS area_level_with_area_auth   FOR TESTING.
    METHODS other_area_refused          FOR TESTING.
    METHODS display_does_not_change     FOR TESTING.
ENDCLASS.


CLASS ltc_isolation IMPLEMENTATION.

  METHOD setup.
    mo_auth = NEW #( ).
    mo_auth->mt_grants = VALUE #( ( activity = zif_ca_ops_auth=>gc_activity-change  area = gc-area bukrs = gc-own )
                                  ( activity = zif_ca_ops_auth=>gc_activity-display area = gc-area bukrs = gc-own ) ).
  ENDMETHOD.


  METHOD act.
    rv_allowed = zcl_ca_ops_exc_policy=>may_act( io_auth     = mo_auth
                                                 iv_activity = zif_ca_ops_auth=>gc_activity-change
                                                 iv_area     = iv_area
                                                 iv_bukrs    = iv_bukrs ).
  ENDMETHOD.


  " Rule: an exception of the user's company code may be changed
  METHOD own_company_code_allowed.
    TRY.
        cl_abap_unit_assert=>assert_true( act = act( iv_area = gc-area iv_bukrs = gc-own )
                                          msg = 'Own company code must be allowed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an exception of another company code is refused, although the area is authorised
  METHOD other_company_code_refused.
    TRY.
        cl_abap_unit_assert=>assert_false( act = act( iv_area = gc-area iv_bukrs = gc-other )
                                           msg = 'Another company code must be refused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an area-level exception (blank company code) needs the area authorisation only
  METHOD area_level_with_area_auth.
    TRY.
        cl_abap_unit_assert=>assert_true( act = act( iv_area = gc-area iv_bukrs = space )
                                          msg = 'Area-level exception must be allowed with the area' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no authorisation for the area - neither area-level nor company code
  METHOD other_area_refused.
    TRY.
        cl_abap_unit_assert=>assert_false( act = act( iv_area = gc-other_area iv_bukrs = space )
                                           msg = 'Area-level exception of another area must be refused' ).
        cl_abap_unit_assert=>assert_false( act = act( iv_area = gc-other_area iv_bukrs = gc-own )
                                           msg = 'Own company code in another area must be refused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the activity counts - display (03) does not allow approval (85)
  METHOD display_does_not_change.
    TRY.
        cl_abap_unit_assert=>assert_false(
          act = zcl_ca_ops_exc_policy=>may_act( io_auth     = mo_auth
                                                iv_activity = zif_ca_ops_auth=>gc_activity-approve
                                                iv_area     = gc-area
                                                iv_bukrs    = gc-own )
          msg = 'Approve without activity 85 must be refused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


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
    METHODS classify_allowed_code_only   FOR TESTING.
    METHODS closed_cannot_be_classified  FOR TESTING.
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



  " Rule: a reason code must be one of the configured codes (case ignored); blank is refused
  METHOD classify_allowed_code_only.
    DATA(ls_open) = state( zif_ca_ops_types=>gc_disposition-open ).
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_exc_policy=>can_classify( is_state       = ls_open
                                                 iv_reason_code = 'timing'
                                                 iv_allowed     = zif_ca_ops_exc_types=>gc_param_default-reason_codes )-allowed
      msg = 'TIMING is a delivered reason code' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_exc_policy=>can_classify( is_state       = ls_open
                                                 iv_reason_code = 'LATER'
                                                 iv_allowed     = zif_ca_ops_exc_types=>gc_param_default-reason_codes )-msgno
      exp = zif_ca_ops_exc_types=>gc_msg-reason_code_invalid
      msg = 'An unknown code is refused with 068' ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_ops_exc_policy=>can_classify( is_state       = ls_open
                                                 iv_reason_code = space
                                                 iv_allowed     = zif_ca_ops_exc_types=>gc_param_default-reason_codes )-allowed
      msg = 'A blank code is refused' ).
  ENDMETHOD.


  " Rule: only an open or assigned exception is classified
  METHOD closed_cannot_be_classified.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_exc_policy=>can_classify( is_state       = state( zif_ca_ops_types=>gc_disposition-resolved )
                                                 iv_reason_code = zif_ca_ops_exc_types=>gc_reason_code-investigating
                                                 iv_allowed     = zif_ca_ops_exc_types=>gc_param_default-reason_codes )-msgno
      exp = zif_ca_ops_exc_types=>gc_msg-not_open
      msg = 'A resolved exception is not classified' ).
  ENDMETHOD.

ENDCLASS.
