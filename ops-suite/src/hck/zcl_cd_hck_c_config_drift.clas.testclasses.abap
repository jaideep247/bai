*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_config_drift.clas.testclasses.abap
*& Purpose:
*& Unit tests of the configuration drift check: changed hash, missing
*& baseline, other hash version, hash error and exhausted time budget. DAO and
*& clock are test doubles; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-07 | Production-maintainable table changed: information CONFIG_CHANGED_IN_PROD, no drift.
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_tables TYPE zif_cd_hck_types=>tt_drift_def.
    DATA mt_baselines TYPE zif_cd_hck_types=>tt_baseline.
    DATA mt_current TYPE zif_cd_hck_types=>tt_baseline.
    DATA mv_hash_calls TYPE i.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_drift_tables.
    rt_tables = mt_tables.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_baselines.
    rt_baselines = mt_baselines.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~compute_table_hash.
    mv_hash_calls = mv_hash_calls + 1.
    READ TABLE mt_current INTO rs_hash WITH KEY by_table COMPONENTS tabname = iv_tabname.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e303(zcd_ops) WITH iv_tabname.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
    CONSTANTS gc_now TYPE timestampl VALUE '20261106070000.0000000'.
    CONSTANTS gc_today TYPE d VALUE '20261106'.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = gc_now.
  ENDMETHOD.

  METHOD zif_cd_ops_clock~today.
    rv_date = gc_today.
  ENDMETHOD.

  METHOD zif_cd_ops_clock~time.
    CLEAR rv_time.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_config_drift DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check     TYPE zif_cd_hck_types=>ty_check_id VALUE 'D_DRIFT',
      gc_table     TYPE zif_cd_hck_types=>ty_tabname VALUE 'ZCD_BTC_MAP',
      gc_prod_tab  TYPE zif_cd_hck_types=>ty_tabname VALUE 'ZCD_FMON_DEADL',
      gc_hash_old  TYPE zif_cd_hck_types=>ty_hash VALUE 'AAAA',
      gc_hash_new  TYPE zif_cd_hck_types=>ty_hash VALUE 'BBBB',
      gc_version_1 TYPE zif_cd_hck_types=>ty_hash_version VALUE '01',
      gc_version_2 TYPE zif_cd_hck_types=>ty_hash_version VALUE '02',
      gc_owner     TYPE syuname VALUE 'CFG_OWNER',
      gc_deadline  TYPE timestampl VALUE '20261106060000.0000000'.

    TYPES:
      BEGIN OF ty_flags,
        baseline    TYPE abap_bool,
        changed     TYPE abap_bool,
        old_version TYPE abap_bool,
        hash_error  TYPE abap_bool,
        exhausted   TYPE abap_bool,
        "! The table is production-maintainable (ZCD_FMON_DEADL)
        prod_table  TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_context TYPE zif_cd_hck_types=>ty_context.

    METHODS setup.
    METHODS teardown.
    METHODS changed_table_is_drift FOR TESTING.
    METHODS same_hash_is_clean FOR TESTING.
    METHODS missing_baseline_is_warning FOR TESTING.
    METHODS other_version_is_outdated FOR TESTING.
    METHODS hash_error_is_error FOR TESTING.
    METHODS exhausted_budget_stops FOR TESTING.
    METHODS prod_change_is_information FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
    METHODS assert_single_finding
      IMPORTING
        is_result   TYPE zif_cd_hck_types=>ty_check_result
        iv_code     TYPE zif_cd_ops_types=>ty_check_code
        iv_severity TYPE zif_cd_ops_types=>ty_severity.
ENDCLASS.


