*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_dao.clas.abap
*& Purpose:
*& Data access of the payment file lifecycle (ZIF_CA_OPS_PF_DAO): the
*& only class that reads the configuration ZCA_OPS_PFTYP / PFSTG / PFMAP /
*& PFADP for the engines and writes the register ZCA_OPS_PFFILE / PFPAY /
*& PFEVT / PFMST / PFSRC / PFDAY. Evidence rows are inserted accepting
*& duplicate keys (an observation read twice is stored once); payments
*& and milestones of a file are replaced; amount totals per file and
*& currency are aggregated in the database (GROUP BY), never summed
*& across currencies. Files are read in packages of GC_PACKAGE keys.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file data access (DB)</p>
CLASS zcl_ca_ops_pf_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_dao.

  PRIVATE SECTION.
    "! Keys per range of one statement
    CONSTANTS gc_package TYPE i VALUE 500.
    TYPES tt_id_range TYPE RANGE OF zif_ca_ops_pf_types=>ty_file_id.
    TYPES tt_id_ranges TYPE STANDARD TABLE OF tt_id_range WITH EMPTY KEY.

    "! The file IDs in ranges of at most GC_PACKAGE
    CLASS-METHODS id_ranges
      IMPORTING
        it_file_ids      TYPE zif_ca_ops_pf_types=>tt_file_id
      RETURNING
        VALUE(rt_ranges) TYPE tt_id_ranges.

ENDCLASS.



