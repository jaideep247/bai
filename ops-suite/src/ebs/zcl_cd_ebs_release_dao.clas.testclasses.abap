*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_release_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the release repository: only approved releases of the
*& requested lines are returned. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
CLASS ltc_release_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ebs_release_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS add_release
      IMPORTING
        iv_uuid       TYPE sysuuid_x16
        iv_object_key TYPE zif_cd_ops_types=>ty_object_key
        iv_status     TYPE zif_cd_ebs_release_types=>ty_status.

    METHODS only_approved_are_returned FOR TESTING.
ENDCLASS.


CLASS ltc_release_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCD_EBS_RELEASE' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ebs_release_dao( ).
  ENDMETHOD.


  METHOD add_release.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ebs_release WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ebs_release.
    ls_row-release_uuid = iv_uuid.
    ls_row-object_key   = iv_object_key.
    ls_row-check_code   = 'UNMAPPED_BTC'.
    ls_row-status       = iv_status.
    ls_row-requested_by = 'REQUESTER'.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  " Rule: a requested or rejected release never opens the posting gate; other lines are not read
  METHOD only_approved_are_returned.
    TRY.
        add_release( iv_uuid = '000000000000000000000000000000A1' iv_object_key = 'S0001/1'
                     iv_status = zif_cd_ebs_release_types=>gc_status-approved ).
        add_release( iv_uuid = '000000000000000000000000000000A2' iv_object_key = 'S0001/1'
                     iv_status = zif_cd_ebs_release_types=>gc_status-requested ).
        add_release( iv_uuid = '000000000000000000000000000000A3' iv_object_key = 'S0001/1'
                     iv_status = zif_cd_ebs_release_types=>gc_status-rejected ).
        add_release( iv_uuid = '000000000000000000000000000000A4' iv_object_key = 'S0009/1'
                     iv_status = zif_cd_ebs_release_types=>gc_status-approved ).
        DATA(lt_releases) = mo_cut->get_approved( VALUE #( ( CONV zif_cd_ops_types=>ty_object_key( 'S0001/1' ) ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_releases ) exp = 1
                                            msg = 'Only the approved release of the line must be returned' ).
        cl_abap_unit_assert=>assert_equals( act = lt_releases[ 1 ]-release_uuid exp = '000000000000000000000000000000A1'
                                            msg = 'The approved release must be the one returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
