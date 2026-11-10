*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_purge_dao.clas.abap
*& Purpose:
*& All SQL of the retention purge. A run is purgeable when it started before
*& the cutoff and none of its findings is open (O), assigned (A) or waived (W)
*& with a waiver that has not expired (no end date = not expired). Its findings
*& are deleted with it. Alert log, FMON events and HCK metrics are purged by
*& their own timestamps. Deletes by key, at most iv_max rows per call; the
*& caller commits. Reads ZCD_FMON_EVENT / ZCD_HCK_METRIC of the payment engine area packages
*& (core-to-payment engine area use accepted for this one housekeeping class).
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCD_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-06 | Purge target FMON_PRISM: PRISM status events by receipt time (RETENTION_DAYS_FMON_PRISM).
*& 2026-11-07 | Purge target HCK_RESULT: check verdicts by execution time (index TIM).
*& 2026-11-07 | Purge target PAY_OUTCOME: versions closed before the cutoff (index OUT) and versions of
*&            | payment runs before the cutoff date (index DAT).
*& 2026-11-08 | PAY_OUTCOME fix: the current version is deleted only when its outcome is final
*&            | (ZCL_CD_OPS_PAY_OUTCOME=>FINAL_OUTCOMES) and its payment run is before the cutoff date;
*&            | the current version of a payment that is not final is never deleted, however old.
*&            | Closed versions (VALID_TO before the cutoff) go as before.
*& 2026-11-08 | PAY_OUTCOME comments: the worklist holds open rows and exception history only (clean payments are
*&            | deleted by the snapshot); rule unchanged - closed history 90 days after the exception closed, open
*&            | rows never.
*& 2026-11-10 | RUN: exception history of the purged findings deleted first (was orphaned); FMON_FILE:
*&            | registry rows by business date, files of open FMON exceptions kept (REFERENCE = file ID).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - retention purge SQL</p>
CLASS zcl_cd_ops_purge_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_purge_dao.

  PRIVATE SECTION.
    TYPES tt_run_range TYPE RANGE OF zcd_ops_run-run_id.

    "! Date (UTC) of the cutoff time stamp
    CLASS-METHODS cutoff_date
      IMPORTING
        iv_cutoff      TYPE timestampl
      RETURNING
        VALUE(rv_date) TYPE d.

    "! FMON_FILE: keys of registry files of a business date before the cutoff that no open,
    "! assigned or validly waived FMON exception refers to (at most iv_max candidates per package)
    METHODS purgeable_files
      IMPORTING
        iv_cutoff       TYPE timestampl
        iv_today        TYPE d
        iv_max          TYPE i
      RETURNING
        VALUE(rt_files) TYPE tt_file_key.

    "! Upper bound of the FMON_FILE count in test mode (one candidate read, no unbounded scan)
    CONSTANTS gc_count_cap TYPE i VALUE 1000000.
    TYPES:
      BEGIN OF ty_file_key,
        file_id TYPE sysuuid_x16,
      END OF ty_file_key.
    TYPES tt_file_key TYPE STANDARD TABLE OF ty_file_key WITH EMPTY KEY.

    METHODS purgeable_runs
      IMPORTING
        iv_cutoff      TYPE timestampl
        iv_today       TYPE d
        iv_max         TYPE i
      RETURNING
        VALUE(rt_runs) TYPE tt_run_range.

ENDCLASS.



