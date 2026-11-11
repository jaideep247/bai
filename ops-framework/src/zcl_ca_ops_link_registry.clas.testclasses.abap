*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_link_registry.clas.testclasses.abap
*& Purpose:
*& Unit tests of the pure link registry rules on a fictitious registry
*& (standard layer ZS with prefix ZS_, customer layer XX with prefix XX_):
*& a valid registry has no problem and gives its chains (head and
*& fallback); an active link on a VERIFY field (218), a cyclic fallback
*& chain (216), a "to one" link without the target's keys (217), a
*& sensitive field as a constant (223), a replacement of a link of the same
*& layer (224), an ID without its layer prefix (231), a reference of
*& another source (234) are problems and take the link out; activation
*& overrides switch a link or a layer off; a replacement of a switched-on
*& layer wins; a chain stops at its first link that is not effective.
*& No database. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
CLASS ltc_link_registry DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        std        TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'ZS',
        cust       TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'XX',
        doc        TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'ZS_DOC',
        item       TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'ZS_ITEM',
        request    TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'XX_REQUEST',
        doc_items  TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'ZS_DOC_TO_ITEMS',
        item_doc   TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'ZS_ITEM_TO_DOC',
        item_req   TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'XX_ITEM_TO_REQ',
        item_req2  TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'XX_ITEM_TO_REQ_ALT',
        own_items  TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'XX_DOC_TO_ITEMS',
      END OF gc.

    DATA ms_registry TYPE zif_ca_ops_link_types=>ty_registry.

    METHODS setup.
    METHODS layer
      IMPORTING
        iv_id     TYPE zif_ca_ops_link_types=>ty_layer_id
        iv_kind   TYPE zif_ca_ops_link_types=>ty_flag1
        iv_rank   TYPE i
        iv_prefix TYPE zif_ca_ops_link_types=>ty_layer_id.
    METHODS object
      IMPORTING
        iv_id     TYPE zif_ca_ops_link_types=>ty_object_id
        iv_layer  TYPE zif_ca_ops_link_types=>ty_layer_id
        iv_source TYPE zif_ca_ops_link_types=>ty_source
        iv_keys   TYPE zif_ca_ops_link_types=>ty_key_list.
    METHODS field
      IMPORTING
        iv_object   TYPE zif_ca_ops_link_types=>ty_object_id
        iv_name     TYPE zif_ca_ops_link_types=>ty_fieldname
        iv_layer    TYPE zif_ca_ops_link_types=>ty_layer_id
        iv_evidence TYPE zif_ca_ops_link_types=>ty_flag1 DEFAULT 'C'
        iv_sens     TYPE zif_ca_ops_link_types=>ty_flag1 OPTIONAL.
    METHODS link
      IMPORTING
        iv_id          TYPE zif_ca_ops_link_types=>ty_link_id
        iv_layer       TYPE zif_ca_ops_link_types=>ty_layer_id
        iv_from        TYPE zif_ca_ops_link_types=>ty_object_id
        iv_to          TYPE zif_ca_ops_link_types=>ty_object_id
        iv_cardinality TYPE zif_ca_ops_link_types=>ty_cardinality DEFAULT 'NM'
        iv_fallback_of TYPE zif_ca_ops_link_types=>ty_link_id OPTIONAL
        iv_replaces    TYPE zif_ca_ops_link_types=>ty_link_id OPTIONAL.
    METHODS cond
      IMPORTING
        iv_link  TYPE zif_ca_ops_link_types=>ty_link_id
        iv_no    TYPE i
        iv_kind  TYPE zif_ca_ops_link_types=>ty_cond_kind DEFAULT 'EQ'
        iv_from  TYPE zif_ca_ops_link_types=>ty_field_ref OPTIONAL
        iv_to    TYPE zif_ca_ops_link_types=>ty_field_ref
        iv_value TYPE zif_ca_ops_link_types=>ty_value OPTIONAL.
    METHODS has_problem
      IMPORTING
        iv_subject    TYPE clike
        iv_msgno      TYPE zif_ca_ops_types=>ty_msgno
      RETURNING
        VALUE(rv_has) TYPE abap_bool.
    METHODS is_effective
      IMPORTING
        iv_link       TYPE zif_ca_ops_link_types=>ty_link_id
      RETURNING
        VALUE(rv_on)  TYPE abap_bool.

    METHODS valid_registry_no_problem  FOR TESTING.
    METHODS chain_head_then_fallback   FOR TESTING.
    METHODS active_link_on_verify      FOR TESTING.
    METHODS cyclic_fallback_found      FOR TESTING.
    METHODS to_one_needs_target_keys   FOR TESTING.
    METHODS sensitive_constant_refused FOR TESTING.
    METHODS replace_same_layer_refused FOR TESTING.
    METHODS id_without_prefix_refused  FOR TESTING.
    METHODS ref_of_other_source        FOR TESTING.
    METHODS override_switches_link_off FOR TESTING.
    METHODS override_switches_layer    FOR TESTING.
    METHODS replacement_wins           FOR TESTING.
    METHODS chain_stops_at_inactive    FOR TESTING.
