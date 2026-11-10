*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_file_path.clas.testclasses.abap
*& Purpose:
*& Unit tests of the logical-path file resolution through its test seams
*& (FILE_NAME, FILE_VALIDATE, FILE_AUTH): a name with a path part is refused
*& before anything is resolved (808), an unresolved or invalid path is 807,
*& no S_DATASET is 809, a valid name returns the physical path. No function
*& module runs; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (directory traversal: logical paths only).
*& 2026-11-10 | Moved from ZCL_CD_OPS_FILE_PATH to the reusable framework ZCA_OPS (test logical path).
*&---------------------------------------------------------------------*
CLASS ltc_file_path DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        name     TYPE string VALUE `IN_BANK_20261110.txt`,
        physical TYPE string VALUE `/usr/sap/DV1/ops/in/IN_BANK_20261110.txt`,
        msg_name TYPE symsgno VALUE '808',
        msg_path TYPE symsgno VALUE '807',
        msg_auth TYPE symsgno VALUE '809',
      END OF gc_test.
    "! Logical path / file name of the tests (a consumer names its own in transaction FILE)
    CONSTANTS:
      BEGIN OF gc_logical,
        path TYPE pathintern VALUE 'ZT_OPS_IN',
        file TYPE fileintern VALUE 'ZT_OPS_IN',
      END OF gc_logical.

    TYPES:
      BEGIN OF ty_flags,
        not_resolved TYPE abap_bool,
        not_valid    TYPE abap_bool,
        no_auth      TYPE abap_bool,
      END OF ty_flags.

    METHODS valid_name_gives_path      FOR TESTING.
    METHODS slash_is_refused           FOR TESTING.
    METHODS backslash_is_refused       FOR TESTING.
    METHODS parent_dir_is_refused      FOR TESTING.
    METHODS unresolved_path_is_807     FOR TESTING.
    METHODS invalid_path_is_807        FOR TESTING.
    METHODS no_dataset_auth_is_809     FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      IMPORTING
        iv_name        TYPE string DEFAULT gc_test-name
      RETURNING
        VALUE(rv_path) TYPE string
      RAISING
        zcx_ca_ops_error.
    METHODS assert_raises
      IMPORTING
        iv_name  TYPE string DEFAULT gc_test-name
        iv_msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_file_path IMPLEMENTATION.

  " Every SAP call is injected in every scenario - no test reaches the function modules
  METHOD configure_scenario.
    IF is_flags-not_resolved = abap_true.
      TEST-INJECTION file_name.
        lv_subrc = 1.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION file_name.
        lv_physical = '/usr/sap/DV1/ops/in/IN_BANK_20261110.txt'.
        lv_subrc = 0.
      END-TEST-INJECTION.
    ENDIF.
    IF is_flags-not_valid = abap_true.
      TEST-INJECTION file_validate.
        lv_subrc = 2.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION file_validate.
        lv_subrc = 0.
      END-TEST-INJECTION.
    ENDIF.
    IF is_flags-no_auth = abap_true.
      TEST-INJECTION file_auth.
        lv_subrc = 1.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION file_auth.
        lv_subrc = 0.
      END-TEST-INJECTION.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rv_path = zcl_ca_ops_file_path=>physical( is_logical   = gc_logical
                                              iv_file_name = iv_name
                                              iv_activity  = zif_ca_ops_types=>gc_dataset_activity-read ).
  ENDMETHOD.


  METHOD assert_raises.
    TRY.
        act( iv_name ).
        cl_abap_unit_assert=>fail( msg = 'The file must be refused' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = iv_msgno
                                            msg = 'Refused with the expected message' ).
    ENDTRY.
  ENDMETHOD.


  " A plain name in the logical path, validated and authorised, gives the physical path
  METHOD valid_name_gives_path.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = act( ) exp = gc_test-physical
                                            msg = 'Path from the logical path' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD slash_is_refused.
    configure_scenario( VALUE #( ) ).
    assert_raises( iv_name = `/etc/passwd` iv_msgno = gc_test-msg_name ).
  ENDMETHOD.


  METHOD backslash_is_refused.
    configure_scenario( VALUE #( ) ).
    assert_raises( iv_name = `in\..\x.txt` iv_msgno = gc_test-msg_name ).
  ENDMETHOD.


  METHOD parent_dir_is_refused.
    configure_scenario( VALUE #( ) ).
    assert_raises( iv_name = `..` iv_msgno = gc_test-msg_name ).
  ENDMETHOD.


  METHOD unresolved_path_is_807.
    configure_scenario( VALUE #( not_resolved = abap_true ) ).
    assert_raises( iv_msgno = gc_test-msg_path ).
  ENDMETHOD.


  METHOD invalid_path_is_807.
    configure_scenario( VALUE #( not_valid = abap_true ) ).
    assert_raises( iv_msgno = gc_test-msg_path ).
  ENDMETHOD.


  METHOD no_dataset_auth_is_809.
    configure_scenario( VALUE #( no_auth = abap_true ) ).
    assert_raises( iv_msgno = gc_test-msg_auth ).
  ENDMETHOD.

ENDCLASS.
