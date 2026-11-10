*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_ack_match.clas.abap
*& Purpose:
*& Plug-in check ACK_COUNT_MISMATCH / ACK_AMOUNT_MISMATCH: the bank ack
*& must confirm the file's record count and control total (TOLERANCE).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - ack count / amount mismatch</p>
"! Rules: ZCL_CD_FMON_RULES=>ACK_COUNT_MISMATCH / ACK_AMOUNT_MISMATCH. Params: TOLERANCE=0.01
CLASS zcl_cd_fmon_chk_ack_match DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

ENDCLASS.



CLASS zcl_cd_fmon_chk_ack_match IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    DATA(lv_tolerance) = CONV zif_ca_ops_types=>ty_amount( zcl_ca_ops_util=>to_decimal(
                           iv_value   = zcl_cd_fmon_util=>param( iv_params = is_check-params iv_name = 'TOLERANCE' )
                           iv_default = '0.01' ) ).
    LOOP AT is_ctx-files ASSIGNING FIELD-SYMBOL(<ls_file>).
      READ TABLE is_ctx-ifaces INTO DATA(ls_iface) WITH TABLE KEY iface_id = <ls_file>-iface_id.
      IF sy-subrc <> 0 OR ls_iface-ack_expected = abap_false.
        CONTINUE.
      ENDIF.
      IF zcl_cd_fmon_rules=>ack_count_mismatch( <ls_file> ) = abap_true.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = <ls_file>
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-ack_count
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-record_s_sent_ack_nack
                                                     iv_v1    = <ls_file>-file_name
                                                     iv_v2    = <ls_file>-record_count
                                                     iv_v3    = <ls_file>-ack_count
                                                     iv_v4    = <ls_file>-nack_count ) ) INTO TABLE rt_findings.
      ENDIF.
      IF zcl_cd_fmon_rules=>ack_amount_mismatch( is_file = <ls_file> iv_tolerance = lv_tolerance ) = abap_true.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = <ls_file>
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-ack_amount
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-control_total_acknowledged
                                                     iv_v1    = <ls_file>-file_name
                                                     iv_v2    = <ls_file>-control_total
                                                     iv_v3    = <ls_file>-ack_amount ) ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