ENDCLASS.


CLASS ltc_link_registry IMPLEMENTATION.

  " A standard document with its items, a customer request table and a custom field on the item
  METHOD setup.
    CLEAR ms_registry.
    layer( iv_id = gc-std iv_kind = 'S' iv_rank = 10 iv_prefix = 'ZS_' ).
    layer( iv_id = gc-cust iv_kind = 'C' iv_rank = 30 iv_prefix = 'XX_' ).
    object( iv_id = gc-doc iv_layer = gc-std iv_source = 'ZDOC' iv_keys = 'DOCNO' ).
    field( iv_object = gc-doc iv_name = 'DOCNO' iv_layer = gc-std ).
    object( iv_id = gc-item iv_layer = gc-std iv_source = 'ZITEM' iv_keys = 'DOCNO,ITEMNO' ).
    field( iv_object = gc-item iv_name = 'DOCNO' iv_layer = gc-std ).
    field( iv_object = gc-item iv_name = 'ITEMNO' iv_layer = gc-std ).
    field( iv_object = gc-item iv_name = 'ZZXX_REQ' iv_layer = gc-cust ).
    object( iv_id = gc-request iv_layer = gc-cust iv_source = 'ZXX_REQ' iv_keys = 'REQ_ID' ).
    field( iv_object = gc-request iv_name = 'REQ_ID' iv_layer = gc-cust ).
    field( iv_object = gc-request iv_name = 'MEMBER' iv_layer = gc-cust iv_sens = 'M' ).
    link( iv_id = gc-doc_items iv_layer = gc-std iv_from = gc-doc iv_to = gc-item iv_cardinality = '1N' ).
    cond( iv_link = gc-doc_items iv_no = 1 iv_from = 'ZDOC-DOCNO' iv_to = 'ZITEM-DOCNO' ).
    link( iv_id = gc-item_doc iv_layer = gc-std iv_from = gc-item iv_to = gc-doc iv_cardinality = 'N1' ).
    cond( iv_link = gc-item_doc iv_no = 1 iv_from = 'ZITEM-DOCNO' iv_to = 'ZDOC-DOCNO' ).
    link( iv_id = gc-item_req iv_layer = gc-cust iv_from = gc-item iv_to = gc-request iv_cardinality = 'N1' ).
    cond( iv_link = gc-item_req iv_no = 1 iv_from = 'ZITEM-ZZXX_REQ' iv_to = 'ZXX_REQ-REQ_ID' ).
    link( iv_id = gc-item_req2 iv_layer = gc-cust iv_from = gc-item iv_to = gc-request iv_fallback_of = gc-item_req ).
    cond( iv_link = gc-item_req2 iv_no = 1 iv_from = 'ZITEM-DOCNO' iv_to = 'ZXX_REQ-REQ_ID' ).
  ENDMETHOD.


  METHOD layer.
    DATA ls_layer TYPE zif_ca_ops_link_types=>ty_layer.
    ls_layer-layer_id   = iv_id.
    ls_layer-layer_kind = iv_kind.
    ls_layer-layer_rank = iv_rank.
    ls_layer-id_prefix  = iv_prefix.
    ls_layer-active     = abap_true.
    INSERT ls_layer INTO TABLE ms_registry-layers.
  ENDMETHOD.


  METHOD object.
    DATA ls_object TYPE zif_ca_ops_link_types=>ty_object.
    ls_object-object_id   = iv_id.
    ls_object-layer_id    = iv_layer.
    ls_object-source_name = iv_source.
    ls_object-source_kind = zif_ca_ops_link_types=>gc_source_kind-table.
    ls_object-key_fields  = iv_keys.
    ls_object-active      = abap_true.
    INSERT ls_object INTO TABLE ms_registry-objects.
  ENDMETHOD.


  METHOD field.
    DATA ls_field TYPE zif_ca_ops_link_types=>ty_field.
    ls_field-object_id   = iv_object.
    ls_field-field_name  = iv_name.
    ls_field-layer_id    = iv_layer.
    ls_field-source_name = ms_registry-objects[ object_id = iv_object ]-source_name.
    ls_field-evidence    = iv_evidence.
    ls_field-sensitivity = iv_sens.
    ls_field-verify_ref  = COND #( WHEN iv_evidence = 'V' THEN 'V999' ).
    INSERT ls_field INTO TABLE ms_registry-fields.
  ENDMETHOD.


  METHOD link.
    DATA ls_link TYPE zif_ca_ops_link_types=>ty_link.
    ls_link-link_id     = iv_id.
    ls_link-layer_id    = iv_layer.
    ls_link-from_object = iv_from.
    ls_link-to_object   = iv_to.
    ls_link-cardinality = iv_cardinality.
    ls_link-quality     = zif_ca_ops_link_types=>gc_quality-confirmed.
    ls_link-fallback_of = iv_fallback_of.
    ls_link-replaces    = iv_replaces.
    ls_link-active      = abap_true.
    INSERT ls_link INTO TABLE ms_registry-links.
  ENDMETHOD.


  METHOD cond.
    DATA ls_cond TYPE zif_ca_ops_link_types=>ty_cond.
    ls_cond-link_id    = iv_link.
    ls_cond-cond_no    = iv_no.
    ls_cond-cond_kind  = iv_kind.
    ls_cond-from_ref   = iv_from.
    ls_cond-to_ref     = iv_to.
    ls_cond-cond_value = iv_value.
    INSERT ls_cond INTO TABLE ms_registry-conds.
  ENDMETHOD.


  METHOD has_problem.
    DATA(lt_problems) = zcl_ca_ops_link_registry=>validate( ms_registry ).
    rv_has = xsdbool( line_exists( lt_problems[ subject = iv_subject msgno = iv_msgno ] ) ).
  ENDMETHOD.


  METHOD is_effective.
    DATA(ls_effective) = zcl_ca_ops_link_registry=>effective( ms_registry ).
    LOOP AT ls_effective-chains ASSIGNING FIELD-SYMBOL(<ls_chain>).
      IF line_exists( <ls_chain>-links[ table_line = iv_link ] ).
        rv_on = abap_true.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD valid_registry_no_problem.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_link_registry=>validate( ms_registry )
                                             msg = 'The fixture is a valid registry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a fallback is a step of its head's chain, never a chain of its own
  METHOD chain_head_then_fallback.
    TRY.
        DATA(ls_effective) = zcl_ca_ops_link_registry=>effective( ms_registry ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_effective-chains ) exp = 3
                                            msg = 'Three heads: document, item, item to request' ).
        DATA(ls_chain) = ls_effective-chains[ head = gc-item_req ].
        cl_abap_unit_assert=>assert_equals( act = ls_chain-links
                                            exp = VALUE zif_ca_ops_link_types=>tt_link_id( ( gc-item_req )
                                                                                           ( gc-item_req2 ) )
                                            msg = 'Head first, then its fallback' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: never guess a field - an active link uses confirmed fields only
  METHOD active_link_on_verify.
    TRY.
        DATA(lr_field) = REF #( ms_registry-fields[ object_id = gc-item field_name = 'ZZXX_REQ' ] ).
        lr_field->evidence = zif_ca_ops_link_types=>gc_evidence-verify.
        cl_abap_unit_assert=>assert_true( act = has_problem( iv_subject = gc-item_req iv_msgno = '218' )
                                          msg = 'Message 218' ).
        cl_abap_unit_assert=>assert_false( act = is_effective( gc-item_req ) msg = 'The link is left out' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD cyclic_fallback_found.
    TRY.
        DATA(lr_link) = REF #( ms_registry-links[ link_id = gc-item_req ] ).
        lr_link->fallback_of = gc-item_req2.
        cl_abap_unit_assert=>assert_true( act = has_problem( iv_subject = gc-item_req iv_msgno = '216' )
                                          msg = 'Message 216' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: N1 / 11 cover the target's key or prefer one row
  METHOD to_one_needs_target_keys.
    TRY.
        DATA(lr_link) = REF #( ms_registry-links[ link_id = gc-doc_items ] ).
        lr_link->cardinality = zif_ca_ops_link_types=>gc_cardinality-many_one.
        cl_abap_unit_assert=>assert_true( act = has_problem( iv_subject = gc-doc_items iv_msgno = '217' )
                                          msg = 'ITEMNO of the target is not covered' ).
        cond( iv_link = gc-doc_items iv_no = 2 iv_kind = 'PREFER' iv_to = 'ZITEM-ITEMNO' iv_value = '1' ).
        cl_abap_unit_assert=>assert_false( act = has_problem( iv_subject = gc-doc_items iv_msgno = '217' )
                                           msg = 'A preferred row makes it one' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD sensitive_constant_refused.
    TRY.
        cond( iv_link = gc-item_req iv_no = 2 iv_kind = 'CONST' iv_to = 'ZXX_REQ-MEMBER' iv_value = '4711' ).
        cl_abap_unit_assert=>assert_true( act = has_problem( iv_subject = gc-item_req iv_msgno = '223' )
                                          msg = 'A member number is never a literal of the configuration' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD replace_same_layer_refused.
    TRY.
        link( iv_id = 'ZS_DOC_TO_ITEMS_NEW' iv_layer = gc-std iv_from = gc-doc iv_to = gc-item
              iv_replaces = gc-doc_items ).
        cond( iv_link = 'ZS_DOC_TO_ITEMS_NEW' iv_no = 1 iv_from = 'ZDOC-DOCNO' iv_to = 'ZITEM-DOCNO' ).
        cl_abap_unit_assert=>assert_true( act = has_problem( iv_subject = 'ZS_DOC_TO_ITEMS_NEW' iv_msgno = '224' )
                                          msg = 'Only a link of a lower layer can be replaced' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD id_without_prefix_refused.
    TRY.
        link( iv_id = 'YY_ITEM_TO_DOC' iv_layer = gc-cust iv_from = gc-item iv_to = gc-doc ).
        cond( iv_link = 'YY_ITEM_TO_DOC' iv_no = 1 iv_from = 'ZITEM-DOCNO' iv_to = 'ZDOC-DOCNO' ).
        cl_abap_unit_assert=>assert_true( act = has_problem( iv_subject = 'YY_ITEM_TO_DOC' iv_msgno = '231' )
                                          msg = 'IDs of a layer start with its prefix' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD ref_of_other_source.
    TRY.
        DATA(lr_cond) = REF #( ms_registry-conds[ link_id = gc-item_doc cond_no = 1 ] ).
        lr_cond->to_ref = 'ZOTHER-DOCNO'.
        cl_abap_unit_assert=>assert_true( act = has_problem( iv_subject = gc-item_doc iv_msgno = '234' )
                                          msg = 'The reference must name the target object''s source' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a customer switches a standard link off without changing the delivered row
  METHOD override_switches_link_off.
    TRY.
        INSERT VALUE #( target_kind = 'K' target_id = gc-item_doc layer_id = gc-cust active = abap_false )
               INTO TABLE ms_registry-activations.
        cl_abap_unit_assert=>assert_false( act = is_effective( gc-item_doc ) msg = 'Switched off by the override' ).
        cl_abap_unit_assert=>assert_true( act = is_effective( gc-doc_items ) msg = 'Other links unchanged' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD override_switches_layer.
    TRY.
        INSERT VALUE #( target_kind = 'L' target_id = gc-std layer_id = gc-cust active = abap_false )
               INTO TABLE ms_registry-activations.
        cl_abap_unit_assert=>assert_false( act = is_effective( gc-doc_items ) msg = 'The whole layer is off' ).
        cl_abap_unit_assert=>assert_false( act = is_effective( gc-item_req )
                                           msg = 'A customer link between objects of an off layer is off too' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD replacement_wins.
    TRY.
        link( iv_id = gc-own_items iv_layer = gc-cust iv_from = gc-doc iv_to = gc-item iv_cardinality = '1N'
              iv_replaces = gc-doc_items ).
        cond( iv_link = gc-own_items iv_no = 1 iv_from = 'ZDOC-DOCNO' iv_to = 'ZITEM-DOCNO' ).
        cl_abap_unit_assert=>assert_false( act = is_effective( gc-doc_items ) msg = 'The standard link is replaced' ).
        cl_abap_unit_assert=>assert_true( act = is_effective( gc-own_items ) msg = 'The customer link runs' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a fallback alone would change what the chain means - the head off stops the chain
  METHOD chain_stops_at_inactive.
    TRY.
        DATA(lr_link) = REF #( ms_registry-links[ link_id = gc-item_req ] ).
        lr_link->active = abap_false.
        cl_abap_unit_assert=>assert_false( act = is_effective( gc-item_req2 ) msg = 'No chain without its head' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
