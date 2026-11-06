*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_missing.clas.abap
*& Purpose:
*& Plug-in check FILE_MISSING / UNEXPECTED_FILE: compares files received for
*& the business date with the interface calendar (ZCD_FMON_CAL).
*& Parameter GRACE_MIN (default 60) after the window end.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - expected file missing</p>
"! Rules: ZCL_CD_FMON_RULES=>EXPECTATION_CODE. Params: GRACE_MIN=60
CLASS zcl_cd_fmon_chk_missing DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

ENDCLASS.



CLASS zcl_cd_fmon_chk_missing IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    DATA(lv_grace) = zcl_cd_fmon_util=>param_int( iv_params  = is_check-params
                                                  iv_name    = 'GRACE_MIN'
                                                  iv_default = 60 ).
    LOOP AT is_ctx-expects INTO DATA(ls_expect).
      DATA(lv_received) = REDUCE i( INIT n = 0
                                    FOR ls_file IN is_ctx-files
                                    WHERE ( iface_id = ls_expect-iface_id AND business_date = is_ctx-business_date )
                                    NEXT n = n + 1 ).
      DATA(lv_code) = zcl_cd_fmon_rules=>expectation_code( is_expect    = ls_expect
                                                          iv_received  = lv_received
                                                          iv_now       = is_ctx-now
                                                          iv_grace_min = lv_grace ).
      CASE lv_code.
        WHEN zif_cd_fmon_types=>gc_check_code-file_missing.
          INSERT zcl_cd_fmon_util=>new_key_finding(
                   iv_iface_id   = ls_expect-iface_id
                   iv_object_key = |{ ls_expect-iface_id }/{ is_ctx-business_date }|
                   is_check      = is_check
                   iv_code       = lv_code
                   iv_message    = |{ ls_expect-iface_id }: { lv_received } of { ls_expect-expected_count } | &&
                                   |expected file(s) received ({ ls_expect-day_type })| ) INTO TABLE rt_findings.
        WHEN zif_cd_fmon_types=>gc_check_code-unexpected_file.
          INSERT zcl_cd_fmon_util=>new_key_finding(
                   iv_iface_id   = ls_expect-iface_id
                   iv_object_key = |{ ls_expect-iface_id }/{ is_ctx-business_date }|
                   is_check      = is_check
                   iv_code       = lv_code
                   iv_severity   = zif_cd_ops_types=>gc_severity-warning
                   iv_message    = |{ ls_expect-iface_id }: { lv_received } file(s) on a { ls_expect-day_type } | &&
                                   |day that expects none| ) INTO TABLE rt_findings.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
