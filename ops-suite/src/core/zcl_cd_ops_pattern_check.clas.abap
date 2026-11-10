*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pattern_check.clas.abap
*& Purpose:
*& Pure pattern logic behind the reports ZCD_OPS_PATTERN_CHECK and
*& ZCD_OPS_PATTERN_MIGRATE (user decision 2026-11-06): which configured PCRE
*& patterns capture which real values - values matched by no pattern,
*& patterns that match nothing, invalid patterns - and the one-off conversion
*& of CP wildcards into PCRE (escape metacharacters, * -> .*, + -> ., #x ->
*& literal x) with the migration plan per configuration row. No database,
*& nothing written. Matching: ZCL_CD_OPS_UTIL=>PCRE_MATCH (complete value,
*& case ignored).
*& Modification log:
*& 2026-11-06 | Initial version (PCRE patterns: pattern check and migration).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - pattern check and CP to PCRE rule</p>
CLASS zcl_cd_ops_pattern_check DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Which pattern captures which value: one MATCHED row per value and pattern, a
    "! NO_MATCH row per value no pattern captures, an UNUSED row per pattern that
    "! captures no value and an INVALID row per pattern that does not compile
    CLASS-METHODS analyse
      IMPORTING
        it_patterns      TYPE zif_cd_ops_pattern_types=>tt_pattern
        it_values        TYPE zif_cd_ops_pattern_types=>tt_value
      RETURNING
        VALUE(rs_result) TYPE zif_cd_ops_pattern_types=>ty_check_result.

    "! Payment engine area that owns a pattern area (authorisation ZCD_OPS); blank = unknown area
    CLASS-METHODS pe_area_of
      IMPORTING
        iv_area           TYPE zif_cd_ops_pattern_types=>ty_area
      RETURNING
        VALUE(rv_pe_area) TYPE zif_ca_ops_types=>ty_area.

    "! Payment engine area that owns a configuration table of the migration (authorisation)
    CLASS-METHODS pe_area_of_table
      IMPORTING
        iv_table          TYPE zif_cd_ops_pattern_types=>ty_name
      RETURNING
        VALUE(rv_pe_area) TYPE zif_ca_ops_types=>ty_area.

    "! RAP entity of a customizing table for transport recording; blank = application data
    "! (ZCD_HCK_SUPPRESS, maintained in each system, never transported)
    CLASS-METHODS entity_of_table
      IMPORTING
        iv_table         TYPE zif_cd_ops_pattern_types=>ty_name
      RETURNING
        VALUE(rv_entity) TYPE zif_cd_ops_pattern_types=>ty_name.

    "! Conversion rule of a CP wildcard into PCRE for the same values: PCRE metacharacters
    "! escaped, * -> .*, + -> ., #x -> literal x (a trailing # is a literal #). Blank stays
    "! blank; the result is matched to the complete value with case ignored, as CP was.
    CLASS-METHODS from_wildcard
      IMPORTING
        iv_wildcard    TYPE clike
      RETURNING
        VALUE(rv_pcre) TYPE string.

    "! The pattern is already written in PCRE syntax (escape, class, group, quantifier,
    "! anchor, alternative, .* or .+) - never converted a second time
    CLASS-METHODS is_pcre_syntax
      IMPORTING
        iv_pattern     TYPE clike
      RETURNING
        VALUE(rv_pcre) TYPE abap_bool.

    "! New pattern and status of every configuration row (CONVERT, UNCHANGED, ALREADY_PCRE,
    "! INVALID, TOO_LONG); a list field (ZCD_HCK_DEF parameter) is converted item by item
    CLASS-METHODS plan_migration
      IMPORTING
        it_rows        TYPE zif_cd_ops_pattern_types=>tt_migration
      RETURNING
        VALUE(rt_rows) TYPE zif_cd_ops_pattern_types=>tt_migration.

  PRIVATE SECTION.
    "! CP wildcard syntax
    CONSTANTS:
      BEGIN OF gc_cp,
        any_string TYPE string VALUE `*`,
        any_char   TYPE string VALUE `+`,
        escape     TYPE string VALUE `#`,
      END OF gc_cp.
    "! PCRE syntax
    CONSTANTS:
      BEGIN OF gc_pcre,
        any_string TYPE string VALUE `.*`,
        any_char   TYPE string VALUE `.`,
        escape     TYPE string VALUE `\`,
        "! Characters with a meaning in PCRE (escaped when converted)
        meta       TYPE string VALUE `\^$.|?*+()[]{}`,
        "! Characters a CP wildcard never needs: their presence means PCRE syntax
        only_pcre  TYPE string VALUE `\^$|?()[]{}`,
        any_more   TYPE string VALUE `.+`,
      END OF gc_pcre.
    "! Separator of a converted pattern list
    CONSTANTS gc_list_separator TYPE string VALUE `, `.

    TYPES:
      BEGIN OF ty_conversion,
        new    TYPE string,
        status TYPE zif_cd_ops_pattern_types=>ty_status,
      END OF ty_conversion.

    CLASS-METHODS convert
      IMPORTING
        iv_old               TYPE string
      RETURNING
        VALUE(rs_conversion) TYPE ty_conversion.

    CLASS-METHODS escaped
      IMPORTING
        iv_char        TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_cd_ops_pattern_check IMPLEMENTATION.

  METHOD analyse.
    TYPES:
      BEGIN OF ty_valid,
        pattern TYPE string,
        source  TYPE string,
        hits    TYPE i,
      END OF ty_valid.
    DATA lt_valid TYPE STANDARD TABLE OF ty_valid WITH EMPTY KEY.
    DATA lt_matched TYPE zif_cd_ops_pattern_types=>tt_check_row.
    DATA lt_unmatched TYPE zif_cd_ops_pattern_types=>tt_check_row.
    DATA lt_unused TYPE zif_cd_ops_pattern_types=>tt_check_row.

    LOOP AT it_patterns ASSIGNING FIELD-SYMBOL(<ls_pattern>).
      IF zcl_ca_ops_util=>pcre_valid( <ls_pattern>-pattern ) = abap_false.
        INSERT VALUE #( status  = zif_cd_ops_pattern_types=>gc_check-invalid
                        pattern = <ls_pattern>-pattern
                        source  = <ls_pattern>-source ) INTO TABLE rs_result-rows.
        rs_result-invalid += 1.
      ELSE.
        INSERT VALUE #( pattern = <ls_pattern>-pattern source = <ls_pattern>-source ) INTO TABLE lt_valid.
      ENDIF.
    ENDLOOP.

    LOOP AT it_values ASSIGNING FIELD-SYMBOL(<lv_value>).
      DATA(lv_first) = lines( lt_matched ) + 1.
      LOOP AT lt_valid ASSIGNING FIELD-SYMBOL(<ls_valid>).
        IF zcl_ca_ops_util=>pcre_match( iv_value = <lv_value> iv_pattern = <ls_valid>-pattern ) = abap_true.
          <ls_valid>-hits += 1.
          INSERT VALUE #( status  = zif_cd_ops_pattern_types=>gc_check-matched
                          value   = <lv_value>
                          pattern = <ls_valid>-pattern
                          source  = <ls_valid>-source ) INTO TABLE lt_matched.
        ENDIF.
      ENDLOOP.
      DATA(lv_hits) = lines( lt_matched ) - lv_first + 1.
      IF lv_hits = 0.
        INSERT VALUE #( status = zif_cd_ops_pattern_types=>gc_check-no_match
                        value  = <lv_value> ) INTO TABLE lt_unmatched.
        CONTINUE.
      ENDIF.
      " Value rows name how many patterns capture the value (more than one: overlap)
      LOOP AT lt_matched ASSIGNING FIELD-SYMBOL(<ls_row>) FROM lv_first.
        <ls_row>-hits = lv_hits.
      ENDLOOP.
    ENDLOOP.

    LOOP AT lt_valid ASSIGNING <ls_valid> WHERE hits = 0.
      INSERT VALUE #( status  = zif_cd_ops_pattern_types=>gc_check-unused
                      pattern = <ls_valid>-pattern
                      source  = <ls_valid>-source ) INTO TABLE lt_unused.
    ENDLOOP.

    rs_result-values    = lines( it_values ).
    rs_result-unmatched = lines( lt_unmatched ).
    rs_result-unused    = lines( lt_unused ).
    " Problems first: invalid patterns, values not captured, patterns capturing nothing
    INSERT LINES OF lt_unmatched INTO TABLE rs_result-rows.
    INSERT LINES OF lt_unused INTO TABLE rs_result-rows.
    INSERT LINES OF lt_matched INTO TABLE rs_result-rows.
  ENDMETHOD.


  METHOD pe_area_of.
    rv_pe_area = SWITCH #( iv_area
                           WHEN zif_cd_ops_pattern_types=>gc_area-ebs_flow    THEN zif_cd_ops_types=>gc_pe_area-ebs
                           WHEN zif_cd_ops_pattern_types=>gc_area-fmon_file   THEN zif_cd_ops_types=>gc_pe_area-file_monitor
                           WHEN zif_cd_ops_pattern_types=>gc_area-hck_job
                             OR zif_cd_ops_pattern_types=>gc_area-hck_suppr   THEN zif_cd_ops_types=>gc_pe_area-health_check
                           WHEN zif_cd_ops_pattern_types=>gc_area-alert_rule
                             OR zif_cd_ops_pattern_types=>gc_area-alert_check
                             OR zif_cd_ops_pattern_types=>gc_area-alert_grp1
                             OR zif_cd_ops_pattern_types=>gc_area-alert_grp2  THEN zif_cd_ops_types=>gc_pe_area-core ).
  ENDMETHOD.


  METHOD pe_area_of_table.
    rv_pe_area = SWITCH #( iv_table
                           WHEN zif_cd_ops_pattern_types=>gc_table-flow_pattern THEN zif_cd_ops_types=>gc_pe_area-ebs
                           WHEN zif_cd_ops_pattern_types=>gc_table-fmon_iface   THEN zif_cd_ops_types=>gc_pe_area-file_monitor
                           WHEN zif_cd_ops_pattern_types=>gc_table-job_step
                             OR zif_cd_ops_pattern_types=>gc_table-hck_def
                             OR zif_cd_ops_pattern_types=>gc_table-suppression  THEN zif_cd_ops_types=>gc_pe_area-health_check
                           WHEN zif_cd_ops_pattern_types=>gc_table-alert_rule   THEN zif_cd_ops_types=>gc_pe_area-core ).
  ENDMETHOD.


  METHOD entity_of_table.
    rv_entity = SWITCH #( iv_table
                          WHEN zif_cd_ops_pattern_types=>gc_table-flow_pattern THEN zif_cd_ops_pattern_types=>gc_entity-flow_pattern
                          WHEN zif_cd_ops_pattern_types=>gc_table-fmon_iface   THEN zif_cd_ops_pattern_types=>gc_entity-fmon_iface
                          WHEN zif_cd_ops_pattern_types=>gc_table-job_step     THEN zif_cd_ops_pattern_types=>gc_entity-job_step
                          WHEN zif_cd_ops_pattern_types=>gc_table-alert_rule   THEN zif_cd_ops_pattern_types=>gc_entity-alert_rule
                          WHEN zif_cd_ops_pattern_types=>gc_table-hck_def      THEN zif_cd_ops_pattern_types=>gc_entity-hck_def ).
  ENDMETHOD.


  METHOD from_wildcard.
    DATA lv_escape TYPE abap_bool.
    DATA(lv_cp) = CONV string( iv_wildcard ).
    DO strlen( lv_cp ) TIMES.
      DATA(lv_char) = substring( val = lv_cp off = sy-index - 1 len = 1 ).
      IF lv_escape = abap_true.
        " CP #x: x is literal
        lv_escape = abap_false.
        rv_pcre = |{ rv_pcre }{ escaped( lv_char ) }|.
      ELSEIF lv_char = gc_cp-escape.
        lv_escape = abap_true.
      ELSEIF lv_char = gc_cp-any_string.
        rv_pcre = |{ rv_pcre }{ gc_pcre-any_string }|.
      ELSEIF lv_char = gc_cp-any_char.
        rv_pcre = |{ rv_pcre }{ gc_pcre-any_char }|.
      ELSE.
        rv_pcre = |{ rv_pcre }{ escaped( lv_char ) }|.
      ENDIF.
    ENDDO.
    IF lv_escape = abap_true.
      rv_pcre = |{ rv_pcre }{ escaped( gc_cp-escape ) }|.
    ENDIF.
  ENDMETHOD.


  METHOD is_pcre_syntax.
    DATA(lv_pattern) = CONV string( iv_pattern ).
    rv_pcre = xsdbool( lv_pattern CA gc_pcre-only_pcre
                       OR find( val = lv_pattern sub = gc_pcre-any_string ) >= 0
                       OR find( val = lv_pattern sub = gc_pcre-any_more ) >= 0 ).
  ENDMETHOD.


  METHOD plan_migration.
    DATA lt_new TYPE string_table.
    rt_rows = it_rows.
    LOOP AT rt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      CLEAR: lt_new, <ls_row>-message.
      IF <ls_row>-is_list = abap_false.
        DATA(ls_conversion) = convert( <ls_row>-old ).
        <ls_row>-new    = ls_conversion-new.
        <ls_row>-status = ls_conversion-status.
      ELSE.
        " Item by item: the list converts when one item converts, is invalid when one is
        <ls_row>-status = zif_cd_ops_pattern_types=>gc_migration-unchanged.
        LOOP AT zcl_ca_ops_util=>split_list( <ls_row>-old ) INTO DATA(lv_item).
          ls_conversion = convert( lv_item ).
          INSERT ls_conversion-new INTO TABLE lt_new.
          IF ls_conversion-status = zif_cd_ops_pattern_types=>gc_migration-invalid.
            <ls_row>-status = ls_conversion-status.
          ELSEIF ls_conversion-status = zif_cd_ops_pattern_types=>gc_migration-convert
             AND <ls_row>-status <> zif_cd_ops_pattern_types=>gc_migration-invalid.
            <ls_row>-status = ls_conversion-status.
          ELSEIF ls_conversion-status = zif_cd_ops_pattern_types=>gc_migration-already_pcre
             AND <ls_row>-status = zif_cd_ops_pattern_types=>gc_migration-unchanged.
            <ls_row>-status = ls_conversion-status.
          ENDIF.
        ENDLOOP.
        <ls_row>-new = COND #( WHEN <ls_row>-status = zif_cd_ops_pattern_types=>gc_migration-convert
                               THEN concat_lines_of( table = lt_new sep = gc_list_separator )
                               ELSE <ls_row>-old ).
      ENDIF.
      CASE <ls_row>-status.
        WHEN zif_cd_ops_pattern_types=>gc_migration-invalid.
          <ls_row>-message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_msg-pattern_invalid
                                                    iv_v1    = <ls_row>-new ).
        WHEN zif_cd_ops_pattern_types=>gc_migration-convert.
          " Never written when it does not fit the field
          IF <ls_row>-max_length > 0 AND strlen( <ls_row>-new ) > <ls_row>-max_length.
            <ls_row>-status  = zif_cd_ops_pattern_types=>gc_migration-too_long.
            <ls_row>-message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_msg-pattern_too_long
                                                      iv_v1    = <ls_row>-new
                                                      iv_v2    = |{ <ls_row>-table }-{ <ls_row>-field }|
                                                      iv_v3    = <ls_row>-max_length ).
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD convert.
    IF iv_old IS INITIAL.
      rs_conversion-status = zif_cd_ops_pattern_types=>gc_migration-unchanged.
      RETURN.
    ENDIF.
    IF is_pcre_syntax( iv_old ) = abap_true.
      rs_conversion-new    = iv_old.
      rs_conversion-status = zif_cd_ops_pattern_types=>gc_migration-already_pcre.
    ELSE.
      rs_conversion-new    = from_wildcard( iv_old ).
      rs_conversion-status = COND #( WHEN rs_conversion-new = iv_old
                                     THEN zif_cd_ops_pattern_types=>gc_migration-unchanged
                                     ELSE zif_cd_ops_pattern_types=>gc_migration-convert ).
    ENDIF.
    " A pattern that does not compile is never written (and an existing one is reported)
    IF zcl_ca_ops_util=>pcre_valid( rs_conversion-new ) = abap_false.
      rs_conversion-status = zif_cd_ops_pattern_types=>gc_migration-invalid.
    ENDIF.
  ENDMETHOD.


  METHOD escaped.
    rv_text = COND #( WHEN iv_char CA gc_pcre-meta THEN |{ gc_pcre-escape }{ iv_char }| ELSE iv_char ).
  ENDMETHOD.

ENDCLASS.
