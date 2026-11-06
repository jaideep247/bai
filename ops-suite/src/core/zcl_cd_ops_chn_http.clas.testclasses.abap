*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_chn_http.clas.testclasses.abap
*& Purpose:
*& Domain tests of the webhook JSON body (TO_JSON): fields present, quotes and
*& line breaks escaped, correlation and de-duplication fields (runId, dedupKey,
*& eventAction, source, occurredAt, correlation) for ServiceNow / PagerDuty. The HTTP delivery itself is a QA1 integration case.
*& Written after the class (characterisation tests). Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (TDD gap closure).
*& 2026-11-06 | Webhook key peArea (rename regression fixed); column names in comments.
*& 2026-11-06 | Correlation and de-duplication fields (written before the change, TDD).
*&---------------------------------------------------------------------*
CLASS ltc_http_json DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS message
      RETURNING
        VALUE(rs_message) TYPE zif_cd_ops_types=>ty_alert_message.

    METHODS body_carries_rule_and_items  FOR TESTING.
    METHODS quotes_are_escaped           FOR TESTING.
    METHODS line_breaks_are_escaped      FOR TESTING.
    METHODS run_and_dedup_key_sent       FOR TESTING.
    METHODS dedup_key_stable_per_intent  FOR TESTING.
    METHODS dedup_key_without_intent     FOR TESTING.
    METHODS event_fields_sent            FOR TESTING.
    METHODS occurred_at_is_utc_iso       FOR TESTING.
    METHODS unknown_time_is_null         FOR TESTING.
ENDCLASS.


