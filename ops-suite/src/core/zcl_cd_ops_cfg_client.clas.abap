*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_client.clas.abap
*& Purpose:
*& Repository for the system settings the configuration apps depend on:
*& change option and role of the logon client (T000, maintained in SCC4)
*& and the state of a transport request or task (E070). An unreadable
*& client is treated as production (no new entries) - fail closed.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: T000 / E070 reads</p>
CLASS zcl_cd_ops_cfg_client DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_cfg_client.

ENDCLASS.



CLASS zcl_cd_ops_cfg_client IMPLEMENTATION.

  METHOD zif_cd_ops_cfg_client~read_client.
    SELECT SINGLE cccoractiv, cccategory
      FROM t000
      WHERE mandt = @sy-mandt
      INTO @DATA(ls_t000).
    IF sy-subrc <> 0.
      rs_client-change_option = zif_cd_ops_cfg_types=>gc_change_option-no_changes.
      rs_client-role          = zif_cd_ops_cfg_types=>gc_role_production.
      RETURN.
    ENDIF.
    rs_client-change_option = ls_t000-cccoractiv.
    rs_client-role          = ls_t000-cccategory.
  ENDMETHOD.


  METHOD zif_cd_ops_cfg_client~read_request.
    SELECT SINGLE trstatus, trfunction
      FROM e070
      WHERE trkorr = @iv_request
      INTO @DATA(ls_e070).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rs_info-exists   = abap_true.
    rs_info-status   = ls_e070-trstatus.
    rs_info-function = ls_e070-trfunction.
  ENDMETHOD.

ENDCLASS.
