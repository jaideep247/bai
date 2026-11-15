*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_src_finding.clas.testclasses.abap
*& Purpose:
*& Tests of the open exceptions source: the checks of the stages that
*& clear the account's role (EXPECT_FROM) are read, inactive stages and
*& controls left out; the amounts are unsigned with the sign rule of the
*& balance; no stage clears the role - not evaluated with a reason. Data
*& access double. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
CLASS ltd_flow_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_flow_dao PARTIALLY IMPLEMENTED.
    DATA mt_sums TYPE zif_ca_ops_flow_types=>tt_currency_sum.
    DATA mt_checks TYPE zif_ca_ops_flow_types=>tt_check_ref.
ENDCLASS.

CLASS ltd_flow_dao IMPLEMENTATION.
  METHOD zif_ca_ops_flow_dao~open_findings.
    mt_checks = it_checks.
    rt_sums = mt_sums.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_flow_src_finding DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_dao TYPE REF TO ltd_flow_dao.

    METHODS setup.
    METHODS teardown.
    METHODS config
      RETURNING
        VALUE(rs_config) TYPE zif_ca_ops_flow_types=>ty_config.
    METHODS run
      IMPORTING
        is_config      TYPE zif_ca_ops_flow_types=>ty_config
      RETURNING
        VALUE(rt_rows) TYPE zif_ca_ops_flow_types=>tt_source_row
      RAISING
        zcx_ca_ops_error.

    METHODS checks_of_clearing_stage FOR TESTING RAISING zcx_ca_ops_error.
    METHODS unsigned_with_sign_rule  FOR TESTING RAISING zcx_ca_ops_error.
    METHODS no_stage_not_evaluated   FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_flow_src_finding IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_ca_ops_injector=>inject_flow_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  " The returns lot stage clears the returns clearing account; its check is controlled by an active row, another by
  " an inactive one
  METHOD config.
    rs_config-flow = VALUE #( flow_id = 'DISB' ).
    rs_config-stages = VALUE #(
      ( stage_id = 'RETURNS_LOT' expect_from = zif_ca_ops_flow_types=>gc_role-clarification
        expect_to = zif_ca_ops_flow_types=>gc_role-payable active = abap_true )
      ( stage_id = 'PAYRUN' active = abap_true ) ).
    rs_config-controls = VALUE #(
      ( stage_id = 'RETURNS_LOT' check_area = 'ZT_OPS_A' check_id = 'ZT_RETURNS_OPEN' active = abap_true )
      ( stage_id = 'RETURNS_LOT' check_area = 'ZT_OPS_A' check_id = 'ZT_OLD_CHECK' active = abap_false )
      ( stage_id = 'PAYRUN' check_area = 'ZT_OPS_A' check_id = 'ZT_PAYRUN' active = abap_true ) ).
  ENDMETHOD.


  METHOD run.
    rt_rows = NEW zcl_ca_ops_flow_src_finding( )->zif_ca_ops_flow_source~accounted_for(
                is_config   = is_config
                is_account  = VALUE #( flow_acct = 'RETURNS' role = zif_ca_ops_flow_types=>gc_role-clarification
                                       bukrs = 'ZT01' )
                iv_key_date = '20261115' ).
  ENDMETHOD.


  " Rule: only the active checks of the stages that clear the account's role are read
  METHOD checks_of_clearing_stage.
    run( config( ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_checks ) exp = 1 msg = 'One check' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_checks[ 1 ]-check_id exp = 'ZT_RETURNS_OPEN'
                                        msg = 'The returns lot check' ).
  ENDMETHOD.


  " Rule: a finding's amount is unsigned - it takes the sign of the closing position (sign rule B)
  METHOD unsigned_with_sign_rule.
    mo_dao->mt_sums = VALUE #( ( currency = 'USD' amount = '300.00' item_count = 1 ) ).
    DATA(lt_rows) = run( config( ) ).
    DATA(ls_row) = lt_rows[ currency = 'USD' ].
    cl_abap_unit_assert=>assert_equals( act = ls_row-amount exp = '300.00' msg = 'Unsigned' ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-sign_rule exp = zif_ca_ops_flow_types=>gc_sign_of_balance
                                        msg = 'Sign of the balance' ).
  ENDMETHOD.


  " Rule: no stage clears the role - no check is named, so the account is not evaluated (grey)
  METHOD no_stage_not_evaluated.
    DATA(ls_config) = config( ).
    CLEAR ls_config-stages[ 1 ]-expect_from.
    DATA(lt_rows) = run( ls_config ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-status
                                        exp = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                                        msg = 'Not evaluated' ).
    cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_checks msg = 'Nothing read' ).
  ENDMETHOD.

ENDCLASS.
