*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_link_walker.clas.abap
*& Purpose:
*& Drill-down over the link registry (ZIF_CA_OPS_LINK_WALKER): from a start
*& object and its key, breadth first, level by level: for every object of
*& the level and every effective chain leaving it, one read per link for
*& all source rows of that object (in chunks of LINK_READ_CHUNK), the rows
*& attributed to their source rows, the preferred rows kept (PREFER), the
*& next link of the chain tried only for the source rows the previous one
*& found nothing for. Every row reached once (object + key); limits
*& LINK_MAX_DEPTH, LINK_MAX_ROWS (per read), LINK_MAX_NODES. Display
*& authorisation ZCA_OPS 03 of the area first; reads through
*& ZIF_CA_OPS_LINK_DAO (approved tables, DDIC-checked names, quoted values).
*& Keys of the result masked by the sensitivity of their fields; the raw
*& values stay inside the walk. Read only, nothing stored.
*& Since 2026-11-16 (build Q): a "to one" link that finds several rows for
*& one source row returns every candidate marked AMBIGUOUS (never one
*& picked) with its evidence - identity values (masked), layer and quality
*& of the link - in RS_RESULT-AMBIGUITIES; a link whose table, view or
*& field is not in this system's dictionary is not followed (634 / 635,
*& result not evaluated beyond it - never a dump); the customer layers of
*& parameter GATE_LINK_LAYERS_OFF are switched off (rollback).
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*& 2026-11-16 | Ambiguous matches with candidates and evidence, identity fields read with the keys, missing
*&            | DDIC objects not followed, GATE_LINK_LAYERS_OFF (build Q).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - link registry walker</p>
"! A row reached from several source rows of one level keeps the first parent (the result is a tree).
"! A link that cannot be read (not approved, unknown field, read error) is skipped with a problem; the
"! walk goes on with the other links.
CLASS zcl_ca_ops_link_walker DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_link_walker.

    "! @parameter io_dao | Data access (default ZCL_CA_OPS_LINK_DAO; a double in tests)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_link_dao OPTIONAL.

  PRIVATE SECTION.
    "! A node of the walk with the raw values of its row (never returned)
    TYPES:
      BEGIN OF ty_work,
        node_id   TYPE i,
        object_id TYPE zif_ca_ops_link_types=>ty_object_id,
        quality   TYPE zif_ca_ops_link_types=>ty_flag1,
        path      TYPE string,
        pairs     TYPE zif_ca_ops_link_types=>tt_pair,
      END OF ty_work.
    TYPES tt_work TYPE STANDARD TABLE OF ty_work WITH EMPTY KEY.
    TYPES tt_visited TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    "! Runtime DDIC of a source, read once per walk (empty = the source is not in the dictionary)
    TYPES:
      BEGIN OF ty_ddic,
        source TYPE zif_ca_ops_link_types=>ty_source,
        fields TYPE zif_ca_ops_chk_types=>tt_field,
      END OF ty_ddic.
    TYPES tt_ddic TYPE HASHED TABLE OF ty_ddic WITH UNIQUE KEY source.

    DATA mo_dao TYPE REF TO zif_ca_ops_link_dao.
    DATA ms_effective TYPE zif_ca_ops_link_types=>ty_effective.
    DATA mv_loaded TYPE abap_bool.
    "! State of one walk
    DATA ms_request TYPE zif_ca_ops_link_types=>ty_request.
    DATA ms_result TYPE zif_ca_ops_link_types=>ty_result.
    DATA mt_work TYPE tt_work.
    DATA mt_visited TYPE tt_visited.
    DATA mt_chains TYPE zif_ca_ops_link_types=>tt_chain.
    DATA mv_max_rows TYPE i.
    DATA mv_max_nodes TYPE i.
    DATA mv_chunk TYPE i.
    DATA mv_stop TYPE abap_bool.
    DATA mt_ddic TYPE tt_ddic.

    METHODS begin
      IMPORTING
        is_request     TYPE zif_ca_ops_link_types=>ty_request
      RETURNING
        VALUE(rv_depth) TYPE i.

    "! The start node (keys checked, the fields its links read added by one read of its own row)
    METHODS start
      RAISING
        zcx_ca_ops_error.

    "! One level: every chain leaving an object of the frontier; returns the nodes of the next level
    METHODS walk_level
      IMPORTING
        it_frontier    TYPE tt_work
        iv_depth       TYPE i
      RETURNING
        VALUE(rt_next) TYPE tt_work.

    "! The links of one chain in order for the source rows the previous link found nothing for
    METHODS follow_chain
      IMPORTING
        is_chain   TYPE zif_ca_ops_link_types=>ty_chain
        it_sources TYPE tt_work
        iv_depth   TYPE i
      CHANGING
        ct_next    TYPE tt_work.

    "! Rows of the link's target for the source rows (chunked reads); a failed read is a problem
    METHODS read
      IMPORTING
        is_link        TYPE zif_ca_ops_link_types=>ty_link
        is_target      TYPE zif_ca_ops_link_types=>ty_object
        it_conds       TYPE zif_ca_ops_link_types=>tt_cond
        it_sources     TYPE tt_work
      EXPORTING
        et_rows        TYPE zif_ca_ops_link_types=>tt_row
        ev_failed      TYPE abap_bool.

    "! A new node for a row of the target unless the row was reached before; returns its node ID (0 = none)
    METHODS add_node
      IMPORTING
        is_parent         TYPE ty_work
        is_link           TYPE zif_ca_ops_link_types=>ty_link
        iv_step           TYPE i
        is_target         TYPE zif_ca_ops_link_types=>ty_object
        is_row            TYPE zif_ca_ops_link_types=>ty_row
        iv_depth          TYPE i
        iv_match          TYPE zif_ca_ops_link_types=>ty_match
        iv_candidates     TYPE i
      CHANGING
        ct_next           TYPE tt_work
      RETURNING
        VALUE(rv_node_id) TYPE i.

    "! The rows of a source row: one node each; several rows of a "to one" link are an ambiguity (every candidate
    "! is kept with its evidence, never one picked)
    METHODS add_rows
      IMPORTING
        is_parent TYPE ty_work
        is_link   TYPE zif_ca_ops_link_types=>ty_link
        iv_step   TYPE i
        is_target TYPE zif_ca_ops_link_types=>ty_object
        it_rows   TYPE zif_ca_ops_link_types=>tt_row
        iv_depth  TYPE i
      CHANGING
        ct_next   TYPE tt_work.

    "! The target's table / view and every field the link reads exist in this system's dictionary; else the link
    "! is not followed (634 / 635) and the walk is marked not evaluated beyond it
    METHODS ddic_ready
      IMPORTING
        is_link         TYPE zif_ca_ops_link_types=>ty_link
        is_target       TYPE zif_ca_ops_link_types=>ty_object
        it_conds        TYPE zif_ca_ops_link_types=>tt_cond
      RETURNING
        VALUE(rv_ready) TYPE abap_bool.

    "! Values of the identity fields of a row, sensitive values masked (evidence of a candidate)
    METHODS masked_identity
      IMPORTING
        is_object      TYPE zif_ca_ops_link_types=>ty_object
        it_pairs       TYPE zif_ca_ops_link_types=>tt_pair
      RETURNING
        VALUE(rt_keys) TYPE zif_ca_ops_link_types=>tt_pair.

    "! Fields of an object the walk needs: its keys, its identity and the from fields of the links leaving it
    METHODS needed_fields
      IMPORTING
        is_object        TYPE zif_ca_ops_link_types=>ty_object
      RETURNING
        VALUE(rt_fields) TYPE zif_ca_ops_link_types=>tt_fieldname.

    "! Key of a row in the result: the object's key fields, sensitive values masked
    METHODS masked_keys
      IMPORTING
        is_object      TYPE zif_ca_ops_link_types=>ty_object
        it_pairs       TYPE zif_ca_ops_link_types=>tt_pair
      RETURNING
        VALUE(rt_keys) TYPE zif_ca_ops_link_types=>tt_pair.

    "! Identity of a row for the visited set: object and raw key values
    METHODS identity
      IMPORTING
        is_object          TYPE zif_ca_ops_link_types=>ty_object
        it_pairs           TYPE zif_ca_ops_link_types=>tt_pair
      RETURNING
        VALUE(rv_identity) TYPE string.

    METHODS problem
      IMPORTING
        iv_subject TYPE clike
        iv_msgno   TYPE zif_ca_ops_types=>ty_msgno
        iv_v1      TYPE simple OPTIONAL
        iv_v2      TYPE simple OPTIONAL.

    "! A chain of the walk leaves the object
    METHODS leaves
      IMPORTING
        iv_object_id   TYPE zif_ca_ops_link_types=>ty_object_id
      RETURNING
        VALUE(rv_leaves) TYPE abap_bool.

    METHODS object
      IMPORTING
        iv_object_id     TYPE zif_ca_ops_link_types=>ty_object_id
      RETURNING
        VALUE(rs_object) TYPE zif_ca_ops_link_types=>ty_object.