CLASS ltc_config_drift IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    CLEAR ms_context.
    INSERT VALUE #( tabname = gc_table ) INTO TABLE mo_dao->mt_tables.
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_hash TYPE zif_cd_hck_types=>ty_baseline.
    IF is_flags-prod_table = abap_true.
      CLEAR mo_dao->mt_tables.
      INSERT VALUE #( tabname = gc_prod_tab ) INTO TABLE mo_dao->mt_tables.
    ENDIF.
    ls_hash-tabname      = COND #( WHEN is_flags-prod_table = abap_true THEN gc_prod_tab ELSE gc_table ).
    ls_hash-hash         = gc_hash_old.
    ls_hash-row_count    = 1.
    ls_hash-taken_by     = gc_owner.
    ls_hash-hash_version = gc_version_1.
    IF is_flags-baseline = abap_true.
      INSERT ls_hash INTO TABLE mo_dao->mt_baselines.
    ENDIF.
    IF is_flags-changed = abap_true.
      ls_hash-hash      = gc_hash_new.
      ls_hash-row_count = 2.
    ENDIF.
    IF is_flags-old_version = abap_true.
      ls_hash-hash_version = gc_version_2.
    ENDIF.
    IF is_flags-hash_error = abap_false.
      INSERT ls_hash INTO TABLE mo_dao->mt_current.
    ENDIF.
    IF is_flags-exhausted = abap_true.
      ms_context-deadline = gc_deadline.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_config_drift( )->zif_cd_hck_check~execute(
      is_def        = VALUE #( check_id = gc_check )
      it_thresholds = VALUE #( )
      is_context    = ms_context ).
  ENDMETHOD.


  METHOD assert_single_finding.
    cl_abap_unit_assert=>assert_equals( act = lines( is_result-findings ) exp = 1 msg = 'Exactly one finding' ).
    cl_abap_unit_assert=>assert_equals( act = is_result-findings[ 1 ]-check_code exp = iv_code
                                        msg = 'Finding check code' ).
    cl_abap_unit_assert=>assert_equals( act = is_result-findings[ 1 ]-severity exp = iv_severity
                                        msg = 'Finding severity' ).
  ENDMETHOD.


  " Rule: a hash that differs from the golden baseline is CONFIG_DRIFT (error, owned exception)
  METHOD changed_table_is_drift.
    TRY.
        configure_scenario( VALUE #( baseline = abap_true changed = abap_true ) ).
        DATA(ls_result) = act( ).
        assert_single_finding( is_result   = ls_result
                               iv_code     = zif_cd_hck_types=>gc_code-config_drift
                               iv_severity = zif_cd_ops_types=>gc_severity-error ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-reference exp = gc_owner
                                            msg = 'Drift names who took the baseline' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 1 msg = 'One drifted table' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the same hash is clean - no finding, DRIFTED_TABLES = 0
  METHOD same_hash_is_clean.
    TRY.
        configure_scenario( VALUE #( baseline = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No drift' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-metric
                                            exp = zcl_cd_hck_c_config_drift=>gc_metric
                                            msg = 'DRIFTED_TABLES measured' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 0 msg = 'Zero drifted tables' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a controlled table without baseline is a warning, not drift
  METHOD missing_baseline_is_warning.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = act( ).
        assert_single_finding( is_result   = ls_result
                               iv_code     = zif_cd_hck_types=>gc_code-no_baseline
                               iv_severity = zif_cd_ops_types=>gc_severity-warning ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A57): a baseline of another hash version is retaken, never compared (no false drift)
  METHOD other_version_is_outdated.
    TRY.
        configure_scenario( VALUE #( baseline = abap_true changed = abap_true old_version = abap_true ) ).
        DATA(ls_result) = act( ).
        assert_single_finding( is_result   = ls_result
                               iv_code     = zif_cd_hck_types=>gc_code-baseline_outdated
                               iv_severity = zif_cd_ops_types=>gc_severity-warning ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 0
                                            msg = 'Outdated baseline is not counted as drift' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a hash that cannot be computed is an error finding; the check goes on
  METHOD hash_error_is_error.
    TRY.
        configure_scenario( VALUE #( baseline = abap_true hash_error = abap_true ) ).
        DATA(ls_result) = act( ).
        assert_single_finding( is_result   = ls_result
                               iv_code     = zif_cd_hck_types=>gc_code-config_drift
                               iv_severity = zif_cd_ops_types=>gc_severity-error ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-action
                                            exp = zif_cd_ops_types=>gc_action-notify
                                            msg = 'Read error is notified, not owned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A18): a passed deadline stops before the next table is hashed
  METHOD exhausted_budget_stops.
    TRY.
        configure_scenario( VALUE #( baseline = abap_true exhausted = abap_true ) ).
        DATA(ls_result) = act( ).
        assert_single_finding( is_result   = ls_result
                               iv_code     = zif_cd_hck_types=>gc_code-budget_exhausted
                               iv_severity = zif_cd_ops_types=>gc_severity-warning ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_hash_calls exp = 0 msg = 'No hash computed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (2026-11-07): a production-maintainable table changed since its baseline is expected
  " production maintenance - information CONFIG_CHANGED_IN_PROD, not drift, metric unchanged
  METHOD prod_change_is_information.
    TRY.
        configure_scenario( VALUE #( baseline = abap_true changed = abap_true prod_table = abap_true ) ).
        DATA(ls_result) = act( ).
        assert_single_finding( is_result   = ls_result
                               iv_code     = zif_cd_hck_types=>gc_code-config_prod_change
                               iv_severity = zif_cd_ops_types=>gc_severity-info ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 0
                                            msg = 'Not counted as a drifted table' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
