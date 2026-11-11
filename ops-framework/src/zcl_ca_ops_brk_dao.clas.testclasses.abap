*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the break analysis data access on doubles of ACDOCA and
*& the break tables: the grouped read returns only groups of one
*& assignment and currency that do not net to zero, oldest first, in the
*& window of the account, capped; the line read returns the lines of the
*& assignments asked for with the later flag and the reference key; rules
*& of the area and of every area, active only; a snapshot saved is read
*& back as the latest of its account and its unexplained groups by age.
*& Does not prove live SAP runtime behavior (PlanViz BRK-PV1 / BRK-PV2).
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
CLASS ltc_brk_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        acct     TYPE zif_ca_ops_brk_types=>ty_acct_id VALUE 'ZT_CLEARING',
        bukrs    TYPE bukrs VALUE 'ZT01',
        hkont    TYPE saknr VALUE '0000199999',
        key_date TYPE d VALUE '20261031',
        snap     TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000C1',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_brk_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS journal_line
      IMPORTING
        iv_belnr      TYPE belnr_d
        iv_zuonr      TYPE zif_ca_ops_brk_types=>ty_assignment
        iv_currency   TYPE zif_ca_ops_types=>ty_currency DEFAULT 'USD'
        iv_amount     TYPE zif_ca_ops_types=>ty_amount
        iv_date       TYPE d
      RETURNING
        VALUE(rs_row) TYPE acdoca.
    METHODS account
      RETURNING
        VALUE(rs_account) TYPE zif_ca_ops_brk_types=>ty_account.

    METHODS groups_not_netting_only     FOR TESTING.
    METHODS lines_of_assignments        FOR TESTING.
    METHODS rules_of_area_and_any       FOR TESTING.
    METHODS snapshot_read_back          FOR TESTING.
ENDCLASS.


