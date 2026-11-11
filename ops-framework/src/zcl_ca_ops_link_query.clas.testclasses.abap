*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_link_query.clas.testclasses.abap
*& Purpose:
*& Unit tests of the pure link read builder: the WHERE clause of one EQ
*& condition (IN list of distinct quoted values, blank source values never
*& joined), of several (OR groups), constants and not-initial conditions;
*& refusals (not approved 212, unknown field 213, reference of another
*& source 234, not a number 227); nothing to read without a join value;
*& transforms (ALPHA, NOZERO, UPPER, LEFT, RIGHT, PREFIX, SUFFIX, invalid
*& argument 215); attribution of a row to its source row; PREFER; masking.
*& Fictitious objects (prefix XX) and a field list built in the test - no
*& database, no DDIC. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
CLASS ltc_link_query DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        object    TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'XX_PAY_REQUEST',
        source    TYPE zif_ca_ops_link_types=>ty_source VALUE 'ZXX_PAY_REQ',
        link      TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'XX_ITEM_TO_REQ',
        req_ref   TYPE zif_ca_ops_link_types=>ty_field_ref VALUE 'ZXX_PAY_REQ-REQ_ID',
        feed_ref  TYPE zif_ca_ops_link_types=>ty_field_ref VALUE 'ZXX_PAY_REQ-FEEDER',
        stat_ref  TYPE zif_ca_ops_link_types=>ty_field_ref VALUE 'ZXX_PAY_REQ-STATUS',
        amt_ref   TYPE zif_ca_ops_link_types=>ty_field_ref VALUE 'ZXX_PAY_REQ-AMOUNT',
        item_ref  TYPE zif_ca_ops_link_types=>ty_field_ref VALUE 'DFKKOP-ZZXX_REQ_ID',
        item_feed TYPE zif_ca_ops_link_types=>ty_field_ref VALUE 'DFKKOP-ZZXX_FEEDER',
        other_ref TYPE zif_ca_ops_link_types=>ty_field_ref VALUE 'ZXX_OTHER-REQ_ID',
        req_id    TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'REQ_ID',
        feeder    TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'FEEDER',
        status    TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'STATUS',
        item_req  TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'ZZXX_REQ_ID',
        item_fdr  TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'ZZXX_FEEDER',
        first     TYPE zif_ca_ops_link_types=>ty_key_value VALUE 'R1',
        second    TYPE zif_ca_ops_link_types=>ty_key_value VALUE 'R2',
        quoted    TYPE zif_ca_ops_link_types=>ty_key_value VALUE `R'3`,
        web       TYPE zif_ca_ops_link_types=>ty_key_value VALUE 'WEB',
        success   TYPE zif_ca_ops_link_types=>ty_value VALUE 'OK',
        failed    TYPE zif_ca_ops_link_types=>ty_value VALUE 'FAIL',
      END OF gc.

    DATA mt_conds TYPE zif_ca_ops_link_types=>tt_cond.

    METHODS setup.
    METHODS target
      RETURNING
        VALUE(rs_target) TYPE zif_ca_ops_link_types=>ty_object.
    METHODS fields
      RETURNING
        VALUE(rt_fields) TYPE zif_ca_ops_chk_types=>tt_field.
    METHODS cond
      IMPORTING
        iv_no   TYPE i
        iv_kind TYPE zif_ca_ops_link_types=>ty_cond_kind
        iv_from TYPE zif_ca_ops_link_types=>ty_field_ref OPTIONAL
        iv_to   TYPE zif_ca_ops_link_types=>ty_field_ref
        iv_value TYPE zif_ca_ops_link_types=>ty_value OPTIONAL.
    METHODS source
      IMPORTING
        iv_req           TYPE zif_ca_ops_link_types=>ty_key_value
        iv_feeder        TYPE zif_ca_ops_link_types=>ty_key_value OPTIONAL
      RETURNING
        VALUE(rs_source) TYPE zif_ca_ops_link_types=>ty_row.
    METHODS build
      IMPORTING
        it_sources      TYPE zif_ca_ops_link_types=>tt_row
        iv_approved     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rs_query) TYPE zif_ca_ops_link_types=>ty_query
      RAISING
        zcx_ca_ops_error.

    METHODS one_eq_gives_in_list       FOR TESTING.
    METHODS blank_source_never_joins   FOR TESTING.
    METHODS no_join_value_reads_none   FOR TESTING.
    METHODS two_eq_give_or_groups      FOR TESTING.
    METHODS const_and_not_initial      FOR TESTING.
    METHODS quote_in_value_escaped     FOR TESTING.
    METHODS unapproved_refused         FOR TESTING.
    METHODS unknown_field_refused      FOR TESTING.
    METHODS other_source_ref_refused   FOR TESTING.
    METHODS numeric_needs_number       FOR TESTING.
    METHODS transforms_applied         FOR TESTING.
    METHODS bad_transform_arg_refused  FOR TESTING.
    METHODS row_belongs_to_its_source  FOR TESTING.
    METHODS prefer_keeps_preferred     FOR TESTING.
    METHODS prefer_keeps_all_otherwise FOR TESTING.
    METHODS mask_keeps_last_four       FOR TESTING.
