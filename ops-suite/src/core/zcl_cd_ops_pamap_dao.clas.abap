*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pamap_dao.clas.abap
*& Purpose:
*& SQL of the typed product mapping tables (product review 2026-11-15): one
*& set-based read of the rows of one mapping version per purpose, the typed
*& columns in layout order as KEY01.. / FUN01.. (the shape of a posting
*& area entry, so ZCL_CD_OPS_POSTAREA applies the same FQC0 precedence and
*& every consumer stays unchanged), and the insert of the migration report
*& ZCD_OPS_POSTAREA_COPY (rows of a new version, change stamps set, no
*& commit). Tables ZCD_OPS_MAPRSN, _MAPPMC, _MAPBTM, _MAPBTR (customizing,
*& maintained in the configuration app ZUI_CD_OPS_CFG).
*& Modification log:
*& 2026-11-15 | Initial version (typed product mapping tables, VERIFY V161 closed).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - typed mapping tables: SQL</p>
CLASS zcl_cd_ops_pamap_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pamap_dao.

  PRIVATE SECTION.
    TYPES tt_reason TYPE STANDARD TABLE OF zcd_ops_maprsn WITH EMPTY KEY.
    TYPES tt_class TYPE STANDARD TABLE OF zcd_ops_mappmc WITH EMPTY KEY.
    TYPES tt_map TYPE STANDARD TABLE OF zcd_ops_mapbtm WITH EMPTY KEY.
    TYPES tt_role TYPE STANDARD TABLE OF zcd_ops_mapbtr WITH EMPTY KEY.

    "! Column names of the typed table of a purpose in layout order (keys, then results) - the
    "! positions of KEY01.. / FUN01.. of the entry
    CLASS-METHODS columns
      IMPORTING
        iv_purpose     TYPE zif_cd_ops_postarea_types=>ty_purpose
      EXPORTING
        et_keys        TYPE string_table
        et_results     TYPE string_table.

    "! Typed row from an entry (layout positions), version and change stamps
    CLASS-METHODS fill_row
      IMPORTING
        iv_purpose TYPE zif_cd_ops_postarea_types=>ty_purpose
        iv_version TYPE zif_cd_ops_postarea_types=>ty_version
        is_entry   TYPE zif_cd_ops_postarea_types=>ty_entry
      CHANGING
        cs_row     TYPE any.

    CONSTANTS:
      BEGIN OF gc_column,
        version        TYPE string VALUE `VERSION`,
        changed_by     TYPE string VALUE `LAST_CHANGED_BY`,
        changed_at     TYPE string VALUE `LAST_CHANGED_AT`,
        local_changed  TYPE string VALUE `LOCAL_LAST_CHANGED_AT`,
        reason         TYPE string VALUE `REASON`,
        fica_reason    TYPE string VALUE `FICA_REASON`,
        is_noc         TYPE string VALUE `IS_NOC`,
        flow           TYPE string VALUE `FLOW`,
        pay_method     TYPE string VALUE `PAY_METHOD`,
        house_bank     TYPE string VALUE `HOUSE_BANK`,
        method_class   TYPE string VALUE `METHOD_CLASS`,
        age_basis      TYPE string VALUE `AGE_BASIS`,
        calendar       TYPE string VALUE `CALENDAR`,
        scheme         TYPE string VALUE `SCHEME`,
        code           TYPE string VALUE `CODE`,
        family         TYPE string VALUE `FAMILY`,
        sub_family     TYPE string VALUE `SUB_FAMILY`,
        bank           TYPE string VALUE `BANK`,
        category       TYPE string VALUE `CATEGORY`,
        rule_group     TYPE string VALUE `RULE_GROUP`,
        exp_cdi        TYPE string VALUE `EXP_CDI`,
        posting_rule   TYPE string VALUE `POSTING_RULE`,
        action         TYPE string VALUE `ACTION`,
        disposition    TYPE string VALUE `DISPOSITION`,
        usage          TYPE string VALUE `USAGE`,
        scope          TYPE string VALUE `SCOPE`,
        role           TYPE string VALUE `ROLE`,
        compare_amount TYPE string VALUE `COMPARE_AMOUNT`,
      END OF gc_column.

ENDCLASS.



