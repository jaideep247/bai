*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_stmt_evidence.clas.abap
*& Purpose:
*& Statement evidence per bank key and statement date, built from the EBS
*& pipeline itself (no second definition): accounts of ZCD_EBS_ACCT, the
*& imported statements and entries of ZCL_CD_EBS_SRC_FEB (one FEBKO and one
*& FEBEP read, posting-area flags of EBS_FEB_POSTED_FIELDS), the payment
*& engine account scope of ZCL_CD_EBS_PE_SCOPE and the map disposition of
*& ZCL_CD_EBS_BTC_RESOLVER. Also the one definition of 'expected to post but
*& not posted' (IS_POSTING_OPEN) used by the EBS engine. Read-only.
*& Modification log:
*& 2026-11-07 | Initial version (BAI processing deadline, statement evidence for FMON).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS - statement evidence per bank and statement date</p>
"! An account counts as imported when FEBKO holds a statement of the date for its house bank
"! account (BUKRS / HBKID / HKTID), whatever its entries. Entries count only for statements in
"! the payment engine account scope (every entry an active ZCD_EBS_ACCT account, as in EBS).
"! A statement read that reaches the row cap marks every row TRUNCATED.
CLASS zcl_cd_ebs_stmt_evidence DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_stmt_evidence.

    "! Entry expected to post but not posted: posting state O (FEBEP posting-area flags not
    "! complete), the map row does not expect it to stay unposted (disposition NOT_POSTED) and,
    "! unless iv_count_blocked, the entry is not blocked (EBS reports a blocked entry as its own
    "! finding, so POSTING_INCOMPLETE leaves it out; file monitoring counts it - the file is
    "! not processed while it stays unposted)
    CLASS-METHODS is_posting_open
      IMPORTING
        is_line          TYPE zif_cd_ebs_types=>ty_line
        iv_count_blocked TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_open)   TYPE abap_bool.

  PRIVATE SECTION.
    "! Account of a requested bank: house bank account key and normalised bank key
    TYPES:
      BEGIN OF ty_account,
        bukrs    TYPE zif_cd_ebs_types=>ty_statement-bukrs,
        hbkid    TYPE zif_cd_ebs_types=>ty_statement-hbkid,
        hktid    TYPE zif_cd_ebs_types=>ty_statement-hktid,
        bank_key TYPE zif_cd_ebs_types=>ty_bank_key,
      END OF ty_account.
    TYPES tt_account TYPE HASHED TABLE OF ty_account WITH UNIQUE KEY bukrs hbkid hktid.

    "! Statement kept for the evidence: its bank and date
    TYPES:
      BEGIN OF ty_kept,
        stmt_key  TYPE zif_cd_ebs_types=>ty_stmt_key,
        bank_key  TYPE zif_cd_ebs_types=>ty_bank_key,
        stmt_date TYPE d,
      END OF ty_kept.
    TYPES tt_kept TYPE HASHED TABLE OF ty_kept WITH UNIQUE KEY stmt_key.

    "! Imported account per bank and date (distinct)
    TYPES:
      BEGIN OF ty_imported,
        bank_key  TYPE zif_cd_ebs_types=>ty_bank_key,
        stmt_date TYPE d,
        bukrs     TYPE zif_cd_ebs_types=>ty_statement-bukrs,
        hbkid     TYPE zif_cd_ebs_types=>ty_statement-hbkid,
        hktid     TYPE zif_cd_ebs_types=>ty_statement-hktid,
      END OF ty_imported.
    TYPES tt_imported TYPE HASHED TABLE OF ty_imported WITH UNIQUE KEY bank_key stmt_date bukrs hbkid hktid.

    CLASS-METHODS normalized
      IMPORTING
        iv_bank_key        TYPE zif_cd_ebs_types=>ty_bank_key
      RETURNING
        VALUE(rv_bank_key) TYPE zif_cd_ebs_types=>ty_bank_key.

    "! FEBKO selection: the company codes and house banks of the accounts, the date range
    CLASS-METHODS selection
      IMPORTING
        it_accounts         TYPE tt_account
        it_dates            TYPE zif_cd_ebs_stmt_evidence=>tt_date
      RETURNING
        VALUE(rs_selection) TYPE zif_cd_ebs_feb_dao=>ty_selection.

ENDCLASS.



