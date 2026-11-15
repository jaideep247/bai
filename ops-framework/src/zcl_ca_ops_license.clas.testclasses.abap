*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_license.clas.testclasses.abap
*& Purpose:
*& Tests of the licence with a fake data access and a fake SSF / system
*& adapter (no database, no SSF): no licence stored = MISSING without a
*& signature check; a stored licence is verified on first use and the
*& status cached per instance; a stored file SSF cannot check is not the
*& vendor's (SIGNATURE); the gate under LIC_ENFORCE X records the refused
*& run and raises 352, under W it lets the module run; CORE is never
*& refused; modules of a check from its class and from the catalogue
*& package of its business process; a process licensed on its own; the
*& installation stores a VALID licence only and nothing in test mode; the
*& generated module map ZCL_CA_OPS_LIC_MAP is the default map (CORE always
*& included, the job monitor's check classes in JOBS, FS-RI on its own).
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
CLASS ltd_lic_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_lic_dao.
    DATA ms_stored TYPE zif_ca_ops_lic_types=>ty_stored.
    DATA mt_packages TYPE zif_ca_ops_lic_types=>tt_process_package.
    DATA mv_package TYPE zif_ca_ops_lic_types=>ty_process_package-pkg_id.
    DATA mv_installs TYPE i.
    DATA ms_installed TYPE zif_ca_ops_lic_types=>ty_install.
ENDCLASS.

CLASS ltd_lic_dao IMPLEMENTATION.
  METHOD zif_ca_ops_lic_dao~get_active.
    rs_stored = ms_stored.
  ENDMETHOD.
  METHOD zif_ca_ops_lic_dao~get_process_packages.
    rt_packages = mt_packages.
  ENDMETHOD.
  METHOD zif_ca_ops_lic_dao~get_cat_package.
    rv_pkg_id = mv_package.
  ENDMETHOD.
  METHOD zif_ca_ops_lic_dao~install.
    mv_installs += 1.
    ms_installed = is_install.
    rv_uuid = '0000000000000000000000000000000B'.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_lic_platform DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_lic_platform.
    DATA ms_verified TYPE zif_ca_ops_lic_types=>ty_verified.
    DATA mv_fail TYPE abap_bool.
    DATA mv_verify_calls TYPE i.
ENDCLASS.

CLASS ltd_lic_platform IMPLEMENTATION.
  METHOD zif_ca_ops_lic_platform~verify.
    mv_verify_calls += 1.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e365(zca_ops) WITH '9' iv_profile.
    ENDIF.
    rs_verified = ms_verified.
  ENDMETHOD.
  METHOD zif_ca_ops_lic_platform~system.
    rs_system = VALUE #( installations = VALUE #( ( `0020123456` ) )
                         sysid         = 'PS4'
                         client        = '100'
                         version       = `1.0.0` ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_lic_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_store PARTIALLY IMPLEMENTED.
    DATA ms_finished TYPE zif_ca_ops_types=>ty_run.
    DATA mt_saved TYPE zif_ca_ops_types=>tt_finding.
ENDCLASS.

CLASS ltd_lic_store IMPLEMENTATION.
  METHOD zif_ca_ops_store~start_run.
    rs_run-area    = iv_area.
    rs_run-variant = iv_variant.
  ENDMETHOD.
  METHOD zif_ca_ops_store~save_findings.
    INSERT LINES OF it_findings INTO TABLE mt_saved.
  ENDMETHOD.
  METHOD zif_ca_ops_store~finish_run.
    ms_finished = is_run.
  ENDMETHOD.
  METHOD zif_ca_ops_store~commit.
  ENDMETHOD.
  METHOD zif_ca_ops_store~rollback.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_lic_alert DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert PARTIALLY IMPLEMENTED.
    DATA mv_dispatched TYPE i.
ENDCLASS.

CLASS ltd_lic_alert IMPLEMENTATION.
  METHOD zif_ca_ops_alert~dispatch.
    mv_dispatched += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_lic_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_lic_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261115070000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261115'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '070000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_license DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        "! Base64 of three bytes: the fake SSF adapter never parses it
        content   TYPE string VALUE `TWFu`,
        json      TYPE string VALUE `{"LICENSE":{"FORMAT":1,"LICENSE_ID":"ZT-LIC-0001","PRODUCT":"ZCA_OPS",`
                                  & `"CUSTOMER":"ZT customer","INSTALLATIONS":["0020123456"],`
                                  & `"SYSTEMS":[{"SID":"PS4","CLIENT":"100"}],"VERSION_FROM":"1.0","VERSION_TO":"1",`
                                  & `"MODULES":[{"CODE":"JOBS","VALID_FROM":"20261101","VALID_TO":"20271031"}],`
                                  & `"GRACE_DAYS":30,"ISSUED_AT":"20261101120000"}}`,
        check_job TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_T_CHK_JOB',
        process   TYPE c LENGTH 20 VALUE 'ZT_PROCESS',
        cat       TYPE c LENGTH 20 VALUE 'ZT_CAT_PROC',
        fsri      TYPE c LENGTH 20 VALUE 'ZT_CAT_FSRI',
        package   TYPE c LENGTH 10 VALUE 'ZT_PKG',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_lic_dao.
    DATA mo_platform TYPE REF TO ltd_lic_platform.
    DATA mo_store TYPE REF TO ltd_lic_store.
    DATA mo_alert TYPE REF TO ltd_lic_alert.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.
    DATA mo_cut TYPE REF TO zif_ca_ops_license.

    METHODS setup.
    METHODS teardown.
    "! A stored licence the fake SSF accepts (signed by the vendor, the payload of gc-json)
    METHODS store_valid.

    METHODS none_stored_is_missing       FOR TESTING.
    METHODS stored_verified_once         FOR TESTING.
    METHODS unverifiable_is_signature    FOR TESTING.
    METHODS gate_refuses_under_x         FOR TESTING.
    METHODS gate_warns_under_w           FOR TESTING RAISING zcx_ca_ops_error.
    METHODS core_never_refused           FOR TESTING RAISING zcx_ca_ops_error.
    METHODS modules_of_check_found       FOR TESTING.
    METHODS process_licensed_on_its_own  FOR TESTING.
    METHODS valid_licence_installed      FOR TESTING RAISING zcx_ca_ops_error.
    METHODS invalid_licence_not_stored   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS test_mode_stores_nothing     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS generated_map_is_default     FOR TESTING.
ENDCLASS.


CLASS ltc_license IMPLEMENTATION.

  METHOD setup.
    mo_dao      = NEW #( ).
    mo_platform = NEW #( ).
    mo_store    = NEW #( ).
    mo_alert    = NEW #( ).
    mo_seed     = NEW #( ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_lic_clock( ) ).
    zcl_ca_ops_injector=>inject_store( mo_store ).
    zcl_ca_ops_injector=>inject_alert( mo_alert ).
    mo_cut = NEW zcl_ca_ops_license(
      io_dao      = mo_dao
      io_platform = mo_platform
      it_map      = VALUE #( ( obj_kind = zif_ca_ops_lic_types=>gc_kind-module obj_name = 'CORE'
                               module   = zif_ca_ops_lic_types=>gc_module-core always = abap_true )
                             ( obj_kind = zif_ca_ops_lic_types=>gc_kind-module obj_name = 'JOBS'
                               module   = zif_ca_ops_lic_types=>gc_module-jobs )
                             ( obj_kind = zif_ca_ops_lic_types=>gc_kind-module obj_name = 'FLOW'
                               module   = zif_ca_ops_lic_types=>gc_module-flow )
                             ( obj_kind = zif_ca_ops_lic_types=>gc_kind-module obj_name = 'CATALOGUE_FICA'
                               module   = zif_ca_ops_lic_types=>gc_module-catalogue_fica )
                             ( obj_kind = zif_ca_ops_lic_types=>gc_kind-check_class obj_name = gc-check_job
                               module   = zif_ca_ops_lic_types=>gc_module-jobs )
                             ( obj_kind = zif_ca_ops_lic_types=>gc_kind-package obj_name = gc-package
                               module   = zif_ca_ops_lic_types=>gc_module-catalogue_fica )
                             ( obj_kind = zif_ca_ops_lic_types=>gc_kind-process obj_name = gc-fsri
                               module   = zif_ca_ops_lic_types=>gc_module-catalogue_fsri ) ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD store_valid.
    mo_dao->ms_stored = VALUE #( lic_uuid = '0000000000000000000000000000000A' license_id = 'ZT-LIC-0001'
                                 content  = gc-content ).
    mo_platform->ms_verified = VALUE #( ok      = abap_true
                                        signer  = zif_ca_ops_lic_types=>gc_vendor-subject
                                        payload = cl_abap_codepage=>convert_to( gc-json ) ).
  ENDMETHOD.


  METHOD none_stored_is_missing.
    DATA(ls_status) = mo_cut->status( ).
    cl_abap_unit_assert=>assert_equals( act = ls_status-state exp = zif_ca_ops_lic_types=>gc_lic_state-missing ).
    cl_abap_unit_assert=>assert_equals( act = mo_platform->mv_verify_calls exp = 0 ).
    " the delivered enforcement is warn only
    cl_abap_unit_assert=>assert_equals( act = ls_status-enforce exp = zif_ca_ops_lic_types=>gc_enforce-warn ).
  ENDMETHOD.


  METHOD stored_verified_once.
    store_valid( ).
    DATA(ls_status) = mo_cut->status( ).
    cl_abap_unit_assert=>assert_equals( act = ls_status-state exp = zif_ca_ops_lic_types=>gc_lic_state-valid ).
    cl_abap_unit_assert=>assert_equals( act = ls_status-license_id exp = 'ZT-LIC-0001' ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->decide( zif_ca_ops_lic_types=>gc_module-jobs )-state
                                        exp = zif_ca_ops_lic_types=>gc_state-licensed ).
    mo_cut->decide( zif_ca_ops_lic_types=>gc_module-flow ).
    " verified once per instance (per run)
    cl_abap_unit_assert=>assert_equals( act = mo_platform->mv_verify_calls exp = 1 ).
  ENDMETHOD.


  METHOD unverifiable_is_signature.
    store_valid( ).
    mo_platform->mv_fail = abap_true.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->status( )-state exp = zif_ca_ops_lic_types=>gc_lic_state-signature ).
  ENDMETHOD.


  METHOD gate_refuses_under_x.
    mo_seed->set( iv_name = zif_ca_ops_lic_types=>gc_param-enforce iv_value = 'X' ).
    TRY.
        mo_cut->gate( iv_module = zif_ca_ops_lic_types=>gc_module-flow
                      iv_area   = gc-area
                      iv_entry  = 'ZT_ENTRY' ).
        cl_abap_unit_assert=>fail( 'unlicensed module not refused under X' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '352' ).
    ENDTRY.
    " recorded: an aborted run of the area with one LICENSE_REFUSED finding, alerted
    cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-status exp = zif_ca_ops_types=>gc_run_status-aborted ).
    cl_abap_unit_assert=>assert_equals( act = mo_store->mt_saved[ 1 ]-check_code exp = zif_ca_ops_lic_types=>gc_code-refused ).
    cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatched exp = 1 ).
  ENDMETHOD.


  METHOD gate_warns_under_w.
    DATA(ls_decision) = mo_cut->gate( iv_module = zif_ca_ops_lic_types=>gc_module-flow
                                      iv_area   = gc-area
                                      iv_entry  = 'ZT_ENTRY' ).
    cl_abap_unit_assert=>assert_true( ls_decision-allowed ).
    cl_abap_unit_assert=>assert_true( ls_decision-warn ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_saved ).
  ENDMETHOD.


  METHOD core_never_refused.
    mo_seed->set( iv_name = zif_ca_ops_lic_types=>gc_param-enforce iv_value = 'X' ).
    DATA(ls_decision) = mo_cut->gate( iv_module = zif_ca_ops_lic_types=>gc_module-core
                                      iv_area   = gc-area
                                      iv_entry  = 'ZT_ENTRY' ).
    cl_abap_unit_assert=>assert_true( ls_decision-allowed ).
    cl_abap_unit_assert=>assert_false( ls_decision-warn ).
  ENDMETHOD.


  METHOD modules_of_check_found.
    mo_dao->mt_packages = VALUE #( ( process_id = gc-process cat_process = gc-cat pkg_id = gc-package ) ).
    DATA(lt_modules) = mo_cut->modules_of_check( VALUE #( area       = gc-area
                                                          check_id   = 'ZT_CHECK'
                                                          process_id = gc-process
                                                          class_name = gc-check_job ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_modules ) exp = 2 ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_modules[ table_line = zif_ca_ops_lic_types=>gc_module-jobs ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists(
                                        lt_modules[ table_line = zif_ca_ops_lic_types=>gc_module-catalogue_fica ] ) ) ).
    " a consumer's own class of a process without catalogue process needs no module
    cl_abap_unit_assert=>assert_initial( mo_cut->modules_of_check( VALUE #( area       = gc-area
                                                                            check_id   = 'ZT_OWN'
                                                                            class_name = 'ZCL_T_OWN' ) ) ).
  ENDMETHOD.


  METHOD process_licensed_on_its_own.
    mo_dao->mv_package = gc-package.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->module_of_cat_process( gc-fsri )
                                        exp = zif_ca_ops_lic_types=>gc_module-catalogue_fsri ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->module_of_cat_process( gc-cat )
                                        exp = zif_ca_ops_lic_types=>gc_module-catalogue_fica ).
    cl_abap_unit_assert=>assert_initial( mo_cut->module_of_cat_process( '' ) ).
  ENDMETHOD.


  METHOD valid_licence_installed.
    store_valid( ).
    CLEAR mo_dao->ms_stored.
    DATA(ls_result) = mo_cut->install( iv_content   = gc-content
                                       iv_file_name = 'zt.pem'
                                       iv_test_mode = abap_false ).
    cl_abap_unit_assert=>assert_true( ls_result-stored ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_installs exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_installed-license_id exp = 'ZT-LIC-0001' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_installed-systems exp = 'PS4/100' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_installed-modules[ 1 ]-valid_to exp = '20271031' ).
  ENDMETHOD.


  METHOD invalid_licence_not_stored.
    store_valid( ).
    mo_platform->ms_verified-signer = `CN=ZT SELF SIGNED`.
    DATA(ls_result) = mo_cut->install( iv_content = gc-content iv_test_mode = abap_false ).
    cl_abap_unit_assert=>assert_false( ls_result-stored ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-status-state exp = zif_ca_ops_lic_types=>gc_lic_state-signature ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_installs exp = 0 ).
  ENDMETHOD.


  METHOD test_mode_stores_nothing.
    store_valid( ).
    DATA(ls_result) = mo_cut->install( iv_content = gc-content ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-status-state exp = zif_ca_ops_lic_types=>gc_lic_state-valid ).
    cl_abap_unit_assert=>assert_false( ls_result-stored ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_installs exp = 0 ).
  ENDMETHOD.

  METHOD generated_map_is_default.
    DATA(lt_rows) = zcl_ca_ops_lic_map=>rows( ).
    cl_abap_unit_assert=>assert_true( lt_rows[ obj_kind = zif_ca_ops_lic_types=>gc_kind-module
                                               obj_name = 'CORE' ]-always ).
    DATA(lo_default) = NEW zcl_ca_ops_license( io_dao = mo_dao io_platform = mo_platform ).
    cl_abap_unit_assert=>assert_equals( act = lo_default->zif_ca_ops_license~module_of_class( 'ZCL_CA_OPS_CHK_JOB_FAIL' )
                                        exp = zif_ca_ops_lic_types=>gc_module-jobs ).
    cl_abap_unit_assert=>assert_equals( act = lo_default->zif_ca_ops_license~module_of_cat_process( 'FSCD_FSRI' )
                                        exp = zif_ca_ops_lic_types=>gc_module-catalogue_fsri ).
    cl_abap_unit_assert=>assert_equals( act = lo_default->zif_ca_ops_license~module_of_package( 'FICA' )
                                        exp = zif_ca_ops_lic_types=>gc_module-catalogue_fica ).
    " every module of the map is evaluated, CORE never refused
    DATA(ls_status) = lo_default->zif_ca_ops_license~status( ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_status-modules )
                                        exp = REDUCE i( INIT lv_count = 0
                                                        FOR ls_row IN lt_rows
                                                        WHERE ( obj_kind = zif_ca_ops_lic_types=>gc_kind-module )
                                                        NEXT lv_count = lv_count + 1 ) ).
  ENDMETHOD.

ENDCLASS.
