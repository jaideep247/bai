*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_lic_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the licence data access on doubles of ZCA_OPS_LIC,
*& ZCA_OPS_LICM, ZCA_OPS_LICMOD, ZCA_OPS_PROC and ZCA_OPS_CATPRC: the
*& active licence is read (none = initial), installing keeps the previous
*& licence as history and writes the module rows and the module catalogue,
*& the catalogue package of a catalogue process and of the business
*& processes of an area. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
CLASS ltc_lic_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        old_id    TYPE zif_ca_ops_lic_types=>ty_license_id VALUE 'ZT-LIC-OLD',
        new_id    TYPE zif_ca_ops_lic_types=>ty_license_id VALUE 'ZT-LIC-NEW',
        now       TYPE timestampl VALUE '20261115080000.0000000',
        earlier   TYPE timestampl VALUE '20251115080000.0000000',
        process   TYPE c LENGTH 20 VALUE 'ZT_PROCESS',
        own       TYPE c LENGTH 20 VALUE 'ZT_OWN',
        cat       TYPE c LENGTH 20 VALUE 'FICA_PAYRUN',
        package   TYPE c LENGTH 10 VALUE 'FICA',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_lic_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS none_installed_is_initial  FOR TESTING.
    METHODS install_keeps_history      FOR TESTING RAISING zcx_ca_ops_error.
    METHODS packages_of_area_processes FOR TESTING.
    METHODS package_of_cat_process     FOR TESTING.
ENDCLASS.


CLASS ltc_lic_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCA_OPS_LIC' )
                                                                            ( 'ZCA_OPS_LICM' )
                                                                            ( 'ZCA_OPS_LICMOD' )
                                                                            ( 'ZCA_OPS_PROC' )
                                                                            ( 'ZCA_OPS_CATPRC' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_procs TYPE STANDARD TABLE OF zca_ops_proc WITH EMPTY KEY.
    DATA lt_cats TYPE STANDARD TABLE OF zca_ops_catprc WITH EMPTY KEY.
    DATA ls_proc TYPE zca_ops_proc.
    DATA ls_cat TYPE zca_ops_catprc.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_lic_dao( ).
    ls_proc-area        = gc-area.
    ls_proc-process_id  = gc-process.
    ls_proc-cat_process = gc-cat.
    INSERT ls_proc INTO TABLE lt_procs.
    " a business process of its own (no catalogue process) is not listed
    ls_proc-process_id  = gc-own.
    CLEAR ls_proc-cat_process.
    INSERT ls_proc INTO TABLE lt_procs.
    ls_cat-process_id = gc-cat.
    ls_cat-pkg_id     = gc-package.
    INSERT ls_cat INTO TABLE lt_cats.
    go_env->insert_test_data( lt_procs ).
    go_env->insert_test_data( lt_cats ).
  ENDMETHOD.


  METHOD none_installed_is_initial.
    cl_abap_unit_assert=>assert_initial( mo_cut->get_active( ) ).
  ENDMETHOD.


  METHOD install_keeps_history.
    DATA lt_old TYPE STANDARD TABLE OF zca_ops_lic WITH EMPTY KEY.
    INSERT VALUE #( lic_uuid = '0000000000000000000000000000000A' license_id = gc-old_id active = abap_true
                    installed_at = gc-earlier ) INTO TABLE lt_old.
    go_env->insert_test_data( lt_old ).

    DATA(lv_uuid) = mo_cut->install(
      is_install = VALUE #( license_id = gc-new_id state = zif_ca_ops_lic_types=>gc_lic_state-valid
                            content    = `TWFu`
                            modules    = VALUE #( ( module = zif_ca_ops_lic_types=>gc_module-jobs
                                                    valid_from = '20261115' valid_to = '20271114' ) ) )
      it_map     = VALUE #( ( obj_kind = zif_ca_ops_lic_types=>gc_kind-module obj_name = 'CORE'
                              module   = zif_ca_ops_lic_types=>gc_module-core always = abap_true ) )
      iv_now     = gc-now ).

    DATA(ls_active) = mo_cut->get_active( ).
    cl_abap_unit_assert=>assert_equals( act = ls_active-license_id exp = gc-new_id ).
    cl_abap_unit_assert=>assert_equals( act = ls_active-lic_uuid exp = lv_uuid ).
    cl_abap_unit_assert=>assert_equals( act = ls_active-content exp = `TWFu` ).
    SELECT license_id, active, replaced_at FROM zca_ops_lic ORDER BY license_id INTO TABLE @DATA(lt_all).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_all ) exp = 2 msg = 'history kept' ).
    cl_abap_unit_assert=>assert_equals( act = lt_all[ license_id = gc-old_id ]-active exp = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = lt_all[ license_id = gc-old_id ]-replaced_at exp = gc-now ).
    SELECT module FROM zca_ops_licm WHERE lic_uuid = @lv_uuid INTO TABLE @DATA(lt_modules).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_modules ) exp = 1 ).
    SELECT obj_name FROM zca_ops_licmod INTO TABLE @DATA(lt_catalogue).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_catalogue ) exp = 1 ).
  ENDMETHOD.


  METHOD packages_of_area_processes.
    DATA(lt_packages) = mo_cut->get_process_packages( gc-area ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_packages ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_packages[ 1 ]-process_id exp = gc-process ).
    cl_abap_unit_assert=>assert_equals( act = lt_packages[ 1 ]-pkg_id exp = gc-package ).
    cl_abap_unit_assert=>assert_initial( mo_cut->get_process_packages( 'ZT_OPS_B' ) ).
  ENDMETHOD.


  METHOD package_of_cat_process.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_cat_package( gc-cat ) exp = gc-package ).
    cl_abap_unit_assert=>assert_initial( mo_cut->get_cat_package( 'ZT_UNKNOWN' ) ).
  ENDMETHOD.

ENDCLASS.