CLASS zcl_ca_ops_pf_dao IMPLEMENTATION.

  METHOD zif_ca_ops_pf_dao~get_file_types.
    SELECT area, file_type, description, process_id, direction, ack_level, ack_multi, calendar_id, time_zone,
           day_cutoff, expected_files, zero_ok, stale_min, open_days, active
      FROM zca_ops_pftyp
      WHERE area   = @iv_area
        AND active = @abap_true
      ORDER BY file_type
      INTO CORRESPONDING FIELDS OF TABLE @rt_types.
    IF iv_file_type IS NOT INITIAL.
      DELETE rt_types WHERE file_type <> iv_file_type.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~get_stages.
    SELECT area, file_type, milestone, required, due_kind, due_time, day_offset, basis, offset_min, grace_min, active
      FROM zca_ops_pfstg
      WHERE area      = @iv_area
        AND file_type = @iv_file_type
        AND active    = @abap_true
      ORDER BY milestone
      INTO CORRESPONDING FIELDS OF TABLE @rt_stages.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~get_maps.
    SELECT area, source_id, status, milestone, outcome, active
      FROM zca_ops_pfmap
      WHERE area   = @iv_area
        AND active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_maps.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~get_adapters.
    SELECT area, file_type, role, source_id, class_name, setting, source_type, active
      FROM zca_ops_pfadp
      WHERE area      = @iv_area
        AND file_type = @iv_file_type
        AND active    = @abap_true
      ORDER BY role
      INTO CORRESPONDING FIELDS OF TABLE @rt_adapters.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~get_source.
    SELECT SINGLE area, source_id, role, watermark, as_of, last_run_at, last_ok_at, status, reason, read_count,
                  unmapped_count
      FROM zca_ops_pfsrc
      WHERE area      = @iv_area
        AND source_id = @iv_source_id
      INTO CORRESPONDING FIELDS OF @rs_source.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~get_sources.
    SELECT area, source_id, role, watermark, as_of, last_run_at, last_ok_at, status, reason, read_count,
           unmapped_count
      FROM zca_ops_pfsrc
      WHERE area = @iv_area
      ORDER BY source_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_sources.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~save_source.
    DATA ls_db TYPE zca_ops_pfsrc.
    ls_db = CORRESPONDING #( is_source ).
    MODIFY zca_ops_pfsrc FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_PFSRC'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~files_by_key.
    IF it_native_keys IS INITIAL.
      RETURN.
    ENDIF.
    SELECT area, file_id, file_type, source_id, native_key, bukrs, run_date, run_id, pay_method, house_bank,
           account_id, bus_date, gen_at, gen_job, gen_jobcount, predecessor, pay_count, unknown_count, pay_partial,
           stage, next_ms, state, deadline_at, overdue_min, calendar_id, ack_conflict, pay_rejected, pay_open,
           late_ms, late_min, eval_state, eval_reason, eval_at,
           last_valid_at, last_valid_state, ticket_ref, created_at, changed_at
      FROM zca_ops_pffile
      FOR ALL ENTRIES IN @it_native_keys
      WHERE area       = @iv_area
        AND file_type  = @iv_file_type
        AND native_key = @it_native_keys-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_files.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~files_since.
    DATA lt_types TYPE RANGE OF zif_ca_ops_pf_types=>ty_file_type.
    IF iv_file_type IS NOT INITIAL.
      lt_types = VALUE #( ( sign = 'I' option = 'EQ' low = iv_file_type ) ).
    ENDIF.
    SELECT area, file_id, file_type, source_id, native_key, bukrs, run_date, run_id, pay_method, house_bank,
           account_id, bus_date, gen_at, gen_job, gen_jobcount, predecessor, pay_count, unknown_count, pay_partial,
           stage, next_ms, state, deadline_at, overdue_min, calendar_id, ack_conflict, pay_rejected, pay_open,
           late_ms, late_min, eval_state, eval_reason, eval_at,
           last_valid_at, last_valid_state, ticket_ref, created_at, changed_at
      FROM zca_ops_pffile
      WHERE area      =  @iv_area
        AND file_type IN @lt_types
        AND bus_date  >= @iv_from
      ORDER BY bus_date, file_type, native_key
      INTO CORRESPONDING FIELDS OF TABLE @rt_files
      UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~save_files.
    DATA lt_db TYPE STANDARD TABLE OF zca_ops_pffile WITH EMPTY KEY.
    IF it_files IS INITIAL.
      RETURN.
    ENDIF.
    lt_db = CORRESPONDING #( it_files ).
    MODIFY zca_ops_pffile FROM TABLE @lt_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_PFFILE'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~save_payments.
    DATA lt_db TYPE STANDARD TABLE OF zca_ops_pfpay WITH EMPTY KEY.
    LOOP AT id_ranges( it_file_ids ) ASSIGNING FIELD-SYMBOL(<lt_range>).
      DELETE FROM zca_ops_pfpay WHERE area = @iv_area AND file_id IN @<lt_range>.
    ENDLOOP.
    IF it_payments IS INITIAL.
      RETURN.
    ENDIF.
    lt_db = CORRESPONDING #( it_payments ).
    SORT lt_db BY area file_id pay_key.
    DELETE ADJACENT DUPLICATES FROM lt_db COMPARING area file_id pay_key.
    INSERT zca_ops_pfpay FROM TABLE @lt_db ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_db ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_PFPAY'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~get_payments.
    DATA lt_part TYPE zif_ca_ops_pf_types=>tt_payment.
    LOOP AT id_ranges( it_file_ids ) ASSIGNING FIELD-SYMBOL(<lt_range>).
      SELECT area, file_id, pay_key, bukrs, currency, amount, amount_known, partner_masked, pay_doc, pay_method,
             batch_id, ack_outcome, ack_at, other_file
        FROM zca_ops_pfpay
        WHERE area    =  @iv_area
          AND file_id IN @<lt_range>
        ORDER BY file_id, pay_key
        INTO CORRESPONDING FIELDS OF TABLE @lt_part.
      INSERT LINES OF lt_part INTO TABLE rt_payments.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~payments_elsewhere.
    IF it_payments IS INITIAL.
      RETURN.
    ENDIF.
    " index PAY (MANDT, AREA, PAY_KEY)
    SELECT area, file_id, pay_key, bukrs, currency, amount, amount_known, partner_masked, pay_doc, pay_method,
           batch_id, ack_outcome, ack_at, other_file
      FROM zca_ops_pfpay
      FOR ALL ENTRIES IN @it_payments
      WHERE area    =  @iv_area
        AND pay_key =  @it_payments-pay_key
        AND file_id <> @it_payments-file_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_payments.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~insert_events.
    DATA lt_db TYPE STANDARD TABLE OF zca_ops_pfevt WITH EMPTY KEY.
    IF it_events IS INITIAL.
      RETURN.
    ENDIF.
    lt_db = CORRESPONDING #( it_events ).
    SORT lt_db BY area event_key.
    DELETE ADJACENT DUPLICATES FROM lt_db COMPARING area event_key.
    " an observation already stored (overlapping windows, repeated reads) is a duplicate key: kept as stored
    INSERT zca_ops_pfevt FROM TABLE @lt_db ACCEPTING DUPLICATE KEYS.
    rv_inserted = sy-dbcnt.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~get_events.
    DATA lt_part TYPE zif_ca_ops_pf_types=>tt_event.
    LOOP AT id_ranges( it_file_ids ) ASSIGNING FIELD-SYMBOL(<lt_range>).
      " index FIL (MANDT, AREA, FILE_ID)
      SELECT area, event_key, file_id, milestone, outcome, native_status, source_id, source_type, logsys, sys_client,
             bukrs, native_key, source_event_id, event_version, occurred_at, observed_at, bus_date, amount, currency,
             item_count, ack_scope, batch_id, pay_key, corr_quality, repeat_no, link_object, link_value, info,
             created_at
        FROM zca_ops_pfevt
        WHERE area    =  @iv_area
          AND file_id IN @<lt_range>
        ORDER BY file_id, occurred_at, event_key
        INTO CORRESPONDING FIELDS OF TABLE @lt_part.
      INSERT LINES OF lt_part INTO TABLE rt_events.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~events_by_source_id.
    IF it_ids IS INITIAL.
      RETURN.
    ENDIF.
    " index SRC (MANDT, AREA, SOURCE_ID, SOURCE_EVENT_ID)
    SELECT area, event_key, file_id, milestone, outcome, native_status, source_id, source_type, logsys, sys_client,
           bukrs, native_key, source_event_id, event_version, occurred_at, observed_at, bus_date, amount, currency,
           item_count, ack_scope, batch_id, pay_key, corr_quality, repeat_no, link_object, link_value, info,
           created_at
      FROM zca_ops_pfevt
      FOR ALL ENTRIES IN @it_ids
      WHERE area            = @iv_area
        AND source_id       = @iv_source_id
        AND source_event_id = @it_ids-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_events.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~save_milestones.
    DATA lt_db TYPE STANDARD TABLE OF zca_ops_pfmst WITH EMPTY KEY.
    LOOP AT id_ranges( it_file_ids ) ASSIGNING FIELD-SYMBOL(<lt_range>).
      DELETE FROM zca_ops_pfmst WHERE area = @iv_area AND file_id IN @<lt_range>.
    ENDLOOP.
    IF it_milestones IS INITIAL.
      RETURN.
    ENDIF.
    lt_db = CORRESPONDING #( it_milestones ).
    INSERT zca_ops_pfmst FROM TABLE @lt_db ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_db ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_PFMST'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~get_milestones.
    DATA lt_part TYPE zif_ca_ops_pf_types=>tt_ms.
    LOOP AT id_ranges( it_file_ids ) ASSIGNING FIELD-SYMBOL(<lt_range>).
      SELECT area, file_id, milestone, seq, required, status, outcome, due_at, observed_at, late_min, event_key,
             evaluated_at
        FROM zca_ops_pfmst
        WHERE area    =  @iv_area
          AND file_id IN @<lt_range>
        ORDER BY file_id, seq
        INTO CORRESPONDING FIELDS OF TABLE @lt_part.
      INSERT LINES OF lt_part INTO TABLE rt_milestones.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~get_totals.
    DATA lt_part TYPE zif_ca_ops_pf_types=>tt_total.
    DATA lv_none TYPE zif_ca_ops_pf_types=>ty_file_id.
    LOOP AT id_ranges( it_file_ids ) ASSIGNING FIELD-SYMBOL(<lt_range>).
      " gross per file and currency, and of it the payments without a known amount
      SELECT file_id, currency, COUNT( * ) AS pay_count, SUM( amount ) AS amount
        FROM zca_ops_pfpay
        WHERE area    =  @iv_area
          AND file_id IN @<lt_range>
        GROUP BY file_id, currency
        INTO CORRESPONDING FIELDS OF TABLE @lt_part.
      SELECT file_id, currency, COUNT( * ) AS unknown_count
        FROM zca_ops_pfpay
        WHERE area         =  @iv_area
          AND file_id      IN @<lt_range>
          AND amount_known =  @abap_false
        GROUP BY file_id, currency
        INTO TABLE @DATA(lt_unknown).
      " possible duplicate exposure: payments another file of the area carries too
      SELECT file_id, currency, COUNT( * ) AS dup_count, SUM( amount ) AS dup_amount
        FROM zca_ops_pfpay
        WHERE area       =  @iv_area
          AND file_id    IN @<lt_range>
          AND other_file <> @lv_none
        GROUP BY file_id, currency
        INTO TABLE @DATA(lt_dup).
      LOOP AT lt_part ASSIGNING FIELD-SYMBOL(<ls_total>).
        <ls_total>-unknown_count = VALUE #( lt_unknown[ file_id  = <ls_total>-file_id
                                                        currency = <ls_total>-currency ]-unknown_count OPTIONAL ).
        DATA(ls_dup) = VALUE #( lt_dup[ file_id = <ls_total>-file_id currency = <ls_total>-currency ] OPTIONAL ).
        <ls_total>-dup_count  = ls_dup-dup_count.
        <ls_total>-dup_amount = ls_dup-dup_amount.
      ENDLOOP.
      INSERT LINES OF lt_part INTO TABLE rt_totals.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~save_days.
    DATA lt_db TYPE STANDARD TABLE OF zca_ops_pfday WITH EMPTY KEY.
    IF it_days IS INITIAL.
      RETURN.
    ENDIF.
    lt_db = CORRESPONDING #( it_days ).
    MODIFY zca_ops_pfday FROM TABLE @lt_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_PFDAY'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~get_days.
    DATA lt_types TYPE RANGE OF zif_ca_ops_pf_types=>ty_file_type.
    IF iv_file_type IS NOT INITIAL.
      lt_types = VALUE #( ( sign = 'I' option = 'EQ' low = iv_file_type ) ).
    ENDIF.
    SELECT area, file_type, bus_date, day_kind, expected, observed, result, reason, as_of, watermark, completeness,
           eval_at, last_valid_result, last_valid_at
      FROM zca_ops_pfday
      WHERE area      =  @iv_area
        AND file_type IN @lt_types
        AND bus_date  >= @iv_from
      ORDER BY file_type, bus_date
      INTO CORRESPONDING FIELDS OF TABLE @rt_days.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~delete_before.
    DATA lt_ids TYPE zif_ca_ops_pf_types=>tt_file_id.
    SELECT file_id
      FROM zca_ops_pffile
      WHERE area      = @iv_area
        AND file_type = @iv_file_type
        AND bus_date  < @iv_before
      INTO TABLE @lt_ids.
    LOOP AT id_ranges( lt_ids ) ASSIGNING FIELD-SYMBOL(<lt_range>).
      DELETE FROM zca_ops_pfpay WHERE area = @iv_area AND file_id IN @<lt_range>.
      DELETE FROM zca_ops_pfevt WHERE area = @iv_area AND file_id IN @<lt_range>.
      DELETE FROM zca_ops_pfmst WHERE area = @iv_area AND file_id IN @<lt_range>.
      DELETE FROM zca_ops_pffile WHERE area = @iv_area AND file_id IN @<lt_range>.
      rv_count += sy-dbcnt.
    ENDLOOP.
    DELETE FROM zca_ops_pfday WHERE area = @iv_area AND file_type = @iv_file_type AND bus_date < @iv_before.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_dao~commit.
    COMMIT WORK.
  ENDMETHOD.


  METHOD id_ranges.
    DATA lt_range TYPE tt_id_range.
    LOOP AT it_file_ids ASSIGNING FIELD-SYMBOL(<lv_id>).
      INSERT VALUE #( sign = 'I' option = 'EQ' low = <lv_id> ) INTO TABLE lt_range.
      IF lines( lt_range ) >= gc_package.
        INSERT lt_range INTO TABLE rt_ranges.
        CLEAR lt_range.
      ENDIF.
    ENDLOOP.
    IF lt_range IS NOT INITIAL.
      INSERT lt_range INTO TABLE rt_ranges.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
