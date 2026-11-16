*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cash_exc.clas.abap
*& Purpose:
*& Exception builder of the FI-CA cash operations checks: the typed
*& exception ZIF_CA_OPS_CASH_TYPES=>TY_EXCEPTION (count, amount per
*& currency, oldest item and age, next cutoff, owner, stage, evaluation,
*& evidence keys at source grain) and its ONE mapping into today's finding
*& fields (TO_FINDING): amount / currency / company code / business date as
*& stored columns, stage as rule, the rule's parameter as configuration
*& rule, the message with count and amount, and labelled detail and
*& context lines for the rest. Build K's shared exception contract replaces
*& only TO_FINDING (docs/FICA_CASH_OPERATIONS.md section 6); the checks
*& fill the typed exception and never a finding directly. Pure logic.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash operations - exception builder</p>
"! Mapping (today): CHECK_CODE, SEVERITY, RULE_ID = stage, OBJECT_TYPE / OBJECT_KEY (source grain + company code +
"! currency), REFERENCE = source tables, BUKRS, AMOUNT / CURRENCY (one currency per finding), BUS_DATE = oldest item
"! (age = run date - BUS_DATE), CFG_RULE = rule parameter, MESSAGE = count / amount / key, DETAILS = stage and
"! evaluation, count and amount, oldest and age, next cutoff, owner, evidence keys, source; CONTEXT (alert e-mail) =
"! the same lines without amounts; ITEM_COUNT, ACCOUNT, PAY_METHOD for the alert e-mail.
CLASS zcl_ca_ops_cash_exc DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! The finding of a cash exception (the single mapping into ZIF_CA_OPS_TYPES=>TY_FINDING)
    CLASS-METHODS to_finding
      IMPORTING
        is_exc            TYPE zif_ca_ops_cash_types=>ty_exception
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Days from the oldest item to the day (0 = no date or not older)
    CLASS-METHODS age_days
      IMPORTING
        iv_oldest      TYPE d
        iv_today       TYPE d
      RETURNING
        VALUE(rv_days) TYPE i.

    "! Object key at source grain: the object's key parts, company code and currency joined by /
    CLASS-METHODS object_key
      IMPORTING
        iv_id         TYPE clike
        iv_sub        TYPE clike OPTIONAL
        iv_company    TYPE bukrs OPTIONAL
        iv_currency   TYPE zif_ca_ops_types=>ty_currency OPTIONAL
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_types=>ty_object_key.

    "! Amount and currency as shown in messages (thousands separators, two decimals)
    CLASS-METHODS amount_text
      IMPORTING
        iv_amount      TYPE zif_ca_ops_cash_types=>ty_amount
        iv_currency    TYPE zif_ca_ops_types=>ty_currency
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
    CONSTANTS gc_separator TYPE c LENGTH 1 VALUE '/'.

    "! Labelled lines of the exception; with iv_amounts the count / amount line too (DETAILS), else not (CONTEXT)
    CLASS-METHODS labelled_lines
      IMPORTING
        is_exc         TYPE zif_ca_ops_cash_types=>ty_exception
        iv_amounts     TYPE abap_bool
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS cutoff_line
      IMPORTING
        is_cutoff      TYPE zif_ca_ops_cash_types=>ty_cutoff
      RETURNING
        VALUE(rv_line) TYPE string.

    CLASS-METHODS owner_line
      IMPORTING
        is_exc         TYPE zif_ca_ops_cash_types=>ty_exception
      RETURNING
        VALUE(rv_line) TYPE string.

ENDCLASS.



