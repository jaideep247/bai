*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cat_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the activation views of the process catalogue on
*& cl_cds_test_environment doubles of their direct dependencies: the
*& effective activation (default, deciding activation row, package off),
*& the registered checks in effect (process in effect, switched off, no
*& process, unknown process, inactive check) and the controls not expected
*& in the daily review (all covered checks switched off). Does not prove
*& live SAP runtime behavior. VERIFY-ADT: doubles of CDS view dependencies
*& (7.58).
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue with activation).
*&---------------------------------------------------------------------*
"! ZI_CA_OPSCATPROCEFF: package switch, activation row, default
CLASS ltc_activation DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        pkg_on   TYPE zif_ca_ops_cat_types=>ty_pkg_id VALUE 'XX',
        pkg_off  TYPE zif_ca_ops_cat_types=>ty_pkg_id VALUE 'XY',
        default  TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'XX_DEFAULT_ON',
        row_off  TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'XX_ROW_OFF',
        pkg_proc TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'XY_PACKAGE_OFF',
        from     TYPE d VALUE '20261101',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS default_row_and_package FOR TESTING.
ENDCLASS.


CLASS ltc_activation IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSCATPROCEFF' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_pkg TYPE STANDARD TABLE OF zca_ops_catpkg WITH EMPTY KEY.
    DATA lt_prc TYPE STANDARD TABLE OF zca_ops_catprc WITH EMPTY KEY.
    DATA lt_last TYPE STANDARD TABLE OF zi_ca_opscatactlast WITH EMPTY KEY.
    DATA lt_act TYPE STANDARD TABLE OF zca_ops_catact WITH EMPTY KEY.

    go_env->clear_doubles( ).
    lt_pkg = VALUE #( ( pkg_id = gc-pkg_on active = abap_true ) ( pkg_id = gc-pkg_off active = abap_false ) ).
    lt_prc = VALUE #( ( process_id = gc-default pkg_id = gc-pkg_on dflt_active = abap_true )
                      ( process_id = gc-row_off pkg_id = gc-pkg_on dflt_active = abap_true )
                      ( process_id = gc-pkg_proc pkg_id = gc-pkg_off dflt_active = abap_true ) ).
    lt_last = VALUE #( ( processid = gc-row_off validfrom = gc-from ) ).
    lt_act = VALUE #( ( process_id = gc-row_off valid_from = gc-from active = abap_false reason = 'Not used' ) ).
    go_env->insert_test_data( lt_pkg ).
    go_env->insert_test_data( lt_prc ).
    go_env->insert_test_data( lt_last ).
    go_env->insert_test_data( lt_act ).
  ENDMETHOD.


  " Rule: package off -> inactive (P); a deciding row -> its flag (A); else the delivered default (D)
  METHOD default_row_and_package.
    SELECT processid, isactive, activationsource, activefrom FROM zi_ca_opscatproceff
      ORDER BY processid
      INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3 msg = 'Every catalogue process' ).
    DATA(ls_default) = lt_rows[ processid = gc-default ].
    cl_abap_unit_assert=>assert_equals( act = ls_default-isactive exp = abap_true msg = 'Default on' ).
    cl_abap_unit_assert=>assert_equals( act = ls_default-activationsource exp = 'D' msg = 'Source default' ).
    DATA(ls_row) = lt_rows[ processid = gc-row_off ].
    cl_abap_unit_assert=>assert_equals( act = ls_row-isactive exp = abap_false msg = 'The row switches it off' ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-activefrom exp = gc-from msg = 'Effective from' ).
    DATA(ls_pkg) = lt_rows[ processid = gc-pkg_proc ].
    cl_abap_unit_assert=>assert_equals( act = ls_pkg-isactive exp = abap_false msg = 'Package off wins' ).
    cl_abap_unit_assert=>assert_equals( act = ls_pkg-activationsource exp = 'P' msg = 'Source package' ).
  ENDMETHOD.

ENDCLASS.


