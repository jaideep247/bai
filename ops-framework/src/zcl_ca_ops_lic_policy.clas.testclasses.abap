*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_lic_policy.clas.testclasses.abap
*& Purpose:
*& Tests of the pure licence decision: no licence installed (CORE runs,
*& every other module not licensed - runs under W, refused under X),
*& licensed, expiring within the warning days, in grace after the end,
*& expired after the grace period, not granted, not yet valid, signature
*& invalid, signer not the vendor, payload not readable, binding to another
*& installation / system / client (a licence without client binds every
*& client), product version out of range, an unknown module, the version
*& comparison and impossible dates. No database, no SSF.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
CLASS ltc_lic_policy DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        today        TYPE d VALUE '20261115',
        installation TYPE string VALUE `0020123456`,
        other_inst   TYPE string VALUE `0020999999`,
        sysid        TYPE c LENGTH 8 VALUE 'PS4',
        client       TYPE c LENGTH 3 VALUE '100',
        version      TYPE string VALUE `1.0.0`,
        license_id   TYPE string VALUE `ZT-LIC-0001`,
        unknown      TYPE zif_ca_ops_lic_types=>ty_module VALUE 'ZT_UNKNOWN',
      END OF gc.

    DATA ms_input TYPE zif_ca_ops_lic_types=>ty_input.

    METHODS setup.
    "! Grant one module of the payload
    METHODS grant
      IMPORTING
        iv_module TYPE zif_ca_ops_lic_types=>ty_module
        iv_from   TYPE c
        iv_to     TYPE c.
    METHODS state_of
      IMPORTING
        iv_module       TYPE zif_ca_ops_lic_types=>ty_module
      RETURNING
        VALUE(rs_state) TYPE zif_ca_ops_lic_types=>ty_module_state.

    METHODS missing_licence_core_only    FOR TESTING.
    METHODS missing_refused_under_x      FOR TESTING.
    METHODS licensed_module_runs         FOR TESTING.
    METHODS expiring_within_warn_days    FOR TESTING.
    METHODS grace_runs_under_x           FOR TESTING.
    METHODS expired_refused_under_x      FOR TESTING.
    METHODS expired_warns_under_w        FOR TESTING.
    METHODS not_granted_is_unlicensed    FOR TESTING.
    METHODS not_yet_valid_is_unlicensed  FOR TESTING.
    METHODS signature_invalid            FOR TESTING.
    METHODS signer_not_vendor            FOR TESTING.
    METHODS payload_not_readable         FOR TESTING.
    METHODS other_installation_binding   FOR TESTING.
    METHODS other_client_binding         FOR TESTING.
    METHODS blank_client_binds_all       FOR TESTING.
    METHODS version_out_of_range         FOR TESTING.
    METHODS unknown_module_decision      FOR TESTING.
    METHODS version_comparison           FOR TESTING.
    METHODS impossible_date_is_initial   FOR TESTING.
ENDCLASS.


