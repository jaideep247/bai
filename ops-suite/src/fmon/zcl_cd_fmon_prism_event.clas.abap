*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_event.clas.abap
*& Purpose:
*& PRISM status API - pure domain logic: parse the JSON body (sXML JSON
*& reader), validate every field, mask account-like numbers in the error
*& text, map to the ZCD_FMON_PRISM row, compare a re-sent event and render
*& the JSON response. No database, no clock, no HTTP.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, user decision 2026-11-06).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FMON PRISM status API - parse, validate, map an event</p>
"! Contract and field rules: docs/PRISM_Status_API.md. Unknown members are ignored
"! (forward compatible); a member sent twice, a nested object / array, or a value
"! that breaks its rule is a 400 error entry. All errors are collected, not only the first.
CLASS zcl_cd_fmon_prism_event DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Top-level members of one JSON object (sXML JSON-XML reader, VERIFY-ADT)
    CLASS-METHODS parse
      IMPORTING
        iv_body          TYPE xstring
      RETURNING
        VALUE(rs_parsed) TYPE zif_cd_fmon_prism_types=>ty_parsed.

    "! Validate the members and map them to the stored row (errors = 400 list)
    CLASS-METHODS map
      IMPORTING
        is_parsed        TYPE zif_cd_fmon_prism_types=>ty_parsed
        is_context       TYPE zif_cd_fmon_prism_types=>ty_map_context
      RETURNING
        VALUE(rs_mapped) TYPE zif_cd_fmon_prism_types=>ty_mapped.

    "! Every run of 8 or more digits keeps only its last 4 digits (account / card numbers)
    CLASS-METHODS mask_text
      IMPORTING
        iv_text        TYPE clike
      RETURNING
        VALUE(rv_text) TYPE string.

    "! ISO 8601 UTC time (Z or +00:00, up to 7 fractional digits); initial when invalid
    CLASS-METHODS parse_timestamp
      IMPORTING
        iv_value     TYPE clike
      RETURNING
        VALUE(rv_ts) TYPE timestampl.

    "! Same event content (idempotent re-send); receipt, processing and derived business date ignored
    CLASS-METHODS same_payload
      IMPORTING
        is_stored      TYPE zif_cd_fmon_prism_types=>ty_row
        is_new         TYPE zif_cd_fmon_prism_types=>ty_row
      RETURNING
        VALUE(rv_same) TYPE abap_bool.

    "! Response body: {"eventId":..,"status":..,"errors":[{"code":..,"field":..,"message":..}]}
    CLASS-METHODS to_json
      IMPORTING
        is_response    TYPE zif_cd_fmon_prism_types=>ty_response
      RETURNING
        VALUE(rv_json) TYPE string.

    CLASS-METHODS new_error
      IMPORTING
        iv_code         TYPE zif_cd_fmon_prism_types=>ty_wire_value
        iv_field        TYPE clike OPTIONAL
        iv_msgno        TYPE zif_cd_ops_types=>ty_msgno
        iv_v1           TYPE simple OPTIONAL
        iv_v2           TYPE simple OPTIONAL
        iv_tail         TYPE string OPTIONAL
      RETURNING
        VALUE(rs_error) TYPE zif_cd_fmon_prism_types=>ty_error.

  PRIVATE SECTION.
    "! Depth of the top-level object and of its members in the JSON-XML tree
    CONSTANTS:
      BEGIN OF gc_depth,
        root   TYPE i VALUE 1,
        member TYPE i VALUE 2,
      END OF gc_depth.

    "! Value of one member as text; absent for a missing member or JSON null
    CLASS-METHODS scalar
      IMPORTING
        it_members  TYPE zif_cd_fmon_prism_types=>tt_member
        iv_key      TYPE string
      EXPORTING
        ev_value    TYPE string
        ev_present  TYPE abap_bool
      CHANGING
        ct_errors   TYPE zif_cd_fmon_prism_types=>tt_error.

    "! Text member: required / length / pattern / no control characters
    CLASS-METHODS text_field
      IMPORTING
        it_members      TYPE zif_cd_fmon_prism_types=>tt_member
        iv_key          TYPE string
        iv_required     TYPE abap_bool DEFAULT abap_false
        iv_max          TYPE i
        iv_pcre         TYPE string OPTIONAL
        iv_upper        TYPE abap_bool DEFAULT abap_false
      CHANGING
        ct_errors       TYPE zif_cd_fmon_prism_types=>tt_error
      RETURNING
        VALUE(rv_value) TYPE string.

    CLASS-METHODS map_numbers
      IMPORTING
        it_members TYPE zif_cd_fmon_prism_types=>tt_member
      CHANGING
        cs_row     TYPE zif_cd_fmon_prism_types=>ty_row
        ct_errors  TYPE zif_cd_fmon_prism_types=>tt_error.

    CLASS-METHODS map_time
      IMPORTING
        it_members TYPE zif_cd_fmon_prism_types=>tt_member
        is_context TYPE zif_cd_fmon_prism_types=>ty_map_context
      CHANGING
        cs_row     TYPE zif_cd_fmon_prism_types=>ty_row
        ct_errors  TYPE zif_cd_fmon_prism_types=>tt_error.

    "! Character length of a CHAR component of the row (no length literals)
    CLASS-METHODS char_length
      IMPORTING
        iv_field         TYPE clike
      RETURNING
        VALUE(rv_length) TYPE i.

    CLASS-METHODS json_string
      IMPORTING
        iv_value       TYPE clike
      RETURNING
        VALUE(rv_json) TYPE string.

    CLASS-METHODS json_member
      IMPORTING
        iv_key         TYPE string
        iv_json        TYPE string
      RETURNING
        VALUE(rv_json) TYPE string.

