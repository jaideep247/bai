*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_stmt_cheque.clas.abap
*& Purpose:
*& Evidence kind "statement line of the cheque": a bank statement line
*& (FEBEP) whose CHECT is the last PARAM1 characters (default 13) of the
*& cheque number DFKKCR-ZTNUM of the payment document (DFKKCR-DOC1R =
*& AUGBL), as given or without leading zeros, posted on or after the
*& payment run, on a statement of the cheque's paying house bank account
*& (company code of the payment, DFKKCR-HBKID / HKTID = FEBKO). A line
*& that fits several cheques of one account is attributed to none: each of
*& their payments gets the anomaly CHEQUE_LINK_AMBIGUOUS (E). Only the
*& lines of the deciding cheque of a payment (newest not voided) count;
*& lines of its other cheques are shown. One cheque
*& read and one statement-line read for all payments, capped (shared
*& reader ZCL_CD_HCK_EV_SUPPORT=>LINES_BY_CHEQUE). Read-only.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 2: FEBEP-CHECT = last 13 characters of ZTNUM).
*& 2026-11-07 | Design review: link by suffix AND house bank account, every eligible cheque kept,
*&            | ambiguous lines attributed to none; suffix moved to ZCL_CD_OPS_CHEQUE_LINK.
*& 2026-11-07 | Code review: lines of the deciding (live) cheque only.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Evidence - statement line with CHECT = cheque no. suffix</p>
CLASS zcl_cd_hck_ev_stmt_cheque DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.

ENDCLASS.



CLASS zcl_cd_hck_ev_stmt_cheque IMPLEMENTATION.

  METHOD zif_cd_hck_evidence~collect.
    DATA(lv_length) = nmax( val1 = 1
                            val2 = zcl_cd_hck_param=>int( iv_value   = is_rule-param1
                                                          iv_default = zif_cd_hck_runtime_types=>gc_check_default-ztnum_suffix ) ).
    DATA(ls_lines) = zcl_cd_hck_ev_support=>lines_by_cheque( it_payments = it_payments
                                                            iv_length   = lv_length
                                                            iv_max_rows = iv_max_rows ).
    rs_result-capped = ls_lines-capped.
    rs_result-source = zif_cd_ops_trace_types=>gc_table-febep.
    DATA(lt_live) = zcl_cd_hck_ev_support=>live_cheques( ls_lines-checks ).
    LOOP AT ls_lines-lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      " A line of another cheque of the payment (e.g. voided before a reissue) is shown, not counted
      DATA(ls_live) = VALUE zif_cd_ops_trace_types=>ty_check( lt_live[ doc1r = <ls_line>-doc1r ] OPTIONAL ).
      zcl_cd_hck_ev_support=>add_hit( EXPORTING iv_doc1r    = <ls_line>-doc1r
                                                iv_found    = xsdbool( ls_live-ztnum = <ls_line>-ztnum
                                                                       AND ls_live-hbkid = <ls_line>-line-hbkid
                                                                       AND ls_live-hktid = <ls_line>-line-hktid )
                                                iv_detail   = zcl_cd_hck_ev_support=>line_text( <ls_line>-line )
                                      CHANGING  ct_evidence = rs_result-evidence ).
    ENDLOOP.
    " A line of several cheques of one account proves no cashing: listed, never inherited
    LOOP AT ls_lines-ambiguous ASSIGNING FIELD-SYMBOL(<ls_ambiguous>).
      zcl_cd_hck_ev_support=>add_anomaly( EXPORTING iv_doc1r    = <ls_ambiguous>-doc1r
                                                    iv_code     = zif_cd_hck_runtime_types=>gc_code-cheque_ambiguous
                                                    iv_severity = zif_cd_ops_types=>gc_severity-error
                                                    iv_detail   = <ls_ambiguous>-detail
                                          CHANGING  ct_evidence = rs_result-evidence ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
