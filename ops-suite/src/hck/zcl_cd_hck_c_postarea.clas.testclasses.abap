*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_postarea.clas.testclasses.abap
*& Purpose:
*& Application tests of the configuration check POSTAREA_INVALID with the
*& in-memory posting areas (ZCL_CD_OPS_POSTAREA_MEM) and an EBS configuration
*& double: one finding per message (object key posting area/entry, severity,
*& ZCD_OPS message text), the metric; the validations themselves are tested in
*& ZCL_CD_OPS_CFG_CHECKS. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas replace four customizing tables).
*&---------------------------------------------------------------------*
CLASS ltd_ebs_cfg DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_ebs_cfg IMPLEMENTATION.
  METHOD zif_cd_ebs_cfg_dao~get_rules.
    CLEAR rt_rules.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_postarea DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        rsn     TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZRSN',
        pmc     TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZPMC',
        reason  TYPE string VALUE `C02`,
        invalid TYPE string VALUE `/Y`,
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        invalid_reason TYPE abap_bool,
      END OF ty_flags.

    DATA mo_mem TYPE REF TO zcl_cd_ops_postarea_mem.

    METHODS setup.
    METHODS teardown.
    METHODS finding_per_invalid_entry FOR TESTING.
    METHODS empty_area_is_a_warning   FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS run_check
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_postarea IMPLEMENTATION.

  METHOD setup.
    zcl_cd_ebs_injector=>inject_cfg_dao( NEW ltd_ebs_cfg( ) ).
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
    mo_mem = NEW #( ).
    zcl_cd_ops_postarea_injector=>inject_dao( mo_mem ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_postarea_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_ebs_injector=>reset( ).
    CLEAR mo_mem.
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-invalid_reason = abap_true.
      mo_mem->add( iv_area = gc_test-rsn iv_keys = gc_test-reason iv_results = gc_test-invalid ).
    ENDIF.
  ENDMETHOD.


  METHOD run_check.
    rs_result = NEW zcl_cd_hck_c_postarea( )->zif_cd_hck_check~execute( is_def        = VALUE #( )
                                                                        it_thresholds = VALUE #( )
                                                                        is_context    = VALUE #( ) ).
  ENDMETHOD.


  " Rule: an entry the reader cannot use is a POSTAREA_INVALID finding (E) keyed area/entry
  METHOD finding_per_invalid_entry.
    TRY.
        configure_scenario( VALUE #( invalid_reason = abap_true ) ).
        DATA(ls_result) = run_check( ).
        DATA(ls_finding) = VALUE #( ls_result-findings[ group1 = gc_test-rsn ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = |{ gc_test-rsn }/{ gc_test-reason }|
                                            msg = 'Object key = posting area / entry key' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code exp = zif_cd_hck_types=>gc_code-postarea_invalid
                                            msg = 'Check code POSTAREA_INVALID' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'An unusable entry is an error' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_finding-message
          exp = zcl_cd_ops_util=>text( iv_msgno = CONV #( zif_cd_ops_cfg_types=>gc_msg-value_invalid )
                                       iv_v1    = `Y`
                                       iv_v2    = zif_cd_ops_postarea_types=>gc_field-is_noc
                                       iv_v3    = `,X` )
          msg = 'ZCD_OPS message 413 with value, field and allowed values' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = lines( ls_result-findings )
                                            msg = 'Metric = number of findings' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: a posting area without entries is one warning keyed by the area
  METHOD empty_area_is_a_warning.
    TRY.
        DATA(ls_result) = run_check( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 4 msg = 'Four empty posting areas' ).
        DATA(ls_finding) = VALUE #( ls_result-findings[ group1 = gc_test-pmc ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = CONV string( gc_test-pmc )
                                            msg = 'Object key = posting area' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'An empty posting area is a warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