CLASS ltc_http_json IMPLEMENTATION.

  METHOD message.
    rs_message-rule_id    = 'EBS_BLOCK'.
    rs_message-pe_area     = zif_cd_ops_types=>gc_pe_area-ebs.
    rs_message-severity   = zif_cd_ops_types=>gc_severity-block.
    rs_message-subject    = 'Blocked entries'.
    rs_message-item_count = 3.
    rs_message-text       = 'three entries blocked'.
    rs_message-run_id     = '0000000000000000000000000000ABCD'.
    rs_message-extnumber  = 'EBS/0000000000000000000000000000ABCD/EBS_BLOCK'.
    rs_message-intent_key = '0123456789ABCDEF0123456789ABCDEF01234567'.
    rs_message-occurred_at = '20261106103045.1234567'.
  ENDMETHOD.


  " The receiver needs rule, payment engine area, severity and item count to route the page
  METHOD body_carries_rule_and_items.
    DATA(lv_json) = zcl_cd_ops_chn_http=>to_json( message( ) ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = '*"ruleId":"EBS_BLOCK"*' msg = 'ruleId must be sent' ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = '*"peArea":"EBS"*'
                                         msg = 'payment engine area must be sent under key peArea' ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = '*"severity":"B"*' msg = 'severity must be sent' ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = '*"items":3*' msg = 'item count must be a number' ).
  ENDMETHOD.


  " A quote in a finding text must not break the JSON document
  METHOD quotes_are_escaped.
    DATA(ls_message) = message( ).
    ls_message-subject = 'Code "999" unmapped'.
    cl_abap_unit_assert=>assert_char_cp( act = zcl_cd_ops_chn_http=>to_json( ls_message )
                                         exp = '*Code \"999\" unmapped*'
                                         msg = 'Quotes must be escaped' ).
  ENDMETHOD.


  " Multi-line digest text is escaped, not sent as raw line breaks
  METHOD line_breaks_are_escaped.
    DATA(ls_message) = message( ).
    ls_message-text = |line one{ cl_abap_char_utilities=>newline }line two|.
    cl_abap_unit_assert=>assert_char_np( act = zcl_cd_ops_chn_http=>to_json( ls_message )
                                         exp = |*{ cl_abap_char_utilities=>newline }*|
                                         msg = 'Raw line breaks must not reach the body' ).
  ENDMETHOD.


  " The receiver correlates the event with the run (SLG1, run monitor) and de-duplicates on the intent
  METHOD run_and_dedup_key_sent.
    DATA(lv_json) = zcl_cd_ops_chn_http=>to_json( message( ) ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = '*"runId":"0000000000000000000000000000ABCD"*'
                                         msg = 'runId must be sent' ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = '*"dedupKey":"0123456789ABCDEF0123456789ABCDEF01234567"*'
                                         msg = 'dedupKey must be the alert intent key' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"correlation":{"runId":"0000000000000000000000000000ABCD","logId":"EBS/0000000000000000000000000000ABCD/EBS_BLOCK"}*'
      msg = 'correlation must carry the run and the application log external ID' ).
  ENDMETHOD.


  " A retry of the same intent (new attempt, new alert ID, later time) must not open a second incident
  METHOD dedup_key_stable_per_intent.
    DATA(ls_first) = message( ).
    DATA(ls_retry) = message( ).
    ls_retry-alert_id    = '0000000000000000000000000000FFFF'.
    ls_retry-occurred_at = '20261106113045.0000000'.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_chn_http=>dedup_key( ls_retry )
                                        exp = zcl_cd_ops_chn_http=>dedup_key( ls_first )
                                        msg = 'Same intent, same dedupKey' ).
  ENDMETHOD.


  " Without an intent key (hash unavailable) the key is still deterministic: area / run / rule
  METHOD dedup_key_without_intent.
    DATA(ls_message) = message( ).
    CLEAR ls_message-intent_key.
    DATA(lv_key) = zcl_cd_ops_chn_http=>dedup_key( ls_message ).
    cl_abap_unit_assert=>assert_equals( act = lv_key
                                        exp = zcl_cd_ops_chn_http=>dedup_key( ls_message )
                                        msg = 'Fallback key must be deterministic' ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_key exp = '*EBS*0000000000000000000000000000ABCD*EBS_BLOCK*'
                                         msg = 'Fallback key is built from area, run and rule' ).
    ls_message-rule_id = 'EBS_OTHER'.
    cl_abap_unit_assert=>assert_differs( act = zcl_cd_ops_chn_http=>dedup_key( ls_message )
                                         exp = lv_key
                                         msg = 'Another rule is another incident' ).
  ENDMETHOD.


  " Event Management / Events v2 need an action and a source to open the incident
  METHOD event_fields_sent.
    DATA(lv_json) = zcl_cd_ops_chn_http=>to_json( message( ) ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = |*"eventAction":"{ zcl_cd_ops_chn_http=>gc_event_action-trigger }"*|
                                         msg = 'eventAction must be sent' ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = |*"source":"{ zcl_cd_ops_chn_http=>gc_source }"*|
                                         msg = 'source must be sent' ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = |*"system":"{ sy-sysid }/{ sy-mandt }"*|
                                         msg = 'system and client must be sent (QA vs production)' ).
    " Existing keys stay - receivers already parse them
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = '*"text":"three entries blocked"*'
                                         msg = 'Existing keys must be kept' ).
  ENDMETHOD.


  " The raise time is UTC, ISO 8601 with Z, so receivers in any time zone order events alike
  METHOD occurred_at_is_utc_iso.
    cl_abap_unit_assert=>assert_char_cp( act = zcl_cd_ops_chn_http=>to_json( message( ) )
                                         exp = '*"occurredAt":"2026-11-06T10:30:45Z"*'
                                         msg = 'occurredAt must be UTC ISO 8601' ).
  ENDMETHOD.


  " An unknown raise time is sent as null, never as a made-up time
  METHOD unknown_time_is_null.
    DATA(ls_message) = message( ).
    CLEAR ls_message-occurred_at.
    cl_abap_unit_assert=>assert_char_cp( act = zcl_cd_ops_chn_http=>to_json( ls_message )
                                         exp = '*"occurredAt":null*'
                                         msg = 'Unknown time must be null' ).
  ENDMETHOD.

ENDCLASS.
