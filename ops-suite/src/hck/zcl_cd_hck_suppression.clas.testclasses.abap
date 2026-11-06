*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_suppression.clas.testclasses.abap
*& Purpose:
*& Pure tests of the suppression matcher (design 6.3): which findings an
*& active suppression turns into information, expiry, pending approval,
*& four-eyes for long suppressions. No doubles.
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
CLASS ltc_suppression DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        check TYPE zif_cd_hck_types=>ty_check_id VALUE 'HCK_C04',
        key   TYPE zif_cd_ops_types=>ty_object_key VALUE 'HCK_C04/AGE_DAYS/US01',
        today TYPE d VALUE '20261106',
        user  TYPE syuname VALUE 'RTB_LEAD',
      END OF gc_test.

    METHODS finding
      IMPORTING
        iv_check          TYPE zif_cd_hck_types=>ty_check_id DEFAULT gc_test-check
        iv_key            TYPE zif_cd_ops_types=>ty_object_key DEFAULT gc_test-key
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.
    METHODS suppression
      IMPORTING
        iv_pattern            TYPE zif_cd_ops_types=>ty_object_key OPTIONAL
        iv_bukrs              TYPE char4 OPTIONAL
        iv_valid_to           TYPE d DEFAULT '20261110'
        iv_status             TYPE zif_cd_hck_suppress_types=>ty_status DEFAULT zif_cd_hck_suppress_types=>gc_status-active
      RETURNING
        VALUE(rt_suppressions) TYPE zif_cd_hck_suppress_types=>tt_suppression.
    METHODS act
      IMPORTING
        it_suppressions    TYPE zif_cd_hck_suppress_types=>tt_suppression
        is_finding         TYPE zif_cd_ops_types=>ty_finding
      RETURNING
        VALUE(rs_finding)  TYPE zif_cd_ops_types=>ty_finding.

    METHODS matching_finding_becomes_info FOR TESTING.
    METHODS pattern_limits_the_match      FOR TESTING.
    METHODS company_code_limits_match     FOR TESTING.
    METHODS other_check_is_untouched      FOR TESTING.
    METHODS expired_is_ignored            FOR TESTING.
    METHODS pending_is_not_applied        FOR TESTING.
    METHODS long_period_needs_approval    FOR TESTING.
    METHODS creator_cannot_approve        FOR TESTING.
ENDCLASS.


CLASS ltc_suppression IMPLEMENTATION.

  METHOD finding.
    rs_finding-object_key = iv_key.
    rs_finding-group2     = iv_check.
    rs_finding-check_code = 'THRESHOLD_RED'.
    rs_finding-severity   = zif_cd_ops_types=>gc_severity-error.
    rs_finding-action     = zif_cd_ops_types=>gc_action-exception.
    rs_finding-message    = 'AGE_DAYS US01: 15 (amber 1, red 10)'.
  ENDMETHOD.


  METHOD suppression.
    DATA ls_row TYPE zif_cd_hck_suppress_types=>ty_suppression.
    ls_row-suppress_uuid = '000000000000000000000000000000C1'.
    ls_row-check_id      = gc_test-check.
    ls_row-key_pattern   = iv_pattern.
    ls_row-bukrs         = iv_bukrs.
    ls_row-valid_from    = '20261101'.
    ls_row-valid_to      = iv_valid_to.
    ls_row-status        = iv_status.
    ls_row-created_by    = gc_test-user.
    INSERT ls_row INTO TABLE rt_suppressions.
  ENDMETHOD.


  METHOD act.
    DATA(lt_findings) = zcl_cd_hck_suppression=>apply( it_findings     = VALUE #( ( is_finding ) )
                                                       it_suppressions = it_suppressions
                                                       iv_today        = gc_test-today ).
    rs_finding = lt_findings[ 1 ].
  ENDMETHOD.


  " Rule: an active suppression turns the finding into information naming end date and user
  METHOD matching_finding_becomes_info.
    TRY.
        DATA(ls_result) = act( it_suppressions = suppression( ) is_finding = finding( ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-severity exp = zif_cd_ops_types=>gc_severity-info
                                            msg = 'A suppressed finding must become information' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*2026-11-10*RTB_LEAD*'
                                             msg = 'The message must name end date and user' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the key pattern limits the suppression to matching objects
  METHOD pattern_limits_the_match.
    TRY.
        DATA(ls_result) = act( it_suppressions = suppression( iv_pattern = 'HCK_C04/*/DE01' ) is_finding = finding( ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'A finding outside the pattern must stay an error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a company-code suppression applies only to that company code's findings
  METHOD company_code_limits_match.
    TRY.
        DATA(ls_other) = act( it_suppressions = suppression( iv_bukrs = 'DE01' ) is_finding = finding( ) ).
        DATA(ls_same) = act( it_suppressions = suppression( iv_bukrs = 'US01' ) is_finding = finding( ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_other-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Another company code must not be suppressed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_same-severity exp = zif_cd_ops_types=>gc_severity-info
                                            msg = 'The company code named must be suppressed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a suppression is for one check only
  METHOD other_check_is_untouched.
    TRY.
        DATA(ls_result) = act( it_suppressions = suppression( )
                               is_finding      = finding( iv_check = 'HCK_A01' iv_key = 'HCK_A01/X/US01' ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Another check must not be suppressed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: after its end date a suppression is ignored automatically
  METHOD expired_is_ignored.
    TRY.
        DATA(ls_result) = act( it_suppressions = suppression( iv_valid_to = '20261105' ) is_finding = finding( ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'An expired suppression must be ignored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a suppression waiting for its second user does not apply yet
  METHOD pending_is_not_applied.
    TRY.
        DATA(ls_result) = act( it_suppressions = suppression( iv_status = zif_cd_hck_suppress_types=>gc_status-requested )
                               is_finding      = finding( ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'A pending suppression must not apply' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: longer than the maximum (default 7 days) needs a second user
  METHOD long_period_needs_approval.
    TRY.
        cl_abap_unit_assert=>assert_false(
          act = zcl_cd_hck_suppression=>needs_approval( iv_from = '20261106' iv_to = '20261113' iv_max_days = 7 )
          msg = '7 days must not need approval' ).
        cl_abap_unit_assert=>assert_true(
          act = zcl_cd_hck_suppression=>needs_approval( iv_from = '20261106' iv_to = '20261114' iv_max_days = 7 )
          msg = '8 days must need approval' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (four-eyes): the creator cannot approve a long suppression
  METHOD creator_cannot_approve.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_suppression=>can_approve( iv_status     = zif_cd_hck_suppress_types=>gc_status-requested
                                                     iv_created_by = gc_test-user
                                                     iv_approver   = gc_test-user )-msgno
          exp = zif_cd_hck_suppress_types=>gc_msg-same_user
          msg = 'Self-approval must be refused with 063' ).
        cl_abap_unit_assert=>assert_true(
          act = zcl_cd_hck_suppression=>can_approve( iv_status     = zif_cd_hck_suppress_types=>gc_status-requested
                                                     iv_created_by = gc_test-user
                                                     iv_approver   = 'SECOND' )-allowed
          msg = 'A second user must be able to approve' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
