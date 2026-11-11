*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_links.clas.testclasses.abap
*& Purpose:
*& Tests of the linked objects of the break analysis on a fictitious link
*& registry (journal line -> statement line by the assignment): the links
*& effective from the line's object, the rows read per chunk of open lines
*& attributed to their lines (later lines not read), sensitive values
*& masked, a failed read reported (293) without stopping the other links.
*& The link registry data access is a local double. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
CLASS ltd_reg_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_link_dao.
    DATA ms_registry TYPE zif_ca_ops_link_types=>ty_registry.
    DATA mt_rows TYPE zif_ca_ops_link_types=>tt_row.
    DATA mv_fail TYPE abap_bool.
    DATA mv_reads TYPE i.
ENDCLASS.

CLASS ltd_reg_dao IMPLEMENTATION.
  METHOD zif_ca_ops_link_dao~read_registry.
    rs_registry = ms_registry.
  ENDMETHOD.
  METHOD zif_ca_ops_link_dao~read_linked.
    mv_reads += 1.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e222(zca_ops) WITH is_target-object_id is_target-source_name.
    ENDIF.
    rt_rows = mt_rows.
  ENDMETHOD.
  METHOD zif_ca_ops_link_dao~source_fields.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_brk_links DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        layer TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'S4',
        line  TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'S4_STMT_LINE',
        link  TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'S4_ITEM_TO_LINE',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_reg_dao.

    METHODS setup.
    METHODS teardown.
    METHODS object
      IMPORTING
        iv_id     TYPE zif_ca_ops_link_types=>ty_object_id
        iv_source TYPE zif_ca_ops_link_types=>ty_source
        iv_keys   TYPE zif_ca_ops_link_types=>ty_key_list
        iv_fields TYPE string.
    METHODS item
      IMPORTING
        iv_assignment  TYPE zif_ca_ops_brk_types=>ty_assignment
        iv_docln       TYPE zif_ca_ops_brk_types=>ty_docln
        iv_later       TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_item) TYPE zif_ca_ops_brk_types=>ty_item.
    METHODS row
      IMPORTING
        iv_chect      TYPE clike
        iv_vgext      TYPE clike
      RETURNING
        VALUE(rs_row) TYPE zif_ca_ops_link_types=>ty_row.

    METHODS links_from_the_line_object  FOR TESTING.
    METHODS rows_attributed_to_lines    FOR TESTING.
    METHODS failed_read_is_a_problem    FOR TESTING.
ENDCLASS.


