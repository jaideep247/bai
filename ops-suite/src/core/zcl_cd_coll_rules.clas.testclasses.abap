*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_coll_rules.clas.testclasses.abap
*& Purpose:
*& Unit tests of the shared rules of the collections request checks: the
*& severity of an age in hours (E from red, W from amber, none below), limits
*& that are not set or red below amber raise, a request status source still
*& a placeholder raises in the constructor (no verdict). In-memory
*& parameters; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
CLASS ltc_rules DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        spec  TYPE string VALUE `TABLE=ZT_REQ;KEY=REQ_ID;STATUS=STAT;DATE=CHDAT`,
        unset TYPE string VALUE `TABLE=‹status table›;KEY=‹request key›;STATUS=‹status›;DATE=‹date›`,
        amber TYPE string VALUE `6`,
        red   TYPE string VALUE `4`,
      END OF gc.

    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS severity_by_hours FOR TESTING.
    METHODS red_below_amber_raises FOR TESTING.
    METHODS unset_source_raises FOR TESTING.
ENDCLASS.


CLASS ltc_rules IMPLEMENTATION.

  METHOD setup.
    mo_params = NEW zcl_cd_ops_param_seed( ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-src_request iv_value = gc-spec ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  " Rule: E from the red limit, W from amber, nothing below amber
  METHOD severity_by_hours.
    DATA(ls_limits) = VALUE zif_cd_coll_types=>ty_limits( amber = 4 red = 24 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_coll_rules=>severity_of( iv_hours = 24 is_limits = ls_limits )
                                        exp = zif_ca_ops_types=>gc_severity-error msg = 'Red' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_coll_rules=>severity_of( iv_hours = 4 is_limits = ls_limits )
                                        exp = zif_ca_ops_types=>gc_severity-warning msg = 'Amber' ).
    cl_abap_unit_assert=>assert_initial( act = zcl_cd_coll_rules=>severity_of( iv_hours = 3 is_limits = ls_limits )
                                         msg = 'Below amber' ).
  ENDMETHOD.


  " Rule: limits not set, or red below amber, are not configured
  METHOD red_below_amber_raises.
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-r2_amber iv_value = gc-amber ).
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-r2_red iv_value = gc-red ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    TRY.
        DATA(lo_rules) = NEW zcl_cd_coll_rules( is_check = VALUE #( ) is_context = VALUE #( ) ).
        lo_rules->limits( iv_amber = zif_cd_coll_types=>gc_param-r2_amber iv_red = zif_cd_coll_types=>gc_param-r2_red ).
        cl_abap_unit_assert=>fail( msg = 'Red below amber must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Not configured' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a source with placeholders raises before anything is read
  METHOD unset_source_raises.
    mo_params->set( iv_name = zif_cd_coll_types=>gc_param-src_request iv_value = gc-unset ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    TRY.
        cl_abap_unit_assert=>assert_not_bound( act = NEW zcl_cd_coll_rules( is_check = VALUE #( ) is_context = VALUE #( ) )
                                               msg = 'Unset source must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Not configured' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
