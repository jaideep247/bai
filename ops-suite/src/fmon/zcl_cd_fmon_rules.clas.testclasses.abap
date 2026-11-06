*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_rules.clas.testclasses.abap
*& Purpose:
*& Pure unit tests (no doubles) for every FMON domain rule: interface
*& defaults, day types, expectations, SLA, ack match, duplicates, size,
*& lot outcome and NOC aging; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A38-A41: ACK known counts, SLA evidence, truncated lots, age basis.
*&---------------------------------------------------------------------*
CLASS ltc_rules DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_date TYPE d VALUE '20261102'.
    CONSTANTS gc_t0430 TYPE timestampl VALUE '20261102043000'.
    CONSTANTS gc_t0440 TYPE timestampl VALUE '20261102044000'.
    CONSTANTS gc_t0530 TYPE timestampl VALUE '20261102053000'.
    CONSTANTS gc_t0600 TYPE timestampl VALUE '20261102060000'.
    CONSTANTS gc_t0630 TYPE timestampl VALUE '20261102063000'.
    CONSTANTS gc_t0800 TYPE timestampl VALUE '20261102080000'.
    CONSTANTS gc_iface_default TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_OUT_DEFAULT'.
    CONSTANTS gc_iface_pclm TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_OUT_PCLM'.
    CONSTANTS gc_file_name TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_PNC_20261102_01'.

    METHODS new_file
      IMPORTING
        iv_id          TYPE i DEFAULT 1
        iv_inbound     TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_file) TYPE zif_cd_fmon_types=>ty_file.

    METHODS new_event
      IMPORTING
        is_file         TYPE zif_cd_fmon_types=>ty_file
        iv_stage        TYPE zif_cd_fmon_types=>ty_stage
        iv_at           TYPE timestampl
      RETURNING
        VALUE(rs_event) TYPE zif_cd_fmon_types=>ty_event.

    METHODS ifaces
      RETURNING
        VALUE(rt_ifaces) TYPE zif_cd_fmon_types=>tt_iface.

    METHODS expect_one
      RETURNING
        VALUE(rs_expect) TYPE zif_cd_fmon_types=>ty_expect.

    METHODS prism_sla
      RETURNING
        VALUE(rs_sla) TYPE zif_cd_fmon_types=>ty_sla.

    METHODS noc_lot
      IMPORTING
        iv_age        TYPE i
        iv_open       TYPE i
      RETURNING
        VALUE(rs_lot) TYPE zif_cd_fmon_types=>ty_lot_status.

    METHODS specific_source_beats_default FOR TESTING.
    METHODS new_source_uses_default_iface FOR TESTING.
    METHODS unmatched_file_has_no_iface FOR TESTING.
    METHODS configured_iface_wins FOR TESTING.
    METHODS non_working_day_is_holiday FOR TESTING.
    METHODS last_workday_is_month_end FOR TESTING.
    METHODS returns_weekday_is_returns_day FOR TESTING.
    METHODS holiday_without_row_expects_0 FOR TESTING.
    METHODS month_end_falls_back_to_normal FOR TESTING.
    METHODS short_after_grace_is_missing FOR TESTING.
    METHODS short_within_grace_is_late FOR TESTING.
    METHODS file_on_zero_day_is_unexpected FOR TESTING.
    METHODS arrival_after_window_is_late FOR TESTING.
    METHODS overdue_handoff_is_missing FOR TESTING.
    METHODS slow_handoff_is_late FOR TESTING.
    METHODS timely_handoff_is_ok FOR TESTING.
    METHODS ack_sla_counts_from_generation FOR TESTING.
    METHODS sla_code_names_the_stage FOR TESTING.
    METHODS ack_count_differs_is_mismatch FOR TESTING.
    METHODS nack_rows_count_as_responses FOR TESTING.
    METHODS amount_within_tolerance_is_ok FOR TESTING.
    METHODS later_same_checksum_is_dup FOR TESTING.
    METHODS earlier_file_is_not_duplicate FOR TESTING.
    METHODS zero_size_is_zero_byte FOR TESTING.
    METHODS size_above_max_is_out_of_bound FOR TESTING.
    METHODS unknown_size_is_not_checked FOR TESTING.
    METHODS open_items_make_partial FOR TESTING.
    METHODS no_open_items_make_full FOR TESTING.
    METHODS missing_lot_derives_nothing FOR TESTING.
    METHODS noc_older_6_bdays_is_error FOR TESTING.
    METHODS noc_on_day_6_is_due_today FOR TESTING.
    METHODS processed_noc_does_not_age FOR TESTING.
    METHODS blank_token_matches_initial FOR TESTING.
    METHODS lot_source_cannot_finish_file FOR TESTING.
    METHODS lot_cfg_falls_back_to_default FOR TESTING.
    METHODS known_zero_ack_is_mismatch FOR TESTING.
    METHODS unreported_ack_count_unchecked FOR TESTING.
    METHODS partial_never_meets_processing FOR TESTING.
    METHODS later_stage_only_is_inferred FOR TESTING.
    METHODS nack_meets_ack_sla FOR TESTING.
    METHODS inferred_code_names_the_stage FOR TESTING.
    METHODS truncated_lot_derives_nothing FOR TESTING.
    METHODS unknown_age_does_not_age FOR TESTING.
    METHODS age_counts_after_receipt FOR TESTING.

