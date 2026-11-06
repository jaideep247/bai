*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_chn_http.clas.testclasses.abap
*& Purpose:
*& Domain tests of the webhook JSON body (TO_JSON): fields present, quotes and
*& line breaks escaped. The HTTP delivery itself is a QA1 integration case.
*& Written after the class (characterisation tests). Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (TDD gap closure).
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
ENDCLASS.


CLASS ltc_http_json IMPLEMENTATION.

  METHOD message.
    rs_message-rule_id    = 'EBS_BLOCK'.
    rs_message-module     = zif_cd_ops_types=>gc_module-ebs.
    rs_message-severity   = zif_cd_ops_types=>gc_severity-block.
    rs_message-subject    = 'Blocked entries'.
    rs_message-item_count = 3.
    rs_message-text       = 'three entries blocked'.
  ENDMETHOD.


  " The receiver needs rule, module, severity and item count to route the page
  METHOD body_carries_rule_and_items.
    DATA(lv_json) = zcl_cd_ops_chn_http=>to_json( message( ) ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = '*"ruleId":"EBS_BLOCK"*' msg = 'ruleId must be sent' ).
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

ENDCLASS.
