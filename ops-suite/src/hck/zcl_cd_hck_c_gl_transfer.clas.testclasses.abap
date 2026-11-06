*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_gl_transfer.clas.testclasses.abap
*& Purpose:
*& Unit tests of the payment engine to GL transfer check: one owned exception
*& per gap and company code, window from lag and days, total from the count
*& read once the list is capped, configured reference type. The DAO is a test
*& double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_gaps TYPE zif_cd_hck_types=>tt_fikey_gap.
    DATA mv_total TYPE i.
    DATA mv_count_calls TYPE i.
    DATA mv_from TYPE d.
    DATA mv_to TYPE d.
    DATA mv_awtyp TYPE awtyp.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_fikeys_without_gl.
    mv_from  = iv_from.
    mv_to    = iv_to.
    mv_awtyp = iv_awtyp.
    LOOP AT mt_gaps INTO DATA(ls_gap) TO iv_max_rows.
      INSERT ls_gap INTO TABLE rt_gaps.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~count_fikeys_without_gl.
    mv_count_calls = mv_count_calls + 1.
    rv_count = mv_total.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_gl_transfer DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check     TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_GL_TRANSFER',
      gc_fikey_1   TYPE zif_cd_hck_types=>ty_fikey VALUE 'FK2026110501',
      gc_fikey_2   TYPE zif_cd_hck_types=>ty_fikey VALUE 'FK2026110502',
      gc_bukrs     TYPE bukrs VALUE 'US01',
      gc_cap_one   TYPE zif_cd_hck_types=>ty_param VALUE '1',
      gc_awtyp     TYPE zif_cd_hck_types=>ty_param VALUE ' bkpff ',
      gc_awtyp_exp TYPE awtyp VALUE 'BKPFF',
      gc_total     TYPE i VALUE 40,
      gc_today     TYPE d VALUE '20261106',
      gc_win_from  TYPE d VALUE '20261030',
      gc_win_to    TYPE d VALUE '20261105'.

    TYPES:
      BEGIN OF ty_flags,
        gaps      TYPE i,
        cap_one   TYPE abap_bool,
        own_awtyp TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.

    METHODS setup.
    METHODS teardown.
    METHODS gap_is_owned_exception FOR TESTING.
    METHODS window_from_lag_and_days FOR TESTING.
    METHODS capped_list_reads_total FOR TESTING.
    METHODS configured_awtyp_is_used FOR TESTING.
    METHODS no_gap_measures_zero FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_gl_transfer IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    CLEAR ms_def.
    ms_def-check_id = gc_check.
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_gap TYPE zif_cd_hck_types=>ty_fikey_gap.
    ls_gap-bukrs = gc_bukrs.
    IF is_flags-gaps >= 1.
      ls_gap-fikey = gc_fikey_1.
      INSERT ls_gap INTO TABLE mo_dao->mt_gaps.
    ENDIF.
    IF is_flags-gaps >= 2.
      ls_gap-fikey = gc_fikey_2.
      INSERT ls_gap INTO TABLE mo_dao->mt_gaps.
    ENDIF.
    IF is_flags-cap_one = abap_true.
      ms_def-param3   = gc_cap_one.
      mo_dao->mv_total = gc_total.
    ENDIF.
    IF is_flags-own_awtyp = abap_true.
      ms_def-param4 = gc_awtyp.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_gl_transfer( )->zif_cd_hck_check~execute(
      is_def        = ms_def
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today ) ).
  ENDMETHOD.


  " Rule (A43): every key and company code without GL document is an owned exception
  METHOD gap_is_owned_exception.
    TRY.
        configure_scenario( VALUE #( gaps = 1 ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One gap, one finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-object_key
                                            exp = |{ gc_fikey_1 }/{ gc_bukrs }|
                                            msg = 'Finding key is reconciliation key / company code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-gl_gap
                                            msg = 'Check code GL_TRANSFER_GAP' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-action
                                            exp = zif_cd_ops_types=>gc_action-exception
                                            msg = 'A gap is an owned exception' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 1 msg = 'Metric counts 1' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_count_calls exp = 0
                                            msg = 'No count read below the cap' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: default lag 1 day and window 7 days end the window yesterday
  METHOD window_from_lag_and_days.
    TRY.
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_from exp = gc_win_from msg = 'Window start' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_to exp = gc_win_to msg = 'Window end' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_awtyp
                                            exp = zcl_cd_hck_c_gl_transfer=>gc_default_awtyp
                                            msg = 'Default reference type' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A43): a list at the cap reads the total; the metric is the total, the summary says so
  METHOD capped_list_reads_total.
    TRY.
        configure_scenario( VALUE #( gaps = 2 cap_one = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'List capped' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = gc_total
                                            msg = 'Metric is the total count' ).
        cl_abap_unit_assert=>assert_not_initial( act = ls_result-summary msg = 'Summary names the cap' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PARAM4 overrides the reference type (condensed, upper case)
  METHOD configured_awtyp_is_used.
    TRY.
        configure_scenario( VALUE #( own_awtyp = abap_true ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_awtyp exp = gc_awtyp_exp
                                            msg = 'Configured reference type is used' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no gap measures GL_MISSING_KEYS = 0 and lists nothing
  METHOD no_gap_measures_zero.
    TRY.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-metric
                                            exp = zcl_cd_hck_c_gl_transfer=>gc_metric
                                            msg = 'GL_MISSING_KEYS measured' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 0 msg = 'Zero gaps' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-summary msg = 'No cap summary' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
