*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_glkey.clas.abap
*& Purpose:
*& FI-CA cash check "reconciliation key to G/L" (catalogue process
*& FICA_GL_TRANSFER). What should have happened: a reconciliation key is
*& closed within CASH_GLKEY_OPEN_DAYS of its creation, its transfer to the
*& G/L ends without error, and CASH_GLKEY_GL_DAYS after closing every
*& company code of its totals has an unreversed G/L document with the key
*& as reference (reference type CASH_GL_AWTYP). Detected on the database
*& per key, company code and currency of the totals (DFKKSUMC status,
*& DFKKSUM debit side; the G/L through the released view I_JournalEntry,
*& ZI_CA_OpsCashJrnl). The G/L rule needs the reference type: pending
*& until maintained ("not evaluated", VERIFY V229). A failed read is "not
*& evaluated" (the check partial), never green. Read-only.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash check - reconciliation key to G/L</p>
CLASS zcl_ca_ops_chk_cash_glkey DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_rule,
        stage TYPE zif_ca_ops_cash_types=>ty_stage,
        code  TYPE zif_ca_ops_types=>ty_check_code,
        param TYPE zif_ca_ops_types=>ty_param_name,
        msgno TYPE zif_ca_ops_types=>ty_msgno,
      END OF ty_rule.

    DATA mo_ctx TYPE REF TO zcl_ca_ops_cash_ctx.

    METHODS report
      IMPORTING
        is_rule   TYPE ty_rule
        it_sums   TYPE zif_ca_ops_cash_types=>tt_sum
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

    METHODS failed
      IMPORTING
        is_rule   TYPE ty_rule
        ix_error  TYPE REF TO zcx_ca_ops_error
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

ENDCLASS.



