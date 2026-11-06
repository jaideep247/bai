*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_event.clas.testclasses.abap
*& Purpose:
*& Pure unit tests of the PRISM status API event logic: parsing, field rules,
*& masking, truncation, mapping (outbound / inbound, every milestone), idempotent
*& payload comparison and the JSON answer. Static ABAP Unit only; does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, user decision 2026-11-06).
*&---------------------------------------------------------------------*
CLASS ltc_event DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    "! Scenario intent: which members the body carries
    TYPES:
      BEGIN OF ty_flags,
        direction   TYPE string,
        milestone   TYPE string,
        occurred_at TYPE string,
        no_event_id TYPE abap_bool,
        no_file_ref TYPE abap_bool,
        error_text  TYPE string,
        extra       TYPE string,
      END OF ty_flags.

    CONSTANTS:
      BEGIN OF gc_test,
        event_id    TYPE string VALUE `PRISM-0001`,
        file_ref    TYPE string VALUE `ACH_PNC_20261106_01.txt`,
        occurred_at TYPE string VALUE `2026-11-06T14:30:00Z`,
        occurred_ts TYPE timestampl VALUE '20261106143000',
        now         TYPE timestampl VALUE '20261106143500',
        counterpart TYPE string VALUE `PNC`,
        user        TYPE syuname VALUE 'PRISM_TECH',
        time_zone   TYPE zif_cd_fmon_types=>ty_time_zone VALUE 'EST',
        early_utc   TYPE string VALUE `2026-11-06T03:00:00Z`,
      END OF gc_test.

    DATA ms_context TYPE zif_cd_fmon_prism_types=>ty_map_context.

    METHODS setup.

    METHODS body
      IMPORTING
        is_flags       TYPE ty_flags
      RETURNING
        VALUE(rv_json) TYPE string.

    METHODS act
      IMPORTING
        iv_json          TYPE string
      RETURNING
        VALUE(rs_mapped) TYPE zif_cd_fmon_prism_types=>ty_mapped.

    METHODS error_codes
      IMPORTING
        it_errors       TYPE zif_cd_fmon_prism_types=>tt_error
      RETURNING
        VALUE(rt_codes) TYPE string_table.

    METHODS outbound_received_maps_row FOR TESTING.
    METHODS outbound_delivered_maps FOR TESTING.
    METHODS failed_keeps_error_code FOR TESTING.
    METHODS inbound_direction_maps_i FOR TESTING.
    METHODS missing_fields_all_listed FOR TESTING.
    METHODS bad_timestamp_rejected FOR TESTING.
    METHODS non_utc_offset_rejected FOR TESTING.
    METHODS future_time_rejected FOR TESTING.
    METHODS fraction_seconds_kept FOR TESTING.
    METHODS unknown_milestone_rejected FOR TESTING.
    METHODS long_error_text_truncated FOR TESTING.
    METHODS account_number_masked FOR TESTING.
    METHODS total_needs_currency FOR TESTING.
    METHODS any_counterparty_accepted FOR TESTING.
    METHODS malformed_json_one_error FOR TESTING.
    METHODS array_body_not_an_object FOR TESTING.
    METHODS nested_member_rejected FOR TESTING.
    METHODS business_date_in_time_zone FOR TESTING.
    METHODS same_payload_ignores_receipt FOR TESTING.
    METHODS answer_json_has_contract FOR TESTING.

ENDCLASS.


