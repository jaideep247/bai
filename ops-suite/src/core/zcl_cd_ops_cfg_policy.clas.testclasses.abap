*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_policy.clas.testclasses.abap
*& Purpose:
*& Domain tests of the configuration change policy: new entries only where
*& the client records changes (DV1), existing entries editable everywhere,
*& transport request checked where changes are recorded. Pure logic; does
*& not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (written before the class, RAP config apps).
*&---------------------------------------------------------------------*
CLASS ltc_policy DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_request TYPE zif_cd_ops_cfg_types=>ty_request VALUE 'DV1K900123'.

    METHODS dv1_allows_all_with_transport FOR TESTING.
    METHODS production_updates_only       FOR TESTING.
    METHODS no_changes_client_updates_only FOR TESTING.
    METHODS sandbox_needs_no_transport    FOR TESTING.
    METHODS production_role_wins          FOR TESTING.
    METHODS missing_request_is_rejected   FOR TESTING.
    METHODS unknown_request_is_rejected   FOR TESTING.
    METHODS workbench_request_rejected    FOR TESTING.
    METHODS released_request_rejected     FOR TESTING.
    METHODS open_cust_task_is_accepted    FOR TESTING.
    METHODS no_check_where_not_recorded   FOR TESTING.

    METHODS client
      IMPORTING
        iv_option        TYPE zif_cd_ops_cfg_types=>ty_change_option
        iv_role          TYPE zif_cd_ops_cfg_types=>ty_client_role OPTIONAL
      RETURNING
        VALUE(rs_client) TYPE zif_cd_ops_cfg_types=>ty_client.

    METHODS decision
      IMPORTING
        iv_create          TYPE abap_bool
        iv_delete          TYPE abap_bool
        iv_transport       TYPE abap_bool
      RETURNING
        VALUE(rs_decision) TYPE zif_cd_ops_cfg_types=>ty_decision.

    METHODS request
      IMPORTING
        iv_exists      TYPE abap_bool
        iv_status      TYPE zif_cd_ops_cfg_types=>ty_req_status
        iv_function    TYPE zif_cd_ops_cfg_types=>ty_req_function
      RETURNING
        VALUE(rs_info) TYPE zif_cd_ops_cfg_types=>ty_request_info.

    METHODS dv1_decision
      RETURNING
        VALUE(rs_decision) TYPE zif_cd_ops_cfg_types=>ty_decision.
ENDCLASS.


