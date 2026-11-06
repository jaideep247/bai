*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_auth.clas.testclasses.abap
*& Purpose:
*& Unit tests of the configuration-app authorisation adapter: the decision
*& and the activity / payment engine area handed to the core authorisation
*& come from the injected ZIF_CD_OPS_AUTH double (ZCL_CD_OPS_INJECTOR); does
*& not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_allowed TYPE abap_bool.
    DATA mv_activity TYPE zif_cd_ops_auth=>ty_activity.
    DATA mv_pe_area TYPE zif_cd_ops_types=>ty_pe_area.
    DATA mv_bukrs TYPE bukrs.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_cd_ops_auth~is_allowed.
    mv_activity = iv_activity.
    mv_pe_area  = iv_pe_area.
    mv_bukrs    = iv_bukrs.
    rv_allowed  = mv_allowed.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_cfg_auth DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flags,
        allowed TYPE abap_bool,
      END OF ty_flags.

    DATA mo_auth TYPE REF TO ltd_auth.

    METHODS setup.
    METHODS teardown.
    METHODS allowed_user_is_authorized FOR TESTING.
    METHODS refused_user_not_authorized FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.
ENDCLASS.


CLASS ltc_cfg_auth IMPLEMENTATION.

  METHOD setup.
    mo_auth = NEW #( ).
    zcl_cd_ops_injector=>inject_auth( mo_auth ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_auth.
  ENDMETHOD.


  METHOD configure_scenario.
    mo_auth->mv_allowed = is_flags-allowed.
  ENDMETHOD.


  METHOD act.
    rv_allowed = NEW zcl_cd_ops_cfg_auth( )->zif_cd_ops_cfg_auth~is_authorized(
      iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs
      iv_actvt   = zif_cd_ops_cfg_types=>gc_actvt-change ).
  ENDMETHOD.


  " Rule: the core ZCD_OPS check decides, area-wide (no company code), with the app's activity
  METHOD allowed_user_is_authorized.
    TRY.
        configure_scenario( VALUE #( allowed = abap_true ) ).
        cl_abap_unit_assert=>assert_true( act = act( ) msg = 'Allowed by the core check' ).
        cl_abap_unit_assert=>assert_equals( act = mo_auth->mv_activity
                                            exp = zif_cd_ops_auth=>gc_activity-change
                                            msg = 'Activity handed through' ).
        cl_abap_unit_assert=>assert_equals( act = mo_auth->mv_pe_area
                                            exp = zif_cd_ops_types=>gc_pe_area-ebs
                                            msg = 'Payment engine area handed through' ).
        cl_abap_unit_assert=>assert_initial( act = mo_auth->mv_bukrs msg = 'Company code not restricted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a refusal of the core check is a refusal of the app
  METHOD refused_user_not_authorized.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_false( act = act( ) msg = 'Refused by the core check' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
