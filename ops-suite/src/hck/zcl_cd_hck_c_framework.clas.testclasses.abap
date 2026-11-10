*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_framework.clas.testclasses.abap
*& Purpose:
*& Unit tests of the framework check adapter: the framework check named in
*& PARAM1 runs with the HCK check ID, the registry area (PARAM2, blank =
*& CD_HCK) and the report date; its findings are the check's findings; a
*& partial framework result is a PARTIAL check; a class that is no framework
*& check is refused (032, PLUGIN_ERROR in the engine). The framework check is
*& a local double injected through ZCL_CA_OPS_INJECTOR. Does not prove live
*& SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding: framework check adapter).
*&---------------------------------------------------------------------*
CLASS ltd_check DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.
    DATA ms_check TYPE zif_ca_ops_chk_types=>ty_check.
    DATA ms_context TYPE zif_ca_ops_chk_types=>ty_context.
    DATA ms_result TYPE zif_ca_ops_chk_types=>ty_result.
ENDCLASS.

CLASS ltd_check IMPLEMENTATION.
  METHOD zif_ca_ops_check~run.
    ms_check   = is_check.
    ms_context = is_context.
    rs_result  = ms_result.
  ENDMETHOD.
ENDCLASS.


"! Any object that is no framework check (a plug-in configured by mistake)
CLASS ltd_not_a_check DEFINITION FINAL FOR TESTING.
ENDCLASS.

CLASS ltd_not_a_check IMPLEMENTATION.
ENDCLASS.


CLASS ltc_framework_check DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        check_id TYPE zif_cd_hck_types=>ty_check_id VALUE 'D_PROC_ONBOARD',
        class    TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_ZT_FRAMEWORK_CHECK',
        other    TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_ZT_NOT_A_CHECK',
        area     TYPE zif_cd_hck_types=>ty_param VALUE 'ZT_OPS_A',
        report   TYPE d VALUE '20261110',
        object   TYPE zif_ca_ops_types=>ty_object_key VALUE 'ZT_OPS_A/ZT_PROCESS',
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        partial TYPE abap_bool,
      END OF ty_flags.

    DATA mo_check TYPE REF TO ltd_check.

    METHODS setup.
    METHODS teardown.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      IMPORTING
        iv_area          TYPE zif_cd_hck_types=>ty_param OPTIONAL
        iv_class         TYPE zif_ca_ops_types=>ty_class_name DEFAULT gc_test-class
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_ca_ops_error.

    METHODS findings_passed_through     FOR TESTING.
    METHODS registry_area_from_param2   FOR TESTING.
    METHODS partial_result_is_partial   FOR TESTING.
    METHODS not_a_framework_check_032   FOR TESTING.
ENDCLASS.


CLASS ltc_framework_check IMPLEMENTATION.

  METHOD setup.
    mo_check = NEW #( ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc_test-class io_instance = mo_check ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc_test-other io_instance = NEW ltd_not_a_check( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_finding TYPE zif_ca_ops_types=>ty_finding.
    ls_finding-object_key = gc_test-object.
    ls_finding-check_code = zif_ca_ops_chk_types=>gc_code-proc_no_alert.
    ls_finding-severity   = zif_ca_ops_types=>gc_severity-warning.
    INSERT ls_finding INTO TABLE mo_check->ms_result-findings.
    mo_check->ms_result-partial = is_flags-partial.
  ENDMETHOD.


  METHOD act.
    DATA ls_def TYPE zif_cd_hck_types=>ty_check_def.
    ls_def-check_id = gc_test-check_id.
    ls_def-param1   = iv_class.
    ls_def-param2   = iv_area.
    rs_result = NEW zcl_cd_hck_c_framework( )->zif_cd_hck_check~execute(
                  is_def        = ls_def
                  it_thresholds = VALUE #( )
                  is_context    = VALUE #( report_date = gc_test-report ) ).
  ENDMETHOD.


  " Rule: the framework check's findings are the health check's findings; it runs as the HCK check
  METHOD findings_passed_through.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-object_key exp = gc_test-object
                                            msg = 'Finding of the framework check' ).
        cl_abap_unit_assert=>assert_equals( act = mo_check->ms_check-check_id exp = gc_test-check_id
                                            msg = 'Runs as the HCK check' ).
        cl_abap_unit_assert=>assert_equals( act = mo_check->ms_context-today exp = gc_test-report
                                            msg = 'Today = report date' ).
        cl_abap_unit_assert=>assert_equals( act = mo_check->ms_check-area
                                            exp = zif_cd_ops_types=>gc_pe_area-health_check
                                            msg = 'Blank PARAM2: area CD_HCK' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-completion msg = 'Complete' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PARAM2 names the area of the framework registry rows the check reads
  METHOD registry_area_from_param2.
    TRY.
        configure_scenario( VALUE #( ) ).
        act( iv_area = gc_test-area ).
        cl_abap_unit_assert=>assert_equals( act = mo_check->ms_check-area exp = CONV zif_ca_ops_types=>ty_area( gc_test-area )
                                            msg = 'Area of PARAM2' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a framework check that read less than all is a PARTIAL health check (never an inherited green)
  METHOD partial_result_is_partial.
    TRY.
        configure_scenario( VALUE #( partial = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )-completion exp = zif_cd_hck_types=>gc_completion-partial
                                            msg = 'Partial' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PARAM1 must name a framework check (ZIF_CA_OPS_CHECK) - else 032, a PLUGIN_ERROR of the engine
  METHOD not_a_framework_check_032.
    TRY.
        act( iv_class = gc_test-other ).
        cl_abap_unit_assert=>fail( msg = 'A class that is no framework check must be refused' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '032' msg = 'Message 032' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
