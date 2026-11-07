*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_policy.clas.abap
*& Purpose:
*& Change policy of the configuration apps (design D-3): new entries only
*& where the client records changes (DV1, on a customizing request);
*& existing entries editable in every client (production: direct,
*& change-logged); delete only where new entries are allowed. Also decides
*& whether a transport request is acceptable. Pure: no SQL, no system read.
*& Per table (2026-11-07): a production-maintainable table (similar alerts
*& configurable directly in production) also allows new entries wherever
*& existing ones may be edited; delete stays DV1-only.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-07 | Per-table policy: is_prod_maintainable( ), create_allowed( decision, table ).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: change policy</p>
CLASS zcl_cd_ops_cfg_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! What may be changed in a client with these settings
    CLASS-METHODS decide
      IMPORTING
        is_client          TYPE zif_cd_ops_cfg_types=>ty_client
      RETURNING
        VALUE(rs_decision) TYPE zif_cd_ops_cfg_types=>ty_decision.

    "! The table is production-maintainable (ZIF_CD_OPS_CFG_TYPES=>GC_PROD_MAINTAINABLE, case ignored)
    CLASS-METHODS is_prod_maintainable
      IMPORTING
        iv_table      TYPE clike
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    "! New entries of a table: where the client allows them (DV1), and for a production-maintainable
    "! table also wherever existing entries may be edited (production: direct, change-logged)
    CLASS-METHODS create_allowed
      IMPORTING
        is_decision       TYPE zif_cd_ops_cfg_types=>ty_decision
        iv_table          TYPE clike OPTIONAL
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    "! Message when the request cannot take the changes; initial when it can
    "! or when this client does not record changes
    CLASS-METHODS request_error
      IMPORTING
        is_decision       TYPE zif_cd_ops_cfg_types=>ty_decision
        iv_request        TYPE zif_cd_ops_cfg_types=>ty_request
        is_info           TYPE zif_cd_ops_cfg_types=>ty_request_info
      RETURNING
        VALUE(rs_message) TYPE zif_cd_ops_cfg_types=>ty_message.

ENDCLASS.



CLASS zcl_cd_ops_cfg_policy IMPLEMENTATION.

  METHOD decide.
    " Existing entries can always be corrected (production: direct, change-logged)
    rs_decision-update_allowed = abap_true.

    IF is_client-role = zif_cd_ops_cfg_types=>gc_role_production
       OR is_client-change_option = zif_cd_ops_cfg_types=>gc_change_option-no_changes
       OR is_client-change_option = zif_cd_ops_cfg_types=>gc_change_option-no_transports.
      RETURN.
    ENDIF.

    rs_decision-create_allowed     = abap_true.
    rs_decision-delete_allowed     = abap_true.
    rs_decision-transport_required = xsdbool( is_client-change_option =
                                              zif_cd_ops_cfg_types=>gc_change_option-auto_record ).
  ENDMETHOD.


  METHOD is_prod_maintainable.
    DATA(lv_table) = to_upper( condense( CONV string( iv_table ) ) ).
    IF lv_table IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_tables) = zcl_cd_ops_util=>split_list( zif_cd_ops_cfg_types=>gc_prod_maintainable ).
    rv_yes = xsdbool( line_exists( lt_tables[ table_line = lv_table ] ) ).
  ENDMETHOD.


  METHOD create_allowed.
    rv_allowed = xsdbool( is_decision-create_allowed = abap_true
                          OR ( is_decision-update_allowed = abap_true AND is_prod_maintainable( iv_table ) = abap_true ) ).
  ENDMETHOD.


  METHOD request_error.
    IF is_decision-transport_required = abap_false.
      RETURN.
    ENDIF.

    rs_message-v1 = iv_request.
    IF iv_request IS INITIAL.
      rs_message-number = zif_cd_ops_cfg_types=>gc_msg-request_missing.
    ELSEIF is_info-exists = abap_false.
      rs_message-number = zif_cd_ops_cfg_types=>gc_msg-request_unknown.
    ELSEIF is_info-function <> zif_cd_ops_cfg_types=>gc_request-customizing_request
       AND is_info-function <> zif_cd_ops_cfg_types=>gc_request-customizing_task.
      rs_message-number = zif_cd_ops_cfg_types=>gc_msg-request_not_cust.
    ELSEIF is_info-status <> zif_cd_ops_cfg_types=>gc_request-modifiable
       AND is_info-status <> zif_cd_ops_cfg_types=>gc_request-modifiable_protected.
      rs_message-number = zif_cd_ops_cfg_types=>gc_msg-request_released.
    ELSE.
      CLEAR rs_message.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
