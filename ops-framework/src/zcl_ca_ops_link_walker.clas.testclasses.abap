*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_link_walker.clas.testclasses.abap
*& Purpose:
*& Unit tests of the link registry walker on a fictitious registry (standard
*& layer ZS: document, items, reconciliation batch, partner; customer layer
*& XX: request table with attempts, custom field ZZXX_REQ on the item, a
*& partner chain with a fallback) and the in-memory data access double
*& LTD_LINK_DAO, which answers like production (rows whose join values
*& match a source row, constants applied, row cap, refusal of a source it
*& is told to fail). Covered: every level reached, the preferred attempt,
*& the fallback only for the source rows the head found nothing for (step
*& 2), masked partner keys, quality P along a probable link, the path, one
*& read per link and level, the limits LINK_MAX_DEPTH (219),
*& LINK_MAX_NODES (220), LINK_MAX_ROWS (221), a failed read skipped (222),
*& the link filter, refusals 210 / 211 / 041. Parameters from the
*& in-memory parameter store, authorisation from a double (injector).
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
CLASS ltd_link_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_link_dao.
    TYPES:
      BEGIN OF ty_table,
        source TYPE zif_ca_ops_link_types=>ty_source,
        rows   TYPE zif_ca_ops_link_types=>tt_row,
      END OF ty_table.
    TYPES tt_table TYPE STANDARD TABLE OF ty_table WITH EMPTY KEY.
    TYPES tt_source TYPE STANDARD TABLE OF zif_ca_ops_link_types=>ty_source WITH EMPTY KEY.
    DATA ms_registry TYPE zif_ca_ops_link_types=>ty_registry.
    DATA mt_tables TYPE tt_table.
    "! Sources whose read fails (message 222)
    DATA mt_failing TYPE tt_source.
    "! Source of every read in order
    DATA mt_reads TYPE tt_source.
    METHODS add_row
      IMPORTING
        iv_source TYPE zif_ca_ops_link_types=>ty_source
        it_pairs  TYPE zif_ca_ops_link_types=>tt_pair.
ENDCLASS.

