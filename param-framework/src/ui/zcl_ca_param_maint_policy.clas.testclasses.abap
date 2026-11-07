*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_maint_policy.clas.testclasses.abap
*& Purpose:
*& Unit tests of the maintenance change policy (pure): mode per client
*& settings, configuration only by transport, values editable in a local
*& client only for PROD_EDITABLE areas and parameters not owned by
*& development, customizing request rules. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
CLASS ltc_policy DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_request TYPE zif_ca_param_types=>ty_request VALUE 'DV1K900001'.
    CONSTANTS gc_area    TYPE zif_ca_param_types=>ty_area VALUE 'ZTEST'.
    CONSTANTS gc_test    TYPE zif_ca_param_types=>ty_role VALUE 'T'.

    METHODS client
      IMPORTING
        iv_role          TYPE zif_ca_param_types=>ty_role
        iv_change_option TYPE zif_ca_param_types=>ty_change_opt
        iv_editable      TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rs_client) TYPE zif_ca_param_types=>ty_client.

    METHODS request_msgno
      IMPORTING
        iv_request      TYPE zif_ca_param_types=>ty_request
        is_info         TYPE zif_ca_param_types=>ty_request_info
      RETURNING
        VALUE(rv_msgno) TYPE symsgno.

    METHODS recording_client_transport FOR TESTING.
    METHODS production_is_local FOR TESTING.
    METHODS no_recording_is_local FOR TESTING.
    METHODS not_editable_is_local FOR TESTING.
    METHODS config_only_by_transport FOR TESTING.
    METHODS value_rules_in_local_mode FOR TESTING.
    METHODS value_always_in_transport FOR TESTING.
    METHODS edit_area_rules FOR TESTING.
    METHODS request_rules FOR TESTING.
    METHODS no_request_needed_locally FOR TESTING.
ENDCLASS.


