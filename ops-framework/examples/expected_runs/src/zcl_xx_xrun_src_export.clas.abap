*&---------------------------------------------------------------------*
*& Artifact: zcl_xx_xrun_src_export.clas.abap
*& Purpose:
*& Worked example of an expected-run source for an external scheduler
*& (never seeded, not part of the product; docs/EXPECTED_RUNS_AND_MASS_
*& ACTIVITIES.md section 2.4): the site loads the scheduler's daily plan
*& export into its own table ZXX_XRUN_PLAN (run ID, folder, job, planned
*& start, status word, predecessor, load time). The class returns the
*& runs of the requested days with the scheduler's status mapped to the
*& product's states (WAITING planned, RUNNING started, OK ended OK, NOTOK
*& ended not OK, HOLD held; an unknown word stays blank - never guessed)
*& and the newest load time as the freshness of the plan, so a plan that
*& stopped arriving makes the evaluation STALE. The SAP job names come
*& from the scheduler rows (ZCA_OPS_JOBSCH) of the same folder and job.
*& Wired only through XRUN_SOURCES, e.g. "ZCL_XX_XRUN_SRC_EXPORT,
*& ZCL_CA_OPS_XRUN_SRC_JOBSCH" (the export first: its runs win).
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Example - expected runs from a scheduler export</p>
CLASS zcl_xx_xrun_src_export DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_expected_run_src.

  PRIVATE SECTION.
    "! The scheduler's status words of the export (the site's own vocabulary)
    CONSTANTS:
      BEGIN OF gc_word,
        waiting TYPE c LENGTH 10 VALUE 'WAITING',
        running TYPE c LENGTH 10 VALUE 'RUNNING',
        ok      TYPE c LENGTH 10 VALUE 'OK',
        not_ok  TYPE c LENGTH 10 VALUE 'NOTOK',
        hold    TYPE c LENGTH 10 VALUE 'HOLD',
      END OF gc_word.
    CONSTANTS gc_id TYPE zif_ca_ops_xrun_types=>ty_source_id VALUE 'XX_EXPORT'.

    CLASS-METHODS state_of
      IMPORTING
        iv_word         TYPE clike
      RETURNING
        VALUE(rv_state) TYPE zif_ca_ops_xrun_types=>ty_sched_state.

ENDCLASS.



CLASS zcl_xx_xrun_src_export IMPLEMENTATION.

  METHOD zif_ca_ops_expected_run_src~id.
    rv_id = gc_id.
  ENDMETHOD.


  METHOD zif_ca_ops_expected_run_src~read.
    DATA(lv_max) = COND i( WHEN is_request-max > 0 THEN is_request-max ELSE 10000 ).
    TRY.
        SELECT plan_date, sched_folder, sched_job, run_id, plan_time, status, status_at, pred_folder, pred_job,
               loaded_at
          FROM zxx_xrun_plan
          WHERE plan_date BETWEEN @is_request-from_date AND @is_request-to_date
          ORDER BY plan_date, plan_time, sched_folder, sched_job, run_id
          INTO TABLE @DATA(lt_rows)
          UP TO @lv_max ROWS.
        SELECT MAX( loaded_at ) FROM zxx_xrun_plan INTO @rs_plan-newest_at.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e607(zca_ops) WITH gc_id lx_sql->get_text( )
          EXPORTING
            previous = lx_sql.
    ENDTRY.
    rs_plan-partial = xsdbool( lines( lt_rows ) >= lv_max ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( source_id    = gc_id
                      run_id       = <ls_row>-run_id
                      sched_folder = <ls_row>-sched_folder
                      sched_job    = <ls_row>-sched_job
                      plan_date    = <ls_row>-plan_date
                      plan_time    = <ls_row>-plan_time
                      pred_folder  = <ls_row>-pred_folder
                      pred_job     = <ls_row>-pred_job
                      sched_state  = state_of( <ls_row>-status )
                      state_at     = <ls_row>-status_at ) INTO TABLE rs_plan-runs.
    ENDLOOP.
  ENDMETHOD.


  METHOD state_of.
    rv_state = SWITCH #( to_upper( iv_word )
                         WHEN gc_word-waiting THEN zif_ca_ops_xrun_types=>gc_state-planned
                         WHEN gc_word-running THEN zif_ca_ops_xrun_types=>gc_state-started
                         WHEN gc_word-ok      THEN zif_ca_ops_xrun_types=>gc_state-ended_ok
                         WHEN gc_word-not_ok  THEN zif_ca_ops_xrun_types=>gc_state-ended_not_ok
                         WHEN gc_word-hold    THEN zif_ca_ops_xrun_types=>gc_state-held ).
  ENDMETHOD.

ENDCLASS.
