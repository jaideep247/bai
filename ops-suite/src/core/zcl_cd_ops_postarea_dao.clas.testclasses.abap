*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the posting area repository (TFK033D doubled): only the
*& entries of the application area, posting area and chart of accounts,
*& ordered by the key values, keys and results complete. VERIFY-DDIC: the
*& TFK033D fields. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas ZRSN, ZPMC, ZBTM, ZBTR).
*&---------------------------------------------------------------------*
CLASS ltc_postarea_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        applk      TYPE zif_cd_ops_postarea_types=>ty_applk VALUE 'V',
        other_appl TYPE zif_cd_ops_postarea_types=>ty_applk VALUE 'P',
        area       TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZBTR',
        other_area TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZBTM',
        ktopl      TYPE zif_cd_ops_postarea_types=>ty_ktopl VALUE 'CAUS',
        usage      TYPE c LENGTH 10 VALUE 'LIFECYCLE',
        scope      TYPE c LENGTH 10 VALUE 'DACH',
        scheme     TYPE c LENGTH 5 VALUE 'BAI2',
        code_low   TYPE c LENGTH 3 VALUE '166',
        code_high  TYPE c LENGTH 3 VALUE '466',
        role       TYPE c LENGTH 15 VALUE 'RETRIEVED',
        compare    TYPE c LENGTH 1 VALUE 'X',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_postarea_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS insert_entry
      IMPORTING
        iv_applk TYPE zif_cd_ops_postarea_types=>ty_applk
        iv_area  TYPE zif_cd_ops_postarea_types=>ty_area
        iv_ktopl TYPE zif_cd_ops_postarea_types=>ty_ktopl OPTIONAL
        iv_code  TYPE clike.

    METHODS entries_of_area_ordered FOR TESTING.
    METHODS keys_and_results_read   FOR TESTING.
    METHODS empty_area_no_entries   FOR TESTING.
ENDCLASS.


CLASS ltc_postarea_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'TFK033D' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ops_postarea_dao( ).
  ENDMETHOD.


  METHOD insert_entry.
    DATA lt_rows TYPE STANDARD TABLE OF tfk033d WITH EMPTY KEY.
    DATA ls_row TYPE tfk033d.
    ls_row-applk = iv_applk.
    ls_row-buber = iv_area.
    ls_row-ktopl = iv_ktopl.
    ls_row-key01 = gc_test-usage.
    ls_row-key02 = gc_test-scope.
    ls_row-key03 = gc_test-scheme.
    ls_row-key04 = iv_code.
    ls_row-fun01 = gc_test-role.
    ls_row-fun02 = gc_test-compare.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  " Rule: only the entries of the application area, posting area and chart of accounts,
  " ordered by the key values
  METHOD entries_of_area_ordered.
    TRY.
        insert_entry( iv_applk = gc_test-applk iv_area = gc_test-area iv_code = gc_test-code_high ).
        insert_entry( iv_applk = gc_test-applk iv_area = gc_test-area iv_code = gc_test-code_low ).
        insert_entry( iv_applk = gc_test-applk iv_area = gc_test-other_area iv_code = gc_test-code_low ).
        insert_entry( iv_applk = gc_test-other_appl iv_area = gc_test-area iv_code = gc_test-code_low ).
        insert_entry( iv_applk = gc_test-applk iv_area = gc_test-area iv_ktopl = gc_test-ktopl
                      iv_code = gc_test-code_low ).
        DATA(lt_entries) = mo_cut->read_entries( iv_applk = gc_test-applk
                                                 iv_area  = gc_test-area
                                                 iv_ktopl = space ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_entries ) exp = 2
                                            msg = 'Other area, application area or chart of accounts excluded' ).
        cl_abap_unit_assert=>assert_equals( act = lt_entries[ 1 ]-key04 exp = CONV string( gc_test-code_low )
                                            msg = 'Ordered by the key values' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every key and result value is read (trailing blanks dropped, nothing truncated)
  METHOD keys_and_results_read.
    TRY.
        insert_entry( iv_applk = gc_test-applk iv_area = gc_test-area iv_ktopl = gc_test-ktopl
                      iv_code = gc_test-code_high ).
        DATA(lt_entries) = mo_cut->read_entries( iv_applk = gc_test-applk
                                                 iv_area  = gc_test-area
                                                 iv_ktopl = gc_test-ktopl ).
        DATA(ls_exp) = VALUE zif_cd_ops_postarea_types=>ty_entry( ).
        ls_exp-key01 = gc_test-usage.
        ls_exp-key02 = gc_test-scope.
        ls_exp-key03 = gc_test-scheme.
        ls_exp-key04 = gc_test-code_high.
        ls_exp-fun01 = gc_test-role.
        ls_exp-fun02 = gc_test-compare.
        cl_abap_unit_assert=>assert_equals( act = lt_entries exp = VALUE zif_cd_ops_postarea_types=>tt_entry( ( ls_exp ) )
                                            msg = 'Keys and results of the entry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: a posting area without entries - empty, no exception
  METHOD empty_area_no_entries.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->read_entries( iv_applk = gc_test-applk
                                                                         iv_area  = gc_test-area
                                                                         iv_ktopl = space )
                                             msg = 'No entries' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
