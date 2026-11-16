*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_exposure.clas.abap
*& Purpose:
*& Exposure of a finding set of the pilot acceptance checks (build R),
*& pure: per currency the number of items, the amount, the oldest age and
*& its item, and the earliest deadline (a blank currency = amount not known,
*& never summed into another currency); one information finding per
*& currency carrying count, amount, currency, oldest age, deadline and the
*& control that owns it; the labelled context lines (deadline, age,
*& control, evidence keys) of every item finding; a parameter value that
*& still holds a placeholder (angle quotes) is not configured.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - exposure per currency (pilot checks)</p>
CLASS zcl_cd_hck_exposure DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Count, amount, oldest age (and its item) and earliest deadline per currency
    CLASS-METHODS totals
      IMPORTING
        it_items         TYPE zif_cd_hck_cheque_types=>tt_item
      RETURNING
        VALUE(rt_totals) TYPE zif_cd_hck_cheque_types=>tt_total.

    "! One information finding per currency (object key <control>/<currency>)
    "! @parameter iv_control  | Control of the daily review that owns the findings (owner in its register row)
    "! @parameter iv_in_hours | X = the ages are hours (collections checks), else days
    CLASS-METHODS total_findings
      IMPORTING
        it_totals          TYPE zif_cd_hck_cheque_types=>tt_total
        iv_control         TYPE clike
        iv_in_hours        TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

    "! Labelled context lines of an item finding: deadline, age, control, evidence keys
    CLASS-METHODS context
      IMPORTING
        is_item           TYPE zif_cd_hck_cheque_types=>ty_item
        iv_control        TYPE clike
        iv_evidence       TYPE clike OPTIONAL
        iv_in_hours       TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_context) TYPE string.

    "! The value is blank or still holds a placeholder (text in angle quotes): not configured
    CLASS-METHODS is_unset
      IMPORTING
        iv_value      TYPE clike
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_hck_exposure IMPLEMENTATION.

  METHOD totals.
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      READ TABLE rt_totals ASSIGNING FIELD-SYMBOL(<ls_total>) WITH TABLE KEY currency = <ls_item>-currency.
      IF sy-subrc <> 0.
        INSERT VALUE #( currency   = <ls_item>-currency
                        oldest     = <ls_item>-age
                        oldest_key = <ls_item>-object_key
                        deadline   = <ls_item>-deadline ) INTO TABLE rt_totals ASSIGNING <ls_total>.
      ENDIF.
      <ls_total>-item_count = <ls_total>-item_count + 1.
      <ls_total>-amount     = <ls_total>-amount + <ls_item>-amount.
      IF <ls_item>-age > <ls_total>-oldest.
        <ls_total>-oldest     = <ls_item>-age.
        <ls_total>-oldest_key = <ls_item>-object_key.
      ENDIF.
      IF <ls_item>-deadline IS NOT INITIAL
         AND ( <ls_total>-deadline IS INITIAL OR <ls_item>-deadline < <ls_total>-deadline ).
        <ls_total>-deadline = <ls_item>-deadline.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD total_findings.
    DATA lv_age_msg TYPE zif_ca_ops_types=>ty_msgno.
    lv_age_msg = COND #( WHEN iv_in_hours = abap_true THEN zif_cd_hck_cheque_types=>gc_msg-ctx_age_hours
                         ELSE zif_cd_hck_cheque_types=>gc_msg-ctx_age_days ).
    LOOP AT it_totals ASSIGNING FIELD-SYMBOL(<ls_total>).
      DATA(lv_currency) = condense( CONV string( <ls_total>-currency ) ).
      INSERT VALUE #(
        object_key = |{ iv_control }/{ lv_currency }|
        check_code = zif_cd_hck_cheque_types=>gc_code-exposure
        severity   = zif_ca_ops_types=>gc_severity-info
        action     = zif_ca_ops_types=>gc_action-notify
        amount     = <ls_total>-amount
        currency   = <ls_total>-currency
        item_count = <ls_total>-item_count
        business_date = <ls_total>-deadline
        reference  = <ls_total>-oldest_key
        message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-exposure
                                            iv_v1    = iv_control
                                            iv_v2    = <ls_total>-item_count
                                            iv_v3    = lv_currency
                                            iv_v4    = <ls_total>-oldest )
        " the amount only in DETAILS: the e-mail shows it on rules with SHOW_AMOUNTS
        details    = |{ <ls_total>-amount NUMBER = RAW } { lv_currency }|
        context    = concat_lines_of(
                       sep   = cl_abap_char_utilities=>newline
                       table = VALUE string_table(
                         ( zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-ctx_deadline
                                                  iv_v1    = <ls_total>-deadline ) )
                         ( zcl_cd_ops_util=>text( iv_msgno = lv_age_msg iv_v1 = <ls_total>-oldest ) )
                         ( zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-ctx_control
                                                  iv_v1    = iv_control ) )
                         ( zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-ctx_evidence
                                                  iv_v1    = <ls_total>-oldest_key ) ) ) ) )
        INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD context.
    DATA lt_lines TYPE string_table.
    DATA lv_age_msg TYPE zif_ca_ops_types=>ty_msgno.
    lv_age_msg = COND #( WHEN iv_in_hours = abap_true THEN zif_cd_hck_cheque_types=>gc_msg-ctx_age_hours
                         ELSE zif_cd_hck_cheque_types=>gc_msg-ctx_age_days ).
    IF is_item-deadline IS NOT INITIAL.
      INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-ctx_deadline
                                    iv_v1    = is_item-deadline ) INTO TABLE lt_lines.
    ENDIF.
    INSERT zcl_cd_ops_util=>text( iv_msgno = lv_age_msg iv_v1 = is_item-age ) INTO TABLE lt_lines.
    INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-ctx_control
                                  iv_v1    = iv_control ) INTO TABLE lt_lines.
    IF iv_evidence IS NOT INITIAL.
      INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-ctx_evidence
                                    iv_v1    = iv_evidence ) INTO TABLE lt_lines.
    ENDIF.
    rv_context = concat_lines_of( table = lt_lines sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.


  METHOD is_unset.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    rv_yes = xsdbool( lv_value IS INITIAL OR lv_value CS zif_cd_hck_cheque_types=>gc_placeholder_open ).
  ENDMETHOD.

ENDCLASS.
