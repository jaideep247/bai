*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_links.clas.abap
*& Purpose:
*& Linked objects of the break analysis through the link registry: the
*& effective registry is read once (ZCL_CA_OPS_LINK_REGISTRY=>EFFECTIVE);
*& for each link a LINK condition names, the open journal lines are the
*& source rows (fields as the registry object S4_JOURNAL_ITEM names them),
*& read in chunks of LINK_READ_CHUNK lines with one database read each
*& (ZIF_CA_OPS_LINK_DAO=>READ_LINKED: approved table, runtime DDIC, quoted
*& literals), at most BRK_LINK_MAX_ROWS rows per read; every row is
*& attributed to its lines by the link's conditions
*& (ZCL_CA_OPS_LINK_QUERY=>BELONGS_TO). Keys and values of sensitive fields
*& are masked before they leave this class. A link that cannot be read is a
*& problem (293): its conditions then see no row. Read only.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - break analysis linked objects</p>
"! The same reads the walker makes for one start row, made for the lines of a package of groups.
CLASS zcl_ca_ops_brk_links DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_brk_links.

    "! @parameter io_dao | Data access of the link registry (default ZCL_CA_OPS_LINK_DAO; a double in tests)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_link_dao OPTIONAL.

  PRIVATE SECTION.
    DATA mo_dao TYPE REF TO zif_ca_ops_link_dao.
    DATA ms_effective TYPE zif_ca_ops_link_types=>ty_effective.
    DATA mv_loaded TYPE abap_bool.

    METHODS effective
      RETURNING
        VALUE(rs_effective) TYPE zif_ca_ops_link_types=>ty_effective.

    "! Fields a read of the link returns: the target's keys, the fields the conditions compare, the to fields
    METHODS select_list
      IMPORTING
        is_target        TYPE zif_ca_ops_link_types=>ty_object
        iv_link_id       TYPE zif_ca_ops_link_types=>ty_link_id
        it_conds         TYPE zif_ca_ops_link_types=>tt_cond
        it_fields        TYPE zif_ca_ops_brk_links=>tt_link_field
      RETURNING
        VALUE(rt_select) TYPE zif_ca_ops_link_types=>tt_fieldname.

    "! The row with the values of sensitive fields masked and its key (masked, separated)
    METHODS masked
      IMPORTING
        is_target TYPE zif_ca_ops_link_types=>ty_object
      EXPORTING
        ev_key    TYPE zif_ca_ops_brk_types=>ty_link_key
      CHANGING
        cs_row    TYPE zif_ca_ops_link_types=>ty_row.

    METHODS problem
      IMPORTING
        iv_link_id  TYPE zif_ca_ops_link_types=>ty_link_id
        iv_detail   TYPE clike
      CHANGING
        ct_problems TYPE zif_ca_ops_brk_types=>tt_problem.

ENDCLASS.



