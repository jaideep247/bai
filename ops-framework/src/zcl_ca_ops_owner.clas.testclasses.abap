*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_owner.clas.testclasses.abap
*& Purpose:
*& Tests of the responsible owner on doubled ZCA_OPS_CONTROL / CTLCHK /
*& PROC (ABAP SQL test environment): the control covering the check code
*& wins over the one covering the check ID; an inactive control counts
*& for nothing; without a control the business process owner; without
*& both the source N. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: exception contract).
*&---------------------------------------------------------------------*
CLASS ltc_owner DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS check_code_control_wins FOR TESTING.
    METHODS process_owner_fallback  FOR TESTING.
    METHODS none_said               FOR TESTING.
ENDCLASS.


CLASS ltc_owner IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCA_OPS_CONTROL' ) ( 'ZCA_OPS_CTLCHK' )
                                                                           ( 'ZCA_OPS_PROC' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_controls TYPE STANDARD TABLE OF zca_ops_control WITH EMPTY KEY.
    DATA lt_covered TYPE STANDARD TABLE OF zca_ops_ctlchk WITH EMPTY KEY.
    DATA lt_processes TYPE STANDARD TABLE OF zca_ops_proc WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_controls = VALUE #( ( area = 'ZT' control_id = 'C_CODE' owner = 'ZT_CODE' team = 'ACKTEAM' active = abap_true )
                           ( area = 'ZT' control_id = 'C_CHECK' owner = 'ZT_CHECK' team = 'PAYOPS' active = abap_true )
                           ( area = 'ZT' control_id = 'C_OFF' owner = 'ZT_OFF' team = 'OFF' active = abap_false ) ).
    lt_covered = VALUE #( ( area = 'ZT' control_id = 'C_CODE' check_area = 'ZT' match_field = 'CHECK_CODE' match_value = 'PF_ACK_MISSING' )
                          ( area = 'ZT' control_id = 'C_CHECK' check_area = 'ZT' match_field = 'GROUP2' match_value = 'FICA_PAYFILE_ACK' )
                          ( area = 'ZT' control_id = 'C_OFF' check_area = 'ZT' match_field = 'GROUP2' match_value = 'OTHER' ) ).
    lt_processes = VALUE #( ( area = 'ZT' process_id = 'ZT_PAY' owner = 'ZT_PROC' active = abap_true ) ).
    go_env->insert_test_data( lt_controls ).
    go_env->insert_test_data( lt_covered ).
    go_env->insert_test_data( lt_processes ).
  ENDMETHOD.


  METHOD check_code_control_wins.
    DATA(lo_cut) = CAST zif_ca_ops_owner( NEW zcl_ca_ops_owner( ) ).
    DATA(ls_code) = lo_cut->resolve( iv_area = 'ZT' iv_check_id = 'FICA_PAYFILE_ACK' iv_check_code = 'PF_ACK_MISSING' ).
    cl_abap_unit_assert=>assert_equals( act = ls_code-team exp = 'ACKTEAM' msg = 'Check code first' ).
    DATA(ls_check) = lo_cut->resolve( iv_area = 'ZT' iv_check_id = 'FICA_PAYFILE_ACK' iv_check_code = 'PF_JOB_FAILED' ).
    cl_abap_unit_assert=>assert_equals( act = ls_check-user exp = 'ZT_CHECK' msg = 'Then the check ID' ).
    cl_abap_unit_assert=>assert_equals( act = ls_check-source exp = zif_ca_ops_exc_contract=>gc_resp_source-control msg = 'Control' ).
  ENDMETHOD.


  METHOD process_owner_fallback.
    DATA(ls_owner) = NEW zcl_ca_ops_owner( )->zif_ca_ops_owner~resolve( iv_area = 'ZT' iv_check_id = 'OTHER'
                                                                       iv_check_code = 'X' iv_process_id = 'ZT_PAY' ).
    cl_abap_unit_assert=>assert_equals( act = ls_owner-user exp = 'ZT_PROC' msg = 'Inactive control ignored, process owner' ).
    cl_abap_unit_assert=>assert_equals( act = ls_owner-source exp = zif_ca_ops_exc_contract=>gc_resp_source-process msg = 'P' ).
  ENDMETHOD.


  METHOD none_said.
    DATA(ls_owner) = NEW zcl_ca_ops_owner( )->zif_ca_ops_owner~resolve( iv_area = 'ZT' iv_check_id = 'OTHER' iv_check_code = 'X' ).
    cl_abap_unit_assert=>assert_equals( act = ls_owner-source exp = zif_ca_ops_exc_contract=>gc_resp_source-none msg = 'N' ).
    cl_abap_unit_assert=>assert_initial( act = ls_owner-user msg = 'Never guessed' ).
  ENDMETHOD.

ENDCLASS.
