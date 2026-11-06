*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_noc_aging.clas.abap
*& Purpose:
*& Plug-in check NOC_AGING (compliance, severity from config, E) when a
*& NOC stays unapplied beyond its banking-day SLA (default 6), and
*& NOC_DUE_TODAY (W) on the last allowed banking day.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
    LOOP AT is_ctx-lots INTO DATA(ls_lot).
      DATA(lv_code) = zcl_cd_fmon_rules=>noc_aging_code( ls_lot ).
      IF lv_code IS INITIAL.
        CONTINUE.
      ENDIF.
      READ TABLE is_ctx-files INTO DATA(ls_file) WITH KEY file_id = ls_lot-file_id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      INSERT zcl_cd_fmon_util=>new_finding(
               is_file     = ls_file
               is_check    = is_check
               iv_code     = lv_code
               iv_severity = COND #( WHEN lv_code = zif_cd_fmon_types=>gc_check_code-noc_due_today
                                     THEN zif_cd_ops_types=>gc_severity-warning )
               iv_message  = |{ ls_file-file_name }: { ls_lot-open_items } NOC entr(ies) open after | &&
                             |{ ls_lot-age_days } banking day(s) (NACHA limit { ls_lot-sla_days })| )
             INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
