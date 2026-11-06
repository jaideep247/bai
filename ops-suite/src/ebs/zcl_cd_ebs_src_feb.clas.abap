*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_src_feb.clas.abap
*& Purpose:
*& Source of imported statements: reads FEBKO headers once, then hands them to
*& the engine in packages of N statements with their FEBEP items, mapped to the
*& format-neutral model. Statement keys FEB<kukey>, line numbers = ESNUM.
*& Debit/credit indicators and the BAI code field are parameters (VERIFY-DDIC).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - source FEBKO/FEBEP</p>
CLASS zcl_cd_ebs_src_feb DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_source.

    METHODS constructor
      IMPORTING
        is_selection    TYPE zif_cd_ebs_feb_dao=>ty_selection
        iv_package_size TYPE i DEFAULT 50.

  PRIVATE SECTION.
    DATA ms_selection    TYPE zif_cd_ebs_feb_dao=>ty_selection.
    DATA mv_package_size TYPE i.
    DATA mt_headers      TYPE zif_cd_ebs_feb_dao=>tt_header.
    DATA mv_loaded       TYPE abap_bool.
    DATA mv_next         TYPE i VALUE 1.
    DATA mv_debit_ind    TYPE c LENGTH 1.
    DATA mv_credit_ind   TYPE c LENGTH 1.

    METHODS map_statement
      IMPORTING
        is_header           TYPE zif_cd_ebs_feb_dao=>ty_header
      RETURNING
        VALUE(rs_statement) TYPE zif_cd_ebs_types=>ty_statement.

    METHODS map_line
      IMPORTING
        is_item        TYPE zif_cd_ebs_feb_dao=>ty_item
        iv_currency    TYPE zif_cd_ops_types=>ty_currency
      RETURNING
        VALUE(rs_line) TYPE zif_cd_ebs_types=>ty_line.

    METHODS signed
      IMPORTING
        iv_amount        TYPE zif_cd_ops_types=>ty_amount
        iv_indicator     TYPE char1
      RETURNING
        VALUE(rv_amount) TYPE zif_cd_ops_types=>ty_amount.

ENDCLASS.



