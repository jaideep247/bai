*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_trx_req_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the request side of the transactions dashboard on
*& cl_cds_test_environment doubles of ZCD_PAYM_REQ_LOG (fields as the
*& placeholders of ZI_CD_TrxReqLog - align them with SE11 together with the
*& view): the SUCCESS row rule (a request with any SUCCESS attempt is
*& processed, whatever COUNTER a later failed attempt has), errored and
*& pending requests, and that the member number never reaches the view.
*& Not executed offline; created in ADT after SE11 confirmation.
*& Modification log:
*& 2026-11-06 | Initial version (transactions dashboard, request side).
*&---------------------------------------------------------------------*
"! ZI_CD_TRXREQUEST: SUCCESS row rule, errored / pending, no member number
CLASS ltc_request DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_fin,
        retry_after  TYPE c LENGTH 20 VALUE 'FIN0000000001',
        errored      TYPE c LENGTH 20 VALUE 'FIN0000000002',
        pending      TYPE c LENGTH 20 VALUE 'FIN0000000003',
      END OF gc_fin.
    CONSTANTS gc_source TYPE c LENGTH 10 VALUE 'PCLM'.
    CONSTANTS:
      BEGIN OF gc_status,
        success  TYPE c LENGTH 20 VALUE 'SUCCESS',
        failed   TYPE c LENGTH 20 VALUE 'FAILED',
        received TYPE c LENGTH 20 VALUE 'RECEIVED',
      END OF gc_status.
    CONSTANTS:
      BEGIN OF gc_outcome,
        processed TYPE c LENGTH 10 VALUE 'PROCESSED',
        errored   TYPE c LENGTH 10 VALUE 'ERRORED',
        pending   TYPE c LENGTH 10 VALUE 'PENDING',
      END OF gc_outcome.
    CONSTANTS gc_member TYPE c LENGTH 20 VALUE '000123456789'.
    CONSTANTS gc_member_field TYPE string VALUE `ZZ_MEMBER_NO`.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    DATA mt_log TYPE STANDARD TABLE OF zcd_paym_req_log WITH EMPTY KEY.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS success_row_wins_over_counter FOR TESTING.
    METHODS errored_without_success_row FOR TESTING.
    METHODS pending_without_outcome FOR TESTING.
    METHODS member_number_not_exposed FOR TESTING.

    METHODS add_attempt
      IMPORTING
        iv_fin     TYPE csequence
        iv_counter TYPE i
        iv_status  TYPE csequence.
    METHODS outcome_of
      IMPORTING
        iv_fin            TYPE csequence
      RETURNING
        VALUE(rv_outcome) TYPE string.
ENDCLASS.


CLASS ltc_request IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity               = 'ZI_CD_TRXREQUEST'
                                              i_select_base_dependencies = abap_true ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    CLEAR mt_log.
    " SUCCESS at counter 1, a failed retry written later at counter 2: still processed
    add_attempt( iv_fin = gc_fin-retry_after iv_counter = 1 iv_status = gc_status-success ).
    add_attempt( iv_fin = gc_fin-retry_after iv_counter = 2 iv_status = gc_status-failed ).
    add_attempt( iv_fin = gc_fin-errored iv_counter = 1 iv_status = gc_status-failed ).
    add_attempt( iv_fin = gc_fin-pending iv_counter = 1 iv_status = gc_status-received ).
    go_env->insert_test_data( i_data = mt_log ).
  ENDMETHOD.


  METHOD add_attempt.
    DATA ls_row TYPE zcd_paym_req_log.
    " VERIFY-SE11: same placeholder fields as ZI_CD_TrxReqLog (FIN, request date)
    ls_row-zz_fin_trans_num = iv_fin.
    ls_row-source           = gc_source.
    ls_row-counter          = iv_counter.
    ls_row-zz_status        = iv_status.
    ls_row-zz_created_on    = cl_abap_context_info=>get_system_date( ).
    ls_row-zz_member_no     = gc_member.
    INSERT ls_row INTO TABLE mt_log.
  ENDMETHOD.


  METHOD outcome_of.
    SELECT SINGLE requestoutcome FROM zi_cd_trxrequest WHERE finid = @iv_fin INTO @DATA(lv_outcome).
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |Request { iv_fin } must be listed| ).
    rv_outcome = condense( lv_outcome ).
  ENDMETHOD.


  METHOD success_row_wins_over_counter.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = outcome_of( gc_fin-retry_after ) exp = gc_outcome-processed
                                            msg = 'A SUCCESS row counts, never the highest COUNTER' ).
        SELECT SINGLE attemptcount, successattempts FROM zi_cd_trxrequest
          WHERE finid = @gc_fin-retry_after INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The request must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-attemptcount exp = 2 msg = 'Both attempts are counted' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-successattempts exp = 1 msg = 'One SUCCESS attempt' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD errored_without_success_row.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = outcome_of( gc_fin-errored ) exp = gc_outcome-errored
                                            msg = 'No SUCCESS row and a failure value: ERRORED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD pending_without_outcome.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = outcome_of( gc_fin-pending ) exp = gc_outcome-pending
                                            msg = 'Neither SUCCESS nor failure: PENDING' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD member_number_not_exposed.
    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( 'ZR_CD_TRXREQFLOW' ) ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( lo_struct->components[ name = gc_member_field ] ) )
          msg = 'The member number is never an element of the request funnel' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
