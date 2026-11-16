*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_ect_pending.clas.testclasses.abap
*& Purpose:
*& Unit tests of the ECT pending check: a cheque whose latest valid status is
*& pending and still open on the register is a finding with payment
*& document, amount, currency and age, plus one exposure finding per
*& currency; a later non-pending status, a row with STATE set, a cheque
*& cashed on the register (BNKDT) are not; a pending cheque without register
*& row has its own code; unset pending values raise (no verdict). Doubles of
*& the trace repository and the cheque DAO; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
CLASS ltd_trace DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_rows TYPE zif_cd_ops_trace_types=>tt_cfg_row.
    DATA ms_source TYPE zif_cd_ops_trace_types=>ty_source_cfg.
ENDCLASS.

CLASS ltd_trace IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~read_configured_after.
    ms_source = is_source.
    rt_rows = mt_rows.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_cheque DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_cheque_dao PARTIALLY IMPLEMENTED.
    DATA mt_register TYPE zif_cd_hck_cheque_types=>tt_register.
ENDCLASS.

CLASS ltd_cheque IMPLEMENTATION.
  METHOD zif_cd_hck_cheque_dao~get_register.
    LOOP AT mt_register ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF line_exists( it_cheques[ table_line = <ls_row>-ztnum ] ).
        INSERT <ls_row> INTO TABLE rt_register.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ect_pending DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        check     TYPE zif_cd_hck_types=>ty_check_id VALUE 'C_ECT_PENDING',
        names     TYPE zif_cd_hck_types=>ty_param VALUE 'TABLE=ZCD_CHECK_HIST;KEY=ZTNUM;KEY2=STATE;STATUS=ZSTAT;DATE=ZDATE',
        options   TYPE zif_cd_hck_types=>ty_param VALUE 'PENDING=1',
        unset     TYPE zif_cd_hck_types=>ty_param VALUE 'PENDING=‹pending values›',
        today     TYPE d VALUE '20261116',
        sent      TYPE d VALUE '20261106',
        later     TYPE d VALUE '20261110',
        pending   TYPE c LENGTH 40 VALUE '1',
        mailed    TYPE c LENGTH 40 VALUE '10',
        state_set TYPE zif_cd_ops_trace_types=>ty_key_value VALUE 'X',
        chq_open  TYPE zif_cd_ops_trace_types=>ty_key_value VALUE '0000000800001',
        chq_moved TYPE zif_cd_ops_trace_types=>ty_key_value VALUE '0000000800002',
        chq_cash  TYPE zif_cd_ops_trace_types=>ty_key_value VALUE '0000000800003',
        chq_noreg TYPE zif_cd_ops_trace_types=>ty_key_value VALUE '0000000800004',
        chq_state TYPE zif_cd_ops_trace_types=>ty_key_value VALUE '0000000800005',
        doc       TYPE c LENGTH 24 VALUE '000000810001',
        doc_cash  TYPE c LENGTH 24 VALUE '000000810003',
        bukrs     TYPE c LENGTH 4 VALUE 'ZT01',
        usd       TYPE zif_ca_ops_types=>ty_currency VALUE 'USD',
        amount    TYPE zif_ca_ops_types=>ty_amount VALUE '310.00',
      END OF gc.

    DATA mo_trace TYPE REF TO ltd_trace.
    DATA mo_cheque TYPE REF TO ltd_cheque.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.

    METHODS setup.
    METHODS teardown.
    METHODS pending_open_is_finding FOR TESTING.
    METHODS not_pending_not_found FOR TESTING.
    METHODS no_register_own_code FOR TESTING.
    METHODS unset_values_raise FOR TESTING.

    METHODS row
      IMPORTING
        iv_key    TYPE zif_cd_ops_trace_types=>ty_key_value
        iv_status TYPE clike
        iv_date   TYPE d
        iv_state  TYPE zif_cd_ops_trace_types=>ty_key_value OPTIONAL.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_ca_ops_error.
    METHODS findings_of
      IMPORTING
        is_result          TYPE zif_cd_hck_types=>ty_check_result
        iv_code            TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.
ENDCLASS.


