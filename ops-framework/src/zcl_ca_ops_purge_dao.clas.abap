*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_purge_dao.clas.abap
*& Purpose:
*& SQL of the retention purge for the framework's own targets and the
*& registry of the consumers' targets. A run is purgeable when it started
*& before the cutoff and none of its findings is open (O), assigned (A) or
*& waived (W) with a waiver that has not expired (no end date = not
*& expired). Its findings and their exception history are deleted with it.
*& The alert log is purged by its send time, the sign-offs of the daily
*& control review (REVIEW) by their sign-off time. Deletes by key, at most iv_max
*& rows per call; the caller commits. GET_TARGETS reads ZCA_OPS_PURGE.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-06 | Modern-syntax sweep: alert tables.
*& 2026-11-10 | RUN: exception history of the purged findings deleted first (was orphaned).
*& 2026-11-10 | Moved from ZCL_CD_OPS_PURGE_DAO to the reusable framework ZCA_OPS: targets RUN and
*&            | ALERT_LOG only (a consumer's tables are purged by its own target classes), GET_TARGETS
*&            | (registry ZCA_OPS_PURGE).
*& 2026-11-10 | Target REVIEW (ZCA_OPS_REVIEW by REVIEWED_AT, daily control review).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - retention purge SQL</p>
CLASS zcl_ca_ops_purge_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_purge_dao.

  PRIVATE SECTION.
    TYPES tt_run_range TYPE RANGE OF zca_ops_run-run_id.

    METHODS purgeable_runs
      IMPORTING
        iv_cutoff      TYPE timestampl
        iv_today       TYPE d
        iv_max         TYPE i
      RETURNING
        VALUE(rt_runs) TYPE tt_run_range.

ENDCLASS.



CLASS zcl_ca_ops_purge_dao IMPLEMENTATION.

  METHOD zif_ca_ops_purge_target~count_purgeable.
    DATA lv_no_end TYPE d.
    CASE iv_target.
      WHEN zif_ca_ops_purge_dao=>gc_target-run.
        " anti-join: runs without any blocking finding
        SELECT COUNT(*)
          FROM zca_ops_run AS r
            LEFT OUTER JOIN zca_ops_finding AS f
              ON  f~run_id = r~run_id
              AND ( f~disposition IN ( @zif_ca_ops_types=>gc_disposition-open,
                                       @zif_ca_ops_types=>gc_disposition-assigned )
                 OR ( f~disposition = @zif_ca_ops_types=>gc_disposition-waived
                      AND ( f~waiver_until >= @iv_today OR f~waiver_until = @lv_no_end ) ) )
          WHERE r~started_at < @iv_cutoff
            AND f~run_id IS NULL
          INTO @rv_count.
      WHEN zif_ca_ops_purge_dao=>gc_target-alert_log.
        SELECT COUNT(*) FROM zca_ops_allog WHERE sent_at < @iv_cutoff INTO @rv_count.
      WHEN zif_ca_ops_purge_dao=>gc_target-review.
        SELECT COUNT(*) FROM zca_ops_review WHERE reviewed_at < @iv_cutoff INTO @rv_count.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_ca_ops_purge_target~delete_package.
    CLEAR: ev_dependent, ev_history.
    CASE iv_target.
      WHEN zif_ca_ops_purge_dao=>gc_target-run.
        DATA(lt_runs) = purgeable_runs( iv_cutoff = iv_cutoff iv_today = iv_today iv_max = iv_max ).
        CHECK lt_runs IS NOT INITIAL.
        " the action history belongs to the findings - never left without them (index FND)
        DELETE FROM zca_ops_exc_hist WHERE run_id IN @lt_runs.
        ev_history = sy-dbcnt.
        DELETE FROM zca_ops_finding WHERE run_id IN @lt_runs.
        ev_dependent = sy-dbcnt.
        DELETE FROM zca_ops_run WHERE run_id IN @lt_runs.
        rv_count = sy-dbcnt.

      WHEN zif_ca_ops_purge_dao=>gc_target-alert_log.
        SELECT alert_id
          FROM zca_ops_allog
          WHERE sent_at < @iv_cutoff
          ORDER BY alert_id
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_alerts)
          UP TO @iv_max ROWS.
        CHECK lt_alerts IS NOT INITIAL.
        DELETE zca_ops_allog FROM TABLE @lt_alerts.
        rv_count = sy-dbcnt.

      WHEN zif_ca_ops_purge_dao=>gc_target-review.
        SELECT area, control_id, business_date
          FROM zca_ops_review
          WHERE reviewed_at < @iv_cutoff
          ORDER BY area, control_id, business_date
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_reviews)
          UP TO @iv_max ROWS.
        CHECK lt_reviews IS NOT INITIAL.
        DELETE zca_ops_review FROM TABLE @lt_reviews.
        rv_count = sy-dbcnt.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_ca_ops_purge_dao~get_targets.
    SELECT target, class_name, param_area, param_name
      FROM zca_ops_purge
      WHERE active = @abap_true
      ORDER BY target
      INTO CORRESPONDING FIELDS OF TABLE @rt_targets.
  ENDMETHOD.


  METHOD purgeable_runs.
    DATA lv_no_end TYPE d.
    " anti-join: runs without any blocking finding (DISTINCT: one row per run)
    SELECT DISTINCT r~run_id
      FROM zca_ops_run AS r
        LEFT OUTER JOIN zca_ops_finding AS f
          ON  f~run_id = r~run_id
          AND ( f~disposition IN ( @zif_ca_ops_types=>gc_disposition-open,
                                   @zif_ca_ops_types=>gc_disposition-assigned )
             OR ( f~disposition = @zif_ca_ops_types=>gc_disposition-waived
                  AND ( f~waiver_until >= @iv_today OR f~waiver_until = @lv_no_end ) ) )
      WHERE r~started_at < @iv_cutoff
        AND f~run_id IS NULL
      ORDER BY r~run_id
      INTO TABLE @DATA(lt_ids)
      UP TO @iv_max ROWS.
    rt_runs = VALUE #( FOR ls_id IN lt_ids ( sign = zif_ca_ops_types=>gc_range-sign_include
                                             option = zif_ca_ops_types=>gc_range-option_equal
                                             low = ls_id-run_id ) ).
  ENDMETHOD.

ENDCLASS.
