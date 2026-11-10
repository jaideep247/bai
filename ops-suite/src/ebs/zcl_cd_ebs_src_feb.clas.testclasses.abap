*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_src_feb.clas.testclasses.abap
*& Purpose:
*& Tests the mapping of imported statements (FEBKO/FEBEP rows from LTD_FEB_DAO)
*& into the format-neutral model and the packaging by statement. Does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A34: an unknown debit/credit indicator stays unknown.
*& 2026-11-06 | Audit A28: return reason from the configured FEBEP field.
*& 2026-11-06 | Audit A68: inverted date range raises.
*& 2026-11-06 | Operating model: posting state from the FEBEP posting-area flags; NONE switches it off.
*& 2026-11-06 | Performance fix 3: reason and posting flags come with the items (one FEBEP read); reads counted.
*& 2026-11-06 | Return reason correction: FEBEP carries no return reason - the line reason stays blank.
*& 2026-11-06 | Modern-syntax sweep: no trailing RETURN.
*& 2026-11-07 | Parameters from the shared fake ZCL_CD_OPS_PARAMS_MEM (ZCL_CD_OPS_INJECTOR=>INJECT_PARAMS)
*&            | instead of a hand-written store double: the semantics of ZCL_CA_OPS_STORE.
*& 2026-11-07 | Parameters over ZCA_PARAM (ZCL_CD_OPS_PARAM_SEED) instead of ZCL_CD_OPS_PARAMS_MEM.
*& 2026-11-07 | FEBEP-VB1OK / VB2OK confirmed as the posted flags (user, 2026-11-07).
*&---------------------------------------------------------------------*
CLASS ltd_feb DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_feb_dao.
    DATA mt_headers TYPE zif_cd_ebs_feb_dao=>tt_header.
    DATA mt_items   TYPE zif_cd_ebs_feb_dao=>tt_item.
    "! Fix 3: extras asked for with the items and number of item reads
    DATA ms_extras  TYPE zif_cd_ebs_feb_dao=>ty_item_extras.
    DATA mv_item_reads TYPE i.
ENDCLASS.

CLASS ltd_feb IMPLEMENTATION.
  METHOD zif_cd_ebs_feb_dao~get_headers.
    rt_headers = mt_headers.
  ENDMETHOD.
  METHOD zif_cd_ebs_feb_dao~get_items.
    ms_extras = is_extras.
    mv_item_reads += 1.
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
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

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
    METHODS unknown_epvoz_has_no_sign    FOR TESTING.
    METHODS no_return_reason_from_febep  FOR TESTING.
    METHODS inverted_date_range_raises   FOR TESTING.
    METHODS posting_state_from_febep     FOR TESTING.
    METHODS posting_state_off_with_none  FOR TESTING.
ENDCLASS.


CLASS ltc_src_feb IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_params = NEW #( ).
    zcl_cd_ebs_injector=>inject_feb_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
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


  " A34: an indicator that is neither the configured credit nor debit value stays unknown
  " (S02 reports it) - it is never silently turned into a debit
  METHOD unknown_epvoz_has_no_sign.
    TRY.
        add_header( gc_test-kukey1 ).
        add_item( iv_kukey = gc_test-kukey1 iv_esnum = '00001' iv_epvoz = 'X' ).
        DATA(ls_package) = new_source( )->next_package( ).
        cl_abap_unit_assert=>assert_initial( act = ls_package-lines[ 1 ]-cdi
                                             msg = 'An unknown EPVOZ must not become debit or credit' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Return reason correction: FEBEP carries no return reason - the FEB source leaves the line's
  " reason blank (R05 reads it from the returns lot item DFKKRP-RLGRD) and still reads once
  METHOD no_return_reason_from_febep.
    TRY.
        add_header( gc_test-kukey1 ).
        add_item( iv_kukey = gc_test-kukey1 iv_esnum = '00001' ).
        DATA(ls_package) = new_source( )->next_package( ).
        cl_abap_unit_assert=>assert_initial( act = ls_package-lines[ 1 ]-return_reason
                                             msg = 'FEBEP has no return reason - the line reason stays blank' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_item_reads exp = 1
                                            msg = 'Items and posting flags must come in one FEBEP read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A68: a date range whose start lies after its end is an error (message 527), not an empty feed
  METHOD inverted_date_range_raises.
    TRY.
        zcl_cd_ebs_src_feb=>check_selection( VALUE #( date_from = '20261106' date_to = '20261105' ) ).
        cl_abap_unit_assert=>fail( msg = 'An inverted date range must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = zif_cd_ebs_types=>gc_msg-date_range
                                            msg = 'Message 527 expected for an inverted date range' ).
    ENDTRY.
  ENDMETHOD.

  " Operating model 2026-11-06: an imported entry is posted when every FEBEP posting-area flag
  " (EBS_FEB_POSTED_FIELDS, default VB1OK / VB2OK - confirmed 2026-11-07) is complete, else open.
  " Fix 3: the flags come with the item (same FEBEP read), so every item read has a state
  METHOD posting_state_from_febep.
    TRY.
        add_header( gc_test-kukey1 ).
        add_item( iv_kukey = gc_test-kukey1 iv_esnum = '00001' ).
        add_item( iv_kukey = gc_test-kukey1 iv_esnum = '00002' ).
        mo_dao->mt_items[ 1 ]-posted = abap_true.
        DATA(ls_package) = new_source( )->next_package( ).
        cl_abap_unit_assert=>assert_equals( act = ls_package-lines[ esnum = '00001' ]-posting_state
                                            exp = zif_cd_ebs_types=>gc_posting_state-posted
                                            msg = 'Complete posting areas must give posting state P' ).
        cl_abap_unit_assert=>assert_equals( act = ls_package-lines[ esnum = '00002' ]-posting_state
                                            exp = zif_cd_ebs_types=>gc_posting_state-open
                                            msg = 'An incomplete posting area must give posting state O' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->ms_extras-posted_fields ) exp = 2
                                            msg = 'The delivered default names two posting-area flags' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_extras-posted_fields[ 1 ] exp = `VB1OK`
                                            msg = 'Posting area 1 flag VB1OK is read first' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_item_reads exp = 1
                                            msg = 'The posting flags must come with the item read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " EBS_FEB_POSTED_FIELDS = NONE: the posting state is not read - every entry stays unknown and
  " the posting-dependent rules behave as before
  METHOD posting_state_off_with_none.
    TRY.
        mo_params->set( iv_name  = zif_cd_ebs_types=>gc_param-feb_posted_fields
                        iv_value = zif_cd_ebs_types=>gc_param_default-feb_posted_off ).
        add_header( gc_test-kukey1 ).
        add_item( iv_kukey = gc_test-kukey1 iv_esnum = '00001' ).
        DATA(ls_package) = new_source( )->next_package( ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->ms_extras-posted_fields
                                             msg = 'NONE must not read the posting state' ).
        cl_abap_unit_assert=>assert_equals( act = ls_package-lines[ 1 ]-posting_state
                                            exp = zif_cd_ebs_types=>gc_posting_state-unknown
                                            msg = 'Without the read the posting state stays unknown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
