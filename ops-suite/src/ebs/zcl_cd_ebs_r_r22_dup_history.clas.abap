*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r22_dup_history.clas.abap
*& Purpose:
*& R22: an entry must not already be in another imported statement of the same
*& house bank account within the look-back window (WINDOW_DAYS of the rule row,
*& else EBS_DUP_LOOKBACK_DAYS): same reference, amount, debit/credit and bank
*& transaction code. The statement's own entries (same KUKEY) are excluded.
*& Needs the SAP house bank identity; R09 stays the within-statement check.
*& Modification log:
*& 2026-11-06 | Initial version (audit A14, business decision: look back N days).
*& 2026-11-06 | Performance fix 2: history read once per account per package (instance memo), statement window
*&            | applied in ABAP on FEBKO-AZDAT; lines by secondary key STMT.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R22 - duplicate of an earlier statement</p>
CLASS zcl_cd_ebs_r_r22_dup_history DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

    "! Look-back days when neither the rule row nor ZCD_OPS_PARAM set them
    CONSTANTS gc_default_days TYPE i VALUE 5.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_key,
        reference TYPE string,
        amount    TYPE zif_cd_ops_types=>ty_amount,
        cdi       TYPE zif_cd_ebs_types=>ty_cdi,
        btc_code  TYPE zif_cd_ebs_types=>ty_btc_code,
      END OF ty_key.
    TYPES:
      BEGIN OF ty_seen,
        key   TYPE ty_key,
        kukey TYPE zif_cd_ebs_types=>ty_kukey,
      END OF ty_seen.
    TYPES tt_seen TYPE HASHED TABLE OF ty_seen WITH UNIQUE KEY key.

    "! Performance fix 2: FEBEP history of one house bank account over the union of the
    "! look-back windows of its statements in the package, in repository order (KUKEY, ESNUM)
    TYPES:
      BEGIN OF ty_history,
        bukrs     TYPE zif_cd_ebs_types=>ty_statement-bukrs,
        hbkid     TYPE zif_cd_ebs_types=>ty_statement-hbkid,
        hktid     TYPE zif_cd_ebs_types=>ty_statement-hktid,
        date_from TYPE d,
        date_to   TYPE d,
        items     TYPE zif_cd_ebs_feb_dao=>tt_item,
      END OF ty_history.
    TYPES tt_history TYPE HASHED TABLE OF ty_history WITH UNIQUE KEY bukrs hbkid hktid.

    "! Memo: package (statement keys and look-back days) the history was read for. The
    "! engine keeps one rule instance per run; R22 (group *) runs once per rule group
    DATA mv_history_package TYPE string.
    DATA mt_history TYPE tt_history.

    METHODS look_back_days
      IMPORTING
        is_rule        TYPE zif_cd_ebs_types=>ty_rule_cfg
      RETURNING
        VALUE(rv_days) TYPE i.

    "! History of every account of the package - one read per account, not per statement
    "! and rule group; a new package (or other look-back days) reads again
    METHODS load_history
      IMPORTING
        it_statements TYPE zif_cd_ebs_types=>tt_statement
        iv_days       TYPE i.

ENDCLASS.



