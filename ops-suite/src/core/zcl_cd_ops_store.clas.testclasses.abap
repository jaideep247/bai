*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_store.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the shared store: test-mode runs write nothing, findings of
*& severity B/E/W become open exceptions with an SLA due date, parameters fall
*& back to defaults. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = '20261105080000.0000000'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261105'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = '080000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_store DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_store.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS finding
      IMPORTING
        iv_severity       TYPE zif_cd_ops_types=>ty_severity
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

    METHODS test_mode_writes_nothing     FOR TESTING.
    METHODS error_becomes_open_exception FOR TESTING.
    METHODS info_is_not_an_exception     FOR TESTING.
    METHODS sla_param_sets_due_date      FOR TESTING.
    METHODS missing_param_gives_default  FOR TESTING.
ENDCLASS.


CLASS ltc_store IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCD_OPS_RUN' ) ( 'ZCD_OPS_FINDING' ) ( 'ZCD_OPS_PARAM' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    mo_cut = NEW zcl_cd_ops_store( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_cut.
  ENDMETHOD.


  METHOD finding.
    rs_finding-object_type = 'LINE'.
    rs_finding-object_key  = 'S0001/1'.
    rs_finding-rule_id     = 'R14'.
    rs_finding-severity    = iv_severity.
    rs_finding-message     = 'test'.
  ENDMETHOD.


  " Test mode: neither run header nor findings reach the database
  METHOD test_mode_writes_nothing.
    TRY.
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs iv_test_mode = abap_true ).
        mo_cut->save_findings( EXPORTING it_findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-error ) ) )
                               CHANGING  cs_run      = ls_run ).
        SELECT COUNT(*) FROM zcd_ops_finding INTO @DATA(lv_count).
        cl_abap_unit_assert=>assert_equals( act = lv_count exp = 0 msg = 'Test mode must not write findings' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-finding_count exp = 1 msg = 'Count must still advance' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " An E finding is stored as an open, owned exception
  METHOD error_becomes_open_exception.
    TRY.
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs ).
        mo_cut->save_findings( EXPORTING it_findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-error ) ) )
                               CHANGING  cs_run      = ls_run ).
        SELECT SINGLE disposition, due_date FROM zcd_ops_finding WHERE run_id = @ls_run-run_id
          INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_equals( act = ls_row-disposition exp = zcl_cd_ops_store=>gc_disposition-open
                                            msg = 'E finding must be an open exception' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-due_date exp = '20261106'
                                            msg = 'Default SLA is one day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " An I finding is information, not an exception to work
  METHOD info_is_not_an_exception.
    TRY.
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs ).
        mo_cut->save_findings( EXPORTING it_findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-info ) ) )
                               CHANGING  cs_run      = ls_run ).
        SELECT SINGLE disposition, due_date FROM zcd_ops_finding WHERE run_id = @ls_run-run_id
          INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_equals( act = ls_row-disposition
                                            exp = zcl_cd_ops_store=>gc_disposition-information
                                            msg = 'I finding must be information' ).
        cl_abap_unit_assert=>assert_initial( act = ls_row-due_date msg = 'Information has no due date' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " SLA_DAYS_<module>_<severity> drives the due date
  METHOD sla_param_sets_due_date.
    DATA lt_param TYPE STANDARD TABLE OF zcd_ops_param WITH EMPTY KEY.
    DATA ls_param TYPE zcd_ops_param.
    TRY.
        ls_param-param_name  = 'SLA_DAYS_EBS_B'.
        ls_param-param_value = '0'.
        INSERT ls_param INTO TABLE lt_param.
        go_env->insert_test_data( lt_param ).
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs ).
        mo_cut->save_findings( EXPORTING it_findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-block ) ) )
                               CHANGING  cs_run      = ls_run ).
        SELECT SINGLE due_date FROM zcd_ops_finding WHERE run_id = @ls_run-run_id INTO @DATA(lv_due).
        cl_abap_unit_assert=>assert_equals( act = lv_due exp = '20261105' msg = 'Blocks are due the same day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A parameter that is not maintained returns the caller's default
  METHOD missing_param_gives_default.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( iv_name = 'NOT_THERE' iv_default = `42` )
                                        exp = `42`
                                        msg = 'Missing parameter must return the default' ).
  ENDMETHOD.

ENDCLASS.
