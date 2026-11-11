*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_correlator.clas.abap
*& Purpose:
*& Alert correlation (2026-11-11, ZCA_OPS_CORR): builds the correlation key of
*& a new open exception - the finding fields of the rule's key list joined
*& with '|', optionally the first capture group of the rule's key pattern
*& (PCRE, complete value, case ignored) - and hashes it with area, rule and
*& company code (the company code is always part of the key: a child never
*& belongs to the parent of another company code, so company-code isolation
*& holds for children and counts). Within the rule's window the first
*& exception of a key is the parent (new correlation ID), later ones its
*& children (the parent's ID). Rules are applied by the lowest rule ID that
*& selects the check code and yields a key. Pure logic on the rows the store
*& is about to write: no database; the store reads the rules and the open
*& parents. Test seam CORR_ID around the UUID of a new group.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: alert correlation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert correlation</p>
CLASS zcl_ca_ops_correlator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES tt_db_finding TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.

    "! Correlation key value of the finding under the rule: the key fields joined with '|', or the first
    "! capture group of the key pattern applied to it (complete value); blank = the rule does not correlate
    "! the finding (unknown field, all fields blank, pattern without match or not valid PCRE)
    CLASS-METHODS key
      IMPORTING
        is_rule       TYPE zif_ca_ops_resp_types=>ty_corr_rule_row
        is_row        TYPE zca_ops_finding
      RETURNING
        VALUE(rv_key) TYPE string.

    "! Hashed key of a correlation: SHA-1 of area, rule, company code and key value
    CLASS-METHODS hash
      IMPORTING
        iv_area        TYPE zif_ca_ops_types=>ty_area
        iv_rule        TYPE zif_ca_ops_resp_types=>ty_corr_rule
        iv_bukrs       TYPE bukrs
        iv_key         TYPE string
      RETURNING
        VALUE(rv_hash) TYPE zif_ca_ops_resp_types=>ty_corr_key.

    "! The new open exceptions of the rows (severity B / E / W, disposition O, no correlation inherited by the
    "! carry-forward) that a rule correlates: position in it_rows, hashed key, window of the rule
    CLASS-METHODS select
      IMPORTING
        it_rules        TYPE zif_ca_ops_resp_types=>tt_corr_rule
        it_rows         TYPE tt_db_finding
      RETURNING
        VALUE(rt_items) TYPE zif_ca_ops_resp_types=>tt_corr_item.

    "! Parent or child: the newest open parent of the key whose window (from its first time seen) still runs
    "! at iv_now, else an earlier row of this batch with the key, makes the row a child (its correlation ID);
    "! otherwise the row is a new parent with a new correlation ID
    "! @raising zcx_ca_ops_error | no UUID for a new group (155) - nothing of the batch may be written
    CLASS-METHODS assign
      IMPORTING
        it_items   TYPE zif_ca_ops_resp_types=>tt_corr_item
        it_parents TYPE zif_ca_ops_resp_types=>tt_corr_parent
        iv_now     TYPE timestampl
      CHANGING
        ct_rows    TYPE tt_db_finding
      RAISING
        zcx_ca_ops_error.

    "! The field may be part of a correlation key (ZIF_CA_OPS_RESP_TYPES=>GC_KEY_FIELD; case ignored)
    CLASS-METHODS is_key_field
      IMPORTING
        iv_field        TYPE clike
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

  PRIVATE SECTION.
    "! Value of one key field of the row (blank for a field that is not a key field)
    CLASS-METHODS field_value
      IMPORTING
        iv_field        TYPE string
        is_row          TYPE zca_ops_finding
      RETURNING
        VALUE(rv_value) TYPE string.

    "! First capture group of the pattern when it matches the complete value (the value itself when the
    "! pattern has no group); blank = no match or not valid PCRE
    CLASS-METHODS capture
      IMPORTING
        iv_value        TYPE string
        iv_pattern      TYPE clike
      RETURNING
        VALUE(rv_value) TYPE string.

    "! The window of a parent still runs at iv_now
    CLASS-METHODS window_open
      IMPORTING
        iv_first_seen  TYPE timestampl
        iv_window_min  TYPE i
        iv_now         TYPE timestampl
      RETURNING
        VALUE(rv_open) TYPE abap_bool.

    CLASS-METHODS new_group
      RETURNING
        VALUE(rv_id) TYPE zif_ca_ops_resp_types=>ty_uuid
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_correlator IMPLEMENTATION.

  METHOD key.
    DATA lt_parts TYPE string_table.
    DATA(lt_fields) = zcl_ca_ops_util=>split_list( to_upper( is_rule-key_fields ) ).
    IF lt_fields IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT lt_fields ASSIGNING FIELD-SYMBOL(<lv_field>).
      IF is_key_field( <lv_field> ) = abap_false.
        " an unknown field never correlates (the configuration app refuses it, message 153)
        RETURN.
      ENDIF.
      INSERT field_value( iv_field = <lv_field> is_row = is_row ) INTO TABLE lt_parts.
    ENDLOOP.
    DATA(lv_filled) = concat_lines_of( lt_parts ).
    IF lv_filled IS INITIAL.
      " every key field blank: nothing to correlate on
      RETURN.
    ENDIF.
    DATA(lv_joined) = concat_lines_of( table = lt_parts sep = zif_ca_ops_resp_types=>gc_key_separator ).
    rv_key = COND #( WHEN is_rule-key_pattern IS INITIAL THEN lv_joined
                     ELSE capture( iv_value = lv_joined iv_pattern = is_rule-key_pattern ) ).
  ENDMETHOD.


  METHOD hash.
    DATA lv_hash TYPE string.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING
            if_algorithm  = zif_ca_ops_resp_types=>gc_hash_algorithm
            if_data       = concat_lines_of( table = VALUE string_table( ( CONV #( iv_area ) ) ( CONV #( iv_rule ) )
                                                                         ( CONV #( iv_bukrs ) ) ( iv_key ) )
                                             sep   = zif_ca_ops_resp_types=>gc_key_separator )
          IMPORTING
            ef_hashstring = lv_hash ).
      CATCH cx_abap_message_digest.
        " without a hash the exception is simply not correlated (the caller skips a blank key)
        CLEAR lv_hash.
    ENDTRY.
    rv_hash = lv_hash.
  ENDMETHOD.


  METHOD select.
    DATA(lt_rules) = it_rules.
    SORT lt_rules BY corr_rule.
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_index) = sy-tabix.
      IF <ls_row>-disposition <> zif_ca_ops_types=>gc_disposition-open
         OR <ls_row>-corr_id IS NOT INITIAL
         OR zcl_ca_ops_util=>severity_rank( <ls_row>-severity ) < 2.
        CONTINUE.
      ENDIF.
      LOOP AT lt_rules ASSIGNING FIELD-SYMBOL(<ls_rule>) WHERE area = <ls_row>-area.
        IF <ls_rule>-check_pattern IS NOT INITIAL
           AND zcl_ca_ops_util=>pcre_match( iv_value   = <ls_row>-check_code
                                            iv_pattern = <ls_rule>-check_pattern ) = abap_false.
          CONTINUE.
        ENDIF.
        DATA(lv_key) = key( is_rule = <ls_rule> is_row = <ls_row> ).
        IF lv_key IS INITIAL.
          CONTINUE.
        ENDIF.
        DATA(lv_hash) = hash( iv_area  = <ls_row>-area
                              iv_rule  = <ls_rule>-corr_rule
                              iv_bukrs = <ls_row>-bukrs
                              iv_key   = lv_key ).
        IF lv_hash IS NOT INITIAL.
          INSERT VALUE #( index = lv_index corr_key = lv_hash window_min = <ls_rule>-window_min ) INTO TABLE rt_items.
        ENDIF.
        EXIT.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD assign.
    DATA lt_batch TYPE zif_ca_ops_resp_types=>tt_corr_parent.
    DATA(lt_parents) = it_parents.
    " the newest parent of a key first
    SORT lt_parents BY corr_key first_seen_at DESCENDING.
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      ASSIGN ct_rows[ <ls_item>-index ] TO FIELD-SYMBOL(<ls_row>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_group) = VALUE zif_ca_ops_resp_types=>ty_uuid( ).
      LOOP AT lt_parents ASSIGNING FIELD-SYMBOL(<ls_parent>) WHERE corr_key = <ls_item>-corr_key.
        IF window_open( iv_first_seen = <ls_parent>-first_seen_at
                        iv_window_min = <ls_item>-window_min
                        iv_now        = iv_now ) = abap_true.
          lv_group = <ls_parent>-corr_id.
        ENDIF.
        EXIT.
      ENDLOOP.
      IF lv_group IS INITIAL.
        " an earlier exception of the same key in this batch is the parent (its window starts now)
        lv_group = VALUE #( lt_batch[ corr_key = <ls_item>-corr_key ]-corr_id OPTIONAL ).
      ENDIF.
      <ls_row>-corr_key = <ls_item>-corr_key.
      IF lv_group IS NOT INITIAL.
        <ls_row>-corr_id   = lv_group.
        <ls_row>-corr_role = zif_ca_ops_resp_types=>gc_corr_role-child.
      ELSE.
        <ls_row>-corr_id   = new_group( ).
        <ls_row>-corr_role = zif_ca_ops_resp_types=>gc_corr_role-parent.
        INSERT VALUE #( corr_key = <ls_item>-corr_key corr_id = <ls_row>-corr_id first_seen_at = iv_now )
          INTO TABLE lt_batch.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_key_field.
    DATA(lv_field) = to_upper( condense( CONV string( iv_field ) ) ).
    rv_valid = xsdbool( lv_field = zif_ca_ops_resp_types=>gc_key_field-object_key
                        OR lv_field = zif_ca_ops_resp_types=>gc_key_field-object_type
                        OR lv_field = zif_ca_ops_resp_types=>gc_key_field-group1
                        OR lv_field = zif_ca_ops_resp_types=>gc_key_field-group2
                        OR lv_field = zif_ca_ops_resp_types=>gc_key_field-rule_id
                        OR lv_field = zif_ca_ops_resp_types=>gc_key_field-check_code ).
  ENDMETHOD.


  METHOD field_value.
    rv_value = condense( SWITCH string( iv_field
                                        WHEN zif_ca_ops_resp_types=>gc_key_field-object_key  THEN is_row-object_key
                                        WHEN zif_ca_ops_resp_types=>gc_key_field-object_type THEN is_row-object_type
                                        WHEN zif_ca_ops_resp_types=>gc_key_field-group1      THEN is_row-group1
                                        WHEN zif_ca_ops_resp_types=>gc_key_field-group2      THEN is_row-group2
                                        WHEN zif_ca_ops_resp_types=>gc_key_field-rule_id     THEN is_row-rule_id
                                        WHEN zif_ca_ops_resp_types=>gc_key_field-check_code  THEN is_row-check_code ) ).
  ENDMETHOD.


  METHOD capture.
    TRY.
        DATA(lo_matcher) = cl_abap_regex=>create_pcre( pattern     = CONV string( condense( iv_pattern ) )
                                                       ignore_case = abap_true )->create_matcher( text = iv_value ).
        " match( ) = the complete value (the house rule of every configured pattern)
        IF lo_matcher->match( ) = abap_false.
          RETURN.
        ENDIF.
        TRY.
            rv_value = lo_matcher->get_submatch( 1 ).
          CATCH cx_sy_no_submatch.
            rv_value = iv_value.
        ENDTRY.
      CATCH cx_sy_invalid_regex cx_sy_regex_too_complex cx_sy_matcher.
        CLEAR rv_value.
    ENDTRY.
  ENDMETHOD.


  METHOD window_open.
    IF iv_window_min <= 0 OR iv_first_seen IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        rv_open = xsdbool( cl_abap_tstmp=>subtract( tstmp1 = iv_now tstmp2 = iv_first_seen )
                           < iv_window_min * zif_ca_ops_resp_types=>gc_seconds_per_minute ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        rv_open = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD new_group.
    DATA lx_uuid TYPE REF TO cx_uuid_error.
    TEST-SEAM corr_id.
      TRY.
          rv_id = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error INTO lx_uuid.
          " raised below: two groups without an ID would merge
      ENDTRY.
    END-TEST-SEAM.
    IF lx_uuid IS BOUND OR rv_id IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e155(zca_ops)
        EXPORTING
          previous = lx_uuid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
