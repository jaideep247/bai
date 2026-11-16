*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_eval_dao.clas.abap
*& Purpose:
*& SQL of the evaluation records (ZIF_CA_OPS_EVAL_DAO): the only writer of
*& ZCA_OPS_EVAL and ZCA_OPS_EVALSRC. SAVE completes the last valid result of
*& each record (itself when complete, else the latest complete record of
*& its area and check, index LST) and inserts records and sources; LATEST
*& returns the newest record of every check (MAX of EVALUATED_AT per area
*& and check on the database, then the rows). No commit: the runner's unit
*& of work. Deleted with their run by the retention purge (target RUN).
*& Modification log:
*& 2026-11-16 | Initial version (build O: evaluation state of every control).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - evaluation records (DB)</p>
CLASS zcl_ca_ops_eval_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_eval_dao.

  PRIVATE SECTION.
    "! The latest complete record of a check before the run (initial = none)
    METHODS last_complete
      IMPORTING
        iv_area        TYPE zif_ca_ops_types=>ty_area
        iv_check_id    TYPE clike
      RETURNING
        VALUE(rs_eval) TYPE zif_ca_ops_eval_types=>ty_eval.

ENDCLASS.



CLASS zcl_ca_ops_eval_dao IMPLEMENTATION.

  METHOD zif_ca_ops_eval_dao~save.
    DATA lt_db TYPE STANDARD TABLE OF zca_ops_eval WITH EMPTY KEY.
    DATA lt_src TYPE STANDARD TABLE OF zca_ops_evalsrc WITH EMPTY KEY.
    IF it_eval IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT it_eval INTO DATA(ls_eval).
      IF ls_eval-completeness = zif_ca_ops_eval_types=>gc_cmpl-complete.
        ls_eval-last_valid_run = ls_eval-run_id.
        ls_eval-last_valid_at  = ls_eval-evaluated_at.
        ls_eval-last_valid_cls = ls_eval-result_class.
      ELSE.
        DATA(ls_last) = last_complete( iv_area = ls_eval-area iv_check_id = ls_eval-check_id ).
        ls_eval-last_valid_run = ls_last-run_id.
        ls_eval-last_valid_at  = ls_last-evaluated_at.
        ls_eval-last_valid_cls = ls_last-result_class.
      ENDIF.
      INSERT CORRESPONDING #( ls_eval ) INTO TABLE lt_db.
      LOOP AT ls_eval-sources ASSIGNING FIELD-SYMBOL(<ls_source>).
        INSERT VALUE #( run_id    = ls_eval-run_id
                        check_id  = ls_eval-check_id
                        source_id = <ls_source>-source_id
                        area      = ls_eval-area
                        newest_at = <ls_source>-newest_at
                        stale_min = <ls_source>-stale_min
                        is_stale  = <ls_source>-is_stale ) INTO TABLE lt_src.
      ENDLOOP.
    ENDLOOP.
    INSERT zca_ops_eval FROM TABLE @lt_db ACCEPTING DUPLICATE KEYS.
    IF sy-dbcnt <> lines( lt_db ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_EVAL'.
    ENDIF.
    IF lt_src IS NOT INITIAL.
      SORT lt_src BY run_id check_id source_id.
      DELETE ADJACENT DUPLICATES FROM lt_src COMPARING run_id check_id source_id.
      INSERT zca_ops_evalsrc FROM TABLE @lt_src ACCEPTING DUPLICATE KEYS.
      IF sy-dbcnt <> lines( lt_src ).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e010(zca_ops) WITH 'ZCA_OPS_EVALSRC'.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD last_complete.
    SELECT run_id, check_id, area, evaluated_at, result_class
      FROM zca_ops_eval
      WHERE area         = @iv_area
        AND check_id     = @iv_check_id
        AND completeness = @zif_ca_ops_eval_types=>gc_cmpl-complete
      ORDER BY evaluated_at DESCENDING
      INTO TABLE @DATA(lt_last)
      UP TO 1 ROWS.
    IF lt_last IS NOT INITIAL.
      rs_eval = CORRESPONDING #( lt_last[ 1 ] ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_eval_dao~latest.
    DATA lt_area TYPE RANGE OF zif_ca_ops_types=>ty_area.
    IF iv_area IS NOT INITIAL.
      lt_area = VALUE #( ( sign = 'I' option = 'EQ' low = iv_area ) ).
    ENDIF.
    SELECT area, check_id, MAX( evaluated_at ) AS evaluated_at
      FROM zca_ops_eval
      WHERE area IN @lt_area
      GROUP BY area, check_id
      ORDER BY area, check_id
      INTO TABLE @DATA(lt_last).
    IF lt_last IS INITIAL.
      RETURN.
    ENDIF.
    SELECT run_id, check_id, area, process_id, sched_group, evaluated_at, bus_date, period, bukrs_list,
           expected_cnt, observed_cnt, item_count, finding_cnt, completeness, result_class, eval_state,
           reason_code, reason, fresh_at, fresh_source, watermark, lic_state, lic_module, last_valid_run,
           last_valid_at, last_valid_cls
      FROM zca_ops_eval
      FOR ALL ENTRIES IN @lt_last
      WHERE area         = @lt_last-area
        AND check_id     = @lt_last-check_id
        AND evaluated_at = @lt_last-evaluated_at
      INTO CORRESPONDING FIELDS OF TABLE @rt_eval.
    SORT rt_eval BY area check_id evaluated_at DESCENDING.
    DELETE ADJACENT DUPLICATES FROM rt_eval COMPARING area check_id.
  ENDMETHOD.

ENDCLASS.
