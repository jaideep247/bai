*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_gl_zuonr.clas.abap
*& Purpose:
*& Evidence kind "assignment state of the G/L line": the G/L line (BSEG)
*& found by the stable key XREF2 = payment document AUGBL (never by
*& ZUONR) and its assignment ZUONR compared with AUGBL. PARAM1 = EQUAL
*& (ACH collections: ZUONR stays AUGBL, F.13 clears one-to-one; a changed
*& assignment is an anomaly CLEARING_INCONSISTENT "assignment changed") or
*& CHANGED (Stripe card collections: payout processing sets the statement
*& descriptor; found when ZUONR is no longer AUGBL). PARAM2 = G/L
*& accounts (optional). One read for all payments (shared with
*& ZCL_CD_HCK_EV_GL_XREF2: same DAO method), capped. Read-only.
*& Modification log:
*& 2026-11-07 | Initial version (user facts on collections clearing: ZUONR / XREF2 after the payment run).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Evidence - BSEG assignment ZUONR still / no longer AUGBL</p>
CLASS zcl_cd_hck_ev_gl_zuonr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.

ENDCLASS.



CLASS zcl_cd_hck_ev_gl_zuonr IMPLEMENTATION.

  METHOD zif_cd_hck_evidence~collect.
    DATA(lv_expect) = CONV zif_cd_hck_runtime_types=>ty_zuonr_expect(
                        to_upper( zcl_cd_hck_ev_support=>required_param(
                                    iv_value = is_rule-param1
                                    iv_name  = zif_cd_hck_runtime_types=>gc_rule_param-param1
                                    is_rule  = is_rule ) ) ).
    IF lv_expect <> zif_cd_hck_runtime_types=>gc_zuonr_expect-equal
       AND lv_expect <> zif_cd_hck_runtime_types=>gc_zuonr_expect-changed.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e671(zcd_ops) WITH is_rule-evidence_class lv_expect.
    ENDIF.
    DATA(ls_lines) = zcl_cd_hck_ev_support=>gl_lines_by_doc( it_payments = it_payments
                                                            iv_accounts = is_rule-param2
                                                            iv_max_rows = iv_max_rows ).
    rs_result-capped = ls_lines-capped.
    rs_result-source = zif_cd_ops_trace_types=>gc_table-bseg.
    LOOP AT ls_lines-lines ASSIGNING FIELD-SYMBOL(<ls_gl>).
      DATA(lv_changed) = xsdbool( zcl_cd_hck_ev_support=>ref_key( <ls_gl>-line-zuonr )
                                  <> zcl_cd_hck_ev_support=>ref_key( <ls_gl>-doc1r ) ).
      zcl_cd_hck_ev_support=>add_hit(
        EXPORTING iv_doc1r    = <ls_gl>-doc1r
                  iv_found    = xsdbool( ( lv_expect = zif_cd_hck_runtime_types=>gc_zuonr_expect-changed AND lv_changed = abap_true )
                                         OR ( lv_expect = zif_cd_hck_runtime_types=>gc_zuonr_expect-equal AND lv_changed = abap_false ) )
                  iv_detail   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_zuonr
                                                       iv_v1    = <ls_gl>-line-belnr
                                                       iv_v2    = <ls_gl>-line-gjahr
                                                       iv_v3    = <ls_gl>-line-zuonr )
        CHANGING  ct_evidence = rs_result-evidence ).
      " ACH collections: the assignment must stay AUGBL until F.13 clears it one-to-one
      IF lv_expect = zif_cd_hck_runtime_types=>gc_zuonr_expect-equal AND lv_changed = abap_true.
        READ TABLE rs_result-evidence ASSIGNING FIELD-SYMBOL(<ls_evidence>) WITH TABLE KEY doc1r = <ls_gl>-doc1r.
        IF sy-subrc = 0.
          <ls_evidence>-anomaly  = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist.
          <ls_evidence>-severity = zif_ca_ops_types=>gc_severity-error.
          <ls_evidence>-detail   = |{ <ls_evidence>-detail } | &&
                                   |{ zcl_cd_ops_util=>text( zif_cd_hck_runtime_types=>gc_msg-ev_zuonr_changed ) }|.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
