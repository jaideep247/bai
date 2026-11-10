*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_agg.clas.testclasses.abap
*& Purpose:
*& Tests of the no-code aggregate check through ZIF_CA_OPS_CHECK~RUN with a
*& data access double: result rows become findings by the row limits, the
*& company-code awareness of the check reaches the aggregate, a row that
*& cannot be measured is AGG_CONFIG_INVALID and makes the check partial while
*& the other rows are measured, and a check without rows raises 092. No
*& database; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check_dao PARTIALLY IMPLEMENTED.
    DATA mt_aggs TYPE zif_ca_ops_chk_types=>tt_agg.
    DATA mt_rows TYPE zif_ca_ops_chk_types=>tt_agg_row.
    "! Aggregate ID whose read fails (configuration error)
    DATA mv_broken TYPE zif_ca_ops_chk_types=>ty_agg_id.
    DATA mv_bukrs_aware TYPE abap_bool.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_check_dao~get_aggregates.
    rt_aggs = mt_aggs.
  ENDMETHOD.
  METHOD zif_ca_ops_check_dao~aggregate.
    mv_bukrs_aware = iv_bukrs_aware.
    IF is_agg-agg_id = mv_broken.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e086(zca_ops) WITH is_agg-tabname is_agg-area.
    ENDIF.
    rt_rows = mt_rows.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_agg DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        check_id TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_PENDING',
        first    TYPE zif_ca_ops_chk_types=>ty_agg_id VALUE 'R1',
        second   TYPE zif_ca_ops_chk_types=>ty_agg_id VALUE 'R2',
        table    TYPE zif_ca_ops_chk_types=>ty_tabname VALUE 'ZT_REQUEST',
        today    TYPE d VALUE '20261110',
        company  TYPE bukrs VALUE '1000',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_dao.

    METHODS setup.
    METHODS teardown.
    METHODS given_agg
      IMPORTING
        iv_agg_id TYPE zif_ca_ops_chk_types=>ty_agg_id.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.

    METHODS rows_become_findings        FOR TESTING.
    METHODS broken_row_makes_partial    FOR TESTING.
    METHODS no_rows_raises_092          FOR TESTING.
ENDCLASS.


CLASS ltc_chk_agg IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_ca_ops_injector=>inject_check_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD given_agg.
    DATA ls_agg TYPE zif_ca_ops_chk_types=>ty_agg.
    ls_agg-area         = gc-area.
    ls_agg-check_id     = gc-check_id.
    ls_agg-agg_id       = iv_agg_id.
    ls_agg-tabname      = gc-table.
    ls_agg-agg_func     = zif_ca_ops_chk_types=>gc_agg_func-count.
    ls_agg-amber        = 1.
    ls_agg-red          = 5.
    ls_agg-active       = abap_true.
    INSERT ls_agg INTO TABLE mo_dao->mt_aggs.
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_agg( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = gc-area check_id = gc-check_id bukrs_aware = abap_true )
                  is_context = VALUE #( area = gc-area today = gc-today ) ).
  ENDMETHOD.


  " Rule: a result at a limit is a finding with its company code; the check is complete
  METHOD rows_become_findings.
    TRY.
        given_agg( gc-first ).
        INSERT VALUE #( company_code = gc-company row_count = 6 ) INTO TABLE mo_dao->mt_rows.
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-company_code exp = gc-company
                                            msg = 'Company code of the result row' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'Red limit reached' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-partial msg = 'Complete' ).
        cl_abap_unit_assert=>assert_true( act = mo_dao->mv_bukrs_aware msg = 'Company-code awareness passed on' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a row that cannot be measured is AGG_CONFIG_INVALID; the check is partial; other rows still run
  METHOD broken_row_makes_partial.
    TRY.
        given_agg( gc-first ).
        given_agg( gc-second ).
        mo_dao->mv_broken = gc-first.
        INSERT VALUE #( company_code = gc-company row_count = 2 ) INTO TABLE mo_dao->mt_rows.
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-partial msg = 'Partial' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ rule_id = gc-first ]-check_code
                                            exp = zif_ca_ops_chk_types=>gc_code-agg_invalid
                                            msg = 'Broken row reported' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ rule_id = gc-second ]-severity
                                            exp = zif_ca_ops_types=>gc_severity-warning
                                            msg = 'The other row measured (amber)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a registered aggregate check without an active row is a configuration error (092)
  METHOD no_rows_raises_092.
    TRY.
        run( ).
        cl_abap_unit_assert=>fail( msg = 'A check without rows must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '092' msg = 'Message 092' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