ENDCLASS.



CLASS zcl_cd_fmon_prism_event IMPLEMENTATION.

  METHOD parse.
    DATA lv_depth TYPE i.
    DATA ls_member TYPE zif_cd_fmon_prism_types=>ty_member.

    IF iv_body IS INITIAL.
      INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-not_an_object
                        iv_msgno = zif_cd_fmon_prism_types=>gc_msg-not_an_object ) INTO TABLE rs_parsed-errors.
      RETURN.
    ENDIF.

    TRY.
        " VERIFY-ADT: sXML recognises JSON input and presents it as JSON-XML
        " (object / str / num / bool / null, member name in attribute "name")
        DATA(lo_reader) = cl_sxml_string_reader=>create( input = iv_body ).
        DO.
          DATA(lo_node) = lo_reader->read_next_node( ).
          IF lo_node IS NOT BOUND.
            EXIT.
          ENDIF.
          CASE lo_node->type.
            WHEN if_sxml_node=>co_nt_element_open.
              lv_depth += 1.
              DATA(lo_open) = CAST if_sxml_open_element( lo_node ).
              DATA(lv_kind) = CONV string( lo_open->qname-name ).
              IF lv_depth = gc_depth-root AND lv_kind <> zif_cd_fmon_prism_types=>gc_jsonxml-object.
                INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-not_an_object
                                  iv_msgno = zif_cd_fmon_prism_types=>gc_msg-not_an_object ) INTO TABLE rs_parsed-errors.
                RETURN.
              ENDIF.
              IF lv_depth = gc_depth-member.
                CLEAR ls_member.
                ls_member-kind = lv_kind.
                DATA(lt_attributes) = lo_open->get_attributes( ).
                LOOP AT lt_attributes INTO DATA(lo_attribute).
                  IF lo_attribute->qname-name = zif_cd_fmon_prism_types=>gc_jsonxml-attr_name.
                    ls_member-name = lo_attribute->get_value( ).
                  ENDIF.
                ENDLOOP.
              ENDIF.
            WHEN if_sxml_node=>co_nt_value.
              IF lv_depth = gc_depth-member.
                ls_member-value = CAST if_sxml_value_node( lo_node )->get_value( ).
              ENDIF.
            WHEN if_sxml_node=>co_nt_element_close.
              IF lv_depth = gc_depth-member.
                IF ls_member-kind = zif_cd_fmon_prism_types=>gc_jsonxml-object
                   OR ls_member-kind = zif_cd_fmon_prism_types=>gc_jsonxml-array.
                  INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-not_scalar
                                    iv_field = ls_member-name
                                    iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_not_scalar
                                    iv_v1    = ls_member-name ) INTO TABLE rs_parsed-errors.
                ELSE.
                  INSERT ls_member INTO TABLE rs_parsed-members.
                  IF sy-subrc <> 0.
                    INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-duplicate_key
                                      iv_field = ls_member-name
                                      iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_duplicate
                                      iv_v1    = ls_member-name ) INTO TABLE rs_parsed-errors.
                  ENDIF.
                ENDIF.
              ENDIF.
              lv_depth -= 1.
            WHEN OTHERS.
          ENDCASE.
        ENDDO.
      CATCH cx_sxml_error INTO DATA(lx_error).
        CLEAR rs_parsed-members.
        rs_parsed-errors = VALUE #( ( new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-malformed_json
                                                 iv_msgno = zif_cd_fmon_prism_types=>gc_msg-malformed_json
                                                 iv_tail  = lx_error->get_text( ) ) ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD map.
    DATA ls_row TYPE zif_cd_fmon_prism_types=>ty_row.
    DATA lt_errors TYPE zif_cd_fmon_prism_types=>tt_error.

    " A body that is not one JSON object has nothing to validate
    IF line_exists( is_parsed-errors[ code = zif_cd_fmon_prism_types=>gc_error-malformed_json ] )
       OR line_exists( is_parsed-errors[ code = zif_cd_fmon_prism_types=>gc_error-not_an_object ] ).
      rs_mapped-errors = is_parsed-errors.
      RETURN.
    ENDIF.
    lt_errors = is_parsed-errors.
    DATA(lt_members) = is_parsed-members.

    ls_row-event_id = text_field( EXPORTING it_members  = lt_members
                                            iv_key      = zif_cd_fmon_prism_types=>gc_key-event_id
                                            iv_required = abap_true
                                            iv_max      = char_length( ls_row-event_id )
                                            iv_pcre     = zif_cd_fmon_prism_types=>gc_pcre-ident
                                  CHANGING  ct_errors   = lt_errors ).
    ls_row-file_ref = text_field( EXPORTING it_members  = lt_members
                                            iv_key      = zif_cd_fmon_prism_types=>gc_key-file_ref
                                            iv_required = abap_true
                                            iv_max      = char_length( ls_row-file_ref )
                                  CHANGING  ct_errors   = lt_errors ).
    ls_row-iface_id = text_field( EXPORTING it_members = lt_members
                                            iv_key     = zif_cd_fmon_prism_types=>gc_key-iface_id
                                            iv_max     = char_length( ls_row-iface_id )
                                            iv_pcre    = zif_cd_fmon_prism_types=>gc_pcre-iface
                                            iv_upper   = abap_true
                                  CHANGING  ct_errors  = lt_errors ).

    DATA(lv_direction) = text_field( EXPORTING it_members  = lt_members
                                               iv_key      = zif_cd_fmon_prism_types=>gc_key-direction
                                               iv_required = abap_true
                                               iv_max      = strlen( zif_cd_fmon_prism_types=>gc_wire_direction-outbound )
                                               iv_upper    = abap_true
                                     CHANGING  ct_errors   = lt_errors ).
    IF lv_direction IS NOT INITIAL.
      CASE lv_direction.
        WHEN zif_cd_fmon_prism_types=>gc_wire_direction-outbound.
          ls_row-direction = zif_cd_fmon_types=>gc_direction-outbound.
        WHEN zif_cd_fmon_prism_types=>gc_wire_direction-inbound.
          ls_row-direction = zif_cd_fmon_types=>gc_direction-inbound.
        WHEN OTHERS.
          INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-invalid
                            iv_field = zif_cd_fmon_prism_types=>gc_key-direction
                            iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_invalid
                            iv_v1    = zif_cd_fmon_prism_types=>gc_key-direction ) INTO TABLE lt_errors.
      ENDCASE.
    ENDIF.

    ls_row-milestone = text_field( EXPORTING it_members  = lt_members
                                             iv_key      = zif_cd_fmon_prism_types=>gc_key-milestone
                                             iv_required = abap_true
                                             iv_max      = char_length( ls_row-milestone )
                                             iv_upper    = abap_true
                                   CHANGING  ct_errors   = lt_errors ).
    IF ls_row-milestone IS NOT INITIAL
       AND ls_row-milestone <> zif_cd_fmon_prism_types=>gc_milestone-received
       AND ls_row-milestone <> zif_cd_fmon_prism_types=>gc_milestone-delivered
       AND ls_row-milestone <> zif_cd_fmon_prism_types=>gc_milestone-failed.
      CLEAR ls_row-milestone.
      INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-invalid
                        iv_field = zif_cd_fmon_prism_types=>gc_key-milestone
                        iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_invalid
                        iv_v1    = zif_cd_fmon_prism_types=>gc_key-milestone ) INTO TABLE lt_errors.
    ENDIF.

    map_time( EXPORTING it_members = lt_members
                        is_context = is_context
              CHANGING  cs_row     = ls_row
                        ct_errors  = lt_errors ).

    " Any system PRISM exchanges files or messages with (bank, IRIS, BLACKLINE, OFSAA,
    " STRIPE, BRIDGER, source codes ...): format only, no closed list
    ls_row-counterparty = text_field( EXPORTING it_members = lt_members
                                                iv_key     = zif_cd_fmon_prism_types=>gc_key-counterparty
                                                iv_max     = char_length( ls_row-counterparty )
                                                iv_pcre    = zif_cd_fmon_prism_types=>gc_pcre-ident
                                                iv_upper   = abap_true
                                      CHANGING  ct_errors  = lt_errors ).
    ls_row-prism_ref = text_field( EXPORTING it_members = lt_members
                                             iv_key     = zif_cd_fmon_prism_types=>gc_key-prism_ref
                                             iv_max     = char_length( ls_row-prism_ref )
                                   CHANGING  ct_errors  = lt_errors ).
    ls_row-error_code = text_field( EXPORTING it_members = lt_members
                                              iv_key     = zif_cd_fmon_prism_types=>gc_key-error_code
                                              iv_max     = char_length( ls_row-error_code )
                                              iv_upper   = abap_true
                                    CHANGING  ct_errors  = lt_errors ).
    " errorText: masked first, then truncated - never rejected for its length
    scalar( EXPORTING it_members = lt_members
                      iv_key     = zif_cd_fmon_prism_types=>gc_key-error_text
            IMPORTING ev_value   = DATA(lv_text)
                      ev_present = DATA(lv_text_present)
            CHANGING  ct_errors  = lt_errors ).
    IF lv_text_present = abap_true.
      ls_row-error_text = mask_text( replace( val = lv_text pcre = zif_cd_fmon_prism_types=>gc_pcre-control
                                              with = ` ` occ = 0 ) ).
    ENDIF.

    map_numbers( EXPORTING it_members = lt_members
                 CHANGING  cs_row     = ls_row
                           ct_errors  = lt_errors ).

    ls_row-received_at = is_context-now.
    ls_row-received_by = is_context-user.
    rs_mapped-errors = lt_errors.
    IF lt_errors IS INITIAL.
      rs_mapped-row = ls_row.
    ELSE.
      " The event ID is echoed in the 400 response when it was valid
      rs_mapped-row-event_id = ls_row-event_id.
    ENDIF.
  ENDMETHOD.


  METHOD map_time.
    DATA lv_time TYPE t.

    DATA(lv_value) = text_field( EXPORTING it_members  = it_members
                                           iv_key      = zif_cd_fmon_prism_types=>gc_key-occurred_at
                                           iv_required = abap_true
                                           iv_max      = 0
                                 CHANGING  ct_errors   = ct_errors ).
    IF lv_value IS INITIAL.
      RETURN.
    ENDIF.
    cs_row-occurred_at = parse_timestamp( lv_value ).
    IF cs_row-occurred_at IS INITIAL.
      INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-invalid
                        iv_field = zif_cd_fmon_prism_types=>gc_key-occurred_at
                        iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_invalid
                        iv_v1    = zif_cd_fmon_prism_types=>gc_key-occurred_at ) INTO TABLE ct_errors.
      RETURN.
    ENDIF.
    IF is_context-now IS NOT INITIAL
       AND cs_row-occurred_at > zcl_cd_fmon_util=>add_minutes( iv_timestamp = is_context-now
                                                               iv_minutes   = zif_cd_fmon_prism_types=>gc_max_future_minutes ).
      INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-invalid
                        iv_field = zif_cd_fmon_prism_types=>gc_key-occurred_at
                        iv_msgno = zif_cd_fmon_prism_types=>gc_msg-occurred_in_future
                        iv_v1    = zif_cd_fmon_prism_types=>gc_key-occurred_at
                        iv_v2    = zif_cd_fmon_prism_types=>gc_max_future_minutes ) INTO TABLE ct_errors.
      CLEAR cs_row-occurred_at.
      RETURN.
    ENDIF.
    " Business date = occurredAt in FMON_TIME_ZONE: the rule the generic adapter applies to
    " TS_FIELD, so the stored date and the date FMON correlates with are the same
    CONVERT TIME STAMP cs_row-occurred_at TIME ZONE is_context-time_zone
      INTO DATE cs_row-business_date TIME lv_time.
    IF sy-subrc > 4.
      CONVERT TIME STAMP cs_row-occurred_at TIME ZONE zif_cd_ops_types=>gc_time_zone_utc
        INTO DATE cs_row-business_date TIME lv_time.
    ENDIF.
  ENDMETHOD.


  METHOD map_numbers.
    scalar( EXPORTING it_members = it_members
                      iv_key     = zif_cd_fmon_prism_types=>gc_key-record_count
            IMPORTING ev_value   = DATA(lv_count)
                      ev_present = DATA(lv_count_present)
            CHANGING  ct_errors  = ct_errors ).
    IF lv_count_present = abap_true.
      IF matches( val = lv_count pcre = zif_cd_fmon_prism_types=>gc_pcre-integer )
         AND CONV int8( lv_count ) <= zif_cd_fmon_prism_types=>gc_max_count.
        cs_row-record_count = lv_count.
        cs_row-count_sent   = abap_true.
      ELSE.
        INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-invalid
                          iv_field = zif_cd_fmon_prism_types=>gc_key-record_count
                          iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_invalid
                          iv_v1    = zif_cd_fmon_prism_types=>gc_key-record_count ) INTO TABLE ct_errors.
      ENDIF.
    ENDIF.

    cs_row-currency = text_field( EXPORTING it_members = it_members
                                            iv_key     = zif_cd_fmon_prism_types=>gc_key-currency
                                            iv_max     = char_length( cs_row-currency )
                                            iv_pcre    = zif_cd_fmon_prism_types=>gc_pcre-currency
                                            iv_upper   = abap_true
                                  CHANGING  ct_errors  = ct_errors ).
    scalar( EXPORTING it_members = it_members
                      iv_key     = zif_cd_fmon_prism_types=>gc_key-control_total
            IMPORTING ev_value   = DATA(lv_total)
                      ev_present = DATA(lv_total_present)
            CHANGING  ct_errors  = ct_errors ).
    IF lv_total_present = abap_false.
      RETURN.
    ENDIF.
    IF NOT matches( val = lv_total pcre = zif_cd_fmon_prism_types=>gc_pcre-amount ).
      INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-invalid
                        iv_field = zif_cd_fmon_prism_types=>gc_key-control_total
                        iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_invalid
                        iv_v1    = zif_cd_fmon_prism_types=>gc_key-control_total ) INTO TABLE ct_errors.
      RETURN.
    ENDIF.
    cs_row-control_total = lv_total.
    IF cs_row-currency IS INITIAL
       AND NOT line_exists( ct_errors[ field = zif_cd_fmon_prism_types=>gc_key-currency ] ).
      INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-missing
                        iv_field = zif_cd_fmon_prism_types=>gc_key-currency
                        iv_msgno = zif_cd_fmon_prism_types=>gc_msg-total_needs_ccy
                        iv_v1    = zif_cd_fmon_prism_types=>gc_key-control_total
                        iv_v2    = zif_cd_fmon_prism_types=>gc_key-currency ) INTO TABLE ct_errors.
    ENDIF.
  ENDMETHOD.


  METHOD scalar.
    CLEAR: ev_value, ev_present.
    READ TABLE it_members ASSIGNING FIELD-SYMBOL(<ls_member>) WITH TABLE KEY name = iv_key.
    IF sy-subrc <> 0 OR <ls_member>-kind = zif_cd_fmon_prism_types=>gc_jsonxml-null.
      RETURN.
    ENDIF.
    IF <ls_member>-kind = zif_cd_fmon_prism_types=>gc_jsonxml-bool.
      INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-invalid
                        iv_field = iv_key
                        iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_invalid
                        iv_v1    = iv_key ) INTO TABLE ct_errors.
      RETURN.
    ENDIF.
    ev_value   = shift_right( val = shift_left( val = <ls_member>-value sub = ` ` ) sub = ` ` ).
    ev_present = xsdbool( ev_value IS NOT INITIAL ).
  ENDMETHOD.


  METHOD text_field.
    scalar( EXPORTING it_members = it_members
                      iv_key     = iv_key
            IMPORTING ev_value   = DATA(lv_value)
                      ev_present = DATA(lv_present)
            CHANGING  ct_errors  = ct_errors ).
    IF lv_present = abap_false.
      IF iv_required = abap_true AND NOT line_exists( ct_errors[ field = iv_key ] ).
        INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-missing
                          iv_field = iv_key
                          iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_missing
                          iv_v1    = iv_key ) INTO TABLE ct_errors.
      ENDIF.
      RETURN.
    ENDIF.
    IF iv_max > 0 AND strlen( lv_value ) > iv_max.
      INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-too_long
                        iv_field = iv_key
                        iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_too_long
                        iv_v1    = iv_key
                        iv_v2    = iv_max ) INTO TABLE ct_errors.
      RETURN.
    ENDIF.
    IF iv_upper = abap_true.
      lv_value = to_upper( lv_value ).
    ENDIF.
    IF find( val = lv_value pcre = zif_cd_fmon_prism_types=>gc_pcre-control ) >= 0
       OR ( iv_pcre IS NOT INITIAL AND NOT matches( val = lv_value pcre = iv_pcre ) ).
      INSERT new_error( iv_code  = zif_cd_fmon_prism_types=>gc_error-invalid
                        iv_field = iv_key
                        iv_msgno = zif_cd_fmon_prism_types=>gc_msg-field_invalid
                        iv_v1    = iv_key ) INTO TABLE ct_errors.
      RETURN.
    ENDIF.
    rv_value = lv_value.
  ENDMETHOD.


  METHOD mask_text.
    rv_text = replace( val  = CONV string( iv_text )
                       pcre = zif_cd_fmon_prism_types=>gc_pcre-account
                       with = zif_cd_fmon_prism_types=>gc_mask
                       occ  = 0 ).
  ENDMETHOD.


  METHOD parse_timestamp.
    DATA lv_date TYPE d.
    DATA lv_time TYPE t.
    DATA lv_seconds TYPE timestamp.

    DATA(lv_value) = to_upper( condense( CONV string( iv_value ) ) ).
    IF NOT matches( val = lv_value pcre = zif_cd_fmon_prism_types=>gc_pcre-timestamp ).
      RETURN.
    ENDIF.
    lv_date = substring( val = lv_value len = 4 ) && substring( val = lv_value off = 5 len = 2 )
           && substring( val = lv_value off = 8 len = 2 ).
    lv_time = substring( val = lv_value off = 11 len = 2 ) && substring( val = lv_value off = 14 len = 2 )
           && substring( val = lv_value off = 17 len = 2 ).
    " VERIFY-ADT: a date that does not exist converts to 0 days; CONVERT DATE refuses an
    " invalid date or time with sy-subrc 12
    IF CONV i( lv_date ) = 0 OR lv_time+0(2) > 23 OR lv_time+2(2) > 59 OR lv_time+4(2) > 59.
      RETURN.
    ENDIF.
    CONVERT DATE lv_date TIME lv_time INTO TIME STAMP lv_seconds TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rv_ts = lv_seconds.
    " Fractional seconds: the characters between the seconds and the UTC designator
    DATA(lv_fraction) = substring_before( val = substring( val = lv_value off = 19 )
                                          sub = zif_cd_fmon_prism_types=>gc_utc-zulu ).
    IF lv_fraction IS INITIAL.
      lv_fraction = substring_before( val = substring( val = lv_value off = 19 )
                                      sub = zif_cd_fmon_prism_types=>gc_utc-offset ).
    ENDIF.
    IF lv_fraction IS NOT INITIAL.
      rv_ts += CONV decfloat34( |0{ lv_fraction }| ).
    ENDIF.
  ENDMETHOD.


  METHOD same_payload.
    DATA(ls_stored) = is_stored.
    DATA(ls_new) = is_new.
    CLEAR: ls_stored-received_at, ls_stored-received_by, ls_stored-business_date, ls_stored-processed_at,
           ls_new-received_at, ls_new-received_by, ls_new-business_date, ls_new-processed_at.
    rv_same = xsdbool( ls_stored = ls_new ).
  ENDMETHOD.


  METHOD to_json.
    DATA(lv_errors) = REDUCE string(
      INIT lv_list = `` lv_sep = ``
      FOR ls_error IN is_response-errors
      NEXT lv_list = lv_list && lv_sep
                     && |\{{ json_member( iv_key = zif_cd_fmon_prism_types=>gc_key-code
                                          iv_json = json_string( ls_error-code ) ) },|
                     && |{ json_member( iv_key = zif_cd_fmon_prism_types=>gc_key-field
                                        iv_json = json_string( ls_error-field ) ) },|
                     && |{ json_member( iv_key = zif_cd_fmon_prism_types=>gc_key-message
                                        iv_json = json_string( ls_error-message ) ) }\}|
           lv_sep  = |,| ).
    DATA(lv_event_id) = COND string( WHEN is_response-event_id IS INITIAL THEN zif_cd_fmon_prism_types=>gc_json_null
                                     ELSE json_string( is_response-event_id ) ).
    rv_json = |\{{ json_member( iv_key  = zif_cd_fmon_prism_types=>gc_key-event_id
                                iv_json = lv_event_id ) },|
           && |{ json_member( iv_key  = zif_cd_fmon_prism_types=>gc_key-status
                              iv_json = json_string( is_response-status ) ) },|
           && |{ json_member( iv_key  = zif_cd_fmon_prism_types=>gc_key-errors
                              iv_json = |[{ lv_errors }]| ) }\}|.
  ENDMETHOD.


  METHOD new_error.
    rs_error-code    = iv_code.
    rs_error-field   = iv_field.
    rs_error-message = zcl_cd_ops_util=>text( iv_msgno = iv_msgno
                                              iv_v1    = iv_v1
                                              iv_v2    = iv_v2
                                              iv_tail  = iv_tail ).
  ENDMETHOD.


  METHOD char_length.
    DESCRIBE FIELD iv_field LENGTH rv_length IN CHARACTER MODE.
  ENDMETHOD.


  METHOD json_string.
    rv_json = |"{ escape( val = condense( CONV string( iv_value ) ) format = cl_abap_format=>e_json_string ) }"|.
  ENDMETHOD.


  METHOD json_member.
    rv_json = |"{ iv_key }":{ iv_json }|.
  ENDMETHOD.

ENDCLASS.
