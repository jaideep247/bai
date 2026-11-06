*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_rule_base.clas.abap
*& Purpose:
*& Shared helpers for EBS rules: repository access through the factory, key
*& normalisation of bank references (lengths are parameters, not code),
*& parameter lists and statement lookup. Abstract: no behaviour of its own.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check register scoped to house bank account; DPAYH proposal runs excluded (review 3.2).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - rule base</p>
CLASS zcl_cd_ebs_rule_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_rule
      ABSTRACT METHODS execute.

    "! Default length of document-number keys (OPBEL/AUGBL/DOC1R): ZCD_OPS_PARAM EBS_KEYLEN_DOCNO
    CONSTANTS gc_default_docno_length TYPE i VALUE 12.

  PROTECTED SECTION.
    TYPES tt_stmt_hash TYPE HASHED TABLE OF zif_cd_ebs_types=>ty_statement WITH UNIQUE KEY stmt_key.

    METHODS sap_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ebs_sap_dao.

    METHODS feb_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ebs_feb_dao.

    METHODS param
      IMPORTING
        iv_name         TYPE zif_cd_ops_types=>ty_param_name
        iv_default      TYPE string OPTIONAL
      RETURNING
        VALUE(rv_value) TYPE string.

    "! Bank reference -> FI-CA document number key (FEBEP-CHECT = DFKKOP-AUGBL)
    METHODS docno_key
      IMPORTING
        iv_reference  TYPE clike
      RETURNING
        VALUE(rv_key) TYPE zif_cd_ebs_sap_dao=>ty_docno.

    "! Bank reference -> check register key (DFKKCR-ZTNUM = FEBEP-CHECT; as-is by default)
    METHODS ztnum_key
      IMPORTING
        iv_reference  TYPE clike
      RETURNING
        VALUE(rv_key) TYPE zif_cd_ebs_sap_dao=>ty_ztnum.

    METHODS docno_keys
      IMPORTING
        it_lines       TYPE zif_cd_ebs_types=>tt_line
      RETURNING
        VALUE(rt_keys) TYPE zif_cd_ebs_sap_dao=>tt_docno.

    "! Comma list from a rule parameter, or the default list when the parameter is blank
    METHODS value_list
      IMPORTING
        iv_values      TYPE clike
        iv_default     TYPE string OPTIONAL
      RETURNING
        VALUE(rt_list) TYPE string_table.

    METHODS in_list
      IMPORTING
        iv_value      TYPE clike
        it_list       TYPE string_table
      RETURNING
        VALUE(rv_hit) TYPE abap_bool.

    METHODS amount_param
      IMPORTING
        iv_value         TYPE clike
        iv_default       TYPE decfloat34 DEFAULT 0
      RETURNING
        VALUE(rv_amount) TYPE decfloat34.

    "! Rule tolerance; 0.00 when not configured
    METHODS tolerance
      IMPORTING
        is_rule             TYPE zif_cd_ebs_types=>ty_rule_cfg
      RETURNING
        VALUE(rv_tolerance) TYPE zif_cd_ops_types=>ty_amount.

    "! Check register rows of one check number, scoped to the house bank account of the
    "! line's statement when both sides carry it (ZTNUM is unique only per account)
    METHODS checks_for_line
      IMPORTING
        it_checks        TYPE zif_cd_ebs_sap_dao=>tt_check
        is_line          TYPE zif_cd_ebs_types=>ty_line
        it_statements    TYPE zif_cd_ebs_types=>tt_statement
      RETURNING
        VALUE(rt_checks) TYPE zif_cd_ebs_sap_dao=>tt_check.

    METHODS line_reference
      IMPORTING
        is_line             TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rv_reference) TYPE zif_cd_ebs_types=>ty_text35.

ENDCLASS.



CLASS zcl_cd_ebs_rule_base IMPLEMENTATION.

  METHOD sap_dao.
    ro_dao = zcl_cd_ebs_factory=>get_sap_dao( ).
  ENDMETHOD.


  METHOD feb_dao.
    ro_dao = zcl_cd_ebs_factory=>get_feb_dao( ).
  ENDMETHOD.


  METHOD param.
    rv_value = zcl_cd_ops_factory=>get_store( )->get_param( iv_name = iv_name iv_default = iv_default ).
  ENDMETHOD.


  METHOD docno_key.
    DATA(lv_length) = CONV i( zcl_cd_ops_util=>to_decimal(
      iv_value   = param( iv_name = 'EBS_KEYLEN_DOCNO' iv_default = |{ gc_default_docno_length }| )
      iv_default = gc_default_docno_length ) ).
    rv_key = zcl_cd_ops_util=>normalize_key( iv_reference = iv_reference iv_length = lv_length ).
  ENDMETHOD.


  METHOD ztnum_key.
    DATA(lv_length) = CONV i( zcl_cd_ops_util=>to_decimal(
      iv_value = param( iv_name = 'EBS_KEYLEN_ZTNUM' iv_default = `0` ) ) ).
    rv_key = zcl_cd_ops_util=>normalize_key( iv_reference = iv_reference iv_length = lv_length ).
  ENDMETHOD.


  METHOD docno_keys.
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(lv_reference) = line_reference( ls_line ).
      IF lv_reference IS NOT INITIAL.
        INSERT docno_key( lv_reference ) INTO TABLE rt_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD value_list.
    DATA(lv_values) = condense( CONV string( iv_values ) ).
    rt_list = zcl_cd_ops_util=>split_list( COND string( WHEN lv_values IS INITIAL THEN iv_default
                                                         ELSE lv_values ) ).
  ENDMETHOD.


  METHOD in_list.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    rv_hit = xsdbool( line_exists( it_list[ table_line = lv_value ] ) ).
  ENDMETHOD.


  METHOD amount_param.
    rv_amount = zcl_cd_ops_util=>to_decimal( iv_value = iv_value iv_default = iv_default ).
  ENDMETHOD.


  METHOD tolerance.
    rv_tolerance = abs( is_rule-tolerance ).
  ENDMETHOD.


  METHOD checks_for_line.
    DATA(lv_ztnum) = ztnum_key( line_reference( is_line ) ).
    IF lv_ztnum IS INITIAL.
      RETURN.
    ENDIF.
    DATA(ls_statement) = VALUE #( it_statements[ stmt_key = is_line-stmt_key ] OPTIONAL ).
    LOOP AT it_checks INTO DATA(ls_check) WHERE ztnum = lv_ztnum.
      IF ls_statement-hbkid IS NOT INITIAL AND ls_check-hbkid IS NOT INITIAL
         AND ( ls_check-hbkid <> ls_statement-hbkid OR ls_check-hktid <> ls_statement-hktid ).
        CONTINUE.
      ENDIF.
      INSERT ls_check INTO TABLE rt_checks.
    ENDLOOP.
  ENDMETHOD.


  METHOD line_reference.
    rv_reference = COND #( WHEN is_line-reference IS NOT INITIAL THEN is_line-reference
                           WHEN is_line-check_no  IS NOT INITIAL THEN is_line-check_no
                           ELSE is_line-end_to_end_id ).
  ENDMETHOD.

ENDCLASS.
