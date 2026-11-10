*&---------------------------------------------------------------------*
*& Artifact: zbp_r_cd_fmonfile.clas.testclasses.abap
*& Purpose:
*& Authorization tests of the FMON manual status behaviour pool through EML
*& GET PERMISSIONS ONLY GLOBAL AUTHORIZATION with the ZIF_CA_OPS_AUTH double of
*& ZCL_CD_OPS_INJECTOR (activity and payment engine area asked, allowed /
*& refused). Actions, determinations, validations and the saver need draft or
*& active EML with COMMIT ENTITIES on doubled tables (QA1 cases RAP_Ops_Apps.md 5);
*& their decisions are tested in the policy classes. VERIFY-ADT: result
*& component GLOBAL on SAP_BASIS 7.58 SP01. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: authorization tests).
*&---------------------------------------------------------------------*
CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_allowed TYPE abap_bool.
    DATA mt_activities TYPE STANDARD TABLE OF zif_ca_ops_auth=>ty_activity WITH EMPTY KEY.
    DATA mv_pe_area TYPE zif_ca_ops_types=>ty_area.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~is_allowed.
    INSERT iv_activity INTO TABLE mt_activities.
    mv_pe_area = iv_area.
    rv_allowed = mv_allowed.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_permissions DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flags,
        authorized TYPE abap_bool,
      END OF ty_flags.

    DATA mo_auth TYPE REF TO ltd_auth.

    METHODS setup.
    METHODS teardown.
    METHODS authorized_user_is_allowed FOR TESTING.
    METHODS refused_user_is_unauthorized FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS permission
      RETURNING
        VALUE(rv_auth) TYPE abp_behv_auth.
ENDCLASS.


CLASS ltc_permissions IMPLEMENTATION.

  METHOD setup.
    mo_auth = NEW #( ).
    zcl_ca_ops_injector=>inject_auth( mo_auth ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_auth.
  ENDMETHOD.


  METHOD configure_scenario.
    mo_auth->mv_allowed = is_flags-authorized.
  ENDMETHOD.


  METHOD permission.
    GET PERMISSIONS ONLY GLOBAL AUTHORIZATION ENTITY zr_cd_fmonfile
      REQUEST VALUE #( %action-setManualStatus = if_abap_behv=>mk-on )
      RESULT DATA(ls_result)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'A permission request never fails' ).
    cl_abap_unit_assert=>assert_initial( act = ls_reported msg = 'No message for a permission request' ).
    rv_auth = ls_result-global-%action-setManualStatus.
  ENDMETHOD.


  " Rule: ZCD_OPS activity change for the payment engine area allows the operation
  METHOD authorized_user_is_allowed.
    TRY.
        configure_scenario( VALUE #( authorized = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = permission( )
                                            exp = if_abap_behv=>auth-allowed
                                            msg = 'Allowed with the activity' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_auth->mt_activities[ table_line = zif_ca_ops_auth=>gc_activity-change ] ) )
          msg = 'Activity change is checked' ).
        cl_abap_unit_assert=>assert_equals( act = mo_auth->mv_pe_area exp = zif_cd_ops_types=>gc_pe_area-file_monitor
                                            msg = 'Checked for the payment engine area' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without the activity the operation is unauthorized
  METHOD refused_user_is_unauthorized.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = permission( )
                                            exp = if_abap_behv=>auth-unauthorized
                                            msg = 'Refused without the activity' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
