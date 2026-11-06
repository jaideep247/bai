*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_duplicate.clas.abap
*& Purpose:
*& Plug-in check DUPLICATE_FILE: the same file generated/received twice
*& (several source rows for one reference) or an earlier file of the same
*& interface with the same name or checksum (FMON_DUP_DAYS history).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - duplicate file</p>
"! Rules: ZCL_CD_FMON_RULES=>IS_DUPLICATE_OF
CLASS zcl_cd_fmon_chk_duplicate DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

ENDCLASS.



CLASS zcl_cd_fmon_chk_duplicate IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    DATA(lt_pool) = is_ctx-files.
    APPEND LINES OF is_ctx-history TO lt_pool.

    LOOP AT is_ctx-files INTO DATA(ls_file).
      IF ls_file-origin_rows > 1.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = ls_file
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-duplicate
                 iv_message = |{ ls_file-file_name }: reported { ls_file-origin_rows } times by the source| )
               INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      LOOP AT lt_pool INTO DATA(ls_other).
        IF zcl_cd_fmon_rules=>is_duplicate_of( is_file = ls_file is_other = ls_other ) = abap_true.
          INSERT zcl_cd_fmon_util=>new_finding(
                   is_file    = ls_file
                   is_check   = is_check
                   iv_code    = zif_cd_fmon_types=>gc_check_code-duplicate
                   iv_message = |{ ls_file-file_name }: same name/checksum as { ls_other-file_name } | &&
                                |of { ls_other-business_date }| ) INTO TABLE rt_findings.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
