*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_pe_scope.clas.abap
*& Purpose:
*& Payment engine account scope (user decision 2026-11-06). FEBEP-XBLNR holds
*& bank text + payment engine bank account (10 characters) + counter; the
*& account is the XBLNR without its leading letters, condensed, upper case,
*& first 10 characters. An imported statement (FEB source) is validated only
*& when every one of its lines carries an active configured account
*& (ZCD_EBS_ACCT-ACCOUNT_NO, compared condensed and in upper case); any other
*& statement - a mixed one, one with a blank or unparseable XBLNR, one without
*& lines - is out of scope: removed from the package with its lines and
*& counted, never a finding. Bank file statements (no XBLNR before import) are
*& not scoped here. Pure logic over configuration passed in; no SQL.
*& Modification log:
*& 2026-11-06 | Initial version (payment engine account scope, user decision).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - payment engine account scope</p>
CLASS zcl_cd_ebs_pe_scope DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Active configured payment engine accounts (ZCD_EBS_ACCT, ACCOUNT_NO); inactive rows
    "! and rows without an account number are ignored
    METHODS constructor
      IMPORTING
        it_accounts TYPE zif_cd_ebs_types=>tt_account_cfg.

    "! Payment engine bank account of a statement line: XBLNR without its leading bank text
    "! (ZIF_CD_EBS_TYPES=>GC_PE_ACCOUNT-BANK_TEXT_PCRE), condensed, upper case, first
    "! GC_PE_ACCOUNT-LENGTH characters. Blank when nothing follows the bank text.
    CLASS-METHODS pe_account_from_xblnr
      IMPORTING
        iv_xblnr          TYPE zif_cd_ebs_types=>ty_xblnr
      RETURNING
        VALUE(rv_account) TYPE zif_cd_ebs_types=>ty_pe_account.

    "! Is the account an active configured payment engine account
    METHODS is_pe_account
      IMPORTING
        iv_account    TYPE zif_cd_ebs_types=>ty_pe_account
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    "! Removes the out-of-scope imported statements (FEB source) of the package with their
    "! lines and returns their number. In scope: at least one line and every line's account
    "! an active configured payment engine account.
    METHODS remove_out_of_scope
      CHANGING
        cs_package      TYPE zif_cd_ebs_types=>ty_package
      RETURNING
        VALUE(rv_count) TYPE i.

  PRIVATE SECTION.
    TYPES tt_account TYPE HASHED TABLE OF zif_cd_ebs_types=>ty_text35 WITH UNIQUE KEY table_line.
    TYPES tt_stmt_key TYPE HASHED TABLE OF zif_cd_ebs_types=>ty_stmt_key WITH UNIQUE KEY table_line.

    "! Condensed, upper-case ACCOUNT_NO of the active rows
    DATA mt_accounts TYPE tt_account.

    METHODS statement_in_scope
      IMPORTING
        iv_stmt_key   TYPE zif_cd_ebs_types=>ty_stmt_key
        it_lines      TYPE zif_cd_ebs_types=>tt_line
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_ebs_pe_scope IMPLEMENTATION.

  METHOD constructor.
    LOOP AT it_accounts ASSIGNING FIELD-SYMBOL(<ls_account>) WHERE active = abap_true.
      DATA(lv_account) = CONV zif_cd_ebs_types=>ty_text35( to_upper( condense( <ls_account>-account_no ) ) ).
      IF lv_account IS NOT INITIAL.
        " Two rows with the same account number are one payment engine account
        INSERT lv_account INTO TABLE mt_accounts.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD pe_account_from_xblnr.
    DATA(lv_rest) = to_upper( condense( replace( val  = CONV string( iv_xblnr )
                                                 pcre = zif_cd_ebs_types=>gc_pe_account-bank_text_pcre
                                                 with = `` ) ) ).
    rv_account = substring( val = lv_rest
                            len = nmin( val1 = strlen( lv_rest ) val2 = zif_cd_ebs_types=>gc_pe_account-length ) ).
  ENDMETHOD.


  METHOD is_pe_account.
    rv_yes = xsdbool( iv_account IS NOT INITIAL
                      AND line_exists( mt_accounts[ table_line = CONV zif_cd_ebs_types=>ty_text35( iv_account ) ] ) ).
  ENDMETHOD.


  METHOD remove_out_of_scope.
    DATA lt_out TYPE tt_stmt_key.

    LOOP AT cs_package-statements ASSIGNING FIELD-SYMBOL(<ls_statement>)
         WHERE source = zif_cd_ebs_types=>gc_source-feb.
      IF statement_in_scope( iv_stmt_key = <ls_statement>-stmt_key it_lines = cs_package-lines ) = abap_false.
        INSERT <ls_statement>-stmt_key INTO TABLE lt_out.
      ENDIF.
    ENDLOOP.
    rv_count = lines( lt_out ).
    IF rv_count = 0.
      RETURN.
    ENDIF.
    LOOP AT lt_out ASSIGNING FIELD-SYMBOL(<lv_out>).
      DELETE cs_package-statements WHERE stmt_key = <lv_out>.
      DELETE cs_package-lines USING KEY stmt WHERE stmt_key = <lv_out>.
    ENDLOOP.
  ENDMETHOD.


  METHOD statement_in_scope.
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>) USING KEY stmt WHERE stmt_key = iv_stmt_key.
      rv_yes = abap_true.
      IF is_pe_account( pe_account_from_xblnr( <ls_line>-xblnr ) ) = abap_false.
        rv_yes = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
