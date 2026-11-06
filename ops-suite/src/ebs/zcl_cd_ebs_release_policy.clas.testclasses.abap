*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_release_policy.clas.testclasses.abap
*& Purpose:
*& Pure tests of the blocked-line release rules (design 6.2): an approved
*& release turns exactly its block finding into information; four-eyes
*& approval; a request needs a line, a check code and a reason. No doubles.
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
CLASS ltc_release_policy DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        key       TYPE zif_cd_ops_types=>ty_object_key VALUE 'S0001/1',
        code      TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNMAPPED_BTC',
        requester TYPE syuname VALUE 'REQUESTER',
        approver  TYPE syuname VALUE 'APPROVER',
      END OF gc_test.

    METHODS block_finding
      IMPORTING
        iv_check_code     TYPE zif_cd_ops_types=>ty_check_code DEFAULT gc_test-code
        iv_object_type    TYPE zif_cd_ops_types=>ty_object_type DEFAULT 'LINE'
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.
    METHODS approved_release
      RETURNING
        VALUE(rt_releases) TYPE zif_cd_ebs_release_types=>tt_release.

    METHODS released_block_becomes_info  FOR TESTING.
    METHODS other_check_still_blocks     FOR TESTING.
    METHODS run_finding_never_released   FOR TESTING.
    METHODS requester_cannot_approve     FOR TESTING.
    METHODS second_user_may_approve      FOR TESTING.
    METHODS request_needs_line_and_check FOR TESTING.
ENDCLASS.


CLASS ltc_release_policy IMPLEMENTATION.

  METHOD block_finding.
    rs_finding-object_type = iv_object_type.
    rs_finding-object_key  = gc_test-key.
    rs_finding-check_code  = iv_check_code.
    rs_finding-severity    = zif_cd_ops_types=>gc_severity-block.
    rs_finding-action      = zif_cd_ops_types=>gc_action-block.
    rs_finding-message     = 'Code not in ZCD_BTC_MAP'.
  ENDMETHOD.


  METHOD approved_release.
    DATA ls_release TYPE zif_cd_ebs_release_types=>ty_release.
    ls_release-release_uuid = '000000000000000000000000000000A1'.
    ls_release-object_key   = gc_test-key.
    ls_release-check_code   = gc_test-code.
    ls_release-reason       = 'Treasury confirmed the code'.
    ls_release-status       = zif_cd_ebs_release_types=>gc_status-approved.
    ls_release-requested_by = gc_test-requester.
    ls_release-approved_by  = gc_test-approver.
    INSERT ls_release INTO TABLE rt_releases.
  ENDMETHOD.


  " Rule: the released block becomes information with the release named; it no longer blocks
  METHOD released_block_becomes_info.
    TRY.
        DATA(lt_findings) = zcl_cd_ebs_release_policy=>apply( it_findings = VALUE #( ( block_finding( ) ) )
                                                              it_releases = approved_release( ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-info
                                            msg = 'A released block must become information' ).
        cl_abap_unit_assert=>assert_differs( act = lt_findings[ 1 ]-action exp = zif_cd_ops_types=>gc_action-block
                                             msg = 'A released block must no longer carry action BLOCK' ).
        cl_abap_unit_assert=>assert_char_cp( act = lt_findings[ 1 ]-message exp = '*APPROVER*'
                                             msg = 'The message must name the approver' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a release is for one check code - another block on the same line still blocks
  METHOD other_check_still_blocks.
    TRY.
        DATA(lt_findings) = zcl_cd_ebs_release_policy=>apply(
                              it_findings = VALUE #( ( block_finding( iv_check_code = 'CHECK_STATUS' ) ) )
                              it_releases = approved_release( ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-block
                                            msg = 'A block with another check code must stay a block' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only line findings are releasable - a validation that could not run is never released
  METHOD run_finding_never_released.
    TRY.
        DATA(lt_findings) = zcl_cd_ebs_release_policy=>apply(
                              it_findings = VALUE #( ( block_finding( iv_object_type = 'RUN' ) ) )
                              it_releases = approved_release( ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-action exp = zif_cd_ops_types=>gc_action-block
                                            msg = 'A run-level block must never be released' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (four-eyes): the requester cannot approve their own release
  METHOD requester_cannot_approve.
    TRY.
        DATA(ls_decision) = zcl_cd_ebs_release_policy=>can_approve(
                              iv_status       = zif_cd_ebs_release_types=>gc_status-requested
                              iv_requested_by = gc_test-requester
                              iv_approver     = gc_test-requester ).
        cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zif_cd_ebs_release_types=>gc_msg-same_user
                                            msg = 'Self-approval must be refused with 063' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (four-eyes): a second user approves a requested release, never an approved one again
  METHOD second_user_may_approve.
    TRY.
        cl_abap_unit_assert=>assert_true(
          act = zcl_cd_ebs_release_policy=>can_approve( iv_status       = zif_cd_ebs_release_types=>gc_status-requested
                                                        iv_requested_by = gc_test-requester
                                                        iv_approver     = gc_test-approver )-allowed
          msg = 'A different user must be able to approve' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ebs_release_policy=>can_approve( iv_status       = zif_cd_ebs_release_types=>gc_status-approved
                                                        iv_requested_by = gc_test-requester
                                                        iv_approver     = gc_test-approver )-msgno
          exp = zif_cd_ebs_release_types=>gc_msg-not_requested
          msg = 'An approved release must not be approved again (160)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a request names the line, the check code and a reason
  METHOD request_needs_line_and_check.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ebs_release_policy=>check_request( iv_object_key = gc_test-key iv_check_code = space
                                                          iv_reason     = 'x' )-msgno
          exp = zif_cd_ebs_release_types=>gc_msg-key_missing
          msg = 'A request without check code must be refused (161)' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ebs_release_policy=>check_request( iv_object_key = gc_test-key iv_check_code = gc_test-code
                                                          iv_reason     = space )-msgno
          exp = zif_cd_ebs_release_types=>gc_msg-no_reason
          msg = 'A request without reason must be refused (062)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