ENDCLASS.



CLASS zcl_ca_ops_link_walker IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_link_dao( ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_link_walker~registry.
    DATA lt_off TYPE string_table.

    IF mv_loaded = abap_false.
      " customer layers switched off at run time (GATE_LINK_LAYERS_OFF: rollback of an overlay, no transport)
      LOOP AT zcl_ca_ops_factory=>get_params( )->get_range( iv_name = zif_ca_ops_link_types=>gc_param-layers_off
                                                             iv_area = zif_ca_ops_types=>gc_param_area )
           ASSIGNING FIELD-SYMBOL(<ls_off>).
        INSERT CONV string( <ls_off>-low ) INTO TABLE lt_off.
      ENDLOOP.
      ms_effective = zcl_ca_ops_link_registry=>effective(
                       zcl_ca_ops_link_registry=>switch_off_layers( is_registry = mo_dao->read_registry( )
                                                                    it_layers   = lt_off ) ).
      mv_loaded = abap_true.
    ENDIF.
    rs_effective = ms_effective.
  ENDMETHOD.


  METHOD zif_ca_ops_link_walker~walk.
    zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-display
                                            iv_area     = is_request-area ).
    DATA(lv_depth) = begin( is_request ).
    start( ).

    DATA(lt_frontier) = mt_work.
    DO lv_depth TIMES.
      DATA(lt_next) = walk_level( it_frontier = lt_frontier iv_depth = sy-index ).
      lt_frontier = lt_next.
      IF mv_stop = abap_true OR lt_frontier IS INITIAL.
        EXIT.
      ENDIF.
    ENDDO.

    " The last level still had links to follow: the depth limit cut the walk
    IF mv_stop = abap_false.
      LOOP AT lt_frontier ASSIGNING FIELD-SYMBOL(<ls_open>).
        IF leaves( <ls_open>-object_id ) = abap_true.
          ms_result-truncated = abap_true.
          problem( iv_subject = ms_request-object_id iv_msgno = zif_ca_ops_link_types=>gc_msg-walk_depth
                   iv_v1 = ms_request-object_id iv_v2 = lv_depth ).
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.
    rs_result = ms_result.
  ENDMETHOD.


  METHOD begin.
    zif_ca_ops_link_walker~registry( ).
    CLEAR: ms_result, mt_work, mt_visited, mt_chains, mv_stop, mt_ddic.
    ms_request = is_request.
    " Field names as the DDIC holds them (the caller may write them in lower case)
    LOOP AT ms_request-keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      <ls_key>-fieldname = to_upper( condense( <ls_key>-fieldname ) ).
    ENDLOOP.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(lv_max_depth) = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                     iv_name    = zif_ca_ops_link_types=>gc_param-max_depth
                                                     iv_default = zif_ca_ops_link_types=>gc_default-max_depth ).
    mv_max_rows = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                              iv_name    = zif_ca_ops_link_types=>gc_param-max_rows
                                              iv_default = zif_ca_ops_link_types=>gc_default-max_rows ).
    mv_max_nodes = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                               iv_name    = zif_ca_ops_link_types=>gc_param-max_nodes
                                               iv_default = zif_ca_ops_link_types=>gc_default-max_nodes ).
    mv_chunk = nmax( val1 = 1
                     val2 = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                        iv_name    = zif_ca_ops_link_types=>gc_param-read_chunk
                                                        iv_default = zif_ca_ops_link_types=>gc_default-read_chunk ) ).
    " The request may walk less deep than the parameter allows, never deeper
    rv_depth = COND #( WHEN is_request-max_depth > 0 AND is_request-max_depth < lv_max_depth THEN is_request-max_depth
                       ELSE lv_max_depth ).

    LOOP AT ms_effective-chains ASSIGNING FIELD-SYMBOL(<ls_chain>).
      IF is_request-links IS INITIAL OR line_exists( is_request-links[ table_line = <ls_chain>-head ] ).
        INSERT <ls_chain> INTO TABLE mt_chains.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD start.
    DATA lt_pairs TYPE zif_ca_ops_link_types=>tt_pair.
    DATA lt_conds TYPE zif_ca_ops_link_types=>tt_cond.

    DATA(ls_start) = object( ms_request-object_id ).
    IF ls_start IS INITIAL OR ls_start-active = abap_false
        OR zcl_ca_ops_link_registry=>layer_on( is_registry = ms_effective-registry
                                               iv_layer_id = ls_start-layer_id ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e210(zca_ops) WITH ms_request-object_id.
    ENDIF.
    LOOP AT zcl_ca_ops_link_registry=>key_fields( ls_start ) ASSIGNING FIELD-SYMBOL(<lv_key>).
      DATA(lv_value) = zcl_ca_ops_link_query=>value_of( it_pairs = ms_request-keys iv_field = <lv_key> ).
      IF lv_value IS INITIAL.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e211(zca_ops) WITH ms_request-object_id <lv_key>.
      ENDIF.
      INSERT VALUE #( fieldname = <lv_key> value = lv_value ) INTO TABLE lt_pairs.
      " One read of the start row by its key: EQ key = key
      INSERT VALUE #( link_id   = ms_request-object_id
                      cond_no   = lines( lt_conds ) + 1
                      cond_kind = zif_ca_ops_link_types=>gc_cond_kind-eq
                      from_ref  = |{ ls_start-source_name }{ zif_ca_ops_link_types=>gc_ref_separator }{ <lv_key> }|
                      to_ref    = |{ ls_start-source_name }{ zif_ca_ops_link_types=>gc_ref_separator }{ <lv_key> }| )
             INTO TABLE lt_conds.
    ENDLOOP.

    DATA(ls_root) = VALUE ty_work( node_id   = 1
                                   object_id = ls_start-object_id
                                   quality   = zif_ca_ops_link_types=>gc_quality-confirmed
                                   path      = condense( CONV string( ls_start-object_id ) )
                                   pairs     = lt_pairs ).
    " The links leaving the start read fields beyond its key: one read of the start row by its key
    DATA(lt_needed) = needed_fields( ls_start ).
    DATA(lv_missing) = abap_false.
    LOOP AT lt_needed ASSIGNING FIELD-SYMBOL(<lv_needed>).
      IF NOT line_exists( lt_pairs[ fieldname = <lv_needed> ] ).
        lv_missing = abap_true.
      ENDIF.
    ENDLOOP.
    IF lv_missing = abap_true.
      TRY.
          DATA(lt_rows) = mo_dao->read_linked( iv_area     = ms_request-area
                                               is_target   = ls_start
                                               it_conds    = lt_conds
                                               it_sources  = VALUE #( ( pairs = lt_pairs ) )
                                               it_select   = lt_needed
                                               iv_max_rows = 1 ).
          IF lt_rows IS NOT INITIAL.
            ls_root-pairs = lt_rows[ 1 ]-pairs.
          ENDIF.
        CATCH zcx_ca_ops_error.
          problem( iv_subject = ls_start-object_id iv_msgno = zif_ca_ops_link_types=>gc_msg-read_failed
                   iv_v1 = ls_start-object_id iv_v2 = ls_start-source_name ).
      ENDTRY.
    ENDIF.

    INSERT ls_root INTO TABLE mt_work.
    INSERT identity( is_object = ls_start it_pairs = lt_pairs ) INTO TABLE mt_visited.
    INSERT VALUE #( node_id   = 1
                    object_id = ls_start-object_id
                    keys      = masked_keys( is_object = ls_start it_pairs = lt_pairs )
                    quality   = ls_root-quality
                    path      = ls_root-path ) INTO TABLE ms_result-nodes.
  ENDMETHOD.


  METHOD walk_level.
    DATA lt_objects TYPE SORTED TABLE OF zif_ca_ops_link_types=>ty_object_id WITH UNIQUE KEY table_line.
    DATA lt_sources TYPE tt_work.

    LOOP AT it_frontier ASSIGNING FIELD-SYMBOL(<ls_node>).
      INSERT <ls_node>-object_id INTO TABLE lt_objects.
    ENDLOOP.
    LOOP AT lt_objects ASSIGNING FIELD-SYMBOL(<lv_object>).
      CLEAR lt_sources.
      LOOP AT it_frontier ASSIGNING <ls_node> WHERE object_id = <lv_object>.
        INSERT <ls_node> INTO TABLE lt_sources.
      ENDLOOP.
      LOOP AT mt_chains ASSIGNING FIELD-SYMBOL(<ls_chain>).
        READ TABLE ms_effective-registry-links ASSIGNING FIELD-SYMBOL(<ls_head>)
             WITH TABLE KEY link_id = <ls_chain>-head.
        IF sy-subrc <> 0 OR <ls_head>-from_object <> <lv_object>.
          CONTINUE.
        ENDIF.
        follow_chain( EXPORTING is_chain   = <ls_chain>
                                it_sources = lt_sources
                                iv_depth   = iv_depth
                      CHANGING  ct_next    = rt_next ).
        IF mv_stop = abap_true.
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD follow_chain.
    DATA lt_still TYPE tt_work.
    DATA lt_matched TYPE zif_ca_ops_link_types=>tt_row.
    DATA lv_step TYPE i.

    DATA(lt_pending) = it_sources.
    LOOP AT is_chain-links ASSIGNING FIELD-SYMBOL(<lv_link_id>).
      IF lt_pending IS INITIAL.
        RETURN.
      ENDIF.
      lv_step = lv_step + 1.
      DATA(ls_link) = ms_effective-registry-links[ link_id = <lv_link_id> ].
      DATA(ls_target) = object( ls_link-to_object ).
      DATA(lt_conds) = zcl_ca_ops_link_registry=>conds_of( is_registry = ms_effective-registry
                                                          iv_link_id  = ls_link-link_id ).
      IF ddic_ready( is_link = ls_link is_target = ls_target it_conds = lt_conds ) = abap_false.
        RETURN.
      ENDIF.
      read( EXPORTING is_link    = ls_link
                      is_target  = ls_target
                      it_conds   = lt_conds
                      it_sources = lt_pending
            IMPORTING et_rows    = DATA(lt_rows)
                      ev_failed  = DATA(lv_failed) ).
      IF lv_failed = abap_true.
        RETURN.
      ENDIF.

      CLEAR lt_still.
      LOOP AT lt_pending ASSIGNING FIELD-SYMBOL(<ls_source>).
        CLEAR lt_matched.
        LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
          TRY.
              IF zcl_ca_ops_link_query=>belongs_to( is_row    = <ls_row>
                                                    is_source = VALUE #( pairs = <ls_source>-pairs )
                                                    it_conds  = lt_conds ) = abap_true.
                INSERT <ls_row> INTO TABLE lt_matched.
              ENDIF.
            CATCH zcx_ca_ops_error.
              " The transform was checked by the registry; a value it refuses joins nothing
              CONTINUE.
          ENDTRY.
        ENDLOOP.
        IF lt_matched IS INITIAL.
          INSERT <ls_source> INTO TABLE lt_still.
          CONTINUE.
        ENDIF.
        add_rows( EXPORTING is_parent = <ls_source>
                            is_link   = ls_link
                            iv_step   = lv_step
                            is_target = ls_target
                            it_rows   = zcl_ca_ops_link_query=>prefer( it_rows = lt_matched it_conds = lt_conds )
                            iv_depth  = iv_depth
                  CHANGING  ct_next   = ct_next ).
        IF mv_stop = abap_true.
          RETURN.
        ENDIF.
      ENDLOOP.
      lt_pending = lt_still.
    ENDLOOP.
  ENDMETHOD.


  METHOD read.
    DATA lt_chunk TYPE zif_ca_ops_link_types=>tt_row.
    DATA lv_count TYPE i.

    CLEAR: et_rows, ev_failed.
    DATA(lt_select) = needed_fields( is_target ).
    LOOP AT it_sources ASSIGNING FIELD-SYMBOL(<ls_source>).
      lv_count = lv_count + 1.
      INSERT VALUE #( pairs = <ls_source>-pairs ) INTO TABLE lt_chunk.
      IF lines( lt_chunk ) < mv_chunk AND lv_count < lines( it_sources ).
        CONTINUE.
      ENDIF.
      TRY.
          DATA(lt_rows) = mo_dao->read_linked( iv_area     = ms_request-area
                                               is_target   = is_target
                                               it_conds    = it_conds
                                               it_sources  = lt_chunk
                                               it_select   = lt_select
                                               iv_max_rows = mv_max_rows ).
        CATCH zcx_ca_ops_error.
          problem( iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-read_failed
                   iv_v1 = is_link-link_id iv_v2 = is_target-source_name ).
          ev_failed = abap_true.
          RETURN.
      ENDTRY.
      IF lines( lt_rows ) >= mv_max_rows.
        ms_result-truncated = abap_true.
        problem( iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-walk_rows
                 iv_v1 = is_link-link_id iv_v2 = mv_max_rows ).
      ENDIF.
      INSERT LINES OF lt_rows INTO TABLE et_rows.
      CLEAR lt_chunk.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_rows.
    DATA(lv_count) = lines( it_rows ).
    DATA(lv_to_one) = zcl_ca_ops_link_registry=>is_to_one( is_link ).
    DATA(lv_match) = COND zif_ca_ops_link_types=>ty_match(
      WHEN lv_to_one = abap_false THEN zif_ca_ops_link_types=>gc_match-many
      WHEN lv_count > 1           THEN zif_ca_ops_link_types=>gc_match-ambiguous
      ELSE zif_ca_ops_link_types=>gc_match-one ).
    DATA(ls_ambiguity) = VALUE zif_ca_ops_link_types=>ty_ambiguity(
      parent_id    = is_parent-node_id
      link_id      = is_link-link_id
      layer_id     = is_link-layer_id
      link_quality = is_link-quality
      object_id    = is_target-object_id
      uncovered    = zcl_ca_ops_link_registry=>uncovered( is_registry = ms_effective-registry is_link = is_link ) ).

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_node_id) = add_node( EXPORTING is_parent     = is_parent
                                             is_link       = is_link
                                             iv_step       = iv_step
                                             is_target     = is_target
                                             is_row        = <ls_row>
                                             iv_depth      = iv_depth
                                             iv_match      = lv_match
                                             iv_candidates = lv_count
                                   CHANGING  ct_next       = ct_next ).
      IF lv_match = zif_ca_ops_link_types=>gc_match-ambiguous.
        " every candidate with its evidence - also one reached before on another path (node 0)
        INSERT VALUE #( node_id  = lv_node_id
                        keys     = masked_keys( is_object = is_target it_pairs = <ls_row>-pairs )
                        identity = masked_identity( is_object = is_target it_pairs = <ls_row>-pairs ) )
               INTO TABLE ls_ambiguity-candidates.
      ENDIF.
      IF mv_stop = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_match = zif_ca_ops_link_types=>gc_match-ambiguous.
      INSERT ls_ambiguity INTO TABLE ms_result-ambiguities.
      problem( iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-ambiguous_match
               iv_v1 = is_link-link_id iv_v2 = lv_count ).
    ENDIF.
  ENDMETHOD.


  METHOD add_node.
    DATA(lv_identity) = identity( is_object = is_target it_pairs = is_row-pairs ).
    IF line_exists( mt_visited[ table_line = lv_identity ] ).
      RETURN.
    ENDIF.
    IF lines( ms_result-nodes ) >= mv_max_nodes.
      ms_result-truncated = abap_true.
      mv_stop = abap_true.
      problem( iv_subject = ms_request-object_id iv_msgno = zif_ca_ops_link_types=>gc_msg-walk_nodes
               iv_v1 = ms_request-object_id iv_v2 = mv_max_nodes ).
      RETURN.
    ENDIF.
    INSERT lv_identity INTO TABLE mt_visited.
    DATA(ls_work) = VALUE ty_work(
      node_id   = lines( ms_result-nodes ) + 1
      object_id = is_target-object_id
      quality   = COND #( WHEN is_parent-quality = zif_ca_ops_link_types=>gc_quality-probable
                            OR is_link-quality = zif_ca_ops_link_types=>gc_quality-probable
                          THEN zif_ca_ops_link_types=>gc_quality-probable
                          ELSE zif_ca_ops_link_types=>gc_quality-confirmed )
      path      = |{ is_parent-path } -{ condense( CONV string( is_link-link_id ) ) }-> {
                     condense( CONV string( is_target-object_id ) ) }|
      pairs     = is_row-pairs ).
    INSERT ls_work INTO TABLE ct_next.
    INSERT VALUE #( node_id      = ls_work-node_id
                    parent_id    = is_parent-node_id
                    depth        = iv_depth
                    object_id    = is_target-object_id
                    keys         = masked_keys( is_object = is_target it_pairs = is_row-pairs )
                    link_id      = is_link-link_id
                    step         = iv_step
                    quality      = ls_work-quality
                    path         = ls_work-path
                    match        = iv_match
                    candidates   = iv_candidates
                    identity     = masked_identity( is_object = is_target it_pairs = is_row-pairs )
                    layer_id     = is_link-layer_id
                    link_quality = is_link-quality ) INTO TABLE ms_result-nodes.
    rv_node_id = ls_work-node_id.
  ENDMETHOD.


  METHOD ddic_ready.
    DATA(lv_source) = CONV zif_ca_ops_link_types=>ty_source( to_upper( condense( is_target-source_name ) ) ).
    READ TABLE mt_ddic ASSIGNING FIELD-SYMBOL(<ls_ddic>) WITH TABLE KEY source = lv_source.
    IF sy-subrc <> 0.
      INSERT VALUE #( source = lv_source fields = mo_dao->source_fields( lv_source ) )
             INTO TABLE mt_ddic ASSIGNING <ls_ddic>.
    ENDIF.
    IF <ls_ddic>-fields IS INITIAL.
      ms_result-not_evaluated = abap_true.
      problem( iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-source_missing
               iv_v1 = is_link-link_id iv_v2 = lv_source ).
      RETURN.
    ENDIF.
    " the fields the read selects (keys, identity, the next links' from fields) and the link's to fields
    DATA(lt_needed) = needed_fields( is_target ).
    LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>).
      INSERT zcl_ca_ops_link_query=>split_ref( <ls_cond>-to_ref )-field INTO TABLE lt_needed.
    ENDLOOP.
    LOOP AT lt_needed ASSIGNING FIELD-SYMBOL(<lv_field>).
      IF NOT line_exists( <ls_ddic>-fields[ fieldname = <lv_field> ] ).
        ms_result-not_evaluated = abap_true.
        problem( iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-field_missing
                 iv_v1 = is_link-link_id iv_v2 = |{ lv_source }-{ <lv_field> }| ).
        RETURN.
      ENDIF.
    ENDLOOP.
    rv_ready = abap_true.
  ENDMETHOD.


  METHOD needed_fields.
    rt_fields = zcl_ca_ops_link_registry=>key_fields( is_object ).
    LOOP AT zcl_ca_ops_link_registry=>identity_fields( is_object ) ASSIGNING FIELD-SYMBOL(<lv_identity>).
      IF NOT line_exists( rt_fields[ table_line = <lv_identity> ] ).
        INSERT <lv_identity> INTO TABLE rt_fields.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_chains ASSIGNING FIELD-SYMBOL(<ls_chain>).
      LOOP AT <ls_chain>-links ASSIGNING FIELD-SYMBOL(<lv_link_id>).
        READ TABLE ms_effective-registry-links ASSIGNING FIELD-SYMBOL(<ls_link>)
             WITH TABLE KEY link_id = <lv_link_id>.
        IF sy-subrc <> 0 OR <ls_link>-from_object <> is_object-object_id.
          CONTINUE.
        ENDIF.
        LOOP AT zcl_ca_ops_link_registry=>conds_of( is_registry = ms_effective-registry iv_link_id = <lv_link_id> )
             ASSIGNING FIELD-SYMBOL(<ls_cond>) WHERE from_ref IS NOT INITIAL.
          DATA(lv_field) = zcl_ca_ops_link_query=>split_ref( <ls_cond>-from_ref )-field.
          IF NOT line_exists( rt_fields[ table_line = lv_field ] ).
            INSERT lv_field INTO TABLE rt_fields.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD masked_keys.
    LOOP AT zcl_ca_ops_link_registry=>key_fields( is_object ) ASSIGNING FIELD-SYMBOL(<lv_key>).
      INSERT VALUE #( fieldname = <lv_key>
                      value     = zcl_ca_ops_link_query=>mask(
                                    iv_value       = zcl_ca_ops_link_query=>value_of( it_pairs = it_pairs
                                                                                      iv_field = <lv_key> )
                                    iv_sensitivity = zcl_ca_ops_link_registry=>sensitivity_of(
                                                       is_registry  = ms_effective-registry
                                                       iv_object_id = is_object-object_id
                                                       iv_field     = <lv_key> ) ) ) INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.


  METHOD masked_identity.
    LOOP AT zcl_ca_ops_link_registry=>identity_fields( is_object ) ASSIGNING FIELD-SYMBOL(<lv_field>).
      INSERT VALUE #( fieldname = <lv_field>
                      value     = zcl_ca_ops_link_query=>mask(
                                    iv_value       = zcl_ca_ops_link_query=>value_of( it_pairs = it_pairs
                                                                                      iv_field = <lv_field> )
                                    iv_sensitivity = zcl_ca_ops_link_registry=>sensitivity_of(
                                                       is_registry  = ms_effective-registry
                                                       iv_object_id = is_object-object_id
                                                       iv_field     = <lv_field> ) ) ) INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.


  METHOD identity.
    rv_identity = condense( CONV string( is_object-object_id ) ).
    LOOP AT zcl_ca_ops_link_registry=>key_fields( is_object ) ASSIGNING FIELD-SYMBOL(<lv_key>).
      rv_identity = |{ rv_identity }{ zif_ca_ops_link_types=>gc_list_separator }{
                       zcl_ca_ops_link_query=>value_of( it_pairs = it_pairs iv_field = <lv_key> ) }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD problem.
    INSERT VALUE #( subject = iv_subject msgno = iv_msgno v1 = iv_v1 v2 = iv_v2 ) INTO TABLE ms_result-problems.
  ENDMETHOD.


  METHOD leaves.
    LOOP AT mt_chains ASSIGNING FIELD-SYMBOL(<ls_chain>).
      READ TABLE ms_effective-registry-links ASSIGNING FIELD-SYMBOL(<ls_head>) WITH TABLE KEY link_id = <ls_chain>-head.
      IF sy-subrc = 0 AND <ls_head>-from_object = iv_object_id.
        rv_leaves = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD object.
    rs_object = VALUE #( ms_effective-registry-objects[ object_id = iv_object_id ] OPTIONAL ).
  ENDMETHOD.

ENDCLASS.