CLASS zcl_ca_ops_chk_cash_glkey IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    mo_ctx = NEW #( is_check = is_check is_context = is_context ).
    DATA(lo_dao) = mo_ctx->dao( ).
    DATA(lv_max) = mo_ctx->max_rows( ).

    " 1. key still open past its cutoff
    DATA(ls_open) = VALUE ty_rule( stage = zif_ca_ops_cash_types=>gc_stage-close
                                   code  = zif_ca_ops_cash_types=>gc_code-glkey_open
                                   param = zif_ca_ops_cash_types=>gc_param-glkey_open_days
                                   msgno = zif_ca_ops_cash_types=>gc_msg-glkey_open ).
    TRY.
        report( EXPORTING is_rule   = ls_open
                          it_sums   = lo_dao->open_keys(
                                        iv_created_to = CONV #( mo_ctx->today( ) - mo_ctx->param_int(
                                                                  iv_name    = ls_open-param
                                                                  iv_default = zif_ca_ops_cash_types=>gc_param_default-glkey_open_days ) )
                                        iv_max        = lv_max )
                CHANGING  cs_result = rs_result ).
      CATCH zcx_ca_ops_error INTO DATA(lx_open).
        failed( EXPORTING is_rule = ls_open ix_error = lx_open CHANGING cs_result = rs_result ).
    ENDTRY.

    " 2. transfer to the G/L in error
    DATA(ls_error) = VALUE ty_rule( stage = zif_ca_ops_cash_types=>gc_stage-transfer
                                    code  = zif_ca_ops_cash_types=>gc_code-glkey_error
                                    msgno = zif_ca_ops_cash_types=>gc_msg-glkey_error ).
    TRY.
        report( EXPORTING is_rule   = ls_error
                          it_sums   = lo_dao->error_keys( lv_max )
                CHANGING  cs_result = rs_result ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        failed( EXPORTING is_rule = ls_error ix_error = lx_error CHANGING cs_result = rs_result ).
    ENDTRY.

    " 3. closed, but no unreversed G/L document of the key (reference type pending until maintained)
    DATA(ls_gl) = VALUE ty_rule( stage = zif_ca_ops_cash_types=>gc_stage-gl
                                 code  = zif_ca_ops_cash_types=>gc_code-glkey_not_gl
                                 param = zif_ca_ops_cash_types=>gc_param-gl_awtyp
                                 msgno = zif_ca_ops_cash_types=>gc_msg-glkey_not_gl ).
    DATA(lv_awtyp) = mo_ctx->param_text( zif_ca_ops_cash_types=>gc_param-gl_awtyp ).
    IF lv_awtyp IS INITIAL.
      INSERT mo_ctx->pending( iv_stage  = ls_gl-stage
                              iv_source = zif_ca_ops_cash_types=>gc_source-journal
                              iv_param  = ls_gl-param ) INTO TABLE rs_result-findings.
    ELSE.
      TRY.
          report( EXPORTING is_rule   = ls_gl
                            it_sums   = lo_dao->keys_not_in_gl(
                                          iv_closed_to = CONV #( mo_ctx->today( ) - mo_ctx->param_int(
                                                                   iv_name    = zif_ca_ops_cash_types=>gc_param-glkey_gl_days
                                                                   iv_default = zif_ca_ops_cash_types=>gc_param_default-glkey_gl_days ) )
                                          iv_awtyp     = lv_awtyp
                                          iv_max       = lv_max )
                  CHANGING  cs_result = rs_result ).
        CATCH zcx_ca_ops_error INTO DATA(lx_gl).
          failed( EXPORTING is_rule = ls_gl ix_error = lx_gl CHANGING cs_result = rs_result ).
      ENDTRY.
    ENDIF.
    rs_result-partial = mo_ctx->partial( ).
  ENDMETHOD.


  METHOD report.
    DATA(lv_source) = COND zif_ca_ops_types=>ty_reference( WHEN is_rule-stage = zif_ca_ops_cash_types=>gc_stage-gl
                                                           THEN zif_ca_ops_cash_types=>gc_source-journal
                                                           ELSE zif_ca_ops_cash_types=>gc_source-keys ).
    mo_ctx->cap( EXPORTING iv_stage    = is_rule-stage
                           iv_source   = lv_source
                           iv_rows     = lines( it_sums )
                 CHANGING  ct_findings = cs_result-findings ).
    cs_result-item_count = cs_result-item_count + lines( it_sums ).
    LOOP AT it_sums ASSIGNING FIELD-SYMBOL(<ls_sum>).
      DATA(lv_key) = condense( CONV string( <ls_sum>-object_id ) ).
      DATA(lv_amount) = zcl_ca_ops_cash_exc=>amount_text( iv_amount = <ls_sum>-amount iv_currency = <ls_sum>-currency ).
      DATA(ls_exc) = VALUE zif_ca_ops_cash_types=>ty_exception(
        check_code   = is_rule-code
        severity     = zif_ca_ops_types=>gc_severity-error
        stage        = is_rule-stage
        object_type  = zif_ca_ops_cash_types=>gc_object_type-recon_key
        object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id       = <ls_sum>-object_id
                                                        iv_company  = <ls_sum>-company_code
                                                        iv_currency = <ls_sum>-currency )
        source       = lv_source
        company_code = <ls_sum>-company_code
        currency     = <ls_sum>-currency
        item_count   = <ls_sum>-item_count
        amount       = <ls_sum>-amount
        oldest       = <ls_sum>-oldest
        rule_param   = is_rule-param
        evidence     = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-recon_key value = <ls_sum>-object_id ) )
        msgno        = is_rule-msgno
        msgv1        = lv_key ).
      CASE is_rule-stage.
        WHEN zif_ca_ops_cash_types=>gc_stage-close.
          ls_exc-msgv2 = |{ <ls_sum>-oldest DATE = ISO }|.
          ls_exc-msgv3 = |{ <ls_sum>-item_count }|.
          ls_exc-msgv4 = lv_amount.
        WHEN zif_ca_ops_cash_types=>gc_stage-transfer.
          ls_exc-msgv2 = |{ <ls_sum>-item_count }|.
          ls_exc-msgv3 = lv_amount.
        WHEN OTHERS.
          " the journal entry that should exist: reference type / key (AWTYP / AWKEY) of the company code
          INSERT VALUE #( name  = zif_ca_ops_cash_types=>gc_key-journal
                          value = |{ mo_ctx->param_text( zif_ca_ops_cash_types=>gc_param-gl_awtyp ) }/{ lv_key }| )
                 INTO TABLE ls_exc-evidence.
          ls_exc-msgv2 = |{ <ls_sum>-oldest DATE = ISO }|.
          ls_exc-msgv3 = <ls_sum>-company_code.
          ls_exc-msgv4 = lv_amount.
      ENDCASE.
      INSERT mo_ctx->finding( ls_exc ) INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD failed.
    INSERT mo_ctx->read_failed( iv_stage  = is_rule-stage
                                iv_source = COND #( WHEN is_rule-stage = zif_ca_ops_cash_types=>gc_stage-gl
                                                    THEN zif_ca_ops_cash_types=>gc_source-journal
                                                    ELSE zif_ca_ops_cash_types=>gc_source-keys )
                                iv_param  = is_rule-param
                                ix_error  = ix_error ) INTO TABLE cs_result-findings.
  ENDMETHOD.

ENDCLASS.