CLASS zcl_cd_ops_pamap_dao IMPLEMENTATION.

  METHOD zif_cd_ops_pamap_dao~read_entries.
    " Typed CHAR columns into strings - trailing blanks dropped, nothing truncated; the column order of each
    " SELECT is the layout of the purpose (FICA_Posting_Areas.md section 2)
    CASE iv_purpose.
      WHEN zif_cd_ops_postarea_types=>gc_purpose-reason.
        SELECT reason AS key01, fica_reason AS fun01, is_noc AS fun02
          FROM zcd_ops_maprsn
          WHERE version = @iv_version
          ORDER BY reason
          INTO CORRESPONDING FIELDS OF TABLE @rt_entries.
      WHEN zif_cd_ops_postarea_types=>gc_purpose-pm_class.
        SELECT flow AS key01, pay_method AS key02, house_bank AS key03,
               method_class AS fun01, age_basis AS fun02, calendar AS fun03
          FROM zcd_ops_mappmc
          WHERE version = @iv_version
          ORDER BY flow, pay_method, house_bank
          INTO CORRESPONDING FIELDS OF TABLE @rt_entries.
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_map.
        SELECT scheme AS key01, code AS key02, family AS key03, sub_family AS key04, bank AS key05, flow AS key06,
               category AS fun01, rule_group AS fun02, exp_cdi AS fun03, pay_method AS fun04,
               posting_rule AS fun05, action AS fun06, disposition AS fun07
          FROM zcd_ops_mapbtm
          WHERE version = @iv_version
          ORDER BY scheme, code, family, sub_family, bank, flow
          INTO CORRESPONDING FIELDS OF TABLE @rt_entries.
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_role.
        SELECT usage AS key01, scope AS key02, scheme AS key03, code AS key04, family AS key05, sub_family AS key06,
               role AS fun01, compare_amount AS fun02
          FROM zcd_ops_mapbtr
          WHERE version = @iv_version
          ORDER BY usage, scope, scheme, code, family, sub_family
          INTO CORRESPONDING FIELDS OF TABLE @rt_entries.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_cd_ops_pamap_dao~insert_entries.
    DATA lt_reason TYPE tt_reason.
    DATA lt_class TYPE tt_class.
    DATA lt_map TYPE tt_map.
    DATA lt_role TYPE tt_role.
    DATA lv_table TYPE zif_ca_ops_cfg_types=>ty_name.

    LOOP AT it_entries ASSIGNING FIELD-SYMBOL(<ls_entry>).
      CASE iv_purpose.
        WHEN zif_cd_ops_postarea_types=>gc_purpose-reason.
          INSERT INITIAL LINE INTO TABLE lt_reason ASSIGNING FIELD-SYMBOL(<ls_reason>).
          fill_row( EXPORTING iv_purpose = iv_purpose iv_version = iv_version is_entry = <ls_entry>
                    CHANGING  cs_row     = <ls_reason> ).
        WHEN zif_cd_ops_postarea_types=>gc_purpose-pm_class.
          INSERT INITIAL LINE INTO TABLE lt_class ASSIGNING FIELD-SYMBOL(<ls_class>).
          fill_row( EXPORTING iv_purpose = iv_purpose iv_version = iv_version is_entry = <ls_entry>
                    CHANGING  cs_row     = <ls_class> ).
        WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_map.
          INSERT INITIAL LINE INTO TABLE lt_map ASSIGNING FIELD-SYMBOL(<ls_map>).
          fill_row( EXPORTING iv_purpose = iv_purpose iv_version = iv_version is_entry = <ls_entry>
                    CHANGING  cs_row     = <ls_map> ).
        WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_role.
          INSERT INITIAL LINE INTO TABLE lt_role ASSIGNING FIELD-SYMBOL(<ls_role>).
          fill_row( EXPORTING iv_purpose = iv_purpose iv_version = iv_version is_entry = <ls_entry>
                    CHANGING  cs_row     = <ls_role> ).
      ENDCASE.
    ENDLOOP.

    DATA(lv_failed) = abap_false.
    CASE iv_purpose.
      WHEN zif_cd_ops_postarea_types=>gc_purpose-reason.
        lv_table = zif_cd_ops_postarea_types=>gc_table-reason.
        INSERT zcd_ops_maprsn FROM TABLE @lt_reason.
        lv_failed = xsdbool( sy-subrc <> 0 ).
        rr_rows = NEW tt_reason( lt_reason ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-pm_class.
        lv_table = zif_cd_ops_postarea_types=>gc_table-pm_class.
        INSERT zcd_ops_mappmc FROM TABLE @lt_class.
        lv_failed = xsdbool( sy-subrc <> 0 ).
        rr_rows = NEW tt_class( lt_class ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_map.
        lv_table = zif_cd_ops_postarea_types=>gc_table-btc_map.
        INSERT zcd_ops_mapbtm FROM TABLE @lt_map.
        lv_failed = xsdbool( sy-subrc <> 0 ).
        rr_rows = NEW tt_map( lt_map ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_role.
        lv_table = zif_cd_ops_postarea_types=>gc_table-btc_role.
        INSERT zcd_ops_mapbtr FROM TABLE @lt_role.
        lv_failed = xsdbool( sy-subrc <> 0 ).
        rr_rows = NEW tt_role( lt_role ).
    ENDCASE.
    IF lv_failed = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH lv_table.
    ENDIF.
  ENDMETHOD.


  METHOD fill_row.
    DATA lv_position TYPE i.

    columns( EXPORTING iv_purpose = iv_purpose
             IMPORTING et_keys    = DATA(lt_keys)
                       et_results = DATA(lt_results) ).
    GET TIME STAMP FIELD DATA(lv_now).
    ASSIGN COMPONENT gc_column-version OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_version>).
    IF sy-subrc = 0.
      <lv_version> = iv_version.
    ENDIF.
    LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<lv_key>).
      lv_position = sy-tabix.
      ASSIGN COMPONENT lv_position OF STRUCTURE is_entry TO FIELD-SYMBOL(<lv_key_value>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT <lv_key> OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_key_target>).
      IF sy-subrc = 0.
        <lv_key_target> = <lv_key_value>.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_results ASSIGNING FIELD-SYMBOL(<lv_result>).
      lv_position = zif_cd_ops_postarea_types=>gc_key_count + sy-tabix.
      ASSIGN COMPONENT lv_position OF STRUCTURE is_entry TO FIELD-SYMBOL(<lv_result_value>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT <lv_result> OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_result_target>).
      IF sy-subrc = 0.
        <lv_result_target> = <lv_result_value>.
      ENDIF.
    ENDLOOP.
    ASSIGN COMPONENT gc_column-changed_by OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_by>).
    IF sy-subrc = 0.
      <lv_by> = sy-uname.
    ENDIF.
    ASSIGN COMPONENT gc_column-changed_at OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_at>).
    IF sy-subrc = 0.
      <lv_at> = lv_now.
    ENDIF.
    ASSIGN COMPONENT gc_column-local_changed OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_local>).
    IF sy-subrc = 0.
      <lv_local> = lv_now.
    ENDIF.
  ENDMETHOD.


  METHOD columns.
    CLEAR: et_keys, et_results.
    CASE iv_purpose.
      WHEN zif_cd_ops_postarea_types=>gc_purpose-reason.
        et_keys = VALUE #( ( gc_column-reason ) ).
        et_results = VALUE #( ( gc_column-fica_reason ) ( gc_column-is_noc ) ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-pm_class.
        et_keys = VALUE #( ( gc_column-flow ) ( gc_column-pay_method ) ( gc_column-house_bank ) ).
        et_results = VALUE #( ( gc_column-method_class ) ( gc_column-age_basis ) ( gc_column-calendar ) ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_map.
        et_keys = VALUE #( ( gc_column-scheme ) ( gc_column-code ) ( gc_column-family ) ( gc_column-sub_family )
                           ( gc_column-bank ) ( gc_column-flow ) ).
        et_results = VALUE #( ( gc_column-category ) ( gc_column-rule_group ) ( gc_column-exp_cdi )
                              ( gc_column-pay_method ) ( gc_column-posting_rule ) ( gc_column-action )
                              ( gc_column-disposition ) ).
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_role.
        et_keys = VALUE #( ( gc_column-usage ) ( gc_column-scope ) ( gc_column-scheme ) ( gc_column-code )
                           ( gc_column-family ) ( gc_column-sub_family ) ).
        et_results = VALUE #( ( gc_column-role ) ( gc_column-compare_amount ) ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
