*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_link_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the link registry data access on cl_osql_test_environment
*& doubles: the six registry tables read whole; the read of one link on a
*& doubled source (the layer table itself as an approved source of the
*& area: the rows of the source values only, the selected fields returned
*& in character form, the row cap); an unapproved source refused (212)
*& before anything is read; the runtime DDIC of a source (metadata) and an
*& unknown source. S_TABU_NAM through an authorisation double. Does not
*& prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
CLASS ltd_table_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_table_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~may_read_table.
    rv_allowed = abap_true.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_link_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        source    TYPE zif_ca_ops_link_types=>ty_source VALUE 'ZCA_OPS_LNKLYR',
        object    TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'XX_LAYER',
        link      TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'XX_TO_LAYER',
        to_ref    TYPE zif_ca_ops_link_types=>ty_field_ref VALUE 'ZCA_OPS_LNKLYR-LAYER_ID',
        from_ref  TYPE zif_ca_ops_link_types=>ty_field_ref VALUE 'ZXX_SOURCE-LAYER',
        first     TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'ZT_A',
        second    TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'ZT_B',
        third     TYPE zif_ca_ops_link_types=>ty_layer_id VALUE 'ZT_C',
        owner     TYPE zif_ca_ops_link_types=>ty_owner VALUE 'ZT TEAM',
        unknown   TYPE zif_ca_ops_link_types=>ty_source VALUE 'ZZ_NO_SUCH_TABLE',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_link_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS given_layer
      IMPORTING
        iv_layer TYPE zif_ca_ops_link_types=>ty_layer_id.
    METHODS given_approved.
    METHODS target
      RETURNING
        VALUE(rs_target) TYPE zif_ca_ops_link_types=>ty_object.
    METHODS conds
      RETURNING
        VALUE(rt_conds) TYPE zif_ca_ops_link_types=>tt_cond.
    METHODS sources
      RETURNING
        VALUE(rt_sources) TYPE zif_ca_ops_link_types=>tt_row.

    METHODS registry_read_whole      FOR TESTING.
    METHODS linked_rows_of_sources   FOR TESTING.
    METHODS row_cap_applied          FOR TESTING.
    METHODS unapproved_source_refused FOR TESTING.
    METHODS ddic_fields_of_source    FOR TESTING.
    METHODS unknown_source_no_fields FOR TESTING.
ENDCLASS.


CLASS ltc_link_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCA_OPS_LNKLYR' ) ( 'ZCA_OPS_LNKOBJ' ) ( 'ZCA_OPS_LNKFLD' ) ( 'ZCA_OPS_LINK' )
                                   ( 'ZCA_OPS_LNKCND' ) ( 'ZCA_OPS_LNKACT' ) ( 'ZCA_OPS_TABWL' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    zcl_ca_ops_injector=>inject_auth( NEW ltd_table_auth( ) ).
    mo_cut = NEW zcl_ca_ops_link_dao( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD given_layer.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_lnklyr WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_lnklyr.
    ls_row-layer_id   = iv_layer.
    ls_row-layer_kind = zif_ca_ops_link_types=>gc_layer_kind-customer.
    ls_row-layer_rank = 30.
    ls_row-id_prefix  = 'XX_'.
    ls_row-owner      = gc-owner.
    ls_row-active     = abap_true.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD given_approved.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_tabwl WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_tabwl.
    ls_row-area       = gc-area.
    ls_row-table_name = gc-source.
    ls_row-active     = abap_true.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD target.
    rs_target-object_id   = gc-object.
    rs_target-source_name = gc-source.
    rs_target-source_kind = zif_ca_ops_link_types=>gc_source_kind-table.
    rs_target-key_fields  = 'LAYER_ID'.
    rs_target-active      = abap_true.
  ENDMETHOD.


  METHOD conds.
    DATA ls_cond TYPE zif_ca_ops_link_types=>ty_cond.
    ls_cond-link_id   = gc-link.
    ls_cond-cond_no   = 1.
    ls_cond-cond_kind = zif_ca_ops_link_types=>gc_cond_kind-eq.
    ls_cond-from_ref  = gc-from_ref.
    ls_cond-to_ref    = gc-to_ref.
    INSERT ls_cond INTO TABLE rt_conds.
  ENDMETHOD.


  METHOD sources.
    INSERT VALUE #( pairs = VALUE #( ( fieldname = 'LAYER' value = gc-first ) ) ) INTO TABLE rt_sources.
    INSERT VALUE #( pairs = VALUE #( ( fieldname = 'LAYER' value = gc-second ) ) ) INTO TABLE rt_sources.
  ENDMETHOD.


  METHOD registry_read_whole.
    DATA lt_links TYPE STANDARD TABLE OF zca_ops_link WITH EMPTY KEY.
    DATA ls_link TYPE zca_ops_link.
    TRY.
        given_layer( gc-first ).
        given_layer( gc-second ).
        ls_link-link_id     = gc-link.
        ls_link-layer_id    = gc-first.
        ls_link-cardinality = zif_ca_ops_link_types=>gc_cardinality-many_many.
        ls_link-active      = abap_true.
        INSERT ls_link INTO TABLE lt_links.
        go_env->insert_test_data( lt_links ).
        DATA(ls_registry) = mo_cut->read_registry( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_registry-layers ) exp = 2 msg = 'Every layer' ).
        cl_abap_unit_assert=>assert_equals( act = ls_registry-links[ 1 ]-link_id exp = gc-link msg = 'The link' ).
        cl_abap_unit_assert=>assert_initial( act = ls_registry-conds msg = 'No condition rows' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one read for all source rows; only the rows of their values; selected fields as characters
  METHOD linked_rows_of_sources.
    TRY.
        given_approved( ).
        given_layer( gc-first ).
        given_layer( gc-second ).
        given_layer( gc-third ).
        DATA(lt_rows) = mo_cut->read_linked( iv_area     = gc-area
                                             is_target   = target( )
                                             it_conds    = conds( )
                                             it_sources  = sources( )
                                             it_select   = VALUE #( ( 'LAYER_ID' ) ( 'OWNER' ) )
                                             iv_max_rows = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'The two layers of the sources' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_link_query=>value_of( it_pairs = lt_rows[ 1 ]-pairs
                                                                                   iv_field = 'OWNER' )
                                            exp = gc-owner msg = 'Selected field returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD row_cap_applied.
    TRY.
        given_approved( ).
        given_layer( gc-first ).
        given_layer( gc-second ).
        DATA(lt_rows) = mo_cut->read_linked( iv_area     = gc-area
                                             is_target   = target( )
                                             it_conds    = conds( )
                                             it_sources  = sources( )
                                             it_select   = VALUE #( ( 'LAYER_ID' ) )
                                             iv_max_rows = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'At most the cap' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unapproved_source_refused.
    TRY.
        given_layer( gc-first ).
        mo_cut->read_linked( iv_area     = gc-area
                             is_target   = target( )
                             it_conds    = conds( )
                             it_sources  = sources( )
                             it_select   = VALUE #( ( 'LAYER_ID' ) )
                             iv_max_rows = 10 ).
        cl_abap_unit_assert=>fail( msg = 'A source not approved for the area is never read' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '212'
                                            msg = 'Message 212' ).
    ENDTRY.
  ENDMETHOD.


  METHOD ddic_fields_of_source.
    TRY.
        DATA(lt_fields) = mo_cut->source_fields( gc-source ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_fields[ fieldname = 'LAYER_ID' ] ) )
                                          msg = 'Field of the runtime DDIC' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_source_no_fields.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->source_fields( gc-unknown ) msg = 'Unknown source' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