CLASS ltc_event IMPLEMENTATION.

  METHOD setup.
    CLEAR ms_context.
    ms_context-now       = gc_test-now.
    ms_context-user      = gc_test-user.
    ms_context-time_zone = zif_cd_ops_types=>gc_time_zone_utc.
  ENDMETHOD.


  METHOD body.
    DATA(lv_direction) = COND string( WHEN is_flags-direction IS NOT INITIAL THEN is_flags-direction
                                      ELSE `OUTBOUND` ).
    DATA(lv_milestone) = COND string( WHEN is_flags-milestone IS NOT INITIAL THEN is_flags-milestone
                                      ELSE `RECEIVED` ).
    DATA(lv_occurred) = COND string( WHEN is_flags-occurred_at IS NOT INITIAL THEN is_flags-occurred_at
                                     ELSE gc_test-occurred_at ).
    rv_json = `{`.
    IF is_flags-no_event_id = abap_false.
      rv_json = rv_json && |"eventId":"{ gc_test-event_id }",|.
    ENDIF.
    IF is_flags-no_file_ref = abap_false.
      rv_json = rv_json && |"fileReference":"{ gc_test-file_ref }",|.
    ENDIF.
    rv_json = rv_json && |"direction":"{ lv_direction }","milestone":"{ lv_milestone }",|
                      && |"occurredAt":"{ lv_occurred }","counterparty":"{ gc_test-counterpart }"|.
    IF is_flags-error_text IS NOT INITIAL.
      rv_json = rv_json && |,"errorCode":"BANK-TIMEOUT","errorText":"{ is_flags-error_text }"|.
    ENDIF.
    rv_json = |{ rv_json }{ is_flags-extra }\}|.
  ENDMETHOD.


  METHOD act.
    rs_mapped = zcl_cd_fmon_prism_event=>map(
                  is_parsed  = zcl_cd_fmon_prism_event=>parse( cl_abap_codepage=>convert_to( iv_json ) )
                  is_context = ms_context ).
  ENDMETHOD.


  METHOD error_codes.
    LOOP AT it_errors ASSIGNING FIELD-SYMBOL(<ls_error>).
      INSERT |{ <ls_error>-code }:{ <ls_error>-field }| INTO TABLE rt_codes.
    ENDLOOP.
    SORT rt_codes.
  ENDMETHOD.


  " Rule: a valid outbound RECEIVED event maps to the stored row field by field.
  METHOD outbound_received_maps_row.
    DATA ls_exp TYPE zif_cd_fmon_prism_types=>ty_row.
    TRY.
        ls_exp-event_id      = gc_test-event_id.
        ls_exp-file_ref      = gc_test-file_ref.
        ls_exp-direction     = zif_cd_fmon_types=>gc_direction-outbound.
        ls_exp-milestone     = zif_cd_fmon_prism_types=>gc_milestone-received.
        ls_exp-occurred_at   = gc_test-occurred_ts.
        ls_exp-counterparty  = gc_test-counterpart.
        ls_exp-business_date = '20261106'.
        ls_exp-received_at   = gc_test-now.
        ls_exp-received_by   = gc_test-user.
        DATA(ls_mapped) = act( body( VALUE #( ) ) ).
        cl_abap_unit_assert=>assert_initial( act = ls_mapped-errors msg = 'A valid event has no errors' ).
        cl_abap_unit_assert=>assert_equals( act = ls_mapped-row exp = ls_exp
                                            msg = 'The row must carry every field of the event' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: DELIVERED (lower case on the wire is accepted) with counts and total.
  METHOD outbound_delivered_maps.
    TRY.
        DATA(ls_mapped) = act( body( VALUE #( milestone = `delivered`
                                              extra     = `,"recordCount":12,"controlTotal":"1500.25","currency":"usd"` ) ) ).
        cl_abap_unit_assert=>assert_initial( act = ls_mapped-errors msg = 'A valid event has no errors' ).
        cl_abap_unit_assert=>assert_equals(
          act = |{ ls_mapped-row-milestone }/{ ls_mapped-row-record_count }/{ ls_mapped-row-count_sent }/|
             && |{ ls_mapped-row-control_total }/{ ls_mapped-row-currency }|
          exp = |{ zif_cd_fmon_prism_types=>gc_milestone-delivered }/12/{ abap_true }/1500.25/USD|
          msg = 'Milestone, count (sent), total and currency must be mapped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: FAILED keeps PRISM's error code and text.
  METHOD failed_keeps_error_code.
    TRY.
        DATA(ls_mapped) = act( body( VALUE #( milestone = `FAILED` error_text = `Bank SFTP refused` ) ) ).
        cl_abap_unit_assert=>assert_initial( act = ls_mapped-errors msg = 'A valid failure has no errors' ).
        cl_abap_unit_assert=>assert_equals(
          act = |{ ls_mapped-row-milestone }/{ ls_mapped-row-error_code }/{ ls_mapped-row-error_text }|
          exp = |{ zif_cd_fmon_prism_types=>gc_milestone-failed }/BANK-TIMEOUT/Bank SFTP refused|
          msg = 'Milestone FAILED with error code and text' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: INBOUND maps to the FMON direction code I.
  METHOD inbound_direction_maps_i.
    TRY.
        DATA(ls_mapped) = act( body( VALUE #( direction = `inbound` ) ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_mapped-row-direction
                                            exp = zif_cd_fmon_types=>gc_direction-inbound
                                            msg = 'INBOUND must be stored as I' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every missing required field is listed (400 with the whole list, not the first only).
  METHOD missing_fields_all_listed.
    TRY.
        DATA(ls_mapped) = act( `{"direction":"OUTBOUND","occurredAt":"2026-11-06T14:30:00Z"}` ).
        cl_abap_unit_assert=>assert_equals(
          act = error_codes( ls_mapped-errors )
          exp = VALUE string_table( ( |MISSING_FIELD:eventId| ) ( |MISSING_FIELD:fileReference| )
                                    ( |MISSING_FIELD:milestone| ) )
          msg = 'eventId, fileReference and milestone must all be reported' ).
        cl_abap_unit_assert=>assert_initial( act = ls_mapped-row msg = 'No row for an invalid event' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: occurredAt that is not an ISO 8601 date-time, or a date that does not exist, is invalid.
  METHOD bad_timestamp_rejected.
    TRY.
        DATA(lt_codes) = error_codes( act( body( VALUE #( occurred_at = `06.11.2026 14:30` ) ) )-errors ).
        INSERT LINES OF error_codes( act( body( VALUE #( occurred_at = `2026-02-30T10:00:00Z` ) ) )-errors )
          INTO TABLE lt_codes.
        cl_abap_unit_assert=>assert_equals(
          act = lt_codes
          exp = VALUE string_table( ( |INVALID_VALUE:occurredAt| ) ( |INVALID_VALUE:occurredAt| ) )
          msg = 'Both timestamps must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: occurredAt must be UTC (Z or +00:00) - a local offset is rejected, +00:00 accepted.
  METHOD non_utc_offset_rejected.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = error_codes( act( body( VALUE #( occurred_at = `2026-11-06T09:30:00-05:00` ) ) )-errors )
          exp = VALUE string_table( ( |INVALID_VALUE:occurredAt| ) )
          msg = 'A non-UTC offset must be rejected' ).
        cl_abap_unit_assert=>assert_equals(
          act = act( body( VALUE #( occurred_at = `2026-11-06T14:30:00+00:00` ) ) )-row-occurred_at
          exp = gc_test-occurred_ts
          msg = '+00:00 is UTC' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: occurredAt more than 15 minutes after the SAP clock is rejected (clock skew guard).
  METHOD future_time_rejected.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = error_codes( act( body( VALUE #( occurred_at = `2026-11-06T15:00:00Z` ) ) )-errors )
          exp = VALUE string_table( ( |INVALID_VALUE:occurredAt| ) )
          msg = 'An event 25 minutes in the future must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: fractional seconds are kept (PRISM's own time, up to 7 digits).
  METHOD fraction_seconds_kept.
    DATA lv_exp TYPE timestampl VALUE '20261106143000.125'.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_prism_event=>parse_timestamp( `2026-11-06T14:30:00.125Z` )
          exp = lv_exp
          msg = 'Milliseconds must be kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a milestone outside RECEIVED / DELIVERED / FAILED is invalid.
  METHOD unknown_milestone_rejected.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = error_codes( act( body( VALUE #( milestone = `ARCHIVED` ) ) )-errors )
          exp = VALUE string_table( ( |INVALID_VALUE:milestone| ) )
          msg = 'ARCHIVED is not a milestone' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an error text longer than the column is truncated, never rejected.
  METHOD long_error_text_truncated.
    DATA lv_long TYPE string.
    DATA lv_text TYPE zif_cd_fmon_prism_types=>ty_error_text.
    TRY.
        DO 30 TIMES.
          lv_long = |{ lv_long }timeout-x |.
        ENDDO.
        DATA(ls_mapped) = act( body( VALUE #( milestone = `FAILED` error_text = lv_long ) ) ).
        lv_text = lv_long.
        cl_abap_unit_assert=>assert_initial( act = ls_mapped-errors msg = 'A long text is no error' ).
        cl_abap_unit_assert=>assert_equals( act = ls_mapped-row-error_text exp = lv_text
                                            msg = 'The text must be cut at the column length' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: runs of 8 or more digits (account / card numbers) keep only the last 4 digits.
  METHOD account_number_masked.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_prism_event=>mask_text( `Acct 123456789012 rejected, file 20261106` )
          exp = `Acct ****9012 rejected, file ****1106`
          msg = 'Account-like numbers must be masked' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_prism_event=>mask_text( `R01 code 1234567` )
                                            exp = `R01 code 1234567`
                                            msg = 'Shorter numbers stay readable' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a control total needs its currency.
  METHOD total_needs_currency.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = error_codes( act( body( VALUE #( extra = `,"controlTotal":100` ) ) )-errors )
          exp = VALUE string_table( ( |MISSING_FIELD:currency| ) )
          msg = 'controlTotal without currency must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (every flow via PRISM): any system code is a counterparty - format only, no closed list.
  METHOD any_counterparty_accepted.
    TRY.
        DATA(lv_json) = replace( val = body( VALUE #( ) ) sub = |"{ gc_test-counterpart }"| with = `"BlackLine"` ).
        DATA(ls_mapped) = act( lv_json ).
        cl_abap_unit_assert=>assert_equals( act = ls_mapped-row-counterparty exp = `BLACKLINE`
                                            msg = 'BLACKLINE is a valid counterparty (upper case)' ).
        cl_abap_unit_assert=>assert_equals(
          act = error_codes( act( replace( val = body( VALUE #( ) ) sub = |"{ gc_test-counterpart }"|
                                           with = `"PNC BANK"` ) )-errors )
          exp = VALUE string_table( ( |INVALID_VALUE:counterparty| ) )
          msg = 'A blank inside the code is a format error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a body that is not JSON gives exactly one MALFORMED_JSON error (no field noise).
  METHOD malformed_json_one_error.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = error_codes( act( `{"eventId":"X",` )-errors )
          exp = VALUE string_table( ( |MALFORMED_JSON:| ) )
          msg = 'Only the parse error is reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one event per call - a JSON array is refused.
  METHOD array_body_not_an_object.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = error_codes( act( |[{ body( VALUE #( ) ) }]| )-errors )
          exp = VALUE string_table( ( |NOT_A_JSON_OBJECT:| ) )
          msg = 'An array must be refused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a known member sent as object or array is refused; unknown members are ignored.
  METHOD nested_member_rejected.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = error_codes( act( body( VALUE #( extra = `,"recordCount":{"value":1},"futureField":"x"` ) ) )-errors )
          exp = VALUE string_table( ( |NOT_A_SCALAR:recordCount| ) )
          msg = 'Only the nested member is reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (business date): occurredAt converted to FMON_TIME_ZONE - 03:00 UTC is the previous
  " day in EST, the same rule the FMON adapter applies to TS_FIELD.
  METHOD business_date_in_time_zone.
    TRY.
        ms_context-time_zone = gc_test-time_zone.
        cl_abap_unit_assert=>assert_equals(
          act = act( body( VALUE #( occurred_at = gc_test-early_utc ) ) )-row-business_date
          exp = CONV d( '20261105' )
          msg = 'Business date must be the local date of FMON_TIME_ZONE' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (idempotency): a re-sent event is the same payload even when received later.
  METHOD same_payload_ignores_receipt.
    TRY.
        DATA(ls_first) = act( body( VALUE #( ) ) )-row.
        DATA(ls_resent) = ls_first.
        ls_resent-received_at  = gc_test-occurred_ts.
        ls_resent-received_by  = 'OTHER'.
        ls_resent-processed_at = gc_test-now.
        DATA(ls_changed) = ls_first.
        ls_changed-milestone = zif_cd_fmon_prism_types=>gc_milestone-failed.
        cl_abap_unit_assert=>assert_true(
          act = zcl_cd_fmon_prism_event=>same_payload( is_stored = ls_first is_new = ls_resent )
          msg = 'Receipt and processing fields do not make a different event' ).
        cl_abap_unit_assert=>assert_false(
          act = zcl_cd_fmon_prism_event=>same_payload( is_stored = ls_first is_new = ls_changed )
          msg = 'Another milestone under the same ID is a conflict' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (contract): the answer is {"eventId","status","errors":[{"code","field","message"}]}.
  METHOD answer_json_has_contract.
    DATA ls_response TYPE zif_cd_fmon_prism_types=>ty_response.
    TRY.
        ls_response-status = zif_cd_fmon_prism_types=>gc_api_status-rejected.
        ls_response-errors = VALUE #( ( code = zif_cd_fmon_prism_types=>gc_error-missing field = `fileReference`
                                        message = `Field fileReference is required` ) ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_fmon_prism_event=>to_json( ls_response )
          exp = |\{"eventId":null,"status":"REJECTED","errors":[\{"code":"MISSING_FIELD","field":"fileReference",|
             && |"message":"Field fileReference is required"\}]\}|
          msg = 'The JSON answer must follow the contract' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
