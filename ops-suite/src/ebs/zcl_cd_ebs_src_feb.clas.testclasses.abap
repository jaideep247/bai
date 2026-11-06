*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_src_feb.clas.testclasses.abap
*& Purpose:
*& Tests the mapping of imported statements (FEBKO/FEBEP rows from LTD_FEB_DAO)
*& into the format-neutral model and the packaging by statement. Does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltd_feb DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_feb_dao.
    DATA mt_headers TYPE zif_cd_ebs_feb_dao=>tt_header.
    DATA mt_items   TYPE zif_cd_ebs_feb_dao=>tt_item.
ENDCLASS.

CLASS ltd_feb IMPLEMENTATION.
  METHOD zif_cd_ebs_feb_dao~get_headers.
    rt_headers = mt_headers.
  ENDMETHOD.
  METHOD zif_cd_ebs_feb_dao~get_items.
    LOOP AT mt_items INTO DATA(ls_item).
      IF line_exists( it_kukey[ table_line = ls_item-kukey ] ).
        INSERT ls_item INTO TABLE rt_items.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ebs_feb_dao~get_prior_header.
    CLEAR rs_header.
  ENDMETHOD.
  METHOD zif_cd_ebs_feb_dao~statement_exists.
    CLEAR rv_exists.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~start_run.
    rs_run-module = iv_module.
  ENDMETHOD.
  METHOD zif_cd_ops_store~save_findings.
    cs_run-finding_count = cs_run-finding_count + lines( it_findings ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~finish_run.
    RETURN.
  ENDMETHOD.
  METHOD zif_cd_ops_store~commit.
    RETURN.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_param.
    rv_value = iv_default.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_last_run.
    CLEAR rs_run.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_runs_since.
    CLEAR rt_runs.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_findings.
    CLEAR rt_findings.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_src_feb DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        kukey1 TYPE zif_cd_ebs_types=>ty_kukey VALUE '00001001',
        kukey2 TYPE zif_cd_ebs_types=>ty_kukey VALUE '00001002',
        kukey3 TYPE zif_cd_ebs_types=>ty_kukey VALUE '00001003',
      END OF gc_test.

    DATA mo_dao TYPE REF TO ltd_feb.

    METHODS setup.
    METHODS teardown.
    METHODS add_header
      IMPORTING
        iv_kukey TYPE zif_cd_ebs_types=>ty_kukey.
    METHODS add_item
      IMPORTING
        iv_kukey TYPE zif_cd_ebs_types=>ty_kukey
        iv_esnum TYPE zif_cd_ebs_types=>ty_esnum
        iv_epvoz TYPE char1 DEFAULT 'H'
        iv_vorgc TYPE char3 DEFAULT '168'
        iv_vgext TYPE char27 OPTIONAL.
    METHODS new_source
      IMPORTING
        iv_package_size  TYPE i DEFAULT 50
      RETURNING
        VALUE(ro_source) TYPE REF TO zif_cd_ebs_source.

    METHODS debit_balance_is_negative    FOR TESTING.
    METHODS h_entry_maps_to_credit       FOR TESTING.
    METHODS bai_code_comes_from_vorgc    FOR TESTING.
    METHODS camt_code_split_into_parts   FOR TESTING.
    METHODS lines_keyed_to_statement     FOR TESTING.
    METHODS packages_follow_size         FOR TESTING.
ENDCLASS.


CLASS ltc_src_feb IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_ebs_injector=>inject_feb_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_store( NEW ltd_store( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ebs_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD add_header.
    DATA ls_header TYPE zif_cd_ebs_feb_dao=>ty_header.
    ls_header-kukey = iv_kukey.
    ls_header-bukrs = 'US01'.
    ls_header-hbkid = 'JPMC1'.
    ls_header-hktid = 'DISB1'.
    ls_header-aznum = '00042'.
    ls_header-azdat = '20261105'.
    ls_header-waers = 'USD'.
    ls_header-ssbtr = '1000.00'.
    ls_header-ssvoz = 'S'.
    ls_header-esbtr = '750.00'.
    ls_header-esvoz = 'H'.
    ls_header-anzes = 2.
    INSERT ls_header INTO TABLE mo_dao->mt_headers.
  ENDMETHOD.


  METHOD add_item.
    DATA ls_item TYPE zif_cd_ebs_feb_dao=>ty_item.
    ls_item-kukey = iv_kukey.
    ls_item-esnum = iv_esnum.
    ls_item-vorgc = iv_vorgc.
    ls_item-vgext = iv_vgext.
    ls_item-epvoz = iv_epvoz.
    ls_item-kwbtr = '-125.00'.
    ls_item-kwaer = 'USD'.
    ls_item-budat = '20261105'.
    ls_item-valut = '20261105'.
    ls_item-chect = '0000000012345'.
    INSERT ls_item INTO TABLE mo_dao->mt_items.
  ENDMETHOD.


  METHOD new_source.
    DATA ls_selection TYPE zif_cd_ebs_feb_dao=>ty_selection.
    ls_selection-date_from = '20261101'.
    ls_selection-date_to   = '20261105'.
    ro_source = NEW zcl_cd_ebs_src_feb( is_selection = ls_selection iv_package_size = iv_package_size ).
  ENDMETHOD.


  " FEBKO balance with debit indicator S is a negative (debit) balance
  METHOD debit_balance_is_negative.
    TRY.
        add_header( gc_test-kukey1 ).
        DATA(ls_package) = new_source( )->next_package( ).
        DATA(ls_statement) = ls_package-statements[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_statement-opening_bal exp = '-1000.00'
                                            msg = 'Opening with SSVOZ = S must be negative' ).
        cl_abap_unit_assert=>assert_equals( act = ls_statement-closing_bal exp = '750.00'
                                            msg = 'Closing with ESVOZ = H must be positive' ).
        cl_abap_unit_assert=>assert_equals( act = ls_statement-declared_count exp = 2
                                            msg = 'Declared count must come from ANZES' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " FEBEP-EPVOZ H is a credit entry; the amount is always positive
  METHOD h_entry_maps_to_credit.
    TRY.
        add_header( gc_test-kukey1 ).
        add_item( iv_kukey = gc_test-kukey1 iv_esnum = '00001' ).
        DATA(ls_package) = new_source( )->next_package( ).
        DATA(ls_line) = ls_package-lines[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_line-cdi exp = zif_cd_ebs_types=>gc_cdi-credit
                                            msg = 'EPVOZ H must map to credit' ).
        cl_abap_unit_assert=>assert_equals( act = ls_line-amount exp = '125.00'
                                            msg = 'Amount must be positive' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " BAI statements: the type code is FEBEP-VORGC (legacy validators' field)
  METHOD bai_code_comes_from_vorgc.
    TRY.
        add_header( gc_test-kukey1 ).
        add_item( iv_kukey = gc_test-kukey1 iv_esnum = '00001' ).
        DATA(ls_package) = new_source( )->next_package( ).
        DATA(ls_line) = ls_package-lines[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_line-scheme exp = zif_cd_ebs_types=>gc_scheme-bai2
                                            msg = 'VORGC must be read as a BAI2 code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_line-btc_code exp = '168'
                                            msg = 'BAI code must be VORGC' ).
        cl_abap_unit_assert=>assert_equals( act = ls_line-reference exp = '0000000012345'
                                            msg = 'Reference must be FEBEP-CHECT' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " CAMT statements: VGEXT PMNT+ICDT+ESCT is split into domain/family/sub-family
  METHOD camt_code_split_into_parts.
    TRY.
        add_header( gc_test-kukey1 ).
        add_item( iv_kukey = gc_test-kukey1 iv_esnum = '00001' iv_vorgc = space iv_vgext = 'PMNT+ICDT+ESCT' ).
        DATA(ls_package) = new_source( )->next_package( ).
        DATA(ls_line) = ls_package-lines[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_line-scheme exp = zif_cd_ebs_types=>gc_scheme-iso
                                            msg = 'Structured VGEXT must be an ISO code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_line-btc_code exp = 'PMNT-ICDT-ESCT'
                                            msg = 'ISO code must be normalised to DOMN-FMLY-SUBF' ).
        cl_abap_unit_assert=>assert_equals( act = ls_line-subfamily exp = 'ESCT'
                                            msg = 'Sub-family must be split out' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Lines carry the statement key FEB<kukey> and the line number ESNUM
  METHOD lines_keyed_to_statement.
    TRY.
        add_header( gc_test-kukey1 ).
        add_item( iv_kukey = gc_test-kukey1 iv_esnum = '00007' ).
        DATA(ls_package) = new_source( )->next_package( ).
        cl_abap_unit_assert=>assert_equals( act = ls_package-lines[ 1 ]-stmt_key
                                            exp = ls_package-statements[ 1 ]-stmt_key
                                            msg = 'Line must belong to its statement' ).
        cl_abap_unit_assert=>assert_equals( act = ls_package-lines[ 1 ]-line_no exp = 7
                                            msg = 'Line number must be ESNUM' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Package size 2 over 3 statements: packages of 2, 1, then end
  METHOD packages_follow_size.
    TRY.
        add_header( gc_test-kukey1 ).
        add_header( gc_test-kukey2 ).
        add_header( gc_test-kukey3 ).
        DATA(lo_source) = new_source( iv_package_size = 2 ).
        DATA(ls_first) = lo_source->next_package( ).
        DATA(ls_second) = lo_source->next_package( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_first-statements ) exp = 2
                                            msg = 'First package must hold 2 statements' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_second-statements ) exp = 1
                                            msg = 'Second package must hold the last statement' ).
        cl_abap_unit_assert=>assert_initial( act = lo_source->next_package( )
                                             msg = 'Third call must end the run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
