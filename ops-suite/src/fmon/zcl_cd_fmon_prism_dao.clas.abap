*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_dao.clas.abap
*& Purpose:
*& All SQL of the PRISM status API: idempotent INSERT into ZCD_FMON_PRISM
*& (duplicate EVENT_ID read back and compared), the event reads of the instant
*& unit and of the 5-minute safety net, and the PROCESSED_AT marker. Writes only
*& the suite's own FMON store; no commit (the caller owns the LUW).
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, user decision 2026-11-06).
*& 2026-11-06 | read_event, read_unprocessed, mark_processed (instant bgPF processing).
*& 2026-11-07 | read_failures: FAILED milestones with a duplicate-name error code (regenerated files).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FMON PRISM status API - event repository (SQL)</p>
"! Concurrency: two calls with the same event ID race on the primary key; the loser
"! reads the winner's row back, so both answer consistently (202 / 200 or 409).
CLASS zcl_cd_fmon_prism_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_prism_dao.

  PRIVATE SECTION.
    CONSTANTS gc_table TYPE tabname VALUE 'ZCD_FMON_PRISM'.

ENDCLASS.



CLASS zcl_cd_fmon_prism_dao IMPLEMENTATION.

  METHOD zif_cd_fmon_prism_dao~insert_event.
    DATA ls_db TYPE zcd_fmon_prism.

    ls_db = CORRESPONDING #( is_row ).
    CLEAR ls_db-processed_at.
    INSERT zcd_fmon_prism FROM @ls_db.
    IF sy-subrc = 0.
      rv_result = zif_cd_fmon_prism_types=>gc_store_result-inserted.
      RETURN.
    ENDIF.

    " sy-subrc 4: the primary key (MANDT, EVENT_ID) exists - compare with what is stored
    DATA(ls_stored) = zif_cd_fmon_prism_dao~read_event( is_row-event_id ).
    IF ls_stored IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH gc_table.
    ENDIF.
    rv_result = COND #( WHEN zcl_cd_fmon_prism_event=>same_payload( is_stored = ls_stored
                                                                    is_new    = is_row ) = abap_true
                        THEN zif_cd_fmon_prism_types=>gc_store_result-duplicate
                        ELSE zif_cd_fmon_prism_types=>gc_store_result-conflict ).
  ENDMETHOD.


  METHOD zif_cd_fmon_prism_dao~read_event.
    SELECT SINGLE event_id, file_ref, iface_id, direction, milestone, occurred_at, counterparty,
                  prism_ref, record_count, count_sent, control_total, currency, error_code,
                  error_text, business_date, received_at, received_by, processed_at
      FROM zcd_fmon_prism
      WHERE event_id = @iv_event_id
      INTO CORRESPONDING FIELDS OF @rs_row.
    IF sy-subrc <> 0.
      CLEAR rs_row.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_fmon_prism_dao~read_unprocessed.
    DATA lv_never TYPE timestampl.
    SELECT event_id, file_ref, iface_id, direction, milestone, occurred_at, counterparty,
           prism_ref, record_count, count_sent, control_total, currency, error_code,
           error_text, business_date, received_at, received_by, processed_at
      FROM zcd_fmon_prism
      WHERE processed_at = @lv_never
        AND received_at >= @iv_from
        AND received_at  < @iv_to
      ORDER BY received_at, event_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_rows
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.


  METHOD zif_cd_fmon_prism_dao~read_failures.
    DATA lt_codes TYPE RANGE OF zif_cd_fmon_prism_types=>ty_error_code.
    IF it_codes IS INITIAL.
      RETURN.
    ENDIF.
    lt_codes = VALUE #( FOR lv_code IN it_codes ( sign = 'I' option = 'EQ' low = lv_code ) ).
    " index BDT: MANDT, BUSINESS_DATE - failures are rare, the codes filter the few rows
    SELECT event_id, file_ref, iface_id, direction, milestone, occurred_at, counterparty,
           prism_ref, record_count, count_sent, control_total, currency, error_code,
           error_text, business_date, received_at, received_by, processed_at
      FROM zcd_fmon_prism
      WHERE business_date >= @iv_since
        AND milestone      = @zif_cd_fmon_prism_types=>gc_milestone-failed
        AND error_code    IN @lt_codes
      ORDER BY business_date, event_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_rows.
  ENDMETHOD.


  METHOD zif_cd_fmon_prism_dao~mark_processed.
    DATA lv_never TYPE timestampl.
    DATA lt_ids TYPE RANGE OF zif_cd_fmon_prism_types=>ty_event_id.
    IF it_event_ids IS INITIAL.
      RETURN.
    ENDIF.
    lt_ids = VALUE #( FOR lv_id IN it_event_ids ( sign = 'I' option = 'EQ' low = lv_id ) ).
    " An event a parallel unit already marked keeps its first processing time
    UPDATE zcd_fmon_prism SET processed_at = @iv_at
      WHERE event_id IN @lt_ids AND processed_at = @lv_never.
    IF sy-subrc > 4.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e011(zcd_ops) WITH gc_table.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
