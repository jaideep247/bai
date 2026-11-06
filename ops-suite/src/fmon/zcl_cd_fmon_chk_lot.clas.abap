*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_lot.clas.abap
*& Purpose:
*& Plug-in check LOT_UNPROCESSED (transactions of a returns/NOC file not
*& yet accounted for) and LOT_NOT_FOUND (loaded file without any lot).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - returns/NOC not fully processed</p>
"! A file is processed only when zero transactions are unaccounted for.
CLASS zcl_cd_fmon_chk_lot DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

ENDCLASS.



CLASS zcl_cd_fmon_chk_lot IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    LOOP AT is_ctx-lots INTO DATA(ls_lot).
      READ TABLE is_ctx-files INTO DATA(ls_file) WITH KEY file_id = ls_lot-file_id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF ls_lot-open_items > 0.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file    = ls_file
                 is_check   = is_check
                 iv_code    = zif_cd_fmon_types=>gc_check_code-lot_unprocessed
                 iv_message = |{ ls_file-file_name }: { ls_lot-open_items } of { ls_lot-total_items } | &&
                              |{ ls_lot-lot_type } transaction(s) unprocessed ({ ls_lot-open_keys })| )
               INTO TABLE rt_findings.
      ELSEIF ls_lot-found = abap_false
             AND zcl_cd_fmon_status=>rank( ls_file-stage ) >= zcl_cd_fmon_status=>rank( zif_cd_fmon_types=>gc_stage-loaded ).
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file     = ls_file
                 is_check    = is_check
                 iv_code     = zif_cd_fmon_types=>gc_check_code-lot_not_found
                 iv_severity = zif_cd_ops_types=>gc_severity-warning
                 iv_message  = |{ ls_file-file_name }: loaded, but no { ls_lot-lot_type } lot found| )
               INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
