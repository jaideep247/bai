*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cat_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the process catalogue data access on
*& cl_osql_test_environment doubles: the six catalogue tables read whole in
*& key order, and the business processes of ZCA_OPS_PROC with their
*& catalogue process - of one area, or of every area, active or not. Does
*& not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue with activation).
*&---------------------------------------------------------------------*
CLASS ltc_cat_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        pkg      TYPE zif_ca_ops_cat_types=>ty_pkg_id VALUE 'XX',
        first    TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'XX_A_FIRST',
        second   TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'XX_B_SECOND',
        area     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        other    TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_B',
        proc     TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_PROC',
        early    TYPE d VALUE '20261101',
        late     TYPE d VALUE '20261201',
        approver TYPE syuname VALUE 'ZT_APPROVER',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_cat_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS given_rows.

    METHODS catalogue_read_whole    FOR TESTING.
    METHODS activations_in_order    FOR TESTING.
    METHODS onboarded_of_one_area   FOR TESTING.
    METHODS onboarded_of_every_area FOR TESTING.
ENDCLASS.


CLASS ltc_cat_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCA_OPS_CATPKG' ) ( 'ZCA_OPS_CATPRC' ) ( 'ZCA_OPS_CATSTP' ) ( 'ZCA_OPS_CATTAB' )
                                   ( 'ZCA_OPS_CATDEP' ) ( 'ZCA_OPS_CATACT' ) ( 'ZCA_OPS_PROC' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_cat_dao( ).
    given_rows( ).
  ENDMETHOD.


  METHOD given_rows.
    DATA lt_pkg TYPE STANDARD TABLE OF zca_ops_catpkg WITH EMPTY KEY.
    DATA ls_pkg TYPE zca_ops_catpkg.
    DATA lt_prc TYPE STANDARD TABLE OF zca_ops_catprc WITH EMPTY KEY.
    DATA ls_prc TYPE zca_ops_catprc.
    DATA lt_stp TYPE STANDARD TABLE OF zca_ops_catstp WITH EMPTY KEY.
    DATA ls_stp TYPE zca_ops_catstp.
    DATA lt_tab TYPE STANDARD TABLE OF zca_ops_cattab WITH EMPTY KEY.
    DATA ls_tab TYPE zca_ops_cattab.
    DATA lt_dep TYPE STANDARD TABLE OF zca_ops_catdep WITH EMPTY KEY.
    DATA ls_dep TYPE zca_ops_catdep.
    DATA lt_act TYPE STANDARD TABLE OF zca_ops_catact WITH EMPTY KEY.
    DATA ls_act TYPE zca_ops_catact.
    DATA lt_proc TYPE STANDARD TABLE OF zca_ops_proc WITH EMPTY KEY.
    DATA ls_proc TYPE zca_ops_proc.

    ls_pkg-pkg_id    = gc-pkg.
    ls_pkg-pkg_kind  = zif_ca_ops_cat_types=>gc_pkg_kind-customer.
    ls_pkg-pkg_rank  = 100.
    ls_pkg-id_prefix = 'XX_'.
    ls_pkg-active    = abap_true.
    INSERT ls_pkg INTO TABLE lt_pkg.
    go_env->insert_test_data( lt_pkg ).

    ls_prc-pkg_id     = gc-pkg.
    ls_prc-process_id = gc-second.
    INSERT ls_prc INTO TABLE lt_prc.
    ls_prc-process_id = gc-first.
    INSERT ls_prc INTO TABLE lt_prc.
    go_env->insert_test_data( lt_prc ).

    ls_stp-process_id = gc-first.
    ls_stp-step_no    = '020'.
    ls_stp-obj_name   = 'SECOND_STEP'.
    INSERT ls_stp INTO TABLE lt_stp.
    ls_stp-step_no    = '010'.
    ls_stp-obj_name   = 'FIRST_STEP'.
    INSERT ls_stp INTO TABLE lt_stp.
    go_env->insert_test_data( lt_stp ).

    ls_tab-process_id = gc-first.
    ls_tab-tabname    = 'ZCA_OPS_RUN'.
    INSERT ls_tab INTO TABLE lt_tab.
    go_env->insert_test_data( lt_tab ).

    ls_dep-process_id = gc-second.
    ls_dep-pred_id    = gc-first.
    ls_dep-dep_kind   = zif_ca_ops_cat_types=>gc_dep_kind-hard.
    INSERT ls_dep INTO TABLE lt_dep.
    go_env->insert_test_data( lt_dep ).

    ls_act-process_id  = gc-first.
    ls_act-valid_from  = gc-late.
    ls_act-active      = abap_false.
    ls_act-approved_by = gc-approver.
    INSERT ls_act INTO TABLE lt_act.
    ls_act-valid_from  = gc-early.
    ls_act-active      = abap_true.
    INSERT ls_act INTO TABLE lt_act.
    go_env->insert_test_data( lt_act ).

    ls_proc-area        = gc-area.
    ls_proc-process_id  = gc-proc.
    ls_proc-cat_process = gc-first.
    ls_proc-active      = abap_false.
    INSERT ls_proc INTO TABLE lt_proc.
    ls_proc-area        = gc-other.
    ls_proc-cat_process = space.
    ls_proc-active      = abap_true.
    INSERT ls_proc INTO TABLE lt_proc.
    go_env->insert_test_data( lt_proc ).
  ENDMETHOD.


  METHOD catalogue_read_whole.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_packages( ) ) exp = 1 msg = 'Package' ).
        DATA(lt_processes) = mo_cut->get_processes( ).
        cl_abap_unit_assert=>assert_equals( act = lt_processes[ 1 ]-process_id exp = gc-first msg = 'Processes in key order' ).
        DATA(lt_steps) = mo_cut->get_steps( ).
        cl_abap_unit_assert=>assert_equals( act = lt_steps[ 1 ]-obj_name exp = 'FIRST_STEP' msg = 'Steps in order' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_tables( ) ) exp = 1 msg = 'Table' ).
        DATA(lt_deps) = mo_cut->get_dependencies( ).
        cl_abap_unit_assert=>assert_equals( act = lt_deps[ 1 ]-pred_id exp = gc-first msg = 'Dependency' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD activations_in_order.
    TRY.
        DATA(lt_act) = mo_cut->get_activations( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_act ) exp = 2 msg = 'Both rows' ).
        cl_abap_unit_assert=>assert_equals( act = lt_act[ 1 ]-valid_from exp = gc-early msg = 'Earliest first' ).
        cl_abap_unit_assert=>assert_equals( act = lt_act[ 2 ]-approved_by exp = gc-approver msg = 'Approver read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD onboarded_of_one_area.
    TRY.
        DATA(lt_onb) = mo_cut->get_onboarded( gc-area ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_onb ) exp = 1 msg = 'One row of the area' ).
        cl_abap_unit_assert=>assert_equals( act = lt_onb[ 1 ]-cat_process exp = gc-first msg = 'Its catalogue process' ).
        cl_abap_unit_assert=>assert_false( act = lt_onb[ 1 ]-active msg = 'Inactive rows are read too' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD onboarded_of_every_area.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_onboarded( ) ) exp = 2 msg = 'Every area' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
