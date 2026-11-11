*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_links.clas.testclasses.abap
*& Purpose:
*& Unit tests of the registry check on a data access double: a valid
*& registry gives only the summary (I, counts of effective links and
*& problems); a rule broken by a row (an active link on a VERIFY field) is
*& a warning LINK_REGISTRY naming the link; a declared field the runtime
*& DDIC of its source does not know, and an unknown source, are warnings
*& LINK_DDIC. No database. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
CLASS ltd_link_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_link_dao PARTIALLY IMPLEMENTED.
    DATA ms_registry TYPE zif_ca_ops_link_types=>ty_registry.
    "! Sources the runtime DDIC knows, with their fields
    DATA mt_known TYPE zif_ca_ops_chk_types=>tt_field.
    DATA mv_known_source TYPE zif_ca_ops_link_types=>ty_source.
ENDCLASS.

CLASS ltd_link_dao IMPLEMENTATION.
  METHOD zif_ca_ops_link_dao~read_registry.
    rs_registry = ms_registry.
  ENDMETHOD.

  METHOD zif_ca_ops_link_dao~source_fields.
    IF iv_source = mv_known_source.
      rt_fields = mt_known.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_links DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        layer  TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'XX',
        doc    TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'XX_DOC',
        item   TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'XX_ITEM',
        link   TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'XX_DOC_TO_ITEMS',
        doc_t  TYPE zif_ca_ops_link_types=>ty_source VALUE 'ZXX_DOC',
        item_t TYPE zif_ca_ops_link_types=>ty_source VALUE 'ZXX_ITEM',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_link_dao.
    DATA mo_cut TYPE REF TO zif_ca_ops_check.

    METHODS setup.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.
    METHODS count_code
      IMPORTING
        is_result       TYPE zif_ca_ops_chk_types=>ty_result
        iv_code         TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rv_count) TYPE i.

    METHODS valid_registry_summary   FOR TESTING.
    METHODS broken_rule_is_warning   FOR TESTING.
    METHODS unknown_ddic_field_found FOR TESTING.
ENDCLASS.


CLASS ltc_chk_links IMPLEMENTATION.

  " A document and its items of one customer layer; the DDIC knows both sources and their fields
  METHOD setup.
    DATA ls_layer TYPE zif_ca_ops_link_types=>ty_layer.
    DATA ls_object TYPE zif_ca_ops_link_types=>ty_object.
    DATA ls_field TYPE zif_ca_ops_link_types=>ty_field.
    DATA ls_link TYPE zif_ca_ops_link_types=>ty_link.
    DATA ls_cond TYPE zif_ca_ops_link_types=>ty_cond.

    mo_dao = NEW ltd_link_dao( ).
    ls_layer-layer_id   = gc-layer.
    ls_layer-layer_kind = zif_ca_ops_link_types=>gc_layer_kind-customer.
    ls_layer-layer_rank = 30.
    ls_layer-id_prefix  = 'XX_'.
    ls_layer-active     = abap_true.
    INSERT ls_layer INTO TABLE mo_dao->ms_registry-layers.
    ls_object-object_id   = gc-doc.
    ls_object-layer_id    = gc-layer.
    ls_object-source_name = gc-doc_t.
    ls_object-key_fields  = 'DOCNO'.
    ls_object-active      = abap_true.
    INSERT ls_object INTO TABLE mo_dao->ms_registry-objects.
    ls_object-object_id   = gc-item.
    ls_object-source_name = gc-item_t.
    INSERT ls_object INTO TABLE mo_dao->ms_registry-objects.
    ls_field-object_id   = gc-doc.
    ls_field-field_name  = 'DOCNO'.
    ls_field-layer_id    = gc-layer.
    ls_field-source_name = gc-doc_t.
    ls_field-evidence    = zif_ca_ops_link_types=>gc_evidence-confirmed.
    INSERT ls_field INTO TABLE mo_dao->ms_registry-fields.
    ls_field-object_id   = gc-item.
    ls_field-source_name = gc-item_t.
    INSERT ls_field INTO TABLE mo_dao->ms_registry-fields.
    ls_link-link_id     = gc-link.
    ls_link-layer_id    = gc-layer.
    ls_link-from_object = gc-doc.
    ls_link-to_object   = gc-item.
    ls_link-cardinality = zif_ca_ops_link_types=>gc_cardinality-one_many.
    ls_link-quality     = zif_ca_ops_link_types=>gc_quality-confirmed.
    ls_link-active      = abap_true.
    INSERT ls_link INTO TABLE mo_dao->ms_registry-links.
    ls_cond-link_id   = gc-link.
    ls_cond-cond_no   = 1.
    ls_cond-cond_kind = zif_ca_ops_link_types=>gc_cond_kind-eq.
    ls_cond-from_ref  = |{ gc-doc_t }-DOCNO|.
    ls_cond-to_ref    = |{ gc-item_t }-DOCNO|.
    INSERT ls_cond INTO TABLE mo_dao->ms_registry-conds.
    mo_dao->mv_known_source = gc-doc_t.
    INSERT VALUE #( fieldname = 'DOCNO' type_kind = cl_abap_typedescr=>typekind_char ) INTO TABLE mo_dao->mt_known.
    mo_cut = NEW zcl_ca_ops_chk_links( mo_dao ).
  ENDMETHOD.


  METHOD run.
    rs_result = mo_cut->run( is_check   = VALUE #( check_id = 'LINKS' )
                             is_context = VALUE #( today = '20261111' ) ).
  ENDMETHOD.


  METHOD count_code.
    LOOP AT is_result-findings TRANSPORTING NO FIELDS WHERE check_code = iv_code.
      rv_count = rv_count + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD valid_registry_summary.
    TRY.
        mo_dao->mv_known_source = space.
        CLEAR mo_dao->ms_registry-objects.
        CLEAR mo_dao->ms_registry-links.
        CLEAR mo_dao->ms_registry-fields.
        CLEAR mo_dao->ms_registry-conds.
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'Only the summary' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity
                                            exp = zif_ca_ops_types=>gc_severity-info msg = 'Information' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an active link on a VERIFY field is reported and left out of every walk
  METHOD broken_rule_is_warning.
    TRY.
        mo_dao->ms_registry-fields[ object_id = gc-item field_name = 'DOCNO' ]-evidence =
          zif_ca_ops_link_types=>gc_evidence-verify.
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_equals( act = count_code( is_result = ls_result
                                                              iv_code   = zif_ca_ops_link_types=>gc_code-problem )
                                            exp = 1 msg = 'One rule broken' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ check_code = zif_ca_ops_link_types=>gc_code-problem
                                                                    ]-reference
                                            exp = gc-link msg = 'The finding names the link' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a declared field must exist in the runtime DDIC of its source
  METHOD unknown_ddic_field_found.
    TRY.
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_equals( act = count_code( is_result = ls_result
                                                              iv_code   = zif_ca_ops_link_types=>gc_code-ddic )
                                            exp = 1 msg = 'The item source is unknown to the DDIC' ).
        cl_abap_unit_assert=>assert_equals( act = count_code( is_result = ls_result
                                                              iv_code   = zif_ca_ops_link_types=>gc_code-problem )
                                            exp = 0 msg = 'The rows themselves are valid' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
