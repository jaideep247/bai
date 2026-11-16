*&---------------------------------------------------------------------*
*& Artifact: zcl_xx_pf_sched_src.clas.abap
*& Purpose:
*& Worked example of a fictitious second customer XX (never seeded, not
*& part of the product): its scheduler source of the payment file
*& lifecycle (role SCHED) - XX runs its payment medium creation from its
*& own scheduler, not as SAP jobs, and logs each run in ZXX_PF_SCHEDLOG
*& (run key, job name, payment run, company code, status DONE / ABEND /
*& RUN, end time). One event per run ended in the window, matched by the
*& product to the files of its payment run and company code. Wired only
*& through the product's interfaces and XX's configuration rows.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle, example XX).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Example XX - payment file scheduler source (run log)</p>
CLASS zcl_xx_pf_sched_src DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_sched_src.

ENDCLASS.



CLASS zcl_xx_pf_sched_src IMPLEMENTATION.

  METHOD zif_ca_ops_pf_adapter~configure.
    " no setting: the run log is XX's own table
  ENDMETHOD.


  METHOD zif_ca_ops_pf_event_src~read_events.
    DATA(lv_max) = COND i( WHEN is_request-max > 0 THEN is_request-max ELSE 10000 ).
    SELECT run_key, job_name, run_date, run_id, bukrs, status, ended_at
      FROM zxx_pf_schedlog
      WHERE ended_at >= @is_request-from_ts
        AND ended_at <= @is_request-to_ts
      ORDER BY ended_at, run_key
      INTO TABLE @DATA(lt_rows)
      UP TO @lv_max ROWS.
    rs_batch-partial = xsdbool( lines( lt_rows ) >= lv_max ).
    rs_batch-as_of = is_request-to_ts.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( source_event_id = <ls_row>-run_key
                      event_version   = 1
                      native_status   = <ls_row>-status
                      run_date        = <ls_row>-run_date
                      run_id          = <ls_row>-run_id
                      bukrs           = <ls_row>-bukrs
                      occurred_at     = <ls_row>-ended_at
                      bus_date        = <ls_row>-run_date
                      job_name        = <ls_row>-job_name ) INTO TABLE rs_batch-events.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
