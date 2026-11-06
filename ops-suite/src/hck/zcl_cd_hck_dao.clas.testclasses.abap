*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_dao.clas.testclasses.abap
*& Purpose:
*& SQL tests of the HCK DAO on cl_osql_test_environment doubles: metric
*& history and overdue exceptions; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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

    METHODS add_metric
      IMPORTING
        iv_run_no   TYPE i
        iv_dim1     TYPE zif_cd_hck_types=>ty_dim
        iv_value    TYPE zif_cd_hck_types=>ty_value
        iv_at       TYPE timestampl.

    METHODS add_finding
      IMPORTING
        iv_no          TYPE i
        iv_module      TYPE zif_cd_ops_types=>ty_module
        iv_disposition TYPE zif_cd_hck_types=>ty_disposition
        iv_due         TYPE d.

ENDCLASS.



CLASS ltc_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCD_HCK_METRIC' )
                                                                            ( 'ZCD_OPS_FINDING' ) ) ).
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
    ls_row-module      = iv_module.
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


  " Rule: overdue = disposition O or A with due date before today, counted per module
  METHOD overdue_open_and_assigned.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_overdue.
    TRY.
        add_finding( iv_no = 1 iv_module = 'EBS'  iv_disposition = 'O' iv_due = '20261101' ).
        add_finding( iv_no = 2 iv_module = 'EBS'  iv_disposition = 'A' iv_due = '20261103' ).
        add_finding( iv_no = 3 iv_module = 'EBS'  iv_disposition = 'R' iv_due = '20261101' ).
        add_finding( iv_no = 4 iv_module = 'FMON' iv_disposition = 'O' iv_due = '20261110' ).
        add_finding( iv_no = 5 iv_module = 'FMON' iv_disposition = 'I' iv_due = '00000000' ).
        go_env->insert_test_data( mt_findings ).
        INSERT VALUE #( module = 'EBS' item_count = 2 oldest_due = '20261101' ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_overdue_exceptions( gc_today )
                                            exp = lt_exp
                                            msg = 'Only open/assigned EBS items past due count' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
