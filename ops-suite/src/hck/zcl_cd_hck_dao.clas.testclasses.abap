*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_dao.clas.testclasses.abap
*& Purpose:
*& SQL tests of the HCK DAO on cl_osql_test_environment doubles: metric
*& history and overdue exceptions; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | only_active_suppressions (design 6.3).
*&---------------------------------------------------------------------*
CLASS ltc_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check  TYPE zif_cd_hck_types=>ty_check_id VALUE 'B_JOB_RUNTIME',
      gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'DURATION_MIN',
      gc_job    TYPE zif_cd_hck_types=>ty_dim VALUE 'ZCD_PAYM_WIRE_CORP',
      gc_other  TYPE zif_cd_hck_types=>ty_dim VALUE 'ZCD_POST_GL',
      gc_today  TYPE d VALUE '20261105'.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_hck_dao.
    DATA mt_metrics TYPE STANDARD TABLE OF zcd_hck_metric WITH EMPTY KEY.
    DATA mt_findings TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS history_newest_first_capped FOR TESTING.
    METHODS history_only_same_dimension FOR TESTING.
    METHODS saved_metric_is_read_back FOR TESTING.
    METHODS overdue_open_and_assigned FOR TESTING.
    METHODS only_active_suppressions FOR TESTING.

    METHODS add_metric
      IMPORTING
        iv_run_no   TYPE i
        iv_dim1     TYPE zif_cd_hck_types=>ty_dim
        iv_value    TYPE zif_cd_hck_types=>ty_value
        iv_at       TYPE timestampl.

    METHODS add_finding
      IMPORTING
        iv_no          TYPE i
        iv_pe_area      TYPE zif_cd_ops_types=>ty_pe_area
        iv_disposition TYPE zif_cd_hck_types=>ty_disposition
        iv_due         TYPE d.

ENDCLASS.



