*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the account flow data access on doubles of its tables
*& and of the tables its sources read: active configuration rows of one
*& flow only; an evaluation saved is removed by the retention with its
*& items; the latest break snapshot per break account in the window and
*& its groups in a named bucket only (not OTHER); open FI-CA items of the
*& account range up to the key date only (no clearing document); open and
*& assigned findings of the named checks and company code only. Does not
*& prove live SAP runtime behavior (PlanViz FLOW-PV4 / FLOW-PV5).
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
CLASS ltc_flow_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        flow  TYPE zif_ca_ops_flow_types=>ty_flow_id VALUE 'DISB',
        bukrs TYPE bukrs VALUE 'ZT01',
        s1    TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000D1',
        s2    TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000D2',
        s3    TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000D3',
        e1    TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E1',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_flow_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS config_active_rows_only    FOR TESTING.
    METHODS evaluation_saved_and_purged FOR TESTING RAISING zcx_ca_ops_error.
    METHODS latest_snapshot_per_account FOR TESTING.
    METHODS explained_groups_only      FOR TESTING.
    METHODS fica_open_items_only       FOR TESTING.
    METHODS open_findings_of_checks    FOR TESTING.
ENDCLASS.


CLASS ltc_flow_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #(
               ( 'ZCA_OPS_FLOW' ) ( 'ZCA_OPS_FLWACC' ) ( 'ZCA_OPS_FLWSTG' ) ( 'ZCA_OPS_FLWTIL' )
               ( 'ZCA_OPS_FLWCTL' ) ( 'ZCA_OPS_FLWRUL' ) ( 'ZCA_OPS_FLWEVL' ) ( 'ZCA_OPS_FLWEVI' ) ( 'ZCA_OPS_BRKRUN' )
               ( 'ZCA_OPS_BRKGRP' ) ( 'DFKKOP' ) ( 'ZCA_OPS_FINDING' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_flow_dao( ).
  ENDMETHOD.


  " Rule: the configuration of one flow, active rows only, rules by sequence
  METHOD config_active_rows_only.
    DATA lt_flows TYPE STANDARD TABLE OF zca_ops_flow WITH EMPTY KEY.
    DATA lt_accounts TYPE STANDARD TABLE OF zca_ops_flwacc WITH EMPTY KEY.
    DATA lt_rules TYPE STANDARD TABLE OF zca_ops_flwrul WITH EMPTY KEY.
    lt_flows = VALUE #( ( area = gc-area flow_id = gc-flow active = abap_true )
                        ( area = gc-area flow_id = 'COLL' active = abap_false ) ).
    lt_accounts = VALUE #( ( area = gc-area flow_id = gc-flow flow_acct = 'CASH' active = abap_true )
                           ( area = gc-area flow_id = gc-flow flow_acct = 'OLD' active = abap_false )
                           ( area = gc-area flow_id = 'COLL' flow_acct = 'CASH' active = abap_true ) ).
    lt_rules = VALUE #( ( area = gc-area flow_id = gc-flow rule_seq = '0020' rule_id = 'B' active = abap_true )
                        ( area = gc-area flow_id = gc-flow rule_seq = '0010' rule_id = 'A' active = abap_true ) ).
    go_env->insert_test_data( lt_flows ).
    go_env->insert_test_data( lt_accounts ).
    go_env->insert_test_data( lt_rules ).
    DATA(lt_read) = mo_cut->get_flows( gc-area ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_read ) exp = 1 msg = 'Active flows only' ).
    DATA(ls_config) = mo_cut->get_config( lt_read[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_config-accounts ) exp = 1 msg = 'Active accounts of the flow' ).
    cl_abap_unit_assert=>assert_equals( act = ls_config-rules[ 1 ]-rule_id exp = 'A' msg = 'By sequence' ).
  ENDMETHOD.


  " Rule: an evaluation is saved with its items; the retention removes it (header and items) before the cut-off
  METHOD evaluation_saved_and_purged.
    mo_cut->save_evaluation( is_eval  = VALUE #( eval_id = gc-e1 area = gc-area flow_id = gc-flow
                                                 key_date = '20261001' )
                             it_items = VALUE #( ( item_no = 1 flow_acct = 'CASH' currency = 'USD' amount = 10 )
                                                 ( item_no = 2 flow_acct = 'CLEARING' currency = 'USD' ) ) ).
    SELECT COUNT(*) FROM zca_ops_flwevi WHERE eval_id = @gc-e1 INTO @DATA(lv_items).
    cl_abap_unit_assert=>assert_equals( act = lv_items exp = 2 msg = 'Items saved' ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->delete_evaluations( iv_area    = gc-area
                                                                          iv_flow_id = gc-flow
                                                                          iv_before  = '20261001' )
                                        exp = 0 msg = 'Not older than the cut-off' ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->delete_evaluations( iv_area    = gc-area
                                                                          iv_flow_id = gc-flow
                                                                          iv_before  = '20261002' )
                                        exp = 1 msg = 'Removed' ).
    SELECT COUNT(*) FROM zca_ops_flwevi WHERE eval_id = @gc-e1 INTO @lv_items.
    cl_abap_unit_assert=>assert_equals( act = lv_items exp = 0 msg = 'Items removed' ).
  ENDMETHOD.


  " Rule: per break account in the range the latest snapshot of the window (later key date, then later start)
  METHOD latest_snapshot_per_account.
    DATA lt_runs TYPE STANDARD TABLE OF zca_ops_brkrun WITH EMPTY KEY.
    lt_runs = VALUE #( ( snap_id = gc-s1 acct_id = 'A' bukrs = gc-bukrs hkont = '0000199999' key_date = '20261113'
                         started_at = '20261114060000.0000000' )
                       ( snap_id = gc-s2 acct_id = 'A' bukrs = gc-bukrs hkont = '0000199999' key_date = '20261114'
                         started_at = '20261115060000.0000000' )
                       ( snap_id = gc-s3 acct_id = 'B' bukrs = gc-bukrs hkont = '0000299999' key_date = '20261114'
                         started_at = '20261115060000.0000000' ) ).
    go_env->insert_test_data( lt_runs ).
    DATA(lt_snaps) = mo_cut->break_snapshots( iv_bukrs      = gc-bukrs
                                              iv_hkont_from = '0000199999'
                                              iv_hkont_to   = '0000199999'
                                              iv_from       = '20261112'
                                              iv_key_date   = '20261115' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_snaps ) exp = 1 msg = 'One account in the range' ).
    cl_abap_unit_assert=>assert_equals( act = lt_snaps[ 1 ]-snap_id exp = gc-s2 msg = 'Latest snapshot' ).
  ENDMETHOD.


  " Rule: groups in a named bucket are explained; OTHER is not
  METHOD explained_groups_only.
    DATA lt_groups TYPE STANDARD TABLE OF zca_ops_brkgrp WITH EMPTY KEY.
    lt_groups = VALUE #( ( snap_id = gc-s1 group_no = 1 bucket = 'TIMING' currency = 'USD' amount = '-100.00' )
                         ( snap_id = gc-s1 group_no = 2 bucket = 'OTHER' currency = 'USD' amount = '-50.00' )
                         ( snap_id = gc-s2 group_no = 1 bucket = 'TIMING' currency = 'USD' amount = '-7.00' ) ).
    go_env->insert_test_data( lt_groups ).
    DATA(lt_sums) = mo_cut->break_explained( VALUE #( ( gc-s1 ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_sums ) exp = 1 msg = 'One currency' ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-amount exp = '-100.00' msg = 'Named bucket only' ).
  ENDMETHOD.


  " Rule: open items (no clearing document) of the account range posted up to the key date, per currency
  METHOD fica_open_items_only.
    DATA lt_items TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    lt_items = VALUE #( ( opbel = '000000000001' bukrs = gc-bukrs hkont = '0000160000' waers = 'USD'
                          betrw = '-300.00' budat = '20261110' )
                        ( opbel = '000000000002' bukrs = gc-bukrs hkont = '0000160000' waers = 'USD'
                          betrw = '-2100.00' budat = '20261110' augbl = '000000000009' )
                        ( opbel = '000000000003' bukrs = gc-bukrs hkont = '0000160000' waers = 'USD'
                          betrw = '-5.00' budat = '20261120' ) ).
    go_env->insert_test_data( lt_items ).
    DATA(lt_sums) = mo_cut->fica_open_items( iv_bukrs      = gc-bukrs
                                             iv_hkont_from = '0000160000'
                                             iv_hkont_to   = '0000160000'
                                             iv_currency   = ''
                                             iv_key_date   = '20261115' ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-amount exp = '-300.00' msg = 'Open up to the key date' ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-item_count exp = 1 msg = 'One item' ).
  ENDMETHOD.


  " Rule: open and assigned findings of the named checks for the company code; resolved ones and other checks not
  METHOD open_findings_of_checks.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    lt_findings = VALUE #(
      ( run_id = gc-s1 finding_no = 1 area = gc-area group2 = 'ZT_RETURNS' bukrs = gc-bukrs currency = 'USD'
        amount = 300 disposition = zif_ca_ops_types=>gc_disposition-open )
      ( run_id = gc-s1 finding_no = 2 area = gc-area group2 = 'ZT_RETURNS' bukrs = gc-bukrs currency = 'USD'
        amount = 40 disposition = zif_ca_ops_types=>gc_disposition-assigned )
      ( run_id = gc-s1 finding_no = 3 area = gc-area group2 = 'ZT_RETURNS' bukrs = gc-bukrs currency = 'USD'
        amount = 999 disposition = zif_ca_ops_types=>gc_disposition-resolved )
      ( run_id = gc-s1 finding_no = 4 area = gc-area group2 = 'ZT_OTHER' bukrs = gc-bukrs currency = 'USD'
        amount = 999 disposition = zif_ca_ops_types=>gc_disposition-open )
      ( run_id = gc-s1 finding_no = 5 area = gc-area group2 = 'ZT_RETURNS' bukrs = 'ZT02' currency = 'USD'
        amount = 999 disposition = zif_ca_ops_types=>gc_disposition-open ) ).
    go_env->insert_test_data( lt_findings ).
    DATA(lt_sums) = mo_cut->open_findings( it_checks   = VALUE #( ( check_area = gc-area check_id = 'ZT_RETURNS' ) )
                                           iv_bukrs    = gc-bukrs
                                           iv_currency = '' ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-amount exp = '340.00' msg = 'Open and assigned only' ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-item_count exp = 2 msg = 'Two exceptions' ).
  ENDMETHOD.

ENDCLASS.
