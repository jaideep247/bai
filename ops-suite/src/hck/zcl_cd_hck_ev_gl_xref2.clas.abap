*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_gl_xref2.clas.abap
*& Purpose:
*& Evidence kind "G/L line cleared": a G/L line (BSEG) of the company code
*& of the payment with XREF2 = the payment document AUGBL (as stored or
*& without leading zeros; XREF2 is the stable key - ZUONR is overwritten
*& for Stripe) whose clearing document AUGBL is filled. A line that
*& exists but is not cleared is shown in the detail, not found. PARAM1 =
*& G/L clearing accounts (comma list, optional; restricts and supports
*& the read). One read for all payments (fiscal years of the run dates up
*& to the following year), capped. Read-only.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 3: collections cleared by BSEG XREF2, replaces BSAS ZUONR).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Evidence - G/L line with XREF2 = payment doc., cleared</p>
CLASS zcl_cd_hck_ev_gl_xref2 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.

ENDCLASS.



CLASS zcl_cd_hck_ev_gl_xref2 IMPLEMENTATION.

  METHOD zif_cd_hck_evidence~collect.
    DATA(ls_lines) = zcl_cd_hck_ev_support=>gl_lines_by_doc( it_payments = it_payments
                                                            iv_accounts = is_rule-param1
                                                            iv_max_rows = iv_max_rows ).
    rs_result-capped = ls_lines-capped.
    rs_result-source = zif_cd_ops_trace_types=>gc_table-bseg.
    LOOP AT ls_lines-lines ASSIGNING FIELD-SYMBOL(<ls_gl>).
      zcl_cd_hck_ev_support=>add_hit(
        EXPORTING iv_doc1r    = <ls_gl>-doc1r
                  iv_found    = xsdbool( <ls_gl>-line-augbl IS NOT INITIAL )
                  iv_detail   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_gl_line
                                                       iv_v1    = <ls_gl>-line-bukrs
                                                       iv_v2    = <ls_gl>-line-belnr
                                                       iv_v3    = <ls_gl>-line-gjahr
                                                       iv_v4    = <ls_gl>-line-augbl )
        CHANGING  ct_evidence = rs_result-evidence ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
