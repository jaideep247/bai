*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_volume.clas.testclasses.abap
*& Purpose:
*& Unit tests of the volume check: expected group set (a silent company
*& measures zero) and a failed query that never looks like zero volume;
*& the DAO is a test double, so live SQL is not proven here.
*& Modification log:
*& 2026-11-06 | Initial version (audit A103).
*& 2026-11-07 | Parameters from the shared fake ZCL_CD_OPS_PARAMS_MEM (row caps at their delivered defaults).
*& 2026-11-07 | Parameters over ZCA_PARAM (ZCL_CD_OPS_PARAM_SEED) instead of ZCL_CD_OPS_PARAMS_MEM.
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_defs TYPE zif_cd_hck_types=>tt_agg_def.
    DATA mt_groups TYPE zif_cd_hck_types=>tt_agg_group.
    DATA mt_rows TYPE zif_cd_hck_types=>tt_agg_row.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_agg_defs.
    rt_defs = mt_defs.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_agg_groups.
    rt_groups = mt_groups.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~is_table_whitelisted.
    rv_allowed = abap_true.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_table_fields.
    rt_fields = VALUE #( ( fieldname = 'BUKRS' type_kind = 'C' )
                         ( fieldname = 'BUDAT' type_kind = 'D' ) ).
  ENDMETHOD.

  METHOD zif_cd_hck_dao~aggregate.
    IF mv_fail = abap_true.
      " SQL failure as raised by the DAO (message 308)
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e308(zcd_ops) WITH is_query-tabname is_query-agg_id.
    ENDIF.
    rt_rows = mt_rows.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_volume DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check  TYPE zif_cd_hck_types=>ty_check_id VALUE 'B_VOLUME',
      gc_agg    TYPE zif_cd_hck_types=>ty_agg_id VALUE 'PAY_CNT',
      gc_active TYPE zif_cd_hck_types=>ty_group_value VALUE 'US01',
      gc_silent TYPE zif_cd_hck_types=>ty_group_value VALUE 'US02',
      gc_today  TYPE d VALUE '20261106'.

    DATA mo_dao TYPE REF TO ltd_dao.

    METHODS setup.
    METHODS teardown.
    METHODS silent_company_measures_zero FOR TESTING.
    METHODS failed_query_is_not_zero FOR TESTING.

    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_volume IMPLEMENTATION.

  METHOD setup.
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
    mo_dao = NEW #( ).
    INSERT VALUE #( check_id    = gc_check
                    agg_id      = gc_agg
                    tabname     = 'DFKKOP'
                    agg_func    = zif_cd_hck_types=>gc_agg_func-count
                    date_field  = 'BUDAT'
                    group_field = 'BUKRS' ) INTO TABLE mo_dao->mt_defs.
    INSERT VALUE #( check_id = gc_check agg_id = gc_agg group_value = gc_active ) INTO TABLE mo_dao->mt_groups.
    INSERT VALUE #( check_id = gc_check agg_id = gc_agg group_value = gc_silent ) INTO TABLE mo_dao->mt_groups.
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_volume( )->zif_cd_hck_check~execute(
      is_def        = VALUE #( check_id = gc_check )
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today ) ).
  ENDMETHOD.


  " Rule (A103): company US02 is expected but booked nothing yesterday while US01 is
  " active - US02 measures 0 so its lower-is-worse threshold can fire
  METHOD silent_company_measures_zero.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        INSERT VALUE #( group_value = gc_active row_count = 40 ) INTO TABLE mo_dao->mt_rows.
        INSERT VALUE #( metric = gc_agg dim1 = gc_active dim2 = '20261105' value = 40 ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = gc_agg dim1 = gc_silent dim2 = '20261105' value = 0 ) INTO TABLE lt_exp.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp
                                            msg = 'Silent company must be measured as 0' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Zero volume is not a failure' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A103): a failed query is an error finding and produces no metric - never a zero
  " that would read as "no volume" and feed the baseline
  METHOD failed_query_is_not_zero.
    TRY.
        mo_dao->mv_fail = abap_true.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-metrics msg = 'A failed query must not measure 0' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One failure finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-agg_invalid
                                            msg = 'Failure is AGG_INVALID' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity
                                            exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Failure is an error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