CLASS ltc_policy IMPLEMENTATION.

  METHOD client.
    rs_client-change_option = iv_option.
    rs_client-role          = iv_role.
  ENDMETHOD.


  METHOD decision.
    rs_decision-create_allowed     = iv_create.
    rs_decision-update_allowed     = abap_true.
    rs_decision-delete_allowed     = iv_delete.
    rs_decision-transport_required = iv_transport.
  ENDMETHOD.


  METHOD request.
    rs_info-exists   = iv_exists.
    rs_info-status   = iv_status.
    rs_info-function = iv_function.
  ENDMETHOD.


  METHOD dv1_decision.
    rs_decision = decision( iv_create = abap_true iv_delete = abap_true iv_transport = abap_true ).
  ENDMETHOD.


  " Rule: the customizing client (automatic recording) allows create, update and
  " delete, and every change goes on a transport
  METHOD dv1_allows_all_with_transport.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ops_cfg_policy=>decide( client( zif_cd_ops_cfg_types=>gc_change_option-auto_record ) )
          exp = dv1_decision( )
          msg = 'DV1: create, update, delete allowed, transport required' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: production - existing entries are edited directly; nothing new, nothing deleted
  METHOD production_updates_only.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ops_cfg_policy=>decide( client( iv_option = zif_cd_ops_cfg_types=>gc_change_option-no_changes
                                                      iv_role   = zif_cd_ops_cfg_types=>gc_role_production ) )
          exp = decision( iv_create = abap_false iv_delete = abap_false iv_transport = abap_false )
          msg = 'Production: update only, no transport' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a client closed for changes (QA1) behaves like production
  METHOD no_changes_client_updates_only.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ops_cfg_policy=>decide( client( zif_cd_ops_cfg_types=>gc_change_option-no_transports ) )
          exp = decision( iv_create = abap_false iv_delete = abap_false iv_transport = abap_false )
          msg = 'Client without transports: update only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a sandbox client (changes without recording) allows all, without transport
  METHOD sandbox_needs_no_transport.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ops_cfg_policy=>decide( client( zif_cd_ops_cfg_types=>gc_change_option-no_recording ) )
          exp = decision( iv_create = abap_true iv_delete = abap_true iv_transport = abap_false )
          msg = 'Sandbox: all changes, no transport' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a production client never accepts new entries, even if SCC4 is left open
  METHOD production_role_wins.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ops_cfg_policy=>decide( client( iv_option = zif_cd_ops_cfg_types=>gc_change_option-auto_record
                                                      iv_role   = zif_cd_ops_cfg_types=>gc_role_production ) )
          exp = decision( iv_create = abap_false iv_delete = abap_false iv_transport = abap_false )
          msg = 'Production role overrides an open change option' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: where changes are recorded, saving without a request is refused
  METHOD missing_request_is_rejected.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ops_cfg_policy=>request_error( is_decision = dv1_decision( )
                                                      iv_request  = space
                                                      is_info     = VALUE #( ) )-number
          exp = zif_cd_ops_cfg_types=>gc_msg-request_missing
          msg = 'Missing request must give message 402' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a request that does not exist is refused
  METHOD unknown_request_is_rejected.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ops_cfg_policy=>request_error( is_decision = dv1_decision( )
                                                      iv_request  = gc_request
                                                      is_info     = request( iv_exists   = abap_false
                                                                             iv_status   = space
                                                                             iv_function = space ) )-number
          exp = zif_cd_ops_cfg_types=>gc_msg-request_unknown
          msg = 'Unknown request must give message 403' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: customizing goes on a customizing request, not a workbench request (K)
  METHOD workbench_request_rejected.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ops_cfg_policy=>request_error(
                  is_decision = dv1_decision( )
                  iv_request  = gc_request
                  is_info     = request( iv_exists   = abap_true
                                         iv_status   = zif_cd_ops_cfg_types=>gc_request-modifiable
                                         iv_function = 'K' ) )-number
          exp = zif_cd_ops_cfg_types=>gc_msg-request_not_cust
          msg = 'Workbench request must give message 404' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a released request cannot take new changes
  METHOD released_request_rejected.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ops_cfg_policy=>request_error(
                  is_decision = dv1_decision( )
                  iv_request  = gc_request
                  is_info     = request( iv_exists   = abap_true
                                         iv_status   = 'R'
                                         iv_function = zif_cd_ops_cfg_types=>gc_request-customizing_request ) )-number
          exp = zif_cd_ops_cfg_types=>gc_msg-request_released
          msg = 'Released request must give message 405' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an open customizing task is a valid target
  METHOD open_cust_task_is_accepted.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_ops_cfg_policy=>request_error(
                  is_decision = dv1_decision( )
                  iv_request  = gc_request
                  is_info     = request( iv_exists   = abap_true
                                         iv_status   = zif_cd_ops_cfg_types=>gc_request-modifiable
                                         iv_function = zif_cd_ops_cfg_types=>gc_request-customizing_task ) )
          msg = 'An open customizing task must be accepted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: where nothing is recorded (production, sandbox) the request is not checked
  METHOD no_check_where_not_recorded.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = zcl_cd_ops_cfg_policy=>request_error(
                  is_decision = decision( iv_create = abap_false iv_delete = abap_false iv_transport = abap_false )
                  iv_request  = space
                  is_info     = VALUE #( ) )
          msg = 'No request needed where changes are not recorded' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
