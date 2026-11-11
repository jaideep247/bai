*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_link_dao.clas.abap
*& Purpose:
*& Data access of the link registry: reads the six registry tables, the
*& runtime DDIC of a source (metadata only) and runs the read of one link
*& for a set of source rows. The read is validated here, never trusting a
*& caller-built string: approval of the target for the area and the S_TABU_NAM
*& display check through the check registry's data access
*& (ZIF_CA_OPS_CHECK_DAO=>IS_TABLE_APPROVED / GET_TABLE_FIELDS), the SQL from
*& ZCL_CA_OPS_LINK_QUERY (DDIC-checked names, quoted literals), at most
*& IV_MAX_ROWS rows into a structure of the selected fields only. Read
*& only; values are returned in character form.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - link registry data access</p>
CLASS zcl_ca_ops_link_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_link_dao.

  PRIVATE SECTION.
    "! Structure description of a source (table or CDS view entity); unbound when unknown
    METHODS describe
      IMPORTING
        iv_source        TYPE clike
      RETURNING
        VALUE(ro_struct) TYPE REF TO cl_abap_structdescr.

    "! Table of a structure of the given fields of the source
    METHODS result_table
      IMPORTING
        io_struct      TYPE REF TO cl_abap_structdescr
        it_fields      TYPE zif_ca_ops_link_types=>tt_fieldname
      RETURNING
        VALUE(rr_data) TYPE REF TO data
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_link_dao IMPLEMENTATION.

  METHOD zif_ca_ops_link_dao~read_registry.
    SELECT layer_id, layer_kind, layer_rank, id_prefix, description, owner, active
      FROM zca_ops_lnklyr
      INTO CORRESPONDING FIELDS OF TABLE @rs_registry-layers.
    SELECT object_id, layer_id, source_name, source_kind, key_fields, description, active
      FROM zca_ops_lnkobj
      INTO CORRESPONDING FIELDS OF TABLE @rs_registry-objects.
    SELECT object_id, field_name, layer_id, source_name, data_element, sensitivity, evidence, verify_ref, description
      FROM zca_ops_lnkfld
      INTO CORRESPONDING FIELDS OF TABLE @rs_registry-fields.
    SELECT link_id, layer_id, from_object, to_object, cardinality, quality, fallback_of, replaces, active, owner,
           verify_ref, description
      FROM zca_ops_link
      INTO CORRESPONDING FIELDS OF TABLE @rs_registry-links.
    SELECT link_id, cond_no, cond_kind, from_ref, to_ref, cond_value, transform, transform_arg
      FROM zca_ops_lnkcnd
      INTO CORRESPONDING FIELDS OF TABLE @rs_registry-conds.
    SELECT target_kind, target_id, layer_id, active, reason, owner
      FROM zca_ops_lnkact
      INTO CORRESPONDING FIELDS OF TABLE @rs_registry-activations.
  ENDMETHOD.


  METHOD zif_ca_ops_link_dao~read_linked.
    DATA lt_fields TYPE zif_ca_ops_chk_types=>tt_field.
    FIELD-SYMBOLS <lt_result> TYPE STANDARD TABLE.

    " The SQL boundary trusts no caller-built string: approval, DDIC and literals are checked here
    DATA(lo_check_dao) = zcl_ca_ops_factory=>get_check_dao( ).
    DATA(lv_tabname) = CONV zif_ca_ops_chk_types=>ty_tabname( to_upper( condense( is_target-source_name ) ) ).
    DATA(lv_approved) = lo_check_dao->is_table_approved( iv_area = iv_area iv_tabname = lv_tabname ).
    IF lv_approved = abap_true.
      lt_fields = lo_check_dao->get_table_fields( lv_tabname ).
    ENDIF.
    DATA(ls_query) = zcl_ca_ops_link_query=>build( iv_area     = iv_area
                                                   is_target   = is_target
                                                   it_conds    = it_conds
                                                   it_sources  = it_sources
                                                   it_select   = it_select
                                                   it_fields   = lt_fields
                                                   iv_approved = lv_approved ).
    IF ls_query-where_clause IS INITIAL OR iv_max_rows <= 0.
      RETURN.
    ENDIF.

    DATA(lr_result) = result_table( io_struct = describe( ls_query-source ) it_fields = ls_query-fields ).
    ASSIGN lr_result->* TO <lt_result>.
    DATA(lv_select) = ls_query-select_list.
    DATA(lv_from) = CONV string( ls_query-source ).
    DATA(lv_where) = ls_query-where_clause.
    DATA(lv_order) = ls_query-select_list.
    TRY.
        SELECT (lv_select)
          FROM (lv_from)
          WHERE (lv_where)
          ORDER BY (lv_order)
          INTO CORRESPONDING FIELDS OF TABLE @<lt_result>
          UP TO @iv_max_rows ROWS.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e222(zca_ops) WITH is_target-object_id ls_query-source
          EXPORTING
            previous = lx_sql.
    ENDTRY.

    LOOP AT <lt_result> ASSIGNING FIELD-SYMBOL(<ls_line>).
      DATA(ls_row) = VALUE zif_ca_ops_link_types=>ty_row( ).
      LOOP AT ls_query-fields ASSIGNING FIELD-SYMBOL(<lv_field>).
        ASSIGN COMPONENT <lv_field> OF STRUCTURE <ls_line> TO FIELD-SYMBOL(<lv_value>).
        IF sy-subrc = 0.
          INSERT VALUE #( fieldname = <lv_field> value = |{ <lv_value> }| ) INTO TABLE ls_row-pairs.
        ENDIF.
      ENDLOOP.
      INSERT ls_row INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_link_dao~source_fields.
    DATA lt_ddic TYPE ddfields.

    DATA(lo_struct) = describe( iv_source ).
    IF lo_struct IS NOT BOUND.
      RETURN.
    ENDIF.
    lo_struct->get_ddic_field_list(
      RECEIVING
        p_field_list = lt_ddic
      EXCEPTIONS
        not_found    = 1
        no_ddic_type = 2
        OTHERS       = 3 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    LOOP AT lt_ddic ASSIGNING FIELD-SYMBOL(<ls_ddic>).
      INSERT VALUE #( fieldname = <ls_ddic>-fieldname type_kind = <ls_ddic>-inttype ) INTO TABLE rt_fields.
    ENDLOOP.
  ENDMETHOD.


  METHOD describe.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.

    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = to_upper( condense( CONV string( iv_source ) ) )
      RECEIVING
        p_descr_ref    = lo_descr
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    TRY.
        ro_struct ?= lo_descr.
      CATCH cx_sy_move_cast_error.
        CLEAR ro_struct.
    ENDTRY.
  ENDMETHOD.


  METHOD result_table.
    DATA lt_components TYPE cl_abap_structdescr=>component_table.

    IF io_struct IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e082(zca_ops) WITH space.
    ENDIF.
    LOOP AT io_struct->get_included_view( ) ASSIGNING FIELD-SYMBOL(<ls_component>).
      IF line_exists( it_fields[ table_line = <ls_component>-name ] ).
        INSERT VALUE #( name = <ls_component>-name type = <ls_component>-type ) INTO TABLE lt_components.
      ENDIF.
    ENDLOOP.
    TRY.
        DATA(lo_table) = cl_abap_tabledescr=>create( p_line_type = cl_abap_structdescr=>create( lt_components ) ).
        CREATE DATA rr_data TYPE HANDLE lo_table.
      CATCH cx_sy_struct_creation cx_sy_table_creation INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e082(zca_ops) WITH io_struct->get_relative_name( )
          EXPORTING
            previous = lx_error.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