"! ZI_CA_OPSCHKEFF: checks in effect (shown on the dashboard)
CLASS ltc_checks_in_effect DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        proc_on   TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_ON',
        proc_off  TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_OFF',
        proc_none TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_UNREGISTERED',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS switched_off_not_in_effect FOR TESTING.
ENDCLASS.


CLASS ltc_checks_in_effect IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSCHKEFF' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_checks TYPE STANDARD TABLE OF zca_ops_check WITH EMPTY KEY.
    DATA lt_eff TYPE STANDARD TABLE OF zi_ca_opsproceff WITH EMPTY KEY.

    go_env->clear_doubles( ).
    lt_checks = VALUE #( area = gc-area
                         ( check_id = 'ZT_C1_ON' process_id = gc-proc_on active = abap_true )
                         ( check_id = 'ZT_C2_OFF' process_id = gc-proc_off active = abap_true )
                         ( check_id = 'ZT_C3_TECH' active = abap_true )
                         ( check_id = 'ZT_C4_UNREG' process_id = gc-proc_none active = abap_true )
                         ( check_id = 'ZT_C5_INACTIVE' process_id = gc-proc_on active = abap_false ) ).
    lt_eff = VALUE #( area = gc-area ( processid = gc-proc_on isactive = abap_true )
                                     ( processid = gc-proc_off isactive = abap_false ) ).
    go_env->insert_test_data( lt_checks ).
    go_env->insert_test_data( lt_eff ).
  ENDMETHOD.


  " Rule: a check of a process not in effect and an inactive check are out; a technical check and a check of an
  " unregistered process run (as the runner does)
  METHOD switched_off_not_in_effect.
    DATA lt_ids TYPE string_table.
    SELECT checkid FROM zi_ca_opschkeff ORDER BY checkid INTO TABLE @lt_ids.
    cl_abap_unit_assert=>assert_equals(
      act = lt_ids
      exp = VALUE string_table( ( `ZT_C1_ON` ) ( `ZT_C3_TECH` ) ( `ZT_C4_UNREG` ) )
      msg = 'Checks in effect' ).
  ENDMETHOD.

ENDCLASS.


"! ZI_CA_OPSCTLPROCOFF: controls not expected in the daily review
CLASS ltc_controls_off DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS only_all_off_not_expected FOR TESTING.
ENDCLASS.


CLASS ltc_controls_off IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSCTLPROCOFF' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_cov TYPE STANDARD TABLE OF zca_ops_ctlchk WITH EMPTY KEY.
    DATA lt_off TYPE STANDARD TABLE OF zi_ca_opschkprocoff WITH EMPTY KEY.

    go_env->clear_doubles( ).
    lt_cov = VALUE #( area = gc-area check_area = gc-area
                      ( control_id = 'ZT_ALL_OFF' match_field = 'GROUP2' match_value = 'ZT_OFF_1' )
                      ( control_id = 'ZT_ALL_OFF' match_field = 'GROUP2' match_value = 'ZT_OFF_2' )
                      ( control_id = 'ZT_MIXED' match_field = 'GROUP2' match_value = 'ZT_OFF_1' )
                      ( control_id = 'ZT_MIXED' match_field = 'GROUP2' match_value = 'ZT_ON_1' )
                      ( control_id = 'ZT_RULE' match_field = 'RULE_ID' match_value = 'ZT_OFF_1' ) ).
    lt_off = VALUE #( area = gc-area ( checkid = 'ZT_OFF_1' ) ( checkid = 'ZT_OFF_2' ) ).
    go_env->insert_test_data( lt_cov ).
    go_env->insert_test_data( lt_off ).
  ENDMETHOD.


  " Rule: a control is not expected only when every covered row is a GROUP2 row of a switched-off check
  METHOD only_all_off_not_expected.
    DATA lt_ids TYPE string_table.
    SELECT controlid FROM zi_ca_opsctlprocoff ORDER BY controlid INTO TABLE @lt_ids.
    cl_abap_unit_assert=>assert_equals( act = lt_ids
                                        exp = VALUE string_table( ( `ZT_ALL_OFF` ) )
                                        msg = 'Only the control of switched-off checks' ).
  ENDMETHOD.

ENDCLASS.
