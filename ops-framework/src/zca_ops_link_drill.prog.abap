*&---------------------------------------------------------------------*
*& Artifact: zca_ops_link_drill.prog.abap
*& Purpose:
*& Link drill-down (build Q, docs/LINK_REGISTRY.md section 5a): from a
*& registry object and the key of one of its rows, every linked row the
*& walker ZIF_CA_OPS_LINK_WALKER reaches - level, object, key (sensitive
*& values masked), link, its layer and quality, the path - with the match
*& of every row: ONE, MANY or AMBIGUOUS (a "to one" link found several
*& rows: every candidate is listed with its identity values, never one
*& picked) and the problems of the walk (limits, a link not followed
*& because its table or field is missing - not evaluated, never a dump).
*& Authorisation ZCA_OPS 03 of the area (the walker); reads only the
*& tables approved for the area. Read only, nothing stored.
*& Modification log:
*& 2026-11-16 | Initial version (build Q: ambiguous matches shown, not hidden).
*&---------------------------------------------------------------------*
REPORT zca_ops_link_drill.

PARAMETERS p_area TYPE zif_ca_ops_types=>ty_area OBLIGATORY.
PARAMETERS p_obj TYPE zif_ca_ops_link_types=>ty_object_id OBLIGATORY.
PARAMETERS p_key1 TYPE zif_ca_ops_link_types=>ty_fieldname OBLIGATORY.
PARAMETERS p_val1 TYPE zif_ca_ops_link_types=>ty_key_value OBLIGATORY LOWER CASE.
PARAMETERS p_key2 TYPE zif_ca_ops_link_types=>ty_fieldname.
PARAMETERS p_val2 TYPE zif_ca_ops_link_types=>ty_key_value LOWER CASE.
PARAMETERS p_key3 TYPE zif_ca_ops_link_types=>ty_fieldname.
PARAMETERS p_val3 TYPE zif_ca_ops_link_types=>ty_key_value LOWER CASE.
PARAMETERS p_depth TYPE i.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    "! One line of the list: a node of the walk or a problem of it
    TYPES:
      BEGIN OF ty_line,
        node_id      TYPE i,
        parent_id    TYPE i,
        depth        TYPE i,
        object_id    TYPE zif_ca_ops_link_types=>ty_object_id,
        keys         TYPE string,
        match        TYPE zif_ca_ops_link_types=>ty_match,
        candidates   TYPE i,
        identity     TYPE string,
        link_id      TYPE zif_ca_ops_link_types=>ty_link_id,
        layer_id     TYPE zif_ca_ops_link_types=>ty_layer_id,
        link_quality TYPE zif_ca_ops_link_types=>ty_flag1,
        quality      TYPE zif_ca_ops_link_types=>ty_flag1,
        path         TYPE string,
        note         TYPE string,
      END OF ty_line.
    TYPES tt_line TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

    CONSTANTS:
      BEGIN OF gc_column,
        object_id    TYPE lvc_fname VALUE 'OBJECT_ID',
        keys         TYPE lvc_fname VALUE 'KEYS',
        match        TYPE lvc_fname VALUE 'MATCH',
        candidates   TYPE lvc_fname VALUE 'CANDIDATES',
        identity     TYPE lvc_fname VALUE 'IDENTITY',
        link_id      TYPE lvc_fname VALUE 'LINK_ID',
        layer_id     TYPE lvc_fname VALUE 'LAYER_ID',
        link_quality TYPE lvc_fname VALUE 'LINK_QUALITY',
        path         TYPE lvc_fname VALUE 'PATH',
        note         TYPE lvc_fname VALUE 'NOTE',
      END OF gc_column.
    CONSTANTS gc_pair_separator TYPE string VALUE `, `.
    CONSTANTS gc_equals TYPE string VALUE `=`.

    DATA mt_lines TYPE tt_line.

    METHODS pairs_text
      IMPORTING
        it_pairs       TYPE zif_ca_ops_link_types=>tt_pair
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS display.

    METHODS set_text
      IMPORTING
        io_columns TYPE REF TO cl_salv_columns_table
        iv_name    TYPE lvc_fname
        iv_text    TYPE clike.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    DATA lt_keys TYPE zif_ca_ops_link_types=>tt_pair.
    DATA lv_ambiguous TYPE i.

    INSERT VALUE #( fieldname = to_upper( p_key1 ) value = p_val1 ) INTO TABLE lt_keys.
    IF p_key2 IS NOT INITIAL.
      INSERT VALUE #( fieldname = to_upper( p_key2 ) value = p_val2 ) INTO TABLE lt_keys.
    ENDIF.
    IF p_key3 IS NOT INITIAL.
      INSERT VALUE #( fieldname = to_upper( p_key3 ) value = p_val3 ) INTO TABLE lt_keys.
    ENDIF.
    TRY.
        DATA(ls_result) = NEW zcl_ca_ops_link_walker( )->zif_ca_ops_link_walker~walk(
                            VALUE #( area      = p_area
                                     object_id = to_upper( p_obj )
                                     keys      = lt_keys
                                     max_depth = p_depth ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    LOOP AT ls_result-nodes ASSIGNING FIELD-SYMBOL(<ls_node>).
      INSERT VALUE #( node_id      = <ls_node>-node_id
                      parent_id    = <ls_node>-parent_id
                      depth        = <ls_node>-depth
                      object_id    = <ls_node>-object_id
                      keys         = pairs_text( <ls_node>-keys )
                      match        = <ls_node>-match
                      candidates   = <ls_node>-candidates
                      identity     = pairs_text( <ls_node>-identity )
                      link_id      = <ls_node>-link_id
                      layer_id     = <ls_node>-layer_id
                      link_quality = <ls_node>-link_quality
                      quality      = <ls_node>-quality
                      path         = <ls_node>-path ) INTO TABLE mt_lines.
      IF <ls_node>-match = zif_ca_ops_link_types=>gc_match-ambiguous.
        lv_ambiguous += 1.
      ENDIF.
    ENDLOOP.
    " a candidate reached before on another path is listed once more with its evidence (node 0)
    LOOP AT ls_result-ambiguities ASSIGNING FIELD-SYMBOL(<ls_ambiguity>).
      LOOP AT <ls_ambiguity>-candidates ASSIGNING FIELD-SYMBOL(<ls_candidate>) WHERE node_id = 0.
        INSERT VALUE #( parent_id    = <ls_ambiguity>-parent_id
                        object_id    = <ls_ambiguity>-object_id
                        keys         = pairs_text( <ls_candidate>-keys )
                        match        = zif_ca_ops_link_types=>gc_match-ambiguous
                        candidates   = lines( <ls_ambiguity>-candidates )
                        identity     = pairs_text( <ls_candidate>-identity )
                        link_id      = <ls_ambiguity>-link_id
                        layer_id     = <ls_ambiguity>-layer_id
                        link_quality = <ls_ambiguity>-link_quality ) INTO TABLE mt_lines.
      ENDLOOP.
    ENDLOOP.
    LOOP AT ls_result-problems ASSIGNING FIELD-SYMBOL(<ls_problem>).
      INSERT VALUE #( link_id = <ls_problem>-subject
                      note    = zcl_ca_ops_util=>text( iv_msgno = <ls_problem>-msgno
                                                       iv_v1    = <ls_problem>-v1
                                                       iv_v2    = <ls_problem>-v2
                                                       iv_v3    = <ls_problem>-v3
                                                       iv_v4    = <ls_problem>-v4 ) ) INTO TABLE mt_lines.
    ENDLOOP.

    DATA(lv_nodes) = lines( ls_result-nodes ).
    DATA(lv_problems) = lines( ls_result-problems ).
    MESSAGE s645(zca_ops) WITH p_obj lv_nodes lv_ambiguous lv_problems.
    IF sy-batch = abap_false.
      display( ).
    ENDIF.
  ENDMETHOD.


  METHOD pairs_text.
    LOOP AT it_pairs ASSIGNING FIELD-SYMBOL(<ls_pair>).
      rv_text = COND #( WHEN rv_text IS INITIAL THEN |{ <ls_pair>-fieldname }{ gc_equals }{ <ls_pair>-value }|
                        ELSE |{ rv_text }{ gc_pair_separator }{ <ls_pair>-fieldname }{ gc_equals }{ <ls_pair>-value }| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_lines ).
        lo_alv->get_functions( )->set_all( abap_true ).
        DATA(lo_columns) = lo_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        set_text( io_columns = lo_columns iv_name = gc_column-object_id iv_text = TEXT-c01 ).
        set_text( io_columns = lo_columns iv_name = gc_column-keys iv_text = TEXT-c02 ).
        set_text( io_columns = lo_columns iv_name = gc_column-match iv_text = TEXT-c03 ).
        set_text( io_columns = lo_columns iv_name = gc_column-candidates iv_text = TEXT-c04 ).
        set_text( io_columns = lo_columns iv_name = gc_column-identity iv_text = TEXT-c05 ).
        set_text( io_columns = lo_columns iv_name = gc_column-link_id iv_text = TEXT-c06 ).
        set_text( io_columns = lo_columns iv_name = gc_column-layer_id iv_text = TEXT-c07 ).
        set_text( io_columns = lo_columns iv_name = gc_column-link_quality iv_text = TEXT-c08 ).
        set_text( io_columns = lo_columns iv_name = gc_column-path iv_text = TEXT-c09 ).
        set_text( io_columns = lo_columns iv_name = gc_column-note iv_text = TEXT-c10 ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD set_text.
    TRY.
        DATA(lo_column) = io_columns->get_column( iv_name ).
        lo_column->set_short_text( CONV #( iv_text ) ).
        lo_column->set_medium_text( CONV #( iv_text ) ).
        lo_column->set_long_text( CONV #( iv_text ) ).
      CATCH cx_salv_not_found ##NO_HANDLER.
        " Column of the row type only - nothing to label
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