CLASS zcl_ca_ops_brk_links IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_link_dao( ) ).
  ENDMETHOD.


  METHOD effective.
    IF mv_loaded = abap_false.
      ms_effective = zcl_ca_ops_link_registry=>effective( mo_dao->read_registry( ) ).
      mv_loaded = abap_true.
    ENDIF.
    rs_effective = ms_effective.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_links~effective_links.
    DATA(ls_effective) = effective( ).
    LOOP AT ls_effective-chains ASSIGNING FIELD-SYMBOL(<ls_chain>).
      LOOP AT <ls_chain>-links ASSIGNING FIELD-SYMBOL(<lv_link_id>).
        READ TABLE ls_effective-registry-links ASSIGNING FIELD-SYMBOL(<ls_link>)
             WITH TABLE KEY link_id = <lv_link_id>.
        IF sy-subrc = 0 AND <ls_link>-from_object = zif_ca_ops_brk_types=>gc_item_object
           AND NOT line_exists( rt_links[ table_line = <lv_link_id> ] ).
          INSERT <lv_link_id> INTO TABLE rt_links.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_links~read.
    DATA lt_sources TYPE zif_ca_ops_link_types=>tt_row.
    DATA lt_keys TYPE string_table.
    DATA lt_links TYPE zif_ca_ops_link_types=>tt_link_id.
    DATA lt_chunk TYPE zif_ca_ops_link_types=>tt_row.
    DATA lt_chunk_keys TYPE string_table.
    CLEAR: et_hits, et_problems.

    DATA(ls_effective) = effective( ).
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(lv_chunk) = nmax( val1 = CONV i( lo_params->get_param(
                                            iv_name    = zif_ca_ops_link_types=>gc_param-read_chunk
                                            iv_default = CONV #( zif_ca_ops_link_types=>gc_default-read_chunk ) ) )
                           val2 = 1 ).
    DATA(lv_max_rows) = nmax( val1 = CONV i( lo_params->get_param(
                                               iv_name    = zif_ca_ops_brk_types=>gc_param-link_rows
                                               iv_default = CONV #( zif_ca_ops_brk_types=>gc_default-link_rows ) ) )
                              val2 = 1 ).

    " source rows: the open lines (a line after the key date is context, its links are not read)
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE later = abap_false.
      INSERT VALUE #( pairs = VALUE #( ( fieldname = zif_ca_ops_brk_types=>gc_item_field-ledger     value = <ls_item>-ledger )
                                       ( fieldname = zif_ca_ops_brk_types=>gc_item_field-company    value = <ls_item>-bukrs )
                                       ( fieldname = zif_ca_ops_brk_types=>gc_item_field-year       value = <ls_item>-gjahr )
                                       ( fieldname = zif_ca_ops_brk_types=>gc_item_field-document   value = <ls_item>-belnr )
                                       ( fieldname = zif_ca_ops_brk_types=>gc_item_field-line       value = <ls_item>-docln )
                                       ( fieldname = zif_ca_ops_brk_types=>gc_item_field-account    value = <ls_item>-hkont )
                                       ( fieldname = zif_ca_ops_brk_types=>gc_item_field-assignment
                                         value     = <ls_item>-assignment ) ) )
             INTO TABLE lt_sources.
      INSERT CONV string( zcl_ca_ops_brk_rules=>line_key( <ls_item> ) ) INTO TABLE lt_keys.
    ENDLOOP.
    IF lt_sources IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_fields ASSIGNING FIELD-SYMBOL(<ls_field>).
      IF NOT line_exists( lt_links[ table_line = <ls_field>-link_id ] ).
        INSERT <ls_field>-link_id INTO TABLE lt_links.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<lv_link_id>).
      READ TABLE ls_effective-registry-links ASSIGNING FIELD-SYMBOL(<ls_link>) WITH TABLE KEY link_id = <lv_link_id>.
      IF sy-subrc <> 0.
        problem( EXPORTING iv_link_id = <lv_link_id> iv_detail = zif_ca_ops_brk_types=>gc_item_object
                 CHANGING  ct_problems = et_problems ).
        CONTINUE.
      ENDIF.
      READ TABLE ls_effective-registry-objects ASSIGNING FIELD-SYMBOL(<ls_target>)
           WITH TABLE KEY object_id = <ls_link>-to_object.
      IF sy-subrc <> 0.
        problem( EXPORTING iv_link_id = <lv_link_id> iv_detail = <ls_link>-to_object
                 CHANGING  ct_problems = et_problems ).
        CONTINUE.
      ENDIF.
      DATA(lt_conds) = zcl_ca_ops_link_registry=>conds_of( is_registry = ls_effective-registry
                                                           iv_link_id  = <lv_link_id> ).
      DATA(lt_select) = select_list( is_target = <ls_target> iv_link_id = <lv_link_id>
                                     it_conds  = lt_conds    it_fields  = it_fields ).
      DATA(lv_truncated) = abap_false.
      DATA(lv_from) = 1.
      WHILE lv_from <= lines( lt_sources ).
        DATA(lv_to) = nmin( val1 = lv_from + lv_chunk - 1 val2 = lines( lt_sources ) ).
        lt_chunk = VALUE #( FOR i = lv_from THEN i + 1 UNTIL i > lv_to ( lt_sources[ i ] ) ).
        lt_chunk_keys = VALUE #( FOR j = lv_from THEN j + 1 UNTIL j > lv_to ( lt_keys[ j ] ) ).
        lv_from = lv_to + 1.
        TRY.
            DATA(lt_rows) = mo_dao->read_linked( iv_area     = iv_area
                                                 is_target   = <ls_target>
                                                 it_conds    = lt_conds
                                                 it_sources  = lt_chunk
                                                 it_select   = lt_select
                                                 iv_max_rows = lv_max_rows ).
          CATCH zcx_ca_ops_error INTO DATA(lx_read).
            problem( EXPORTING iv_link_id = <lv_link_id> iv_detail = lx_read->get_text( )
                     CHANGING  ct_problems = et_problems ).
            EXIT.
        ENDTRY.
        IF lines( lt_rows ) >= lv_max_rows AND lv_truncated = abap_false.
          lv_truncated = abap_true.
          problem( EXPORTING iv_link_id = <lv_link_id> iv_detail = |{ lv_max_rows }|
                   CHANGING  ct_problems = et_problems ).
        ENDIF.
        LOOP AT lt_rows INTO DATA(ls_row).
          DATA(ls_raw) = ls_row.
          masked( EXPORTING is_target = <ls_target>
                  IMPORTING ev_key    = DATA(lv_row_key)
                  CHANGING  cs_row    = ls_row ).
          LOOP AT lt_chunk ASSIGNING FIELD-SYMBOL(<ls_source>).
            DATA(lv_index) = sy-tabix.
            TRY.
                IF zcl_ca_ops_link_query=>belongs_to( is_row    = ls_raw
                                                      is_source = <ls_source>
                                                      it_conds  = lt_conds ) = abap_true.
                  INSERT VALUE #( link_id   = <lv_link_id>
                                  line_key  = lt_chunk_keys[ lv_index ]
                                  object_id = <ls_target>-object_id
                                  row_key   = lv_row_key
                                  pairs     = ls_row-pairs ) INTO TABLE et_hits.
                ENDIF.
              CATCH zcx_ca_ops_error.
                " a transform the row cannot take: the row belongs to no line
                CONTINUE.
            ENDTRY.
          ENDLOOP.
        ENDLOOP.
      ENDWHILE.
    ENDLOOP.
  ENDMETHOD.


  METHOD select_list.
    rt_select = zcl_ca_ops_link_registry=>key_fields( is_target ).
    LOOP AT it_fields ASSIGNING FIELD-SYMBOL(<ls_field>) WHERE link_id = iv_link_id AND field IS NOT INITIAL.
      DATA(lv_field) = CONV zif_ca_ops_link_types=>ty_fieldname( to_upper( condense( <ls_field>-field ) ) ).
      IF NOT line_exists( rt_select[ table_line = lv_field ] ).
        INSERT lv_field INTO TABLE rt_select.
      ENDIF.
    ENDLOOP.
    LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>) WHERE to_ref IS NOT INITIAL.
      lv_field = zcl_ca_ops_link_query=>split_ref( <ls_cond>-to_ref )-field.
      IF NOT line_exists( rt_select[ table_line = lv_field ] ).
        INSERT lv_field INTO TABLE rt_select.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD masked.
    DATA lt_parts TYPE string_table.
    CLEAR ev_key.
    LOOP AT cs_row-pairs ASSIGNING FIELD-SYMBOL(<ls_pair>).
      DATA(lv_sensitivity) = zcl_ca_ops_link_registry=>sensitivity_of( is_registry  = ms_effective-registry
                                                                        iv_object_id = is_target-object_id
                                                                        iv_field     = <ls_pair>-fieldname ).
      IF lv_sensitivity IS NOT INITIAL.
        <ls_pair>-value = zcl_ca_ops_link_query=>mask( iv_value = <ls_pair>-value iv_sensitivity = lv_sensitivity ).
      ENDIF.
    ENDLOOP.
    LOOP AT zcl_ca_ops_link_registry=>key_fields( is_target ) ASSIGNING FIELD-SYMBOL(<lv_key>).
      INSERT condense( CONV string( zcl_ca_ops_link_query=>value_of( it_pairs = cs_row-pairs
                                                                     iv_field = <lv_key> ) ) ) INTO TABLE lt_parts.
    ENDLOOP.
    ev_key = concat_lines_of( table = lt_parts sep = zif_ca_ops_brk_types=>gc_key_separator ).
  ENDMETHOD.


  METHOD problem.
    INSERT VALUE #( msgno = zif_ca_ops_brk_types=>gc_msg-link_failed v1 = iv_link_id v2 = iv_detail )
           INTO TABLE ct_problems.
  ENDMETHOD.

ENDCLASS.