CLASS ltc_policy IMPLEMENTATION.

  METHOD client.
    rs_client-role          = iv_role.
    rs_client-change_option = iv_change_option.
    rs_client-cust_editable = iv_editable.
  ENDMETHOD.


  METHOD request_msgno.
    rv_msgno = zcl_ca_param_maint_policy=>request_message( iv_mode    = zif_ca_param_types=>gc_mode-transport
                                                           iv_area    = gc_area
                                                           iv_request = iv_request
                                                           is_info    = is_info )-msgno.
  ENDMETHOD.


  METHOD recording_client_transport.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_param_maint_policy=>mode( client( iv_role          = gc_test
                                                     iv_change_option = zif_ca_param_types=>gc_change_option-auto_record ) )
      exp = zif_ca_param_types=>gc_mode-transport
      msg = `Customizing client with automatic recording: transport mode` ).
  ENDMETHOD.


  METHOD production_is_local.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_param_maint_policy=>mode( client( iv_role          = zif_ca_param_types=>gc_role_production
                                                     iv_change_option = zif_ca_param_types=>gc_change_option-auto_record ) )
      exp = zif_ca_param_types=>gc_mode-local
      msg = `A production client is never in transport mode` ).
  ENDMETHOD.


  METHOD no_recording_is_local.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_param_maint_policy=>mode( client( iv_role          = gc_test
                                                     iv_change_option = zif_ca_param_types=>gc_change_option-no_recording ) )
      exp = zif_ca_param_types=>gc_mode-local
      msg = `Changes without recording cannot be transported: local mode` ).
  ENDMETHOD.


  METHOD not_editable_is_local.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_param_maint_policy=>mode( client( iv_role          = gc_test
                                                     iv_change_option = zif_ca_param_types=>gc_change_option-auto_record
                                                     iv_editable      = abap_false ) )
      exp = zif_ca_param_types=>gc_mode-local
      msg = `Customizing not editable per business configuration API: local mode` ).
  ENDMETHOD.


  METHOD config_only_by_transport.
    cl_abap_unit_assert=>assert_true( act = zcl_ca_param_maint_policy=>can_maintain_config( zif_ca_param_types=>gc_mode-transport )
                                      msg = `Definitions in transport mode` ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_param_maint_policy=>can_maintain_config( zif_ca_param_types=>gc_mode-local )
                                       msg = `No definitions in a local client` ).
  ENDMETHOD.


  METHOD value_rules_in_local_mode.
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_param_maint_policy=>can_change_value( iv_mode            = zif_ca_param_types=>gc_mode-local
                                                         iv_prod_editable   = abap_true
                                                         iv_developer_owned = abap_false )
      msg = `Production-editable area, business-owned parameter: editable` ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_param_maint_policy=>can_change_value( iv_mode            = zif_ca_param_types=>gc_mode-local
                                                         iv_prod_editable   = abap_true
                                                         iv_developer_owned = abap_true )
      msg = `Developer-owned parameter: transport only` ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_param_maint_policy=>can_change_value( iv_mode            = zif_ca_param_types=>gc_mode-local
                                                         iv_prod_editable   = abap_false
                                                         iv_developer_owned = abap_false )
      msg = `Area not production-editable: transport only` ).
  ENDMETHOD.


  METHOD value_always_in_transport.
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_param_maint_policy=>can_change_value( iv_mode            = zif_ca_param_types=>gc_mode-transport
                                                         iv_prod_editable   = abap_false
                                                         iv_developer_owned = abap_true )
      msg = `Every value in transport mode` ).
  ENDMETHOD.


  METHOD edit_area_rules.
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_param_maint_policy=>can_edit_area( iv_mode          = zif_ca_param_types=>gc_mode-local
                                                      iv_prod_editable = abap_true )
      msg = `A production-editable area can be opened locally` ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_param_maint_policy=>can_edit_area( iv_mode          = zif_ca_param_types=>gc_mode-local
                                                      iv_prod_editable = abap_false )
      msg = `Other areas are read-only locally` ).
  ENDMETHOD.


  METHOD request_rules.
    DATA ls_info TYPE zif_ca_param_types=>ty_request_info.

    cl_abap_unit_assert=>assert_equals( act = request_msgno( iv_request = space is_info = ls_info )
                                        exp = zif_ca_param_types=>gc_msg-request_missing
                                        msg = `No request` ).
    cl_abap_unit_assert=>assert_equals( act = request_msgno( iv_request = gc_request is_info = ls_info )
                                        exp = zif_ca_param_types=>gc_msg-request_unknown
                                        msg = `Unknown request` ).
    ls_info-exists   = abap_true.
    ls_info-function = 'K'.
    ls_info-status   = zif_ca_param_types=>gc_request-modifiable.
    cl_abap_unit_assert=>assert_equals( act = request_msgno( iv_request = gc_request is_info = ls_info )
                                        exp = zif_ca_param_types=>gc_msg-request_not_cust
                                        msg = `Workbench request` ).
    ls_info-function = zif_ca_param_types=>gc_request-customizing_task.
    ls_info-status   = 'R'.
    cl_abap_unit_assert=>assert_equals( act = request_msgno( iv_request = gc_request is_info = ls_info )
                                        exp = zif_ca_param_types=>gc_msg-request_released
                                        msg = `Released task` ).
    ls_info-status = zif_ca_param_types=>gc_request-modifiable.
    cl_abap_unit_assert=>assert_initial( act = request_msgno( iv_request = gc_request is_info = ls_info )
                                         msg = `Modifiable customizing task` ).
  ENDMETHOD.


  METHOD no_request_needed_locally.
    DATA ls_info TYPE zif_ca_param_types=>ty_request_info.

    cl_abap_unit_assert=>assert_initial(
      act = zcl_ca_param_maint_policy=>request_message( iv_mode    = zif_ca_param_types=>gc_mode-local
                                                        iv_area    = gc_area
                                                        iv_request = space
                                                        is_info    = ls_info )
      msg = `Local clients do not record: no request` ).
  ENDMETHOD.

ENDCLASS.
