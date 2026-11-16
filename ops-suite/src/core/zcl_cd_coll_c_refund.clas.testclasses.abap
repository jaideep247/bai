*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_coll_c_refund.clas.testclasses.abap
*& Purpose:
*& Tests of check COLL_R3_REFUND through ZIF_CA_OPS_CHECK~RUN with doubles of
*& the trace repository (request status source, refund log) and the
*& in-memory parameters: a rejected request with a successful refund is not
*& reported, one with only a failed refund is PREMIUM_REFUND_FAILED (E) at
*& once, one without refund past the red hours PREMIUM_REFUND_MISSING (E);
*& an unset reject value raises (the runner records CHECK_FAILED). Does not
*& prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (scaffold tools/abaptools/new_process.py).
*& 2026-11-16 | Rule R3 tests (build R).
*&---------------------------------------------------------------------*
CLASS ltd_trace DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_rows TYPE zif_cd_ops_trace_types=>tt_cfg_row.
    DATA mt_refunds TYPE zif_cd_ops_trace_types=>tt_cfg_row.
ENDCLASS.

CLASS ltd_trace IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~read_configured_after.
    rt_rows = mt_rows.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~read_configured_set.
    LOOP AT mt_refunds ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF line_exists( it_keys[ table_line = <ls_row>-key1 ] ).
        INSERT <ls_row> INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_check DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        spec      TYPE string VALUE `TABLE=ZT_REQ;KEY=REQ_ID;KEY2=BUKRS;STATUS=STAT;DATE=CHDAT;TIME=CHTIM;AMOUNT=AMT`,
        refunds   TYPE string VALUE `TABLE=ZT_REFUND;KEY=REQ_ID;STATUS=RSTAT;DATE=RDAT;TIME=RTIM`,
        reject    TYPE string VALUE `SRCREJECT`,
        ok        TYPE string VALUE `SUCCEEDED`,
        failed    TYPE string VALUE `FAILED`,
        unset     TYPE string VALUE `‹reject value›`,
        amber     TYPE string VALUE `2`,
        red       TYPE string VALUE `8`,
        today     TYPE d VALUE '20261116',
        now       TYPE timestampl VALUE '20261116120000',
        old_day   TYPE d VALUE '20261115',
        morning   TYPE t VALUE '060000',
        req_paid  TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'REQ1001',
        req_fail  TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'REQ1002',
        req_none  TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'REQ1003',
        bukrs     TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'ZT01',
        amount    TYPE c LENGTH 40 VALUE '19.99',
        st_reject TYPE c LENGTH 40 VALUE 'SRCREJECT',
        st_ok     TYPE c LENGTH 40 VALUE 'SUCCEEDED',
        st_failed TYPE c LENGTH 40 VALUE 'FAILED',
      END OF gc.

    DATA mo_trace TYPE REF TO ltd_trace.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS reject_needs_refund FOR TESTING.
    METHODS unset_reject_raises FOR TESTING.

    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_check IMPLEMENTATION.

  METHOD setup.
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    mo_params = NEW zcl_cd_ops_param_seed( ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-src_request iv_value = gc-spec ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-src_refund iv_value = gc-refunds ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-reject_value iv_value = gc-reject ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-refund_ok iv_value = gc-ok ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-refund_failed iv_value = gc-failed ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-r3_amber iv_value = gc-amber ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-r3_red iv_value = gc-red ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    LOOP AT VALUE string_table( ( CONV #( gc-req_paid ) ) ( CONV #( gc-req_fail ) ) ( CONV #( gc-req_none ) ) )
         INTO DATA(lv_key).
      INSERT VALUE #( key1 = lv_key key2 = gc-bukrs status = gc-st_reject ev_date = gc-old_day ev_time = gc-morning
                      amount = gc-amount ) INTO TABLE mo_trace->mt_rows.
    ENDLOOP.
    mo_trace->mt_refunds = VALUE #( ( key1 = gc-req_paid status = gc-st_failed )
                                    ( key1 = gc-req_paid status = gc-st_ok )
                                    ( key1 = gc-req_fail status = gc-st_failed ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_coll_c_refund( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = 'CD_COLL' check_id = 'COLL_R3_REFUND' bukrs_aware = abap_true )
                  is_context = VALUE #( today = gc-today now = gc-now ) ).
  ENDMETHOD.


  " Rule: a successful refund closes the reject; a failed one is an error at once; none past red an error
  METHOD reject_needs_refund.
    TRY.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ls_result-findings[ object_key = gc-req_paid ] ) )
          msg = 'Refunded request not reported (a success wins over an earlier failure)' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ object_key = gc-req_fail ]-check_code
                                            exp = zif_cd_coll_types=>gc_code-refund_failed msg = 'Refund failed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ object_key = gc-req_none ]-check_code
                                            exp = zif_cd_coll_types=>gc_code-refund_missing msg = 'Refund missing' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ object_key = gc-req_none ]-severity
                                            exp = zif_ca_ops_types=>gc_severity-error msg = 'Past red' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ object_key = gc-req_none ]-company_code
                                            exp = gc-bukrs msg = 'Company code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-item_count exp = 3 msg = 'Three rejected requests' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the reject value still a placeholder - no verdict
  METHOD unset_reject_raises.
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-reject_value iv_value = gc-unset ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Unset reject value must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Not evaluated' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