CLASS ltc_brk_links IMPLEMENTATION.

  METHOD setup.
    DATA ls_layer TYPE zif_ca_ops_link_types=>ty_layer.
    DATA ls_link TYPE zif_ca_ops_link_types=>ty_link.
    DATA ls_cond TYPE zif_ca_ops_link_types=>ty_cond.
    mo_dao = NEW #( ).
    zcl_ca_ops_injector=>inject_params( NEW zcl_ca_ops_param_seed( )->params( ) ).
    ls_layer-layer_id   = gc-layer.
    ls_layer-layer_kind = 'S'.
    ls_layer-layer_rank = 10.
    ls_layer-id_prefix  = 'S4_'.
    ls_layer-active     = abap_true.
    INSERT ls_layer INTO TABLE mo_dao->ms_registry-layers.
    object( iv_id = zif_ca_ops_brk_types=>gc_item_object iv_source = 'I_JOURNALENTRYITEM'
            iv_keys = 'LEDGER,COMPANYCODE,FISCALYEAR,ACCOUNTINGDOCUMENT,LEDGERGLLINEITEM'
            iv_fields = `LEDGER,COMPANYCODE,FISCALYEAR,ACCOUNTINGDOCUMENT,LEDGERGLLINEITEM,ASSIGNMENTREFERENCE` ).
    object( iv_id = gc-line iv_source = 'FEBEP' iv_keys = 'KUKEY,ESNUM' iv_fields = `KUKEY,ESNUM,CHECT,VGEXT` ).
    mo_dao->ms_registry-fields[ object_id = gc-line field_name = 'KUKEY' ]-sensitivity = 'M'.
    ls_link-link_id     = gc-link.
    ls_link-layer_id    = gc-layer.
    ls_link-from_object = zif_ca_ops_brk_types=>gc_item_object.
    ls_link-to_object   = gc-line.
    ls_link-cardinality = zif_ca_ops_link_types=>gc_cardinality-many_many.
    ls_link-quality     = 'C'.
    ls_link-active      = abap_true.
    INSERT ls_link INTO TABLE mo_dao->ms_registry-links.
    ls_cond-link_id   = gc-link.
    ls_cond-cond_no   = 1.
    ls_cond-cond_kind = 'EQ'.
    ls_cond-from_ref  = 'I_JOURNALENTRYITEM-ASSIGNMENTREFERENCE'.
    ls_cond-to_ref    = 'FEBEP-CHECT'.
    INSERT ls_cond INTO TABLE mo_dao->ms_registry-conds.
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD object.
    DATA ls_object TYPE zif_ca_ops_link_types=>ty_object.
    DATA ls_field TYPE zif_ca_ops_link_types=>ty_field.
    ls_object-object_id   = iv_id.
    ls_object-layer_id    = gc-layer.
    ls_object-source_name = iv_source.
    ls_object-source_kind = zif_ca_ops_link_types=>gc_source_kind-table.
    ls_object-key_fields  = iv_keys.
    ls_object-active      = abap_true.
    INSERT ls_object INTO TABLE mo_dao->ms_registry-objects.
    LOOP AT zcl_ca_ops_util=>split_list( iv_fields ) ASSIGNING FIELD-SYMBOL(<lv_field>).
      CLEAR ls_field.
      ls_field-object_id   = iv_id.
      ls_field-field_name  = <lv_field>.
      ls_field-layer_id    = gc-layer.
      ls_field-source_name = iv_source.
      ls_field-evidence    = zif_ca_ops_link_types=>gc_evidence-confirmed.
      INSERT ls_field INTO TABLE mo_dao->ms_registry-fields.
    ENDLOOP.
  ENDMETHOD.


  METHOD item.
    rs_item-ledger     = '0L'.
    rs_item-bukrs      = 'ZT01'.
    rs_item-gjahr      = '2026'.
    rs_item-belnr      = '0100000001'.
    rs_item-docln      = iv_docln.
    rs_item-assignment = iv_assignment.
    rs_item-later      = iv_later.
  ENDMETHOD.


  METHOD row.
    rs_row-pairs = VALUE #( ( fieldname = 'KUKEY' value = '00001234' ) ( fieldname = 'ESNUM' value = '1' )
                            ( fieldname = 'CHECT' value = iv_chect ) ( fieldname = 'VGEXT' value = iv_vgext ) ).
  ENDMETHOD.


  " Rule: only links from the journal line's object are offered to the bucket rules
  METHOD links_from_the_line_object.
    TRY.
        DATA(lt_links) = NEW zcl_ca_ops_brk_links( mo_dao )->zif_ca_ops_brk_links~effective_links( ).
        cl_abap_unit_assert=>assert_equals( act = lt_links exp = VALUE zif_ca_ops_link_types=>tt_link_id( ( gc-link ) )
                                            msg = 'The effective link' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a row belongs to the open lines whose assignment it matches; masked key; later lines not read
  METHOD rows_attributed_to_lines.
    TRY.
        mo_dao->mt_rows = VALUE #( ( row( iv_chect = 'A1' iv_vgext = '452' ) )
                                   ( row( iv_chect = 'A9' iv_vgext = '165' ) ) ).
        NEW zcl_ca_ops_brk_links( mo_dao )->zif_ca_ops_brk_links~read(
          EXPORTING iv_area   = 'ZT_OPS_A'
                    it_fields = VALUE #( ( link_id = gc-link field = 'VGEXT' ) )
                    it_items  = VALUE #( ( item( iv_assignment = 'A1' iv_docln = '000001' ) )
                                         ( item( iv_assignment = 'A1' iv_docln = '000002' iv_later = abap_true ) ) )
          IMPORTING et_hits   = DATA(lt_hits) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_hits ) exp = 1 msg = 'One row of the open line' ).
        cl_abap_unit_assert=>assert_equals( act = lt_hits[ 1 ]-object_id exp = gc-line msg = 'Linked object' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>value_of( it_pairs = lt_hits[ 1 ]-pairs iv_field = 'VGEXT' )
          exp = '452' msg = 'Compared field' ).
        cl_abap_unit_assert=>assert_differs( act = lt_hits[ 1 ]-row_key exp = '00001234/1' msg = 'Key masked' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_reads exp = 1 msg = 'One read for the chunk' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a read that fails is a problem (293); the lines see no row of that link
  METHOD failed_read_is_a_problem.
    TRY.
        mo_dao->mv_fail = abap_true.
        NEW zcl_ca_ops_brk_links( mo_dao )->zif_ca_ops_brk_links~read(
          EXPORTING iv_area     = 'ZT_OPS_A'
                    it_fields   = VALUE #( ( link_id = gc-link field = 'VGEXT' ) )
                    it_items    = VALUE #( ( item( iv_assignment = 'A1' iv_docln = '000001' ) ) )
          IMPORTING et_hits     = DATA(lt_hits)
                    et_problems = DATA(lt_problems) ).
        cl_abap_unit_assert=>assert_initial( act = lt_hits msg = 'No row' ).
        cl_abap_unit_assert=>assert_equals( act = lt_problems[ 1 ]-msgno exp = zif_ca_ops_brk_types=>gc_msg-link_failed
                                            msg = 'Problem 293' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
