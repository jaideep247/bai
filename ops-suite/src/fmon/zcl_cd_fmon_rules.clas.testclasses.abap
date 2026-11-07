*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_rules.clas.testclasses.abap
*& Purpose:
*& Pure unit tests (no doubles) for every FMON domain rule: interface
*& defaults, day types, expectations, SLA, ack match, duplicates, size,
*& lot outcome and NOC aging; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A38-A41: ACK known counts, SLA evidence, truncated lots, age basis.
*& 2026-11-06 | Modern-syntax sweep: caught exception lx_error.
*& 2026-11-06 | ltc_throttle: PRISM throttle of ACH / wire files (queue position, scope, cap,
*&              allowance on the delivery stage and on later stages measured from generation).
*& 2026-11-06 | PCRE interface name patterns: complete file name, any case, more literal characters win,
*&              invalid pattern never resolves.
*& 2026-11-07 | Design review: the throttle helper uses the delivered queue scope C (one queue per
*&              bank); bank queues do not delay each other; scope A still works when configured.
*& 2026-11-07 | Design review: ltc_instance - file generation identity (one instance across
*&              midnight, re-read, next-day file of the same name, out-of-order evidence).
*& 2026-11-07 | ltc_regen - regenerated files (user 2026-11-07): generation key, replaced failed file,
*&            | regeneration wait boundary, PRISM duplicate-name codes, regenerated file whose earlier
*&            | generation did not fail, generation order.
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
    METHODS name_pattern_is_whole_name FOR TESTING.
    METHODS name_pattern_ignores_case FOR TESTING.
    METHODS longer_literal_pattern_wins FOR TESTING.
    METHODS invalid_name_pattern_no_iface FOR TESTING.
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
    ls_iface-name_pattern = 'ACH_.*'.
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a file no name pattern matches has no interface (raised as UNMAPPED_FILE).
  METHOD unmatched_file_has_no_iface.
    TRY.
        DATA(ls_iface) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = ifaces( )
                                                          iv_file_name = 'WIRE_JPMC_1' ).
        cl_abap_unit_assert=>assert_initial( act = ls_iface
                                             msg = 'No interface may be resolved' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " PCRE is matched to the complete file name: ACH_ alone does not cover ACH_PNC_...
  METHOD name_pattern_is_whole_name.
    DATA lt_ifaces TYPE zif_cd_fmon_types=>tt_iface.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    TRY.
        ls_iface-iface_id     = gc_iface_default.
        ls_iface-name_pattern = 'ACH_'.
        ls_iface-active       = abap_true.
        INSERT ls_iface INTO TABLE lt_ifaces.
        DATA(ls_result) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = lt_ifaces
                                                           iv_file_name = gc_file_name ).
        cl_abap_unit_assert=>assert_initial( act = ls_result
                                             msg = 'A pattern for the start of the name is no match' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Case is ignored (file names arrive in either case)
  METHOD name_pattern_ignores_case.
    TRY.
        DATA(ls_iface) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = ifaces( )
                                                          iv_file_name = 'ach_pnc_20261102_01' ).
        cl_abap_unit_assert=>assert_equals( act = ls_iface-iface_id exp = gc_iface_default
                                            msg = 'Lower-case name must resolve like upper case' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " The most specific pattern (more literal characters) wins over a broader one
  METHOD longer_literal_pattern_wins.
    DATA lt_ifaces TYPE zif_cd_fmon_types=>tt_iface.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    TRY.
        ls_iface-iface_id     = gc_iface_default.
        ls_iface-name_pattern = 'ACH_.*'.
        ls_iface-active       = abap_true.
        INSERT ls_iface INTO TABLE lt_ifaces.
        ls_iface-iface_id     = gc_iface_pclm.
        ls_iface-name_pattern = 'ACH_PNC_[0-9]{8}_.*'.
        INSERT ls_iface INTO TABLE lt_ifaces.
        DATA(ls_result) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = lt_ifaces
                                                           iv_file_name = gc_file_name ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-iface_id exp = gc_iface_pclm
                                            msg = 'ACH_PNC_ ... _ has more literal characters than ACH_' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " An invalid pattern resolves nothing here (the engine reports it as PATTERN_INVALID)
  METHOD invalid_name_pattern_no_iface.
    DATA lt_ifaces TYPE zif_cd_fmon_types=>tt_iface.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    TRY.
        ls_iface-iface_id     = gc_iface_default.
        ls_iface-name_pattern = 'ACH_[.*'.
        ls_iface-active       = abap_true.
        INSERT ls_iface INTO TABLE lt_ifaces.
        DATA(ls_result) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = lt_ifaces
                                                           iv_file_name = gc_file_name ).
        cl_abap_unit_assert=>assert_initial( act = ls_result
                                             msg = 'An invalid pattern must not resolve an interface' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
        ls_exp-allowed_min = 30.
        DATA(ls_verdict) = zcl_cd_fmon_rules=>sla_verdict( is_file   = ls_file
                                                          is_sla    = prism_sla( )
                                                          it_events = lt_events
                                                          iv_now    = gc_t0800 ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict exp = ls_exp
                                            msg = 'No PRISM handoff after 210 min must be missing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (acceptance test 8): any unprocessed transaction makes the file PARTIALLY_PROCESSED.
  METHOD open_items_make_partial.
    TRY.
        DATA(ls_lot) = noc_lot( iv_age = 1 iv_open = 1 ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>lot_outcome( ls_lot )
                                            exp = zif_cd_fmon_types=>gc_stage-partially
                                            msg = 'One open item must give PARTIALLY_PROCESSED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a lot with zero unaccounted transactions makes the file FULLY_PROCESSED.
  METHOD no_open_items_make_full.
    TRY.
        DATA(ls_lot) = noc_lot( iv_age = 1 iv_open = 0 ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>lot_outcome( ls_lot )
                                            exp = zif_cd_fmon_types=>gc_stage-fully
                                            msg = 'No open item must give FULLY_PROCESSED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without a lot no outcome is derived (the file stays FILE_LOADED).
  METHOD missing_lot_derives_nothing.
    DATA ls_lot TYPE zif_cd_fmon_types=>ty_lot_status.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_fmon_rules=>lot_outcome( ls_lot )
                                             msg = 'No lot, no outcome' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (NACHA): an open NOC older than 6 banking days is a compliance error.
  METHOD noc_older_6_bdays_is_error.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>noc_aging_code( noc_lot( iv_age = 7 iv_open = 1 ) )
                                            exp = zif_cd_fmon_types=>gc_check_code-noc_aging
                                            msg = 'Day 7 with an open NOC must be NOC_AGING' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (NACHA): banking day 6 is the last allowed day - warn as NOC_DUE_TODAY.
  METHOD noc_on_day_6_is_due_today.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_rules=>noc_aging_code( noc_lot( iv_age = 6 iv_open = 1 ) )
                                            exp = zif_cd_fmon_types=>gc_check_code-noc_due_today
                                            msg = 'Day 6 with an open NOC must be NOC_DUE_TODAY' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a fully applied NOC lot never ages.
  METHOD processed_noc_does_not_age.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_fmon_rules=>noc_aging_code( noc_lot( iv_age = 9 iv_open = 0 ) )
                                             msg = 'No open NOC item, no aging finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: <BLANK> in the done-value list matches an initial item status.
  METHOD blank_token_matches_initial.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_rules=>is_done( iv_status      = ``
                                                                            iv_done_values = `X,<BLANK>` )
                                          msg = 'Initial status must match <BLANK>' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A38: a scan stopped at the row cap proves nothing - no outcome derived
  METHOD truncated_lot_derives_nothing.
    TRY.
        DATA(ls_lot) = noc_lot( iv_age = 1 iv_open = 0 ).
        ls_lot-truncated = abap_true.
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_fmon_rules=>lot_outcome( ls_lot )
                                             msg = 'A truncated scan must not derive FULLY_PROCESSED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A41: an age the calendar could not determine gives no aging verdict
  METHOD unknown_age_does_not_age.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_fmon_rules=>noc_aging_code( noc_lot( iv_age = zif_cd_fmon_types=>gc_age_unknown iv_open = 1 ) )
          msg = 'Unknown age must not be NOC_AGING or NOC_DUE_TODAY' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! PRISM throttle (user 2026-11-06): PRISM sends ACH and wire files to the bank one at a time,
"! 2 minutes apart. Pure tests of the queue, the position and the SLA allowance.
CLASS ltc_throttle DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_date TYPE d VALUE '20261106'.
    "! SENT_TO_PRISM of every file (first event, basis G)
    CONSTANTS gc_t1650 TYPE timestampl VALUE '20261106165000'.
    "! PRISM receipts of an evening ACH cycle: 17:00:00, then one every 5 seconds
    CONSTANTS gc_t1700 TYPE timestampl VALUE '20261106170000'.
    CONSTANTS gc_receipt_step TYPE i VALUE 5.
    CONSTANTS gc_base_min TYPE i VALUE 5.
    CONSTANTS gc_throttle_min TYPE i VALUE 2.
    CONSTANTS gc_queue_max TYPE i VALUE 30.
    CONSTANTS:
      BEGIN OF gc_iface,
        ach       TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_PNC_DISB_OUT',
        wire      TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'WIRE_JPMC_OUT',
        ach_boa   TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_BOA_DISB_OUT',
        pospay    TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'CHECK_POSPAY_OUT',
        blackline TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'BLACKLINE_OUT',
      END OF gc_iface.
    CONSTANTS:
      BEGIN OF gc_method,
        ach   TYPE zif_cd_fmon_types=>ty_pay_method VALUE 'ACH',
        wire  TYPE zif_cd_fmon_types=>ty_pay_method VALUE 'WIRE',
        check TYPE zif_cd_fmon_types=>ty_pay_method VALUE 'CHECK',
        list  TYPE zif_cd_fmon_types=>ty_value_list VALUE 'ACH,WIRE',
      END OF gc_method.
    CONSTANTS:
      BEGIN OF gc_bank,
        pnc  TYPE zif_cd_fmon_types=>ty_bank_key VALUE 'PNC',
        jpmc TYPE zif_cd_fmon_types=>ty_bank_key VALUE 'JPMC',
        boa  TYPE zif_cd_fmon_types=>ty_bank_key VALUE 'BOA',
      END OF gc_bank.

    DATA mt_files TYPE zif_cd_fmon_types=>tt_file.
    DATA mt_events TYPE zif_cd_fmon_types=>tt_event.

    METHODS setup.

    METHODS ifaces
      RETURNING
        VALUE(rt_ifaces) TYPE zif_cd_fmon_types=>tt_iface.

    METHODS add_iface
      IMPORTING
        iv_iface_id TYPE zif_cd_fmon_types=>ty_iface_id
        iv_method   TYPE zif_cd_fmon_types=>ty_pay_method
        iv_bank     TYPE zif_cd_fmon_types=>ty_bank_key
      CHANGING
        ct_ifaces   TYPE zif_cd_fmon_types=>tt_iface.

    METHODS throttle
      IMPORTING
        iv_minutes         TYPE i DEFAULT gc_throttle_min
        iv_scope           TYPE zif_cd_fmon_types=>ty_queue_scope
                           DEFAULT zif_cd_fmon_types=>gc_param_default-throttle_scope
      RETURNING
        VALUE(rs_throttle) TYPE zif_cd_fmon_types=>ty_throttle.

    "! Receipt time of the n-th file of the cycle (17:00:00 + (n - 1) x 5 s)
    METHODS receipt
      IMPORTING
        iv_no        TYPE i
      RETURNING
        VALUE(rv_at) TYPE timestampl.

    "! File n: SENT_TO_PRISM at 16:50, PRISM_RECEIVED at iv_received (blank = no PRISM evidence)
    METHODS add_file
      IMPORTING
        iv_no       TYPE i
        iv_iface_id TYPE zif_cd_fmon_types=>ty_iface_id DEFAULT gc_iface-ach
        iv_received TYPE timestampl OPTIONAL.

    METHODS add_event
      IMPORTING
        iv_no    TYPE i
        iv_stage TYPE zif_cd_fmon_types=>ty_stage
        iv_at    TYPE timestampl.

    "! ACH cycle: files 1..n received 5 seconds apart, none delivered yet
    METHODS add_cycle
      IMPORTING
        iv_files TYPE i.

    METHODS position
      IMPORTING
        iv_no         TYPE i
        is_throttle   TYPE zif_cd_fmon_types=>ty_throttle
      RETURNING
        VALUE(rs_pos) TYPE zif_cd_fmon_types=>ty_queue_pos.

    "! SLA verdict of file n for the stage with the file's queue allowance (default throttle)
    METHODS verdict
      IMPORTING
        iv_no             TYPE i
        iv_stage          TYPE zif_cd_fmon_types=>ty_stage DEFAULT zif_cd_fmon_types=>gc_stage-prism_delivered
        iv_basis          TYPE zif_cd_fmon_types=>ty_sla_basis DEFAULT zif_cd_fmon_types=>gc_sla_basis-previous
        iv_max_minutes    TYPE i DEFAULT gc_base_min
        is_throttle       TYPE zif_cd_fmon_types=>ty_throttle
      RETURNING
        VALUE(rs_verdict) TYPE zif_cd_fmon_types=>ty_sla_verdict.

    METHODS plus
      IMPORTING
        iv_at        TYPE timestampl
        iv_secs      TYPE i
      RETURNING
        VALUE(rv_at) TYPE timestampl.

    METHODS file_id
      IMPORTING
        iv_no        TYPE i
      RETURNING
        VALUE(rv_id) TYPE zif_cd_fmon_types=>ty_file_id.

    METHODS single_file_gets_base_sla FOR TESTING.
    METHODS fifth_file_on_time_at_9_min FOR TESTING.
    METHODS fifth_file_late_after_13_min FOR TESTING.
    METHODS scope_c_queues_per_bank FOR TESTING.
    METHODS default_scope_is_per_bank FOR TESTING.
    METHODS bank_queues_do_not_wait FOR TESTING.
    METHODS scope_a_one_queue_when_set FOR TESTING.
    METHODS pospay_not_throttled FOR TESTING.
    METHODS queue_over_max_is_long FOR TESTING.
    METHODS ack_from_generation_shifted FOR TESTING.
    METHODS ack_after_delivery_not_shifted FOR TESTING.
    METHODS zero_throttle_keeps_today FOR TESTING.
    METHODS no_receipt_keeps_today FOR TESTING.
    METHODS delivered_file_is_not_ahead FOR TESTING.

ENDCLASS.


CLASS ltc_throttle IMPLEMENTATION.

  METHOD setup.
    CLEAR: mt_files, mt_events.
  ENDMETHOD.


  METHOD ifaces.
    add_iface( EXPORTING iv_iface_id = gc_iface-ach iv_method = gc_method-ach iv_bank = gc_bank-pnc
               CHANGING  ct_ifaces   = rt_ifaces ).
    add_iface( EXPORTING iv_iface_id = gc_iface-wire iv_method = gc_method-wire iv_bank = gc_bank-jpmc
               CHANGING  ct_ifaces   = rt_ifaces ).
    add_iface( EXPORTING iv_iface_id = gc_iface-ach_boa iv_method = gc_method-ach iv_bank = gc_bank-boa
               CHANGING  ct_ifaces   = rt_ifaces ).
    add_iface( EXPORTING iv_iface_id = gc_iface-pospay iv_method = gc_method-check iv_bank = gc_bank-pnc
               CHANGING  ct_ifaces   = rt_ifaces ).
    add_iface( EXPORTING iv_iface_id = gc_iface-blackline iv_method = space iv_bank = space
               CHANGING  ct_ifaces   = rt_ifaces ).
  ENDMETHOD.


  METHOD add_iface.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    ls_iface-iface_id   = iv_iface_id.
    ls_iface-direction  = zif_cd_fmon_types=>gc_direction-outbound.
    ls_iface-pay_method = iv_method.
    ls_iface-bank_key   = iv_bank.
    ls_iface-active     = abap_true.
    INSERT ls_iface INTO TABLE ct_ifaces.
  ENDMETHOD.


  METHOD throttle.
    rs_throttle-minutes   = iv_minutes.
    rs_throttle-scope     = iv_scope.
    rs_throttle-methods   = gc_method-list.
    rs_throttle-queue_max = gc_queue_max.
  ENDMETHOD.


  METHOD receipt.
    rv_at = plus( iv_at = gc_t1700 iv_secs = ( iv_no - 1 ) * gc_receipt_step ).
  ENDMETHOD.


  METHOD plus.
    TRY.
        rv_at = cl_abap_tstmp=>add( tstmp = iv_at secs = iv_secs ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Invalid test time: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD file_id.
    rv_id = CONV zif_cd_fmon_types=>ty_file_id( iv_no ).
  ENDMETHOD.


  METHOD add_file.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    ls_file-file_id        = file_id( iv_no ).
    ls_file-iface_id       = iv_iface_id.
    ls_file-direction      = zif_cd_fmon_types=>gc_direction-outbound.
    ls_file-file_name      = |FILE_{ iv_no }|.
    ls_file-business_date  = gc_date.
    ls_file-stage          = zif_cd_fmon_types=>gc_stage-sent.
    ls_file-first_event_at = gc_t1650.
    ls_file-last_event_at  = gc_t1650.
    INSERT ls_file INTO TABLE mt_files.
    add_event( iv_no = iv_no iv_stage = zif_cd_fmon_types=>gc_stage-sent iv_at = gc_t1650 ).
    IF iv_received IS NOT INITIAL.
      add_event( iv_no = iv_no iv_stage = zif_cd_fmon_types=>gc_stage-prism_received iv_at = iv_received ).
    ENDIF.
  ENDMETHOD.


  METHOD add_event.
    DATA ls_event TYPE zif_cd_fmon_types=>ty_event.
    ls_event-file_id  = file_id( iv_no ).
    ls_event-stage    = iv_stage.
    ls_event-event_at = iv_at.
    INSERT ls_event INTO TABLE mt_events.
  ENDMETHOD.


  METHOD add_cycle.
    DO iv_files TIMES.
      add_file( iv_no = sy-index iv_received = receipt( sy-index ) ).
    ENDDO.
  ENDMETHOD.


  METHOD position.
    rs_pos = zcl_cd_fmon_rules=>queue_position( iv_file_id  = file_id( iv_no )
                                               it_queue    = zcl_cd_fmon_rules=>build_queue(
                                                               it_files    = mt_files
                                                               it_events   = mt_events
                                                               it_ifaces   = ifaces( )
                                                               is_throttle = is_throttle )
                                               is_throttle = is_throttle ).
  ENDMETHOD.


  METHOD verdict.
    DATA ls_sla TYPE zif_cd_fmon_types=>ty_sla.
    ls_sla-iface_id    = gc_iface-ach.
    ls_sla-stage       = iv_stage.
    ls_sla-max_minutes = iv_max_minutes.
    ls_sla-basis       = iv_basis.
    ls_sla-severity    = zif_cd_ops_types=>gc_severity-error.
    rs_verdict = zcl_cd_fmon_rules=>sla_verdict(
                   is_file      = mt_files[ file_id = file_id( iv_no ) ]
                   is_sla       = ls_sla
                   it_events    = mt_events
                   iv_now       = plus( iv_at = gc_t1700 iv_secs = 86400 )
                   iv_queue_min = position( iv_no = iv_no is_throttle = is_throttle )-delay_min ).
  ENDMETHOD.


  " Rule: a file alone in the PRISM queue gets the base SLA only - delivered after 6 min with
  " SLA 5 is late.
  METHOD single_file_gets_base_sla.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_queue_pos.
    TRY.
        add_cycle( 1 ).
        add_event( iv_no = 1 iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                   iv_at = plus( iv_at = receipt( 1 ) iv_secs = 360 ) ).
        ls_exp-queued = abap_true.
        cl_abap_unit_assert=>assert_equals( act = position( iv_no = 1 is_throttle = throttle( ) ) exp = ls_exp
                                            msg = 'A file alone has nobody ahead and no allowance' ).
        DATA(ls_verdict) = verdict( iv_no = 1 is_throttle = throttle( ) ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_verdict-state }/{ ls_verdict-allowed_min }|
                                            exp = |{ zif_cd_fmon_types=>gc_sla_state-late }/{ gc_base_min }|
                                            msg = 'Delivery after 6 min (SLA 5, no queue) must be late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: 5 ACH files received together - the 5th waits for 4 files at 2 min each, so its
  " delivery 9 min after receipt is on time (allowed 5 + 4 x 2 = 13 min).
  METHOD fifth_file_on_time_at_9_min.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_queue_pos.
    TRY.
        add_cycle( 5 ).
        add_event( iv_no = 5 iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                   iv_at = plus( iv_at = receipt( 5 ) iv_secs = 540 ) ).
        ls_exp-queued    = abap_true.
        ls_exp-ahead     = 4.
        ls_exp-counted   = 4.
        ls_exp-delay_min = 8.
        cl_abap_unit_assert=>assert_equals( act = position( iv_no = 5 is_throttle = throttle( ) ) exp = ls_exp
                                            msg = 'The 5th file has 4 files ahead: 8 min allowance' ).
        DATA(ls_verdict) = verdict( iv_no = 5 is_throttle = throttle( ) ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_verdict-state }/{ ls_verdict-elapsed_min }/|
                                               && |{ ls_verdict-allowed_min }/{ ls_verdict-queue_min }|
                                            exp = |{ zif_cd_fmon_types=>gc_sla_state-ok }/9/13/8|
                                            msg = 'Delivered after 9 min, allowed 13 min: on time' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the allowance is not open-ended - the 5th file delivered 14 min after receipt
  " (base 5 + 8 + 1) is late.
  METHOD fifth_file_late_after_13_min.
    TRY.
        add_cycle( 5 ).
        add_event( iv_no = 5 iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                   iv_at = plus( iv_at = receipt( 5 ) iv_secs = 840 ) ).
        DATA(ls_verdict) = verdict( iv_no = 5 is_throttle = throttle( ) ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_verdict-state }/{ ls_verdict-elapsed_min }/|
                                               && |{ ls_verdict-allowed_min }|
                                            exp = |{ zif_cd_fmon_types=>gc_sla_state-late }/14/13|
                                            msg = 'Delivered after 14 min, allowed 13 min: late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: scope A = one PRISM queue for all throttled files (the wire waits behind 3 ACH files);
  " scope C = one queue per bank (the JPMC wire has nobody ahead, the PNC ACH files keep theirs).
  METHOD scope_c_queues_per_bank.
    TRY.
        add_cycle( 3 ).
        add_file( iv_no = 4 iv_iface_id = gc_iface-wire iv_received = receipt( 4 ) ).
        DATA(lv_scope_c) = zif_cd_fmon_types=>gc_queue_scope-counterparty.
        cl_abap_unit_assert=>assert_equals(
          act = |{ position( iv_no = 4 is_throttle = throttle( iv_scope = zif_cd_fmon_types=>gc_queue_scope-all ) )-ahead }/|
             && |{ position( iv_no = 4 is_throttle = throttle( iv_scope = lv_scope_c ) )-ahead }/|
             && |{ position( iv_no = 3 is_throttle = throttle( iv_scope = lv_scope_c ) )-ahead }|
          exp = |3/0/2|
          msg = 'Scope A: one queue (3 ahead); scope C: per bank (0 for JPMC, 2 for the 3rd PNC file)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (confirmed by the user 2026-11-06, design review 2026-11-07): the delivered queue scope
  " is C - one PRISM queue per bank.
  METHOD default_scope_is_per_bank.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = throttle( )-scope
                                            exp = zif_cd_fmon_types=>gc_queue_scope-counterparty
                                            msg = 'FMON_PRISM_THROTTLE_SCOPE must default to C (one queue per bank)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (scope C, the default): bank queues are independent. Three JPMC wires reach PRISM before
  " a BOA ACH file; the JPMC files are not counted in the BOA file's position, so the BOA file gets
  " the base SLA only (delivered after 6 min with SLA 5 is late) while the 3rd JPMC wire keeps
  " its 2 files ahead.
  METHOD bank_queues_do_not_wait.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_queue_pos.
    TRY.
        add_file( iv_no = 1 iv_iface_id = gc_iface-wire iv_received = receipt( 1 ) ).
        add_file( iv_no = 2 iv_iface_id = gc_iface-wire iv_received = receipt( 2 ) ).
        add_file( iv_no = 3 iv_iface_id = gc_iface-wire iv_received = receipt( 3 ) ).
        add_file( iv_no = 4 iv_iface_id = gc_iface-ach_boa iv_received = receipt( 4 ) ).
        add_event( iv_no = 4 iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                   iv_at = plus( iv_at = receipt( 4 ) iv_secs = 360 ) ).
        ls_exp-queued = abap_true.
        cl_abap_unit_assert=>assert_equals( act = position( iv_no = 4 is_throttle = throttle( ) ) exp = ls_exp
                                            msg = 'No JPMC file may count in the BOA queue position' ).
        cl_abap_unit_assert=>assert_equals( act = position( iv_no = 3 is_throttle = throttle( ) )-ahead
                                            exp = 2
                                            msg = 'The 3rd JPMC wire keeps the 2 JPMC files ahead' ).
        DATA(ls_verdict) = verdict( iv_no = 4 is_throttle = throttle( ) ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_verdict-state }/{ ls_verdict-allowed_min }|
                                            exp = |{ zif_cd_fmon_types=>gc_sla_state-late }/{ gc_base_min }|
                                            msg = 'The BOA delivery gets no allowance for the JPMC queue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: scope A, when configured, is still one queue for every throttled file - the same BOA
  " file has the 3 JPMC wires ahead and its delivery after 6 min is on time (5 + 3 x 2 = 11 min).
  METHOD scope_a_one_queue_when_set.
    TRY.
        add_file( iv_no = 1 iv_iface_id = gc_iface-wire iv_received = receipt( 1 ) ).
        add_file( iv_no = 2 iv_iface_id = gc_iface-wire iv_received = receipt( 2 ) ).
        add_file( iv_no = 3 iv_iface_id = gc_iface-wire iv_received = receipt( 3 ) ).
        add_file( iv_no = 4 iv_iface_id = gc_iface-ach_boa iv_received = receipt( 4 ) ).
        add_event( iv_no = 4 iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                   iv_at = plus( iv_at = receipt( 4 ) iv_secs = 360 ) ).
        DATA(ls_scope_a) = throttle( iv_scope = zif_cd_fmon_types=>gc_queue_scope-all ).
        cl_abap_unit_assert=>assert_equals( act = position( iv_no = 4 is_throttle = ls_scope_a )-ahead
                                            exp = 3
                                            msg = 'Scope A: the JPMC wires are ahead of the BOA file' ).
        DATA(ls_verdict) = verdict( iv_no = 4 is_throttle = ls_scope_a ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_verdict-state }/{ ls_verdict-allowed_min }|
                                            exp = |{ zif_cd_fmon_types=>gc_sla_state-ok }/|
                                               && |{ gc_base_min + 3 * gc_throttle_min }|
                                            msg = 'Scope A: delivery after 6 min is within 5 + 3 x 2 min' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (user 2026-11-06): only ACH and wire files are throttled. A positive pay or a BlackLine
  " file sent in the same cycle is neither queued itself nor counted in the ACH queue.
  METHOD pospay_not_throttled.
    TRY.
        add_file( iv_no = 1 iv_received = receipt( 1 ) ).
        add_file( iv_no = 2 iv_iface_id = gc_iface-pospay iv_received = receipt( 2 ) ).
        add_file( iv_no = 3 iv_iface_id = gc_iface-blackline iv_received = receipt( 3 ) ).
        add_file( iv_no = 4 iv_received = receipt( 4 ) ).
        DATA(lt_ifaces) = ifaces( ).
        cl_abap_unit_assert=>assert_equals(
          act = |{ zcl_cd_fmon_rules=>is_throttled( is_iface    = lt_ifaces[ iface_id = gc_iface-ach ]
                                                    is_throttle = throttle( ) ) }/|
             && |{ zcl_cd_fmon_rules=>is_throttled( is_iface    = lt_ifaces[ iface_id = gc_iface-wire ]
                                                    is_throttle = throttle( ) ) }/|
             && |{ zcl_cd_fmon_rules=>is_throttled( is_iface    = lt_ifaces[ iface_id = gc_iface-pospay ]
                                                    is_throttle = throttle( ) ) }/|
             && |{ zcl_cd_fmon_rules=>is_throttled( is_iface    = lt_ifaces[ iface_id = gc_iface-blackline ]
                                                    is_throttle = throttle( ) ) }|
          exp = |{ abap_true }/{ abap_true }//|
          msg = 'ACH and wire are throttled; positive pay and BlackLine are not' ).
        cl_abap_unit_assert=>assert_equals(
          act = |{ position( iv_no = 4 is_throttle = throttle( ) )-ahead }/|
             && |{ position( iv_no = 2 is_throttle = throttle( ) )-queued }/|
             && |{ position( iv_no = 3 is_throttle = throttle( ) )-queued }|
          exp = |1//|
          msg = 'Only the earlier ACH file is ahead; the others are not queued' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the allowance covers a queue of up to FMON_PRISM_QUEUE_MAX (30) files. The 31st file
  " gets no more than the 30th (29 files ahead counted) and its queue is reported as long.
  METHOD queue_over_max_is_long.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_queue_pos.
    TRY.
        add_cycle( gc_queue_max + 1 ).
        ls_exp-queued    = abap_true.
        ls_exp-ahead     = gc_queue_max.
        ls_exp-counted   = gc_queue_max - 1.
        ls_exp-delay_min = ( gc_queue_max - 1 ) * gc_throttle_min.
        ls_exp-long      = abap_true.
        cl_abap_unit_assert=>assert_equals( act = position( iv_no = gc_queue_max + 1 is_throttle = throttle( ) )
                                            exp = ls_exp
                                            msg = 'Queue of 31 files: allowance capped, PRISM_QUEUE_LONG' ).
        cl_abap_unit_assert=>assert_false( act = position( iv_no = gc_queue_max is_throttle = throttle( ) )-long
                                           msg = 'A queue of exactly 30 files is still covered' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an ACK SLA measured from generation (basis G) is shifted by the same queue wait:
  " 5th file, ACK SLA 240 min, ACK 247 min after the first event is on time (allowed 248).
  METHOD ack_from_generation_shifted.
    TRY.
        add_cycle( 5 ).
        add_event( iv_no = 5 iv_stage = zif_cd_fmon_types=>gc_stage-ack
                   iv_at = plus( iv_at = gc_t1650 iv_secs = 14820 ) ).
        DATA(ls_verdict) = verdict( iv_no          = 5
                                    iv_stage       = zif_cd_fmon_types=>gc_stage-ack
                                    iv_basis       = zif_cd_fmon_types=>gc_sla_basis-generation
                                    iv_max_minutes = 240
                                    is_throttle    = throttle( ) ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_verdict-state }/{ ls_verdict-elapsed_min }/|
                                               && |{ ls_verdict-allowed_min }|
                                            exp = |{ zif_cd_fmon_types=>gc_sla_state-ok }/247/248|
                                            msg = 'ACK after 247 min with 240 + 8 allowed: on time' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an ACK SLA measured from the previous stage (basis P) starts at the recorded delivery
  " - the queue wait is already behind it, so no allowance is added.
  METHOD ack_after_delivery_not_shifted.
    TRY.
        add_cycle( 5 ).
        DATA(lv_delivered) = plus( iv_at = receipt( 5 ) iv_secs = 540 ).
        add_event( iv_no = 5 iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered iv_at = lv_delivered ).
        add_event( iv_no = 5 iv_stage = zif_cd_fmon_types=>gc_stage-ack
                   iv_at = plus( iv_at = lv_delivered iv_secs = 3660 ) ).
        DATA(ls_verdict) = verdict( iv_no          = 5
                                    iv_stage       = zif_cd_fmon_types=>gc_stage-ack
                                    iv_max_minutes = 60
                                    is_throttle    = throttle( ) ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_verdict-state }/{ ls_verdict-queue_min }/|
                                               && |{ ls_verdict-allowed_min }|
                                            exp = |{ zif_cd_fmon_types=>gc_sla_state-late }/0/60|
                                            msg = 'ACK 61 min after delivery (basis P, SLA 60): late, no allowance' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: FMON_PRISM_THROTTLE_MIN = 0 is today's behaviour - no queue, base SLA only.
  METHOD zero_throttle_keeps_today.
    TRY.
        add_cycle( 5 ).
        add_event( iv_no = 5 iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                   iv_at = plus( iv_at = receipt( 5 ) iv_secs = 540 ) ).
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_fmon_rules=>build_queue( it_files    = mt_files
                                                it_events   = mt_events
                                                it_ifaces   = ifaces( )
                                                is_throttle = throttle( iv_minutes = 0 ) )
          msg = 'Throttle 0: no PRISM queue' ).
        DATA(ls_verdict) = verdict( iv_no = 5 is_throttle = throttle( iv_minutes = 0 ) ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_verdict-state }/{ ls_verdict-allowed_min }|
                                            exp = |{ zif_cd_fmon_types=>gc_sla_state-late }/{ gc_base_min }|
                                            msg = 'Throttle 0: delivery after 9 min with SLA 5 is late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without PRISM_RECEIVED evidence a file has no queue position (today's behaviour) and
  " is not counted ahead of others.
  METHOD no_receipt_keeps_today.
    TRY.
        add_file( iv_no = 1 ).
        add_file( iv_no = 2 iv_received = receipt( 2 ) ).
        cl_abap_unit_assert=>assert_equals(
          act = |{ position( iv_no = 1 is_throttle = throttle( ) )-queued }/|
             && |{ position( iv_no = 2 is_throttle = throttle( ) )-ahead }|
          exp = |/0|
          msg = 'No receipt evidence: not queued and not counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a file PRISM had already sent on (or failed) before this file arrived is not ahead.
  METHOD delivered_file_is_not_ahead.
    TRY.
        add_cycle( 3 ).
        add_event( iv_no = 1 iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered iv_at = receipt( 2 ) ).
        add_event( iv_no = 2 iv_stage = zif_cd_fmon_types=>gc_stage-prism_failed iv_at = receipt( 2 ) ).
        cl_abap_unit_assert=>assert_equals( act = position( iv_no = 3 is_throttle = throttle( ) )-ahead
                                            exp = 0
                                            msg = 'Files that left the queue before the receipt are not ahead' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! File generation identity (design review 2026-11-07): the instance of a file is fixed when the
"! file is first known and every later event of the same reference attaches to it, whatever its
"! own date or time; only a new generation opens a new instance. Times are UTC, business dates
"! US Central (FMON_TIME_ZONE CST): 23:58 CST on 1 Nov = 05:58 UTC on 2 Nov.
CLASS ltc_instance DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_day,
        first  TYPE d VALUE '20261101',
        second TYPE d VALUE '20261102',
        third  TYPE d VALUE '20261103',
      END OF gc_day.
    CONSTANTS:
      BEGIN OF gc_at,
        "! PRISM delivers to SAP at 23:58 CST on day 1, SAP receives at 00:03 CST on day 2
        delivered_2358 TYPE timestampl VALUE '20261102055800',
        received_0003  TYPE timestampl VALUE '20261102060300',
        "! A PRISM receipt just before midnight, the instance opened 30 seconds after midnight
        received_2359  TYPE timestampl VALUE '20261102055959',
        opened_0000    TYPE timestampl VALUE '20261102060030',
        "! The next day's file of the same name, and a later delivery of day 1's file
        next_day_file  TYPE timestampl VALUE '20261102150000',
        late_delivery  TYPE timestampl VALUE '20261103061500',
      END OF gc_at.
    "! Daylight saving in US Central: on 1 Nov 2026 01:00-02:00 local happens twice (CDT, then
    "! CST); on 8 Mar 2026 02:00-03:00 local does not exist
    CONSTANTS:
      BEGIN OF gc_dst,
        "! 01:30 CDT and 01:10 CST - the local clock goes back, 40 minutes pass
        fall_received  TYPE timestampl VALUE '20261101063000',
        fall_delivered TYPE timestampl VALUE '20261101071000',
        "! 01:50 CST and 03:15 CDT - the local clock jumps 85 minutes, 25 minutes pass
        spring_deliv   TYPE timestampl VALUE '20260308075000',
        spring_receipt TYPE timestampl VALUE '20260308081500',
        sla_min        TYPE i VALUE 30,
      END OF gc_dst.
    CONSTANTS:
      BEGIN OF gc_src,
        prism TYPE zif_cd_fmon_types=>ty_src_id VALUE 'PRISM',
        sap   TYPE zif_cd_fmon_types=>ty_src_id VALUE 'RTRV',
      END OF gc_src.
    CONSTANTS gc_iface TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'BAI_JPMC_IN'.
    CONSTANTS gc_ref TYPE zif_cd_fmon_types=>ty_file_ref VALUE 'BAI_JPMC_DAILY.TXT'.
    CONSTANTS gc_first_id TYPE zif_cd_fmon_types=>ty_file_id VALUE '00000000000000000000000000000001'.
    CONSTANTS gc_second_id TYPE zif_cd_fmon_types=>ty_file_id VALUE '00000000000000000000000000000002'.

    DATA mt_files TYPE zif_cd_fmon_types=>tt_file.
    DATA mt_events TYPE zif_cd_fmon_types=>tt_event.

    METHODS setup.

    "! A registered instance of the reference (iv_stage = the stage it reached)
    METHODS add_instance
      IMPORTING
        iv_id        TYPE zif_cd_fmon_types=>ty_file_id
        iv_date      TYPE d
        iv_stage     TYPE zif_cd_fmon_types=>ty_stage
        iv_direction TYPE zif_cd_fmon_types=>ty_direction DEFAULT zif_cd_fmon_types=>gc_direction-inbound
        iv_first_at  TYPE timestampl
        iv_outcome   TYPE zif_cd_fmon_types=>ty_stage OPTIONAL.

    METHODS add_event
      IMPORTING
        iv_id    TYPE zif_cd_fmon_types=>ty_file_id
        iv_src   TYPE zif_cd_fmon_types=>ty_src_id
        iv_stage TYPE zif_cd_fmon_types=>ty_stage
        iv_at    TYPE timestampl.

    METHODS pick
      IMPORTING
        iv_src         TYPE zif_cd_fmon_types=>ty_src_id DEFAULT gc_src-prism
        iv_stage       TYPE zif_cd_fmon_types=>ty_stage
        iv_direction   TYPE zif_cd_fmon_types=>ty_direction DEFAULT zif_cd_fmon_types=>gc_direction-inbound
        iv_date        TYPE d
        iv_at          TYPE timestampl
      RETURNING
        VALUE(rs_pick) TYPE zif_cd_fmon_types=>ty_instance_pick.

    METHODS same_date_instance_is_used FOR TESTING.
    METHODS receipt_after_midnight_joins FOR TESTING.
    METHODS reread_receipt_stays FOR TESTING.
    METHODS next_day_file_is_new FOR TESTING.
    METHODS next_day_generation_is_new FOR TESTING.
    METHODS later_stage_joins_any_date FOR TESTING.
    METHODS early_evidence_joins_later FOR TESTING.
    METHODS retry_after_failure_joins FOR TESTING.
    METHODS undated_two_instances_ambig FOR TESTING.
    METHODS first_evidence_without_file FOR TESTING.
    METHODS sla_utc_minutes_fall_back FOR TESTING.
    METHODS sla_utc_minutes_spring FOR TESTING.

    "! SLA verdict (basis P) of instance 1 for the stage
    METHODS dst_verdict
      IMPORTING
        iv_stage          TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rs_verdict) TYPE zif_cd_fmon_types=>ty_sla_verdict.

ENDCLASS.


CLASS ltc_instance IMPLEMENTATION.

  METHOD setup.
    CLEAR: mt_files, mt_events.
  ENDMETHOD.


  METHOD add_instance.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    ls_file-file_id        = iv_id.
    ls_file-iface_id       = gc_iface.
    ls_file-file_ref       = gc_ref.
    ls_file-direction      = iv_direction.
    ls_file-business_date  = iv_date.
    ls_file-stage          = iv_stage.
    ls_file-outcome        = iv_outcome.
    ls_file-first_event_at = iv_first_at.
    ls_file-last_event_at  = iv_first_at.
    INSERT ls_file INTO TABLE mt_files.
  ENDMETHOD.


  METHOD add_event.
    DATA ls_event TYPE zif_cd_fmon_types=>ty_event.
    ls_event-file_id  = iv_id.
    ls_event-src_id   = iv_src.
    ls_event-src_key  = gc_ref.
    ls_event-stage    = iv_stage.
    ls_event-event_at = iv_at.
    INSERT ls_event INTO TABLE mt_events.
  ENDMETHOD.


  METHOD pick.
    DATA ls_obs TYPE zif_cd_fmon_types=>ty_observation.
    ls_obs-src_id        = iv_src.
    ls_obs-file_ref      = gc_ref.
    ls_obs-stage         = iv_stage.
    ls_obs-direction     = iv_direction.
    ls_obs-business_date = iv_date.
    ls_obs-run_date      = gc_day-second.
    ls_obs-event_at      = iv_at.
    rs_pick = zcl_cd_fmon_rules=>file_instance( is_obs        = ls_obs
                                               it_candidates = mt_files
                                               it_events     = mt_events ).
  ENDMETHOD.


  " Rule: an instance of the observation's own business date is that file (the generation date
  " decides - a reference repeated on one business date is one file).
  METHOD same_date_instance_is_used.
    TRY.
        add_instance( iv_id = gc_first_id iv_date = gc_day-first iv_stage = zif_cd_fmon_types=>gc_stage-loaded
                      iv_first_at = gc_at-delivered_2358 ).
        add_instance( iv_id       = gc_second_id
                      iv_date     = gc_day-second
                      iv_stage    = zif_cd_fmon_types=>gc_stage-prism_received
                      iv_first_at = gc_at-next_day_file ).
        cl_abap_unit_assert=>assert_equals(
          act = pick( iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered iv_date = gc_day-second
                      iv_at = gc_at-next_day_file )-file_id
          exp = gc_second_id
          msg = 'The instance of the same business date must be used' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance (design review): PRISM delivers at 23:58 CST, SAP receives at 00:03 CST the next
  " business day - SAP's receipt continues the file PRISM opened: one instance, business date of
  " the first evidence.
  METHOD receipt_after_midnight_joins.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_instance_pick.
    TRY.
        add_instance( iv_id       = gc_first_id
                      iv_date     = gc_day-first
                      iv_stage    = zif_cd_fmon_types=>gc_stage-prism_delivered
                      iv_first_at = gc_at-delivered_2358 ).
        add_event( iv_id = gc_first_id iv_src = gc_src-prism iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                   iv_at = gc_at-delivered_2358 ).
        ls_exp-file_id = gc_first_id.
        cl_abap_unit_assert=>assert_equals(
          act = pick( iv_src = gc_src-sap iv_stage = zif_cd_fmon_types=>gc_stage-received iv_date = gc_day-second
                      iv_at = gc_at-received_0003 )
          exp = ls_exp
          msg = 'SAP''s receipt after midnight must attach to the file PRISM delivered before midnight' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the next 5-minute run reads SAP's receipt again - the event the instance already
  " recorded (same source, stage and time) stays with it, although the instance has reached
  " the stage.
  METHOD reread_receipt_stays.
    TRY.
        add_instance( iv_id = gc_first_id iv_date = gc_day-first iv_stage = zif_cd_fmon_types=>gc_stage-received
                      iv_first_at = gc_at-delivered_2358 ).
        add_event( iv_id = gc_first_id iv_src = gc_src-prism iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                   iv_at = gc_at-delivered_2358 ).
        add_event( iv_id = gc_first_id iv_src = gc_src-sap iv_stage = zif_cd_fmon_types=>gc_stage-received
                   iv_at = gc_at-received_0003 ).
        cl_abap_unit_assert=>assert_equals(
          act = pick( iv_src = gc_src-sap iv_stage = zif_cd_fmon_types=>gc_stage-received iv_date = gc_day-second
                      iv_at = gc_at-received_0003 )-file_id
          exp = gc_first_id
          msg = 'A re-read of a recorded receipt must not open a second instance' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance (design review): two different files with the same name on consecutive days -
  " PRISM's receipt of the next day's file, after day 1's file was loaded, is a new generation.
  METHOD next_day_file_is_new.
    TRY.
        add_instance( iv_id = gc_first_id iv_date = gc_day-first iv_stage = zif_cd_fmon_types=>gc_stage-loaded
                      iv_first_at = gc_at-received_2359 ).
        add_event( iv_id = gc_first_id iv_src = gc_src-prism iv_stage = zif_cd_fmon_types=>gc_stage-prism_received
                   iv_at = gc_at-received_2359 ).
        cl_abap_unit_assert=>assert_initial(
          act = pick( iv_stage = zif_cd_fmon_types=>gc_stage-prism_received iv_date = gc_day-second
                      iv_at = gc_at-next_day_file )
          msg = 'The next day''s file of the same name must open its own instance' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: outbound, a generation in SAP on a later business date is a new file even with the
  " same name (the generation date decides).
  METHOD next_day_generation_is_new.
    TRY.
        add_instance( iv_id        = gc_first_id
                      iv_date      = gc_day-first
                      iv_stage     = zif_cd_fmon_types=>gc_stage-ack
                      iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                      iv_first_at  = gc_at-delivered_2358
                      iv_outcome   = zif_cd_fmon_types=>gc_stage-ack ).
        cl_abap_unit_assert=>assert_initial(
          act = pick( iv_src       = gc_src-sap
                      iv_stage     = zif_cd_fmon_types=>gc_stage-generated
                      iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                      iv_date      = gc_day-second
                      iv_at        = gc_at-next_day_file )
          msg = 'A generation on a later date must open a new instance' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a later stage (not first evidence) attaches to the latest earlier instance whatever its
  " own date - PRISM's delivery two business days after the generation.
  METHOD later_stage_joins_any_date.
    TRY.
        add_instance( iv_id        = gc_first_id
                      iv_date      = gc_day-first
                      iv_stage     = zif_cd_fmon_types=>gc_stage-prism_received
                      iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                      iv_first_at  = gc_at-delivered_2358 ).
        cl_abap_unit_assert=>assert_equals(
          act = pick( iv_stage     = zif_cd_fmon_types=>gc_stage-prism_delivered
                      iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                      iv_date      = gc_day-third
                      iv_at        = gc_at-late_delivery )-file_id
          exp = gc_first_id
          msg = 'A later stage must attach to the file generated on an earlier date' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PRISM's receipt at 23:59:59 that reaches SAP after its delivery (00:00:30, which opened
  " the instance of day 2) is earlier evidence of the same file - it attaches, no second instance.
  METHOD early_evidence_joins_later.
    TRY.
        add_instance( iv_id       = gc_second_id
                      iv_date     = gc_day-second
                      iv_stage    = zif_cd_fmon_types=>gc_stage-prism_delivered
                      iv_first_at = gc_at-opened_0000 ).
        cl_abap_unit_assert=>assert_equals(
          act = pick( iv_stage = zif_cd_fmon_types=>gc_stage-prism_received iv_date = gc_day-first
                      iv_at = gc_at-received_2359 )-file_id
          exp = gc_second_id
          msg = 'Earlier evidence that arrives late must attach to the file it belongs to' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PRISM_FAILED before midnight and a successful retry (DELIVERED) after midnight are the
  " same file - the failed delivery has not reached PRISM_DELIVERED.
  METHOD retry_after_failure_joins.
    TRY.
        add_instance( iv_id       = gc_first_id
                      iv_date     = gc_day-first
                      iv_stage    = zif_cd_fmon_types=>gc_stage-prism_failed
                      iv_first_at = gc_at-delivered_2358
                      iv_outcome  = zif_cd_fmon_types=>gc_stage-prism_failed ).
        cl_abap_unit_assert=>assert_equals(
          act = pick( iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered iv_date = gc_day-second
                      iv_at = gc_at-received_0003 )-file_id
          exp = gc_first_id
          msg = 'A successful retry after midnight must attach to the failed file' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A49 kept: an undated later stage that matches instances of several dates is ambiguous.
  METHOD undated_two_instances_ambig.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_instance_pick.
    DATA lv_undated TYPE d.
    TRY.
        add_instance( iv_id        = gc_first_id
                      iv_date      = gc_day-first
                      iv_stage     = zif_cd_fmon_types=>gc_stage-sent
                      iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                      iv_first_at  = gc_at-delivered_2358 ).
        add_instance( iv_id        = gc_second_id
                      iv_date      = gc_day-second
                      iv_stage     = zif_cd_fmon_types=>gc_stage-sent
                      iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                      iv_first_at  = gc_at-next_day_file ).
        ls_exp-ambiguous = abap_true.
        cl_abap_unit_assert=>assert_equals(
          act = pick( iv_src       = gc_src-sap
                      iv_stage     = zif_cd_fmon_types=>gc_stage-ack
                      iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                      iv_date      = lv_undated
                      iv_at        = gc_at-late_delivery )
          exp = ls_exp
          msg = 'An undated ACK for two instances must be ambiguous' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the first evidence of a reference FMON does not know yet opens a new instance.
  METHOD first_evidence_without_file.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = pick( iv_stage = zif_cd_fmon_types=>gc_stage-prism_received iv_date = gc_day-first
                      iv_at = gc_at-received_2359 )
          msg = 'Without an instance the first evidence opens one (blank ID, not ambiguous)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD dst_verdict.
    DATA ls_sla TYPE zif_cd_fmon_types=>ty_sla.
    ls_sla-iface_id    = gc_iface.
    ls_sla-stage       = iv_stage.
    ls_sla-max_minutes = gc_dst-sla_min.
    ls_sla-basis       = zif_cd_fmon_types=>gc_sla_basis-previous.
    ls_sla-severity    = zif_cd_ops_types=>gc_severity-error.
    rs_verdict = zcl_cd_fmon_rules=>sla_verdict( is_file   = mt_files[ file_id = gc_first_id ]
                                                is_sla    = ls_sla
                                                it_events = mt_events
                                                iv_now    = gc_at-late_delivery ).
  ENDMETHOD.


  " Acceptance (design review, fall back): SLA minutes are UTC differences, never local clock
  " differences - received 01:30 CDT, delivered 01:10 CST = 40 minutes, late with SLA 30.
  METHOD sla_utc_minutes_fall_back.
    TRY.
        add_instance( iv_id = gc_first_id iv_date = gc_day-first iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                      iv_first_at = gc_dst-fall_received ).
        add_event( iv_id = gc_first_id iv_src = gc_src-prism iv_stage = zif_cd_fmon_types=>gc_stage-prism_received
                   iv_at = gc_dst-fall_received ).
        add_event( iv_id = gc_first_id iv_src = gc_src-prism iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                   iv_at = gc_dst-fall_delivered ).
        DATA(ls_fall) = dst_verdict( zif_cd_fmon_types=>gc_stage-prism_delivered ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_fall-state }/{ ls_fall-elapsed_min }|
                                            exp = |{ zif_cd_fmon_types=>gc_sla_state-late }/40|
                                            msg = 'Fall back: 40 UTC minutes across the repeated hour are late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance (design review, spring forward): delivered 01:50 CST, received by SAP 03:15 CDT =
  " 25 minutes (the local clock shows 85), on time with SLA 30.
  METHOD sla_utc_minutes_spring.
    TRY.
        add_instance( iv_id = gc_first_id iv_date = gc_day-first iv_stage = zif_cd_fmon_types=>gc_stage-received
                      iv_first_at = gc_dst-spring_deliv ).
        add_event( iv_id = gc_first_id iv_src = gc_src-prism iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                   iv_at = gc_dst-spring_deliv ).
        add_event( iv_id = gc_first_id iv_src = gc_src-sap iv_stage = zif_cd_fmon_types=>gc_stage-received
                   iv_at = gc_dst-spring_receipt ).
        DATA(ls_spring) = dst_verdict( zif_cd_fmon_types=>gc_stage-received ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_spring-state }/{ ls_spring-elapsed_min }|
                                            exp = |{ zif_cd_fmon_types=>gc_sla_state-ok }/25|
                                            msg = 'Spring forward: 25 UTC minutes across the missing hour are on time' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! Regenerated files (user 2026-11-07): a file PRISM could not deliver is regenerated under a new
"! name for the same payments; the generation group (payment run) links the generations
CLASS ltc_regen DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_iface TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_BOA_OUT'.
    CONSTANTS gc_other_iface TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'POSPAY_BOA_OUT'.
    CONSTANTS gc_group TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261102/RUN01/BOA1'.
    CONSTANTS gc_inner_blank TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261102//BOA1'.
    CONSTANTS gc_dup_code TYPE zif_cd_fmon_types=>ty_prism_error VALUE 'DUPLICATE_NAME'.
    CONSTANTS gc_prefix_code TYPE zif_cd_fmon_types=>ty_prism_error VALUE 'DUPLICATE'.
    CONSTANTS gc_wait_min TYPE i VALUE 60.
    CONSTANTS:
      BEGIN OF gc_id,
        failed TYPE zif_cd_fmon_types=>ty_file_id VALUE '00000000000000000000000000000011',
        regen  TYPE zif_cd_fmon_types=>ty_file_id VALUE '00000000000000000000000000000012',
        third  TYPE zif_cd_fmon_types=>ty_file_id VALUE '00000000000000000000000000000013',
        before TYPE zif_cd_fmon_types=>ty_file_id VALUE '00000000000000000000000000000010',
      END OF gc_id.
    CONSTANTS:
      BEGIN OF gc_name,
        failed TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_BOA_20261102_01.TXT',
        regen  TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_BOA_20261102_02.TXT',
        third  TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_BOA_20261102_03.TXT',
        before TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_BOA_20261102_00.TXT',
      END OF gc_name.
    "! UTC: generations at 16:50 / 17:00 / 17:40 / 18:30, PRISM failure at 17:10; the wait of 60
    "! minutes ends at 18:10 (on time) and is over at 18:11
    CONSTANTS:
      BEGIN OF gc_at,
        before    TYPE timestampl VALUE '20261102165000',
        failed    TYPE timestampl VALUE '20261102170000',
        failure   TYPE timestampl VALUE '20261102171000',
        regen     TYPE timestampl VALUE '20261102174000',
        third     TYPE timestampl VALUE '20261102183000',
        wait_end  TYPE timestampl VALUE '20261102181000',
        wait_over TYPE timestampl VALUE '20261102181100',
      END OF gc_at.

    DATA mt_generations TYPE zif_cd_fmon_types=>tt_file.
    DATA mt_events TYPE zif_cd_fmon_types=>tt_event.
    DATA mt_failures TYPE zif_cd_fmon_types=>tt_prism_failure.
    DATA ms_regen TYPE zif_cd_fmon_types=>ty_regen.

    METHODS setup.

    "! A generation of the group (outcome PRISM_FAILED when iv_failed, else stage iv_stage)
    METHODS add_generation
      IMPORTING
        iv_id     TYPE zif_cd_fmon_types=>ty_file_id
        iv_name   TYPE zif_cd_fmon_types=>ty_file_name
        iv_at     TYPE timestampl
        iv_stage  TYPE zif_cd_fmon_types=>ty_stage DEFAULT zif_cd_fmon_types=>gc_stage-prism_delivered
        iv_failed TYPE abap_bool DEFAULT abap_false
        iv_iface  TYPE zif_cd_fmon_types=>ty_iface_id DEFAULT gc_iface
        iv_group  TYPE zif_cd_fmon_types=>ty_file_ref DEFAULT gc_group.

    "! A PRISM failure of the failed file's name with an error code
    METHODS add_failure
      IMPORTING
        iv_code TYPE zif_cd_fmon_types=>ty_prism_error
        iv_at   TYPE timestampl DEFAULT gc_at-failure.

    METHODS generation
      IMPORTING
        iv_id          TYPE zif_cd_fmon_types=>ty_file_id
      RETURNING
        VALUE(rs_file) TYPE zif_cd_fmon_types=>ty_file.

    "! Verdict on the failed file at iv_now
    METHODS verdict
      IMPORTING
        iv_now            TYPE timestampl DEFAULT gc_at-wait_end
      RETURNING
        VALUE(rs_verdict) TYPE zif_cd_fmon_types=>ty_failed_verdict.

    METHODS key_joins_fields_in_order FOR TESTING.
    METHODS key_blank_values_no_link FOR TESTING.
    METHODS key_keeps_inner_blank FOR TESTING.
    METHODS failed_replaced_by_next FOR TESTING.
    METHODS no_group_stays_prism_failed FOR TESTING.
    METHODS other_iface_not_replacement FOR TESTING.
    METHODS earlier_file_not_replacement FOR TESTING.
    METHODS wait_end_not_missing FOR TESTING.
    METHODS wait_passed_is_missing FOR TESTING.
    METHODS zero_wait_never_missing FOR TESTING.
    METHODS dup_code_is_duplicate_name FOR TESTING.
    METHODS dup_code_ignores_case FOR TESTING.
    METHODS other_code_stays_failed FOR TESTING.
    METHODS empty_code_list_stays_failed FOR TESTING.
    METHODS dup_before_generation_ignored FOR TESTING.
    METHODS replaced_wins_over_dup_name FOR TESTING.
    METHODS regen_after_delivery_flagged FOR TESTING.
    METHODS regen_in_flight_flagged FOR TESTING.
    METHODS regen_after_failure_ok FOR TESTING.
    METHODS first_generation_not_flagged FOR TESTING.
    METHODS same_instant_ordered_by_id FOR TESTING.
    METHODS chain_uses_latest_earlier FOR TESTING.

ENDCLASS.


CLASS ltc_regen IMPLEMENTATION.

  METHOD setup.
    CLEAR: mt_generations, mt_events, mt_failures, ms_regen.
    ms_regen-wait_min  = gc_wait_min.
    ms_regen-dup_codes = gc_dup_code.
  ENDMETHOD.


  METHOD add_generation.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    DATA ls_event TYPE zif_cd_fmon_types=>ty_event.
    ls_file-file_id        = iv_id.
    ls_file-iface_id       = iv_iface.
    ls_file-direction      = zif_cd_fmon_types=>gc_direction-outbound.
    ls_file-file_name      = iv_name.
    ls_file-file_ref       = zcl_cd_fmon_util=>normalize_ref( iv_name ).
    ls_file-gen_group      = iv_group.
    ls_file-stage          = iv_stage.
    ls_file-first_event_at = iv_at.
    ls_file-last_event_at  = iv_at.
    IF iv_failed = abap_true.
      ls_file-stage         = zif_cd_fmon_types=>gc_stage-prism_failed.
      ls_file-outcome       = zif_cd_fmon_types=>gc_stage-prism_failed.
      ls_file-last_event_at = gc_at-failure.
      ls_event-file_id  = iv_id.
      ls_event-stage    = zif_cd_fmon_types=>gc_stage-prism_failed.
      ls_event-event_at = gc_at-failure.
      INSERT ls_event INTO TABLE mt_events.
    ENDIF.
    INSERT ls_file INTO TABLE mt_generations.
  ENDMETHOD.


  METHOD add_failure.
    DATA ls_failure TYPE zif_cd_fmon_types=>ty_prism_failure.
    ls_failure-file_ref    = zcl_cd_fmon_util=>normalize_ref( gc_name-failed ).
    ls_failure-error_code  = iv_code.
    ls_failure-occurred_at = iv_at.
    INSERT ls_failure INTO TABLE mt_failures.
  ENDMETHOD.


  METHOD generation.
    rs_file = VALUE #( mt_generations[ file_id = iv_id ] OPTIONAL ).
  ENDMETHOD.


  METHOD verdict.
    rs_verdict = zcl_cd_fmon_rules=>failed_verdict( is_file        = generation( gc_id-failed )
                                                    it_generations = mt_generations
                                                    it_events      = mt_events
                                                    it_failures    = mt_failures
                                                    is_regen       = ms_regen
                                                    iv_now         = iv_now ).
  ENDMETHOD.


  " Rule: the generation key is the configured fields' values in their order, joined by '/'.
  METHOD key_joins_fields_in_order.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>generation_key( VALUE #( ( `20261102` ) ( ` RUN01` ) ( `boa1` ) ( `` ) ) )
          exp = gc_group
          msg = 'Values condensed, upper case, trailing blank field dropped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a row whose group fields are all blank is not linked to any generation.
  METHOD key_blank_values_no_link.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_fmon_rules=>generation_key( VALUE #( ( `` ) ( ` ` ) ( `` ) ( `` ) ) )
          msg = 'No key, no link' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (boundary): a blank field between two values keeps its position, so two runs never collide.
  METHOD key_keeps_inner_blank.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>generation_key( VALUE #( ( `20261102` ) ( `` ) ( `BOA1` ) ) )
          exp = gc_inner_blank
          msg = 'The blank middle field stays a position' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (a): a failed file with a later generation of its group is replaced - information that
  " names the replacing file, no PRISM_FAILED.
  METHOD failed_replaced_by_next.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        add_generation( iv_id = gc_id-regen iv_name = gc_name-regen iv_at = gc_at-regen ).
        DATA(ls_verdict) = verdict( iv_now = gc_at-wait_over ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-code
                                            exp = zif_cd_fmon_types=>gc_check_code-file_replaced
                                            msg = 'The failure is answered by the regenerated file' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-replaced_by-file_name
                                            exp = gc_name-regen
                                            msg = 'The verdict names the replacing file' ).
        cl_abap_unit_assert=>assert_false( act = ls_verdict-regen_missing
                                           msg = 'A replaced file is not missing its regeneration' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (no group configured): exactly as before - PRISM_FAILED, never replaced, never missing.
  METHOD no_group_stays_prism_failed.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true
                        iv_group = space ).
        add_generation( iv_id = gc_id-regen iv_name = gc_name-regen iv_at = gc_at-regen iv_group = space ).
        DATA(ls_verdict) = verdict( iv_now = gc_at-wait_over ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-code
                                            exp = zif_cd_fmon_types=>gc_check_code-prism_failed
                                            msg = 'Without a generation group a failure stays PRISM_FAILED' ).
        cl_abap_unit_assert=>assert_false( act = ls_verdict-regen_missing
                                           msg = 'Without a generation group no REGENERATION_MISSING' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (negative): a file of another interface of the same payment run (e.g. positive pay of the
  " run) is not a regeneration.
  METHOD other_iface_not_replacement.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        add_generation( iv_id = gc_id-regen iv_name = gc_name-regen iv_at = gc_at-regen iv_iface = gc_other_iface ).
        cl_abap_unit_assert=>assert_equals( act = verdict( )-code
                                            exp = zif_cd_fmon_types=>gc_check_code-prism_failed
                                            msg = 'Another interface never replaces the file' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (negative): only a later generation replaces the failed file, never an earlier one.
  METHOD earlier_file_not_replacement.
    TRY.
        add_generation( iv_id = gc_id-before iv_name = gc_name-before iv_at = gc_at-before ).
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        cl_abap_unit_assert=>assert_equals( act = verdict( )-code
                                            exp = zif_cd_fmon_types=>gc_check_code-prism_failed
                                            msg = 'An earlier generation does not answer the failure' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (b, boundary): exactly FMON_REGEN_WAIT_MIN minutes after the failure is still in time.
  METHOD wait_end_not_missing.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        DATA(ls_verdict) = verdict( iv_now = gc_at-wait_end ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-failed_min
                                            exp = gc_wait_min
                                            msg = 'Minutes since the PRISM failure (UTC)' ).
        cl_abap_unit_assert=>assert_false( act = ls_verdict-regen_missing
                                           msg = 'At the end of the wait the regeneration is not overdue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (b): one minute after the wait, a failed file without regeneration is REGENERATION_MISSING
  " in addition to its PRISM_FAILED.
  METHOD wait_passed_is_missing.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        DATA(ls_verdict) = verdict( iv_now = gc_at-wait_over ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-code
                                            exp = zif_cd_fmon_types=>gc_check_code-prism_failed
                                            msg = 'PRISM_FAILED stays open and escalates as before' ).
        cl_abap_unit_assert=>assert_true( act = ls_verdict-regen_missing
                                          msg = 'The overdue regeneration is reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (b): FMON_REGEN_WAIT_MIN = 0 switches REGENERATION_MISSING off.
  METHOD zero_wait_never_missing.
    TRY.
        ms_regen-wait_min = 0.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        cl_abap_unit_assert=>assert_false( act = verdict( iv_now = gc_at-wait_over )-regen_missing
                                           msg = 'Wait 0 never reports a missing regeneration' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (d): PRISM rejected the name as already received - its own code, with PRISM's error code.
  METHOD dup_code_is_duplicate_name.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        add_failure( gc_dup_code ).
        DATA(ls_verdict) = verdict( iv_now = gc_at-wait_over ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-code
                                            exp = zif_cd_fmon_types=>gc_check_code-prism_dup_name
                                            msg = 'A duplicate name is reported as such' ).
        cl_abap_unit_assert=>assert_equals( act = ls_verdict-error_code
                                            exp = gc_dup_code
                                            msg = 'PRISM error code in the verdict' ).
        cl_abap_unit_assert=>assert_false( act = ls_verdict-regen_missing
                                           msg = 'The duplicate-name finding already says regenerate' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (d): the code list is matched to the whole value, case ignored.
  METHOD dup_code_ignores_case.
    TRY.
        ms_regen-dup_codes = to_lower( gc_dup_code ).
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        add_failure( gc_dup_code ).
        cl_abap_unit_assert=>assert_equals( act = verdict( )-code
                                            exp = zif_cd_fmon_types=>gc_check_code-prism_dup_name
                                            msg = 'A code in another case matches' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (d, negative): an error code outside the list is an ordinary PRISM failure; a code that
  " is only the beginning of a listed one does not match (whole value).
  METHOD other_code_stays_failed.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        add_failure( gc_prefix_code ).
        cl_abap_unit_assert=>assert_equals( act = verdict( )-code
                                            exp = zif_cd_fmon_types=>gc_check_code-prism_failed
                                            msg = 'Only a listed code is a duplicate name' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (d, delivered default): an empty code list never reports a duplicate name.
  METHOD empty_code_list_stays_failed.
    TRY.
        CLEAR ms_regen-dup_codes.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        add_failure( gc_dup_code ).
        cl_abap_unit_assert=>assert_equals( act = verdict( )-code
                                            exp = zif_cd_fmon_types=>gc_check_code-prism_failed
                                            msg = 'Default (codes to VERIFY with PRISM): no duplicate name' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (d, boundary): a failure before the file's first event belongs to an earlier generation.
  METHOD dup_before_generation_ignored.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        add_failure( iv_code = gc_dup_code iv_at = gc_at-before ).
        cl_abap_unit_assert=>assert_equals( act = verdict( )-code
                                            exp = zif_cd_fmon_types=>gc_check_code-prism_failed
                                            msg = 'An older failure of the name is not this generation' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: once the file is regenerated, the duplicate-name rejection is answered too.
  METHOD replaced_wins_over_dup_name.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        add_generation( iv_id = gc_id-regen iv_name = gc_name-regen iv_at = gc_at-regen ).
        add_failure( gc_dup_code ).
        cl_abap_unit_assert=>assert_equals( act = verdict( )-code
                                            exp = zif_cd_fmon_types=>gc_check_code-file_replaced
                                            msg = 'The regenerated file answers the rejection' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (c): a regenerated file whose earlier generation was delivered (also after a PRISM retry
  " superseded a failure) is a possible duplicate - the earlier generation is returned.
  METHOD regen_after_delivery_flagged.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed ).
        add_generation( iv_id = gc_id-regen iv_name = gc_name-regen iv_at = gc_at-regen ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>unfailed_predecessor( is_file        = generation( gc_id-regen )
                                                         it_generations = mt_generations )-file_id
          exp = gc_id-failed
          msg = 'Both generations delivered: the earlier one is named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (c): an earlier generation still in flight (generated, not yet at PRISM) also counts.
  METHOD regen_in_flight_flagged.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed
                        iv_stage = zif_cd_fmon_types=>gc_stage-generated ).
        add_generation( iv_id = gc_id-regen iv_name = gc_name-regen iv_at = gc_at-regen ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>unfailed_predecessor( is_file        = generation( gc_id-regen )
                                                         it_generations = mt_generations )-stage
          exp = zif_cd_fmon_types=>gc_stage-generated
          msg = 'The earlier generation in flight is a duplicate risk' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (c, negative): regeneration after a PRISM failure is the expected recovery.
  METHOD regen_after_failure_ok.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        add_generation( iv_id = gc_id-regen iv_name = gc_name-regen iv_at = gc_at-regen ).
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_fmon_rules=>unfailed_predecessor( is_file        = generation( gc_id-regen )
                                                         it_generations = mt_generations )
          msg = 'A replacement of a failed file is not a duplicate' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (c, negative): the first generation of a payment run is never a regeneration.
  METHOD first_generation_not_flagged.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed ).
        add_generation( iv_id = gc_id-regen iv_name = gc_name-regen iv_at = gc_at-regen ).
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_fmon_rules=>unfailed_predecessor( is_file        = generation( gc_id-failed )
                                                         it_generations = mt_generations )
          msg = 'Nothing was generated before the first file' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (boundary): two generations of the same instant are ordered by file ID - one of them is
  " the earlier, so a same-second regeneration is neither missed nor reported twice.
  METHOD same_instant_ordered_by_id.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed ).
        add_generation( iv_id = gc_id-regen iv_name = gc_name-regen iv_at = gc_at-failed ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>previous_generation( is_file        = generation( gc_id-regen )
                                                        it_generations = mt_generations )-file_id
          exp = gc_id-failed
          msg = 'The lower file ID is the earlier generation' ).
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_fmon_rules=>previous_generation( is_file        = generation( gc_id-failed )
                                                        it_generations = mt_generations )
          msg = 'The earlier one has no predecessor' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: generations chain pairwise - a failed file is replaced by the next one, a third generation
  " is judged against the second (the latest earlier one), not the first.
  METHOD chain_uses_latest_earlier.
    TRY.
        add_generation( iv_id = gc_id-failed iv_name = gc_name-failed iv_at = gc_at-failed iv_failed = abap_true ).
        add_generation( iv_id = gc_id-regen iv_name = gc_name-regen iv_at = gc_at-regen iv_failed = abap_true ).
        add_generation( iv_id = gc_id-third iv_name = gc_name-third iv_at = gc_at-third ).
        cl_abap_unit_assert=>assert_equals( act = verdict( )-replaced_by-file_id
                                            exp = gc_id-regen
                                            msg = 'The first failure is answered by the second generation' ).
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_fmon_rules=>unfailed_predecessor( is_file        = generation( gc_id-third )
                                                         it_generations = mt_generations )
          msg = 'The third generation replaces the failed second one' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_rules=>next_generation( is_file        = generation( gc_id-regen )
                                                    it_generations = mt_generations )-file_id
          exp = gc_id-third
          msg = 'The second failure is answered by the third generation' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