CLASS ltc_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCD_HCK_METRIC' )
                                                                            ( 'ZCD_OPS_FINDING' )
                                                                            ( 'ZCD_HCK_SUPPRESS' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    CLEAR: mt_metrics, mt_findings.
    mo_cut = zcl_cd_hck_factory=>get_dao( ).
  ENDMETHOD.


  METHOD add_metric.
    DATA ls_row TYPE zcd_hck_metric.
    DATA lv_run_byte TYPE x LENGTH 1.
    lv_run_byte        = iv_run_no.
    ls_row-run_id      = lv_run_byte.
    ls_row-check_id    = gc_check.
    ls_row-metric      = gc_metric.
    ls_row-dim1        = iv_dim1.
    ls_row-value       = iv_value.
    ls_row-measured_at = iv_at.
    INSERT ls_row INTO TABLE mt_metrics.
  ENDMETHOD.


  METHOD add_finding.
    DATA ls_row TYPE zcd_ops_finding.
    ls_row-run_id      = '0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A'.
    ls_row-finding_no  = iv_no.
    ls_row-pe_area      = iv_pe_area.
    ls_row-severity    = zif_cd_ops_types=>gc_severity-error.
    ls_row-disposition = iv_disposition.
    ls_row-due_date    = iv_due.
    INSERT ls_row INTO TABLE mt_findings.
  ENDMETHOD.


  " Rule: history is newest first and capped at the lookback
  METHOD history_newest_first_capped.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_value.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        add_metric( iv_run_no = 1 iv_dim1 = gc_job iv_value = 10 iv_at = '20261102070000.0000000' ).
        add_metric( iv_run_no = 2 iv_dim1 = gc_job iv_value = 20 iv_at = '20261103070000.0000000' ).
        add_metric( iv_run_no = 3 iv_dim1 = gc_job iv_value = 30 iv_at = '20261104070000.0000000' ).
        go_env->insert_test_data( mt_metrics ).
        lv_value = 30.
        INSERT lv_value INTO TABLE lt_exp.
        lv_value = 20.
        INSERT lv_value INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_metric_history( iv_check_id = gc_check
                                                                              iv_metric   = gc_metric
                                                                              iv_dim1     = gc_job
                                                                              iv_max_rows = 2 )
                                            exp = lt_exp
                                            msg = 'Two newest values, newest first' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a baseline only uses history of the same dimension (job, company code, source)
  METHOD history_only_same_dimension.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_value.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        add_metric( iv_run_no = 1 iv_dim1 = gc_job iv_value = 10 iv_at = '20261102070000.0000000' ).
        add_metric( iv_run_no = 1 iv_dim1 = gc_other iv_value = 99 iv_at = '20261102070000.0000000' ).
        go_env->insert_test_data( mt_metrics ).
        lv_value = 10.
        INSERT lv_value INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_metric_history( iv_check_id = gc_check
                                                                              iv_metric   = gc_metric
                                                                              iv_dim1     = gc_job
                                                                              iv_max_rows = 8 )
                                            exp = lt_exp
                                            msg = 'Other job must not leak into the history' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: saved metrics become history (round trip through ZCD_HCK_METRIC)
  METHOD saved_metric_is_read_back.
    DATA lt_metrics TYPE zif_cd_hck_types=>tt_metric_hist.
    DATA ls_metric TYPE zif_cd_hck_types=>ty_metric_hist.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_value.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        ls_metric-run_id      = '0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B'.
        ls_metric-check_id    = gc_check.
        ls_metric-metric      = gc_metric.
        ls_metric-dim1        = gc_job.
        ls_metric-dim2        = '13300001'.
        ls_metric-value       = '42.5'.
        ls_metric-measured_at = '20261105070000.0000000'.
        INSERT ls_metric INTO TABLE lt_metrics.
        mo_cut->save_metrics( lt_metrics ).
        lv_value = '42.5'.
        INSERT lv_value INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_metric_history( iv_check_id = gc_check
                                                                              iv_metric   = gc_metric
                                                                              iv_dim1     = gc_job
                                                                              iv_max_rows = 8 )
                                            exp = lt_exp
                                            msg = 'Saved metric must be read back' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: overdue = disposition O or A with due date before today, counted per payment engine area
  METHOD overdue_open_and_assigned.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_overdue.
    TRY.
        add_finding( iv_no = 1 iv_pe_area = 'EBS'  iv_disposition = 'O' iv_due = '20261101' ).
        add_finding( iv_no = 2 iv_pe_area = 'EBS'  iv_disposition = 'A' iv_due = '20261103' ).
        add_finding( iv_no = 3 iv_pe_area = 'EBS'  iv_disposition = 'R' iv_due = '20261101' ).
        add_finding( iv_no = 4 iv_pe_area = 'FMON' iv_disposition = 'O' iv_due = '20261110' ).
        add_finding( iv_no = 5 iv_pe_area = 'FMON' iv_disposition = 'I' iv_due = '00000000' ).
        go_env->insert_test_data( mt_findings ).
        INSERT VALUE #( pe_area = 'EBS' item_count = 2 oldest_due = '20261101' ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_overdue_exceptions( gc_today )
                                            exp = lt_exp
                                            msg = 'Only open/assigned EBS items past due count' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (design 6.3): only active suppressions valid today are read - pending and expired are not
  METHOD only_active_suppressions.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_hck_suppress WITH EMPTY KEY.
    DATA ls_row TYPE zcd_hck_suppress.
    TRY.
        ls_row-suppress_uuid = '000000000000000000000000000000C1'.
        ls_row-check_id      = 'HCK_C04'.
        ls_row-valid_from    = '20261101'.
        ls_row-valid_to      = '20261110'.
        ls_row-status        = zif_cd_hck_suppress_types=>gc_status-active.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-suppress_uuid = '000000000000000000000000000000C2'.
        ls_row-status        = zif_cd_hck_suppress_types=>gc_status-requested.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-suppress_uuid = '000000000000000000000000000000C3'.
        ls_row-status        = zif_cd_hck_suppress_types=>gc_status-active.
        ls_row-valid_to      = '20261105'.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_active) = mo_cut->get_suppressions( '20261106' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_active ) exp = 1
                                            msg = 'Only the active suppression valid today must be read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_active[ 1 ]-suppress_uuid exp = '000000000000000000000000000000C1'
                                            msg = 'The active suppression must be the one read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
