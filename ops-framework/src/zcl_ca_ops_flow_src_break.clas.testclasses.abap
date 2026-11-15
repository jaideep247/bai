*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_src_break.clas.testclasses.abap
*& Purpose:
*& Tests of the break analysis source: the explained groups of the latest
*& snapshots in the window are what it accounts for (signed, per
*& currency), a blank-currency row covers the other currencies of the
*& account, no snapshot or a partial one is not evaluated with a reason,
*& the window is FLOW_BREAK_MAX_AGE_DAYS before the key date and the G/L
*& range defaults to one account. Data access double; parameters in
*& memory. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
CLASS ltd_flow_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_flow_dao PARTIALLY IMPLEMENTED.
    DATA mt_snaps TYPE zif_ca_ops_flow_types=>tt_break_snap.
    DATA mt_sums TYPE zif_ca_ops_flow_types=>tt_currency_sum.
    DATA mv_from TYPE d.
    DATA mv_hkont_to TYPE saknr.
    DATA mt_ids TYPE zif_ca_ops_flow_types=>tt_run_id.
ENDCLASS.

CLASS ltd_flow_dao IMPLEMENTATION.
  METHOD zif_ca_ops_flow_dao~break_snapshots.
    mv_from = iv_from.
    mv_hkont_to = iv_hkont_to.
    rt_snaps = mt_snaps.
  ENDMETHOD.
  METHOD zif_ca_ops_flow_dao~break_explained.
    mt_ids = it_snap_ids.
    rt_sums = mt_sums.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_flow_src_break DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_snap TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000B1'.
    DATA mo_dao TYPE REF TO ltd_flow_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS account
      IMPORTING
        iv_currency       TYPE zif_ca_ops_types=>ty_currency OPTIONAL
      RETURNING
        VALUE(rs_account) TYPE zif_ca_ops_flow_types=>ty_account.
    METHODS run
      IMPORTING
        is_account     TYPE zif_ca_ops_flow_types=>ty_account
      RETURNING
        VALUE(rt_rows) TYPE zif_ca_ops_flow_types=>tt_source_row
      RAISING
        zcx_ca_ops_error.

    METHODS explained_groups_per_currency FOR TESTING RAISING zcx_ca_ops_error.
    METHODS named_currency_only           FOR TESTING RAISING zcx_ca_ops_error.
    METHODS no_snapshot_not_evaluated     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS partial_snapshot_not_eval     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS window_from_parameter         FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_flow_src_break IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_injector=>inject_flow_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD account.
    rs_account = VALUE #( flow_acct = 'CLEARING' role = zif_ca_ops_flow_types=>gc_role-clearing bukrs = 'ZT01'
                          hkont_from = '0000199999' currency = iv_currency active = abap_true ).
  ENDMETHOD.


  METHOD run.
    rt_rows = NEW zcl_ca_ops_flow_src_break( )->zif_ca_ops_flow_source~accounted_for(
                is_config   = VALUE #( flow = VALUE #( flow_id = 'DISB' ) )
                is_account  = is_account
                iv_key_date = '20261115' ).
  ENDMETHOD.


  " Rule: the explained groups of the latest snapshot are accounted for, signed, per currency; a blank-currency row
  " says "nothing explained" for the other currencies of the account
  METHOD explained_groups_per_currency.
    mo_dao->mt_snaps = VALUE #( ( snap_id = gc_snap acct_id = 'ZT_CLEARING' key_date = '20261115'
                                  status = zif_ca_ops_brk_types=>gc_status-complete ) ).
    mo_dao->mt_sums = VALUE #( ( currency = 'USD' amount = '-120.00' item_count = 2 ) ).
    DATA(lt_rows) = run( account( ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ currency = 'USD' ]-amount exp = '-120.00' msg = 'Signed' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ currency = 'USD' ]-item_count exp = 2 msg = 'Groups' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ currency = '' ]-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-evaluated
                                        msg = 'Other currencies evaluated' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_ids[ 1 ] exp = gc_snap msg = 'Snapshot read' ).
  ENDMETHOD.


  " Rule: an account of one currency gets the row of that currency only
  METHOD named_currency_only.
    mo_dao->mt_snaps = VALUE #( ( snap_id = gc_snap acct_id = 'ZT_CLEARING' key_date = '20261115'
                                  status = zif_ca_ops_brk_types=>gc_status-complete ) ).
    mo_dao->mt_sums = VALUE #( ( currency = 'USD' amount = '50.00' item_count = 1 )
                               ( currency = 'EUR' amount = '10.00' item_count = 1 ) ).
    DATA(lt_rows) = run( account( 'USD' ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One row' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-currency exp = 'USD' msg = 'USD only' ).
  ENDMETHOD.


  " Rule: no snapshot in the window - not evaluated with the reason, never zero
  METHOD no_snapshot_not_evaluated.
    DATA(lt_rows) = run( account( ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                                        msg = 'Not evaluated' ).
    cl_abap_unit_assert=>assert_not_initial( act = lt_rows[ 1 ]-reason msg = 'Reason' ).
  ENDMETHOD.


  " Rule: a partial snapshot holds the oldest groups only - not evaluated
  METHOD partial_snapshot_not_eval.
    mo_dao->mt_snaps = VALUE #( ( snap_id = gc_snap acct_id = 'ZT_CLEARING' key_date = '20261115'
                                  status = zif_ca_ops_brk_types=>gc_status-partial ) ).
    DATA(lt_rows) = run( account( ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                                        msg = 'Partial: not evaluated' ).
  ENDMETHOD.


  " Rule: snapshots of FLOW_BREAK_MAX_AGE_DAYS before the key date count; one account when no range end is given
  METHOD window_from_parameter.
    mo_seed->set( iv_name = zif_ca_ops_flow_types=>gc_param-break_age iv_value = '5' ).
    run( account( ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_from exp = '20261110' msg = 'Window' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_hkont_to exp = '0000199999' msg = 'One account' ).
  ENDMETHOD.

ENDCLASS.