CLASS zcl_cd_ebs_src_feb IMPLEMENTATION.

  METHOD constructor.
    ms_selection    = is_selection.
    mv_package_size = COND #( WHEN iv_package_size > 0 THEN iv_package_size ELSE 50 ).
  ENDMETHOD.


  METHOD zif_cd_ebs_source~next_package.
    DATA lt_kukey TYPE zif_cd_ebs_feb_dao=>tt_kukey.

    IF mv_loaded = abap_false.
      DATA(lo_store) = zcl_cd_ops_factory=>get_store( ).
      mv_debit_ind  = lo_store->get_param( iv_name    = zif_cd_ebs_types=>gc_param-feb_debit_ind
                                          iv_default = zif_cd_ebs_types=>gc_param_default-feb_debit_ind ).
      mv_credit_ind = lo_store->get_param( iv_name    = zif_cd_ebs_types=>gc_param-feb_credit_ind
                                          iv_default = zif_cd_ebs_types=>gc_param_default-feb_credit_ind ).
      mt_headers = zcl_cd_ebs_factory=>get_feb_dao( )->get_headers( ms_selection ).
      mv_loaded = abap_true.
    ENDIF.

    LOOP AT mt_headers INTO DATA(ls_header) FROM mv_next.
      IF lines( rs_package-statements ) >= mv_package_size.
        EXIT.
      ENDIF.
      INSERT map_statement( ls_header ) INTO TABLE rs_package-statements.
      INSERT ls_header-kukey INTO TABLE lt_kukey.
      mv_next += 1.
    ENDLOOP.
    IF lt_kukey IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_items) = zcl_cd_ebs_factory=>get_feb_dao( )->get_items( lt_kukey ).
    LOOP AT lt_items INTO DATA(ls_item).
      DATA(lv_currency) = VALUE #( mt_headers[ kukey = ls_item-kukey ]-waers OPTIONAL ).
      INSERT map_line( is_item = ls_item iv_currency = CONV #( lv_currency ) ) INTO TABLE rs_package-lines.
    ENDLOOP.
  ENDMETHOD.


  METHOD map_statement.
    rs_statement-stmt_key       = zif_cd_ebs_types=>gc_feb_stmt_prefix && |{ is_header-kukey }|.
    rs_statement-source         = zif_cd_ebs_types=>gc_source-feb.
    rs_statement-kukey          = is_header-kukey.
    rs_statement-bukrs          = is_header-bukrs.
    rs_statement-hbkid          = is_header-hbkid.
    rs_statement-hktid          = is_header-hktid.
    rs_statement-currency       = is_header-waers.
    rs_statement-stmt_id        = |{ is_header-hbkid }/{ is_header-hktid }/{ is_header-aznum }|.
    rs_statement-stmt_no        = is_header-aznum.
    rs_statement-stmt_date      = is_header-azdat.
    rs_statement-has_opening    = abap_true.
    rs_statement-opening_bal    = signed( iv_amount = is_header-ssbtr iv_indicator = is_header-ssvoz ).
    rs_statement-has_closing    = abap_true.
    rs_statement-closing_bal    = signed( iv_amount = is_header-esbtr iv_indicator = is_header-esvoz ).
    rs_statement-declared_count = COND #( WHEN is_header-anzes > 0 THEN is_header-anzes ELSE -1 ).
  ENDMETHOD.


  METHOD map_line.
    rs_line-stmt_key     = zif_cd_ebs_types=>gc_feb_stmt_prefix && |{ is_item-kukey }|.
    rs_line-line_no      = is_item-esnum.
    rs_line-kukey        = is_item-kukey.
    rs_line-esnum        = is_item-esnum.
    rs_line-cdi          = COND #( WHEN is_item-epvoz = mv_credit_ind THEN zif_cd_ebs_types=>gc_cdi-credit
                                   ELSE zif_cd_ebs_types=>gc_cdi-debit ).
    rs_line-amount       = abs( is_item-kwbtr ).
    rs_line-currency     = COND #( WHEN is_item-kwaer IS NOT INITIAL THEN is_item-kwaer ELSE iv_currency ).
    rs_line-booking_date = is_item-budat.
    rs_line-value_date   = is_item-valut.
    rs_line-reference    = is_item-chect.
    rs_line-xblnr        = is_item-xblnr.
    rs_line-belnr        = is_item-belnr.
    rs_line-gjahr        = is_item-gjahr.
    rs_line-posting_rule = is_item-vgint.

    IF is_item-vorgc IS NOT INITIAL.
      rs_line-scheme   = zif_cd_ebs_types=>gc_scheme-bai2.
      rs_line-btc_code = is_item-vorgc.
      RETURN.
    ENDIF.

    " CAMT import: external transaction holds Domain/Family/Sub-family (separator + - or /)
    DATA(lv_code) = translate( val = condense( CONV string( is_item-vgext ) ) from = `+/` to = `--` ).
    SPLIT lv_code AT '-' INTO DATA(lv_domain) DATA(lv_family) DATA(lv_subfamily).
    IF lv_family IS NOT INITIAL.
      rs_line-scheme    = zif_cd_ebs_types=>gc_scheme-iso.
      rs_line-domain    = lv_domain.
      rs_line-family    = lv_family.
      rs_line-subfamily = lv_subfamily.
      rs_line-btc_code  = COND #( WHEN lv_subfamily IS NOT INITIAL THEN |{ lv_domain }-{ lv_family }-{ lv_subfamily }|
                                  ELSE |{ lv_domain }-{ lv_family }| ).
    ELSE.
      rs_line-scheme     = COND #( WHEN strlen( lv_code ) = 3 AND lv_code CO zif_cd_ebs_types=>gc_digits
                                   THEN zif_cd_ebs_types=>gc_scheme-bai2
                                   ELSE zif_cd_ebs_types=>gc_scheme-prtry ).
      rs_line-btc_code   = lv_code.
      rs_line-prtry_code = lv_code.
    ENDIF.
  ENDMETHOD.


  METHOD signed.
    rv_amount = COND #( WHEN iv_indicator = mv_debit_ind THEN - abs( iv_amount ) ELSE abs( iv_amount ) ).
  ENDMETHOD.

ENDCLASS.
