*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_lifecycle.clas.testclasses.abap
*& Purpose:
*& Tests of the payment file lifecycle model on the scenarios of
*& config/payfile/fixtures.json (the offline reference model runs the
*& same): acknowledgement missing past 10:00 of the next business day
*& (flagship), reached late, payment-level partial acceptance, accepted
*& then rejected (conflict, latest answer decides), a later milestone
*& implies an earlier one, overnight cut-off, holiday, a stale source
*& (unknown, never missing), a cancelled job, a duplicate acknowledgement
*& (reached at the first answer), no acknowledgement milestones for a
*& file type without ACK, and the results of a business day (holiday,
*& valid zero volume, stale, not evaluated, missing, pending, OK). The
*& business calendar is a local double (weekends and 2026-11-26); every
*& time is UTC. No database. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! Weekends and 2026-11-26 are not business days
CLASS ltd_pf_calendar DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_calendar.
ENDCLASS.

CLASS ltd_pf_calendar IMPLEMENTATION.
  METHOD zif_ca_ops_pf_adapter~configure.
    " no setting
  ENDMETHOD.
  METHOD zif_ca_ops_pf_calendar~is_business_day.
    " 1900-01-01 was a Monday: day 5 and 6 of the week are Saturday and Sunday
    DATA(lv_weekday) = ( iv_date - CONV d( '19000101' ) ) MOD 7.
    rv_business = xsdbool( lv_weekday < 5 AND iv_date <> '20261126' ).
  ENDMETHOD.
  METHOD zif_ca_ops_pf_calendar~add_business_days.
    rv_date = iv_date.
    WHILE zif_ca_ops_pf_calendar~is_business_day( iv_calendar_id = iv_calendar_id iv_date = rv_date ) = abap_false.
      rv_date += 1.
    ENDWHILE.
    DO iv_days TIMES.
      rv_date += 1.
      WHILE zif_ca_ops_pf_calendar~is_business_day( iv_calendar_id = iv_calendar_id iv_date = rv_date ) = abap_false.
        rv_date += 1.
      ENDWHILE.
    ENDDO.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_pf_lifecycle DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_ca_ops_pf_lifecycle.
    DATA ms_type TYPE zif_ca_ops_pf_types=>ty_type_cfg.
    DATA mt_stages TYPE zif_ca_ops_pf_types=>tt_stage.
    DATA ms_file TYPE zif_ca_ops_pf_types=>ty_file.
    DATA mt_events TYPE zif_ca_ops_pf_types=>tt_event.

    METHODS setup.
    "! An event of the file
    METHODS event
      IMPORTING
        iv_milestone TYPE zif_ca_ops_pf_types=>ty_milestone
        iv_outcome   TYPE zif_ca_ops_pf_types=>ty_outcome DEFAULT zif_ca_ops_pf_types=>gc_outcome-ok
        iv_at        TYPE timestampl
        iv_pay_key   TYPE zif_ca_ops_pf_types=>ty_pay_key OPTIONAL.
    "! The flagship's events up to the bank's receipt
    METHODS until_receipt.
    METHODS evaluate
      IMPORTING
        iv_now         TYPE timestampl
        it_health      TYPE zcl_ca_ops_pf_lifecycle=>tt_health OPTIONAL
        it_payments    TYPE zif_ca_ops_pf_types=>tt_payment OPTIONAL
      RETURNING
        VALUE(rs_eval) TYPE zif_ca_ops_pf_types=>ty_eval.
    METHODS status_of
      IMPORTING
        is_eval          TYPE zif_ca_ops_pf_types=>ty_eval
        iv_milestone     TYPE zif_ca_ops_pf_types=>ty_milestone
      RETURNING
        VALUE(rv_status) TYPE zif_ca_ops_pf_types=>ty_ms_status.
    METHODS day
      IMPORTING
        iv_date          TYPE d
        iv_observed      TYPE i
        iv_status        TYPE zif_ca_ops_pf_types=>ty_flag DEFAULT zif_ca_ops_pf_types=>gc_src_status-read
        iv_as_of         TYPE timestampl
        iv_now           TYPE timestampl
      RETURNING
        VALUE(rv_result) TYPE zif_ca_ops_pf_types=>ty_day_result.

    METHODS ack_missing_flagship      FOR TESTING.
    METHODS ack_late_is_reached_late  FOR TESTING.
    METHODS payment_level_partial     FOR TESTING.
    METHODS conflict_latest_decides   FOR TESTING.
    METHODS overnight_cutoff          FOR TESTING.
    METHODS holiday_moves_deadline    FOR TESTING.
    METHODS stale_source_unknown      FOR TESTING.
    METHODS job_failed_state_failed   FOR TESTING.
    METHODS duplicate_ack_first_time  FOR TESTING.
    METHODS no_ack_type_skips_ack     FOR TESTING.
    METHODS rank_in_product_order     FOR TESTING.
    METHODS days_differ_by_reason     FOR TESTING.