ENDCLASS.


CLASS ltc_link_query IMPLEMENTATION.

  METHOD setup.
    CLEAR mt_conds.
  ENDMETHOD.


  METHOD target.
    rs_target-object_id   = gc-object.
    rs_target-source_name = gc-source.
    rs_target-source_kind = zif_ca_ops_link_types=>gc_source_kind-table.
    rs_target-key_fields  = gc-req_id.
    rs_target-active      = abap_true.
  ENDMETHOD.


  METHOD fields.
    INSERT VALUE #( fieldname = gc-req_id type_kind = cl_abap_typedescr=>typekind_char ) INTO TABLE rt_fields.
    INSERT VALUE #( fieldname = gc-feeder type_kind = cl_abap_typedescr=>typekind_char ) INTO TABLE rt_fields.
    INSERT VALUE #( fieldname = gc-status type_kind = cl_abap_typedescr=>typekind_char ) INTO TABLE rt_fields.
    INSERT VALUE #( fieldname = 'AMOUNT' type_kind = cl_abap_typedescr=>typekind_packed ) INTO TABLE rt_fields.
  ENDMETHOD.


  METHOD cond.
    DATA ls_cond TYPE zif_ca_ops_link_types=>ty_cond.
    ls_cond-link_id    = gc-link.
    ls_cond-cond_no    = iv_no.
    ls_cond-cond_kind  = iv_kind.
    ls_cond-from_ref   = iv_from.
    ls_cond-to_ref     = iv_to.
    ls_cond-cond_value = iv_value.
    INSERT ls_cond INTO TABLE mt_conds.
  ENDMETHOD.


  METHOD source.
    INSERT VALUE #( fieldname = gc-item_req value = iv_req ) INTO TABLE rs_source-pairs.
    INSERT VALUE #( fieldname = gc-item_fdr value = iv_feeder ) INTO TABLE rs_source-pairs.
  ENDMETHOD.


  METHOD build.
    rs_query = zcl_ca_ops_link_query=>build( iv_area     = gc-area
                                             is_target   = target( )
                                             it_conds    = mt_conds
                                             it_sources  = it_sources
                                             it_select   = VALUE #( ( gc-req_id ) )
                                             it_fields   = fields( )
                                             iv_approved = iv_approved ).
  ENDMETHOD.


  " Rule: one EQ condition reads the distinct values of all source rows in one IN list
  METHOD one_eq_gives_in_list.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref iv_to = gc-req_ref ).
        DATA(ls_query) = build( VALUE #( ( source( gc-first ) ) ( source( gc-second ) ) ( source( gc-first ) ) ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-where_clause
                                            exp = |REQ_ID IN ( 'R1', 'R2' )|
                                            msg = 'Distinct quoted values in one IN list' ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-source exp = gc-source msg = 'The target source' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a blank join value never joins (it would match every blank row)
  METHOD blank_source_never_joins.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref iv_to = gc-req_ref ).
        DATA(ls_query) = build( VALUE #( ( source( gc-first ) ) ( source( space ) ) ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-where_clause exp = |REQ_ID IN ( 'R1' )|
                                            msg = 'Only the filled value' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD no_join_value_reads_none.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref iv_to = gc-req_ref ).
        DATA(ls_query) = build( VALUE #( ( source( space ) ) ) ).
        cl_abap_unit_assert=>assert_initial( act = ls_query-where_clause msg = 'Nothing to read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: several EQ conditions are OR groups of AND pairs
  METHOD two_eq_give_or_groups.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref iv_to = gc-req_ref ).
        cond( iv_no = 2 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_feed iv_to = gc-feed_ref ).
        DATA(ls_query) = build( VALUE #( ( source( iv_req = gc-first iv_feeder = gc-web ) )
                                         ( source( iv_req = gc-second iv_feeder = space ) ) ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-where_clause
                                            exp = |( ( REQ_ID = 'R1' AND FEEDER = 'WEB' ) )|
                                            msg = 'One group; the row without a feeder joins nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD const_and_not_initial.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref iv_to = gc-req_ref ).
        cond( iv_no = 2 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-const iv_to = gc-stat_ref iv_value = 'OK,HOLD' ).
        cond( iv_no = 3 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-not_initial iv_to = gc-feed_ref ).
        DATA(ls_query) = build( VALUE #( ( source( gc-first ) ) ) ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_query-where_clause
          exp = |REQ_ID IN ( 'R1' ) AND STATUS IN ( 'OK', 'HOLD' ) AND FEEDER <> ' '|
          msg = 'Join, constant list and not-initial condition' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a quote of a value is escaped, never closes the literal
  METHOD quote_in_value_escaped.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref iv_to = gc-req_ref ).
        DATA(ls_query) = build( VALUE #( ( source( gc-quoted ) ) ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-where_clause exp = |REQ_ID IN ( 'R''3' )|
                                            msg = 'Quote doubled by CL_ABAP_DYN_PRG' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unapproved_refused.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref iv_to = gc-req_ref ).
        build( it_sources = VALUE #( ( source( gc-first ) ) ) iv_approved = abap_false ).
        cl_abap_unit_assert=>fail( msg = 'A source not approved for the area is never read' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '212'
                                            msg = 'Message 212' ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_field_refused.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref
              iv_to = 'ZXX_PAY_REQ-NO_SUCH' ).
        build( VALUE #( ( source( gc-first ) ) ) ).
        cl_abap_unit_assert=>fail( msg = 'A field the DDIC does not know is refused' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '213'
                                            msg = 'Message 213' ).
    ENDTRY.
  ENDMETHOD.


  METHOD other_source_ref_refused.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref iv_to = gc-other_ref ).
        build( VALUE #( ( source( gc-first ) ) ) ).
        cl_abap_unit_assert=>fail( msg = 'A reference of another source is refused' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '234'
                                            msg = 'Message 234' ).
    ENDTRY.
  ENDMETHOD.


  METHOD numeric_needs_number.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref iv_to = gc-req_ref ).
        cond( iv_no = 2 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-const iv_to = gc-amt_ref iv_value = 'ten' ).
        build( VALUE #( ( source( gc-first ) ) ) ).
        cl_abap_unit_assert=>fail( msg = 'A numeric field takes numbers only' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '227'
                                            msg = 'Message 227' ).
    ENDTRY.
  ENDMETHOD.


  METHOD transforms_applied.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>transform( iv_value = '123' iv_transform = 'ALPHA' iv_arg = '6' iv_link_id = gc-link )
          exp = `000123` msg = 'ALPHA adds leading zeros' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>transform( iv_value = '000123' iv_transform = 'NOZERO' iv_arg = space
                                                  iv_link_id = gc-link )
          exp = `123` msg = 'NOZERO removes them' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>transform( iv_value = 'ab' iv_transform = 'UPPER' iv_arg = space
                                                  iv_link_id = gc-link )
          exp = `AB` msg = 'UPPER' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>transform( iv_value = '1234567890123456' iv_transform = 'RIGHT' iv_arg = '13'
                                                  iv_link_id = gc-link )
          exp = `4567890123456` msg = 'RIGHT keeps the last characters' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>transform( iv_value = 'ABCDEF' iv_transform = 'LEFT' iv_arg = '2'
                                                  iv_link_id = gc-link )
          exp = `AB` msg = 'LEFT keeps the first characters' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>transform( iv_value = '42' iv_transform = 'PREFIX' iv_arg = 'X-'
                                                  iv_link_id = gc-link )
          exp = `X-42` msg = 'PREFIX' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>transform( iv_value = '42' iv_transform = 'SUFFIX' iv_arg = '/1'
                                                  iv_link_id = gc-link )
          exp = `42/1` msg = 'SUFFIX' ).
        cl_abap_unit_assert=>assert_initial(
          act = zcl_ca_ops_link_query=>transform( iv_value = space iv_transform = 'PREFIX' iv_arg = 'X-'
                                                  iv_link_id = gc-link )
          msg = 'A blank value stays blank (never joins)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD bad_transform_arg_refused.
    TRY.
        zcl_ca_ops_link_query=>transform( iv_value = '1' iv_transform = 'ALPHA' iv_arg = 'x' iv_link_id = gc-link ).
        cl_abap_unit_assert=>fail( msg = 'ALPHA needs a length' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '215'
                                            msg = 'Message 215' ).
    ENDTRY.
  ENDMETHOD.


  METHOD row_belongs_to_its_source.
    DATA ls_row TYPE zif_ca_ops_link_types=>ty_row.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-eq iv_from = gc-item_ref iv_to = gc-req_ref ).
        INSERT VALUE #( fieldname = gc-req_id value = gc-first ) INTO TABLE ls_row-pairs.
        cl_abap_unit_assert=>assert_true(
          act = zcl_ca_ops_link_query=>belongs_to( is_row = ls_row is_source = source( gc-first ) it_conds = mt_conds )
          msg = 'Same join value' ).
        cl_abap_unit_assert=>assert_false(
          act = zcl_ca_ops_link_query=>belongs_to( is_row = ls_row is_source = source( gc-second ) it_conds = mt_conds )
          msg = 'Other join value' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the accepted attempt is the row with the preferred status, never the highest counter
  METHOD prefer_keeps_preferred.
    DATA lt_rows TYPE zif_ca_ops_link_types=>tt_row.
    DATA ls_row TYPE zif_ca_ops_link_types=>ty_row.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-prefer iv_to = gc-stat_ref
              iv_value = gc-success ).
        INSERT VALUE #( fieldname = gc-status value = gc-success ) INTO TABLE ls_row-pairs.
        INSERT ls_row INTO TABLE lt_rows.
        CLEAR ls_row.
        INSERT VALUE #( fieldname = gc-status value = gc-failed ) INTO TABLE ls_row-pairs.
        INSERT ls_row INTO TABLE lt_rows.
        DATA(lt_kept) = zcl_ca_ops_link_query=>prefer( it_rows = lt_rows it_conds = mt_conds ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_kept ) exp = 1 msg = 'Only the preferred row' ).
        cl_abap_unit_assert=>assert_equals( act = lt_kept[ 1 ]-pairs[ 1 ]-value exp = gc-success
                                            msg = 'The accepted attempt' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD prefer_keeps_all_otherwise.
    DATA lt_rows TYPE zif_ca_ops_link_types=>tt_row.
    DATA ls_row TYPE zif_ca_ops_link_types=>ty_row.
    TRY.
        cond( iv_no = 1 iv_kind = zif_ca_ops_link_types=>gc_cond_kind-prefer iv_to = gc-stat_ref
              iv_value = gc-success ).
        INSERT VALUE #( fieldname = gc-status value = gc-failed ) INTO TABLE ls_row-pairs.
        INSERT ls_row INTO TABLE lt_rows.
        INSERT ls_row INTO TABLE lt_rows.
        cl_abap_unit_assert=>assert_equals( act = lines( zcl_ca_ops_link_query=>prefer( it_rows  = lt_rows
                                                                                        it_conds = mt_conds ) )
                                            exp = 2 msg = 'No preferred row: every row stays visible' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD mask_keeps_last_four.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>mask( iv_value = '1234567890' iv_sensitivity = 'M' )
          exp = '******7890' msg = 'Masked: last four visible' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>mask( iv_value = '123' iv_sensitivity = 'M' )
          exp = '***' msg = 'A short value is masked completely' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>mask( iv_value = '1234567890' iv_sensitivity = 'H' )
          exp = '**********' msg = 'Hidden: nothing visible' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_link_query=>mask( iv_value = 'ABC' iv_sensitivity = space )
          exp = 'ABC' msg = 'Not sensitive: unchanged' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
