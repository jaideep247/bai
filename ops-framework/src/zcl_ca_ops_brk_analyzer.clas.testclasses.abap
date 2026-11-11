*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_analyzer.clas.testclasses.abap
*& Purpose:
*& Tests of the break analysis through its public seam ANALYZE( ): a
*& snapshot per account saved and committed (groups, lines, counts, status,
*& configuration version), test mode writes nothing, an account of a
*& business process not in effect is skipped, the group cap makes the
*& snapshot partial, the lines are read package by package with the group
*& numbers continued, another rule is another configuration version, the
*& linked objects are read only for LINK conditions, the authorisation is
*& checked. Every dependency is a local double (data access, linked objects,
*& catalogue, authorisation, clock; parameters in memory); no test reads or
*& writes the database. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
CLASS ltd_brk_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_brk_dao.
    DATA mt_accounts TYPE zif_ca_ops_brk_types=>tt_account.
    DATA mt_buckets TYPE zif_ca_ops_brk_types=>tt_bucket.
    DATA mt_rules TYPE zif_ca_ops_brk_types=>tt_rule.
    DATA mt_conds TYPE zif_ca_ops_brk_types=>tt_cond.
    DATA mt_sums TYPE zif_ca_ops_brk_types=>tt_group_sum.
    DATA mt_items TYPE zif_ca_ops_brk_types=>tt_item.
    DATA mt_saved TYPE zif_ca_ops_brk_types=>tt_snapshot.
    DATA mt_groups TYPE zif_ca_ops_brk_types=>tt_group.
    DATA mv_commits TYPE i.
    DATA mv_group_reads TYPE i.
    DATA mv_line_reads TYPE i.
ENDCLASS.

CLASS ltd_brk_dao IMPLEMENTATION.
  METHOD zif_ca_ops_brk_dao~get_accounts.
    rt_accounts = mt_accounts.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~get_buckets.
    rt_buckets = mt_buckets.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~get_rules.
    rt_rules = mt_rules.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~get_conds.
    rt_conds = mt_conds.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~open_groups.
    mv_group_reads += 1.
    LOOP AT mt_sums ASSIGNING FIELD-SYMBOL(<ls_sum>).
      IF lines( rt_sums ) >= iv_max.
        EXIT.
      ENDIF.
      INSERT <ls_sum> INTO TABLE rt_sums.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~group_lines.
    mv_line_reads += 1.
    LOOP AT mt_items ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE assignment IN it_assignments.
      INSERT <ls_item> INTO TABLE rt_items.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~save_snapshot.
    INSERT is_snapshot INTO TABLE mt_saved.
    INSERT LINES OF it_groups INTO TABLE mt_groups.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~latest_snapshot.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~open_breaks.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~count_open_breaks.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~commit.
    mv_commits += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_brk_links DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_brk_links.
    DATA mt_links TYPE zif_ca_ops_link_types=>tt_link_id.
    DATA mv_reads TYPE i.
ENDCLASS.

CLASS ltd_brk_links IMPLEMENTATION.
  METHOD zif_ca_ops_brk_links~effective_links.
    rt_links = mt_links.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_links~read.
    CLEAR: et_hits, et_problems.
    mv_reads += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_brk_catalog DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_catalog PARTIALLY IMPLEMENTED.
    DATA mt_off TYPE zif_ca_ops_cat_types=>tt_process_ids.
ENDCLASS.

CLASS ltd_brk_catalog IMPLEMENTATION.
  METHOD zif_ca_ops_catalog~inactive_onboarded.
    rt_processes = mt_off.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_brk_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_allowed TYPE abap_bool VALUE abap_true.
ENDCLASS.

CLASS ltd_brk_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~check.
    IF mv_allowed = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e041(zca_ops) WITH zif_ca_ops_auth=>gc_object iv_activity.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_brk_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_brk_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261102060000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261102'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '060000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_brk_analyzer DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        acct     TYPE zif_ca_ops_brk_types=>ty_acct_id VALUE 'ZT_CLEARING',
        process  TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_GL_CLEAR',
        key_date TYPE d VALUE '20261031',
        timing   TYPE zif_ca_ops_brk_types=>ty_bucket VALUE 'TIMING',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_brk_dao.
    DATA mo_links TYPE REF TO ltd_brk_links.
    DATA mo_catalog TYPE REF TO ltd_brk_catalog.
    DATA mo_auth TYPE REF TO ltd_brk_auth.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS given_account_with_breaks.
    METHODS analyze
      IMPORTING
        iv_test_mode      TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rt_results) TYPE zif_ca_ops_brk_types=>tt_analysis
      RAISING
        zcx_ca_ops_error.

    METHODS snapshot_saved_per_account  FOR TESTING.
    METHODS test_mode_writes_nothing    FOR TESTING.
    METHODS inactive_process_skipped    FOR TESTING.
    METHODS group_cap_makes_partial     FOR TESTING.
    METHODS lines_read_per_package      FOR TESTING.
    METHODS changed_rule_new_version    FOR TESTING.
    METHODS links_only_for_link_rules   FOR TESTING.
    METHODS not_authorised_raises       FOR TESTING.