ENDCLASS.


CLASS ltc_pf_lifecycle IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( io_calendar = NEW ltd_pf_calendar( ) ).
    ms_type = VALUE #( area = 'ZT_PF' file_type = 'PAYMENTS' ack_level = zif_ca_ops_pf_types=>gc_ack_level-file
                       calendar_id = 'ZT' time_zone = 'UTC' day_cutoff = '220000' expected_files = 1
                       zero_ok = abap_true stale_min = 120 active = abap_true ).
    mt_stages = VALUE #(
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-payrun required = abap_true active = abap_true )
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-generated required = abap_true active = abap_true
        due_kind = zif_ca_ops_pf_types=>gc_due_kind-offset basis = zif_ca_ops_pf_types=>gc_milestone-payrun offset_min = 60 )
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-pickup active = abap_true
        due_kind = zif_ca_ops_pf_types=>gc_due_kind-offset basis = zif_ca_ops_pf_types=>gc_milestone-generated offset_min = 30 )
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-delivered required = abap_true active = abap_true
        due_kind = zif_ca_ops_pf_types=>gc_due_kind-offset basis = zif_ca_ops_pf_types=>gc_milestone-generated offset_min = 60 )
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-receipt required = abap_true active = abap_true
        due_kind = zif_ca_ops_pf_types=>gc_due_kind-offset basis = zif_ca_ops_pf_types=>gc_milestone-delivered offset_min = 30 )
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-accepted required = abap_true active = abap_true
        due_kind = zif_ca_ops_pf_types=>gc_due_kind-clock due_time = '100000' day_offset = 1 )
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-settled active = abap_true
        due_kind = zif_ca_ops_pf_types=>gc_due_kind-clock due_time = '180000' day_offset = 2 ) ).
    ms_file = VALUE #( area = 'ZT_PF' file_type = 'PAYMENTS' native_key = 'F1' bus_date = '20261116'
                       gen_at = '20261116160000.0000000' pay_count = 1 ).
    CLEAR mt_events.
  ENDMETHOD.


  METHOD event.
    INSERT VALUE #( area = 'ZT_PF' event_key = |{ iv_milestone }{ lines( mt_events ) }| file_id = ms_file-file_id
                    milestone = iv_milestone outcome = iv_outcome occurred_at = iv_at pay_key = iv_pay_key )
           INTO TABLE mt_events.
  ENDMETHOD.


  METHOD until_receipt.
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-payrun    iv_at = '20261116160000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-generated iv_at = '20261116162000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-pickup    iv_at = '20261116163000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-delivered iv_at = '20261116164500.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-receipt   iv_at = '20261116170000.0000000' ).
  ENDMETHOD.


  METHOD evaluate.
    TRY.
        rs_eval = mo_cut->evaluate( is_type     = ms_type
                                    it_stages   = mt_stages
                                    is_file     = ms_file
                                    it_events   = mt_events
                                    it_payments = it_payments
                                    it_health   = it_health
                                    iv_now      = iv_now ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD status_of.
    rv_status = VALUE #( is_eval-milestones[ milestone = iv_milestone ]-status OPTIONAL ).
  ENDMETHOD.


  METHOD day.
    DATA lv_due TYPE timestampl.
    TRY.
        lv_due = mo_cut->clock_due( is_type = ms_type iv_date = iv_date iv_days = 1 iv_time = '100000' ).
        rv_result = mo_cut->evaluate_day( is_type      = ms_type
                                          is_input     = VALUE #( bus_date      = iv_date
                                                                  observed      = iv_observed
                                                                  source_status = iv_status
                                                                  as_of         = iv_as_of
                                                                  due_at        = lv_due )
                                          iv_stale_min = 120
                                          iv_now       = iv_now )-result.
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Flagship: the job finished, the bank received the file, no acceptance at 11:00 of the next business day
  METHOD ack_missing_flagship.
    until_receipt( ).
    DATA(ls_eval) = evaluate( '20261117110000.0000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-state exp = zif_ca_ops_pf_types=>gc_state-open msg = 'Open' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-stage exp = zif_ca_ops_pf_types=>gc_milestone-receipt
                                        msg = 'Stopped after the bank receipt' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-next_ms exp = zif_ca_ops_pf_types=>gc_milestone-accepted
                                        msg = 'Next: acceptance' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-overdue_min exp = 60 msg = 'Due 10:00, now 11:00' ).
    cl_abap_unit_assert=>assert_equals( act = CONV timestampl( ls_eval-deadline_at ) exp = '20261117100000.0000000'
                                        msg = '10:00 of the next business day' ).
    cl_abap_unit_assert=>assert_equals( act = status_of( is_eval = ls_eval iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted )
                                        exp = zif_ca_ops_pf_types=>gc_ms_status-missing msg = 'Acceptance missing' ).
    cl_abap_unit_assert=>assert_equals( act = status_of( is_eval = ls_eval iv_milestone = zif_ca_ops_pf_types=>gc_milestone-receipt )
                                        exp = zif_ca_ops_pf_types=>gc_ms_status-reached msg = 'Receipt is its own milestone' ).
  ENDMETHOD.


  METHOD ack_late_is_reached_late.
    until_receipt( ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted iv_at = '20261117103000.0000000' ).
    DATA(ls_eval) = evaluate( '20261117120000.0000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-state exp = zif_ca_ops_pf_types=>gc_state-done msg = 'Done' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-late_ms exp = zif_ca_ops_pf_types=>gc_milestone-accepted msg = 'Late' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-late_min exp = 30 msg = '30 minutes late' ).
  ENDMETHOD.


  METHOD payment_level_partial.
    ms_type-ack_level = zif_ca_ops_pf_types=>gc_ack_level-payment.
    until_receipt( ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted iv_at = '20261117080000.0000000' iv_pay_key = 'P1' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted iv_outcome = zif_ca_ops_pf_types=>gc_outcome-rejected
           iv_at = '20261117080000.0000000' iv_pay_key = 'P2' ).
    DATA(lt_payments) = VALUE zif_ca_ops_pf_types=>tt_payment( ( pay_key = 'P1' ) ( pay_key = 'P2' ) ( pay_key = 'P3' ) ).
    " before the deadline the open answer is still pending
    DATA(ls_before) = evaluate( iv_now = '20261117090000.0000000' it_payments = lt_payments ).
    cl_abap_unit_assert=>assert_equals( act = status_of( is_eval = ls_before iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted )
                                        exp = zif_ca_ops_pf_types=>gc_ms_status-pending msg = 'Pending before 10:00' ).
    DATA(ls_eval) = evaluate( iv_now = '20261117110000.0000000' it_payments = lt_payments ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-state exp = zif_ca_ops_pf_types=>gc_state-partial msg = 'Partial' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-pay_accepted exp = 1 msg = 'One accepted' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-pay_rejected exp = 1 msg = 'One rejected' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-pay_open exp = 1 msg = 'One without answer' ).
  ENDMETHOD.


  METHOD conflict_latest_decides.
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-payrun    iv_at = '20261116160000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-generated iv_at = '20261116162000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-delivered iv_at = '20261116164500.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted  iv_at = '20261117080000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted  iv_outcome = zif_ca_ops_pf_types=>gc_outcome-rejected
           iv_at = '20261117083000.0000000' ).
    DATA(ls_eval) = evaluate( '20261117110000.0000000' ).
    cl_abap_unit_assert=>assert_true( act = ls_eval-conflict msg = 'Conflict said' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-state exp = zif_ca_ops_pf_types=>gc_state-rejected msg = 'Latest decides' ).
    cl_abap_unit_assert=>assert_equals( act = status_of( is_eval = ls_eval iv_milestone = zif_ca_ops_pf_types=>gc_milestone-receipt )
                                        exp = zif_ca_ops_pf_types=>gc_ms_status-implied msg = 'Receipt implied' ).
  ENDMETHOD.


  METHOD overnight_cutoff.
    TRY.
        DATA(lv_date) = mo_cut->business_date( is_type = ms_type iv_gen_at = '20261116223000.0000000' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = lv_date exp = '20261117' msg = 'After 22:00: the next business date' ).
    ms_file-bus_date = lv_date.
    until_receipt( ).
    DATA(ls_eval) = evaluate( '20261117110000.0000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-overdue_min exp = 0 msg = 'Due a day later' ).
    cl_abap_unit_assert=>assert_equals( act = status_of( is_eval = ls_eval iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted )
                                        exp = zif_ca_ops_pf_types=>gc_ms_status-pending msg = 'Pending' ).
  ENDMETHOD.


  METHOD holiday_moves_deadline.
    TRY.
        DATA(lv_due) = mo_cut->clock_due( is_type = ms_type iv_date = '20261125' iv_days = 1 iv_time = '100000' ).
        DATA(lv_friday) = mo_cut->business_date( is_type = ms_type iv_gen_at = '20261121120000.0000000' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = CONV timestampl( lv_due ) exp = '20261127100000.0000000'
                                        msg = 'The holiday 26th is skipped' ).
    cl_abap_unit_assert=>assert_equals( act = lv_friday exp = '20261123' msg = 'Generated on Saturday: Monday' ).
  ENDMETHOD.


  METHOD stale_source_unknown.
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-payrun    iv_at = '20261116160000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-generated iv_at = '20261116162000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-delivered iv_at = '20261116164500.0000000' ).
    DATA(ls_eval) = evaluate(
      iv_now    = '20261117110000.0000000'
      it_health = VALUE #( ( milestone = zif_ca_ops_pf_types=>gc_milestone-receipt  eval = zif_ca_ops_pf_types=>gc_eval-stale )
                           ( milestone = zif_ca_ops_pf_types=>gc_milestone-accepted eval = zif_ca_ops_pf_types=>gc_eval-stale ) ) ).
    cl_abap_unit_assert=>assert_equals( act = status_of( is_eval = ls_eval iv_milestone = zif_ca_ops_pf_types=>gc_milestone-receipt )
                                        exp = zif_ca_ops_pf_types=>gc_ms_status-unknown msg = 'Unknown, not missing' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-overdue_min exp = 0 msg = 'Never overdue' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-eval_state exp = zif_ca_ops_pf_types=>gc_eval-stale msg = 'Stale' ).
  ENDMETHOD.


  METHOD job_failed_state_failed.
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-payrun    iv_at = '20261116160000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-generated iv_outcome = zif_ca_ops_pf_types=>gc_outcome-failed
           iv_at = '20261116162000.0000000' ).
    DATA(ls_eval) = evaluate( '20261116173000.0000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-state exp = zif_ca_ops_pf_types=>gc_state-failed msg = 'Failed' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-next_ms exp = zif_ca_ops_pf_types=>gc_milestone-generated msg = 'At generation' ).
  ENDMETHOD.


  METHOD duplicate_ack_first_time.
    until_receipt( ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted iv_at = '20261117104000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted iv_at = '20261117080000.0000000' ).
    DATA(ls_eval) = evaluate( '20261117110000.0000000' ).
    cl_abap_unit_assert=>assert_equals( act = status_of( is_eval = ls_eval iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted )
                                        exp = zif_ca_ops_pf_types=>gc_ms_status-reached msg = 'At its first answer, on time' ).
    cl_abap_unit_assert=>assert_false( act = ls_eval-conflict msg = 'Same answer twice: no conflict' ).
  ENDMETHOD.


  METHOD no_ack_type_skips_ack.
    ms_type-ack_level = zif_ca_ops_pf_types=>gc_ack_level-none.
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-payrun    iv_at = '20261116160000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-generated iv_at = '20261116162000.0000000' ).
    event( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-delivered iv_at = '20261116164500.0000000' ).
    DATA(ls_eval) = evaluate( '20261118110000.0000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_eval-state exp = zif_ca_ops_pf_types=>gc_state-done msg = 'Done at delivery' ).
    DATA(lv_has_ack) = xsdbool( line_exists( ls_eval-milestones[ milestone = zif_ca_ops_pf_types=>gc_milestone-accepted ] ) ).
    cl_abap_unit_assert=>assert_false( act = lv_has_ack msg = 'No acceptance milestone' ).
  ENDMETHOD.


  METHOD rank_in_product_order.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_pf_lifecycle=>rank( zif_ca_ops_pf_types=>gc_milestone-payrun )
                                        exp = 1 msg = 'First' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_pf_lifecycle=>rank( zif_ca_ops_pf_types=>gc_milestone-receipt )
                                        exp = 5 msg = 'Receipt' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_pf_lifecycle=>rank( zif_ca_ops_pf_types=>gc_milestone-accepted )
                                        exp = 6 msg = 'Acceptance' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_pf_lifecycle=>rank( 'OTHER' ) exp = 0 msg = 'Not a milestone' ).
  ENDMETHOD.


  " A holiday, a valid day without files, a stale source and a failed read are four different results
  METHOD days_differ_by_reason.
    cl_abap_unit_assert=>assert_equals( act = day( iv_date = '20261121' iv_observed = 0 iv_as_of = '20261123120000.0000000'
                                                   iv_now = '20261123120000.0000000' )
                                        exp = zif_ca_ops_pf_types=>gc_day-holiday msg = 'Holiday' ).
    cl_abap_unit_assert=>assert_equals( act = day( iv_date = '20261116' iv_observed = 0 iv_as_of = '20261117120000.0000000'
                                                   iv_now = '20261117120000.0000000' )
                                        exp = zif_ca_ops_pf_types=>gc_day-zero_ok msg = 'Valid zero volume' ).
    cl_abap_unit_assert=>assert_equals( act = day( iv_date = '20261116' iv_observed = 0 iv_as_of = '20261117060000.0000000'
                                                   iv_now = '20261117120000.0000000' )
                                        exp = zif_ca_ops_pf_types=>gc_day-stale msg = 'Stale' ).
    cl_abap_unit_assert=>assert_equals( act = day( iv_date   = '20261116' iv_observed = 0
                                                   iv_status = zif_ca_ops_pf_types=>gc_src_status-failed
                                                   iv_as_of  = '20261117120000.0000000' iv_now = '20261117120000.0000000' )
                                        exp = zif_ca_ops_pf_types=>gc_day-not_eval msg = 'Not evaluated' ).
    cl_abap_unit_assert=>assert_equals( act = day( iv_date = '20261116' iv_observed = 0 iv_as_of = '20261117090000.0000000'
                                                   iv_now = '20261117090000.0000000' )
                                        exp = zif_ca_ops_pf_types=>gc_day-pending msg = 'Pending' ).
    cl_abap_unit_assert=>assert_equals( act = day( iv_date = '20261116' iv_observed = 1 iv_as_of = '20261117120000.0000000'
                                                   iv_now = '20261117120000.0000000' )
                                        exp = zif_ca_ops_pf_types=>gc_day-ok msg = 'OK' ).
    ms_type-zero_ok = abap_false.
    cl_abap_unit_assert=>assert_equals( act = day( iv_date = '20261116' iv_observed = 0 iv_as_of = '20261117120000.0000000'
                                                   iv_now = '20261117120000.0000000' )
                                        exp = zif_ca_ops_pf_types=>gc_day-missing msg = 'Missing' ).
  ENDMETHOD.

ENDCLASS.
