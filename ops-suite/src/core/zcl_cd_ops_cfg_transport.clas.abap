*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_transport.clas.abap
*& Purpose:
*& Records the customizing rows changed in one RAP save on a customizing
*& request, through SAP's business-configuration CTS API for RAP
*& (MBC_CP_API). The only class that touches that API; called by
*& ZCL_CD_OPS_CFG_GATE only where the client records changes (DV1).
*& VERIFY-ADT before activation in DV1 (open MBC_CP_API in ADT):
*&  - class MBC_CP_API, static method RAP_TABLE_CTS with parameter
*&    TABLE_ENTITY_RELATIONS (components ENTITY = BDEF alias, TABLE);
*&  - returned interface IF_MBC_CP_RAP_TABLE_CTS, method RECORD_CHANGES
*&    with TRANSPORT_REQUEST, CREATE, UPDATE, DELETE (REF TO data).
*& If the names differ, adapt only this method; the gate and the behaviour
*& pools do not change. Fallback if the API is not available: function
*& payment engine areas TR_OBJECTS_CHECK / TR_OBJECTS_INSERT with E071K TABU keys
*& (VERIFY-SE37).
*& The API call sits in test seam CTS_API (own test include: error mapping).
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-06 | Test seam CTS_API; API error kept in a local, raised after the seam (coverage gap closure).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: transport recording</p>
CLASS zcl_cd_ops_cfg_transport DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_cfg_transport.

ENDCLASS.



CLASS zcl_cd_ops_cfg_transport IMPLEMENTATION.

  METHOD zif_cd_ops_cfg_transport~record.
    DATA lx_error TYPE REF TO cx_root.
    " VERIFY-ADT: API names and parameters - see the class header
    TEST-SEAM cts_api.
      TRY.
          mbc_cp_api=>rap_table_cts(
            table_entity_relations = VALUE #( FOR ls_relation IN it_relations
                                              ( entity = ls_relation-entity
                                                table  = ls_relation-table ) )
            )->record_changes( transport_request = iv_request
                               create            = ir_create
                               update            = ir_update
                               delete            = ir_delete ).
        CATCH cx_root INTO lx_error.
          " Deliberately broad: whatever the API raises, the save must not go
          " through unrecorded - raised below, the caller aborts the save
      ENDTRY.
    END-TEST-SEAM.
    IF lx_error IS BOUND.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e408(zcd_ops) WITH iv_request
        EXPORTING
          previous = lx_error.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
