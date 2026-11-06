*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_duplicate.clas.abap
*& Purpose:
*& Plug-in check DUPLICATE_FILE: the same file generated/received twice
*& (several source rows for one reference) or an earlier file of the same
*& interface with the same name or checksum (FMON_DUP_DAYS history).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - duplicate file</p>
"! Rules: ZCL_CD_FMON_RULES=>IS_DUPLICATE_OF. Params: ORIGIN_ROWS=Y|N
CLASS zcl_cd_fmon_chk_duplicate DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

ENDCLASS.



CLASS zcl_cd_fmon_chk_duplicate IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    " ORIGIN_ROWS=N for generation sources that hold one row per payment, not per file
    DATA(lv_rows_check) = xsdbool( zcl_cd_fmon_util=>param( iv_params  = is_check-params
                                                            iv_name    = 'ORIGIN_ROWS'
                                                            iv_default = `Y` ) <> `N` ).
    DATA(lt_pool) = is_ctx-files.
    INSERT LINES OF is_ctx-history INTO TABLE lt_pool.

    LOOP AT is_ctx-files ASSIGNING FIELD-SYMBOL(<ls_file>).
      IF <ls_file>-origin_rows > 1 AND lv_rows_check = abap_true.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = <ls_file>
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-duplicate
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-reported_times_by_the_sourc
                                                     iv_v1    = <ls_file>-file_name
                                                     iv_v2    = <ls_file>-origin_rows ) )
               INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      LOOP AT lt_pool ASSIGNING FIELD-SYMBOL(<ls_other>).
        IF zcl_cd_fmon_rules=>is_duplicate_of( is_file = <ls_file> is_other = <ls_other> ) = abap_true.
          INSERT zcl_cd_fmon_util=>new_finding(
                   is_file    = <ls_file>
                   is_check   = is_check
                   iv_code    = zif_cd_fmon_types=>gc_check_code-duplicate
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-same_name_checksum_as_of
                                                       iv_v1    = <ls_file>-file_name
                                                       iv_v2    = <ls_other>-file_name
                                                       iv_v3    = <ls_other>-business_date ) ) INTO TABLE rt_findings.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
