*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_dao.clas.testclasses.abap
*& Purpose:
*& SQL tests of the HCK DAO on cl_osql_test_environment doubles: metric
*& history and overdue exceptions; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | only_active_suppressions (design 6.3).
*& 2026-11-06 | History by distinct completed runs, as-of bound (audit A58).
*& 2026-11-06 | job_run_carries_variant, unresolved_jobs_any_date (audit A42, A44).
*& 2026-11-06 | gl_gap_per_company_and_type (audit A43).
*& 2026-11-06 | raw_aggregate_is_rejected, raw_value_query_is_rejected (audit A56).
*& 2026-11-06 | Metric kind and weight round trip (audit A88).
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
    DATA mt_runs TYPE SORTED TABLE OF zcd_ops_run WITH UNIQUE KEY run_id.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS history_newest_first_capped FOR TESTING.
    METHODS history_only_same_dimension FOR TESTING.
    METHODS history_only_same_dim2 FOR TESTING.
    METHODS saved_metric_is_read_back FOR TESTING.
    METHODS metric_kind_and_weight_saved FOR TESTING.
    METHODS overdue_open_and_assigned FOR TESTING.
    METHODS only_active_suppressions FOR TESTING.
    METHODS history_one_point_per_run FOR TESTING.
    METHODS history_skips_unfinished_runs FOR TESTING.
    METHODS history_as_of_excludes_later FOR TESTING.
    METHODS job_run_carries_variant FOR TESTING.
    METHODS unresolved_jobs_any_date FOR TESTING.
    METHODS gl_gap_per_company_and_type FOR TESTING.
    METHODS raw_aggregate_is_rejected FOR TESTING.
    METHODS raw_value_query_is_rejected FOR TESTING.

    METHODS add_metric
      IMPORTING
        iv_run_no   TYPE i
        iv_dim1     TYPE zif_cd_hck_types=>ty_dim
        iv_value    TYPE zif_cd_hck_types=>ty_value
        iv_at       TYPE timestampl
        iv_status   TYPE zif_cd_ops_types=>ty_run_status DEFAULT zif_cd_ops_types=>gc_run_status-success
        iv_dim2     TYPE zif_cd_hck_types=>ty_dim OPTIONAL.

    "! Metric rows and the run headers they belong to
    METHODS insert_history.

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
                                                                            ( 'ZCD_OPS_RUN' )
                                                                            ( 'TBTCO' )
                                                                            ( 'TBTCP' )
                                                                            ( 'DFKKSUMC' )
                                                                            ( 'DFKKKO' )
                                                                            ( 'BKPF' )
                                                                            ( 'ZCD_HCK_TABWL' )
                                                                            ( 'ZCD_HCK_SUPPRESS' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    CLEAR: mt_metrics, mt_findings, mt_runs.
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
    ls_row-dim2        = iv_dim2.
    ls_row-value       = iv_value.
    ls_row-measured_at = iv_at.
    INSERT ls_row INTO TABLE mt_metrics.
    DATA ls_run TYPE zcd_ops_run.
    ls_run-run_id     = lv_run_byte.
    ls_run-pe_area    = zif_cd_ops_types=>gc_pe_area-health_check.
    ls_run-status     = iv_status.
    ls_run-started_at = iv_at.
    INSERT ls_run INTO TABLE mt_runs.
  ENDMETHOD.


  METHOD insert_history.
    go_env->insert_test_data( mt_metrics ).
    go_env->insert_test_data( mt_runs ).
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
        insert_history( ).
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
        insert_history( ).
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

  " Audit A101: history is read at the persisted grain - two series sharing DIM1 with a
  " different DIM2 (e.g. company code / source) never mix their baselines
  METHOD history_only_same_dim2.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_value.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        add_metric( iv_run_no = 1 iv_dim1 = gc_job iv_dim2 = 'US01' iv_value = 10 iv_at = '20261102070000.0000000' ).
        add_metric( iv_run_no = 1 iv_dim1 = gc_job iv_dim2 = 'US02' iv_value = 900 iv_at = '20261102070000.0000000' ).
        add_metric( iv_run_no = 2 iv_dim1 = gc_job iv_dim2 = 'US01' iv_value = 12 iv_at = '20261103070000.0000000' ).
        insert_history( ).
        lv_value = 12.
        INSERT lv_value INTO TABLE lt_exp.
        lv_value = 10.
        INSERT lv_value INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_metric_history( iv_check_id = gc_check
                                                                              iv_metric   = gc_metric
                                                                              iv_dim1     = gc_job
                                                                              iv_dim2     = 'US01'
                                                                              iv_max_rows = 8 )
                                            exp = lt_exp
                                            msg = 'Only the US01 series, one point per run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.



  " Rule: saved metrics become history (round trip through ZCD_HCK_METRIC)
  " Audit A88: kind and weight are stored; an unclassified metric is stored as a volume
  METHOD metric_kind_and_weight_saved.
    DATA lt_metrics TYPE zif_cd_hck_types=>tt_metric_hist.
    TRY.
        lt_metrics = VALUE #( run_id = '0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C' check_id = gc_check
                              measured_at = '20261105070000.0000000'
                              ( metric = 'COUNTED' dim1 = gc_job value = 3 )
                              ( metric = 'ERR_RATE_PCT' dim1 = gc_job value = '12.5' weight = 80
                                kind = zif_cd_hck_types=>gc_metric_kind-rate ) ).
        mo_cut->save_metrics( lt_metrics ).
        SELECT metric, kind, weight FROM zcd_hck_metric ORDER BY PRIMARY KEY INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Both metrics must be stored' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ metric = 'COUNTED' ]-kind
                                            exp = zif_cd_hck_types=>gc_metric_kind-volume
                                            msg = 'A metric without kind is stored as a volume' ).
        DATA(ls_rate) = lt_rows[ metric = 'ERR_RATE_PCT' ].
        cl_abap_unit_assert=>assert_equals( act = ls_rate-kind exp = zif_cd_hck_types=>gc_metric_kind-rate
                                            msg = 'The rate keeps its kind' ).
        cl_abap_unit_assert=>assert_equals( act = ls_rate-weight exp = 80
                                            msg = 'The rate keeps its denominator as weight' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


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
        DATA ls_run TYPE zcd_ops_run.
        ls_run-run_id  = ls_metric-run_id.
        ls_run-pe_area = zif_cd_ops_types=>gc_pe_area-health_check.
        ls_run-status  = zif_cd_ops_types=>gc_run_status-success.
        INSERT ls_run INTO TABLE mt_runs.
        go_env->insert_test_data( mt_runs ).
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


  " Audit A58: the lookback counts runs, not rows - one point per run (its latest), runs newest first
  METHOD history_one_point_per_run.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_value.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        add_metric( iv_run_no = 1 iv_dim1 = gc_job iv_value = 10 iv_at = '20261102070000.0000000' ).
        add_metric( iv_run_no = 1 iv_dim1 = gc_job iv_value = 15 iv_at = '20261102080000.0000000' ).
        add_metric( iv_run_no = 2 iv_dim1 = gc_job iv_value = 20 iv_at = '20261103070000.0000000' ).
        insert_history( ).
        lv_value = 20.
        INSERT lv_value INTO TABLE lt_exp.
        lv_value = 15.
        INSERT lv_value INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_metric_history( iv_check_id = gc_check
                                                                              iv_metric   = gc_metric
                                                                              iv_dim1     = gc_job
                                                                              iv_max_rows = 2 )
                                            exp = lt_exp
                                            msg = 'Two runs, one point each: run 2, then the latest point of run 1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A58: points of running or aborted runs are not part of a baseline
  METHOD history_skips_unfinished_runs.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_value.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        add_metric( iv_run_no = 1 iv_dim1 = gc_job iv_value = 10 iv_at = '20261102070000.0000000' ).
        add_metric( iv_run_no = 2 iv_dim1 = gc_job iv_value = 20 iv_at = '20261103070000.0000000'
                    iv_status = zif_cd_ops_types=>gc_run_status-running ).
        add_metric( iv_run_no = 3 iv_dim1 = gc_job iv_value = 30 iv_at = '20261104070000.0000000'
                    iv_status = zif_cd_ops_types=>gc_run_status-aborted ).
        insert_history( ).
        lv_value = 10.
        INSERT lv_value INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_metric_history( iv_check_id = gc_check
                                                                              iv_metric   = gc_metric
                                                                              iv_dim1     = gc_job
                                                                              iv_max_rows = 8 )
                                            exp = lt_exp
                                            msg = 'Only the completed run may contribute' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A58: a backdated evaluation sees only history measured up to its as-of time
  METHOD history_as_of_excludes_later.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_value.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        add_metric( iv_run_no = 1 iv_dim1 = gc_job iv_value = 10 iv_at = '20261102070000.0000000' ).
        add_metric( iv_run_no = 2 iv_dim1 = gc_job iv_value = 20 iv_at = '20261104070000.0000000' ).
        insert_history( ).
        lv_value = 10.
        INSERT lv_value INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_metric_history( iv_check_id = gc_check
                                                                              iv_metric   = gc_metric
                                                                              iv_dim1     = gc_job
                                                                              iv_max_rows = 8
                                                                              iv_as_of    = '20261103000000.0000000' )
                                            exp = lt_exp
                                            msg = 'History after the as-of time must not be used' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A42: a job run carries program and variant of its first step
  METHOD job_run_carries_variant.
    DATA lt_jobs TYPE STANDARD TABLE OF tbtco WITH EMPTY KEY.
    DATA ls_job TYPE tbtco.
    DATA lt_steps TYPE STANDARD TABLE OF tbtcp WITH EMPTY KEY.
    DATA ls_step TYPE tbtcp.
    DATA lt_names TYPE zif_cd_hck_types=>tt_jobname_range.
    TRY.
        ls_job-jobname  = gc_job.
        ls_job-jobcount = '13300001'.
        ls_job-status   = zif_cd_hck_types=>gc_job_status-finished.
        ls_job-strtdate = gc_today.
        INSERT ls_job INTO TABLE lt_jobs.
        go_env->insert_test_data( lt_jobs ).
        ls_step-jobname   = gc_job.
        ls_step-jobcount  = '13300001'.
        ls_step-stepcount = 1.
        ls_step-progname  = 'RFKK_MA_SCHEDULER'.
        ls_step-variant   = 'ZDISB_WIRE'.
        INSERT ls_step INTO TABLE lt_steps.
        go_env->insert_test_data( lt_steps ).
        INSERT VALUE #( sign = 'I' option = 'EQ' low = gc_job ) INTO TABLE lt_names.
        DATA(lt_runs) = mo_cut->get_job_runs( it_jobnames = lt_names iv_from = gc_today iv_to = gc_today ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_runs ) exp = 1 msg = 'One job run' ).
        cl_abap_unit_assert=>assert_equals( act = lt_runs[ 1 ]-variant exp = 'ZDISB_WIRE'
                                            msg = 'The variant of step 1 must be returned' ).
        cl_abap_unit_assert=>assert_equals( act = lt_runs[ 1 ]-progname exp = 'RFKK_MA_SCHEDULER'
                                            msg = 'The program of step 1 must be returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A44: unresolved jobs are read whatever their date - an old stuck job stays visible
  METHOD unresolved_jobs_any_date.
    DATA lt_jobs TYPE STANDARD TABLE OF tbtco WITH EMPTY KEY.
    DATA ls_job TYPE tbtco.
    DATA lt_names TYPE zif_cd_hck_types=>tt_jobname_range.
    TRY.
        ls_job-jobname  = gc_job.
        ls_job-jobcount = '00000001'.
        ls_job-status   = zif_cd_hck_types=>gc_job_status-running.
        ls_job-strtdate = '20261020'.
        INSERT ls_job INTO TABLE lt_jobs.
        ls_job-jobcount = '00000002'.
        ls_job-status   = zif_cd_hck_types=>gc_job_status-finished.
        INSERT ls_job INTO TABLE lt_jobs.
        go_env->insert_test_data( lt_jobs ).
        INSERT VALUE #( sign = 'I' option = 'EQ' low = gc_job ) INTO TABLE lt_names.
        DATA(lt_runs) = mo_cut->get_unresolved_jobs( lt_names ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_runs ) exp = 1 msg = 'Only the unfinished job' ).
        cl_abap_unit_assert=>assert_equals( act = lt_runs[ 1 ]-jobcount exp = '00000001'
                                            msg = 'The job running since October must be found' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A43: a GL document only closes the gap for its company code, of the transfer
  " reference type, unreversed; the total count ignores the display cap
  METHOD gl_gap_per_company_and_type.
    DATA lt_sumc TYPE STANDARD TABLE OF dfkksumc WITH EMPTY KEY.
    DATA ls_sumc TYPE dfkksumc.
    DATA lt_kko TYPE STANDARD TABLE OF dfkkko WITH EMPTY KEY.
    DATA ls_kko TYPE dfkkko.
    DATA lt_bkpf TYPE STANDARD TABLE OF bkpf WITH EMPTY KEY.
    DATA ls_bkpf TYPE bkpf.
    CONSTANTS lc_awtyp TYPE awtyp VALUE 'FKKSU'.
    TRY.
        " K1 transferred for US01 only; K2 only by a document of another type; K3 reversed
        ls_sumc-fikey = 'K1'.
        ls_sumc-bukrs = 'US01'.
        INSERT ls_sumc INTO TABLE lt_sumc.
        ls_sumc-bukrs = 'US02'.
        INSERT ls_sumc INTO TABLE lt_sumc.
        ls_sumc-fikey = 'K2'.
        ls_sumc-bukrs = 'US01'.
        INSERT ls_sumc INTO TABLE lt_sumc.
        ls_sumc-fikey = 'K3'.
        INSERT ls_sumc INTO TABLE lt_sumc.
        go_env->insert_test_data( lt_sumc ).
        ls_kko-budat = gc_today.
        ls_kko-fikey = 'K1'.
        INSERT ls_kko INTO TABLE lt_kko.
        ls_kko-fikey = 'K2'.
        INSERT ls_kko INTO TABLE lt_kko.
        ls_kko-fikey = 'K3'.
        INSERT ls_kko INTO TABLE lt_kko.
        go_env->insert_test_data( lt_kko ).
        ls_bkpf-bukrs = 'US01'.
        ls_bkpf-belnr = '0100000001'.
        ls_bkpf-awtyp = lc_awtyp.
        ls_bkpf-awkey = 'K1'.
        INSERT ls_bkpf INTO TABLE lt_bkpf.
        ls_bkpf-belnr = '0100000002'.
        ls_bkpf-awtyp = 'BKPF'.
        ls_bkpf-awkey = 'K2'.
        INSERT ls_bkpf INTO TABLE lt_bkpf.
        ls_bkpf-belnr = '0100000003'.
        ls_bkpf-awtyp = lc_awtyp.
        ls_bkpf-awkey = 'K3'.
        ls_bkpf-stblg = '0100000009'.
        INSERT ls_bkpf INTO TABLE lt_bkpf.
        go_env->insert_test_data( lt_bkpf ).
        DATA(lt_gaps) = mo_cut->get_fikeys_without_gl( iv_from = gc_today iv_to = gc_today
                                                       iv_max_rows = 1 iv_awtyp = lc_awtyp ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_gaps ) exp = 1 msg = 'Display is capped at one gap' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->count_fikeys_without_gl( iv_from = gc_today iv_to = gc_today
                                                                                   iv_awtyp = lc_awtyp )
                                            exp = 3
                                            msg = 'K1/US02, K2/US01 and K3/US01 are gaps' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A56: a query built outside the builder (raw WHERE, table not on the whitelist)
  " is rejected at the SQL boundary - the raw strings are never executed
  METHOD raw_aggregate_is_rejected.
    DATA ls_query TYPE zif_cd_hck_types=>ty_agg_query.
    ls_query-tabname        = 'ZCD_OPS_FINDING'.
    ls_query-where_clause   = `1 = 1`.
    ls_query-agg_func       = zif_cd_hck_types=>gc_agg_func-count.
    ls_query-def-tabname    = 'ZCD_OPS_FINDING'.
    ls_query-def-agg_func   = zif_cd_hck_types=>gc_agg_func-count.
    TRY.
        mo_cut->aggregate( ls_query ).
        cl_abap_unit_assert=>fail( msg = 'A table that is not whitelisted must be rejected by the DAO' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '302'
                                            msg = 'Message 302 (not whitelisted) expected' ).
    ENDTRY.
  ENDMETHOD.


  " Audit A56: the same for a value query passed directly to the DAO
  METHOD raw_value_query_is_rejected.
    DATA ls_query TYPE zif_cd_hck_value_types=>ty_value_query.
    ls_query-tabname      = 'ZCD_OPS_FINDING'.
    ls_query-field_list   = `MESSAGE AS V1`.
    ls_query-where_clause = `1 = 1`.
    ls_query-date_field   = 'DUE_DATE'.
    TRY.
        mo_cut->select_values( is_query = ls_query iv_max_rows = 10 ).
        cl_abap_unit_assert=>fail( msg = 'A table that is not whitelisted must be rejected by the DAO' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '302'
                                            msg = 'Message 302 (not whitelisted) expected' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
