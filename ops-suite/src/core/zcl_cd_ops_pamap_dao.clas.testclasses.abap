*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pamap_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the typed mapping table repository (ZCD_OPS_MAPRSN,
*& _MAPPMC, _MAPBTM, _MAPBTR doubled): only the rows of the requested
*& version, columns in layout order as KEY01.. / FUN01.. (the ZBTM
*& disposition as FUN07), ordered by the keys; the insert of the migration
*& writes rows that read back as the same entries, with version and change
*& stamps. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (typed product mapping tables).
*&---------------------------------------------------------------------*
CLASS ltc_pamap_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        v1          TYPE zif_cd_ops_postarea_types=>ty_version VALUE '0001',
        v2          TYPE zif_cd_ops_postarea_types=>ty_version VALUE '0002',
        unknown     TYPE zif_cd_ops_postarea_types=>ty_purpose VALUE 'XXX',
        bai2        TYPE c LENGTH 5 VALUE 'BAI2',
        code_low    TYPE c LENGTH 3 VALUE '166',
        code_high   TYPE c LENGTH 3 VALUE '495',
        generic     TYPE c LENGTH 1 VALUE '*',
        category    TYPE c LENGTH 4 VALUE 'W01',
        not_posted  TYPE c LENGTH 10 VALUE 'NOT_POSTED',
        reason      TYPE c LENGTH 4 VALUE 'R01',
        fica_reason TYPE c LENGTH 3 VALUE 'R1',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_pamap_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS rows_of_version_in_layout FOR TESTING.
    METHODS reasons_classes_and_roles FOR TESTING.
    METHODS insert_reads_back_same    FOR TESTING.
    METHODS unknown_purpose_empty     FOR TESTING.
ENDCLASS.