CLASS ltc_lic_policy IMPLEMENTATION.

  METHOD setup.
    ms_input = VALUE #(
      installed = abap_true
      readable  = abap_true
      verified  = VALUE #( ok = abap_true signer = zif_ca_ops_lic_types=>gc_vendor-subject )
      payload   = VALUE #( format        = zif_ca_ops_lic_types=>gc_format
                           license_id    = gc-license_id
                           product       = zif_ca_ops_lic_types=>gc_vendor-product
                           installations = VALUE #( ( gc-installation ) )
                           systems       = VALUE #( ( sid = 'PS4' client = '100' ) )
                           version_from  = `1.0`
                           version_to    = `1`
                           grace_days    = 30 )
      system    = VALUE #( installations = VALUE #( ( gc-installation ) )
                           sysid         = gc-sysid
                           client        = gc-client
                           version       = gc-version )
      today     = gc-today
      warn_days = 30
      enforce   = zif_ca_ops_lic_types=>gc_enforce-refuse
      map       = VALUE #( ( obj_kind = zif_ca_ops_lic_types=>gc_kind-module obj_name = 'CORE'
                             module   = zif_ca_ops_lic_types=>gc_module-core always = abap_true )
                           ( obj_kind = zif_ca_ops_lic_types=>gc_kind-module obj_name = 'JOBS'
                             module   = zif_ca_ops_lic_types=>gc_module-jobs )
                           ( obj_kind = zif_ca_ops_lic_types=>gc_kind-module obj_name = 'FLOW'
                             module   = zif_ca_ops_lic_types=>gc_module-flow )
                           ( obj_kind = zif_ca_ops_lic_types=>gc_kind-check_class obj_name = 'ZCL_T_CHECK'
                             module   = zif_ca_ops_lic_types=>gc_module-jobs ) ) ).
  ENDMETHOD.


  METHOD grant.
    INSERT VALUE #( code = iv_module valid_from = iv_from valid_to = iv_to ) INTO TABLE ms_input-payload-modules.
  ENDMETHOD.


  METHOD state_of.
    DATA(ls_status) = zcl_ca_ops_lic_policy=>evaluate( ms_input ).
    READ TABLE ls_status-modules INTO rs_state WITH TABLE KEY module = iv_module.
    cl_abap_unit_assert=>assert_subrc( act = sy-subrc msg = |module { iv_module } missing| ).
  ENDMETHOD.


  METHOD missing_licence_core_only.
    ms_input-installed = abap_false.
    ms_input-enforce   = zif_ca_ops_lic_types=>gc_enforce-warn.
    DATA(ls_status) = zcl_ca_ops_lic_policy=>evaluate( ms_input ).
    cl_abap_unit_assert=>assert_equals( act = ls_status-state exp = zif_ca_ops_lic_types=>gc_lic_state-missing ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_status-modules ) exp = 3 ).
    DATA(ls_core) = ls_status-modules[ module = zif_ca_ops_lic_types=>gc_module-core ].
    cl_abap_unit_assert=>assert_equals( act = ls_core-state exp = zif_ca_ops_lic_types=>gc_state-included ).
    cl_abap_unit_assert=>assert_false( ls_core-warn ).
    DATA(ls_jobs) = ls_status-modules[ module = zif_ca_ops_lic_types=>gc_module-jobs ].
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-state exp = zif_ca_ops_lic_types=>gc_state-unlicensed ).
    " warn only: nothing stops working until the licence is installed
    cl_abap_unit_assert=>assert_true( ls_jobs-runs ).
    cl_abap_unit_assert=>assert_true( ls_jobs-warn ).
  ENDMETHOD.


  METHOD missing_refused_under_x.
    ms_input-installed = abap_false.
    DATA(ls_status) = zcl_ca_ops_lic_policy=>evaluate( ms_input ).
    cl_abap_unit_assert=>assert_false( zcl_ca_ops_lic_policy=>decide( is_status = ls_status
                                                                      iv_module = zif_ca_ops_lic_types=>gc_module-jobs
                                                                    )-allowed ).
    " CORE is never refused
    cl_abap_unit_assert=>assert_true( zcl_ca_ops_lic_policy=>decide( is_status = ls_status
                                                                     iv_module = zif_ca_ops_lic_types=>gc_module-core
                                                                   )-allowed ).
  ENDMETHOD.


  METHOD licensed_module_runs.
    grant( iv_module = zif_ca_ops_lic_types=>gc_module-jobs iv_from = '20261101' iv_to = '20271031' ).
    DATA(ls_jobs) = state_of( zif_ca_ops_lic_types=>gc_module-jobs ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-state exp = zif_ca_ops_lic_types=>gc_state-licensed ).
    cl_abap_unit_assert=>assert_true( ls_jobs-runs ).
    cl_abap_unit_assert=>assert_false( ls_jobs-warn ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-valid_to exp = '20271031' ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-grace_to exp = '20271130' ).
    " a module not granted stays not licensed
    cl_abap_unit_assert=>assert_false( state_of( zif_ca_ops_lic_types=>gc_module-flow )-runs ).
  ENDMETHOD.


  METHOD expiring_within_warn_days.
    grant( iv_module = zif_ca_ops_lic_types=>gc_module-jobs iv_from = '20251201' iv_to = '20261130' ).
    DATA(ls_jobs) = state_of( zif_ca_ops_lic_types=>gc_module-jobs ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-state exp = zif_ca_ops_lic_types=>gc_state-expiring ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-days_left exp = 15 ).
    cl_abap_unit_assert=>assert_true( ls_jobs-runs ).
    cl_abap_unit_assert=>assert_true( ls_jobs-warn ).
    " the last day itself still counts as licensed (0 days left)
    ms_input-today = '20261130'.
    cl_abap_unit_assert=>assert_equals( act = state_of( zif_ca_ops_lic_types=>gc_module-jobs )-state
                                        exp = zif_ca_ops_lic_types=>gc_state-expiring ).
  ENDMETHOD.


  METHOD grace_runs_under_x.
    grant( iv_module = zif_ca_ops_lic_types=>gc_module-jobs iv_from = '20251101' iv_to = '20261031' ).
    DATA(ls_jobs) = state_of( zif_ca_ops_lic_types=>gc_module-jobs ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-state exp = zif_ca_ops_lic_types=>gc_state-grace ).
    cl_abap_unit_assert=>assert_true( ls_jobs-runs ).
    cl_abap_unit_assert=>assert_true( ls_jobs-warn ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-grace_to exp = '20261130' ).
  ENDMETHOD.


  METHOD expired_refused_under_x.
    ms_input-payload-grace_days = 10.
    grant( iv_module = zif_ca_ops_lic_types=>gc_module-jobs iv_from = '20251101' iv_to = '20261031' ).
    DATA(ls_jobs) = state_of( zif_ca_ops_lic_types=>gc_module-jobs ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-state exp = zif_ca_ops_lic_types=>gc_state-expired ).
    cl_abap_unit_assert=>assert_false( ls_jobs-runs ).
  ENDMETHOD.


  METHOD expired_warns_under_w.
    ms_input-enforce = zif_ca_ops_lic_types=>gc_enforce-warn.
    ms_input-payload-grace_days = 0.
    grant( iv_module = zif_ca_ops_lic_types=>gc_module-jobs iv_from = '20251101' iv_to = '20261114' ).
    DATA(ls_jobs) = state_of( zif_ca_ops_lic_types=>gc_module-jobs ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-state exp = zif_ca_ops_lic_types=>gc_state-expired ).
    cl_abap_unit_assert=>assert_true( ls_jobs-runs ).
    cl_abap_unit_assert=>assert_true( ls_jobs-warn ).
  ENDMETHOD.


  METHOD not_granted_is_unlicensed.
    grant( iv_module = zif_ca_ops_lic_types=>gc_module-flow iv_from = '20261101' iv_to = '20271031' ).
    DATA(ls_jobs) = state_of( zif_ca_ops_lic_types=>gc_module-jobs ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-state exp = zif_ca_ops_lic_types=>gc_state-unlicensed ).
    cl_abap_unit_assert=>assert_false( ls_jobs-runs ).
  ENDMETHOD.


  METHOD not_yet_valid_is_unlicensed.
    grant( iv_module = zif_ca_ops_lic_types=>gc_module-jobs iv_from = '20261201' iv_to = '20271130' ).
    cl_abap_unit_assert=>assert_equals( act = state_of( zif_ca_ops_lic_types=>gc_module-jobs )-state
                                        exp = zif_ca_ops_lic_types=>gc_state-unlicensed ).
  ENDMETHOD.


  METHOD signature_invalid.
    grant( iv_module = zif_ca_ops_lic_types=>gc_module-jobs iv_from = '20261101' iv_to = '20271031' ).
    ms_input-verified-ok = abap_false.
    ms_input-verified-return_code = `5`.
    DATA(ls_status) = zcl_ca_ops_lic_policy=>evaluate( ms_input ).
    cl_abap_unit_assert=>assert_equals( act = ls_status-state exp = zif_ca_ops_lic_types=>gc_lic_state-signature ).
    cl_abap_unit_assert=>assert_equals( act = ls_status-detail exp = `5` ).
    " a granted module of a licence that is not the vendor's is not licensed
    cl_abap_unit_assert=>assert_equals( act = ls_status-modules[ module = zif_ca_ops_lic_types=>gc_module-jobs ]-state
                                        exp = zif_ca_ops_lic_types=>gc_state-unlicensed ).
  ENDMETHOD.


  METHOD signer_not_vendor.
    grant( iv_module = zif_ca_ops_lic_types=>gc_module-jobs iv_from = '20261101' iv_to = '20271031' ).
    ms_input-verified-signer = `CN=ZT SELF SIGNED`.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_lic_policy=>evaluate( ms_input )-state
                                        exp = zif_ca_ops_lic_types=>gc_lic_state-signature ).
  ENDMETHOD.


  METHOD payload_not_readable.
    ms_input-readable = abap_false.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_lic_policy=>evaluate( ms_input )-state
                                        exp = zif_ca_ops_lic_types=>gc_lic_state-signature ).
  ENDMETHOD.


  METHOD other_installation_binding.
    grant( iv_module = zif_ca_ops_lic_types=>gc_module-jobs iv_from = '20261101' iv_to = '20271031' ).
    ms_input-system-installations = VALUE #( ( gc-other_inst ) ).
    DATA(ls_status) = zcl_ca_ops_lic_policy=>evaluate( ms_input ).
    cl_abap_unit_assert=>assert_equals( act = ls_status-state exp = zif_ca_ops_lic_types=>gc_lic_state-binding ).
    cl_abap_unit_assert=>assert_true( xsdbool( find( val = ls_status-detail sub = gc-other_inst ) >= 0 ) ).
    cl_abap_unit_assert=>assert_false( ls_status-modules[ module = zif_ca_ops_lic_types=>gc_module-jobs ]-runs ).
  ENDMETHOD.


  METHOD other_client_binding.
    ms_input-system-client = '200'.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_lic_policy=>evaluate( ms_input )-state
                                        exp = zif_ca_ops_lic_types=>gc_lic_state-binding ).
    ms_input-system-client = '100'.
    ms_input-system-sysid  = 'QA1'.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_lic_policy=>evaluate( ms_input )-state
                                        exp = zif_ca_ops_lic_types=>gc_lic_state-binding ).
  ENDMETHOD.


  METHOD blank_client_binds_all.
    ms_input-payload-systems = VALUE #( ( sid = 'PS4' ) ).
    ms_input-system-client = '300'.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_lic_policy=>evaluate( ms_input )-state
                                        exp = zif_ca_ops_lic_types=>gc_lic_state-valid ).
  ENDMETHOD.


  METHOD version_out_of_range.
    ms_input-system-version = `2.0.0`.
    DATA(ls_status) = zcl_ca_ops_lic_policy=>evaluate( ms_input ).
    cl_abap_unit_assert=>assert_equals( act = ls_status-state exp = zif_ca_ops_lic_types=>gc_lic_state-version ).
    cl_abap_unit_assert=>assert_equals( act = ls_status-detail exp = `2.0.0` ).
  ENDMETHOD.


  METHOD unknown_module_decision.
    DATA(ls_status) = zcl_ca_ops_lic_policy=>evaluate( ms_input ).
    DATA(ls_decision) = zcl_ca_ops_lic_policy=>decide( is_status = ls_status iv_module = gc-unknown ).
    cl_abap_unit_assert=>assert_equals( act = ls_decision-state exp = zif_ca_ops_lic_types=>gc_state-unlicensed ).
    cl_abap_unit_assert=>assert_false( ls_decision-allowed ).
    ls_status-enforce = zif_ca_ops_lic_types=>gc_enforce-warn.
    cl_abap_unit_assert=>assert_true( zcl_ca_ops_lic_policy=>decide( is_status = ls_status
                                                                     iv_module = gc-unknown )-allowed ).
  ENDMETHOD.


  METHOD version_comparison.
    cl_abap_unit_assert=>assert_true( zcl_ca_ops_lic_policy=>version_in_range( iv_version = '1.0.0'
                                                                               iv_from    = '1.0'
                                                                               iv_to      = '1' ) ).
    cl_abap_unit_assert=>assert_true( zcl_ca_ops_lic_policy=>version_in_range( iv_version = '1.9.3'
                                                                               iv_from    = '1'
                                                                               iv_to      = '1' ) ).
    cl_abap_unit_assert=>assert_false( zcl_ca_ops_lic_policy=>version_in_range( iv_version = '1.10.0'
                                                                                iv_from    = '1.2'
                                                                                iv_to      = '1.9' ) ).
    cl_abap_unit_assert=>assert_false( zcl_ca_ops_lic_policy=>version_in_range( iv_version = '0.9'
                                                                                iv_from    = '1.0'
                                                                                iv_to      = '2' ) ).
    cl_abap_unit_assert=>assert_false( zcl_ca_ops_lic_policy=>version_in_range( iv_version = '1.0'
                                                                                iv_from    = 'x'
                                                                                iv_to      = '2' ) ).
  ENDMETHOD.


  METHOD impossible_date_is_initial.
    cl_abap_unit_assert=>assert_initial( zcl_ca_ops_lic_policy=>to_date( '20261131' ) ).
    cl_abap_unit_assert=>assert_initial( zcl_ca_ops_lic_policy=>to_date( '2026113' ) ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_lic_policy=>to_date( '20261130' ) exp = '20261130' ).
  ENDMETHOD.

ENDCLASS.
