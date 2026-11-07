*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_api.clas.testclasses.abap
*& Purpose:
*& Application tests of the PRISM status API service with LTD_* doubles (PRISM
*& DAO, queue, authorisation, store, clock) through both injectors: every HTTP
*& status of the contract, commit / rollback and the instant unit; does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, instant bgPF processing).
*& 2026-11-07 | Store double: get_param delegates to the shared fake ZCL_CD_OPS_PARAMS_MEM.
*&---------------------------------------------------------------------*
CLASS ltd_prism_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_prism_dao PARTIALLY IMPLEMENTED.
    DATA mv_result TYPE zif_cd_fmon_prism_types=>ty_store_result.
    DATA mv_fail TYPE abap_bool.
    DATA mt_inserted TYPE zif_cd_fmon_prism_types=>tt_row.
ENDCLASS.


CLASS ltd_prism_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_prism_dao~insert_event.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e010(zcd_ops) WITH 'ZCD_FMON_PRISM'.
    ENDIF.
    INSERT is_row INTO TABLE mt_inserted.
    rv_result = mv_result.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_queue DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_prism_queue.
    DATA mt_queued TYPE zif_cd_fmon_prism_types=>tt_event_id.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.


CLASS ltd_queue IMPLEMENTATION.
  METHOD zif_cd_fmon_prism_queue~enqueue.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e268(zcd_ops) WITH iv_event_id.
    ENDIF.
    INSERT iv_event_id INTO TABLE mt_queued.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_allowed TYPE abap_bool VALUE abap_true.
    DATA mv_activity TYPE zif_cd_ops_auth=>ty_activity.
    DATA mv_pe_area TYPE zif_cd_ops_types=>ty_pe_area.
ENDCLASS.


CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_cd_ops_auth~is_allowed.
    mv_activity = iv_activity.
    mv_pe_area  = iv_pe_area.
    rv_allowed  = mv_allowed.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store PARTIALLY IMPLEMENTED.
    DATA mv_commits TYPE i.
    DATA mv_rollbacks TYPE i.
    DATA mv_max_bytes TYPE string.
    "! Queued units in the LUW at commit time (the unit must be part of the committed LUW)
    DATA mo_queue TYPE REF TO ltd_queue.
    DATA mv_queued_at_commit TYPE i.
ENDCLASS.


CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~commit.
    mv_commits += 1.
    IF mo_queue IS BOUND.
      mv_queued_at_commit = lines( mo_queue->mt_queued ).
    ENDIF.
  ENDMETHOD.
  METHOD zif_cd_ops_store~rollback.
    mv_rollbacks += 1.
  ENDMETHOD.
  METHOD zif_cd_ops_params~get_param.
    " Shared parameter fake: semantics of ZCL_CD_OPS_STORE (blank = default)
    rv_value = NEW zcl_cd_ops_params_mem( )->set( iv_name  = zif_cd_fmon_prism_types=>gc_param_max_bytes
                                                  iv_value = mv_max_bytes
                 )->zif_cd_ops_params~get_param( iv_name = iv_name iv_default = iv_default ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
ENDCLASS.


CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = '20261106143500'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261106'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = '143500'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_api DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flags,
        method       TYPE string,
        content_type TYPE string,
        body         TYPE string,
        denied       TYPE abap_bool,
        store_result TYPE zif_cd_fmon_prism_types=>ty_store_result,
        store_fails  TYPE abap_bool,
        queue_fails  TYPE abap_bool,
        max_bytes    TYPE string,
      END OF ty_flags.

    CONSTANTS:
      BEGIN OF gc_test,
        event_id TYPE zif_cd_fmon_prism_types=>ty_event_id VALUE 'PRISM-0001',
        body     TYPE string VALUE `{"eventId":"PRISM-0001","fileReference":"ACH_PNC_20261106_01",` &
                                  `"direction":"OUTBOUND","milestone":"RECEIVED","occurredAt":"2026-11-06T14:30:00Z"}`,
        get      TYPE string VALUE `GET`,
        text     TYPE string VALUE `text/plain`,
        json_8   TYPE string VALUE `application/json; charset=UTF-8`,
        latin1   TYPE string VALUE `application/json; charset=iso-8859-1`,
      END OF gc_test.

    DATA mo_dao TYPE REF TO ltd_prism_dao.
    DATA mo_queue TYPE REF TO ltd_queue.
    DATA mo_auth TYPE REF TO ltd_auth.
    DATA mo_store TYPE REF TO ltd_store.
    DATA ms_request TYPE zif_cd_fmon_prism_types=>ty_request.

    METHODS setup.
    METHODS teardown.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS act
      RETURNING
        VALUE(rs_response) TYPE zif_cd_fmon_prism_types=>ty_response.

    METHODS valid_event_is_202 FOR TESTING.
    METHODS duplicate_event_is_200 FOR TESTING.
    METHODS conflicting_event_is_409 FOR TESTING.
    METHODS store_failure_is_500 FOR TESTING.
    METHODS invalid_body_is_400 FOR TESTING.
    METHODS get_is_405 FOR TESTING.
    METHODS no_authority_is_403 FOR TESTING.
    METHODS wrong_media_type_is_415 FOR TESTING.
    METHODS utf8_charset_is_accepted FOR TESTING.
    METHODS oversize_body_is_413 FOR TESTING.
    METHODS queue_failure_still_202 FOR TESTING.

ENDCLASS.


CLASS ltc_api IMPLEMENTATION.

  METHOD setup.
    mo_dao   = NEW #( ).
    mo_queue = NEW #( ).
    mo_auth  = NEW #( ).
    mo_store = NEW #( ).
    mo_store->mo_queue = mo_queue.
    zcl_cd_fmon_injector=>inject_prism_dao( mo_dao ).
    zcl_cd_fmon_injector=>inject_prism_queue( mo_queue ).
    zcl_cd_ops_injector=>inject_auth( mo_auth ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR: mo_dao, mo_queue, mo_auth, mo_store, ms_request.
    zcl_cd_fmon_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD configure_scenario.
    ms_request-method       = COND #( WHEN is_flags-method IS NOT INITIAL THEN is_flags-method
                                      ELSE zif_cd_fmon_prism_types=>gc_method_post ).
    ms_request-content_type = COND #( WHEN is_flags-content_type IS NOT INITIAL THEN is_flags-content_type
                                      ELSE zif_cd_fmon_prism_types=>gc_media_json ).
    ms_request-body         = cl_abap_codepage=>convert_to( COND string( WHEN is_flags-body IS NOT INITIAL
                                                                         THEN is_flags-body
                                                                         ELSE gc_test-body ) ).
    mo_auth->mv_allowed  = xsdbool( is_flags-denied = abap_false ).
    mo_dao->mv_result    = COND #( WHEN is_flags-store_result IS NOT INITIAL THEN is_flags-store_result
                                   ELSE zif_cd_fmon_prism_types=>gc_store_result-inserted ).
    mo_dao->mv_fail      = is_flags-store_fails.
    mo_queue->mv_fail    = is_flags-queue_fails.
    mo_store->mv_max_bytes = is_flags-max_bytes.
  ENDMETHOD.


  METHOD act.
    rs_response = NEW zcl_cd_fmon_prism_api( )->handle( ms_request ).
  ENDMETHOD.


  " Rule: a valid new event is stored, its unit queued in the same LUW, committed, then 202.
  METHOD valid_event_is_202.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_response) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = |{ ls_response-status_code }/{ ls_response-status }/{ ls_response-event_id }|
          exp = |{ zif_cd_fmon_prism_types=>gc_http-accepted }/{ zif_cd_fmon_prism_types=>gc_api_status-accepted }/|
             && |{ gc_test-event_id }|
          msg = '202 ACCEPTED with the event ID' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_queued_at_commit exp = 1
                                            msg = 'The unit must be queued before the commit' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 1 msg = 'Exactly one commit' ).
        cl_abap_unit_assert=>assert_equals( act = mo_auth->mv_activity exp = zif_cd_ops_auth=>gc_activity-create
                                            msg = 'Authority ZCD_OPS 01 must be checked' ).
        cl_abap_unit_assert=>assert_equals( act = mo_auth->mv_pe_area
                                            exp = zif_cd_ops_types=>gc_pe_area-file_monitor
                                            msg = 'for payment engine area FMON' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (idempotency): a re-sent event is answered 200 DUPLICATE; no new unit, no commit.
  METHOD duplicate_event_is_200.
    TRY.
        configure_scenario( VALUE #( store_result = zif_cd_fmon_prism_types=>gc_store_result-duplicate ) ).
        DATA(ls_response) = act( ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_response-status_code }/{ ls_response-status }|
                                            exp = |{ zif_cd_fmon_prism_types=>gc_http-ok }/|
                                               && |{ zif_cd_fmon_prism_types=>gc_api_status-duplicate }|
                                            msg = '200 DUPLICATE' ).
        cl_abap_unit_assert=>assert_initial( act = mo_queue->mt_queued msg = 'No second unit' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 0 msg = 'Nothing to commit' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an event ID reused with another payload is 409 CONFLICT (PRISM must not retry it).
  METHOD conflicting_event_is_409.
    TRY.
        configure_scenario( VALUE #( store_result = zif_cd_fmon_prism_types=>gc_store_result-conflict ) ).
        DATA(ls_response) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_response-status_code exp = zif_cd_fmon_prism_types=>gc_http-conflict
                                            msg = '409 CONFLICT' ).
        cl_abap_unit_assert=>assert_equals( act = ls_response-errors[ 1 ]-code
                                            exp = zif_cd_fmon_prism_types=>gc_error-event_id_conflict
                                            msg = 'Error EVENT_ID_CONFLICT' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a store failure is rolled back and answered 500 (PRISM retries the same event ID).
  METHOD store_failure_is_500.
    TRY.
        configure_scenario( VALUE #( store_fails = abap_true ) ).
        DATA(ls_response) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_response-status_code
                                            exp = zif_cd_fmon_prism_types=>gc_http-internal_error
                                            msg = '500 on a store failure' ).
        cl_abap_unit_assert=>assert_equals( act = |{ mo_store->mv_rollbacks }/{ mo_store->mv_commits }| exp = |1/0|
                                            msg = 'Rolled back, never committed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a validation error is 400 REJECTED with the error list; nothing is stored.
  METHOD invalid_body_is_400.
    TRY.
        configure_scenario( VALUE #( body = `{"eventId":"PRISM-0001"}` ) ).
        DATA(ls_response) = act( ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_response-status_code }/{ lines( ls_response-errors ) }|
                                            exp = |{ zif_cd_fmon_prism_types=>gc_http-bad_request }/4|
                                            msg = '400 listing fileReference, direction, milestone, occurredAt' ).
        cl_abap_unit_assert=>assert_equals( act = ls_response-event_id exp = gc_test-event_id
                                            msg = 'The valid event ID is echoed' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'Nothing may be stored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only POST is allowed (405).
  METHOD get_is_405.
    TRY.
        configure_scenario( VALUE #( method = gc_test-get ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )-status_code
                                            exp = zif_cd_fmon_prism_types=>gc_http-method_not_allowed
                                            msg = 'GET must be 405' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'Nothing may be stored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without ZCD_OPS 01 / FMON the call is 403 and nothing is parsed or stored.
  METHOD no_authority_is_403.
    TRY.
        configure_scenario( VALUE #( denied = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )-status_code exp = zif_cd_fmon_prism_types=>gc_http-forbidden
                                            msg = 'No authority must be 403' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'Nothing may be stored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a body that is not application/json (or not UTF-8) is 415.
  METHOD wrong_media_type_is_415.
    TRY.
        configure_scenario( VALUE #( content_type = gc_test-text ) ).
        DATA(lv_text) = act( )-status_code.
        configure_scenario( VALUE #( content_type = gc_test-latin1 ) ).
        DATA(lv_latin1) = act( )-status_code.
        cl_abap_unit_assert=>assert_equals( act = |{ lv_text }/{ lv_latin1 }|
                                            exp = |{ zif_cd_fmon_prism_types=>gc_http-unsupported_media }/|
                                               && |{ zif_cd_fmon_prism_types=>gc_http-unsupported_media }|
                                            msg = 'text/plain and ISO-8859-1 must be 415' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: application/json with charset UTF-8 (any case) is accepted.
  METHOD utf8_charset_is_accepted.
    TRY.
        configure_scenario( VALUE #( content_type = gc_test-json_8 ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )-status_code exp = zif_cd_fmon_prism_types=>gc_http-accepted
                                            msg = 'charset=UTF-8 must be accepted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a body above FMON_PRISM_MAX_BYTES is 413 before it is parsed.
  METHOD oversize_body_is_413.
    TRY.
        configure_scenario( VALUE #( max_bytes = `64` ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )-status_code
                                            exp = zif_cd_fmon_prism_types=>gc_http-payload_too_large
                                            msg = 'A body above the limit must be 413' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'Nothing may be stored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (fallback): if bgPF cannot queue the unit, the event is still stored and committed (202);
  " the 5-minute run applies it.
  METHOD queue_failure_still_202.
    TRY.
        configure_scenario( VALUE #( queue_fails = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )-status_code exp = zif_cd_fmon_prism_types=>gc_http-accepted
                                            msg = 'The event is accepted without the unit' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 1 msg = 'The event must be committed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
