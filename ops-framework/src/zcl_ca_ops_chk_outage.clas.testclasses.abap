*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_outage.clas.testclasses.abap
*& Purpose:
*& Tests of the outage check through ZIF_CA_OPS_CHECK~RUN with doubles of
*& the check registry data access, the downtime API and the parameters: an
*& ended window measures every row in the window (a row with a time field
*& exactly, one without it on the window's days plus the margin), rows at or
*& above the limits are findings per window and company code, below nothing,
*& a window still running is not measured yet, a row that cannot be measured
*& is AGG_CONFIG_INVALID, the check is always partial (never auto-resolved)
*& and a check without rows raises 092. No database; does not prove live
*& SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue: generic risk checks).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check_dao PARTIALLY IMPLEMENTED.
    DATA mt_aggs TYPE zif_ca_ops_chk_types=>tt_agg.
    DATA mt_rows TYPE zif_ca_ops_chk_types=>tt_agg_row.
    DATA mt_windows TYPE STANDARD TABLE OF zif_ca_ops_chk_types=>ty_window WITH EMPTY KEY.
    DATA mv_broken TYPE zif_ca_ops_chk_types=>ty_agg_id.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_check_dao~get_aggregates.
    rt_aggs = mt_aggs.
  ENDMETHOD.
  METHOD zif_ca_ops_check_dao~aggregate.
    INSERT is_window INTO TABLE mt_windows.
    IF is_agg-agg_id = mv_broken.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e255(zca_ops) WITH is_agg-agg_id is_agg-time_field is_agg-tabname.
    ENDIF.
    rt_rows = mt_rows.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_downtime DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_downtime PARTIALLY IMPLEMENTED.
    DATA mt_windows TYPE zif_ca_ops_resp_types=>tt_window.
    DATA mv_area TYPE zif_ca_ops_types=>ty_area.
    DATA mv_approved_only TYPE abap_bool.
ENDCLASS.

CLASS ltd_downtime IMPLEMENTATION.
  METHOD zif_ca_ops_downtime~windows.
    mv_area = iv_area.
    mv_approved_only = iv_approved_only.
    rt_windows = mt_windows.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_outage DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        check_id  TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_OUTAGE',
        posted    TYPE zif_ca_ops_chk_types=>ty_agg_id VALUE 'OUT_POST',
        open_keys TYPE zif_ca_ops_chk_types=>ty_agg_id VALUE 'OUT_GL',
        table     TYPE zif_ca_ops_chk_types=>ty_tabname VALUE 'ZT_DOCUMENT',
        time      TYPE zif_ca_ops_chk_types=>ty_fieldname VALUE 'ENTRY_TIME',
        today     TYPE d VALUE '20261111',
        now       TYPE timestampl VALUE '20261111070000.0000000',
        from_date TYPE d VALUE '20261108',
        from_time TYPE t VALUE '220000',
        to_date   TYPE d VALUE '20261109',
        to_time   TYPE t VALUE '020000',
        ended     TYPE timestampl VALUE '20261109020000.0000000',
        running   TYPE timestampl VALUE '20261111090000.0000000',
        company   TYPE bukrs VALUE '1000',
        margin    TYPE i VALUE 1,
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_downtime TYPE REF TO ltd_downtime.

    METHODS setup.
    METHODS teardown.
    METHODS given_agg
      IMPORTING
        iv_agg_id     TYPE zif_ca_ops_chk_types=>ty_agg_id
        iv_time_field TYPE zif_ca_ops_chk_types=>ty_fieldname OPTIONAL.
    METHODS given_window
      IMPORTING
        iv_to_utc TYPE timestampl.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.

    METHODS posting_in_window_is_finding FOR TESTING.
    METHODS no_time_field_adds_margin    FOR TESTING.
    METHODS below_limits_no_finding      FOR TESTING.
    METHODS running_window_not_measured  FOR TESTING.
    METHODS broken_row_is_reported       FOR TESTING.
    METHODS no_rows_raises_092           FOR TESTING.
ENDCLASS.