ENDCLASS.


CLASS ltc_rules IMPLEMENTATION.

  METHOD new_file.
    rs_file-file_id        = CONV zif_cd_fmon_types=>ty_file_id( iv_id ).
    rs_file-iface_id       = gc_iface_default.
    rs_file-direction      = COND #( WHEN iv_inbound = abap_true THEN zif_cd_fmon_types=>gc_direction-inbound
                                     ELSE zif_cd_fmon_types=>gc_direction-outbound ).
    rs_file-file_name      = gc_file_name.
    rs_file-business_date  = gc_date.
    rs_file-stage          = COND #( WHEN iv_inbound = abap_true THEN zif_cd_fmon_types=>gc_stage-received
                                     ELSE zif_cd_fmon_types=>gc_stage-generated ).
    rs_file-first_event_at = gc_t0430.
    rs_file-last_event_at  = gc_t0430.
  ENDMETHOD.


  METHOD new_event.
    rs_event-file_id  = is_file-file_id.
    rs_event-stage    = iv_stage.
    rs_event-event_at = iv_at.
  ENDMETHOD.


  METHOD ifaces.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    ls_iface-iface_id     = gc_iface_default.
    ls_iface-direction    = zif_cd_fmon_types=>gc_direction-outbound.
    ls_iface-source_sys   = zif_cd_fmon_types=>gc_wildcard.
    ls_iface-lob          = zif_cd_fmon_types=>gc_wildcard.
    ls_iface-name_pattern = 'ACH_*'.
    ls_iface-active       = abap_true.
    INSERT ls_iface INTO TABLE rt_ifaces.
    ls_iface-iface_id     = gc_iface_pclm.
    ls_iface-source_sys   = 'PCLM'.
    INSERT ls_iface INTO TABLE rt_ifaces.
  ENDMETHOD.


  METHOD expect_one.
    rs_expect-iface_id       = gc_iface_default.
    rs_expect-day_type       = zif_cd_fmon_types=>gc_day_type-normal.
    rs_expect-expected_count = 1.
    rs_expect-ts_to          = gc_t0600.
  ENDMETHOD.


  METHOD prism_sla.
    rs_sla-iface_id    = gc_iface_default.
    rs_sla-stage       = zif_cd_fmon_types=>gc_stage-sent.
    rs_sla-max_minutes = 30.
    rs_sla-basis       = zif_cd_fmon_types=>gc_sla_basis-previous.
  ENDMETHOD.


  METHOD noc_lot.
    rs_lot-lot_type    = zif_cd_fmon_types=>gc_lot_type-noc.
    rs_lot-found       = abap_true.
    rs_lot-total_items = 2.
    rs_lot-open_items  = iv_open.
    rs_lot-done_items  = 2 - iv_open.
    rs_lot-age_days    = iv_age.
    rs_lot-sla_days    = 6.
  ENDMETHOD.


  " Rule: a row for the record's own source beats the '*' default row.
  METHOD specific_source_beats_default.
    TRY.
        DATA(ls_iface) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = ifaces( )
                                                          iv_file_name = gc_file_name
                                                          iv_source    = 'PCLM' ).
        cl_abap_unit_assert=>assert_equals( act = ls_iface-iface_id exp = gc_iface_pclm
                                            msg = 'PCLM row must win over the default row' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (acceptance test 2): a new source is served by the '*' row - customizing only.
  METHOD new_source_uses_default_iface.
    TRY.
        DATA(ls_iface) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = ifaces( )
                                                          iv_file_name = gc_file_name
                                                          iv_source    = 'NEWSRC'
                                                          iv_lob       = 'NEWLOB' ).
        cl_abap_unit_assert=>assert_equals( act = ls_iface-iface_id exp = gc_iface_default
                                            msg = 'Unknown source and LOB must use the default row' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a file no name pattern matches has no interface (raised as UNMAPPED_FILE).
  METHOD unmatched_file_has_no_iface.
    TRY.
        DATA(ls_iface) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = ifaces( )
                                                          iv_file_name = 'WIRE_JPMC_1' ).
        cl_abap_unit_assert=>assert_initial( act = ls_iface
                                             msg = 'No interface may be resolved' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an interface fixed on the source adapter row wins over name patterns.
  METHOD configured_iface_wins.
    TRY.
        DATA(ls_iface) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = ifaces( )
                                                          iv_iface_id  = gc_iface_pclm
                                                          iv_file_name = 'ANY_NAME' ).
        cl_abap_unit_assert=>assert_equals( act = ls_iface-iface_id exp = gc_iface_pclm
                                            msg = 'Configured interface must be used' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a non-working day of the factory calendar is a HOLIDAY, even at month end.
  METHOD non_working_day_is_holiday.
    TRY.
        DATA(lv_day_type) = zcl_cd_fmon_rules=>day_type( iv_working_day  = abap_false
                                                        iv_month_end    = abap_true
                                                        iv_date         = gc_date
                                                        iv_returns_days = `1` ).
        cl_abap_unit_assert=>assert_equals( act = lv_day_type exp = zif_cd_fmon_types=>gc_day_type-holiday
                                            msg = 'Non-working day must be HOLIDAY' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the last working day of the month is MONTH_END (before RETURNS_DAY).
  METHOD last_workday_is_month_end.
    TRY.
        DATA(lv_day_type) = zcl_cd_fmon_rules=>day_type( iv_working_day  = abap_true
                                                        iv_month_end    = abap_true
                                                        iv_date         = gc_date
                                                        iv_returns_days = `1` ).
        cl_abap_unit_assert=>assert_equals( act = lv_day_type exp = zif_cd_fmon_types=>gc_day_type-month_end
                                            msg = 'Last working day must be MONTH_END' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a weekday listed in FMON_RETURNS_WEEKDAYS (1 = Monday) is a RETURNS_DAY.
  METHOD returns_weekday_is_returns_day.
    TRY.
        DATA(lv_day_type) = zcl_cd_fmon_rules=>day_type( iv_working_day  = abap_true
                                                        iv_month_end    = abap_false
                                                        iv_date         = gc_date
                                                        iv_returns_days = `1,3` ).
        cl_abap_unit_assert=>assert_equals( act = lv_day_type exp = zif_cd_fmon_types=>gc_day_type-returns_day
                                            msg = 'Monday 2026-11-02 must be RETURNS_DAY' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: on a HOLIDAY without its own calendar row nothing is expected (no NORMAL fallback).
  METHOD holiday_without_row_expects_0.
    DATA lt_cals TYPE zif_cd_fmon_types=>tt_cal.
    DATA ls_cal TYPE zif_cd_fmon_types=>ty_cal.
    TRY.
        ls_cal-iface_id       = gc_iface_default.
        ls_cal-day_type       = zif_cd_fmon_types=>gc_day_type-normal.
        ls_cal-expected_count = 1.
        INSERT ls_cal INTO TABLE lt_cals.
        DATA(ls_row) = zcl_cd_fmon_rules=>pick_calendar_row( it_cals     = lt_cals
                                                            iv_iface_id = gc_iface_default
                                                            iv_day_type = zif_cd_fmon_types=>gc_day_type-holiday ).
        cl_abap_unit_assert=>assert_initial( act = ls_row
                                             msg = 'Holiday must not fall back to NORMAL' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: MONTH_END / RETURNS_DAY without a row fall back to the NORMAL row.
  METHOD month_end_falls_back_to_normal.
    DATA lt_cals TYPE zif_cd_fmon_types=>tt_cal.
    DATA ls_cal TYPE zif_cd_fmon_types=>ty_cal.
    TRY.
        ls_cal-iface_id       = gc_iface_default.
        ls_cal-day_type       = zif_cd_fmon_types=>gc_day_type-normal.
        ls_cal-expected_count = 1.
        INSERT ls_cal INTO TABLE lt_cals.
        DATA(ls_row) = zcl_cd_fmon_rules=>pick_calendar_row( it_cals     = lt_cals
                                                            iv_iface_id = gc_iface_default
                                                            iv_day_type = zif_cd_fmon_types=>gc_day_type-month_end ).
        cl_abap_unit_assert=>assert_equals( act = ls_row exp = ls_cal
                                            msg = 'Month end must use the NORMAL row' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: fewer files than expected after window end + grace is FILE_MISSING.
  METHOD short_after_grace_is_missing.
    TRY.
        DATA(lv_code) = zcl_cd_fmon_rules=>expectation_code( is_expect    = expect_one( )
                                                            iv_received  = 0
                                                            iv_now       = gc_t0800
                                                            iv_grace_min = 60 ).
        cl_abap_unit_assert=>assert_equals( act = lv_code exp = zif_cd_fmon_types=>gc_check_code-file_missing
                                            msg = 'Two hours after window end must be FILE_MISSING' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: fewer files than expected after window end but within grace is FILE_LATE.
  METHOD short_within_grace_is_late.
    TRY.
        DATA(lv_code) = zcl_cd_fmon_rules=>expectation_code( is_expect    = expect_one( )
                                                            iv_received  = 0
                                                            iv_now       = gc_t0630
                                                            iv_grace_min = 60 ).
        cl_abap_unit_assert=>assert_equals( act = lv_code exp = zif_cd_fmon_types=>gc_check_code-file_late
                                            msg = 'Inside the grace period must be FILE_LATE' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a file on a day that expects zero files is UNEXPECTED_FILE.
  METHOD file_on_zero_day_is_unexpected.
    TRY.
        DATA(ls_expect) = expect_one( ).
        ls_expect-expected_count = 0.
        DATA(lv_code) = zcl_cd_fmon_rules=>expectation_code( is_expect    = ls_expect
                                                            iv_received  = 1
                                                            iv_now       = gc_t0800
                                                            iv_grace_min = 60 ).
        cl_abap_unit_assert=>assert_equals( act = lv_code exp = zif_cd_fmon_types=>gc_check_code-unexpected_file
                                            msg = 'File on a zero-expectation day must be flagged' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a file whose first event is after the window end arrived late.
  METHOD arrival_after_window_is_late.
    TRY.
        DATA(ls_file) = new_file( ).
        ls_file-first_event_at = gc_t0630.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_rules=>arrived_late( is_file   = ls_file
                                                                                 is_expect = expect_one( ) )
                                          msg = 'First event after window end must be late' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: stage not reached and SLA minutes since the previous stage exceeded -> missing.
  METHOD overdue_handoff_is_missing.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_sla_verdict.
    TRY.
        DATA(ls_file) = new_file( ).
        DATA(lt_events) = VALUE zif_cd_fmon_types=>tt_event(
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-generated iv_at = gc_t0430 ) ) ).
        ls_exp-state       = zif_cd_fmon_types=>gc_sla_state-missing.
        ls_exp-elapsed_min = 210.
        ls_exp-basis_at    = gc_t0430.
        DATA(ls_verdict) = zcl_cd_fmon_rules=>sla_verdict( is_file   = ls_file
                                                          is_sla    = prism_sla( )
                                                          it_events = lt_events
                                                          iv_now    = gc_t0800 ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict exp = ls_exp
                                            msg = 'No PRISM handoff after 210 min must be missing' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: stage reached, but later than the SLA allows -> late.
  METHOD slow_handoff_is_late.
    TRY.
        DATA(ls_file) = new_file( ).
        DATA(lt_events) = VALUE zif_cd_fmon_types=>tt_event(
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-generated iv_at = gc_t0430 ) )
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-sent iv_at = gc_t0530 ) ) ).
        DATA(ls_verdict) = zcl_cd_fmon_rules=>sla_verdict( is_file   = ls_file
                                                          is_sla    = prism_sla( )
                                                          it_events = lt_events
                                                          iv_now    = gc_t0800 ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-state exp = zif_cd_fmon_types=>gc_sla_state-late
                                            msg = 'Handoff after 60 min (SLA 30) must be late' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: stage reached within the SLA -> ok.
  METHOD timely_handoff_is_ok.
    TRY.
        DATA(ls_file) = new_file( ).
        DATA(lt_events) = VALUE zif_cd_fmon_types=>tt_event(
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-generated iv_at = gc_t0430 ) )
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-sent iv_at = gc_t0440 ) ) ).
        DATA(ls_verdict) = zcl_cd_fmon_rules=>sla_verdict( is_file   = ls_file
                                                          is_sla    = prism_sla( )
                                                          it_events = lt_events
                                                          iv_now    = gc_t0800 ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-state exp = zif_cd_fmon_types=>gc_sla_state-ok
                                            msg = 'Handoff after 10 min must be ok' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: basis G measures from the file's first event, not from the previous stage.
  METHOD ack_sla_counts_from_generation.
    TRY.
        DATA(ls_file) = new_file( ).
        DATA(ls_sla) = prism_sla( ).
        ls_sla-stage       = zif_cd_fmon_types=>gc_stage-ack.
        ls_sla-basis       = zif_cd_fmon_types=>gc_sla_basis-generation.
        ls_sla-max_minutes = 120.
        DATA(lt_events) = VALUE zif_cd_fmon_types=>tt_event(
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-generated iv_at = gc_t0430 ) )
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-sent iv_at = gc_t0600 ) ) ).
        DATA(ls_verdict) = zcl_cd_fmon_rules=>sla_verdict( is_file   = ls_file
                                                          is_sla    = ls_sla
                                                          it_events = lt_events
                                                          iv_now    = gc_t0800 ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-basis_at exp = gc_t0430
                                            msg = 'Basis must be the first event' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: SLA finding codes name the stage (NO_PRISM_HANDOFF, BANK_ACK_LATE, ...).
  METHOD sla_code_names_the_stage.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>sla_code( iv_stage = zif_cd_fmon_types=>gc_stage-sent
                                             iv_state = zif_cd_fmon_types=>gc_sla_state-missing )
          exp = zif_cd_fmon_types=>gc_check_code-no_prism_handoff
          msg = 'Missing PRISM handoff code' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>sla_code( iv_stage = zif_cd_fmon_types=>gc_stage-ack
                                             iv_state = zif_cd_fmon_types=>gc_sla_state-late )
          exp = zif_cd_fmon_types=>gc_check_code-bank_ack_late
          msg = 'Late bank ack code' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: acknowledged records differing from the file's record count is a mismatch.
  METHOD ack_count_differs_is_mismatch.
    TRY.
        DATA(ls_file) = new_file( ).
        ls_file-record_count = 10.
        ls_file-ack_count    = 9.
        ls_file-ack_known    = abap_true.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_rules=>ack_count_mismatch( ls_file )
                                          msg = '9 of 10 acknowledged must be a mismatch' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: rejected (NACK) payments count as bank responses in the count match.
  METHOD nack_rows_count_as_responses.
    TRY.
        DATA(ls_file) = new_file( ).
        ls_file-record_count = 10.
        ls_file-ack_count    = 9.
        ls_file-nack_count   = 1.
        ls_file-ack_known    = abap_true.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_fmon_rules=>ack_count_mismatch( ls_file )
                                           msg = '9 ACK + 1 NACK of 10 is no count mismatch' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an amount difference within the tolerance is not a mismatch.
  METHOD amount_within_tolerance_is_ok.
    TRY.
        DATA(ls_file) = new_file( ).
        ls_file-control_total = '1000.00'.
        ls_file-ack_amount    = '1000.01'.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_fmon_rules=>ack_amount_mismatch( is_file      = ls_file
                                                                                         iv_tolerance = '0.01' )
                                           msg = 'A 0.01 difference is within tolerance' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a later file of the same interface with the same checksum is a duplicate.
  METHOD later_same_checksum_is_dup.
    TRY.
        DATA(ls_first) = new_file( iv_id = 1 ).
        ls_first-checksum  = 'ABC'.
        DATA(ls_second) = new_file( iv_id = 2 ).
        ls_second-file_name      = 'ACH_PNC_20261102_02'.
        ls_second-checksum       = 'ABC'.
        ls_second-first_event_at = gc_t0440.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_rules=>is_duplicate_of( is_file  = ls_second
                                                                                    is_other = ls_first )
                                          msg = 'Same checksum, later arrival must be a duplicate' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the first of two identical files is the original, not the duplicate.
  METHOD earlier_file_is_not_duplicate.
    TRY.
        DATA(ls_first) = new_file( iv_id = 1 ).
        ls_first-checksum = 'ABC'.
        DATA(ls_second) = new_file( iv_id = 2 ).
        ls_second-checksum       = 'ABC'.
        ls_second-first_event_at = gc_t0440.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_fmon_rules=>is_duplicate_of( is_file  = ls_first
                                                                                     is_other = ls_second )
                                           msg = 'The earlier file must not be flagged' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a known size of 0 bytes is ZERO_BYTE.
  METHOD zero_size_is_zero_byte.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    TRY.
        DATA(ls_file) = new_file( ).
        ls_file-size_known = abap_true.
        ls_file-size_bytes = 0.
        ls_iface-min_bytes = 1.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>size_code( is_file  = ls_file
                                                                                is_iface = ls_iface )
                                            exp = zif_cd_fmon_types=>gc_check_code-zero_byte
                                            msg = 'Zero bytes must be ZERO_BYTE' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a size above MAX_BYTES (when maintained) is SIZE_OUT_OF_BOUNDS.
  METHOD size_above_max_is_out_of_bound.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    TRY.
        DATA(ls_file) = new_file( ).
        ls_file-size_known = abap_true.
        ls_file-size_bytes = 5000.
        ls_iface-min_bytes = 1.
        ls_iface-max_bytes = 4000.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>size_code( is_file  = ls_file
                                                                                is_iface = ls_iface )
                                            exp = zif_cd_fmon_types=>gc_check_code-size_bounds
                                            msg = '5000 bytes above max 4000 must be out of bounds' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: when no source delivers a size, no size finding is raised.
  METHOD unknown_size_is_not_checked.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    TRY.
        DATA(ls_file) = new_file( ).
        ls_iface-min_bytes = 1.
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_fmon_rules=>size_code( is_file  = ls_file
                                                                                 is_iface = ls_iface )
                                             msg = 'Unknown size must not be checked' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (acceptance test 8): any unprocessed transaction makes the file PARTIALLY_PROCESSED.
  METHOD open_items_make_partial.
    TRY.
        DATA(ls_lot) = noc_lot( iv_age = 1 iv_open = 1 ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>lot_outcome( ls_lot )
                                            exp = zif_cd_fmon_types=>gc_stage-partially
                                            msg = 'One open item must give PARTIALLY_PROCESSED' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a lot with zero unaccounted transactions makes the file FULLY_PROCESSED.
  METHOD no_open_items_make_full.
    TRY.
        DATA(ls_lot) = noc_lot( iv_age = 1 iv_open = 0 ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>lot_outcome( ls_lot )
                                            exp = zif_cd_fmon_types=>gc_stage-fully
                                            msg = 'No open item must give FULLY_PROCESSED' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without a lot no outcome is derived (the file stays FILE_LOADED).
  METHOD missing_lot_derives_nothing.
    DATA ls_lot TYPE zif_cd_fmon_types=>ty_lot_status.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_fmon_rules=>lot_outcome( ls_lot )
                                             msg = 'No lot, no outcome' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (NACHA): an open NOC older than 6 banking days is a compliance error.
  METHOD noc_older_6_bdays_is_error.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>noc_aging_code( noc_lot( iv_age = 7 iv_open = 1 ) )
                                            exp = zif_cd_fmon_types=>gc_check_code-noc_aging
                                            msg = 'Day 7 with an open NOC must be NOC_AGING' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (NACHA): banking day 6 is the last allowed day - warn as NOC_DUE_TODAY.
  METHOD noc_on_day_6_is_due_today.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>noc_aging_code( noc_lot( iv_age = 6 iv_open = 1 ) )
                                            exp = zif_cd_fmon_types=>gc_check_code-noc_due_today
                                            msg = 'Day 6 with an open NOC must be NOC_DUE_TODAY' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a fully applied NOC lot never ages.
  METHOD processed_noc_does_not_age.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_fmon_rules=>noc_aging_code( noc_lot( iv_age = 9 iv_open = 0 ) )
                                             msg = 'No open NOC item, no aging finding' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: <BLANK> in the done-value list matches an initial item status.
  METHOD blank_token_matches_initial.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_rules=>is_done( iv_status      = ``
                                                                            iv_done_values = `X,<BLANK>` )
                                          msg = 'Initial status must match <BLANK>' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: for lot-controlled interfaces a source cannot declare the file processed;
  " its FULLY/PARTIALLY status is capped at FILE_LOADED and the lot decides.
  METHOD lot_source_cannot_finish_file.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>cap_stage( iv_stage          = zif_cd_fmon_types=>gc_stage-fully
                                                                                iv_lot_controlled = abap_true )
                                            exp = zif_cd_fmon_types=>gc_stage-loaded
                                            msg = 'FULLY from a source must be capped at FILE_LOADED' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an interface without its own lot row uses the '*' row of the lot type.
  METHOD lot_cfg_falls_back_to_default.
    DATA lt_cfgs TYPE zif_cd_fmon_types=>tt_lotcfg.
    DATA ls_cfg TYPE zif_cd_fmon_types=>ty_lotcfg.
    TRY.
        ls_cfg-iface_id   = zif_cd_fmon_types=>gc_wildcard.
        ls_cfg-lot_type   = zif_cd_fmon_types=>gc_lot_type-noc.
        ls_cfg-item_table = 'DFKKNRP'.
        ls_cfg-active     = abap_true.
        INSERT ls_cfg INTO TABLE lt_cfgs.
        DATA(ls_found) = zcl_cd_fmon_rules=>lot_cfg_for( it_cfgs     = lt_cfgs
                                                        iv_iface_id = 'NOC_PNC_IN'
                                                        iv_lot_type = zif_cd_fmon_types=>gc_lot_type-noc ).
        cl_abap_unit_assert=>assert_equals( act = ls_found exp = ls_cfg
                                            msg = 'Default lot row must be used' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A39: a count the bank reported as zero is a fact, compared like any other count
  METHOD known_zero_ack_is_mismatch.
    TRY.
        DATA(ls_file) = new_file( ).
        ls_file-record_count = 10.
        ls_file-ack_known    = abap_true.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_rules=>ack_count_mismatch( ls_file )
                                          msg = 'A reported ACK count of 0 for 10 records is a mismatch' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A39: an ACK without a reported count is unknown, not zero - no count verdict
  METHOD unreported_ack_count_unchecked.
    TRY.
        DATA(ls_file) = new_file( ).
        ls_file-record_count = 10.
        ls_file-stage        = zif_cd_fmon_types=>gc_stage-ack.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_fmon_rules=>ack_count_mismatch( ls_file )
                                           msg = 'An unreported ACK count must not be compared as 0' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A40: PARTIALLY_PROCESSED / FAILED never satisfy a processing SLA
  METHOD partial_never_meets_processing.
    TRY.
        DATA(ls_file) = new_file( iv_inbound = abap_true ).
        DATA(ls_sla) = prism_sla( ).
        ls_sla-stage = zif_cd_fmon_types=>gc_stage-fully.
        DATA(lt_events) = VALUE zif_cd_fmon_types=>tt_event(
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-loaded iv_at = gc_t0430 ) )
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-partially iv_at = gc_t0440 ) ) ).
        ls_file-stage   = zif_cd_fmon_types=>gc_stage-partially.
        ls_file-outcome = zif_cd_fmon_types=>gc_stage-partially.
        DATA(ls_verdict) = zcl_cd_fmon_rules=>sla_verdict( is_file   = ls_file
                                                          is_sla    = ls_sla
                                                          it_events = lt_events
                                                          iv_now    = gc_t0800 ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-state exp = zif_cd_fmon_types=>gc_sla_state-missing
                                            msg = 'A partial outcome must not meet the processing SLA' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A40: a later stage is no evidence of the handoff itself - inferred, not met
  METHOD later_stage_only_is_inferred.
    TRY.
        DATA(ls_file) = new_file( ).
        DATA(lt_events) = VALUE zif_cd_fmon_types=>tt_event(
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-generated iv_at = gc_t0430 ) )
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-forwarded iv_at = gc_t0440 ) ) ).
        ls_file-stage = zif_cd_fmon_types=>gc_stage-forwarded.
        DATA(ls_verdict) = zcl_cd_fmon_rules=>sla_verdict( is_file   = ls_file
                                                          is_sla    = prism_sla( )
                                                          it_events = lt_events
                                                          iv_now    = gc_t0800 ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-state exp = zif_cd_fmon_types=>gc_sla_state-inferred
                                            msg = 'Forwarded without a PRISM handoff event must be inferred' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A40: a bank rejection is the bank's response - it meets the ACK SLA
  METHOD nack_meets_ack_sla.
    TRY.
        DATA(ls_file) = new_file( ).
        DATA(ls_sla) = prism_sla( ).
        ls_sla-stage       = zif_cd_fmon_types=>gc_stage-ack.
        ls_sla-basis       = zif_cd_fmon_types=>gc_sla_basis-generation.
        ls_sla-max_minutes = 120.
        DATA(lt_events) = VALUE zif_cd_fmon_types=>tt_event(
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-generated iv_at = gc_t0430 ) )
          ( new_event( is_file = ls_file iv_stage = zif_cd_fmon_types=>gc_stage-nack iv_at = gc_t0530 ) ) ).
        DATA(ls_verdict) = zcl_cd_fmon_rules=>sla_verdict( is_file   = ls_file
                                                          is_sla    = ls_sla
                                                          it_events = lt_events
                                                          iv_now    = gc_t0800 ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-state exp = zif_cd_fmon_types=>gc_sla_state-ok
                                            msg = 'A NACK within 120 min meets the ACK SLA' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A40: the inferred verdict has its own check code
  METHOD inferred_code_names_the_stage.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>sla_code( iv_stage = zif_cd_fmon_types=>gc_stage-sent
                                             iv_state = zif_cd_fmon_types=>gc_sla_state-inferred )
          exp = 'PRISM_HANDOFF_INFERRED'
          msg = 'Inferred handoff must be PRISM_HANDOFF_INFERRED' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A38: a scan stopped at the row cap proves nothing - no outcome derived
  METHOD truncated_lot_derives_nothing.
    TRY.
        DATA(ls_lot) = noc_lot( iv_age = 1 iv_open = 0 ).
        ls_lot-truncated = abap_true.
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_fmon_rules=>lot_outcome( ls_lot )
                                             msg = 'A truncated scan must not derive FULLY_PROCESSED' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A41: an age the calendar could not determine gives no aging verdict
  METHOD unknown_age_does_not_age.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_fmon_rules=>noc_aging_code( noc_lot( iv_age = zif_cd_fmon_types=>gc_age_unknown iv_open = 1 ) )
          msg = 'Unknown age must not be NOC_AGING or NOC_DUE_TODAY' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A41: by default banking days count strictly after receipt, so a receipt on a
  " non-working day is corrected to the previous working day ('-'); basis N keeps '+'
  METHOD age_counts_after_receipt.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>receipt_correction( zif_cd_fmon_types=>gc_age_basis-after_receipt )
          exp = zif_cd_fmon_types=>gc_fcal_correct-previous
          msg = 'Basis A must correct a weekend receipt backwards' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>receipt_correction( zif_cd_fmon_types=>gc_age_basis-next_working )
          exp = zif_cd_fmon_types=>gc_fcal_correct-next
          msg = 'Basis N must start on the next working day' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>receipt_correction( space )
          exp = zif_cd_fmon_types=>gc_fcal_correct-previous
          msg = 'Blank basis must default to A' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