CLASS zcl_cd_ebs_stmt_evidence IMPLEMENTATION.

  METHOD is_posting_open.
    rv_open = xsdbool( is_line-posting_state = zif_cd_ebs_types=>gc_posting_state-open
                       AND is_line-not_posted = abap_false
                       AND ( is_line-blocked = abap_false OR iv_count_blocked = abap_true ) ).
  ENDMETHOD.


  METHOD zif_cd_ebs_stmt_evidence~read.
    DATA lt_banks TYPE zif_cd_ebs_stmt_evidence=>tt_bank_key.
    DATA lt_accounts TYPE tt_account.
    DATA lt_kept TYPE tt_kept.
    DATA lt_imported TYPE tt_imported.
    DATA lt_drop TYPE SORTED TABLE OF zif_cd_ebs_types=>ty_stmt_key WITH UNIQUE KEY table_line.
    FIELD-SYMBOLS <ls_evidence> TYPE zif_cd_ebs_stmt_evidence=>ty_evidence.

    LOOP AT is_request-bank_keys ASSIGNING FIELD-SYMBOL(<lv_bank>).
      INSERT normalized( <lv_bank> ) INTO TABLE lt_banks.
    ENDLOOP.
    IF lt_banks IS INITIAL OR is_request-stmt_dates IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_cfg) = zcl_cd_ebs_factory=>get_cfg_dao( ).
    DATA(lt_all_accounts) = lo_cfg->get_accounts( ).
    LOOP AT lt_all_accounts ASSIGNING FIELD-SYMBOL(<ls_account>) WHERE active = abap_true.
      DATA(lv_bank_key) = normalized( <ls_account>-bank_key ).
      IF line_exists( lt_banks[ table_line = lv_bank_key ] ).
        INSERT VALUE #( bukrs    = <ls_account>-bukrs
                        hbkid    = <ls_account>-hbkid
                        hktid    = <ls_account>-hktid
                        bank_key = lv_bank_key ) INTO TABLE lt_accounts.
      ENDIF.
    ENDLOOP.

    " One row per requested bank and date, also when nothing was imported (condition: not imported)
    LOOP AT lt_banks ASSIGNING FIELD-SYMBOL(<lv_requested>).
      DATA(lv_expected) = REDUCE i( INIT n = 0
                                    FOR ls_acc IN lt_accounts WHERE ( bank_key = <lv_requested> )
                                    NEXT n = n + 1 ).
      LOOP AT is_request-stmt_dates ASSIGNING FIELD-SYMBOL(<lv_date>).
        INSERT VALUE #( bank_key          = <lv_requested>
                        stmt_date         = <lv_date>
                        accounts_expected = lv_expected ) INTO TABLE rt_evidence.
      ENDLOOP.
    ENDLOOP.
    IF lt_accounts IS INITIAL.
      RETURN.
    ENDIF.

    " One FEBKO read and one FEBEP read: a single package of at most MAX_ROWS statements
    DATA(lv_cap) = nmax( val1 = is_request-max_rows val2 = 1 ).
    DATA(ls_package) = NEW zcl_cd_ebs_src_feb( is_selection    = selection( it_accounts = lt_accounts
                                                                            it_dates    = is_request-stmt_dates )
                                               iv_package_size = lv_cap )->zif_cd_ebs_source~next_package( ).
    DATA(lv_truncated) = xsdbool( lines( ls_package-statements ) >= lv_cap ).
    DATA(lv_posting_known) = xsdbool( zcl_cd_ebs_src_feb=>posted_fields( ) IS NOT INITIAL ).

    LOOP AT ls_package-statements ASSIGNING FIELD-SYMBOL(<ls_statement>).
      READ TABLE lt_accounts ASSIGNING FIELD-SYMBOL(<ls_own>)
           WITH TABLE KEY bukrs = <ls_statement>-bukrs hbkid = <ls_statement>-hbkid hktid = <ls_statement>-hktid.
      IF sy-subrc <> 0 OR NOT line_exists( is_request-stmt_dates[ table_line = <ls_statement>-stmt_date ] ).
        INSERT <ls_statement>-stmt_key INTO TABLE lt_drop.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( stmt_key  = <ls_statement>-stmt_key
                      bank_key  = <ls_own>-bank_key
                      stmt_date = <ls_statement>-stmt_date ) INTO TABLE lt_kept.
      INSERT VALUE #( bank_key  = <ls_own>-bank_key
                      stmt_date = <ls_statement>-stmt_date
                      bukrs     = <ls_statement>-bukrs
                      hbkid     = <ls_statement>-hbkid
                      hktid     = <ls_statement>-hktid ) INTO TABLE lt_imported.
      READ TABLE rt_evidence ASSIGNING <ls_evidence>
           WITH TABLE KEY bank_key = <ls_own>-bank_key stmt_date = <ls_statement>-stmt_date.
      IF sy-subrc = 0.
        <ls_evidence>-statements += 1.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_drop ASSIGNING FIELD-SYMBOL(<lv_drop>).
      DELETE ls_package-statements WHERE stmt_key = <lv_drop>.
      DELETE ls_package-lines USING KEY stmt WHERE stmt_key = <lv_drop>.
    ENDLOOP.
    LOOP AT lt_imported ASSIGNING FIELD-SYMBOL(<ls_imported>).
      READ TABLE rt_evidence ASSIGNING <ls_evidence>
           WITH TABLE KEY bank_key = <ls_imported>-bank_key stmt_date = <ls_imported>-stmt_date.
      IF sy-subrc = 0.
        <ls_evidence>-accounts_imported += 1.
      ENDIF.
    ENDLOOP.

    " Same scope as EBS: a statement counts only when every entry carries a payment engine account
    NEW zcl_cd_ebs_pe_scope( lt_all_accounts )->remove_out_of_scope( CHANGING cs_package = ls_package ).
    LOOP AT lt_kept ASSIGNING FIELD-SYMBOL(<ls_kept>).
      IF NOT line_exists( ls_package-statements[ stmt_key = <ls_kept>-stmt_key ] ).
        READ TABLE rt_evidence ASSIGNING <ls_evidence>
             WITH TABLE KEY bank_key = <ls_kept>-bank_key stmt_date = <ls_kept>-stmt_date.
        IF sy-subrc = 0.
          <ls_evidence>-out_of_scope += 1.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " Map disposition (NOT_POSTED) and blocking of the entries, as in the EBS run
    DATA(lo_resolver) = NEW zcl_cd_ebs_btc_resolver(
      it_map          = lo_cfg->get_btc_map( )
      it_patterns     = lo_cfg->get_flow_patterns( )
      it_accounts     = lt_all_accounts
      iv_bai_fallback = xsdbool( zcl_cd_ops_factory=>get_params( )->get_param(
                                   iv_name    = zif_cd_ebs_types=>gc_param-camt_bai_fallback
                                   iv_default = zif_cd_ebs_types=>gc_param_default-camt_bai_fallback )
                                 = abap_true ) ).
    lo_resolver->enrich_statements( CHANGING ct_statements = ls_package-statements ).
    lo_resolver->resolve( EXPORTING it_statements = ls_package-statements
                          CHANGING  ct_lines      = ls_package-lines ).

    LOOP AT ls_package-lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      READ TABLE lt_kept ASSIGNING <ls_kept> WITH TABLE KEY stmt_key = <ls_line>-stmt_key.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE rt_evidence ASSIGNING <ls_evidence>
           WITH TABLE KEY bank_key = <ls_kept>-bank_key stmt_date = <ls_kept>-stmt_date.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      <ls_evidence>-lines_total += 1.
      IF is_posting_open( is_line = <ls_line> iv_count_blocked = abap_true ) = abap_true.
        <ls_evidence>-lines_open += 1.
      ENDIF.
    ENDLOOP.

    LOOP AT rt_evidence ASSIGNING <ls_evidence>.
      <ls_evidence>-posting_known = lv_posting_known.
      <ls_evidence>-truncated     = lv_truncated.
    ENDLOOP.
  ENDMETHOD.


  METHOD normalized.
    rv_bank_key = to_upper( condense( iv_bank_key ) ).
  ENDMETHOD.


  METHOD selection.
    LOOP AT it_accounts ASSIGNING FIELD-SYMBOL(<ls_account>).
      IF NOT line_exists( rs_selection-bukrs[ low = <ls_account>-bukrs ] ).
        INSERT VALUE #( sign   = zif_cd_ops_types=>gc_range-sign_include
                        option = zif_cd_ops_types=>gc_range-option_equal
                        low    = <ls_account>-bukrs ) INTO TABLE rs_selection-bukrs.
      ENDIF.
      IF NOT line_exists( rs_selection-hbkid[ low = <ls_account>-hbkid ] ).
        INSERT VALUE #( sign   = zif_cd_ops_types=>gc_range-sign_include
                        option = zif_cd_ops_types=>gc_range-option_equal
                        low    = <ls_account>-hbkid ) INTO TABLE rs_selection-hbkid.
      ENDIF.
    ENDLOOP.
    rs_selection-date_from = it_dates[ 1 ].
    rs_selection-date_to   = it_dates[ lines( it_dates ) ].
  ENDMETHOD.

ENDCLASS.
