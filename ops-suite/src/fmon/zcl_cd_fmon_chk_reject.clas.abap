*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_reject.clas.abap
*& Purpose:
*& Plug-in check NACK (bank rejected the file or payments of it) and
*& FILE_FAILED (inbound file failed to load or process).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - bank NACK / failed inbound file</p>
CLASS zcl_cd_fmon_chk_reject DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

ENDCLASS.



CLASS zcl_cd_fmon_chk_reject IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    LOOP AT is_ctx-files INTO DATA(ls_file).
      IF ls_file-outcome = zif_cd_fmon_types=>gc_stage-nack OR ls_file-nack_count > 0.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = ls_file
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-nack
                 iv_message = |{ ls_file-file_name }: rejected by the bank | &&
                              |({ ls_file-nack_count } record(s) NACK)| ) INTO TABLE rt_findings.
      ELSEIF ls_file-outcome = zif_cd_fmon_types=>gc_stage-failed.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = ls_file
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-file_failed
                 iv_message = |{ ls_file-file_name }: processing FAILED| ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
