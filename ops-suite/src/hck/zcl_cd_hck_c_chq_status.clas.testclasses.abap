*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_chq_status.clas.testclasses.abap
*& Purpose:
*& Unit tests of the cheque status regression check: a terminal status that
*& moves on is an error finding, the allowed step 10 > 9 is not, the finding
*& list is capped while the metric counts all, a non-whitelisted table is
*& refused. The DAO is a test double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_rows TYPE zif_cd_hck_value_types=>tt_value_row.
    DATA mv_whitelisted TYPE abap_bool VALUE abap_true.
    DATA ms_query TYPE zif_cd_hck_value_types=>ty_value_query.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~is_table_whitelisted.
    rv_allowed = mv_whitelisted.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_table_fields.
    rt_fields = VALUE #( ( fieldname = 'CHECT' type_kind = cl_abap_typedescr=>typekind_char )
                         ( fieldname = 'SEQNO' type_kind = cl_abap_typedescr=>typekind_num )
                         ( fieldname = 'ZZ_STATUS' type_kind = cl_abap_typedescr=>typekind_char )
                         ( fieldname = 'ERDAT' type_kind = cl_abap_typedescr=>typekind_date ) ).
  ENDMETHOD.

  METHOD zif_cd_hck_dao~select_values.
    ms_query = is_query.
    rt_rows = mt_rows.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chq_status DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check    TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_CHQ_STATUS',
      gc_names    TYPE zif_cd_hck_types=>ty_param VALUE 'TABLE=ZCD_CHECK_HIST;KEY=CHECT;SEQ=SEQNO;STATUS=ZZ_STATUS;DATE=ERDAT',
      gc_cap_one  TYPE zif_cd_hck_types=>ty_param VALUE 'MAX=1',
      gc_returned TYPE string VALUE `9`,
      gc_mailed   TYPE string VALUE `10`,
      gc_cheque_a TYPE string VALUE `100001`,
      gc_cheque_b TYPE string VALUE `100002`,
      gc_cheque_c TYPE string VALUE `100003`,
      gc_seq_1    TYPE string VALUE `001`,
      gc_seq_2    TYPE string VALUE `002`,
      gc_today    TYPE d VALUE '20261106',
      gc_from     TYPE d VALUE '20261030'.

    TYPES:
      BEGIN OF ty_flags,
        terminal_moved TYPE abap_bool,
        mailed_return  TYPE abap_bool,
        second_moved   TYPE abap_bool,
        cap_one        TYPE abap_bool,
        not_listed     TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.

    METHODS setup.
    METHODS teardown.
    METHODS terminal_move_is_error FOR TESTING.
    METHODS mailed_to_returned_allowed FOR TESTING.
    METHODS findings_capped_metric_all FOR TESTING.
    METHODS unlisted_table_raises FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS add_event
      IMPORTING
        iv_key    TYPE string
        iv_seq    TYPE string
        iv_status TYPE string.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_chq_status IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    CLEAR ms_def.
    ms_def-check_id = gc_check.
    ms_def-param1   = gc_names.
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD add_event.
    DATA ls_row TYPE zif_cd_hck_value_types=>ty_value_row.
    ls_row-v1 = iv_key.
    ls_row-v2 = iv_seq.
    ls_row-v3 = iv_status.
    INSERT ls_row INTO TABLE mo_dao->mt_rows.
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-terminal_moved = abap_true.
      add_event( iv_key = gc_cheque_a iv_seq = gc_seq_1 iv_status = gc_returned ).
      add_event( iv_key = gc_cheque_a iv_seq = gc_seq_2 iv_status = gc_mailed ).
    ENDIF.
    IF is_flags-mailed_return = abap_true.
      add_event( iv_key = gc_cheque_b iv_seq = gc_seq_1 iv_status = gc_mailed ).
      add_event( iv_key = gc_cheque_b iv_seq = gc_seq_2 iv_status = gc_returned ).
    ENDIF.
    IF is_flags-second_moved = abap_true.
      add_event( iv_key = gc_cheque_c iv_seq = gc_seq_1 iv_status = gc_returned ).
      add_event( iv_key = gc_cheque_c iv_seq = gc_seq_2 iv_status = gc_mailed ).
    ENDIF.
    IF is_flags-cap_one = abap_true.
      ms_def-param2 = gc_cap_one.
    ENDIF.
    IF is_flags-not_listed = abap_true.
      mo_dao->mv_whitelisted = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_chq_status( )->zif_cd_hck_check~execute(
      is_def        = ms_def
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today ) ).
  ENDMETHOD.


  " Rule: returned (9, terminal) must never move on - one error finding, owned exception
  METHOD terminal_move_is_error.
    TRY.
        configure_scenario( VALUE #( terminal_moved = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One regression' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-object_key exp = gc_cheque_a
                                            msg = 'Finding names the cheque' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zcl_cd_hck_c_chq_status=>gc_code
                                            msg = 'Check code CHEQUE_STATUS_REGRESSION' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-action
                                            exp = zif_cd_ops_types=>gc_action-exception
                                            msg = 'Regression is an owned exception' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 1 msg = 'Metric counts 1' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_query-date_from exp = gc_from
                                            msg = 'Default window is 7 days' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: mailed 10 -> returned 9 is the allowed backward step (default ALLOWED=10>9)
  METHOD mailed_to_returned_allowed.
    TRY.
        configure_scenario( VALUE #( mailed_return = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Allowed step is no finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 0 msg = 'Metric counts 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: MAX caps the listed findings, the metric still counts every regression
  METHOD findings_capped_metric_all.
    TRY.
        configure_scenario( VALUE #( terminal_moved = abap_true second_moved = abap_true cap_one = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'List capped at MAX' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 2 msg = 'Metric counts all' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a table not on the whitelist is never read
  METHOD unlisted_table_raises.
    configure_scenario( VALUE #( not_listed = abap_true ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Non-whitelisted table must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Whitelist refusal raised' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->ms_query msg = 'No SQL issued' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
