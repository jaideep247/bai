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
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
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

    "! A new node for a row of the target unless the row was reached before
    METHODS add_node
      IMPORTING
        is_parent      TYPE ty_work
        is_link        TYPE zif_ca_ops_link_types=>ty_link
        iv_step        TYPE i
        is_target      TYPE zif_ca_ops_link_types=>ty_object
        is_row         TYPE zif_ca_ops_link_types=>ty_row
        iv_depth       TYPE i
      CHANGING
        ct_next        TYPE tt_work.

    "! Fields of an object the walk needs: its keys and the from fields of the links leaving it
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
    IF mv_loaded = abap_false.
      ms_effective = zcl_ca_ops_link_registry=>effective( mo_dao->read_registry( ) ).
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
    CLEAR: ms_result, mt_work, mt_visited, mt_chains, mv_stop.
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
        LOOP AT zcl_ca_ops_link_query=>prefer( it_rows = lt_matched it_conds = lt_conds ) ASSIGNING <ls_row>.
          add_node( EXPORTING is_parent = <ls_source>
                              is_link   = ls_link
                              iv_step   = lv_step
                              is_target = ls_target
                              is_row    = <ls_row>
                              iv_depth  = iv_depth
                    CHANGING  ct_next   = ct_next ).
          IF mv_stop = abap_true.
            RETURN.
          ENDIF.
        ENDLOOP.
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
    INSERT VALUE #( node_id   = ls_work-node_id
                    parent_id = is_parent-node_id
                    depth     = iv_depth
                    object_id = is_target-object_id
                    keys      = masked_keys( is_object = is_target it_pairs = is_row-pairs )
                    link_id   = is_link-link_id
                    step      = iv_step
                    quality   = ls_work-quality
                    path      = ls_work-path ) INTO TABLE ms_result-nodes.
  ENDMETHOD.


  METHOD needed_fields.
    rt_fields = zcl_ca_ops_link_registry=>key_fields( is_object ).
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
