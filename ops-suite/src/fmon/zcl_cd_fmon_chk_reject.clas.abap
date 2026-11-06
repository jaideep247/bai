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
*& 2026-11-06 | Parameter OUTCOME=PRISM_FAILED for the PRISM status API (check row F_PRISMFAIL);
*&              without the parameter the behaviour is unchanged.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - bank NACK / failed inbound file</p>
"! Params: OUTCOME= (blank: NACK and FAILED; PRISM_FAILED: only files PRISM reported as failed).
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

ENDCLASS.



CLASS zcl_cd_fmon_chk_reject IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    DATA(lv_outcome) = CONV zif_cd_fmon_types=>ty_stage( to_upper( zcl_cd_fmon_util=>param(
                         iv_params = is_check-params iv_name = gc_param_outcome ) ) ).

    IF lv_outcome = zif_cd_fmon_types=>gc_stage-prism_failed.
      LOOP AT is_ctx-files ASSIGNING FIELD-SYMBOL(<ls_failed>)
           WHERE outcome = zif_cd_fmon_types=>gc_stage-prism_failed.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = <ls_failed>
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-prism_failed
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-prism_failed
                                                     iv_v1    = COND string( WHEN <ls_failed>-file_name IS NOT INITIAL
                                                                             THEN <ls_failed>-file_name
                                                                             ELSE <ls_failed>-file_ref )
                                                     iv_v2    = <ls_failed>-direction ) ) INTO TABLE rt_findings.
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

ENDCLASS.
