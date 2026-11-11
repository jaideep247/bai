*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_break.clas.testclasses.abap
*& Purpose:
*& Tests of the unexplained-break check through ZIF_CA_OPS_CHECK=>RUN: an
*& unexplained group of the latest snapshot is an exception with amount,
*& currency, company code, business date, assignment and the snapshot's
*& configuration version; a missing or stale snapshot is a warning; a
*& partial snapshot makes the check partial; findings beyond
*& BRK_MAX_FINDINGS are summarised (partial); an account of a process not in
*& effect is not checked; the configuration lines carry the snapshot
*& versions. Doubles: data access, catalogue; parameters in memory. Does
*& not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
CLASS ltd_chk_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_brk_dao PARTIALLY IMPLEMENTED.
    DATA mt_accounts TYPE zif_ca_ops_brk_types=>tt_account.
    DATA ms_snapshot TYPE zif_ca_ops_brk_types=>ty_snapshot.
    DATA mt_breaks TYPE zif_ca_ops_brk_types=>tt_open_break.
    DATA mv_min_age TYPE i.
ENDCLASS.

CLASS ltd_chk_dao IMPLEMENTATION.
  METHOD zif_ca_ops_brk_dao~get_accounts.
    rt_accounts = mt_accounts.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~latest_snapshot.
    rs_snapshot = ms_snapshot.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~open_breaks.
    mv_min_age = iv_min_age.
    LOOP AT mt_breaks ASSIGNING FIELD-SYMBOL(<ls_break>) WHERE age_days >= iv_min_age.
      IF lines( rt_breaks ) >= iv_max.
        EXIT.
      ENDIF.
      INSERT <ls_break> INTO TABLE rt_breaks.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_brk_dao~count_open_breaks.
    rv_count = REDUCE i( INIT n = 0 FOR ls IN mt_breaks WHERE ( age_days >= iv_min_age ) NEXT n = n + 1 ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_chk_catalog DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_catalog PARTIALLY IMPLEMENTED.
    DATA mt_off TYPE zif_ca_ops_cat_types=>tt_process_ids.
ENDCLASS.

CLASS ltd_chk_catalog IMPLEMENTATION.
  METHOD zif_ca_ops_catalog~inactive_onboarded.
    rt_processes = mt_off.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_break DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area    TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        acct    TYPE zif_ca_ops_brk_types=>ty_acct_id VALUE 'ZT_CLEARING',
        process TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_GL_CLEAR',
        today   TYPE d VALUE '20261102',
        version TYPE zif_ca_ops_types=>ty_cfg_version VALUE 'ABCDEF0123456789ABCDEF0123456789ABCDEF01',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_chk_dao.
    DATA mo_catalog TYPE REF TO ltd_chk_catalog.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS given_snapshot.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.

    METHODS unexplained_is_exception    FOR TESTING.
    METHODS missing_snapshot_warns      FOR TESTING.
    METHODS partial_snapshot_partial    FOR TESTING.
    METHODS findings_capped_summarised  FOR TESTING.
    METHODS inactive_process_unchecked  FOR TESTING.
    METHODS config_lines_carry_version  FOR TESTING.
ENDCLASS.


CLASS ltc_chk_break IMPLEMENTATION.

  METHOD setup.
    mo_dao     = NEW #( ).
    mo_catalog = NEW #( ).
    mo_seed    = NEW #( ).
    zcl_ca_ops_injector=>inject_brk_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_catalog( mo_catalog ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    INSERT VALUE #( area = gc-area acct_id = gc-acct bukrs = 'ZT01' process_id = gc-process active = abap_true )
           INTO TABLE mo_dao->mt_accounts.
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  " Latest snapshot of yesterday: one break 9 days old, one 2 days old (below BRK_UNEXPLAINED_DAYS 5)
  METHOD given_snapshot.
    mo_dao->ms_snapshot = VALUE #( snap_id = '000000000000000000000000000000B1' area = gc-area acct_id = gc-acct
                                   key_date = '20261101' status = zif_ca_ops_brk_types=>gc_status-complete
                                   cfg_version = gc-version ).
    mo_dao->mt_breaks = VALUE #( ( group_no = 1 assignment = 'A1' currency = 'USD' amount = '125.50'
                                   first_date = '20261023' age_days = 9 line_count = 2 )
                                 ( group_no = 2 assignment = 'A2' currency = 'EUR' amount = 10
                                   first_date = '20261030' age_days = 2 line_count = 1 ) ).
  ENDMETHOD.


  METHOD run.
    rs_result = CAST zif_ca_ops_check( NEW zcl_ca_ops_chk_break( ) )->run(
                  is_check   = VALUE #( area = gc-area check_id = 'ZT_BREAKS' bukrs_aware = abap_true )
                  is_context = VALUE #( area = gc-area today = gc-today ) ).
  ENDMETHOD.


  " Rule: an unexplained group older than BRK_UNEXPLAINED_DAYS is an exception with its amount and evidence
  METHOD unexplained_is_exception.
    TRY.
        given_snapshot( ).
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_min_age exp = 5 msg = 'Default age' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One old break' ).
        DATA(ls_finding) = ls_result-findings[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code exp = zif_ca_ops_brk_types=>gc_code-unexplained
                                            msg = 'Check code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'Exception' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '125.50' msg = 'Amount' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-currency exp = 'USD' msg = 'Currency' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-company_code exp = 'ZT01' msg = 'Company code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-business_date exp = '20261023' msg = 'Oldest line' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-cfg_version exp = gc-version msg = 'Snapshot version' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-cfg_rule exp = zif_ca_ops_brk_types=>gc_bucket_other
                                            msg = 'Bucket OTHER' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'ZT_CLEARING/A1/USD' msg = 'Identity' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-partial msg = 'Complete' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no snapshot (or a stale one) is a warning, not a green check
  METHOD missing_snapshot_warns.
    TRY.
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_ca_ops_brk_types=>gc_code-no_snapshot msg = 'No snapshot' ).
        given_snapshot( ).
        mo_dao->ms_snapshot-key_date = '20261020'.
        ls_result = run( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_ca_ops_brk_types=>gc_code-no_snapshot msg = 'Stale snapshot' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a partial snapshot is reported and the check is partial (nothing unlisted auto-resolved)
  METHOD partial_snapshot_partial.
    TRY.
        given_snapshot( ).
        mo_dao->ms_snapshot-status = zif_ca_ops_brk_types=>gc_status-partial.
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-partial msg = 'Partial' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_ca_ops_brk_types=>gc_code-partial ] ) )
          msg = 'Reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: at most BRK_MAX_FINDINGS breaks per account, the rest in one summary; the check is then partial
  METHOD findings_capped_summarised.
    TRY.
        given_snapshot( ).
        mo_seed->set( iv_name = zif_ca_ops_brk_types=>gc_param-unexplained iv_value = '0' ).
        mo_seed->set( iv_name = zif_ca_ops_brk_types=>gc_param-max_finds iv_value = '1' ).
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 2 msg = 'One break and the summary' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 2 ]-object_type
                                            exp = zif_ca_ops_brk_types=>gc_object_type-account msg = 'Summary' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-partial msg = 'Partial' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an account of a business process not in effect is not checked (process catalogue)
  METHOD inactive_process_unchecked.
    TRY.
        INSERT gc-process INTO TABLE mo_catalog->mt_off.
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-item_count exp = 0 msg = 'Nothing evaluated' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the check's configuration lines carry the version of each account's latest snapshot
  METHOD config_lines_carry_version.
    TRY.
        given_snapshot( ).
        DATA(lt_lines) = CAST zif_ca_ops_check_config( NEW zcl_ca_ops_chk_break( ) )->config_lines(
                           VALUE #( area = gc-area check_id = 'ZT_BREAKS' ) ).
        DATA(lv_found) = abap_false.
        LOOP AT lt_lines INTO DATA(lv_line).
          IF lv_line CS gc-version.
            lv_found = abap_true.
          ENDIF.
        ENDLOOP.
        cl_abap_unit_assert=>assert_true( act = lv_found msg = 'Snapshot version in the lines' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