CLASS ltc_pamap_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCD_OPS_MAPRSN' )
                                                                            ( 'ZCD_OPS_MAPPMC' )
                                                                            ( 'ZCD_OPS_MAPBTM' )
                                                                            ( 'ZCD_OPS_MAPBTR' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ops_pamap_dao( ).
  ENDMETHOD.


  " Rule: only the rows of the version; ZBTM columns as KEY01..KEY06 / FUN01..FUN07, ordered by the keys
  METHOD rows_of_version_in_layout.
    DATA lt_map TYPE STANDARD TABLE OF zcd_ops_mapbtm WITH EMPTY KEY.
    TRY.
        lt_map = VALUE #( ( version = gc_test-v1 scheme = gc_test-bai2 code = gc_test-code_high bank = gc_test-generic
                            flow = gc_test-generic category = gc_test-category disposition = gc_test-not_posted )
                          ( version = gc_test-v1 scheme = gc_test-bai2 code = gc_test-code_low bank = gc_test-generic
                            flow = gc_test-generic category = gc_test-category )
                          ( version = gc_test-v2 scheme = gc_test-bai2 code = gc_test-code_low bank = gc_test-generic
                            flow = gc_test-generic ) ).
        go_env->insert_test_data( lt_map ).
        DATA(lt_entries) = mo_cut->read_entries( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                                                 iv_version = gc_test-v1 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_entries ) exp = 2 msg = 'Version 2 excluded' ).
        cl_abap_unit_assert=>assert_equals( act = lt_entries[ 1 ]-key02 exp = CONV string( gc_test-code_low )
                                            msg = 'Ordered by the keys' ).
        cl_abap_unit_assert=>assert_equals( act = lt_entries[ 2 ]-key05 exp = CONV string( gc_test-generic )
                                            msg = 'Bank as KEY05' ).
        cl_abap_unit_assert=>assert_equals( act = lt_entries[ 2 ]-fun07 exp = CONV string( gc_test-not_posted )
                                            msg = 'Disposition as FUN07' ).
        cl_abap_unit_assert=>assert_equals( act = lt_entries[ 2 ]-fun01 exp = CONV string( gc_test-category )
                                            msg = 'Category as FUN01' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: ZRSN, ZPMC and ZBTR columns in their layout order
  METHOD reasons_classes_and_roles.
    DATA lt_reason TYPE STANDARD TABLE OF zcd_ops_maprsn WITH EMPTY KEY.
    DATA lt_class TYPE STANDARD TABLE OF zcd_ops_mappmc WITH EMPTY KEY.
    DATA lt_role TYPE STANDARD TABLE OF zcd_ops_mapbtr WITH EMPTY KEY.
    TRY.
        lt_reason = VALUE #( ( version = gc_test-v1 reason = gc_test-reason fica_reason = gc_test-fica_reason ) ).
        lt_class = VALUE #( ( version = gc_test-v1 flow = 'D' pay_method = 'X' house_bank = gc_test-generic
                              method_class = 'ACI' age_basis = 'VALUE_DATE' ) ).
        lt_role = VALUE #( ( version = gc_test-v1 usage = 'LIFECYCLE' scope = 'DACH' scheme = gc_test-bai2
                             code = gc_test-code_low role = 'RETRIEVED' compare_amount = 'X' ) ).
        go_env->insert_test_data( lt_reason ).
        go_env->insert_test_data( lt_class ).
        go_env->insert_test_data( lt_role ).
        DATA(lt_reason_read) = mo_cut->read_entries( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                                                     iv_version = gc_test-v1 ).
        DATA(ls_reason) = lt_reason_read[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_reason-fun01 exp = CONV string( gc_test-fica_reason )
                                            msg = 'ZRSN: FICA_REASON as FUN01' ).
        DATA(lt_class_read) = mo_cut->read_entries( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-pm_class
                                                    iv_version = gc_test-v1 ).
        DATA(ls_class) = lt_class_read[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_class-key03 exp = CONV string( gc_test-generic )
                                            msg = 'ZPMC: house bank as KEY03' ).
        cl_abap_unit_assert=>assert_equals( act = ls_class-fun02 exp = `VALUE_DATE` msg = 'ZPMC: ageing basis as FUN02' ).
        DATA(lt_role_read) = mo_cut->read_entries( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_role
                                                   iv_version = gc_test-v1 ).
        DATA(ls_role) = lt_role_read[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_role-key04 exp = CONV string( gc_test-code_low )
                                            msg = 'ZBTR: code as KEY04' ).
        cl_abap_unit_assert=>assert_equals( act = ls_role-fun02 exp = `X` msg = 'ZBTR: compare amount as FUN02' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the migration insert writes rows of the version that read back as the same entries
  METHOD insert_reads_back_same.
    DATA lt_entries TYPE zif_cd_ops_postarea_types=>tt_entry.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    TRY.
        INSERT VALUE #( key01 = gc_test-bai2 key02 = gc_test-code_high key05 = gc_test-generic key06 = gc_test-generic
                        fun01 = gc_test-category fun07 = gc_test-not_posted ) INTO TABLE lt_entries.
        DATA(lr_rows) = mo_cut->insert_entries( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                                                iv_version = gc_test-v2
                                                it_entries = lt_entries ).
        ASSIGN lr_rows->* TO <lt_rows>.
        cl_abap_unit_assert=>assert_equals( act = lines( <lt_rows> ) exp = 1 msg = 'One row written' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->read_entries( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                                                                        iv_version = gc_test-v2 )
                                            exp = lt_entries msg = 'Reads back as the same entry' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->read_entries( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                                                                         iv_version = gc_test-v1 )
                                             msg = 'Only the target version' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: an unknown purpose reads and writes nothing
  METHOD unknown_purpose_empty.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->read_entries( iv_purpose = gc_test-unknown iv_version = gc_test-v1 )
                                             msg = 'No entries' ).
        cl_abap_unit_assert=>assert_not_bound(
          act = mo_cut->insert_entries( iv_purpose = gc_test-unknown iv_version = gc_test-v1
                                        it_entries = VALUE #( ( key01 = gc_test-reason ) ) )
          msg = 'Nothing written' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
