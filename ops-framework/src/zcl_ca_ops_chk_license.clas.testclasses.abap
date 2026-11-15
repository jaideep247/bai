*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_license.clas.testclasses.abap
*& Purpose:
*& Tests of the licence check through ZIF_CA_OPS_CHECK~RUN with a licence
*& double: no licence = one LICENSE_MISSING exception (W under W, E under
*& X), a licence of another system = LICENSE_INVALID, modules ending soon /
*& in grace / expired = one exception each with the dates, licensed and
*& never granted modules = no finding, the check is complete (its earlier
*& exceptions resolve once the licence is renewed). No database.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
CLASS ltd_chk_license DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_license PARTIALLY IMPLEMENTED.
    DATA ms_status TYPE zif_ca_ops_lic_types=>ty_status.
ENDCLASS.

CLASS ltd_chk_license IMPLEMENTATION.
  METHOD zif_ca_ops_license~status.
    rs_status = ms_status.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_license DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_license TYPE REF TO ltd_chk_license.

    METHODS setup.
    METHODS teardown.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result.

    METHODS missing_is_one_exception  FOR TESTING.
    METHODS missing_is_error_under_x  FOR TESTING.
    METHODS other_system_is_invalid   FOR TESTING.
    METHODS due_modules_reported      FOR TESTING.
ENDCLASS.


CLASS ltc_chk_license IMPLEMENTATION.

  METHOD setup.
    mo_license = NEW #( ).
    zcl_ca_ops_injector=>inject_license( mo_license ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD run.
    TRY.
        rs_result = NEW zcl_ca_ops_chk_license( )->zif_ca_ops_check~run(
                      is_check   = VALUE #( area = 'CA_OPS' check_id = 'LICENSE' )
                      is_context = VALUE #( area = 'CA_OPS' today = '20261115' ) ).
      CATCH zcx_ca_ops_error.
        cl_abap_unit_assert=>fail( 'the licence check raised' ).
    ENDTRY.
  ENDMETHOD.


  METHOD missing_is_one_exception.
    mo_license->ms_status = VALUE #( state   = zif_ca_ops_lic_types=>gc_lic_state-missing
                                     enforce = zif_ca_ops_lic_types=>gc_enforce-warn ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 ).
    DATA(ls_finding) = ls_result-findings[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code exp = zif_ca_ops_lic_types=>gc_code-missing ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-warning ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-action exp = zif_ca_ops_types=>gc_action-exception ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'NONE' ).
    cl_abap_unit_assert=>assert_false( ls_result-partial ).
  ENDMETHOD.


  METHOD missing_is_error_under_x.
    mo_license->ms_status = VALUE #( state   = zif_ca_ops_lic_types=>gc_lic_state-missing
                                     enforce = zif_ca_ops_lic_types=>gc_enforce-refuse ).
    DATA(lt_findings) = run( )-findings.
    cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-error ).
  ENDMETHOD.


  METHOD other_system_is_invalid.
    mo_license->ms_status = VALUE #( state      = zif_ca_ops_lic_types=>gc_lic_state-binding
                                     license_id = 'ZT-LIC-0001'
                                     detail     = `0020999999/QA1/100`
                                     enforce    = zif_ca_ops_lic_types=>gc_enforce-warn ).
    DATA(lt_findings) = run( )-findings.
    DATA(ls_finding) = lt_findings[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code exp = zif_ca_ops_lic_types=>gc_code-invalid ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'ZT-LIC-0001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-reference exp = zif_ca_ops_lic_types=>gc_lic_state-binding ).
  ENDMETHOD.


  METHOD due_modules_reported.
    mo_license->ms_status = VALUE #(
      state      = zif_ca_ops_lic_types=>gc_lic_state-valid
      license_id = 'ZT-LIC-0001'
      enforce    = zif_ca_ops_lic_types=>gc_enforce-refuse
      modules    = VALUE #( ( module = zif_ca_ops_lic_types=>gc_module-core state = zif_ca_ops_lic_types=>gc_state-included
                              runs = abap_true )
                            ( module = zif_ca_ops_lic_types=>gc_module-breaks state = zif_ca_ops_lic_types=>gc_state-expired
                              valid_to = '20261001' grace_to = '20261031' )
                            ( module = zif_ca_ops_lic_types=>gc_module-flow state = zif_ca_ops_lic_types=>gc_state-unlicensed )
                            ( module = zif_ca_ops_lic_types=>gc_module-jobs state = zif_ca_ops_lic_types=>gc_state-expiring
                              valid_to = '20261130' days_left = 15 runs = abap_true warn = abap_true )
                            ( module = zif_ca_ops_lic_types=>gc_module-links state = zif_ca_ops_lic_types=>gc_state-licensed
                              runs = abap_true )
                            ( module = zif_ca_ops_lic_types=>gc_module-response state = zif_ca_ops_lic_types=>gc_state-grace
                              valid_to = '20261101' grace_to = '20261201' runs = abap_true warn = abap_true ) ) ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 3 ).
    DATA(ls_jobs) = ls_result-findings[ object_key = 'JOBS' ].
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-check_code exp = zif_ca_ops_lic_types=>gc_code-expiring ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-severity exp = zif_ca_ops_types=>gc_severity-warning ).
    cl_abap_unit_assert=>assert_equals( act = ls_jobs-business_date exp = '20261130' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ object_key = 'RESPONSE' ]-check_code
                                        exp = zif_ca_ops_lic_types=>gc_code-grace ).
    " refused under X: an error
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ object_key = 'BREAKS' ]-severity
                                        exp = zif_ca_ops_types=>gc_severity-error ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-item_count exp = 6 ).
  ENDMETHOD.

ENDCLASS.
