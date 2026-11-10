*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_system.clas.abap
*& Purpose:
*& SAP APIs behind ZIF_CA_PARAM_SYSTEM, one thin method each:
*&  - read_client: T000 (role CCCATEGORY, change option CCCORACTIV) and the
*&    business configuration API CL_BCFG_CD_REUSE_API_FACTORY (is the
*&    customizing table ZCA_PARAM_DEF editable in this client); unreadable
*&    = production / not editable (fail closed), the API's error text is
*&    returned as CUST_REASON (message 048 in the app);
*&  - read_request: E070 (TRSTATUS, TRFUNCTION);
*&  - is_authorized: AUTHORITY-CHECK OBJECT ZCA_PARAM (ZCA_PARAR, ACTVT);
*&  - record_changes: MBC_CP_API=>RAP_TABLE_CTS( )->RECORD_CHANGES.
*& VERIFY-ADT (DV1, before activation): CL_BCFG_CD_REUSE_API_FACTORY=>
*& GET_CUST_OBJ_SERVICE_INSTANCE( iv_objectname iv_objecttype )->IS_EDITABLE,
*& constant SIMPLE_TABLE; MBC_CP_API=>RAP_TABLE_CTS( table_entity_relations )
*& ->RECORD_CHANGES( transport_request create update delete ). If a name
*& differs, adapt only this class. Exempt from unit tests (wrapper of SAP
*& APIs only, docs/DESIGN.md section 9); its callers are tested with a double.
*& Modification log:
*& 2026-11-07 | Initial version.
*& 2026-11-10 | Fail closed keeps the reason: CUST_REASON = error text of the configuration API.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - SAP APIs of the app</p>
CLASS zcl_ca_param_system DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_param_system.

ENDCLASS.



CLASS zcl_ca_param_system IMPLEMENTATION.

  METHOD zif_ca_param_system~read_client.
    SELECT SINGLE cccategory, cccoractiv
      FROM t000
      WHERE mandt = @sy-mandt
      INTO @DATA(ls_t000).
    IF sy-subrc <> 0.
      rs_client-role          = zif_ca_param_types=>gc_role_production.
      rs_client-change_option = zif_ca_param_types=>gc_change_option-no_changes.
      RETURN.
    ENDIF.
    rs_client-role          = ls_t000-cccategory.
    rs_client-change_option = ls_t000-cccoractiv.
    TRY.
        " VERIFY-ADT: business configuration API (client settings + table delivery class)
        rs_client-cust_editable = cl_bcfg_cd_reuse_api_factory=>get_cust_obj_service_instance(
                                    iv_objectname = CONV #( zif_ca_param_types=>gc_table-definition )
                                    iv_objecttype = cl_bcfg_cd_reuse_api_factory=>simple_table )->is_editable( ).
      CATCH cx_root INTO DATA(lx_error).
        " Deliberately broad: any failure of the API means "not editable" (fail closed);
        " the reason is kept for the app message (048), never dropped
        rs_client-cust_editable = abap_false.
        rs_client-cust_reason   = lx_error->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_param_system~read_request.
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


  METHOD zif_ca_param_system~is_authorized.
    IF iv_area IS INITIAL.
      AUTHORITY-CHECK OBJECT zif_ca_param_types=>gc_auth-object
        ID zif_ca_param_types=>gc_auth-area DUMMY
        ID zif_ca_param_types=>gc_auth-actvt FIELD iv_actvt.
    ELSE.
      AUTHORITY-CHECK OBJECT zif_ca_param_types=>gc_auth-object
        ID zif_ca_param_types=>gc_auth-area FIELD iv_area
        ID zif_ca_param_types=>gc_auth-actvt FIELD iv_actvt.
    ENDIF.
    rv_allowed = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD zif_ca_param_system~record_changes.
    DATA lx_error TYPE REF TO cx_root.

    TRY.
        " VERIFY-ADT: API names and parameters - see the class header
        mbc_cp_api=>rap_table_cts(
          table_entity_relations = VALUE #( FOR ls_relation IN it_relations
                                            ( entity = ls_relation-entity
                                              table  = ls_relation-table ) )
          )->record_changes( transport_request = iv_request
                             create            = ir_create
                             update            = ir_update
                             delete            = ir_delete ).
      CATCH cx_root INTO lx_error.
        " Deliberately broad: whatever the API raises, the save must not go through unrecorded
    ENDTRY.
    IF lx_error IS BOUND.
      RAISE EXCEPTION zcx_ca_param=>create( is_message  = VALUE #( msgid = zif_ca_param_types=>gc_msgid
                                                                   msgno = zif_ca_param_types=>gc_msg-record_failed
                                                                   v1    = iv_request )
                                            ix_previous = lx_error ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
