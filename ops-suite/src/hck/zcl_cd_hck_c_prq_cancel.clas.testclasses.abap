*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_prq_cancel.clas.testclasses.abap
*& Purpose:
*& Unit tests of the paid-but-cancelled payment request check: a cancelled
*& request with a cleared item is an owned exception, an unpaid one is not,
*& the source filter is only applied when configured, findings are capped.
*& The DAO is a test double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    CONSTANTS gc_paid_table TYPE zif_cd_hck_types=>ty_tabname VALUE 'DFKKOP'.
    DATA mt_cancelled TYPE zif_cd_hck_value_types=>tt_value_row.
    DATA mt_paid TYPE zif_cd_hck_value_types=>tt_value_row.
    DATA mt_log_conditions TYPE zif_cd_hck_value_types=>tt_condition.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~is_table_whitelisted.
    rv_allowed = abap_true.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_table_fields.
    rt_fields = VALUE #( ( fieldname = 'ZZ_FIN_TRANS_NUM' type_kind = cl_abap_typedescr=>typekind_char )
                         ( fieldname = 'ZZ_STATUS' type_kind = cl_abap_typedescr=>typekind_char )
                         ( fieldname = 'SOURCE' type_kind = cl_abap_typedescr=>typekind_char )
                         ( fieldname = 'ERDAT' type_kind = cl_abap_typedescr=>typekind_date )
                         ( fieldname = 'AUGBL' type_kind = cl_abap_typedescr=>typekind_char )
                         ( fieldname = 'AUGDT' type_kind = cl_abap_typedescr=>typekind_date ) ).
  ENDMETHOD.

  METHOD zif_cd_hck_dao~select_values.
    IF is_query-tabname = gc_paid_table.
      rt_rows = mt_paid.
      RETURN.
    ENDIF.
    mt_log_conditions = is_query-conditions.
    rt_rows = mt_cancelled.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_prq_cancel DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check      TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_PRQ_CANCEL',
      gc_log        TYPE zif_cd_hck_types=>ty_param VALUE 'TABLE=ZCD_PAYM_REQ_LOG;KEY=ZZ_FIN_TRANS_NUM;DATE=ERDAT',
      gc_log_source TYPE zif_cd_hck_types=>ty_param
                    VALUE 'TABLE=ZCD_PAYM_REQ_LOG;KEY=ZZ_FIN_TRANS_NUM;DATE=ERDAT;SOURCE=SOURCE',
      gc_cap_one    TYPE zif_cd_hck_types=>ty_param VALUE 'MAX=1',
      gc_fin_paid   TYPE string VALUE `FIN0001`,
      gc_fin_paid_2 TYPE string VALUE `FIN0003`,
      gc_fin_open   TYPE string VALUE `FIN0002`,
      gc_today      TYPE d VALUE '20261106'.

    TYPES:
      BEGIN OF ty_flags,
        paid_cancelled TYPE abap_bool,
        open_cancelled TYPE abap_bool,
        second_paid    TYPE abap_bool,
        with_source    TYPE abap_bool,
        cap_one        TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.

    METHODS setup.
    METHODS teardown.
    METHODS paid_cancelled_is_exception FOR TESTING.
    METHODS unpaid_cancelled_is_ok FOR TESTING.
    METHODS source_filter_when_set FOR TESTING.
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


CLASS ltc_prq_cancel IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    CLEAR ms_def.
    ms_def-check_id = gc_check.
    ms_def-param1   = gc_log.
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
    IF is_flags-paid_cancelled = abap_true.
      add_key( EXPORTING iv_key = gc_fin_paid CHANGING ct_rows = mo_dao->mt_cancelled ).
      add_key( EXPORTING iv_key = gc_fin_paid CHANGING ct_rows = mo_dao->mt_paid ).
    ENDIF.
    IF is_flags-open_cancelled = abap_true.
      add_key( EXPORTING iv_key = gc_fin_open CHANGING ct_rows = mo_dao->mt_cancelled ).
    ENDIF.
    IF is_flags-second_paid = abap_true.
      add_key( EXPORTING iv_key = gc_fin_paid_2 CHANGING ct_rows = mo_dao->mt_cancelled ).
      add_key( EXPORTING iv_key = gc_fin_paid_2 CHANGING ct_rows = mo_dao->mt_paid ).
    ENDIF.
    IF is_flags-with_source = abap_true.
      ms_def-param1 = gc_log_source.
    ENDIF.
    IF is_flags-cap_one = abap_true.
      ms_def-param2 = gc_cap_one.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_prq_cancel( )->zif_cd_hck_check~execute(
      is_def        = ms_def
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today ) ).
  ENDMETHOD.


  " Rule (PCLM): CANCELLED means money will not leave - a paid request left CANCELLED is an owned exception
  METHOD paid_cancelled_is_exception.
    TRY.
        configure_scenario( VALUE #( paid_cancelled = abap_true open_cancelled = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'Only the paid request' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-object_key exp = gc_fin_paid
                                            msg = 'Finding names the FIN number' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zcl_cd_hck_c_prq_cancel=>gc_code
                                            msg = 'Check code PRQ_PAID_CANCELLED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-action
                                            exp = zif_cd_ops_types=>gc_action-exception
                                            msg = 'Owned exception' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 1 msg = 'Metric counts 1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a cancelled request without a cleared item is correct - no finding
  METHOD unpaid_cancelled_is_ok.
    TRY.
        configure_scenario( VALUE #( open_cancelled = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No finding' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_log_conditions ) exp = 1
                                            msg = 'Status condition only without SOURCE' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: SOURCE in PARAM1 adds the source set (default PCLM) as an IN condition
  METHOD source_filter_when_set.
    TRY.
        configure_scenario( VALUE #( with_source = abap_true ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_log_conditions ) exp = 2
                                            msg = 'Status and source conditions' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_log_conditions[ 2 ]-operator
                                            exp = zif_cd_hck_types=>gc_operator-in_set
                                            msg = 'Source is an IN set' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: MAX caps the findings, the metric counts all
  METHOD findings_capped_metric_all.
    TRY.
        configure_scenario( VALUE #( paid_cancelled = abap_true second_paid = abap_true cap_one = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'List capped' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 2 msg = 'Metric counts all' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
