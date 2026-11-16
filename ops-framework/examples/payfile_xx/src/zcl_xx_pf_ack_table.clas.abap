*&---------------------------------------------------------------------*
*& Artifact: zcl_xx_pf_ack_table.clas.abap
*& Purpose:
*& Worked example of a fictitious second customer XX (never seeded, not
*& part of the product): its acknowledgement source of the payment file
*& lifecycle (role ACK). XX's own inbound program stores every answer of
*& the bank in its table ZXX_PF_BANKACK (bank reference and version, file
*& name, payment reference for a payment-level answer, status RCVD /
*& ACCP / RJCT / PART, time, amount and currency). One event per answer
*& received in the window; a repeated reference of the bank is a new
*& version and is counted as a repeat by the product. Wired only through
*& the product's interfaces and XX's configuration rows.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle, example XX).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Example XX - payment file acknowledgement source (table)</p>
CLASS zcl_xx_pf_ack_table DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_ack_src.

ENDCLASS.



CLASS zcl_xx_pf_ack_table IMPLEMENTATION.

  METHOD zif_ca_ops_pf_adapter~configure.
    " no setting: the answers are XX's own table
  ENDMETHOD.


  METHOD zif_ca_ops_pf_event_src~read_events.
    DATA(lv_max) = COND i( WHEN is_request-max > 0 THEN is_request-max ELSE 10000 ).
    SELECT ack_id, version, file_name, pay_ref, status, received_at, amount, currency
      FROM zxx_pf_bankack
      WHERE received_at >= @is_request-from_ts
        AND received_at <= @is_request-to_ts
      ORDER BY received_at, ack_id, version
      INTO TABLE @DATA(lt_rows)
      UP TO @lv_max ROWS.
    rs_batch-partial = xsdbool( lines( lt_rows ) >= lv_max ).
    rs_batch-as_of = is_request-to_ts.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( source_event_id = <ls_row>-ack_id
                      event_version   = <ls_row>-version
                      native_status   = <ls_row>-status
                      native_key      = <ls_row>-file_name
                      pay_key         = <ls_row>-pay_ref
                      occurred_at     = <ls_row>-received_at
                      amount          = <ls_row>-amount
                      currency        = <ls_row>-currency ) INTO TABLE rs_batch-events.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
