*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_prq_spe.clas.testclasses.abap
*& Purpose:
*& Unit tests of the failed-request-without-SPE check: a failed request
*& without SPE row is an owned exception, an SPE row or a later success
*& clears it, findings are capped. The DAO is a test double; does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    CONSTANTS gc_spe_table TYPE zif_cd_hck_types=>ty_tabname VALUE 'ZCD_SPE_EXCP_LOG'.
    DATA mt_failed TYPE zif_cd_hck_value_types=>tt_value_row.
    DATA mt_success TYPE zif_cd_hck_value_types=>tt_value_row.
    DATA mt_spe TYPE zif_cd_hck_value_types=>tt_value_row.
    DATA mv_reads TYPE i.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~is_table_whitelisted.
    rv_allowed = abap_true.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_table_fields.
    rt_fields = VALUE #( ( fieldname = 'REQ_ID' type_kind = cl_abap_typedescr=>typekind_char )
                         ( fieldname = 'ZZ_STATUS' type_kind = cl_abap_typedescr=>typekind_char )
                         ( fieldname = 'ERDAT' type_kind = cl_abap_typedescr=>typekind_date ) ).
  ENDMETHOD.

  METHOD zif_cd_hck_dao~select_values.
    mv_reads = mv_reads + 1.
    IF is_query-tabname = gc_spe_table.
      rt_rows = mt_spe.
      RETURN.
    ENDIF.
    rt_rows = COND #( WHEN is_query-conditions[ 1 ]-operator = zif_cd_hck_types=>gc_operator-in_set
                      THEN mt_failed
                      ELSE mt_success ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_prq_spe DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check    TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_PRQ_SPE',
      gc_log      TYPE zif_cd_hck_types=>ty_param VALUE 'TABLE=ZCD_PAYM_REQ_LOG;KEY=REQ_ID;DATE=ERDAT',
      gc_options  TYPE zif_cd_hck_types=>ty_param VALUE 'FAIL=FAILED,ERROR',
      gc_cap_one  TYPE zif_cd_hck_types=>ty_param VALUE 'FAIL=FAILED,ERROR;MAX=1',
      gc_spe      TYPE zif_cd_hck_types=>ty_param VALUE 'KEY=REQ_ID;DATE=ERDAT',
      gc_req_lost TYPE string VALUE `REQ0001`,
      gc_req_spe  TYPE string VALUE `REQ0002`,
      gc_req_ok   TYPE string VALUE `REQ0003`,
      gc_req_more TYPE string VALUE `REQ0004`,
      gc_today    TYPE d VALUE '20261106'.

    TYPES:
      BEGIN OF ty_flags,
        lost      TYPE abap_bool,
        with_spe  TYPE abap_bool,
        succeeded TYPE abap_bool,
        more_lost TYPE abap_bool,
        cap_one   TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.

    METHODS setup.
    METHODS teardown.
    METHODS failed_without_spe_reported FOR TESTING.
    METHODS spe_or_success_clears FOR TESTING.
    METHODS findings_capped_metric_all FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS add_key
      IMPORTING
        iv_key  TYPE string
      CHANGING
        ct_rows TYPE zif_cd_hck_value_types=>tt_value_row.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_prq_spe IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    CLEAR ms_def.
    ms_def-check_id = gc_check.
    ms_def-param1   = gc_log.
    ms_def-param2   = gc_options.
    ms_def-param3   = gc_spe.
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD add_key.
    DATA ls_row TYPE zif_cd_hck_value_types=>ty_value_row.
    ls_row-v1 = iv_key.
    INSERT ls_row INTO TABLE ct_rows.
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-lost = abap_true.
      add_key( EXPORTING iv_key = gc_req_lost CHANGING ct_rows = mo_dao->mt_failed ).
    ENDIF.
    IF is_flags-with_spe = abap_true.
      add_key( EXPORTING iv_key = gc_req_spe CHANGING ct_rows = mo_dao->mt_failed ).
      add_key( EXPORTING iv_key = gc_req_spe CHANGING ct_rows = mo_dao->mt_spe ).
    ENDIF.
    IF is_flags-succeeded = abap_true.
      add_key( EXPORTING iv_key = gc_req_ok CHANGING ct_rows = mo_dao->mt_failed ).
      add_key( EXPORTING iv_key = gc_req_ok CHANGING ct_rows = mo_dao->mt_success ).
    ENDIF.
    IF is_flags-more_lost = abap_true.
      add_key( EXPORTING iv_key = gc_req_more CHANGING ct_rows = mo_dao->mt_failed ).
    ENDIF.
    IF is_flags-cap_one = abap_true.
      ms_def-param2 = gc_cap_one.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_prq_spe( )->zif_cd_hck_check~execute(
      is_def        = ms_def
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today ) ).
  ENDMETHOD.


  " Rule: every payment-request failure needs an SPE row, or the hourly status job never reports it
  METHOD failed_without_spe_reported.
    TRY.
        configure_scenario( VALUE #( lost = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One lost failure' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-object_key exp = gc_req_lost
                                            msg = 'Finding names the request' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zcl_cd_hck_c_prq_spe=>gc_code
                                            msg = 'Check code PRQ_FAILED_NO_SPE' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_reads exp = 3
                                            msg = 'Failed, success and SPE reads' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (ZZ_STATUS = SUCCESS wins): an SPE row or a later success clears the failure
  METHOD spe_or_success_clears.
    TRY.
        configure_scenario( VALUE #( with_spe = abap_true succeeded = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 0 msg = 'Metric counts 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: MAX caps the findings, the metric counts all
  METHOD findings_capped_metric_all.
    TRY.
        configure_scenario( VALUE #( lost = abap_true more_lost = abap_true cap_one = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'List capped' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 2 msg = 'Metric counts all' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