CLASS ltd_link_dao IMPLEMENTATION.
  METHOD zif_ca_ops_link_dao~read_registry.
    rs_registry = ms_registry.
  ENDMETHOD.

  METHOD zif_ca_ops_link_dao~read_linked.
    INSERT is_target-source_name INTO TABLE mt_reads.
    IF line_exists( mt_failing[ table_line = is_target-source_name ] ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e222(zca_ops) WITH is_target-object_id is_target-source_name.
    ENDIF.
    READ TABLE mt_tables ASSIGNING FIELD-SYMBOL(<ls_table>) WITH KEY source = is_target-source_name.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    LOOP AT <ls_table>-rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_keep) = abap_false.
      LOOP AT it_sources ASSIGNING FIELD-SYMBOL(<ls_source>).
        IF zcl_ca_ops_link_query=>belongs_to( is_row = <ls_row> is_source = <ls_source> it_conds = it_conds ) = abap_true.
          lv_keep = abap_true.
        ENDIF.
      ENDLOOP.
      LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>) WHERE cond_kind = zif_ca_ops_link_types=>gc_cond_kind-const.
        DATA(lv_value) = zcl_ca_ops_link_query=>value_of(
                           it_pairs = <ls_row>-pairs
                           iv_field = zcl_ca_ops_link_query=>split_ref( <ls_cond>-to_ref )-field ).
        DATA(lt_allowed) = zcl_ca_ops_util=>split_list( <ls_cond>-cond_value ).
        IF NOT line_exists( lt_allowed[ table_line = condense( lv_value ) ] ).
          lv_keep = abap_false.
        ENDIF.
      ENDLOOP.
      IF lv_keep = abap_true.
        IF lines( rt_rows ) >= iv_max_rows.
          RETURN.
        ENDIF.
        INSERT <ls_row> INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_ca_ops_link_dao~source_fields.
    CLEAR rt_fields.
  ENDMETHOD.

  METHOD add_row.
    READ TABLE mt_tables ASSIGNING FIELD-SYMBOL(<ls_table>) WITH KEY source = iv_source.
    IF sy-subrc <> 0.
      INSERT VALUE #( source = iv_source ) INTO TABLE mt_tables ASSIGNING <ls_table>.
    ENDIF.
    INSERT VALUE #( pairs = it_pairs ) INTO TABLE <ls_table>-rows.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_allowed TYPE abap_bool VALUE abap_true.
    DATA mv_activity TYPE zif_ca_ops_auth=>ty_activity.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~check.
    mv_activity = iv_activity.
    IF mv_allowed = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e041(zca_ops) WITH zif_ca_ops_auth=>gc_object iv_activity.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_link_walker DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area        TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        std         TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'ZS',
        cust        TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'XX',
        doc         TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'ZS_DOC',
        item        TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'ZS_ITEM',
        batch       TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'ZS_BATCH',
        partner     TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'ZS_PARTNER',
        request     TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'XX_REQUEST',
        doc_items   TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'ZS_DOC_TO_ITEMS',
        doc_batch   TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'ZS_DOC_TO_BATCH',
        item_req    TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'XX_ITEM_TO_REQ',
        req_bp_fdr  TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'XX_REQ_TO_PARTNER_FDR',
        req_bp      TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'XX_REQ_TO_PARTNER',
        doc_no      TYPE zif_ca_ops_link_types=>ty_key_value VALUE 'D1',
        fikey       TYPE zif_ca_ops_link_types=>ty_key_value VALUE 'K1',
        partner_one TYPE zif_ca_ops_link_types=>ty_key_value VALUE 'P0000001234',
        partner_two TYPE zif_ca_ops_link_types=>ty_key_value VALUE 'P0000005678',
        masked_one  TYPE zif_ca_ops_link_types=>ty_key_value VALUE '*******1234',
        success     TYPE zif_ca_ops_link_types=>ty_value VALUE 'SUCCESS',
        failed      TYPE zif_ca_ops_link_types=>ty_value VALUE 'FAIL',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_link_dao.
    DATA mo_auth TYPE REF TO ltd_auth.
    DATA mo_params TYPE REF TO zcl_ca_ops_param_seed.
    DATA mo_cut TYPE REF TO zif_ca_ops_link_walker.

    METHODS setup.
    METHODS teardown.
    METHODS given_registry.
    METHODS given_rows.
    METHODS layer
      IMPORTING
        iv_id   TYPE zif_ca_ops_link_types=>ty_layer_id
        iv_kind TYPE zif_ca_ops_link_types=>ty_flag1
        iv_rank TYPE i.
    METHODS object
      IMPORTING
        iv_id     TYPE zif_ca_ops_link_types=>ty_object_id
        iv_layer  TYPE zif_ca_ops_link_types=>ty_layer_id
        iv_source TYPE zif_ca_ops_link_types=>ty_source
        iv_keys   TYPE zif_ca_ops_link_types=>ty_key_list
        iv_fields TYPE string.
    METHODS link
      IMPORTING
        iv_id          TYPE zif_ca_ops_link_types=>ty_link_id
        iv_layer       TYPE zif_ca_ops_link_types=>ty_layer_id
        iv_from        TYPE zif_ca_ops_link_types=>ty_object_id
        iv_to          TYPE zif_ca_ops_link_types=>ty_object_id
        iv_quality     TYPE zif_ca_ops_link_types=>ty_flag1 DEFAULT 'C'
        iv_fallback_of TYPE zif_ca_ops_link_types=>ty_link_id OPTIONAL.
    METHODS cond
      IMPORTING
        iv_link  TYPE zif_ca_ops_link_types=>ty_link_id
        iv_no    TYPE i
        iv_kind  TYPE zif_ca_ops_link_types=>ty_cond_kind DEFAULT 'EQ'
        iv_from  TYPE zif_ca_ops_link_types=>ty_field_ref OPTIONAL
        iv_to    TYPE zif_ca_ops_link_types=>ty_field_ref
        iv_value TYPE zif_ca_ops_link_types=>ty_value OPTIONAL.
    METHODS pairs
      IMPORTING
        iv_text         TYPE string
      RETURNING
        VALUE(rt_pairs) TYPE zif_ca_ops_link_types=>tt_pair.
    METHODS walk
      IMPORTING
        iv_depth         TYPE i OPTIONAL
        it_links         TYPE zif_ca_ops_link_types=>tt_link_id OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_link_types=>ty_result
      RAISING
        zcx_ca_ops_error.
    METHODS nodes_of
      IMPORTING
        is_result       TYPE zif_ca_ops_link_types=>ty_result
        iv_object       TYPE zif_ca_ops_link_types=>ty_object_id
      RETURNING
        VALUE(rt_nodes) TYPE zif_ca_ops_link_types=>tt_node.

    METHODS every_level_reached        FOR TESTING.
    METHODS preferred_attempt_kept     FOR TESTING.
    METHODS fallback_for_unmatched     FOR TESTING.
    METHODS partner_key_masked         FOR TESTING.
    METHODS probable_quality_inherited FOR TESTING.
    METHODS path_names_the_links       FOR TESTING.
    METHODS one_read_per_link_level    FOR TESTING.
    METHODS depth_limit_reported       FOR TESTING.
    METHODS node_limit_stops_walk      FOR TESTING.
    METHODS row_cap_reported           FOR TESTING.
    METHODS failed_read_skips_link     FOR TESTING.
    METHODS link_filter_applied        FOR TESTING.
    METHODS unknown_start_refused      FOR TESTING.
    METHODS missing_key_refused        FOR TESTING.
    METHODS no_display_auth_refused    FOR TESTING.
