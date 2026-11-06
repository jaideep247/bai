*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r21_lookup.clas.abap
*& Purpose:
*& R21: generic configurable lookup. PARAM1 names a ZCD_EBS_LOOKUP row (table,
*& key field, key kind, status field, allowed values). Each line's reference must
*& exist in that table; with a status field, at least one matching row needs an
*& allowed status (any-row semantics as R07). A new BAI / CAMT validation against
*& a further table is configuration only. Unknown or inactive lookup, or a table /
*& field that is not in the DDIC, raises: the engine records PLUGIN_ERROR with
*& action BLOCK (fail closed).
*& Modification log:
*& 2026-11-06 | Initial version (phase 5: new codes and validations by configuration).
*& 2026-11-06 | Generic lookup rule R21 (ZCD_EBS_LOOKUP) - new validations by configuration.
*& 2026-11-06 | Audit A65: reference checked against the width of the lookup key kind (no truncation).
*& 2026-11-06 | FS-CD review: not found within EBS_INFLIGHT_HOURS of the statement is AWAITING_LOT_TRANSFER.
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R21 - configurable table lookup</p>
CLASS zcl_cd_ebs_r_r21_lookup DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

  PRIVATE SECTION.
    METHODS lookup_key
      IMPORTING
        is_lookup     TYPE zif_cd_ebs_types=>ty_lookup_cfg
        is_line       TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rv_key) TYPE zif_cd_ebs_sap_dao=>ty_lookup_key.

    "! A65: the line's reference cannot become the lookup key (width of the key kind)
    METHODS lookup_rejection
      IMPORTING
        is_rule           TYPE zif_cd_ebs_types=>ty_rule_cfg
        is_lookup         TYPE zif_cd_ebs_types=>ty_lookup_cfg
        is_line           TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

ENDCLASS.



CLASS zcl_cd_ebs_r_r21_lookup IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA lt_keys TYPE zif_cd_ebs_sap_dao=>tt_lookup_key.
    DATA lv_statuses TYPE string.
    DATA lv_found TYPE abap_bool.
    DATA lv_ok TYPE abap_bool.

    DATA(lt_lookups) = zcl_cd_ebs_factory=>get_cfg_dao( )->get_lookups( ).
    DATA(ls_lookup) = VALUE #( lt_lookups[ lookup_id = is_rule-param1 ] OPTIONAL ).
    IF ls_lookup IS INITIAL OR ls_lookup-active = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e050(zcd_ops) WITH zif_cd_ebs_types=>gc_lookup_table is_rule-param1.
    ENDIF.
    DATA(lv_not_found) = COND zif_cd_ops_types=>ty_check_code( WHEN ls_lookup-not_found_code IS NOT INITIAL
                                                              THEN ls_lookup-not_found_code
                                                              ELSE zif_cd_ebs_types=>gc_check_code-lookup_not_found ).
    DATA(lv_status_code) = COND zif_cd_ops_types=>ty_check_code( WHEN ls_lookup-status_code IS NOT INITIAL
                                                                THEN ls_lookup-status_code
                                                                ELSE zif_cd_ebs_types=>gc_check_code-lookup_status ).
    DATA(lt_allowed) = value_list( ls_lookup-allowed_values ).

    LOOP AT it_lines INTO DATA(ls_key_line).
      DATA(lv_line_key) = lookup_key( is_lookup = ls_lookup is_line = ls_key_line ).
      IF lv_line_key IS NOT INITIAL.
        INSERT lv_line_key INTO TABLE lt_keys.
      ENDIF.
    ENDLOOP.
    DATA(lt_rows) = sap_dao( )->get_lookup_rows( is_lookup = ls_lookup it_keys = lt_keys ).

    LOOP AT it_lines INTO DATA(ls_line).
      DATA(ls_rejection) = lookup_rejection( is_rule = is_rule is_lookup = ls_lookup is_line = ls_line ).
      IF ls_rejection IS NOT INITIAL.
        INSERT ls_rejection INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      DATA(lv_key) = lookup_key( is_lookup = ls_lookup is_line = ls_line ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.
      CLEAR: lv_statuses, lv_found, lv_ok.
      LOOP AT lt_rows INTO DATA(ls_row) USING KEY by_key WHERE lookup_key = lv_key.
        lv_found = abap_true.
        IF ls_lookup-status_field IS INITIAL OR lt_allowed IS INITIAL
           OR in_list( iv_value = ls_row-status it_list = lt_allowed ) = abap_true.
          lv_ok = abap_true.
          EXIT.
        ENDIF.
        lv_statuses = condense( |{ lv_statuses } { ls_row-status }| ).
      ENDLOOP.
      IF lv_found = abap_false.
        INSERT not_found_finding(
                 is_rule = is_rule is_line = ls_line it_statements = it_statements
                 iv_check_code = lv_not_found
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-lookup_not_found
                                                     iv_v1    = ls_lookup-lookup_id
                                                     iv_v2    = lv_key
                                                     iv_v3    = ls_lookup-table_name ) ) INTO TABLE rt_findings.
      ELSEIF lv_ok = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = lv_status_code
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-lookup_status
                                                     iv_v1    = ls_lookup-lookup_id
                                                     iv_v2    = lv_key
                                                     iv_v3    = lv_statuses
                                                     iv_v4    = ls_lookup-allowed_values ) ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD lookup_rejection.
    DATA lv_ztnum TYPE zif_cd_ebs_sap_dao=>ty_ztnum.
    DATA lv_generic TYPE zif_cd_ebs_sap_dao=>ty_lookup_key.
    rs_finding = SWITCH #( is_lookup-key_kind
                           WHEN zif_cd_ebs_types=>gc_lookup_key-docno
                           THEN docno_rejection( is_rule = is_rule is_line = is_line )
                           WHEN zif_cd_ebs_types=>gc_lookup_key-ztnum
                           THEN key_rejection( is_rule   = is_rule
                                               is_line   = is_line
                                               iv_length = ztnum_length( )
                                               iv_width  = key_width( lv_ztnum ) )
                           ELSE key_rejection( is_rule   = is_rule
                                               is_line   = is_line
                                               iv_length = is_lookup-key_length
                                               iv_width  = key_width( lv_generic ) ) ).
  ENDMETHOD.


  METHOD lookup_key.
    DATA(lv_reference) = line_reference( is_line ).
    rv_key = SWITCH #( is_lookup-key_kind
                       WHEN zif_cd_ebs_types=>gc_lookup_key-docno THEN docno_key( lv_reference )
                       WHEN zif_cd_ebs_types=>gc_lookup_key-ztnum THEN ztnum_key( lv_reference )
                       ELSE zcl_cd_ops_util=>normalize_key( iv_reference = lv_reference
                                                            iv_length    = is_lookup-key_length ) ).
  ENDMETHOD.

ENDCLASS.
