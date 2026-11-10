*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_noc_aging.clas.abap
*& Purpose:
*& Plug-in check NOC_AGING (compliance, severity from config, E) when a
*& NOC stays unapplied beyond its banking-day SLA (default 6), and
*& NOC_DUE_TODAY (W) on the last allowed banking day.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - NOC aging (NACHA banking days)</p>
"! Rules: ZCL_CD_FMON_RULES=>NOC_AGING_CODE. Banking days come from the engine (calendar).
CLASS zcl_cd_fmon_chk_noc_aging DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

ENDCLASS.



CLASS zcl_cd_fmon_chk_noc_aging IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    LOOP AT is_ctx-lots ASSIGNING FIELD-SYMBOL(<ls_lot>).
      DATA(lv_code) = zcl_cd_fmon_rules=>noc_aging_code( <ls_lot> ).
      IF lv_code IS INITIAL.
        CONTINUE.
      ENDIF.
      READ TABLE is_ctx-files INTO DATA(ls_file) WITH KEY by_id COMPONENTS file_id = <ls_lot>-file_id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      INSERT zcl_cd_fmon_util=>new_finding(
               is_file     = ls_file
               is_check    = is_check
               iv_code     = lv_code
               iv_severity = COND #( WHEN lv_code = zif_cd_fmon_types=>gc_check_code-noc_due_today
                                     THEN zif_ca_ops_types=>gc_severity-warning )
               iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-noc_entr_ies_open_after
                                                    iv_v1    = ls_file-file_name
                                                    iv_v2    = <ls_lot>-open_items
                                                    iv_v3    = <ls_lot>-age_days
                                                    iv_v4    = <ls_lot>-sla_days ) )
             INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
