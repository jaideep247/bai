*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_rules.clas.abap
*& Purpose:
*& Pure FMON domain rules (no database, no clock, no function payment engine areas):
*& interface defaults, day types, expectations, SLA verdicts, ack match,
*& duplicates, size, lot outcome, NOC aging. Check classes call these.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A38-A41: SLA admissible evidence / INFERRED, reported ACK counts only,
*&              truncated lots derive nothing, unknown age no verdict, receipt correction.
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - pure domain rules</p>
CLASS zcl_cd_fmon_rules DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! Interface of a file. A configured interface (source adapter row) wins.
    "! Otherwise the active row whose CP name pattern matches and whose
    "! source / LOB are blank, '*' or equal to the record's values; the most
    "! specific row wins (pattern characters, then exact source, then LOB).
    "! Blank/'*' rows are therefore defaults: a new source or LOB needs no code.
    CLASS-METHODS resolve_iface
      IMPORTING
        it_ifaces       TYPE zif_cd_fmon_types=>tt_iface
        iv_iface_id     TYPE zif_cd_fmon_types=>ty_iface_id OPTIONAL
        iv_file_name    TYPE clike
        iv_source       TYPE zif_cd_fmon_types=>ty_system OPTIONAL
        iv_lob          TYPE zif_cd_fmon_types=>ty_lob OPTIONAL
      RETURNING
        VALUE(rs_iface) TYPE zif_cd_fmon_types=>ty_iface.

    "! HOLIDAY (non-working) > MONTH_END (last working day) > RETURNS_DAY > NORMAL
    CLASS-METHODS day_type
      IMPORTING
        iv_working_day     TYPE abap_bool
        iv_month_end       TYPE abap_bool
        iv_date            TYPE d
        iv_returns_days    TYPE string
      RETURNING
        VALUE(rv_day_type) TYPE zif_cd_fmon_types=>ty_day_type.

    "! ISO weekday, 1 = Monday
    CLASS-METHODS weekday
      IMPORTING
        iv_date           TYPE d
      RETURNING
        VALUE(rv_weekday) TYPE i.

    "! Calendar row for the day type; MONTH_END / RETURNS_DAY fall back to
    "! NORMAL, HOLIDAY never does (initial = nothing expected)
    CLASS-METHODS pick_calendar_row
      IMPORTING
        it_cals       TYPE zif_cd_fmon_types=>tt_cal
        iv_iface_id   TYPE zif_cd_fmon_types=>ty_iface_id
        iv_day_type   TYPE zif_cd_fmon_types=>ty_day_type
      RETURNING
        VALUE(rs_cal) TYPE zif_cd_fmon_types=>ty_cal.

    "! FILE_MISSING / FILE_LATE / UNEXPECTED_FILE / blank
    CLASS-METHODS expectation_code
      IMPORTING
        is_expect      TYPE zif_cd_fmon_types=>ty_expect
        iv_received    TYPE i
        iv_now         TYPE timestampl
        iv_grace_min   TYPE i
      RETURNING
        VALUE(rv_code) TYPE zif_cd_ops_types=>ty_check_code.

    CLASS-METHODS arrived_late
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
        is_expect      TYPE zif_cd_fmon_types=>ty_expect
      RETURNING
        VALUE(rv_late) TYPE abap_bool.

    "! SLA of one stage for one file. Only admissible evidence meets it (audit A40): an
    "! event of the SLA stage itself, or NACK for the ACK stage (the bank's response).
    "! PARTIALLY / FAILED never meet a processing SLA. A later stage without the SLA
    "! stage's own event is INFERRED, not met. Basis P = latest event of the highest
    "! lower rank, G = first event.
    CLASS-METHODS sla_verdict
      IMPORTING
        is_file           TYPE zif_cd_fmon_types=>ty_file
        is_sla            TYPE zif_cd_fmon_types=>ty_sla
        it_events         TYPE zif_cd_fmon_types=>tt_event
        iv_now            TYPE timestampl
      RETURNING
        VALUE(rs_verdict) TYPE zif_cd_fmon_types=>ty_sla_verdict.

    "! NO_<label> for missing, <label>_LATE for late, blank for ok
    CLASS-METHODS sla_code
      IMPORTING
        iv_stage       TYPE zif_cd_fmon_types=>ty_stage
        iv_state       TYPE zif_cd_fmon_types=>ty_sla_state
      RETURNING
        VALUE(rv_code) TYPE zif_cd_ops_types=>ty_check_code.

    "! Record count known, ACK/NACK count reported (ACK_KNOWN) and ACK + NACK <> record count
    CLASS-METHODS ack_count_mismatch
      IMPORTING
        is_file            TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_mismatch) TYPE abap_bool.

    "! No NACK, both amounts reported and |control total - ack amount| > tolerance
    CLASS-METHODS ack_amount_mismatch
      IMPORTING
        is_file            TYPE zif_cd_fmon_types=>ty_file
        iv_tolerance       TYPE zif_cd_ops_types=>ty_amount
      RETURNING
        VALUE(rv_mismatch) TYPE abap_bool.

    "! is_other is an earlier file of the same interface with the same name or checksum
    CLASS-METHODS is_duplicate_of
      IMPORTING
        is_file             TYPE zif_cd_fmon_types=>ty_file
        is_other            TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_duplicate) TYPE abap_bool.

    "! ZERO_BYTE / SIZE_OUT_OF_BOUNDS / blank (only when the size is known)
    CLASS-METHODS size_code
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
        is_iface       TYPE zif_cd_fmon_types=>ty_iface
      RETURNING
        VALUE(rv_code) TYPE zif_cd_ops_types=>ty_check_code.

    "! Outcome derived from lot completeness: open > 0 PARTIALLY, else FULLY;
    "! blank when no lot was found
    CLASS-METHODS lot_outcome
      IMPORTING
        is_lot          TYPE zif_cd_fmon_types=>ty_lot_status
      RETURNING
        VALUE(rv_stage) TYPE zif_cd_fmon_types=>ty_stage.

    "! NOC with open items: age > SLA days NOC_AGING, age = SLA days NOC_DUE_TODAY
    CLASS-METHODS noc_aging_code
      IMPORTING
        is_lot         TYPE zif_cd_fmon_types=>ty_lot_status
      RETURNING
        VALUE(rv_code) TYPE zif_cd_ops_types=>ty_check_code.

    "! Item status is in the comma list (case-insensitive; <BLANK> = initial)
    CLASS-METHODS is_done
      IMPORTING
        iv_status      TYPE clike
        iv_done_values TYPE clike
      RETURNING
        VALUE(rv_done) TYPE abap_bool.

    "! Correction option for the receipt date of a banking-day age (audit A41):
    "! A (default) = days strictly after receipt, so a non-working receipt day moves back;
    "! N = count from the next working day
    CLASS-METHODS receipt_correction
      IMPORTING
        iv_basis          TYPE zif_cd_fmon_types=>ty_age_basis
      RETURNING
        VALUE(rv_correct) TYPE zif_cd_fmon_types=>ty_fcal_correct.

    "! The event stage is admissible evidence for the SLA stage (same stage; NACK for ACK)
    CLASS-METHODS is_admissible
      IMPORTING
        iv_sla_stage         TYPE zif_cd_fmon_types=>ty_stage
        iv_event_stage       TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_admissible) TYPE abap_bool.

    "! Lot-controlled interfaces: a source FULLY/PARTIALLY is capped at FILE_LOADED
    CLASS-METHODS cap_stage
      IMPORTING
        iv_stage          TYPE zif_cd_fmon_types=>ty_stage
        iv_lot_controlled TYPE abap_bool
      RETURNING
        VALUE(rv_stage)   TYPE zif_cd_fmon_types=>ty_stage.

    "! Active lot row of the interface, else of '*', else of blank
    CLASS-METHODS lot_cfg_for
      IMPORTING
        it_cfgs       TYPE zif_cd_fmon_types=>tt_lotcfg
        iv_iface_id   TYPE zif_cd_fmon_types=>ty_iface_id
        iv_lot_type   TYPE zif_cd_fmon_types=>ty_lot_type
      RETURNING
        VALUE(rs_cfg) TYPE zif_cd_fmon_types=>ty_lotcfg.

  PRIVATE SECTION.

    CLASS-METHODS dimension_matches
      IMPORTING
        iv_configured     TYPE clike
        iv_actual         TYPE clike
      RETURNING
        VALUE(rv_matches) TYPE abap_bool.

    CLASS-METHODS is_specific
      IMPORTING
        iv_configured      TYPE clike
        iv_actual          TYPE clike
      RETURNING
        VALUE(rv_specific) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_fmon_rules IMPLEMENTATION.

  METHOD resolve_iface.
    DATA lv_best TYPE i VALUE -1.

    IF iv_iface_id IS NOT INITIAL.
      READ TABLE it_ifaces INTO DATA(ls_fixed) WITH TABLE KEY iface_id = iv_iface_id.
      IF sy-subrc = 0 AND ls_fixed-active = abap_true.
        rs_iface = ls_fixed.
      ENDIF.
      RETURN.
    ENDIF.

    DATA(lv_name) = to_upper( condense( CONV string( iv_file_name ) ) ).
    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_ifaces ASSIGNING FIELD-SYMBOL(<ls_iface>) WHERE active = abap_true.
      DATA(lv_pattern) = to_upper( condense( CONV string( <ls_iface>-name_pattern ) ) ).
      IF lv_pattern IS INITIAL OR lv_name NP lv_pattern.
        CONTINUE.
      ENDIF.
      IF dimension_matches( iv_configured = <ls_iface>-source_sys iv_actual = iv_source ) = abap_false
         OR dimension_matches( iv_configured = <ls_iface>-lob iv_actual = iv_lob ) = abap_false.
        CONTINUE.
      ENDIF.
      DATA(lv_score) = ( strlen( lv_pattern ) - count( val = lv_pattern sub = `*` )
                                              - count( val = lv_pattern sub = `+` ) ) * 4.
      IF is_specific( iv_configured = <ls_iface>-source_sys iv_actual = iv_source ) = abap_true.
        lv_score += 2.
      ENDIF.
      IF is_specific( iv_configured = <ls_iface>-lob iv_actual = iv_lob ) = abap_true.
        lv_score += 1.
      ENDIF.
      IF lv_score > lv_best.
        lv_best  = lv_score.
        rs_iface = <ls_iface>.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD dimension_matches.
    rv_matches = xsdbool( iv_configured IS INITIAL
                       OR iv_configured = zif_cd_fmon_types=>gc_wildcard
                       OR iv_actual IS INITIAL
                       OR to_upper( iv_configured ) = to_upper( iv_actual ) ).
  ENDMETHOD.


  METHOD is_specific.
    rv_specific = xsdbool( iv_configured IS NOT INITIAL
                       AND iv_configured <> zif_cd_fmon_types=>gc_wildcard
                       AND iv_actual IS NOT INITIAL
                       AND to_upper( iv_configured ) = to_upper( iv_actual ) ).
  ENDMETHOD.


  METHOD day_type.
    IF iv_working_day = abap_false.
      rv_day_type = zif_cd_fmon_types=>gc_day_type-holiday.
    ELSEIF iv_month_end = abap_true.
      rv_day_type = zif_cd_fmon_types=>gc_day_type-month_end.
    ELSE.
      rv_day_type = zif_cd_fmon_types=>gc_day_type-normal.
      DATA(lt_days) = zcl_cd_ops_util=>split_list( iv_returns_days ).
      DATA(lv_weekday) = |{ weekday( iv_date ) }|.
      IF line_exists( lt_days[ table_line = lv_weekday ] ).
        rv_day_type = zif_cd_fmon_types=>gc_day_type-returns_day.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD weekday.
    " 1900-01-01 was a Monday
    CONSTANTS lc_monday TYPE d VALUE '19000101'.
    rv_weekday = ( iv_date - lc_monday ) MOD 7 + 1.
  ENDMETHOD.


  METHOD pick_calendar_row.
    READ TABLE it_cals INTO rs_cal WITH TABLE KEY iface_id = iv_iface_id
                                                  day_type = iv_day_type.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    CLEAR rs_cal.
    IF iv_day_type = zif_cd_fmon_types=>gc_day_type-holiday
       OR iv_day_type = zif_cd_fmon_types=>gc_day_type-normal.
      RETURN.
    ENDIF.
    READ TABLE it_cals INTO rs_cal WITH TABLE KEY iface_id = iv_iface_id
                                                  day_type = zif_cd_fmon_types=>gc_day_type-normal.
    IF sy-subrc <> 0.
      CLEAR rs_cal.
    ENDIF.
  ENDMETHOD.


  METHOD expectation_code.
    IF is_expect-expected_count = 0.
      IF iv_received > 0.
        rv_code = zif_cd_fmon_types=>gc_check_code-unexpected_file.
      ENDIF.
      RETURN.
    ENDIF.
    IF iv_received >= is_expect-expected_count OR is_expect-ts_to IS INITIAL.
      RETURN.
    ENDIF.
    IF iv_now > zcl_cd_fmon_util=>add_minutes( iv_timestamp = is_expect-ts_to
                                               iv_minutes   = iv_grace_min ).
      rv_code = zif_cd_fmon_types=>gc_check_code-file_missing.
    ELSEIF iv_now > is_expect-ts_to.
      rv_code = zif_cd_fmon_types=>gc_check_code-file_late.
    ENDIF.
  ENDMETHOD.


  METHOD arrived_late.
    rv_late = xsdbool( is_expect-ts_to IS NOT INITIAL
                   AND is_file-first_event_at IS NOT INITIAL
                   AND is_file-first_event_at > is_expect-ts_to ).
  ENDMETHOD.


  METHOD sla_verdict.
    DATA lv_prev_rank TYPE i.
    DATA lv_prev_at TYPE timestampl.
    DATA lv_reached TYPE timestampl.
    DATA lv_beyond TYPE abap_bool.

    DATA(lv_target) = zcl_cd_fmon_status=>rank( is_sla-stage ).
    IF lv_target = 0 OR zcl_cd_fmon_status=>direction_of( is_sla-stage ) <> is_file-direction.
      RETURN.
    ENDIF.

    " Sweep: by key (the verdict does not depend on the order of the events)
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>) USING KEY by_file WHERE file_id = is_file-file_id.
      IF zcl_cd_fmon_status=>direction_of( <ls_event>-stage ) <> is_file-direction.
        CONTINUE.
      ENDIF.
      DATA(lv_rank) = zcl_cd_fmon_status=>rank( <ls_event>-stage ).
      IF is_admissible( iv_sla_stage = is_sla-stage iv_event_stage = <ls_event>-stage ) = abap_true.
        IF lv_reached IS INITIAL OR <ls_event>-event_at < lv_reached.
          lv_reached = <ls_event>-event_at.
        ENDIF.
      ELSEIF lv_rank > lv_target.
        lv_beyond = abap_true.
      ELSEIF lv_rank < lv_target
         AND ( lv_rank > lv_prev_rank OR ( lv_rank = lv_prev_rank AND <ls_event>-event_at > lv_prev_at ) ).
        lv_prev_rank = lv_rank.
        lv_prev_at   = <ls_event>-event_at.
      ENDIF.
    ENDLOOP.

    " The registry state counts only as admissible evidence, never by rank alone
    IF lv_reached IS INITIAL
       AND ( is_admissible( iv_sla_stage = is_sla-stage iv_event_stage = is_file-stage ) = abap_true
             OR is_admissible( iv_sla_stage = is_sla-stage iv_event_stage = is_file-outcome ) = abap_true ).
      lv_reached = is_file-last_event_at.
    ENDIF.
    IF lv_reached IS INITIAL AND zcl_cd_fmon_status=>rank( is_file-stage ) > lv_target.
      lv_beyond = abap_true.
    ENDIF.

    rs_verdict-basis_at   = COND #( WHEN is_sla-basis = zif_cd_fmon_types=>gc_sla_basis-generation
                                    THEN is_file-first_event_at
                                    ELSE lv_prev_at ).
    rs_verdict-reached_at = lv_reached.
    IF lv_reached IS INITIAL AND lv_beyond = abap_true.
      " A later stage was observed without the SLA stage's own event: not evidenced
      rs_verdict-state = zif_cd_fmon_types=>gc_sla_state-inferred.
      RETURN.
    ENDIF.
    IF rs_verdict-basis_at IS INITIAL.
      RETURN.
    ENDIF.

    IF lv_reached IS INITIAL.
      rs_verdict-elapsed_min = zcl_cd_fmon_util=>minutes_between( iv_from = rs_verdict-basis_at
                                                                  iv_to   = iv_now ).
      IF rs_verdict-elapsed_min > is_sla-max_minutes.
        rs_verdict-state = zif_cd_fmon_types=>gc_sla_state-missing.
      ENDIF.
    ELSE.
      rs_verdict-elapsed_min = zcl_cd_fmon_util=>minutes_between( iv_from = rs_verdict-basis_at
                                                                  iv_to   = lv_reached ).
      IF rs_verdict-elapsed_min > is_sla-max_minutes.
        rs_verdict-state = zif_cd_fmon_types=>gc_sla_state-late.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD is_admissible.
    rv_admissible = xsdbool( iv_event_stage IS NOT INITIAL
                         AND ( iv_event_stage = iv_sla_stage
                               OR ( iv_sla_stage = zif_cd_fmon_types=>gc_stage-ack
                                    AND iv_event_stage = zif_cd_fmon_types=>gc_stage-nack ) ) ).
  ENDMETHOD.


  METHOD receipt_correction.
    rv_correct = COND #( WHEN iv_basis = zif_cd_fmon_types=>gc_age_basis-next_working
                         THEN zif_cd_fmon_types=>gc_fcal_correct-next
                         ELSE zif_cd_fmon_types=>gc_fcal_correct-previous ).
  ENDMETHOD.


  METHOD sla_code.
    DATA(lv_label) = SWITCH string( iv_stage
                                    WHEN zif_cd_fmon_types=>gc_stage-sent      THEN `PRISM_HANDOFF`
                                    WHEN zif_cd_fmon_types=>gc_stage-forwarded THEN `BANK_FORWARD`
                                    WHEN zif_cd_fmon_types=>gc_stage-ack       THEN `BANK_ACK`
                                    WHEN zif_cd_fmon_types=>gc_stage-loaded    THEN `FILE_LOAD`
                                    WHEN zif_cd_fmon_types=>gc_stage-fully     THEN `PROCESSING`
                                    ELSE condense( iv_stage ) ).
    rv_code = SWITCH #( iv_state
                        WHEN zif_cd_fmon_types=>gc_sla_state-missing THEN zif_cd_fmon_types=>gc_sla_code-missing_prefix && lv_label
                        WHEN zif_cd_fmon_types=>gc_sla_state-late    THEN lv_label && zif_cd_fmon_types=>gc_sla_code-late_suffix
                        WHEN zif_cd_fmon_types=>gc_sla_state-inferred
                          THEN lv_label && zif_cd_fmon_types=>gc_sla_code-inferred_suffix
                        ELSE `` ).
  ENDMETHOD.


  METHOD ack_count_mismatch.
    " Audit A39: only a count the source reported is compared (a reported 0 is a fact,
    " an unreported count is unknown); ACK + NACK together are the bank's responses
    IF is_file-record_count <= 0 OR is_file-ack_known = abap_false.
      RETURN.
    ENDIF.
    rv_mismatch = xsdbool( is_file-ack_count + is_file-nack_count <> is_file-record_count ).
  ENDMETHOD.


  METHOD ack_amount_mismatch.
    rv_mismatch = xsdbool( is_file-nack_count = 0
                       AND is_file-control_total <> 0
                       AND is_file-ack_amount <> 0
                       AND abs( is_file-control_total - is_file-ack_amount ) > iv_tolerance ).
  ENDMETHOD.


  METHOD is_duplicate_of.
    IF is_other-file_id = is_file-file_id OR is_other-iface_id <> is_file-iface_id.
      RETURN.
    ENDIF.
    DATA(lv_same) = xsdbool( ( is_file-file_name IS NOT INITIAL AND is_other-file_name = is_file-file_name )
                          OR ( is_file-checksum IS NOT INITIAL AND is_other-checksum = is_file-checksum ) ).
    IF lv_same = abap_false.
      RETURN.
    ENDIF.
    rv_duplicate = xsdbool( is_other-first_event_at < is_file-first_event_at
                         OR ( is_other-first_event_at = is_file-first_event_at
                              AND is_other-file_id < is_file-file_id ) ).
  ENDMETHOD.


  METHOD size_code.
    IF is_file-size_known = abap_false.
      RETURN.
    ENDIF.
    IF is_file-size_bytes = 0.
      rv_code = zif_cd_fmon_types=>gc_check_code-zero_byte.
    ELSEIF is_file-size_bytes < is_iface-min_bytes
        OR ( is_iface-max_bytes > 0 AND is_file-size_bytes > is_iface-max_bytes ).
      rv_code = zif_cd_fmon_types=>gc_check_code-size_bounds.
    ENDIF.
  ENDMETHOD.


  METHOD lot_outcome.
    " Audit A38: a scan stopped at the row cap cannot prove completion
    IF is_lot-found = abap_false OR is_lot-total_items = 0 OR is_lot-truncated = abap_true.
      RETURN.
    ENDIF.
    rv_stage = COND #( WHEN is_lot-open_items > 0 THEN zif_cd_fmon_types=>gc_stage-partially
                       ELSE zif_cd_fmon_types=>gc_stage-fully ).
  ENDMETHOD.


  METHOD noc_aging_code.
    " Audit A41: an age the calendar could not determine gives no verdict
    IF is_lot-lot_type <> zif_cd_fmon_types=>gc_lot_type-noc OR is_lot-open_items = 0 OR is_lot-sla_days <= 0
       OR is_lot-age_days < 0.
      RETURN.
    ENDIF.
    IF is_lot-age_days > is_lot-sla_days.
      rv_code = zif_cd_fmon_types=>gc_check_code-noc_aging.
    ELSEIF is_lot-age_days = is_lot-sla_days.
      rv_code = zif_cd_fmon_types=>gc_check_code-noc_due_today.
    ENDIF.
  ENDMETHOD.


  METHOD is_done.
    DATA(lv_status) = to_upper( condense( CONV string( iv_status ) ) ).
    IF lv_status IS INITIAL.
      lv_status = zif_cd_fmon_types=>gc_blank_token.
    ENDIF.
    LOOP AT zcl_cd_ops_util=>split_list( iv_done_values ) ASSIGNING FIELD-SYMBOL(<lv_token>).
      IF to_upper( <lv_token> ) = lv_status.
        rv_done = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD cap_stage.
    rv_stage = iv_stage.
    IF iv_lot_controlled = abap_true
       AND ( iv_stage = zif_cd_fmon_types=>gc_stage-fully OR iv_stage = zif_cd_fmon_types=>gc_stage-partially ).
      rv_stage = zif_cd_fmon_types=>gc_stage-loaded.
    ENDIF.
  ENDMETHOD.


  METHOD lot_cfg_for.
    DATA lt_candidates TYPE STANDARD TABLE OF zif_cd_fmon_types=>ty_iface_id WITH EMPTY KEY.
    lt_candidates = VALUE #( ( iv_iface_id ) ( zif_cd_fmon_types=>gc_wildcard ) ( `` ) ).
    LOOP AT lt_candidates ASSIGNING FIELD-SYMBOL(<lv_iface>).
      READ TABLE it_cfgs INTO rs_cfg WITH TABLE KEY iface_id = <lv_iface>
                                                    lot_type = iv_lot_type.
      IF sy-subrc = 0 AND rs_cfg-active = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
    CLEAR rs_cfg.
  ENDMETHOD.

ENDCLASS.
