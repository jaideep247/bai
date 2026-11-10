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
*& 2026-11-06 | PRISM status API: SLA verdict ranks stages in the file's direction (PRISM_*).
*& 2026-11-06 | Modern-syntax sweep: NP.
*& 2026-11-06 | PRISM throttle (user 2026-11-06): throttled files, PRISM queue and position,
*&              queue allowance in the SLA verdict of the delivery stage and later stages.
*& 2026-11-06 | Interface name patterns are PCRE matched to the complete file name (case ignored);
*&              specificity = literal characters of the pattern (ZCL_CD_OPS_UTIL=>PCRE_LITERALS).
*& 2026-11-07 | Design review: FILE_INSTANCE - file generation identity (the instance is fixed by
*&              the file's first evidence; later events attach whatever their date or time).
*& 2026-11-07 | Regenerated files (user 2026-11-07): GENERATION_KEY, PREVIOUS_ / NEXT_GENERATION,
*&            | FAILED_VERDICT (replaced / duplicate name / regeneration missing), UNFAILED_PREDECESSOR
*&            | (a regenerated file whose earlier generation did not fail); FILE_INSTANCE comment: the
*&            | reference is unique per generation (confirmed by the user 2026-11-07).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - pure domain rules</p>
CLASS zcl_cd_fmon_rules DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! Interface of a file. A configured interface (source adapter row) wins.
    "! Otherwise the active row whose name pattern (PCRE, complete file name,
    "! case ignored; blank = not resolved by name) matches and whose
    "! source / LOB are blank, '*' or equal to the record's values; the most
    "! specific row wins (literal pattern characters, then exact source, then LOB).
    "! An invalid pattern never matches; the engine reports it (PATTERN_INVALID).
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
        VALUE(rv_code) TYPE zif_ca_ops_types=>ty_check_code.

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
    "! PRISM throttle: iv_queue_min (QUEUE_POSITION-DELAY_MIN) is added to the SLA minutes of an
    "! outbound stage at or after delivery (PRISM_DELIVERED = FORWARDED_TO_BANK, ACK) when the
    "! basis lies before the delivery: basis G, or basis P measured from a stage below delivery.
    "! A basis P stage measured from the recorded delivery (e.g. ACK after PRISM_DELIVERED) is
    "! not shifted - the queue wait is already behind it.
    CLASS-METHODS sla_verdict
      IMPORTING
        is_file           TYPE zif_cd_fmon_types=>ty_file
        is_sla            TYPE zif_cd_fmon_types=>ty_sla
        it_events         TYPE zif_cd_fmon_types=>tt_event
        iv_now            TYPE timestampl
        iv_queue_min      TYPE i DEFAULT 0
      RETURNING
        VALUE(rs_verdict) TYPE zif_cd_fmon_types=>ty_sla_verdict.

    "! PRISM throttles the file (user 2026-11-06): throttle on (minutes > 0), outbound interface
    "! and its payment method in the configured list (ACH, WIRE). Positive pay, stop pay, IRIS,
    "! BlackLine, OFSAA and source files are not throttled.
    CLASS-METHODS is_throttled
      IMPORTING
        is_iface            TYPE zif_cd_fmon_types=>ty_iface
        is_throttle         TYPE zif_cd_fmon_types=>ty_throttle
      RETURNING
        VALUE(rv_throttled) TYPE abap_bool.

    "! Stage the PRISM queue delays: delivery rank in the outbound direction
    "! (PRISM_DELIVERED, FORWARDED_TO_BANK)
    CLASS-METHODS is_queue_stage
      IMPORTING
        iv_stage        TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_queue) TYPE abap_bool.

    "! PRISM queue of the throttled files with PRISM receipt evidence: received = first
    "! PRISM_RECEIVED event, left = first event at delivery rank or later (PRISM_DELIVERED,
    "! FORWARDED_TO_BANK, PRISM_FAILED, ACK / NACK). Queue key per scope (A blank, C bank key).
    "! Empty when the throttle is off.
    CLASS-METHODS build_queue
      IMPORTING
        it_files        TYPE zif_cd_fmon_types=>tt_file
        it_events       TYPE zif_cd_fmon_types=>tt_event
        it_ifaces       TYPE zif_cd_fmon_types=>tt_iface
        is_throttle     TYPE zif_cd_fmon_types=>ty_throttle
      RETURNING
        VALUE(rt_queue) TYPE zif_cd_fmon_types=>tt_queue.

    "! Files ahead of the file in its queue when PRISM received it: same business date and
    "! queue key, received earlier or at the same time (PRISM's order within one instant is
    "! unknown, so a tie counts as ahead - never a false late) and not yet sent on at that
    "! moment. The allowance counts at most QUEUE_MAX - 1 files; a longer queue is LONG.
    "! A file without a queue entry (not throttled, no receipt evidence) is not QUEUED.
    CLASS-METHODS queue_position
      IMPORTING
        iv_file_id    TYPE zif_cd_fmon_types=>ty_file_id
        it_queue      TYPE zif_cd_fmon_types=>tt_queue
        is_throttle   TYPE zif_cd_fmon_types=>ty_throttle
      RETURNING
        VALUE(rs_pos) TYPE zif_cd_fmon_types=>ty_queue_pos.

    "! NO_<label> for missing, <label>_LATE for late, blank for ok
    CLASS-METHODS sla_code
      IMPORTING
        iv_stage       TYPE zif_cd_fmon_types=>ty_stage
        iv_state       TYPE zif_cd_fmon_types=>ty_sla_state
      RETURNING
        VALUE(rv_code) TYPE zif_ca_ops_types=>ty_check_code.

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
        iv_tolerance       TYPE zif_ca_ops_types=>ty_amount
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
        VALUE(rv_code) TYPE zif_ca_ops_types=>ty_check_code.

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
        VALUE(rv_code) TYPE zif_ca_ops_types=>ty_check_code.

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

    "! File generation identity (design review 2026-11-07; replaces the date rule of audit A49).
    "! The instance of a file is fixed when the file is first known - outbound by its generation
    "! in SAP, inbound by the first of PRISM's receipt / delivery and SAP's receipt - and keeps the
    "! business date of that first evidence. Later evidence of the same interface + reference
    "! attaches to it whatever its own business date or time (midnight, daylight saving); only a
    "! new generation of the reference opens a new instance. In this order:
    "! <ol><li>an instance of the observation's own business date is that file (the generation
    "! date decides - one reference is one file per business date);</li>
    "! <li>else the latest instance of an earlier date: first evidence (IS_ORIGIN) of a stage the
    "! instance has already reached (ZCL_CD_FMON_STATUS=>REACHES) is a new generation - unless
    "! the instance recorded that very event (same source, stage and time: a re-read); every
    "! other observation attaches; an undated observation with several instances is ambiguous;</li>
    "! <li>else (only instances of later dates) first evidence not after the earliest one's first
    "! event attaches to it (earlier evidence that reached SAP late);</li>
    "! <li>otherwise none: blank ID - the caller opens an instance or defers.</li></ol>
    "! The reference is unique per file generation (confirmed by the user 2026-11-07: PRISM rejects a
    "! name it has already received); rule 4 keeps a reused inbound name of a later day apart.
    CLASS-METHODS file_instance
      IMPORTING
        is_obs         TYPE zif_cd_fmon_types=>ty_observation
        it_candidates  TYPE zif_cd_fmon_types=>tt_file
        it_events      TYPE zif_cd_fmon_types=>tt_event
      RETURNING
        VALUE(rs_pick) TYPE zif_cd_fmon_types=>ty_instance_pick.

    "! Generation group key of a file (regenerated files, user 2026-11-07): the values of the
    "! configured group fields condensed, joined by '/' up to the last non-blank value, upper case;
    "! longer than the reference = prefix + digest (ZCL_CD_FMON_UTIL=>NORMALIZE_REF). Every value
    "! blank = no key (the file is not linked).
    CLASS-METHODS generation_key
      IMPORTING
        it_values     TYPE string_table
      RETURNING
        VALUE(rv_key) TYPE zif_cd_fmon_types=>ty_file_ref.

    "! The latest generation of the file's interface and generation group generated before it
    "! (first event, then file ID); initial without a group or an earlier generation
    CLASS-METHODS previous_generation
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
        it_generations TYPE zif_cd_fmon_types=>tt_file
      RETURNING
        VALUE(rs_file) TYPE zif_cd_fmon_types=>ty_file.

    "! The first generation of the file's interface and generation group generated after it
    CLASS-METHODS next_generation
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
        it_generations TYPE zif_cd_fmon_types=>tt_file
      RETURNING
        VALUE(rs_file) TYPE zif_cd_fmon_types=>ty_file.

    "! Verdict on a file with outcome PRISM_FAILED (user 2026-11-07: SAP regenerates a file PRISM
    "! could not deliver under a new name for the same payments). In this order:
    "! <ol><li>a later generation of its group exists: FILE_REPLACED (the failure is answered;
    "! the new file follows its own SLA);</li>
    "! <li>a PRISM failure of this generation (not before its first event) carries an error code of
    "! the duplicate-name list (whole value, case ignored): PRISM_DUPLICATE_NAME - regenerate,
    "! do not resend;</li>
    "! <li>otherwise PRISM_FAILED, with REGENERATION_MISSING when the file has a generation group,
    "! the wait is on (> 0) and more minutes than the wait passed since the latest failure.</li></ol>
    "! A file without a generation group and an empty code list is PRISM_FAILED as before.
    CLASS-METHODS failed_verdict
      IMPORTING
        is_file           TYPE zif_cd_fmon_types=>ty_file
        it_generations    TYPE zif_cd_fmon_types=>tt_file
        it_events         TYPE zif_cd_fmon_types=>tt_event
        it_failures       TYPE zif_cd_fmon_types=>tt_prism_failure
        is_regen          TYPE zif_cd_fmon_types=>ty_regen
        iv_now            TYPE timestampl
      RETURNING
        VALUE(rs_verdict) TYPE zif_cd_fmon_types=>ty_failed_verdict.

    "! A regenerated file whose previous generation did not fail - delivered, acknowledged or still
    "! in flight (any outcome but PRISM_FAILED): that generation (FILE_REGENERATED_NOT_FAILED,
    "! possible duplicate payment file to the bank / IRIS); initial otherwise
    CLASS-METHODS unfailed_predecessor
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
        it_generations TYPE zif_cd_fmon_types=>tt_file
      RETURNING
        VALUE(rs_file) TYPE zif_cd_fmon_types=>ty_file.

  PRIVATE SECTION.

    "! is_first was generated before is_second (first event, then file ID: a strict order)
    CLASS-METHODS generated_before
      IMPORTING
        is_first         TYPE zif_cd_fmon_types=>ty_file
        is_second        TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_before) TYPE abap_bool.

    "! is_other is another generation of the file (same interface and non-blank group)
    CLASS-METHODS same_group
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
        is_other       TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_same) TYPE abap_bool.

    "! First evidence that continues the instance: the instance has not reached the stage yet
    "! (the rest of the file's first evidence, e.g. SAP's receipt after PRISM's delivery across
    "! midnight, or PRISM's delivery after a failure), or the instance recorded this very event
    CLASS-METHODS continues_file
      IMPORTING
        is_obs         TYPE zif_cd_fmon_types=>ty_observation
        is_file        TYPE zif_cd_fmon_types=>ty_file
        it_events      TYPE zif_cd_fmon_types=>tt_event
      RETURNING
        VALUE(rv_same) TYPE abap_bool.

    "! Queue of a throttled interface: blank (scope A), else its bank key ('*' when blank)
    CLASS-METHODS queue_key
      IMPORTING
        is_iface      TYPE zif_cd_fmon_types=>ty_iface
        iv_scope      TYPE zif_cd_fmon_types=>ty_queue_scope
      RETURNING
        VALUE(rv_key) TYPE zif_cd_fmon_types=>ty_bank_key.

    "! Outbound rank at which a file has left the PRISM queue (= PRISM_DELIVERED)
    CLASS-METHODS delivery_rank
      RETURNING
        VALUE(rv_rank) TYPE i.

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

    DATA(lv_name) = condense( CONV string( iv_file_name ) ).
    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_ifaces ASSIGNING FIELD-SYMBOL(<ls_iface>) WHERE active = abap_true.
      DATA(lv_pattern) = condense( CONV string( <ls_iface>-name_pattern ) ).
      IF lv_pattern IS INITIAL
         OR zcl_ca_ops_util=>pcre_match( iv_value = lv_name iv_pattern = lv_pattern ) = abap_false.
        CONTINUE.
      ENDIF.
      IF dimension_matches( iv_configured = <ls_iface>-source_sys iv_actual = iv_source ) = abap_false
         OR dimension_matches( iv_configured = <ls_iface>-lob iv_actual = iv_lob ) = abap_false.
        CONTINUE.
      ENDIF.
      DATA(lv_score) = zcl_ca_ops_util=>pcre_literals( lv_pattern ) * 4.
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
      DATA(lt_days) = zcl_ca_ops_util=>split_list( iv_returns_days ).
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

    " Ranks in the file's direction: PRISM_* stages belong to both directions
    DATA(lv_target) = zcl_cd_fmon_status=>rank( iv_stage     = is_sla-stage
                                                iv_direction = is_file-direction ).
    IF lv_target = 0.
      RETURN.
    ENDIF.

    " Sweep: by key (the verdict does not depend on the order of the events); ranks in the
    " file's direction - PRISM_* stages belong to both directions
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>) USING KEY by_file WHERE file_id = is_file-file_id.
      DATA(lv_rank) = zcl_cd_fmon_status=>rank( iv_stage     = <ls_event>-stage
                                                iv_direction = is_file-direction ).
      IF lv_rank = 0.
        CONTINUE.
      ENDIF.
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
    IF lv_reached IS INITIAL
       AND zcl_cd_fmon_status=>rank( iv_stage = is_file-stage iv_direction = is_file-direction ) > lv_target.
      lv_beyond = abap_true.
    ENDIF.

    rs_verdict-basis_at   = COND #( WHEN is_sla-basis = zif_cd_fmon_types=>gc_sla_basis-generation
                                    THEN is_file-first_event_at
                                    ELSE lv_prev_at ).
    rs_verdict-reached_at = lv_reached.
    " PRISM throttle: the queue wait lies between the basis and the stage only when the basis is
    " before the delivery (G, or P from a stage below delivery)
    IF iv_queue_min > 0
       AND is_file-direction = zif_cd_fmon_types=>gc_direction-outbound
       AND lv_target >= delivery_rank( )
       AND ( is_sla-basis = zif_cd_fmon_types=>gc_sla_basis-generation OR lv_prev_rank < delivery_rank( ) ).
      rs_verdict-queue_min = iv_queue_min.
    ENDIF.
    rs_verdict-allowed_min = is_sla-max_minutes + rs_verdict-queue_min.
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
      IF rs_verdict-elapsed_min > rs_verdict-allowed_min.
        rs_verdict-state = zif_cd_fmon_types=>gc_sla_state-missing.
      ENDIF.
    ELSE.
      rs_verdict-elapsed_min = zcl_cd_fmon_util=>minutes_between( iv_from = rs_verdict-basis_at
                                                                  iv_to   = lv_reached ).
      IF rs_verdict-elapsed_min > rs_verdict-allowed_min.
        rs_verdict-state = zif_cd_fmon_types=>gc_sla_state-late.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD is_throttled.
    IF is_throttle-minutes <= 0 OR is_iface-direction <> zif_cd_fmon_types=>gc_direction-outbound.
      RETURN.
    ENDIF.
    DATA(lv_method) = to_upper( condense( CONV string( is_iface-pay_method ) ) ).
    IF lv_method IS INITIAL OR lv_method = zif_cd_fmon_types=>gc_wildcard.
      RETURN.
    ENDIF.
    LOOP AT zcl_ca_ops_util=>split_list( is_throttle-methods ) ASSIGNING FIELD-SYMBOL(<lv_method>).
      IF to_upper( <lv_method> ) = lv_method.
        rv_throttled = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_queue_stage.
    rv_queue = xsdbool( iv_stage IS NOT INITIAL
                    AND zcl_cd_fmon_status=>rank( iv_stage     = iv_stage
                                                  iv_direction = zif_cd_fmon_types=>gc_direction-outbound )
                        = delivery_rank( ) ).
  ENDMETHOD.


  METHOD delivery_rank.
    rv_rank = zcl_cd_fmon_status=>rank( iv_stage     = zif_cd_fmon_types=>gc_stage-prism_delivered
                                        iv_direction = zif_cd_fmon_types=>gc_direction-outbound ).
  ENDMETHOD.


  METHOD queue_key.
    IF iv_scope <> zif_cd_fmon_types=>gc_queue_scope-counterparty.
      RETURN.
    ENDIF.
    rv_key = to_upper( condense( is_iface-bank_key ) ).
    IF rv_key IS INITIAL.
      rv_key = zif_cd_fmon_types=>gc_wildcard.
    ENDIF.
  ENDMETHOD.


  METHOD build_queue.
    DATA ls_entry TYPE zif_cd_fmon_types=>ty_queue_entry.

    IF is_throttle-minutes <= 0.
      RETURN.
    ENDIF.
    DATA(lv_left_rank) = delivery_rank( ).
    LOOP AT it_files ASSIGNING FIELD-SYMBOL(<ls_file>).
      READ TABLE it_ifaces ASSIGNING FIELD-SYMBOL(<ls_iface>) WITH TABLE KEY iface_id = <ls_file>-iface_id.
      IF sy-subrc <> 0
         OR is_throttled( is_iface = <ls_iface> is_throttle = is_throttle ) = abap_false
         OR line_exists( rt_queue[ file_id = <ls_file>-file_id ] ).
        CONTINUE.
      ENDIF.
      CLEAR ls_entry.
      ls_entry-file_id       = <ls_file>-file_id.
      ls_entry-business_date = <ls_file>-business_date.
      ls_entry-queue_key     = queue_key( is_iface = <ls_iface> iv_scope = is_throttle-scope ).
      LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>) USING KEY by_file WHERE file_id = <ls_file>-file_id.
        IF <ls_event>-stage = zif_cd_fmon_types=>gc_stage-prism_received.
          IF ls_entry-received_at IS INITIAL OR <ls_event>-event_at < ls_entry-received_at.
            ls_entry-received_at = <ls_event>-event_at.
          ENDIF.
        ELSEIF zcl_cd_fmon_status=>rank( iv_stage     = <ls_event>-stage
                                         iv_direction = zif_cd_fmon_types=>gc_direction-outbound ) >= lv_left_rank
           AND ( ls_entry-left_at IS INITIAL OR <ls_event>-event_at < ls_entry-left_at ).
          ls_entry-left_at = <ls_event>-event_at.
        ENDIF.
      ENDLOOP.
      " No PRISM receipt evidence: the file has no known queue position (today's behaviour)
      IF ls_entry-received_at IS NOT INITIAL.
        INSERT ls_entry INTO TABLE rt_queue.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD queue_position.
    READ TABLE it_queue ASSIGNING FIELD-SYMBOL(<ls_self>) WITH TABLE KEY file_id = iv_file_id.
    IF sy-subrc <> 0 OR is_throttle-minutes <= 0.
      RETURN.
    ENDIF.
    rs_pos-queued = abap_true.
    LOOP AT it_queue ASSIGNING FIELD-SYMBOL(<ls_other>) USING KEY by_queue
         WHERE business_date = <ls_self>-business_date
           AND queue_key     = <ls_self>-queue_key.
      IF <ls_other>-file_id <> iv_file_id
         AND <ls_other>-received_at <= <ls_self>-received_at
         AND ( <ls_other>-left_at IS INITIAL OR <ls_other>-left_at > <ls_self>-received_at ).
        rs_pos-ahead += 1.
      ENDIF.
    ENDLOOP.
    " A queue of up to QUEUE_MAX files (incl. this one) is covered; a longer one is reported
    DATA(lv_max) = nmax( val1 = is_throttle-queue_max val2 = 1 ).
    rs_pos-counted   = nmin( val1 = rs_pos-ahead val2 = lv_max - 1 ).
    rs_pos-delay_min = rs_pos-counted * is_throttle-minutes.
    rs_pos-long      = xsdbool( rs_pos-ahead + 1 > lv_max ).
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
    LOOP AT zcl_ca_ops_util=>split_list( iv_done_values ) ASSIGNING FIELD-SYMBOL(<lv_token>).
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


  METHOD file_instance.
    DATA ls_earlier TYPE zif_cd_fmon_types=>ty_file.
    DATA ls_later TYPE zif_cd_fmon_types=>ty_file.

    DATA(lv_origin) = zcl_cd_fmon_status=>is_origin( iv_stage     = is_obs-stage
                                                     iv_direction = is_obs-direction ).
    DATA(lv_date) = COND d( WHEN is_obs-business_date IS NOT INITIAL THEN is_obs-business_date
                            WHEN lv_origin = abap_true THEN is_obs-run_date ).
    LOOP AT it_candidates ASSIGNING FIELD-SYMBOL(<ls_file>).
      IF lv_date IS NOT INITIAL AND <ls_file>-business_date = lv_date.
        rs_pick-file_id = <ls_file>-file_id.
        RETURN.
      ENDIF.
      IF lv_date IS INITIAL OR <ls_file>-business_date < lv_date.
        IF ls_earlier IS INITIAL OR <ls_file>-business_date > ls_earlier-business_date.
          ls_earlier = <ls_file>.
        ENDIF.
      ELSEIF ls_later IS INITIAL OR <ls_file>-business_date < ls_later-business_date.
        ls_later = <ls_file>.
      ENDIF.
    ENDLOOP.

    IF ls_earlier IS NOT INITIAL.
      IF is_obs-business_date IS INITIAL AND lines( it_candidates ) > 1.
        " Undated and several instances: no safe correlation (audit A49)
        rs_pick-ambiguous = abap_true.
      ELSEIF lv_origin = abap_false
          OR continues_file( is_obs = is_obs is_file = ls_earlier it_events = it_events ) = abap_true.
        rs_pick-file_id = ls_earlier-file_id.
      ENDIF.
      RETURN.
    ENDIF.

    IF ls_later IS NOT INITIAL AND lv_origin = abap_true
       AND ( ls_later-first_event_at IS INITIAL OR is_obs-event_at <= ls_later-first_event_at ).
      rs_pick-file_id = ls_later-file_id.
    ENDIF.
  ENDMETHOD.


  METHOD continues_file.
    IF zcl_cd_fmon_status=>reaches( is_file = is_file iv_stage = is_obs-stage ) = abap_false.
      rv_same = abap_true.
      RETURN.
    ENDIF.
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>) USING KEY by_file
         WHERE file_id = is_file-file_id
           AND src_id  = is_obs-src_id
           AND src_key = is_obs-file_ref
           AND stage   = is_obs-stage.
      IF <ls_event>-event_at = is_obs-event_at.
        rv_same = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD generation_key.
    DATA lv_last TYPE i.
    DATA lt_parts TYPE string_table.
    LOOP AT it_values ASSIGNING FIELD-SYMBOL(<lv_value>).
      DATA(lv_part) = condense( <lv_value> ).
      INSERT lv_part INTO TABLE lt_parts.
      IF lv_part IS NOT INITIAL.
        lv_last = lines( lt_parts ).
      ENDIF.
    ENDLOOP.
    IF lv_last = 0.
      RETURN.
    ENDIF.
    DATA(lv_cut) = lv_last + 1.
    DELETE lt_parts FROM lv_cut.
    rv_key = zcl_cd_fmon_util=>normalize_ref(
               concat_lines_of( table = lt_parts sep = zif_cd_fmon_types=>gc_generation-separator ) ).
  ENDMETHOD.


  METHOD generated_before.
    rv_before = xsdbool( is_first-first_event_at < is_second-first_event_at
                         OR ( is_first-first_event_at = is_second-first_event_at
                              AND is_first-file_id < is_second-file_id ) ).
  ENDMETHOD.


  METHOD same_group.
    rv_same = xsdbool( is_file-gen_group IS NOT INITIAL
                       AND is_other-file_id   <> is_file-file_id
                       AND is_other-iface_id  = is_file-iface_id
                       AND is_other-gen_group = is_file-gen_group ).
  ENDMETHOD.


  METHOD previous_generation.
    LOOP AT it_generations ASSIGNING FIELD-SYMBOL(<ls_other>).
      IF same_group( is_file = is_file is_other = <ls_other> ) = abap_true
         AND generated_before( is_first = <ls_other> is_second = is_file ) = abap_true
         AND ( rs_file IS INITIAL OR generated_before( is_first = rs_file is_second = <ls_other> ) = abap_true ).
        rs_file = <ls_other>.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD next_generation.
    LOOP AT it_generations ASSIGNING FIELD-SYMBOL(<ls_other>).
      IF same_group( is_file = is_file is_other = <ls_other> ) = abap_true
         AND generated_before( is_first = is_file is_second = <ls_other> ) = abap_true
         AND ( rs_file IS INITIAL OR generated_before( is_first = <ls_other> is_second = rs_file ) = abap_true ).
        rs_file = <ls_other>.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD failed_verdict.
    DATA lv_failed_at TYPE timestampl.

    rs_verdict-code = zif_cd_fmon_types=>gc_check_code-prism_failed.
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>) USING KEY by_file WHERE file_id = is_file-file_id.
      IF <ls_event>-stage = zif_cd_fmon_types=>gc_stage-prism_failed AND <ls_event>-event_at > lv_failed_at.
        lv_failed_at = <ls_event>-event_at.
      ENDIF.
    ENDLOOP.
    IF lv_failed_at IS INITIAL.
      lv_failed_at = is_file-last_event_at.
    ENDIF.
    rs_verdict-failed_min = zcl_cd_fmon_util=>minutes_between( iv_from = lv_failed_at
                                                               iv_to   = iv_now ).

    rs_verdict-replaced_by = next_generation( is_file = is_file it_generations = it_generations ).
    IF rs_verdict-replaced_by IS NOT INITIAL.
      rs_verdict-code = zif_cd_fmon_types=>gc_check_code-file_replaced.
      RETURN.
    ENDIF.

    DATA(lt_codes) = zcl_ca_ops_util=>split_list( is_regen-dup_codes ).
    LOOP AT it_failures ASSIGNING FIELD-SYMBOL(<ls_failure>)
         WHERE file_ref = is_file-file_ref AND occurred_at >= is_file-first_event_at.
      DATA(lv_code) = to_upper( condense( CONV string( <ls_failure>-error_code ) ) ).
      LOOP AT lt_codes ASSIGNING FIELD-SYMBOL(<lv_code>).
        IF to_upper( <lv_code> ) = lv_code AND lv_code IS NOT INITIAL.
          rs_verdict-code       = zif_cd_fmon_types=>gc_check_code-prism_dup_name.
          rs_verdict-error_code = <ls_failure>-error_code.
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    rs_verdict-regen_missing = xsdbool( is_file-gen_group IS NOT INITIAL
                                        AND is_regen-wait_min > 0
                                        AND rs_verdict-failed_min > is_regen-wait_min ).
  ENDMETHOD.


  METHOD unfailed_predecessor.
    DATA(ls_previous) = previous_generation( is_file = is_file it_generations = it_generations ).
    IF ls_previous IS NOT INITIAL AND ls_previous-outcome <> zif_cd_fmon_types=>gc_stage-prism_failed.
      rs_file = ls_previous.
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
