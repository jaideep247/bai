*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_purge.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the purge target BREAK: a snapshot older than the cutoff
*& that a later snapshot of its account replaced is purged with its groups
*& and lines; the latest snapshot of an account is kept however old; the
*& package size bounds a delete. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
CLASS ltc_brk_purge DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        cutoff TYPE timestampl VALUE '20261101000000.0000000',
        old_a  TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000A1',
        new_a  TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000A2',
        only_b TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000B1',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_purge_target.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS replaced_snapshot_purged FOR TESTING.
ENDCLASS.


CLASS ltc_brk_purge IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCA_OPS_BRKRUN' ) ( 'ZCA_OPS_BRKGRP' )
                                                                            ( 'ZCA_OPS_BRKITM' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_runs TYPE STANDARD TABLE OF zca_ops_brkrun WITH EMPTY KEY.
    DATA lt_groups TYPE STANDARD TABLE OF zca_ops_brkgrp WITH EMPTY KEY.
    DATA lt_items TYPE STANDARD TABLE OF zca_ops_brkitm WITH EMPTY KEY.
    DATA ls_run TYPE zca_ops_brkrun.
    DATA ls_group TYPE zca_ops_brkgrp.
    DATA ls_item TYPE zca_ops_brkitm.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_brk_purge( ).
    " account A: an old snapshot replaced by a new one; account B: one old snapshot (the latest - kept)
    ls_run-area       = 'ZT_OPS_A'.
    ls_run-acct_id    = 'ZT_ACCT_A'.
    ls_run-snap_id    = gc-old_a.
    ls_run-started_at = '20260901060000.0000000'.
    INSERT ls_run INTO TABLE lt_runs.
    ls_run-snap_id    = gc-new_a.
    ls_run-started_at = '20261102060000.0000000'.
    INSERT ls_run INTO TABLE lt_runs.
    ls_run-acct_id    = 'ZT_ACCT_B'.
    ls_run-snap_id    = gc-only_b.
    ls_run-started_at = '20260901060000.0000000'.
    INSERT ls_run INTO TABLE lt_runs.
    ls_group-snap_id  = gc-old_a.
    ls_group-group_no = 1.
    INSERT ls_group INTO TABLE lt_groups.
    ls_item-snap_id   = gc-old_a.
    ls_item-group_no  = 1.
    ls_item-item_no   = 1.
    INSERT ls_item INTO TABLE lt_items.
    go_env->insert_test_data( lt_runs ).
    go_env->insert_test_data( lt_groups ).
    go_env->insert_test_data( lt_items ).
  ENDMETHOD.


  " Rule: only a replaced snapshot before the cutoff goes, with its groups and lines; the latest stays
  METHOD replaced_snapshot_purged.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->count_purgeable( iv_target = 'BREAK' iv_cutoff = gc-cutoff
                                                                           iv_today  = '20261102' )
                                            exp = 1 msg = 'One purgeable snapshot' ).
        DATA(lv_count) = mo_cut->delete_package( EXPORTING iv_target    = 'BREAK'
                                                           iv_cutoff    = gc-cutoff
                                                           iv_today     = '20261102'
                                                           iv_max       = 10
                                                 IMPORTING ev_dependent = DATA(lv_dependent) ).
        cl_abap_unit_assert=>assert_equals( act = lv_count exp = 1 msg = 'One snapshot deleted' ).
        cl_abap_unit_assert=>assert_equals( act = lv_dependent exp = 2 msg = 'Its group and line' ).
        SELECT snap_id FROM zca_ops_brkrun ORDER BY snap_id INTO TABLE @DATA(lt_left).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_left ) exp = 2 msg = 'Latest snapshots kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