ENDCLASS.


CLASS ltc_link_walker IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW ltd_link_dao( ).
    mo_auth = NEW ltd_auth( ).
    mo_params = NEW zcl_ca_ops_param_seed( ).
    zcl_ca_ops_injector=>inject_auth( mo_auth ).
    zcl_ca_ops_injector=>inject_params( mo_params->params( ) ).
    given_registry( ).
    given_rows( ).
    mo_cut = NEW zcl_ca_ops_link_walker( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
    CLEAR: mo_cut, mo_dao, mo_auth, mo_params.
  ENDMETHOD.


  " Document -> cleared items -> request (preferred attempt) -> partner (head, else fallback); document ->
  " reconciliation batch (probable link)
  METHOD given_registry.
    layer( iv_id = gc-std iv_kind = 'S' iv_rank = 10 ).
    layer( iv_id = gc-cust iv_kind = 'C' iv_rank = 30 ).
    object( iv_id = gc-doc iv_layer = gc-std iv_source = 'ZDOC' iv_keys = 'DOCNO' iv_fields = `DOCNO,FIKEY` ).
    object( iv_id = gc-item iv_layer = gc-std iv_source = 'ZITEM' iv_keys = 'DOCNO' iv_fields = `DOCNO,CLEARDOC` ).
    object( iv_id = gc-batch iv_layer = gc-std iv_source = 'ZBATCH' iv_keys = 'FIKEY' iv_fields = `FIKEY` ).
    object( iv_id = gc-partner iv_layer = gc-std iv_source = 'ZPARTNER' iv_keys = 'PARTNER'
            iv_fields = `PARTNER,EXTNO` ).
    object( iv_id = gc-request iv_layer = gc-cust iv_source = 'ZXX_REQ' iv_keys = 'REQ_ID,ATTEMPT'
            iv_fields = `REQ_ID,ATTEMPT,STATUS,MEMBER,FEEDER` ).
    INSERT VALUE #( object_id = gc-item field_name = 'ZZXX_REQ' layer_id = gc-cust source_name = 'ZITEM'
                    evidence = 'C' ) INTO TABLE mo_dao->ms_registry-fields.
    INSERT VALUE #( object_id = gc-partner field_name = 'ZZXX_FEEDER' layer_id = gc-cust source_name = 'ZPARTNER'
                    evidence = 'C' ) INTO TABLE mo_dao->ms_registry-fields.
    mo_dao->ms_registry-fields[ object_id = gc-partner field_name = 'PARTNER' ]-sensitivity = 'M'.
    mo_dao->ms_registry-fields[ object_id = gc-request field_name = 'MEMBER' ]-sensitivity = 'M'.

    link( iv_id = gc-doc_items iv_layer = gc-std iv_from = gc-doc iv_to = gc-item ).
    cond( iv_link = gc-doc_items iv_no = 1 iv_from = 'ZDOC-DOCNO' iv_to = 'ZITEM-CLEARDOC' ).
    link( iv_id = gc-doc_batch iv_layer = gc-std iv_from = gc-doc iv_to = gc-batch iv_quality = 'P' ).
    cond( iv_link = gc-doc_batch iv_no = 1 iv_from = 'ZDOC-FIKEY' iv_to = 'ZBATCH-FIKEY' ).
    link( iv_id = gc-item_req iv_layer = gc-cust iv_from = gc-item iv_to = gc-request ).
    cond( iv_link = gc-item_req iv_no = 1 iv_from = 'ZITEM-ZZXX_REQ' iv_to = 'ZXX_REQ-REQ_ID' ).
    cond( iv_link = gc-item_req iv_no = 2 iv_kind = 'PREFER' iv_to = 'ZXX_REQ-STATUS' iv_value = gc-success ).
    link( iv_id = gc-req_bp_fdr iv_layer = gc-cust iv_from = gc-request iv_to = gc-partner ).
    cond( iv_link = gc-req_bp_fdr iv_no = 1 iv_from = 'ZXX_REQ-MEMBER' iv_to = 'ZPARTNER-EXTNO' ).
    cond( iv_link = gc-req_bp_fdr iv_no = 2 iv_from = 'ZXX_REQ-FEEDER' iv_to = 'ZPARTNER-ZZXX_FEEDER' ).
    link( iv_id = gc-req_bp iv_layer = gc-cust iv_from = gc-request iv_to = gc-partner
          iv_fallback_of = gc-req_bp_fdr ).
    cond( iv_link = gc-req_bp iv_no = 1 iv_from = 'ZXX_REQ-MEMBER' iv_to = 'ZPARTNER-EXTNO' ).
  ENDMETHOD.


  METHOD given_rows.
    mo_dao->add_row( iv_source = 'ZDOC' it_pairs = pairs( `DOCNO=D1;FIKEY=K1` ) ).
    mo_dao->add_row( iv_source = 'ZITEM' it_pairs = pairs( `DOCNO=I1;CLEARDOC=D1;ZZXX_REQ=R1` ) ).
    mo_dao->add_row( iv_source = 'ZITEM' it_pairs = pairs( `DOCNO=I2;CLEARDOC=D1;ZZXX_REQ=R2` ) ).
    mo_dao->add_row( iv_source = 'ZITEM' it_pairs = pairs( `DOCNO=I9;CLEARDOC=D9;ZZXX_REQ=R9` ) ).
    mo_dao->add_row( iv_source = 'ZBATCH' it_pairs = pairs( `FIKEY=K1` ) ).
    " Request R1: a failed attempt after the success (never take the highest counter)
    mo_dao->add_row( iv_source = 'ZXX_REQ' it_pairs = pairs( `REQ_ID=R1;ATTEMPT=1;STATUS=FAIL;MEMBER=M1;FEEDER=WEB` ) ).
    mo_dao->add_row( iv_source = 'ZXX_REQ' it_pairs = pairs( `REQ_ID=R1;ATTEMPT=2;STATUS=SUCCESS;MEMBER=M1;FEEDER=WEB` ) ).
    mo_dao->add_row( iv_source = 'ZXX_REQ' it_pairs = pairs( `REQ_ID=R1;ATTEMPT=3;STATUS=FAIL;MEMBER=M1;FEEDER=WEB` ) ).
    mo_dao->add_row( iv_source = 'ZXX_REQ' it_pairs = pairs( `REQ_ID=R2;ATTEMPT=1;STATUS=SUCCESS;MEMBER=M2;FEEDER=APP` ) ).
    " Partner of M1 carries the feeder; the old partner of M2 has none (found by the fallback only)
    mo_dao->add_row( iv_source = 'ZPARTNER' it_pairs = pairs( `PARTNER=P0000001234;EXTNO=M1;ZZXX_FEEDER=WEB` ) ).
    mo_dao->add_row( iv_source = 'ZPARTNER' it_pairs = pairs( `PARTNER=P0000005678;EXTNO=M2` ) ).
  ENDMETHOD.


  METHOD layer.
    DATA ls_layer TYPE zif_ca_ops_link_types=>ty_layer.
    ls_layer-layer_id   = iv_id.
    ls_layer-layer_kind = iv_kind.
    ls_layer-layer_rank = iv_rank.
    ls_layer-id_prefix  = |{ iv_id }_|.
    ls_layer-active     = abap_true.
    INSERT ls_layer INTO TABLE mo_dao->ms_registry-layers.
  ENDMETHOD.


  METHOD object.
    DATA ls_object TYPE zif_ca_ops_link_types=>ty_object.
    DATA ls_field TYPE zif_ca_ops_link_types=>ty_field.
    ls_object-object_id   = iv_id.
    ls_object-layer_id    = iv_layer.
    ls_object-source_name = iv_source.
    ls_object-source_kind = zif_ca_ops_link_types=>gc_source_kind-table.
    ls_object-key_fields  = iv_keys.
    ls_object-active      = abap_true.
    INSERT ls_object INTO TABLE mo_dao->ms_registry-objects.
    LOOP AT zcl_ca_ops_util=>split_list( iv_fields ) ASSIGNING FIELD-SYMBOL(<lv_field>).
      CLEAR ls_field.
      ls_field-object_id   = iv_id.
      ls_field-field_name  = <lv_field>.
      ls_field-layer_id    = iv_layer.
      ls_field-source_name = iv_source.
      ls_field-evidence    = zif_ca_ops_link_types=>gc_evidence-confirmed.
      INSERT ls_field INTO TABLE mo_dao->ms_registry-fields.
    ENDLOOP.
  ENDMETHOD.


  METHOD link.
    DATA ls_link TYPE zif_ca_ops_link_types=>ty_link.
    ls_link-link_id     = iv_id.
    ls_link-layer_id    = iv_layer.
    ls_link-from_object = iv_from.
    ls_link-to_object   = iv_to.
    ls_link-cardinality = zif_ca_ops_link_types=>gc_cardinality-many_many.
    ls_link-quality     = iv_quality.
    ls_link-fallback_of = iv_fallback_of.
    ls_link-active      = abap_true.
    INSERT ls_link INTO TABLE mo_dao->ms_registry-links.
  ENDMETHOD.


  METHOD cond.
    DATA ls_cond TYPE zif_ca_ops_link_types=>ty_cond.
    ls_cond-link_id    = iv_link.
    ls_cond-cond_no    = iv_no.
    ls_cond-cond_kind  = iv_kind.
    ls_cond-from_ref   = iv_from.
    ls_cond-to_ref     = iv_to.
    ls_cond-cond_value = iv_value.
    INSERT ls_cond INTO TABLE mo_dao->ms_registry-conds.
  ENDMETHOD.


  METHOD pairs.
    SPLIT iv_text AT `;` INTO TABLE DATA(lt_parts).
    LOOP AT lt_parts ASSIGNING FIELD-SYMBOL(<lv_part>).
      SPLIT <lv_part> AT `=` INTO DATA(lv_field) DATA(lv_value).
      INSERT VALUE #( fieldname = lv_field value = lv_value ) INTO TABLE rt_pairs.
    ENDLOOP.
  ENDMETHOD.


  METHOD walk.
    rs_result = mo_cut->walk( VALUE #( area      = gc-area
                                       object_id = gc-doc
                                       keys      = pairs( |DOCNO={ gc-doc_no }| )
                                       max_depth = iv_depth
                                       links     = it_links ) ).
  ENDMETHOD.


  METHOD nodes_of.
    LOOP AT is_result-nodes ASSIGNING FIELD-SYMBOL(<ls_node>) WHERE object_id = iv_object.
      INSERT <ls_node> INTO TABLE rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD every_level_reached.
    TRY.
        DATA(ls_result) = walk( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-nodes ) exp = 8
                                            msg = 'Start, two items, batch, two requests, two partners' ).
        cl_abap_unit_assert=>assert_equals( act = lines( nodes_of( is_result = ls_result iv_object = gc-item ) )
                                            exp = 2 msg = 'Only the items the document cleared' ).
        DATA(lt_partners) = nodes_of( is_result = ls_result iv_object = gc-partner ).
        cl_abap_unit_assert=>assert_equals( act = lt_partners[ 1 ]-depth exp = 3 msg = 'Partners on the third level' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-truncated msg = 'No limit reached' ).
        cl_abap_unit_assert=>assert_equals( act = mo_auth->mv_activity exp = zif_ca_ops_auth=>gc_activity-display
                                            msg = 'Display authorisation of the area checked' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the accepted attempt is the SUCCESS row, never the highest counter
  METHOD preferred_attempt_kept.
    TRY.
        DATA(lt_requests) = nodes_of( is_result = walk( ) iv_object = gc-request ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_requests ) exp = 2 msg = 'One node per request' ).
        LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls_request>).
          IF zcl_ca_ops_link_query=>value_of( it_pairs = <ls_request>-keys iv_field = 'REQ_ID' ) = 'R1'.
            cl_abap_unit_assert=>assert_equals(
              act = zcl_ca_ops_link_query=>value_of( it_pairs = <ls_request>-keys iv_field = 'ATTEMPT' )
              exp = '2' msg = 'Attempt 2 of R1, not the later failed attempt 3' ).
          ENDIF.
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the fallback runs only for the source rows its head found nothing for
  METHOD fallback_for_unmatched.
    TRY.
        DATA(lt_partners) = nodes_of( is_result = walk( ) iv_object = gc-partner ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_partners ) exp = 2 msg = 'Two partners' ).
        cl_abap_unit_assert=>assert_equals( act = lt_partners[ link_id = gc-req_bp_fdr ]-step exp = 1
                                            msg = 'M1 found with the feeder' ).
        cl_abap_unit_assert=>assert_equals( act = lt_partners[ link_id = gc-req_bp ]-step exp = 2
                                            msg = 'M2 found by the fallback (step 2)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD partner_key_masked.
    TRY.
        DATA(lt_partners) = nodes_of( is_result = walk( ) iv_object = gc-partner ).
        cl_abap_unit_assert=>assert_equals( act = lt_partners[ link_id = gc-req_bp_fdr ]-keys[ 1 ]-value
                                            exp = gc-masked_one msg = 'Partner number masked to the last four' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD probable_quality_inherited.
    TRY.
        DATA(ls_result) = walk( ).
        DATA(lt_batches) = nodes_of( is_result = ls_result iv_object = gc-batch ).
        DATA(lt_items) = nodes_of( is_result = ls_result iv_object = gc-item ).
        cl_abap_unit_assert=>assert_equals( act = lt_batches[ 1 ]-quality
                                            exp = zif_ca_ops_link_types=>gc_quality-probable
                                            msg = 'Reached over a probable link' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-quality
                                            exp = zif_ca_ops_link_types=>gc_quality-confirmed
                                            msg = 'Confirmed links only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD path_names_the_links.
    TRY.
        DATA(lt_partners) = nodes_of( is_result = walk( ) iv_object = gc-partner ).
        cl_abap_unit_assert=>assert_equals(
          act = lt_partners[ link_id = gc-req_bp_fdr ]-path
          exp = |ZS_DOC -ZS_DOC_TO_ITEMS-> ZS_ITEM -XX_ITEM_TO_REQ-> XX_REQUEST -XX_REQ_TO_PARTNER_FDR-> ZS_PARTNER|
          msg = 'Objects and links from the start' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: set-based - one read per link and level for all source rows (never one per row)
  METHOD one_read_per_link_level.
    TRY.
        walk( ).
        DATA(lv_requests) = REDUCE i( INIT n = 0 FOR lv_read IN mo_dao->mt_reads WHERE ( table_line = 'ZXX_REQ' )
                                      NEXT n = n + 1 ).
        cl_abap_unit_assert=>assert_equals( act = lv_requests exp = 1 msg = 'One read of the requests of both items' ).
        DATA(lv_partners) = REDUCE i( INIT n = 0 FOR lv_read IN mo_dao->mt_reads WHERE ( table_line = 'ZPARTNER' )
                                      NEXT n = n + 1 ).
        cl_abap_unit_assert=>assert_equals( act = lv_partners exp = 2 msg = 'Head and fallback: one read each' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD depth_limit_reported.
    TRY.
        DATA(ls_result) = walk( iv_depth = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-nodes ) exp = 4 msg = 'Start and its first level' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-truncated msg = 'Cut by the depth' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_result-problems[ msgno = '219' ] ) )
                                          msg = 'Message 219' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD node_limit_stops_walk.
    TRY.
        mo_params->set( iv_name = zif_ca_ops_link_types=>gc_param-max_nodes iv_value = `3` ).
        DATA(ls_result) = walk( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-nodes ) exp = 3 msg = 'At most three nodes' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_result-problems[ msgno = '220' ] ) )
                                          msg = 'Message 220' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD row_cap_reported.
    TRY.
        mo_params->set( iv_name = zif_ca_ops_link_types=>gc_param-max_rows iv_value = `1` ).
        DATA(ls_result) = walk( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-truncated msg = 'A read was capped' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-problems[ msgno = '221' subject = gc-doc_items ] ) )
          msg = 'Message 221 names the link' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD failed_read_skips_link.
    TRY.
        INSERT CONV zif_ca_ops_link_types=>ty_source( 'ZBATCH' ) INTO TABLE mo_dao->mt_failing.
        DATA(ls_result) = walk( ).
        cl_abap_unit_assert=>assert_initial( act = nodes_of( is_result = ls_result iv_object = gc-batch )
                                             msg = 'No batch' ).
        cl_abap_unit_assert=>assert_equals( act = lines( nodes_of( is_result = ls_result iv_object = gc-item ) )
                                            exp = 2 msg = 'The other links still followed' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-problems[ msgno = '222' subject = gc-doc_batch ] ) )
          msg = 'Message 222 names the link' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD link_filter_applied.
    TRY.
        DATA(ls_result) = walk( it_links = VALUE #( ( gc-doc_batch ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-nodes ) exp = 2 msg = 'Start and its batch' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_start_refused.
    TRY.
        mo_cut->walk( VALUE #( area = gc-area object_id = 'ZS_NONE' keys = pairs( `DOCNO=D1` ) ) ).
        cl_abap_unit_assert=>fail( msg = 'An object the registry does not know cannot start a walk' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '210'
                                            msg = 'Message 210' ).
    ENDTRY.
  ENDMETHOD.


  METHOD missing_key_refused.
    TRY.
        mo_cut->walk( VALUE #( area = gc-area object_id = gc-doc keys = pairs( `FIKEY=K1` ) ) ).
        cl_abap_unit_assert=>fail( msg = 'The start needs its key' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '211'
                                            msg = 'Message 211' ).
    ENDTRY.
  ENDMETHOD.


  METHOD no_display_auth_refused.
    TRY.
        mo_auth->mv_allowed = abap_false.
        walk( ).
        cl_abap_unit_assert=>fail( msg = 'No walk without display authorisation of the area' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '041'
                                            msg = 'Message 041' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_reads msg = 'Nothing read' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
