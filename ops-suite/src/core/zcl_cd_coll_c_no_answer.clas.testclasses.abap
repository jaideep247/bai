*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_coll_c_no_answer.clas.testclasses.abap
*& Purpose:
*& Tests of check COLL_R2_SCHEDULED through ZIF_CA_OPS_CHECK~RUN with doubles
*& of the trace repository (configured request status source) and the
*& in-memory parameters: a request still SCHEDULED past the red hours is an
*& error with company code and amount, past amber a warning, below amber
*& nothing; a request answered later (SRCPOSTED) is not reported; one
*& exposure finding per currency; an unset source or limits raise (the
*& runner records CHECK_FAILED). Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (scaffold tools/abaptools/new_process.py).
*& 2026-11-16 | Rule R2 tests (build R).
*&---------------------------------------------------------------------*
CLASS ltd_trace DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_rows TYPE zif_cd_ops_trace_types=>tt_cfg_row.
ENDCLASS.

CLASS ltd_trace IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~read_configured_after.
    rt_rows = mt_rows.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_check DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        spec      TYPE string VALUE `TABLE=ZT_REQ;KEY=REQ_ID;KEY2=BUKRS;STATUS=STAT;DATE=CHDAT;TIME=CHTIM;AMOUNT=AMT`,
        unset     TYPE string VALUE `TABLE=‹status table›;KEY=‹request key›;STATUS=‹status›;DATE=‹date›`,
        amber     TYPE string VALUE `4`,
        red       TYPE string VALUE `24`,
        today     TYPE d VALUE '20261116',
        now       TYPE timestampl VALUE '20261116120000',
        old_day   TYPE d VALUE '20261114',
        today_6   TYPE t VALUE '060000',
        today_11  TYPE t VALUE '110000',
        req_red   TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'REQ0001',
        req_amber TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'REQ0002',
        req_young TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'REQ0003',
        req_done  TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'REQ0004',
        bukrs     TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'ZT01',
        amount    TYPE c LENGTH 40 VALUE '42.50',
        scheduled TYPE c LENGTH 40 VALUE 'SCHEDULED',
        srcposted TYPE c LENGTH 40 VALUE 'SRCPOSTED',
        usd       TYPE string VALUE `USD`,
      END OF gc.

    DATA mo_trace TYPE REF TO ltd_trace.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS scheduled_past_limits FOR TESTING.
    METHODS unset_source_raises FOR TESTING.

    METHODS row
      IMPORTING
        iv_key    TYPE zif_cd_ops_trace_types=>ty_key_value
        iv_status TYPE clike
        iv_date   TYPE d
        iv_time   TYPE t.
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
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-r2_amber iv_value = gc-amber ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-r2_red iv_value = gc-red ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-currency iv_value = gc-usd ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    row( iv_key = gc-req_red iv_status = gc-scheduled iv_date = gc-old_day iv_time = gc-today_6 ).
    row( iv_key = gc-req_amber iv_status = gc-scheduled iv_date = gc-today iv_time = gc-today_6 ).
    row( iv_key = gc-req_young iv_status = gc-scheduled iv_date = gc-today iv_time = gc-today_11 ).
    row( iv_key = gc-req_done iv_status = gc-scheduled iv_date = gc-old_day iv_time = gc-today_6 ).
    row( iv_key = gc-req_done iv_status = gc-srcposted iv_date = gc-today iv_time = gc-today_6 ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD row.
    INSERT VALUE #( key1 = iv_key key2 = gc-bukrs status = iv_status ev_date = iv_date ev_time = iv_time
                    amount = gc-amount ) INTO TABLE mo_trace->mt_rows.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_coll_c_no_answer( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = 'CD_COLL' check_id = 'COLL_R2_SCHEDULED' bukrs_aware = abap_true )
                  is_context = VALUE #( today = gc-today now = gc-now ) ).
  ENDMETHOD.


  " Rule: SCHEDULED past red = error, past amber = warning, younger or answered = nothing
  METHOD scheduled_past_limits.
    TRY.
        DATA(ls_result) = act( ).
        DATA(lt_found) = VALUE zif_ca_ops_types=>tt_finding(
                           FOR ls_finding IN ls_result-findings
                           WHERE ( check_code = zif_cd_coll_types=>gc_code-no_answer ) ( ls_finding ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_found ) exp = 2 msg = 'Two requests without answer' ).
        cl_abap_unit_assert=>assert_equals( act = lt_found[ object_key = gc-req_red ]-severity
                                            exp = zif_ca_ops_types=>gc_severity-error msg = 'Past red: error' ).
        cl_abap_unit_assert=>assert_equals( act = lt_found[ object_key = gc-req_amber ]-severity
                                            exp = zif_ca_ops_types=>gc_severity-warning msg = 'Past amber: warning' ).
        cl_abap_unit_assert=>assert_equals( act = lt_found[ object_key = gc-req_red ]-company_code exp = gc-bukrs
                                            msg = 'Company code' ).
        cl_abap_unit_assert=>assert_equals( act = lt_found[ object_key = gc-req_red ]-amount
                                            exp = CONV zif_ca_ops_types=>ty_amount( gc-amount ) msg = 'Amount' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_found[ object_key = gc-req_done ] ) )
                                           msg = 'Answered request not reported' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_cheque_types=>gc_code-exposure ] ) )
          msg = 'Exposure per currency' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the source still a placeholder - no verdict (the runner records CHECK_FAILED)
  METHOD unset_source_raises.
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-src_request iv_value = gc-unset ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Unset source must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Not evaluated' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
