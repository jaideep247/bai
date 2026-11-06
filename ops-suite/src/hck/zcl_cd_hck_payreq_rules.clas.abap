*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_payreq_rules.clas.abap
*& Purpose:
*& Known-table rules of the payment engine (USAA reference), pure:
*& payment request failed without SPE row (a SUCCESS row overrides failed
*& attempts, as in ZCD_PAYM_REQ_LOG), paid request left CANCELLED (PCLM),
*& cheque status regression (ZECT_STATUS: terminal statuses, allowed
*& backward steps such as mailed 10 -> returned 9, otherwise never lower).
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - payment request and cheque rules</p>
CLASS zcl_cd_hck_payreq_rules DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS failed_without_spe
      IMPORTING
        it_failed      TYPE zif_cd_hck_value_types=>tt_key
        it_success     TYPE zif_cd_hck_value_types=>tt_key
        it_spe         TYPE zif_cd_hck_value_types=>tt_key
      RETURNING
        VALUE(rt_keys) TYPE zif_cd_hck_value_types=>tt_key.

    CLASS-METHODS paid_but_cancelled
      IMPORTING
        it_cancelled   TYPE zif_cd_hck_value_types=>tt_key
        it_paid        TYPE zif_cd_hck_value_types=>tt_key
      RETURNING
        VALUE(rt_keys) TYPE zif_cd_hck_value_types=>tt_key.

    "! @parameter it_allowed | allowed backward steps 'from>to', e.g. 10>9
    CLASS-METHODS is_regression
      IMPORTING
        iv_from              TYPE string
        iv_to                TYPE string
        it_terminal          TYPE string_table
        it_allowed           TYPE string_table
      RETURNING
        VALUE(rv_regression) TYPE abap_bool.

    "! Events sorted or not; evaluated per key in sequence order
    CLASS-METHODS cheque_regressions
      IMPORTING
        it_events       TYPE zif_cd_hck_value_types=>tt_status_event
        it_terminal     TYPE string_table
        it_allowed      TYPE string_table
      RETURNING
        VALUE(rt_found) TYPE zif_cd_hck_value_types=>tt_regression.

  PRIVATE SECTION.
    CLASS-METHODS rank
      IMPORTING
        iv_status      TYPE string
      RETURNING
        VALUE(rv_rank) TYPE i.
ENDCLASS.



CLASS zcl_cd_hck_payreq_rules IMPLEMENTATION.

  METHOD failed_without_spe.
    LOOP AT it_failed INTO DATA(lv_key).
      IF line_exists( it_success[ table_line = lv_key ] ) OR line_exists( it_spe[ table_line = lv_key ] ).
        CONTINUE.
      ENDIF.
      INSERT lv_key INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.


  METHOD paid_but_cancelled.
    LOOP AT it_cancelled INTO DATA(lv_key).
      IF line_exists( it_paid[ table_line = lv_key ] ).
        INSERT lv_key INTO TABLE rt_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_regression.
    DATA(lv_from) = condense( iv_from ).
    DATA(lv_to) = condense( iv_to ).
    IF lv_from = lv_to.
      RETURN.
    ENDIF.
    IF line_exists( it_terminal[ table_line = lv_from ] ).
      rv_regression = abap_true.
      RETURN.
    ENDIF.
    IF line_exists( it_allowed[ table_line = |{ lv_from }>{ lv_to }| ] ).
      RETURN.
    ENDIF.
    rv_regression = xsdbool( rank( lv_to ) < rank( lv_from ) ).
  ENDMETHOD.


  METHOD cheque_regressions.
    DATA(lt_events) = it_events.
    SORT lt_events BY key seq.
    DATA(lv_key) = VALUE string( ).
    DATA(lv_previous) = VALUE string( ).
    DATA(lv_reported) = abap_false.
    LOOP AT lt_events INTO DATA(ls_event).
      IF ls_event-key <> lv_key.
        lv_key      = ls_event-key.
        lv_previous = ls_event-status.
        lv_reported = abap_false.
        CONTINUE.
      ENDIF.
      IF lv_reported = abap_false
         AND is_regression( iv_from = lv_previous iv_to = ls_event-status
                            it_terminal = it_terminal it_allowed = it_allowed ) = abap_true.
        INSERT VALUE #( key = ls_event-key from_status = lv_previous to_status = ls_event-status ) INTO TABLE rt_found.
        lv_reported = abap_true.
      ENDIF.
      lv_previous = ls_event-status.
    ENDLOOP.
  ENDMETHOD.


  METHOD rank.
    " Status codes are numeric (ZECT_STATUS); a non-numeric code ranks lowest
    TRY.
        rv_rank = CONV i( iv_status ).
      CATCH cx_sy_conversion_error.
        rv_rank = 0.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