CLASS ltc_ect_pending IMPLEMENTATION.

  METHOD setup.
    mo_trace = NEW #( ).
    mo_cheque = NEW #( ).
    ms_def = VALUE #( check_id = gc-check param1 = gc-names param2 = gc-options ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    zcl_cd_hck_injector=>inject_cheque_dao( mo_cheque ).
    " open: pending since the 6th, register open
    row( iv_key = gc-chq_open iv_status = gc-pending iv_date = gc-sent ).
    " moved on: pending, then mailed later
    row( iv_key = gc-chq_moved iv_status = gc-pending iv_date = gc-sent ).
    row( iv_key = gc-chq_moved iv_status = gc-mailed iv_date = gc-later ).
    " cashed on the register (encashment date written by the statement import)
    row( iv_key = gc-chq_cash iv_status = gc-pending iv_date = gc-sent ).
    " only a row with STATE set: not a validated status
    row( iv_key = gc-chq_state iv_status = gc-pending iv_date = gc-sent iv_state = gc-state_set ).
    mo_cheque->mt_register = VALUE #( ( ztnum = gc-chq_open doc1r = gc-doc bukrs = gc-bukrs
                                        amount = gc-amount currency = gc-usd )
                                      ( ztnum = gc-chq_cash doc1r = gc-doc_cash bukrs = gc-bukrs
                                        amount = gc-amount currency = gc-usd bnkdt = gc-later ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_hck_injector=>reset( ).
  ENDMETHOD.


  METHOD row.
    INSERT VALUE #( key1 = iv_key key2 = iv_state status = iv_status ev_date = iv_date ) INTO TABLE mo_trace->mt_rows.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_ect_pending( )->zif_cd_hck_check~execute(
      is_def        = ms_def
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc-today ) ).
  ENDMETHOD.


  METHOD findings_of.
    rt_findings = VALUE #( FOR ls_finding IN is_result-findings WHERE ( check_code = iv_code ) ( ls_finding ) ).
  ENDMETHOD.


  " Rule: latest valid status pending and register open = one finding with the payment evidence
  METHOD pending_open_is_finding.
    TRY.
        DATA(ls_result) = act( ).
        DATA(lt_found) = findings_of( is_result = ls_result iv_code = zif_cd_hck_cheque_types=>gc_code-ect_pending ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_found ) exp = 1 msg = 'One pending cheque' ).
        DATA(ls_finding) = lt_found[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = gc-chq_open msg = 'Cheque number' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-reference exp = gc-doc msg = 'Payment document' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = gc-amount msg = 'Amount' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-currency exp = gc-usd msg = 'Currency' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-company_code exp = gc-bukrs msg = 'Company code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-business_date exp = gc-sent msg = 'Pending since' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 1 msg = 'Count metric' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 2 ]-value exp = 10 msg = 'Age of the oldest' ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( findings_of( is_result = ls_result iv_code = zif_cd_hck_cheque_types=>gc_code-exposure ) )
          exp = 1 msg = 'One exposure finding (USD)' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->ms_source-key2_field exp = 'STATE' msg = 'STATE read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a later status, a STATE row and a cashed cheque are not pending
  METHOD not_pending_not_found.
    TRY.
        DATA(ls_result) = act( ).
        LOOP AT ls_result-findings ASSIGNING FIELD-SYMBOL(<ls_finding>)
             WHERE check_code = zif_cd_hck_cheque_types=>gc_code-ect_pending
                OR check_code = zif_cd_hck_cheque_types=>gc_code-ect_no_register.
          cl_abap_unit_assert=>assert_differs( act = <ls_finding>-object_key exp = gc-chq_moved msg = 'Moved on' ).
          cl_abap_unit_assert=>assert_differs( act = <ls_finding>-object_key exp = gc-chq_cash msg = 'Cashed' ).
          cl_abap_unit_assert=>assert_differs( act = <ls_finding>-object_key exp = gc-chq_state msg = 'STATE set' ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a pending cheque without register row is reported with its own code, amount not known
  METHOD no_register_own_code.
    TRY.
        row( iv_key = gc-chq_noreg iv_status = gc-pending iv_date = gc-later ).
        DATA(ls_result) = act( ).
        DATA(lt_found) = findings_of( is_result = ls_result iv_code = zif_cd_hck_cheque_types=>gc_code-ect_no_register ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_found ) exp = 1 msg = 'One without register row' ).
        cl_abap_unit_assert=>assert_initial( act = lt_found[ 1 ]-currency msg = 'Currency not known' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: pending values still a placeholder - not evaluated (the engine records PLUGIN_ERROR, never green)
  METHOD unset_values_raise.
    ms_def-param2 = gc-unset.
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Unset pending values must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Not evaluated' ).
        cl_abap_unit_assert=>assert_initial( act = mo_trace->ms_source msg = 'Nothing read' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
