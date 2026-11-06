*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_feb_dao.clas.abap
*& Purpose:
*& SQL for imported bank statements: FEBKO headers in scope, FEBEP items per
*& statement, the previous statement of a house bank account and the
*& duplicate check. Read-only. Field list limited to what the suite uses.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | Audit A14: get_recent_items for rule R22.
*& 2026-11-06 | Performance fix 2: get_recent_items returns FEBKO-AZDAT (one read per account, window in ABAP).
*& 2026-11-06 | Performance fix 3: get_items reads return reason and posting-area flags in the same FEBEP pass
*&            | (names DDIC-validated as before in the SAP DAO).
*& 2026-11-06 | Return reason correction: no FEBEP reason field (FEBEP carries no return reason).
*& 2026-11-06 | Modern-syntax sweep: unchained TYPES.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - FEBKO/FEBEP repository</p>
CLASS zcl_cd_ebs_feb_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_feb_dao.

  PRIVATE SECTION.
    "! Item read (fix 3: a dynamic field list so the configured fields join the same statement)
    CONSTANTS gc_febep_table TYPE string VALUE `FEBEP`.
    CONSTANTS gc_item_fields TYPE string
      VALUE `kukey, esnum, vorgc, vgext, vgint, epvoz, kwbtr, kwaer, budat, valut, chect, xblnr, belnr, gjahr`.
    CONSTANTS gc_sql_separator TYPE string VALUE `, `.
    "! Posting-area flags: alias FLAG<n>, at most four (components FLAG1..FLAG4 of ty_item_row)
    CONSTANTS gc_sql_as_flag TYPE string VALUE ` AS flag`.
    CONSTANTS gc_max_posting_flags TYPE i VALUE 4.
    "! Component name prefix of the flags in ty_item_row (FLAG1..FLAG4)
    CONSTANTS gc_flag_prefix TYPE string VALUE `FLAG`.

    TYPES BEGIN OF ty_item_row.
        INCLUDE TYPE zif_cd_ebs_feb_dao=>ty_item.
    TYPES:
        flag1 TYPE c LENGTH 1,
        flag2 TYPE c LENGTH 1,
        flag3 TYPE c LENGTH 1,
        flag4 TYPE c LENGTH 1,
      END OF ty_item_row.

    "! Field list of the item read: item fields and the posting-area flags (each must be
    "! a FEBEP field, else raises)
    METHODS item_select
      IMPORTING
        is_extras        TYPE zif_cd_ebs_feb_dao=>ty_item_extras
      RETURNING
        VALUE(rv_select) TYPE string
      RAISING
        zcx_cd_ops_error.

    METHODS field_exists
      IMPORTING
        iv_table      TYPE string
        iv_field      TYPE string
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_ebs_feb_dao IMPLEMENTATION.

  METHOD zif_cd_ebs_feb_dao~get_headers.
    " VERIFY-DDIC: FEBKO-SSVOZ, ESVOZ (balance debit/credit), ANZES (number of items), EFART
    SELECT kukey, bukrs, hbkid, hktid, aznum, azdat, waers, ssbtr, ssvoz, esbtr, esvoz, anzes, efart
      FROM febko
      WHERE bukrs IN @is_selection-bukrs
        AND hbkid IN @is_selection-hbkid
        AND kukey IN @is_selection-kukey
        AND azdat BETWEEN @is_selection-date_from AND @is_selection-date_to
      ORDER BY bukrs, hbkid, hktid, azdat, aznum
      INTO CORRESPONDING FIELDS OF TABLE @rt_headers.
  ENDMETHOD.


  METHOD zif_cd_ebs_feb_dao~get_items.
    DATA lt_rows TYPE STANDARD TABLE OF ty_item_row WITH EMPTY KEY.
    DATA ls_item TYPE zif_cd_ebs_feb_dao=>ty_item.
    CHECK it_kukey IS NOT INITIAL.
    " VERIFY-DDIC: FEBEP-VORGC (BAI type code used by the legacy validators), VGEXT, EPVOZ, KWAER
    " Fix 3: one FEBEP pass for items and posting-area flags (FEBEP has no return reason)
    DATA(lv_select) = item_select( is_extras ).
    DATA(lv_flags) = lines( is_extras-posted_fields ).
    TRY.
        SELECT (lv_select)
          FROM febep
          FOR ALL ENTRIES IN @it_kukey
          WHERE kukey = @it_kukey-table_line
          INTO CORRESPONDING FIELDS OF TABLE @lt_rows.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e012(zcd_ops) WITH gc_febep_table
          EXPORTING
            previous = lx_sql.
    ENDTRY.
    SORT lt_rows BY kukey esnum.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      ls_item = CORRESPONDING #( <ls_row> ).
      IF lv_flags > 0.
        " Posted only when every configured posting area is complete
        ls_item-posted = abap_true.
        DO lv_flags TIMES.
          ASSIGN COMPONENT |{ gc_flag_prefix }{ sy-index }| OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_flag>).
          IF sy-subrc <> 0.
            ls_item-posted = abap_false.
          ELSEIF <lv_flag> <> abap_true.
            ls_item-posted = abap_false.
          ENDIF.
        ENDDO.
      ENDIF.
      INSERT ls_item INTO TABLE rt_items.
    ENDLOOP.
  ENDMETHOD.


  METHOD item_select.
    rv_select = gc_item_fields.
    " Operating model: VERIFY-SE11 FEBEP-VB1OK / VB2OK (posting area 1 / 2 completed) are the
    " delivered default of EBS_FEB_POSTED_FIELDS. Every name is checked before it reaches the statement.
    IF lines( is_extras-posted_fields ) > gc_max_posting_flags.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e051(zcd_ops) WITH lines( is_extras-posted_fields ) zif_cd_ebs_types=>gc_param-feb_posted_fields.
    ENDIF.
    DATA(lv_flag) = 0.
    LOOP AT is_extras-posted_fields ASSIGNING FIELD-SYMBOL(<lv_name>).
      lv_flag += 1.
      DATA(lv_field) = to_upper( condense( <lv_name> ) ).
      IF field_exists( iv_table = gc_febep_table iv_field = lv_field ) = abap_false.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e051(zcd_ops) WITH lv_field zif_cd_ebs_types=>gc_param-feb_posted_fields.
      ENDIF.
      rv_select = |{ rv_select }{ gc_sql_separator }{ lv_field }{ gc_sql_as_flag }{ lv_flag }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD field_exists.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = iv_table
      RECEIVING
        p_descr_ref    = lo_descr
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    TRY.
        lo_struct ?= lo_descr.
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.
    rv_yes = xsdbool( line_exists( lo_struct->components[ name = iv_field ] ) ).
  ENDMETHOD.


  METHOD zif_cd_ebs_feb_dao~get_prior_header.
    DATA lt_headers TYPE zif_cd_ebs_feb_dao=>tt_header.
    SELECT kukey, bukrs, hbkid, hktid, aznum, azdat, waers, ssbtr, ssvoz, esbtr, esvoz, anzes, efart
      FROM febko
      WHERE bukrs = @iv_bukrs
        AND hbkid = @iv_hbkid
        AND hktid = @iv_hktid
        AND ( azdat < @iv_before
           OR ( azdat = @iv_before AND aznum < @iv_aznum ) )
      ORDER BY azdat DESCENDING, aznum DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_headers
      UP TO 1 ROWS.
    rs_header = VALUE #( lt_headers[ 1 ] OPTIONAL ).
  ENDMETHOD.


  METHOD zif_cd_ebs_feb_dao~get_recent_items.
    " A14: history of the account for the cross-statement duplicate rule R22.
    " VERIFY-DDIC: FEBEP-VORGC / VGEXT / EPVOZ as in get_items
    SELECT p~kukey, p~esnum, p~vorgc, p~vgext, p~vgint, p~epvoz, p~kwbtr, p~kwaer, p~budat, p~valut,
           p~chect, p~xblnr, p~belnr, p~gjahr, k~azdat
      FROM febep AS p
      INNER JOIN febko AS k ON k~kukey = p~kukey
      WHERE k~bukrs = @iv_bukrs
        AND k~hbkid = @iv_hbkid
        AND k~hktid = @iv_hktid
        AND k~azdat BETWEEN @iv_from AND @iv_to
      ORDER BY p~kukey, p~esnum
      INTO CORRESPONDING FIELDS OF TABLE @rt_items.
  ENDMETHOD.


  METHOD zif_cd_ebs_feb_dao~statement_exists.
    SELECT SINGLE @abap_true
      FROM febko
      WHERE bukrs = @iv_bukrs
        AND hbkid = @iv_hbkid
        AND hktid = @iv_hktid
        AND aznum = @iv_aznum
        AND azdat = @iv_azdat
      INTO @rv_exists.
  ENDMETHOD.

ENDCLASS.