CLASS zcl_cd_ops_purge_dao IMPLEMENTATION.

  METHOD zif_cd_ops_purge_dao~count_purgeable.
    DATA lv_no_end TYPE d.
    CASE iv_target.
      WHEN zif_cd_ops_purge_dao=>gc_target-run.
        " anti-join: runs without any blocking finding
        SELECT COUNT(*)
          FROM zcd_ops_run AS r
            LEFT OUTER JOIN zcd_ops_finding AS f
              ON  f~run_id = r~run_id
              AND ( f~disposition IN ( @zif_cd_ops_types=>gc_disposition-open,
                                       @zif_cd_ops_types=>gc_disposition-assigned )
                 OR ( f~disposition = @zif_cd_ops_types=>gc_disposition-waived
                      AND ( f~waiver_until >= @iv_today OR f~waiver_until = @lv_no_end ) ) )
          WHERE r~started_at < @iv_cutoff
            AND f~run_id IS NULL
          INTO @rv_count.
      WHEN zif_cd_ops_purge_dao=>gc_target-alert_log.
        SELECT COUNT(*) FROM zcd_ops_allog WHERE sent_at < @iv_cutoff INTO @rv_count.
      WHEN zif_cd_ops_purge_dao=>gc_target-fmon_event.
        SELECT COUNT(*) FROM zcd_fmon_event WHERE created_at < @iv_cutoff INTO @rv_count.
      WHEN zif_cd_ops_purge_dao=>gc_target-hck_metric.
        SELECT COUNT(*) FROM zcd_hck_metric WHERE measured_at < @iv_cutoff INTO @rv_count.
      WHEN zif_cd_ops_purge_dao=>gc_target-fmon_prism.
        SELECT COUNT(*) FROM zcd_fmon_prism WHERE received_at < @iv_cutoff INTO @rv_count.
      WHEN zif_cd_ops_purge_dao=>gc_target-hck_result.
        SELECT COUNT(*) FROM zcd_hck_result WHERE executed_at < @iv_cutoff INTO @rv_count.
      WHEN zif_cd_ops_purge_dao=>gc_target-fmon_file.
        " counted like it is deleted: the files of open exceptions are left out
        rv_count = lines( purgeable_files( iv_cutoff = iv_cutoff iv_today = iv_today iv_max = gc_count_cap ) ).
      WHEN zif_cd_ops_purge_dao=>gc_target-pay_outcome.
        DATA(lv_cutoff_date) = cutoff_date( iv_cutoff ).
        DATA(lt_final) = zcl_cd_ops_pay_outcome=>final_outcomes( ).
        SELECT COUNT(*) FROM zcd_pay_outcome
          WHERE valid_to < @iv_cutoff
             OR ( valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
                  AND outcome IN @lt_final
                  AND laufd < @lv_cutoff_date )
          INTO @rv_count.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_cd_ops_purge_dao~delete_package.
    CLEAR ev_findings.
    CASE iv_target.
      WHEN zif_cd_ops_purge_dao=>gc_target-run.
        DATA(lt_runs) = purgeable_runs( iv_cutoff = iv_cutoff iv_today = iv_today iv_max = iv_max ).
        CHECK lt_runs IS NOT INITIAL.
        " the action history belongs to the findings - never left without them (index FND)
        DELETE FROM zcd_ops_exc_hist WHERE run_id IN @lt_runs.
        ev_history = sy-dbcnt.
        DELETE FROM zcd_ops_finding WHERE run_id IN @lt_runs.
        ev_findings = sy-dbcnt.
        DELETE FROM zcd_ops_run WHERE run_id IN @lt_runs.
        rv_count = sy-dbcnt.

      WHEN zif_cd_ops_purge_dao=>gc_target-alert_log.
        SELECT alert_id
          FROM zcd_ops_allog
          WHERE sent_at < @iv_cutoff
          ORDER BY alert_id
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_alerts)
          UP TO @iv_max ROWS.
        CHECK lt_alerts IS NOT INITIAL.
        DELETE zcd_ops_allog FROM TABLE @lt_alerts.
        rv_count = sy-dbcnt.

      WHEN zif_cd_ops_purge_dao=>gc_target-fmon_event.
        SELECT file_id, event_no
          FROM zcd_fmon_event
          WHERE created_at < @iv_cutoff
          ORDER BY file_id, event_no
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_events)
          UP TO @iv_max ROWS.
        CHECK lt_events IS NOT INITIAL.
        DELETE zcd_fmon_event FROM TABLE @lt_events.
        rv_count = sy-dbcnt.

      WHEN zif_cd_ops_purge_dao=>gc_target-hck_metric.
        SELECT run_id, check_id, metric, dim1, dim2
          FROM zcd_hck_metric
          WHERE measured_at < @iv_cutoff
          ORDER BY run_id, check_id, metric, dim1, dim2
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_metrics)
          UP TO @iv_max ROWS.
        CHECK lt_metrics IS NOT INITIAL.
        DELETE zcd_hck_metric FROM TABLE @lt_metrics.
        rv_count = sy-dbcnt.

      WHEN zif_cd_ops_purge_dao=>gc_target-hck_result.
        SELECT run_id, check_id
          FROM zcd_hck_result
          WHERE executed_at < @iv_cutoff
          ORDER BY run_id, check_id
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_results)
          UP TO @iv_max ROWS.
        CHECK lt_results IS NOT INITIAL.
        DELETE zcd_hck_result FROM TABLE @lt_results.
        rv_count = sy-dbcnt.

      WHEN zif_cd_ops_purge_dao=>gc_target-pay_outcome.
        " The payment worklist (2026-11-08): closed versions are exception history - VALID_TO before the
        " cutoff = the exception closed more than RETENTION_DAYS_PAY_OUTCOME ago (index OUT); a current row
        " only when its outcome is final (an exception that can no longer change) and its run is before
        " the cutoff date. An open row (payment in flight, pending, undetermined, inconsistent, ambiguous;
        " a payment request) is never deleted, however old: A_INFLIGHT / A_PRQ_NOT_PAID count it
        DATA(lv_run_cutoff) = cutoff_date( iv_cutoff ).
        DATA(lt_final_outcomes) = zcl_cd_ops_pay_outcome=>final_outcomes( ).
        SELECT fin_id, source, bukrs, augbl, laufd, laufi, valid_from
          FROM zcd_pay_outcome
          WHERE valid_to < @iv_cutoff
             OR ( valid_to = @zif_cd_ops_payout_types=>gc_valid_to_open
                  AND outcome IN @lt_final_outcomes
                  AND laufd < @lv_run_cutoff )
          ORDER BY fin_id, source, bukrs, augbl, laufd, laufi, valid_from
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_versions)
          UP TO @iv_max ROWS.
        CHECK lt_versions IS NOT INITIAL.
        DELETE zcd_pay_outcome FROM TABLE @lt_versions.
        rv_count = sy-dbcnt.

      WHEN zif_cd_ops_purge_dao=>gc_target-fmon_file.
        DATA(lt_files) = purgeable_files( iv_cutoff = iv_cutoff iv_today = iv_today iv_max = iv_max ).
        CHECK lt_files IS NOT INITIAL.
        DELETE zcd_fmon_file FROM TABLE @lt_files.
        rv_count = sy-dbcnt.

      WHEN zif_cd_ops_purge_dao=>gc_target-fmon_prism.
        " By receipt time; FMON keeps its own events (ZCD_FMON_EVENT) for the file history
        SELECT event_id
          FROM zcd_fmon_prism
          WHERE received_at < @iv_cutoff
          ORDER BY event_id
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_prism)
          UP TO @iv_max ROWS.
        CHECK lt_prism IS NOT INITIAL.
        DELETE zcd_fmon_prism FROM TABLE @lt_prism.
        rv_count = sy-dbcnt.
    ENDCASE.
  ENDMETHOD.


  METHOD cutoff_date.
    CONVERT TIME STAMP iv_cutoff TIME ZONE zif_cd_ops_types=>gc_time_zone_utc INTO DATE rv_date.
  ENDMETHOD.


  METHOD purgeable_files.
    DATA lt_refs TYPE SORTED TABLE OF zif_cd_ops_types=>ty_reference WITH UNIQUE KEY table_line.
    DATA lv_no_end TYPE d.

    DATA(lv_cutoff_date) = cutoff_date( iv_cutoff ).
    SELECT file_id
      FROM zcd_fmon_file
      WHERE business_date < @lv_cutoff_date
      ORDER BY file_id
      INTO TABLE @DATA(lt_candidates)
      UP TO @iv_max ROWS.
    IF lt_candidates IS INITIAL.
      RETURN.
    ENDIF.
    " FMON findings refer to their file by REFERENCE = file ID (hex, ZCL_CD_FMON_UTIL=>FILE_HEX)
    LOOP AT lt_candidates ASSIGNING FIELD-SYMBOL(<ls_candidate>).
      INSERT CONV zif_cd_ops_types=>ty_reference( |{ <ls_candidate>-file_id }| ) INTO TABLE lt_refs.
    ENDLOOP.
    CHECK lt_refs IS NOT INITIAL.
    SELECT DISTINCT reference
      FROM zcd_ops_finding
      FOR ALL ENTRIES IN @lt_refs
      WHERE pe_area   = @zif_cd_ops_types=>gc_pe_area-file_monitor
        AND reference = @lt_refs-table_line
        AND ( disposition IN ( @zif_cd_ops_types=>gc_disposition-open,
                               @zif_cd_ops_types=>gc_disposition-assigned )
              OR ( disposition = @zif_cd_ops_types=>gc_disposition-waived
                   AND ( waiver_until >= @iv_today OR waiver_until = @lv_no_end ) ) )
      INTO TABLE @DATA(lt_kept).
    LOOP AT lt_candidates ASSIGNING <ls_candidate>.
      IF NOT line_exists( lt_kept[ reference = |{ <ls_candidate>-file_id }| ] ).
        INSERT VALUE #( file_id = <ls_candidate>-file_id ) INTO TABLE rt_files.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD purgeable_runs.
    DATA lv_no_end TYPE d.
    " anti-join: runs without any blocking finding (DISTINCT: one row per run)
    SELECT DISTINCT r~run_id
      FROM zcd_ops_run AS r
        LEFT OUTER JOIN zcd_ops_finding AS f
          ON  f~run_id = r~run_id
          AND ( f~disposition IN ( @zif_cd_ops_types=>gc_disposition-open,
                                   @zif_cd_ops_types=>gc_disposition-assigned )
             OR ( f~disposition = @zif_cd_ops_types=>gc_disposition-waived
                  AND ( f~waiver_until >= @iv_today OR f~waiver_until = @lv_no_end ) ) )
      WHERE r~started_at < @iv_cutoff
        AND f~run_id IS NULL
      ORDER BY r~run_id
      INTO TABLE @DATA(lt_ids)
      UP TO @iv_max ROWS.
    rt_runs = VALUE #( FOR ls_id IN lt_ids ( sign = 'I' option = 'EQ' low = ls_id-run_id ) ).
  ENDMETHOD.

ENDCLASS.
