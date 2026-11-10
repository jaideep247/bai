*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_overdue_exc.clas.testclasses.abap
*& Purpose:
*& Unit tests of the overdue exceptions check: count and oldest age per
*& payment engine area, nothing overdue as one '*' zero metric. The DAO is a
*& test double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_overdue TYPE zif_cd_hck_types=>tt_overdue.
    DATA mv_today TYPE d.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_overdue_exceptions.
    mv_today   = iv_today.
    rt_overdue = mt_overdue.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_overdue_exc DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check  TYPE zif_cd_hck_types=>ty_check_id VALUE 'C_OVERDUE',
      gc_items  TYPE i VALUE 4,
      gc_age    TYPE i VALUE 6,
      gc_today  TYPE d VALUE '20261106',
      gc_oldest TYPE d VALUE '20261031'.

    TYPES:
      BEGIN OF ty_flags,
        ebs_overdue TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.

    METHODS setup.
    METHODS teardown.
    METHODS overdue_per_area FOR TESTING.
    METHODS nothing_overdue_is_zero FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_overdue_exc IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_overdue TYPE zif_cd_hck_types=>ty_overdue.
    IF is_flags-ebs_overdue = abap_true.
      ls_overdue-pe_area    = zif_cd_ops_types=>gc_pe_area-ebs.
      ls_overdue-item_count = gc_items.
      ls_overdue-oldest_due = gc_oldest.
      INSERT ls_overdue INTO TABLE mo_dao->mt_overdue.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_overdue_exc( )->zif_cd_hck_check~execute(
      is_def        = VALUE #( check_id = gc_check )
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today now_date = gc_today ) ).
  ENDMETHOD.


  " Rule: overdue items and the age of the oldest (a level metric) per payment engine area
  METHOD overdue_per_area.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        configure_scenario( VALUE #( ebs_overdue = abap_true ) ).
        INSERT VALUE #( metric = zcl_cd_hck_c_overdue_exc=>gc_metric-overdue
                        dim1   = zif_cd_ops_types=>gc_pe_area-ebs
                        value  = gc_items ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = zcl_cd_hck_c_overdue_exc=>gc_metric-oldest_days
                        dim1   = zif_cd_ops_types=>gc_pe_area-ebs
                        value  = gc_age
                        kind   = zif_cd_hck_types=>gc_metric_kind-level ) INTO TABLE lt_exp.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp
                                            msg = 'Overdue count and oldest age per area' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_today exp = gc_today
                                            msg = 'Due dates compared with today' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: nothing overdue is one OVERDUE '*' = 0
  METHOD nothing_overdue_is_zero.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        INSERT VALUE #( metric = zcl_cd_hck_c_overdue_exc=>gc_metric-overdue
                        dim1   = zif_cd_hck_types=>gc_default_key ) INTO TABLE lt_exp.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp msg = 'OVERDUE * = 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
