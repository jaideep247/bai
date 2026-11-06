*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_btc_resolver.clas.abap
*& Purpose:
*& Maps every statement line to a semantic category and rule group through
*& ZCD_BTC_MAP and derives the flow (XBLNR pattern, else account default).
*& An unmapped or deactivated code is blocked with an R14 finding: nothing is
*& ever left to post to suspense. Pure logic over configuration passed in.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A25: imported statement gets the account number of its house bank account.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - BTC resolver (zero suspense)</p>
CLASS zcl_cd_ebs_btc_resolver DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_rule_unmapped TYPE zif_cd_ops_types=>ty_rule_id VALUE 'R14'.
    CONSTANTS gc_issuer_bai TYPE zif_cd_ebs_types=>ty_text35 VALUE '*BAI*'.

    "! @parameter iv_bai_fallback | CAMT proprietary BAI type codes reuse BAI2 map rows
    METHODS constructor
      IMPORTING
        it_map          TYPE zif_cd_ebs_types=>tt_btc_map
        it_patterns     TYPE zif_cd_ebs_types=>tt_flow_pattern
        it_accounts     TYPE zif_cd_ebs_types=>tt_account_cfg
        iv_bai_fallback TYPE abap_bool DEFAULT abap_true.

    "! Bank key and default flow from ZCD_EBS_ACCT (house bank account or account number)
    METHODS enrich_statements
      CHANGING
        ct_statements TYPE zif_cd_ebs_types=>tt_statement.

    METHODS resolve
      IMPORTING
        it_statements      TYPE zif_cd_ebs_types=>tt_statement
      CHANGING
        ct_lines           TYPE zif_cd_ebs_types=>tt_line
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

  PRIVATE SECTION.
    "! A proprietary BAI code: three digits (the field may carry trailing blanks)
    CONSTANTS gc_digits_or_blank TYPE string VALUE `0123456789 `.
    TYPES tt_map_hash TYPE HASHED TABLE OF zif_cd_ebs_types=>ty_btc_map
      WITH UNIQUE KEY scheme btc_code bank_key flow_type.
    TYPES tt_stmt_hash TYPE HASHED TABLE OF zif_cd_ebs_types=>ty_statement
      WITH UNIQUE KEY stmt_key.

    DATA mt_map          TYPE tt_map_hash.
    DATA mt_patterns     TYPE zif_cd_ebs_types=>tt_flow_pattern.
    DATA mt_accounts     TYPE zif_cd_ebs_types=>tt_account_cfg.
    DATA mv_bai_fallback TYPE abap_bool.

    METHODS find_account
      IMPORTING
        is_statement      TYPE zif_cd_ebs_types=>ty_statement
      RETURNING
        VALUE(rs_account) TYPE zif_cd_ebs_types=>ty_account_cfg.

    METHODS derive_flow
      IMPORTING
        is_line        TYPE zif_cd_ebs_types=>ty_line
        is_statement   TYPE zif_cd_ebs_types=>ty_statement
      RETURNING
        VALUE(rv_flow) TYPE zif_cd_ebs_types=>ty_flow.

    "! Bank row before blank-bank row; flow row before '*' row
    METHODS lookup
      IMPORTING
        iv_scheme      TYPE zif_cd_ebs_types=>ty_scheme
        iv_code        TYPE zif_cd_ebs_types=>ty_btc_code
        iv_bank_key    TYPE zif_cd_ebs_types=>ty_bank_key
        iv_flow        TYPE zif_cd_ebs_types=>ty_flow
      RETURNING
        VALUE(rs_map)  TYPE zif_cd_ebs_types=>ty_btc_map.

    "! Exact code, ISO family row, then proprietary code (BAI2 first when allowed)
    METHODS find_mapping
      IMPORTING
        is_line       TYPE zif_cd_ebs_types=>ty_line
        iv_bank_key   TYPE zif_cd_ebs_types=>ty_bank_key
      RETURNING
        VALUE(rs_map) TYPE zif_cd_ebs_types=>ty_btc_map.

    METHODS is_bai_code
      IMPORTING
        is_line       TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rv_bai) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_ebs_btc_resolver IMPLEMENTATION.

  METHOD constructor.
    LOOP AT it_map INTO DATA(ls_map).
      " A blank flow in customizing means 'any flow'
      IF ls_map-flow_type IS INITIAL.
        ls_map-flow_type = zif_cd_ebs_types=>gc_flow-any.
      ENDIF.
      " Duplicate keys in customizing: first row wins (table key prevents it in SM30)
      INSERT ls_map INTO TABLE mt_map.
    ENDLOOP.
    mt_patterns = it_patterns.
    SORT mt_patterns BY priority pattern.
    mt_accounts     = it_accounts.
    mv_bai_fallback = iv_bai_fallback.
  ENDMETHOD.


  METHOD enrich_statements.
    LOOP AT ct_statements ASSIGNING FIELD-SYMBOL(<ls_statement>).
      DATA(ls_account) = find_account( <ls_statement> ).
      IF ls_account IS INITIAL.
        CONTINUE.
      ENDIF.
      <ls_statement>-bank_key = ls_account-bank_key.
      IF <ls_statement>-flow_default IS INITIAL.
        <ls_statement>-flow_default = ls_account-flow_default.
      ENDIF.
      IF <ls_statement>-bukrs IS INITIAL.
        <ls_statement>-bukrs = ls_account-bukrs.
        <ls_statement>-hbkid = ls_account-hbkid.
        <ls_statement>-hktid = ls_account-hktid.
      ENDIF.
      " A25: imported statements (FEBKO) carry no account number - take the configured one
      IF <ls_statement>-account_no IS INITIAL.
        <ls_statement>-account_no = ls_account-account_no.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD resolve.
    DATA lt_statements TYPE tt_stmt_hash.
    lt_statements = it_statements.

    LOOP AT ct_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      DATA(ls_statement) = VALUE #( lt_statements[ stmt_key = <ls_line>-stmt_key ] OPTIONAL ).
      IF <ls_line>-flow_type IS INITIAL.
        <ls_line>-flow_type = derive_flow( is_line = <ls_line> is_statement = ls_statement ).
      ENDIF.

      DATA(ls_map) = find_mapping( is_line = <ls_line> iv_bank_key = ls_statement-bank_key ).

      IF ls_map IS INITIAL OR ls_map-active = abap_false.
        <ls_line>-category = zif_cd_ebs_types=>gc_category_unmapped.
        <ls_line>-blocked  = abap_true.
        INSERT zcl_cd_ebs_finding=>for_line(
                 is_line       = <ls_line>
                 iv_rule_id    = gc_rule_unmapped
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-unmapped_btc
                 iv_severity   = zif_cd_ops_types=>gc_severity-block
                 iv_action     = zif_cd_ops_types=>gc_action-block
                 iv_message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-unmapped_btc
                                                        iv_v1    = <ls_line>-scheme
                                                        iv_v2    = <ls_line>-btc_code
                                                        iv_v3    = ls_statement-bank_key
                                                        iv_v4    = <ls_line>-flow_type ) )
          INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.

      <ls_line>-category    = ls_map-category.
      <ls_line>-rule_group  = COND #( WHEN ls_map-rule_group IS NOT INITIAL THEN ls_map-rule_group
                                      ELSE ls_map-category ).
      <ls_line>-exp_cdi     = ls_map-exp_cdi.
      <ls_line>-pay_method  = ls_map-pay_method.
      <ls_line>-map_posting = ls_map-posting_rule.

      IF ls_map-action = zif_cd_ops_types=>gc_action-block.
        <ls_line>-blocked = abap_true.
        INSERT zcl_cd_ebs_finding=>for_line(
                 is_line       = <ls_line>
                 iv_rule_id    = gc_rule_unmapped
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-map_action_block
                 iv_severity   = zif_cd_ops_types=>gc_severity-info
                 iv_action     = zif_cd_ops_types=>gc_action-block
                 iv_message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-map_action_block
                                                        iv_v1    = ls_map-category ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD find_account.
    IF is_statement-hbkid IS NOT INITIAL.
      rs_account = VALUE #( mt_accounts[ bukrs  = is_statement-bukrs
                                         hbkid  = is_statement-hbkid
                                         hktid  = is_statement-hktid
                                         active = abap_true ] OPTIONAL ).
    ENDIF.
    IF rs_account IS INITIAL AND is_statement-account_no IS NOT INITIAL.
      rs_account = VALUE #( mt_accounts[ account_no = is_statement-account_no
                                         active     = abap_true ] OPTIONAL ).
    ENDIF.
  ENDMETHOD.


  METHOD derive_flow.
    IF is_line-xblnr IS NOT INITIAL.
      LOOP AT mt_patterns INTO DATA(ls_pattern).
        IF is_line-xblnr CP ls_pattern-pattern.
          rv_flow = ls_pattern-flow_type.
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDIF.
    rv_flow = is_statement-flow_default.
  ENDMETHOD.


  METHOD lookup.
    DATA(lt_try) = VALUE zif_cd_ebs_types=>tt_btc_map(
      ( bank_key = iv_bank_key flow_type = iv_flow )
      ( bank_key = iv_bank_key flow_type = zif_cd_ebs_types=>gc_flow-any )
      ( bank_key = space       flow_type = iv_flow )
      ( bank_key = space       flow_type = zif_cd_ebs_types=>gc_flow-any ) ).
    " An unknown (blank) flow finds no flow row and falls through to the '*' rows
    LOOP AT lt_try INTO DATA(ls_try).
      rs_map = VALUE #( mt_map[ scheme    = iv_scheme
                                btc_code  = iv_code
                                bank_key  = ls_try-bank_key
                                flow_type = ls_try-flow_type ] OPTIONAL ).
      IF rs_map IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD find_mapping.
    rs_map = lookup( iv_scheme = is_line-scheme iv_code = is_line-btc_code
                     iv_bank_key = iv_bank_key iv_flow = is_line-flow_type ).
    IF rs_map IS NOT INITIAL.
      RETURN.
    ENDIF.

    IF is_line-scheme = zif_cd_ebs_types=>gc_scheme-iso AND is_line-family IS NOT INITIAL.
      rs_map = lookup( iv_scheme = is_line-scheme iv_code = |{ is_line-domain }-{ is_line-family }|
                       iv_bank_key = iv_bank_key iv_flow = is_line-flow_type ).
      IF rs_map IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    IF is_line-prtry_code IS INITIAL.
      RETURN.
    ENDIF.

    IF mv_bai_fallback = abap_true AND is_bai_code( is_line ) = abap_true.
      rs_map = lookup( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = is_line-prtry_code
                       iv_bank_key = iv_bank_key iv_flow = is_line-flow_type ).
      IF rs_map IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    rs_map = lookup( iv_scheme = zif_cd_ebs_types=>gc_scheme-prtry iv_code = is_line-prtry_code
                     iv_bank_key = iv_bank_key iv_flow = is_line-flow_type ).
  ENDMETHOD.


  METHOD is_bai_code.
    " US banks deliver BAI type codes in CAMT BkTxCd/Prtry with issuer BAI
    rv_bai = xsdbool( is_line-prtry_issuer CP gc_issuer_bai
                      OR ( strlen( condense( is_line-prtry_code ) ) = 3
                           AND is_line-prtry_code CO gc_digits_or_blank ) ).
  ENDMETHOD.

ENDCLASS.