CLASS ltc_brk_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ACDOCA' ) ( 'ZCA_OPS_BRKACC' )
                                                                            ( 'ZCA_OPS_BRKBKT' ) ( 'ZCA_OPS_BRKRUL' )
                                                                            ( 'ZCA_OPS_BRKCND' ) ( 'ZCA_OPS_BRKRUN' )
                                                                            ( 'ZCA_OPS_BRKGRP' ) ( 'ZCA_OPS_BRKITM' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_brk_dao( ).
  ENDMETHOD.


  METHOD journal_line.
    rs_row-rldnr  = '0L'.
    rs_row-rbukrs = gc-bukrs.
    rs_row-gjahr  = '2026'.
    rs_row-belnr  = iv_belnr.
    rs_row-docln  = '000001'.
    rs_row-racct  = gc-hkont.
    rs_row-rwcur  = iv_currency.
    rs_row-wsl    = iv_amount.
    rs_row-budat  = iv_date.
    rs_row-blart  = 'SA'.
    rs_row-drcrk  = COND #( WHEN iv_amount >= 0 THEN zif_ca_ops_brk_types=>gc_debit ELSE 'H' ).
    rs_row-zuonr  = iv_zuonr.
    rs_row-awtyp  = 'FKKSU'.
    rs_row-awref  = 'KEY0000001'.
  ENDMETHOD.


  METHOD account.
    rs_account-area    = gc-area.
    rs_account-acct_id = gc-acct.
    rs_account-bukrs   = gc-bukrs.
    rs_account-hkont   = gc-hkont.
  ENDMETHOD.


  " Rule: A1 nets to zero (dropped), A2 does not (a break), A3 in EUR and USD are two groups; oldest first; the
  " line after the key date is not part of the grouped read; the cap cuts
  METHOD groups_not_netting_only.
    DATA lt_lines TYPE STANDARD TABLE OF acdoca WITH EMPTY KEY.
    TRY.
        INSERT journal_line( iv_belnr = '0100000001' iv_zuonr = 'A1' iv_amount = 100 iv_date = '20261020' )
               INTO TABLE lt_lines.
        INSERT journal_line( iv_belnr = '0100000002' iv_zuonr = 'A1' iv_amount = -100 iv_date = '20261021' )
               INTO TABLE lt_lines.
        INSERT journal_line( iv_belnr = '0100000003' iv_zuonr = 'A2' iv_amount = 50 iv_date = '20261015' )
               INTO TABLE lt_lines.
        INSERT journal_line( iv_belnr = '0100000004' iv_zuonr = 'A3' iv_amount = 5 iv_date = '20261025' )
               INTO TABLE lt_lines.
        INSERT journal_line( iv_belnr = '0100000005' iv_zuonr = 'A3' iv_currency = 'EUR' iv_amount = 7
                             iv_date = '20261026' ) INTO TABLE lt_lines.
        INSERT journal_line( iv_belnr = '0100000006' iv_zuonr = 'A2' iv_amount = -50 iv_date = '20261102' )
               INTO TABLE lt_lines.
        go_env->insert_test_data( lt_lines ).
        DATA(lt_sums) = mo_cut->open_groups( is_account = account( ) iv_ledger = '0L' iv_from = '20261001'
                                             iv_key_date = gc-key_date iv_max = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_sums ) exp = 3 msg = 'Three groups do not net' ).
        cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-assignment exp = 'A2' msg = 'Oldest first' ).
        cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-amount exp = 50 msg = 'Net at the key date' ).
        lt_sums = mo_cut->open_groups( is_account = account( ) iv_ledger = '0L' iv_from = '20261001'
                                       iv_key_date = gc-key_date iv_max = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_sums ) exp = 1 msg = 'Capped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the lines of the asked assignments in the window, the later flag and the reference key
  METHOD lines_of_assignments.
    DATA lt_lines TYPE STANDARD TABLE OF acdoca WITH EMPTY KEY.
    DATA lt_range TYPE zif_ca_ops_brk_dao=>tt_assignment_range.
    TRY.
        INSERT journal_line( iv_belnr = '0100000003' iv_zuonr = 'A2' iv_amount = 50 iv_date = '20261015' )
               INTO TABLE lt_lines.
        INSERT journal_line( iv_belnr = '0100000006' iv_zuonr = 'A2' iv_amount = -50 iv_date = '20261102' )
               INTO TABLE lt_lines.
        INSERT journal_line( iv_belnr = '0100000007' iv_zuonr = 'A9' iv_amount = 9 iv_date = '20261015' )
               INTO TABLE lt_lines.
        go_env->insert_test_data( lt_lines ).
        lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'A2' ) ).
        DATA(lt_items) = mo_cut->group_lines( is_account = account( ) iv_ledger = '0L' iv_from = '20261001'
                                              iv_to = '20261110' iv_key_date = gc-key_date it_assignments = lt_range
                                              iv_max = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 2 msg = 'Lines of A2 only' ).
        cl_abap_unit_assert=>assert_false( act = lt_items[ 1 ]-later msg = 'Up to the key date' ).
        cl_abap_unit_assert=>assert_true( act = lt_items[ 2 ]-later msg = 'After the key date' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-recon_key exp = 'KEY0000001' msg = 'Reference key' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the active rules of the area and of every area (*)
  METHOD rules_of_area_and_any.
    DATA lt_rules TYPE STANDARD TABLE OF zca_ops_brkrul WITH EMPTY KEY.
    DATA ls_rule TYPE zca_ops_brkrul.
    TRY.
        ls_rule-area    = zif_ca_ops_brk_types=>gc_area_any.
        ls_rule-rule_id = 'S4_TIMING'.
        ls_rule-active  = abap_true.
        INSERT ls_rule INTO TABLE lt_rules.
        ls_rule-area    = gc-area.
        ls_rule-rule_id = 'ZT_OWN'.
        INSERT ls_rule INTO TABLE lt_rules.
        ls_rule-area    = 'ZT_OPS_B'.
        ls_rule-rule_id = 'ZT_OTHER'.
        INSERT ls_rule INTO TABLE lt_rules.
        ls_rule-area    = gc-area.
        ls_rule-rule_id = 'ZT_OFF'.
        ls_rule-active  = abap_false.
        INSERT ls_rule INTO TABLE lt_rules.
        go_env->insert_test_data( lt_rules ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_rules( gc-area ) ) exp = 2
                                            msg = 'Area and *, active only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a saved snapshot is the latest of its account; its unexplained groups come back oldest first
  METHOD snapshot_read_back.
    DATA ls_snapshot TYPE zif_ca_ops_brk_types=>ty_snapshot.
    TRY.
        ls_snapshot-snap_id  = gc-snap.
        ls_snapshot-area     = gc-area.
        ls_snapshot-acct_id  = gc-acct.
        ls_snapshot-key_date = gc-key_date.
        ls_snapshot-status   = zif_ca_ops_brk_types=>gc_status-complete.
        mo_cut->save_snapshot( is_snapshot = ls_snapshot
                               it_groups   = VALUE #( ( group_no = 1 assignment = 'A1' currency = 'USD' amount = 5
                                                        age_days = 3 bucket = zif_ca_ops_brk_types=>gc_bucket_other )
                                                      ( group_no = 2 assignment = 'A2' currency = 'USD' amount = 6
                                                        age_days = 9 bucket = zif_ca_ops_brk_types=>gc_bucket_other )
                                                      ( group_no = 3 assignment = 'A3' currency = 'USD' amount = 7
                                                        age_days = 20 bucket = 'TIMING' explained = abap_true ) )
                               it_items    = VALUE #( ( group_no = 1 item_no = 1 bucket = 'OTHER' ) ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->latest_snapshot( iv_area = gc-area iv_acct_id = gc-acct )-snap_id
                                            exp = gc-snap msg = 'Latest snapshot' ).
        DATA(lt_breaks) = mo_cut->open_breaks( iv_snap_id = gc-snap iv_min_age = 1 iv_max = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_breaks ) exp = 2 msg = 'Unexplained only' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-assignment exp = 'A2' msg = 'Oldest first' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->count_open_breaks( iv_snap_id = gc-snap iv_min_age = 5 )
                                            exp = 1 msg = 'Counted by age' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