CLASS ltc_chk_outage IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_downtime = NEW #( ).
    zcl_ca_ops_injector=>inject_check_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_downtime( mo_downtime ).
    zcl_ca_ops_injector=>inject_params( NEW zcl_ca_ops_param_seed( )->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD given_agg.
    DATA ls_agg TYPE zif_ca_ops_chk_types=>ty_agg.
    ls_agg-area       = gc-area.
    ls_agg-check_id   = gc-check_id.
    ls_agg-agg_id     = iv_agg_id.
    ls_agg-tabname    = gc-table.
    ls_agg-agg_func   = zif_ca_ops_chk_types=>gc_agg_func-count.
    ls_agg-time_field = iv_time_field.
    ls_agg-amber      = 1.
    ls_agg-red        = 10.
    ls_agg-active     = abap_true.
    INSERT ls_agg INTO TABLE mo_dao->mt_aggs.
  ENDMETHOD.


  METHOD given_window.
    DATA ls_window TYPE zif_ca_ops_resp_types=>ty_window.
    ls_window-area      = gc-area.
    ls_window-from_date = gc-from_date.
    ls_window-from_time = gc-from_time.
    ls_window-to_date   = gc-to_date.
    ls_window-to_time   = gc-to_time.
    ls_window-to_utc    = iv_to_utc.
    INSERT ls_window INTO TABLE mo_downtime->mt_windows.
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_outage( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = gc-area check_id = gc-check_id bukrs_aware = abap_true )
                  is_context = VALUE #( area = gc-area today = gc-today now = gc-now ) ).
  ENDMETHOD.


  " Rule: rows posted inside an ended window (date and time) at or above a limit are a finding per window
  METHOD posting_in_window_is_finding.
    TRY.
        given_agg( iv_agg_id = gc-posted iv_time_field = gc-time ).
        given_window( gc-ended ).
        INSERT VALUE #( company_code = gc-company row_count = 12 ) INTO TABLE mo_dao->mt_rows.
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One finding' ).
        DATA(ls_finding) = ls_result-findings[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'At or above red: error' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code exp = zif_ca_ops_cat_types=>gc_code-outage_rows
                                            msg = 'Default check code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-company_code exp = gc-company msg = 'Per company code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-business_date exp = gc-from_date msg = 'Day of the window' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_windows[ 1 ]
                                            exp = VALUE zif_ca_ops_chk_types=>ty_window(
                                                        from_date = gc-from_date from_time = gc-from_time
                                                        to_date   = gc-to_date   to_time   = gc-to_time )
                                            msg = 'Measured exactly in the window' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-partial msg = 'Never auto-resolved' ).
        cl_abap_unit_assert=>assert_equals( act = mo_downtime->mv_area exp = gc-area msg = 'Windows of the area' ).
        cl_abap_unit_assert=>assert_true( act = mo_downtime->mv_approved_only msg = 'Approved windows only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a row without a time field covers the window's days plus the margin (G/L transfer around the outage)
  METHOD no_time_field_adds_margin.
    TRY.
        given_agg( gc-open_keys ).
        given_window( gc-ended ).
        run( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_windows[ 1 ]-to_date exp = CONV d( gc-to_date + gc-margin )
                                            msg = 'Window days plus CAT_OUTAGE_MARGIN_DAYS (default 1)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD below_limits_no_finding.
    TRY.
        given_agg( iv_agg_id = gc-posted iv_time_field = gc-time ).
        given_window( gc-ended ).
        INSERT VALUE #( company_code = gc-company row_count = 0 ) INTO TABLE mo_dao->mt_rows.
        cl_abap_unit_assert=>assert_initial( act = run( )-findings msg = 'Nothing posted in the window' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a window that has not ended is measured after its end
  METHOD running_window_not_measured.
    TRY.
        given_agg( iv_agg_id = gc-posted iv_time_field = gc-time ).
        given_window( gc-running ).
        INSERT VALUE #( company_code = gc-company row_count = 12 ) INTO TABLE mo_dao->mt_rows.
        cl_abap_unit_assert=>assert_initial( act = run( )-findings msg = 'Not measured while it runs' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_windows msg = 'No aggregate read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD broken_row_is_reported.
    TRY.
        given_agg( iv_agg_id = gc-posted iv_time_field = gc-time ).
        given_window( gc-ended ).
        mo_dao->mv_broken = gc-posted.
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_ca_ops_chk_types=>gc_code-agg_invalid
                                            msg = 'A row that cannot be measured is reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD no_rows_raises_092.
    TRY.
        run( ).
        cl_abap_unit_assert=>fail( msg = 'A check without aggregate rows raises' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '092'
                                            msg = 'Message 092' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
