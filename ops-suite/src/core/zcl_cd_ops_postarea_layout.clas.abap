*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_layout.clas.abap
*& Purpose:
*& Layouts of the four mapping purposes (ZRSN, ZPMC, ZBTM, ZBTR): key and
*& result fields in FQC0 / column order, the characters each reader takes
*& (from the readers' own types), where '*' is applied and which keys are
*& required - and whether the layout fits a FI-CA customer posting area
*& (TFK033D of the reference system: 8 keys, 6 results, CHAR 12). A purpose
*& whose layout does not fit is never read from a posting area: the reader
*& refuses source P for it and the configuration check reports why
*& (messages 440 / 441). No SQL, no state.
*& Modification log:
*& 2026-11-15 | Initial version (layouts moved from ZCL_CD_OPS_CFG_CHECKS; fit to TFK033D for the source
*&            | per purpose, product review 2026-11-15).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - mapping layouts and fit to TFK033D</p>
CLASS zcl_cd_ops_postarea_layout DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Layout of the purpose (area blank - the caller names it); initial for an unknown purpose
    CLASS-METHODS layout
      IMPORTING
        iv_purpose       TYPE zif_cd_ops_postarea_types=>ty_purpose
      RETURNING
        VALUE(rs_layout) TYPE zif_cd_ops_postarea_types=>ty_layout.

    "! What a posting area cannot hold of the layout: one message per field longer than CHAR 12
    "! (440: field, length, capacity) and one when there are more results than TFK033D has (441:
    "! results, capacity) - purpose, area and entry blank. Empty: the layout fits.
    CLASS-METHODS misfits
      IMPORTING
        iv_purpose         TYPE zif_cd_ops_postarea_types=>ty_purpose
      RETURNING
        VALUE(rt_messages) TYPE zif_cd_ops_postarea_types=>tt_check_message.

    "! Typed table of the purpose (ZCD_OPS_MAP*); blank for an unknown purpose
    CLASS-METHODS table_of
      IMPORTING
        iv_purpose      TYPE zif_cd_ops_postarea_types=>ty_purpose
      RETURNING
        VALUE(rv_table) TYPE zif_ca_ops_cfg_types=>ty_name.

    "! Entity of the typed table in the configuration app ZUI_CD_OPS_CFG (transport recording)
    CLASS-METHODS entity_of
      IMPORTING
        iv_purpose       TYPE zif_cd_ops_postarea_types=>ty_purpose
      RETURNING
        VALUE(rv_entity) TYPE zif_ca_ops_cfg_types=>ty_name.

  PRIVATE SECTION.
    "! Characters of a character-like field of a reader's structure
    CLASS-METHODS length_of
      IMPORTING
        iv_field         TYPE any
      RETURNING
        VALUE(rv_length) TYPE i.

ENDCLASS.



CLASS zcl_cd_ops_postarea_layout IMPLEMENTATION.

  METHOD layout.
    " The reader's own types give the lengths: a value longer than its reader takes is a finding,
    " never truncated
    DATA ls_reason TYPE zif_cd_ebs_types=>ty_reason_map.
    DATA ls_map    TYPE zif_cd_ebs_types=>ty_btc_map.
    DATA ls_class  TYPE zif_cd_hck_runtime_types=>ty_pm_class.
    DATA ls_role   TYPE zif_cd_hck_runtime_types=>ty_btc_role_row.
    DATA lv_pymet  TYPE zif_cd_hck_runtime_types=>ty_pymet.
    DATA lv_usage  TYPE zif_cd_hck_types=>ty_btc_usage.
    DATA lv_set    TYPE zif_cd_hck_recon_types=>ty_set_id.

    rs_layout-purpose = iv_purpose.
    CASE iv_purpose.
      WHEN zif_cd_ops_postarea_types=>gc_purpose-reason.
        rs_layout-keys = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-reason
                                    length = length_of( ls_reason-reason ) generic = abap_true required = abap_true ) ).
        rs_layout-results = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-fica_reason
                                       length = length_of( ls_reason-fica_reason ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-is_noc
                                       length = length_of( ls_reason-is_noc ) ) ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-pm_class.
        rs_layout-keys = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-flow
                                    length = length_of( ls_class-flow ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-pay_method
                                    length = length_of( lv_pymet ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-house_bank
                                    length = length_of( ls_class-hbkid ) generic = abap_true required = abap_true ) ).
        rs_layout-results = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-method_class
                                       length = length_of( ls_class-method_class ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-age_basis
                                       length = length_of( ls_class-age_basis ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-calendar
                                       length = length_of( ls_class-calendar ) ) ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_map.
        rs_layout-keys = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-scheme
                                    length = length_of( ls_map-scheme ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-code
                                    length = length_of( ls_map-btc_code ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-family
                                    length = length_of( ls_map-btc_code ) )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-sub_family
                                    length = length_of( ls_map-btc_code ) generic = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-bank_key
                                    length = length_of( ls_map-bank_key ) generic = abap_true required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-flow
                                    length = length_of( ls_map-flow_type ) generic = abap_true required = abap_true ) ).
        rs_layout-results = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-category
                                       length = length_of( ls_map-category ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-rule_group
                                       length = length_of( ls_map-rule_group ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-exp_cdi
                                       length = length_of( ls_map-exp_cdi ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-pay_method
                                       length = length_of( ls_map-pay_method ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-posting_rule
                                       length = length_of( ls_map-posting_rule ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-action
                                       length = length_of( ls_map-action ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-disposition
                                       length = length_of( ls_map-disposition ) ) ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_role.
        rs_layout-keys = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-usage
                                    length = length_of( lv_usage ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-scope
                                    length = length_of( lv_set ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-scheme
                                    length = length_of( ls_role-scheme ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-code
                                    length = length_of( ls_role-btc_code ) required = abap_true )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-family
                                    length = length_of( ls_role-btc_code ) )
                                  ( name = zif_cd_ops_postarea_types=>gc_field-sub_family
                                    length = length_of( ls_role-btc_code ) ) ).
        rs_layout-results = VALUE #( ( name = zif_cd_ops_postarea_types=>gc_field-role
                                       length = length_of( ls_role-role ) )
                                     ( name = zif_cd_ops_postarea_types=>gc_field-compare_amount
                                       length = length_of( ls_role-compare_amount ) ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD misfits.
    DATA(ls_layout) = layout( iv_purpose ).
    DATA(lt_fields) = ls_layout-keys.
    INSERT LINES OF ls_layout-results INTO TABLE lt_fields.
    LOOP AT lt_fields ASSIGNING FIELD-SYMBOL(<ls_field>)
         WHERE length > zif_cd_ops_postarea_types=>gc_postarea_capacity-length.
      INSERT VALUE #( severity = zif_ca_ops_types=>gc_severity-error
                      number   = zif_cd_ops_cfg_types=>gc_msg-postarea_too_short
                      v1       = <ls_field>-name
                      v2       = |{ <ls_field>-length }|
                      v3       = |{ zif_cd_ops_postarea_types=>gc_postarea_capacity-length }| ) INTO TABLE rt_messages.
    ENDLOOP.
    IF lines( ls_layout-results ) > zif_cd_ops_postarea_types=>gc_postarea_capacity-results
       OR lines( ls_layout-keys ) > zif_cd_ops_postarea_types=>gc_postarea_capacity-keys.
      INSERT VALUE #( severity = zif_ca_ops_types=>gc_severity-error
                      number   = zif_cd_ops_cfg_types=>gc_msg-postarea_too_few
                      v1       = |{ lines( ls_layout-keys ) }{ zif_cd_ops_postarea_types=>gc_key_separator }| &&
                                 |{ lines( ls_layout-results ) }|
                      v2       = |{ zif_cd_ops_postarea_types=>gc_postarea_capacity-keys }| &&
                                 |{ zif_cd_ops_postarea_types=>gc_key_separator }| &&
                                 |{ zif_cd_ops_postarea_types=>gc_postarea_capacity-results }| ) INTO TABLE rt_messages.
    ENDIF.
  ENDMETHOD.


  METHOD table_of.
    rv_table = SWITCH #( iv_purpose
                         WHEN zif_cd_ops_postarea_types=>gc_purpose-reason   THEN zif_cd_ops_postarea_types=>gc_table-reason
                         WHEN zif_cd_ops_postarea_types=>gc_purpose-pm_class THEN zif_cd_ops_postarea_types=>gc_table-pm_class
                         WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_map  THEN zif_cd_ops_postarea_types=>gc_table-btc_map
                         WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_role THEN zif_cd_ops_postarea_types=>gc_table-btc_role ).
  ENDMETHOD.


  METHOD entity_of.
    rv_entity = SWITCH #( iv_purpose
                          WHEN zif_cd_ops_postarea_types=>gc_purpose-reason   THEN zif_cd_ops_postarea_types=>gc_entity-reason
                          WHEN zif_cd_ops_postarea_types=>gc_purpose-pm_class THEN zif_cd_ops_postarea_types=>gc_entity-pm_class
                          WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_map  THEN zif_cd_ops_postarea_types=>gc_entity-btc_map
                          WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_role THEN zif_cd_ops_postarea_types=>gc_entity-btc_role ).
  ENDMETHOD.


  METHOD length_of.
    DESCRIBE FIELD iv_field LENGTH rv_length IN CHARACTER MODE.
  ENDMETHOD.

ENDCLASS.