CLASS zcl_ca_ops_cash_exc IMPLEMENTATION.

  METHOD to_finding.
    rs_finding = VALUE #(
      object_type   = is_exc-object_type
      object_key    = is_exc-object_key
      rule_id       = is_exc-stage
      check_code    = is_exc-check_code
      severity      = is_exc-severity
      action        = COND #( WHEN is_exc-severity = zif_ca_ops_types=>gc_severity-info
                                 OR is_exc-evaluation = zif_ca_ops_cash_types=>gc_evaluation-not_evaluated
                              THEN zif_ca_ops_types=>gc_action-notify
                              ELSE zif_ca_ops_types=>gc_action-exception )
      amount        = is_exc-amount
      currency      = is_exc-currency
      reference     = is_exc-source
      message       = zcl_ca_ops_util=>text( iv_msgno = is_exc-msgno
                                             iv_v1    = is_exc-msgv1
                                             iv_v2    = is_exc-msgv2
                                             iv_v3    = is_exc-msgv3
                                             iv_v4    = is_exc-msgv4 )
      details       = labelled_lines( is_exc = is_exc iv_amounts = abap_true )
      context       = labelled_lines( is_exc = is_exc iv_amounts = abap_false )
      business_date = is_exc-oldest
      company_code  = is_exc-company_code
      account       = is_exc-account
      pay_method    = is_exc-pay_method
      item_count    = is_exc-item_count
      cfg_rule      = is_exc-rule_param ).
  ENDMETHOD.


  METHOD age_days.
    IF iv_oldest IS NOT INITIAL AND iv_today > iv_oldest.
      rv_days = iv_today - iv_oldest.
    ENDIF.
  ENDMETHOD.


  METHOD object_key.
    DATA(lv_key) = condense( CONV string( iv_id ) ).
    IF iv_sub IS NOT INITIAL.
      lv_key = |{ lv_key }{ gc_separator }{ condense( CONV string( iv_sub ) ) }|.
    ENDIF.
    IF iv_company IS NOT INITIAL OR iv_currency IS NOT INITIAL.
      lv_key = |{ lv_key }{ gc_separator }{ iv_company }{ gc_separator }{ iv_currency }|.
    ENDIF.
    rv_key = lv_key.
  ENDMETHOD.


  METHOD amount_text.
    rv_text = condense( |{ zcl_ca_ops_util=>format_amount( CONV decfloat34( iv_amount ) ) } { iv_currency }| ).
  ENDMETHOD.


  METHOD labelled_lines.
    DATA lt_lines TYPE string_table.

    INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_stage
                                  iv_v1    = is_exc-stage
                                  iv_v2    = is_exc-evaluation ) INTO TABLE lt_lines.
    IF iv_amounts = abap_true.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_amount
                                    iv_v1    = is_exc-item_count
                                    iv_v2    = zcl_ca_ops_util=>format_amount( CONV decfloat34( is_exc-amount ) )
                                    iv_v3    = is_exc-currency ) INTO TABLE lt_lines.
    ENDIF.
    IF is_exc-oldest IS NOT INITIAL.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_oldest
                                    iv_v1    = |{ is_exc-oldest DATE = ISO }|
                                    iv_v2    = is_exc-age_days ) INTO TABLE lt_lines.
    ENDIF.
    INSERT cutoff_line( is_exc-cutoff ) INTO TABLE lt_lines.
    INSERT owner_line( is_exc ) INTO TABLE lt_lines.
    LOOP AT is_exc-evidence ASSIGNING FIELD-SYMBOL(<ls_evidence>).
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_evidence
                                    iv_v1    = <ls_evidence>-name
                                    iv_v2    = <ls_evidence>-value ) INTO TABLE lt_lines.
    ENDLOOP.
    INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_source
                                  iv_v1    = is_exc-source
                                  iv_v2    = is_exc-rule_param ) INTO TABLE lt_lines.
    IF iv_amounts = abap_true AND is_exc-note IS NOT INITIAL.
      INSERT is_exc-note INTO TABLE lt_lines.
    ENDIF.
    rv_text = concat_lines_of( table = lt_lines sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.


  METHOD cutoff_line.
    IF is_cutoff-known = abap_true.
      rv_line = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_cutoff
                                       iv_v1    = |{ is_cutoff-date DATE = ISO }|
                                       iv_v2    = |{ is_cutoff-time TIME = ISO }|
                                       iv_v3    = is_cutoff-time_zone ).
    ELSE.
      rv_line = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_cutoff_open
                                       iv_v1    = zif_ca_ops_cash_types=>gc_param-calendar
                                       iv_v2    = zif_ca_ops_cash_types=>gc_source-control ).
    ENDIF.
  ENDMETHOD.


  METHOD owner_line.
    IF is_exc-owner-owner IS INITIAL AND is_exc-owner-team IS INITIAL.
      rv_line = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_no_owner
                                       iv_v1    = is_exc-check_code ).
    ELSE.
      rv_line = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_owner
                                       iv_v1    = is_exc-owner-owner
                                       iv_v2    = is_exc-owner-backup
                                       iv_v3    = is_exc-owner-team
                                       iv_v4    = is_exc-owner-control_id ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
