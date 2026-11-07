*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_stmt_doc.clas.abap
*& Purpose:
*& Evidence kind "statement line by payment document": a bank statement
*& line (FEBEP) with CHECT = the payment document AUGBL / DOC1R (as stored
*& or without leading zeros), posted on or after the payment run. Any BAI
*& code; the lifecycle by code is ZCL_CD_HCK_EV_BTC_SEQ. No parameters.
*& One read for all payments (payment trace repository), capped.
*& Read-only.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 1: wire / ACH disbursements on the statement).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Evidence - statement line with CHECT = payment document</p>
CLASS zcl_cd_hck_ev_stmt_doc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.

ENDCLASS.



CLASS zcl_cd_hck_ev_stmt_doc IMPLEMENTATION.

  METHOD zif_cd_hck_evidence~collect.
    DATA(ls_lines) = zcl_cd_hck_ev_support=>lines_by_doc( it_payments = it_payments
                                                         iv_max_rows = iv_max_rows ).
    rs_result-capped = ls_lines-capped.
    rs_result-source = zif_cd_ops_trace_types=>gc_table-febep.
    LOOP AT ls_lines-lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      zcl_cd_hck_ev_support=>add_hit( EXPORTING iv_doc1r    = <ls_line>-doc1r
                                                iv_detail   = zcl_cd_hck_ev_support=>line_text( <ls_line>-line )
                                      CHANGING  ct_evidence = rs_result-evidence ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
