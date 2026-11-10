*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_reject.clas.abap
*& Purpose:
*& Plug-in check NACK (bank rejected the file or payments of it) and
*& FILE_FAILED (inbound file failed to load or process). With parameter
*& OUTCOME=PRISM_FAILED it reports PRISM_FAILED (PRISM could not process or
*& deliver the file) instead.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Parameter OUTCOME=PRISM_FAILED for the PRISM status API (check row F_PRFAIL);
*&              without the parameter the behaviour is unchanged.
*& 2026-11-07 | Regenerated files (user 2026-11-07): a PRISM_FAILED file is FILE_REPLACED (information,
*&            | names the regenerated file) when a later generation of its group exists, PRISM_DUPLICATE_NAME
*&            | when PRISM rejected a name it already had, plus REGENERATION_MISSING after
*&            | FMON_REGEN_WAIT_MIN (ZCL_CD_FMON_RULES=>FAILED_VERDICT). Without generation group and
*&            | duplicate-name codes the result is PRISM_FAILED as before.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - bank NACK / failed inbound file</p>
"! Params: OUTCOME= (blank: NACK and FAILED; PRISM_FAILED: only files PRISM reported as failed).
"! With OUTCOME=PRISM_FAILED the failure is refined by ZCL_CD_FMON_RULES=>FAILED_VERDICT: replaced by
"! a regenerated file (FILE_REPLACED, information - the open PRISM_FAILED exception is then resolved
"! by the 5-minute run's reconcile), duplicate name (PRISM_DUPLICATE_NAME instead of PRISM_FAILED),
"! regeneration overdue (REGENERATION_MISSING in addition to PRISM_FAILED).
"! Separate check rows keep the existing F_REJECT findings unchanged and give the PRISM
"! failure its own severity and owner routing.
CLASS zcl_cd_fmon_chk_reject DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

  PRIVATE SECTION.
    "! Name of the check parameter (ZCD_FMON_CHK-PARAMS)
    CONSTANTS gc_param_outcome TYPE string VALUE `OUTCOME`.

    "! Findings of one file with outcome PRISM_FAILED (regenerated files, user 2026-11-07)
    CLASS-METHODS failed_findings
      IMPORTING
        is_ctx             TYPE zif_cd_fmon_types=>ty_check_ctx
        is_check           TYPE zif_cd_fmon_types=>ty_chk
        is_file            TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

    "! File name, else reference
    CLASS-METHODS name_of
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_name) TYPE string.

ENDCLASS.



CLASS zcl_cd_fmon_chk_reject IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    DATA(lv_outcome) = CONV zif_cd_fmon_types=>ty_stage( to_upper( zcl_cd_fmon_util=>param(
                         iv_params = is_check-params iv_name = gc_param_outcome ) ) ).

    IF lv_outcome = zif_cd_fmon_types=>gc_stage-prism_failed.
      LOOP AT is_ctx-files ASSIGNING FIELD-SYMBOL(<ls_failed>)
           WHERE outcome = zif_cd_fmon_types=>gc_stage-prism_failed.
        INSERT LINES OF failed_findings( is_ctx   = is_ctx
                                         is_check = is_check
                                         is_file  = <ls_failed> ) INTO TABLE rt_findings.
      ENDLOOP.
      RETURN.
    ENDIF.

    LOOP AT is_ctx-files ASSIGNING FIELD-SYMBOL(<ls_file>).
      IF <ls_file>-outcome = zif_cd_fmon_types=>gc_stage-nack OR <ls_file>-nack_count > 0.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = <ls_file>
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-nack
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-rejected_by_the_bank_record
                                                     iv_v1    = <ls_file>-file_name
                                                     iv_v2    = <ls_file>-nack_count ) ) INTO TABLE rt_findings.
      ELSEIF <ls_file>-outcome = zif_cd_fmon_types=>gc_stage-failed.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = <ls_file>
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-file_failed
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-processing_failed
                                                     iv_v1    = <ls_file>-file_name ) ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.



  METHOD failed_findings.
    DATA(ls_verdict) = zcl_cd_fmon_rules=>failed_verdict( is_file        = is_file
                                                          it_generations = is_ctx-generations
                                                          it_events      = is_ctx-events
                                                          it_failures    = is_ctx-prism_failures
                                                          is_regen       = is_ctx-regen
                                                          iv_now         = is_ctx-now ).
    DATA(lv_name) = name_of( is_file ).
    CASE ls_verdict-code.
      WHEN zif_cd_fmon_types=>gc_check_code-file_replaced.
        " The failure is answered by the regenerated file: information only - the open PRISM_FAILED
        " exception of the file is not raised again and the 5-minute run's reconcile resolves it
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file     = is_file
                 is_check    = is_check
                 iv_code     = ls_verdict-code
                 iv_severity = zif_ca_ops_types=>gc_severity-info
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-file_replaced
                                                      iv_v1    = lv_name
                                                      iv_v2    = name_of( ls_verdict-replaced_by )
                                                      iv_v3    = is_file-gen_group ) ) INTO TABLE rt_findings.
      WHEN zif_cd_fmon_types=>gc_check_code-prism_dup_name.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = is_file
                 is_check   = is_check
                 iv_code    = ls_verdict-code
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-prism_dup_name
                                                     iv_v1    = lv_name
                                                     iv_v2    = ls_verdict-error_code ) ) INTO TABLE rt_findings.
      WHEN OTHERS.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = is_file
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-prism_failed
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-prism_failed
                                                     iv_v1    = lv_name
                                                     iv_v2    = is_file-direction ) ) INTO TABLE rt_findings.
        IF ls_verdict-regen_missing = abap_true.
          INSERT zcl_cd_fmon_util=>new_finding(
                   is_file    = is_file
                   is_check   = is_check
                   iv_code    = zif_cd_fmon_types=>gc_check_code-regen_missing
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-regen_missing
                                                       iv_v1    = lv_name
                                                       iv_v2    = ls_verdict-failed_min
                                                       iv_v3    = is_file-gen_group ) ) INTO TABLE rt_findings.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD name_of.
    rv_name = COND #( WHEN is_file-file_name IS NOT INITIAL THEN is_file-file_name ELSE is_file-file_ref ).
  ENDMETHOD.

ENDCLASS.
