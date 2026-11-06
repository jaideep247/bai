*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_size.clas.abap
*& Purpose:
*& Plug-in check ZERO_BYTE / SIZE_OUT_OF_BOUNDS against MIN_BYTES and
*& MAX_BYTES of the interface (only when a source reports the size).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - zero-byte / size out of bounds</p>
"! Rules: ZCL_CD_FMON_RULES=>SIZE_CODE
CLASS zcl_cd_fmon_chk_size DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

ENDCLASS.



CLASS zcl_cd_fmon_chk_size IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    LOOP AT is_ctx-files ASSIGNING FIELD-SYMBOL(<ls_file>).
      READ TABLE is_ctx-ifaces INTO DATA(ls_iface) WITH TABLE KEY iface_id = <ls_file>-iface_id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_code) = zcl_cd_fmon_rules=>size_code( is_file = <ls_file> is_iface = ls_iface ).
      IF lv_code IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT zcl_cd_fmon_util=>new_finding(
               is_file    = <ls_file>
               is_check   = is_check
               iv_code    = lv_code
               iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-bytes_min_max
                                                   iv_v1    = <ls_file>-file_name
                                                   iv_v2    = <ls_file>-size_bytes
                                                   iv_v3    = ls_iface-min_bytes
                                                   iv_v4    = ls_iface-max_bytes ) ) INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