CLASS zcl_cd_ebs_r_r22_dup_history IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA lt_seen TYPE tt_seen.
    DATA ls_key TYPE ty_key.
    DATA lv_from TYPE d.
    FIELD-SYMBOLS <ls_history> TYPE ty_history.
    DATA(lv_days) = look_back_days( is_rule ).
    DATA(lv_credit_ind) = param( iv_name    = zif_cd_ebs_types=>gc_param-feb_credit_ind
                                 iv_default = zif_cd_ebs_types=>gc_param_default-feb_credit_ind ).
    DATA(lv_debit_ind) = param( iv_name    = zif_cd_ebs_types=>gc_param-feb_debit_ind
                                iv_default = zif_cd_ebs_types=>gc_param_default-feb_debit_ind ).

    load_history( it_statements = it_statements iv_days = lv_days ).

    LOOP AT it_statements ASSIGNING FIELD-SYMBOL(<ls_statement>)
         WHERE hbkid IS NOT INITIAL AND stmt_date IS NOT INITIAL.
      CLEAR lt_seen.
      lv_from = <ls_statement>-stmt_date - lv_days.
      UNASSIGN <ls_history>.
      ASSIGN mt_history[ bukrs = <ls_statement>-bukrs
                         hbkid = <ls_statement>-hbkid
                         hktid = <ls_statement>-hktid ] TO <ls_history>.
      IF <ls_history> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.
      " The statement's own window on FEBKO-AZDAT, as the per-statement read applied it
      LOOP AT <ls_history>-items ASSIGNING FIELD-SYMBOL(<ls_item>)
           WHERE kukey <> <ls_statement>-kukey AND chect IS NOT INITIAL
             AND azdat >= lv_from AND azdat <= <ls_statement>-stmt_date.
        CLEAR ls_key.
        ls_key-reference = condense( CONV string( <ls_item>-chect ) ).
        ls_key-amount    = abs( <ls_item>-kwbtr ).
        ls_key-cdi       = COND #( WHEN <ls_item>-epvoz = lv_credit_ind THEN zif_cd_ebs_types=>gc_cdi-credit
                                   WHEN <ls_item>-epvoz = lv_debit_ind  THEN zif_cd_ebs_types=>gc_cdi-debit ).
        ls_key-btc_code  = COND #( WHEN <ls_item>-vorgc IS NOT INITIAL THEN <ls_item>-vorgc ELSE <ls_item>-vgext ).
        " First (lowest KUKEY) statement wins, as before
        INSERT VALUE #( key = ls_key kukey = <ls_item>-kukey ) INTO TABLE lt_seen.
      ENDLOOP.
      IF lt_seen IS INITIAL.
        CONTINUE.
      ENDIF.
      LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>) USING KEY stmt
           WHERE stmt_key = <ls_statement>-stmt_key AND reference IS NOT INITIAL.
        CLEAR ls_key.
        ls_key-reference = condense( CONV string( <ls_line>-reference ) ).
        ls_key-amount    = <ls_line>-amount.
        ls_key-cdi       = <ls_line>-cdi.
        ls_key-btc_code  = <ls_line>-btc_code.
        READ TABLE lt_seen ASSIGNING FIELD-SYMBOL(<ls_seen>) WITH TABLE KEY key = ls_key.
        IF sy-subrc = 0.
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-duplicate_history
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-duplicate_history
                                                       iv_v1    = zcl_cd_ebs_finding=>line_key( <ls_line> )
                                                       iv_v2    = <ls_seen>-kukey
                                                       iv_v3    = <ls_line>-reference ) )
            INTO TABLE rt_findings.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_history.
    DATA ls_history TYPE ty_history.
    FIELD-SYMBOLS <ls_history> TYPE ty_history.
    DATA(lv_package) = |{ package_fingerprint( it_statements ) }{ iv_days }|.
    IF lv_package = mv_history_package.
      RETURN.
    ENDIF.
    CLEAR mt_history.
    mv_history_package = lv_package.
    " Union of the look-back windows of the account's statements
    LOOP AT it_statements ASSIGNING FIELD-SYMBOL(<ls_statement>)
         WHERE hbkid IS NOT INITIAL AND stmt_date IS NOT INITIAL.
      DATA(lv_from) = CONV d( <ls_statement>-stmt_date - iv_days ).
      UNASSIGN <ls_history>.
      ASSIGN mt_history[ bukrs = <ls_statement>-bukrs
                         hbkid = <ls_statement>-hbkid
                         hktid = <ls_statement>-hktid ] TO <ls_history>.
      IF <ls_history> IS ASSIGNED.
        " Non-key components only (the hashed key stays untouched)
        IF lv_from < <ls_history>-date_from.
          <ls_history>-date_from = lv_from.
        ENDIF.
        IF <ls_statement>-stmt_date > <ls_history>-date_to.
          <ls_history>-date_to = <ls_statement>-stmt_date.
        ENDIF.
      ELSE.
        CLEAR ls_history.
        ls_history-bukrs     = <ls_statement>-bukrs.
        ls_history-hbkid     = <ls_statement>-hbkid.
        ls_history-hktid     = <ls_statement>-hktid.
        ls_history-date_from = lv_from.
        ls_history-date_to   = <ls_statement>-stmt_date.
        INSERT ls_history INTO TABLE mt_history.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_history ASSIGNING <ls_history>.
      <ls_history>-items = feb_dao( )->get_recent_items( iv_bukrs = <ls_history>-bukrs
                                                         iv_hbkid = <ls_history>-hbkid
                                                         iv_hktid = <ls_history>-hktid
                                                         iv_from  = <ls_history>-date_from
                                                         iv_to    = <ls_history>-date_to ).
    ENDLOOP.
  ENDMETHOD.


  METHOD look_back_days.
    rv_days = COND #( WHEN is_rule-window_days > 0 THEN is_rule-window_days
                      ELSE CONV i( zcl_cd_ops_util=>to_decimal(
                                     iv_value   = param( iv_name    = zif_cd_ebs_types=>gc_param-dup_lookback_days
                                                         iv_default = |{ gc_default_days }| )
                                     iv_default = gc_default_days ) ) ).
  ENDMETHOD.

ENDCLASS.