ENDCLASS.


CLASS ltc_brk_analyzer IMPLEMENTATION.

  METHOD setup.
    mo_dao     = NEW #( ).
    mo_links   = NEW #( ).
    mo_catalog = NEW #( ).
    mo_auth    = NEW #( ).
    mo_seed    = NEW #( ).
    zcl_ca_ops_injector=>inject_brk_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_catalog( mo_catalog ).
    zcl_ca_ops_injector=>inject_auth( mo_auth ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_brk_clock( ) ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  " One account; group A1 is cleared two days after the key date (timing), group A2 nothing explains
  METHOD given_account_with_breaks.
    DATA ls_item TYPE zif_ca_ops_brk_types=>ty_item.
    INSERT VALUE #( area = gc-area acct_id = gc-acct bukrs = 'ZT01' hkont = '0000199999' process_id = gc-process
                    active = abap_true ) INTO TABLE mo_dao->mt_accounts.
    mo_dao->mt_buckets = VALUE #( ( bucket = gc-timing explained = abap_true active = abap_true )
                                  ( bucket = zif_ca_ops_brk_types=>gc_bucket_other active = abap_true ) ).
    INSERT VALUE #( area = zif_ca_ops_brk_types=>gc_area_any rule_id = 'S4_TIMING' seq = 10 bucket = gc-timing
                    active = abap_true ) INTO TABLE mo_dao->mt_rules.
    INSERT VALUE #( area = zif_ca_ops_brk_types=>gc_area_any rule_id = 'S4_TIMING' cond_no = 1
                    cond_kind = zif_ca_ops_brk_types=>gc_kind-group field = zif_ca_ops_brk_types=>gc_group-clears_later
                    operator = zif_ca_ops_brk_types=>gc_op-eq cond_value = 'X' ) INTO TABLE mo_dao->mt_conds.
    mo_dao->mt_sums = VALUE #( ( assignment = 'A1' currency = 'USD' amount = 100 line_count = 1 first_date = '20261030' )
                               ( assignment = 'A2' currency = 'USD' amount = 50 line_count = 1 first_date = '20261001' ) ).
    ls_item-ledger       = '0L'.
    ls_item-bukrs        = 'ZT01'.
    ls_item-gjahr        = '2026'.
    ls_item-belnr        = '0100000001'.
    ls_item-docln        = '000001'.
    ls_item-assignment   = 'A1'.
    ls_item-currency     = 'USD'.
    ls_item-amount       = 100.
    ls_item-posting_date = '20261030'.
    INSERT ls_item INTO TABLE mo_dao->mt_items.
    ls_item-docln        = '000002'.
    ls_item-amount       = -100.
    ls_item-posting_date = '20261102'.
    ls_item-later        = abap_true.
    INSERT ls_item INTO TABLE mo_dao->mt_items.
    ls_item-belnr        = '0100000002'.
    ls_item-docln        = '000001'.
    ls_item-assignment   = 'A2'.
    ls_item-amount       = 50.
    ls_item-posting_date = '20261001'.
    ls_item-later        = abap_false.
    INSERT ls_item INTO TABLE mo_dao->mt_items.
  ENDMETHOD.


  METHOD analyze.
    rt_results = NEW zcl_ca_ops_brk_analyzer( mo_links )->analyze( iv_area      = gc-area
                                                                     iv_key_date  = gc-key_date
                                                                     iv_test_mode = iv_test_mode ).
  ENDMETHOD.


  " Rule: one snapshot per account with its groups, counts and version, saved and committed per account
  METHOD snapshot_saved_per_account.
    TRY.
        given_account_with_breaks( ).
        DATA(lt_results) = analyze( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_saved ) exp = 1 msg = 'One snapshot' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_commits exp = 1 msg = 'Committed per account' ).
        DATA(ls_snapshot) = mo_dao->mt_saved[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_snapshot-group_count exp = 2 msg = 'Two groups' ).
        cl_abap_unit_assert=>assert_equals( act = ls_snapshot-other_count exp = 1 msg = 'One unexplained' ).
        cl_abap_unit_assert=>assert_equals( act = ls_snapshot-status exp = zif_ca_ops_brk_types=>gc_status-complete
                                            msg = 'Complete' ).
        cl_abap_unit_assert=>assert_equals( act = strlen( ls_snapshot-cfg_version ) exp = 40 msg = 'Versioned' ).
        cl_abap_unit_assert=>assert_equals( act = ls_snapshot-from_date exp = CONV d( gc-key_date - 62 )
                                            msg = 'Default look-back' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_groups[ assignment = 'A1' ]-bucket exp = gc-timing
                                            msg = 'Cleared after the key date: timing' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_results ) exp = 1 msg = 'One result' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: test mode classifies but writes and commits nothing
  METHOD test_mode_writes_nothing.
    TRY.
        given_account_with_breaks( ).
        DATA(lt_results) = analyze( iv_test_mode = abap_true ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_saved msg = 'Nothing saved' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_commits exp = 0 msg = 'No commit' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_results[ 1 ]-groups ) exp = 2 msg = 'Classified' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the process catalogue decides - an account of a process not in effect is not read
  METHOD inactive_process_skipped.
    TRY.
        given_account_with_breaks( ).
        INSERT gc-process INTO TABLE mo_catalog->mt_off.
        DATA(lt_results) = analyze( ).
        cl_abap_unit_assert=>assert_true( act = lt_results[ 1 ]-skipped msg = 'Skipped' ).
        cl_abap_unit_assert=>assert_equals( act = lt_results[ 1 ]-problems[ 1 ]-msgno
                                            exp = zif_ca_ops_brk_types=>gc_msg-process_off msg = 'Reason 290' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_group_reads exp = 0 msg = 'Journal not read' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_saved msg = 'Nothing saved' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a result at the group cap is partial - never silently complete
  METHOD group_cap_makes_partial.
    TRY.
        given_account_with_breaks( ).
        mo_dao->mt_accounts[ 1 ]-max_groups = 1.
        analyze( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-status exp = zif_ca_ops_brk_types=>gc_status-partial
                                            msg = 'Partial' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-group_count exp = 1 msg = 'Oldest group only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: lines are read package by package (BRK_PACKAGE_SIZE assignments); group numbers continue
  METHOD lines_read_per_package.
    TRY.
        given_account_with_breaks( ).
        mo_seed->set( iv_name = zif_ca_ops_brk_types=>gc_param-package iv_value = '1' ).
        analyze( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_line_reads exp = 2 msg = 'One read per package' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_groups[ 2 ]-group_no exp = 2 msg = 'Numbers continue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the snapshot records the configuration version - another rule value, another version
  METHOD changed_rule_new_version.
    TRY.
        given_account_with_breaks( ).
        analyze( iv_test_mode = abap_true ).
        DATA(lt_first) = analyze( iv_test_mode = abap_true ).
        mo_dao->mt_rules[ 1 ]-seq = 20.
        DATA(lt_second) = analyze( iv_test_mode = abap_true ).
        cl_abap_unit_assert=>assert_differs( act = lt_second[ 1 ]-snapshot-cfg_version
                                             exp = lt_first[ 1 ]-snapshot-cfg_version msg = 'New version' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: linked objects are read only when an applying rule has a LINK condition
  METHOD links_only_for_link_rules.
    TRY.
        given_account_with_breaks( ).
        analyze( iv_test_mode = abap_true ).
        cl_abap_unit_assert=>assert_equals( act = mo_links->mv_reads exp = 0 msg = 'No LINK condition, no read' ).
        mo_links->mt_links = VALUE #( ( 'ZT_ITEM_TO_LINE' ) ).
        INSERT VALUE #( area = zif_ca_ops_brk_types=>gc_area_any rule_id = 'S4_TIMING' cond_no = 2
                        cond_kind = zif_ca_ops_brk_types=>gc_kind-link operator = zif_ca_ops_brk_types=>gc_op-ex
                        link_id = 'ZT_ITEM_TO_LINE' ) INTO TABLE mo_dao->mt_conds.
        analyze( iv_test_mode = abap_true ).
        cl_abap_unit_assert=>assert_equals( act = mo_links->mv_reads exp = 1 msg = 'One read for the package' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: ZCA_OPS execute for the area before anything is read
  METHOD not_authorised_raises.
    given_account_with_breaks( ).
    mo_auth->mv_allowed = abap_false.
    TRY.
        analyze( ).
        cl_abap_unit_assert=>fail( msg = 'Not authorised: must raise' ).
      CATCH zcx_ca_ops_error.
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_group_reads exp = 0 msg = 'Nothing read' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
