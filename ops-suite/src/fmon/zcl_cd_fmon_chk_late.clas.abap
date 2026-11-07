*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_late.clas.abap
*& Purpose:
*& Plug-in check FILE_LATE: a file arrived after its calendar window, or
*& the window has closed and the file is still inside the grace period.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-07 | Check parameter GRACE_MIN and its default from ZIF_CD_FMON_TYPES.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - file late</p>
"! Rules: ZCL_CD_FMON_RULES=>ARRIVED_LATE / EXPECTATION_CODE. Params: GRACE_MIN=60
CLASS zcl_cd_fmon_chk_late DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

ENDCLASS.



CLASS zcl_cd_fmon_chk_late IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    DATA(lv_grace) = zcl_cd_fmon_util=>param_int( iv_params  = is_check-params
                                                  iv_name    = zif_cd_fmon_types=>gc_check_param-grace_min
                                                  iv_default = zif_cd_fmon_types=>gc_check_param_default-grace_min ).
    LOOP AT is_ctx-expects ASSIGNING FIELD-SYMBOL(<ls_expect>).
      DATA(lv_received) = 0.
      LOOP AT is_ctx-files ASSIGNING FIELD-SYMBOL(<ls_file>) USING KEY by_iface
           WHERE iface_id = <ls_expect>-iface_id AND business_date = is_ctx-business_date.
        lv_received += 1.
        IF zcl_cd_fmon_rules=>arrived_late( is_file = <ls_file> is_expect = <ls_expect> ) = abap_true.
          INSERT zcl_cd_fmon_util=>new_finding(
                   is_file    = <ls_file>
                   is_check   = is_check
                   iv_code    = zif_cd_fmon_types=>gc_check_code-file_late
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-first_event_after_the_windo
                                                       iv_v1    = <ls_file>-file_name ) ) INTO TABLE rt_findings.
        ENDIF.
      ENDLOOP.
      IF zcl_cd_fmon_rules=>expectation_code( is_expect    = <ls_expect>
                                              iv_received  = lv_received
                                              iv_now       = is_ctx-now
                                              iv_grace_min = lv_grace ) = zif_cd_fmon_types=>gc_check_code-file_late.
        INSERT zcl_cd_fmon_util=>new_key_finding(
                 iv_iface_id   = <ls_expect>-iface_id
                 iv_object_key = |{ <ls_expect>-iface_id }/{ is_ctx-business_date }|
                 is_check      = is_check
                 iv_code       = zif_cd_fmon_types=>gc_check_code-file_late
                 iv_message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-window_closed_of_file_s
                                                        iv_v1    = <ls_expect>-iface_id
                                                        iv_v2    = lv_received
                                                        iv_v3    = <ls_expect>-expected_count ) ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
