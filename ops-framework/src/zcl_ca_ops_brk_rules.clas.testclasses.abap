*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_rules.clas.testclasses.abap
*& Purpose:
*& Pure tests of the break analysis rules: which rules apply (area or *,
*& active, account pattern, invalid bucket / operator / link left out with
*& a problem, blank @ parameter reported), comparisons (numbers, lists,
*& PCRE, blank list never matches), and the classification: first match
*& wins in sequence order, a group cleared by lines after the key date
*& (timing), day windows (last days of the month), linked rows (exists with
*& a minimum count, none exists), group bucket = that of its oldest open
*& line, OTHER when nothing explains, explained flag of the bucket, later
*& lines kept as context. No doubles; does not prove live SAP runtime
*& behavior.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
CLASS ltc_brk_rules DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        acct     TYPE zif_ca_ops_brk_types=>ty_acct_id VALUE 'ZT_CLEARING',
        key_date TYPE d VALUE '20261031',
        link     TYPE zif_ca_ops_link_types=>ty_link_id VALUE 'ZT_ITEM_TO_LINE',
        timing   TYPE zif_ca_ops_brk_types=>ty_bucket VALUE 'TIMING',
        new_code TYPE zif_ca_ops_brk_types=>ty_bucket VALUE 'NEW_BTC',
        redep    TYPE zif_ca_ops_brk_types=>ty_bucket VALUE 'REDEPOSIT_NO_LOT',
      END OF gc.

    DATA mt_rules TYPE zif_ca_ops_brk_types=>tt_rule.
    DATA mt_conds TYPE zif_ca_ops_brk_types=>tt_cond.
    DATA mt_buckets TYPE zif_ca_ops_brk_types=>tt_bucket.
    DATA mt_params TYPE zif_ca_ops_brk_types=>tt_param_list.
    DATA mt_links TYPE zif_ca_ops_link_types=>tt_link_id.

    METHODS setup.
    METHODS add_rule
      IMPORTING
        iv_rule_id TYPE zif_ca_ops_brk_types=>ty_rule_id
        iv_seq     TYPE i
        iv_bucket  TYPE zif_ca_ops_brk_types=>ty_bucket
        iv_area    TYPE zif_ca_ops_types=>ty_area DEFAULT zif_ca_ops_brk_types=>gc_area_any.
    METHODS add_cond
      IMPORTING
        iv_rule_id   TYPE zif_ca_ops_brk_types=>ty_rule_id
        iv_kind      TYPE zif_ca_ops_brk_types=>ty_cond_kind
        iv_field     TYPE zif_ca_ops_brk_types=>ty_field OPTIONAL
        iv_op        TYPE zif_ca_ops_brk_types=>ty_operator
        iv_value     TYPE zif_ca_ops_brk_types=>ty_value OPTIONAL
        iv_link_id   TYPE zif_ca_ops_link_types=>ty_link_id OPTIONAL
        iv_min_count TYPE i OPTIONAL
        iv_area      TYPE zif_ca_ops_types=>ty_area DEFAULT zif_ca_ops_brk_types=>gc_area_any.
    METHODS line
      IMPORTING
        iv_assignment  TYPE zif_ca_ops_brk_types=>ty_assignment
        iv_docln       TYPE zif_ca_ops_brk_types=>ty_docln
        iv_date        TYPE d
        iv_amount      TYPE zif_ca_ops_types=>ty_amount
        iv_later       TYPE abap_bool DEFAULT abap_false
        iv_doc_type    TYPE zif_ca_ops_brk_types=>ty_item-doc_type DEFAULT 'SA'
      RETURNING
        VALUE(rs_item) TYPE zif_ca_ops_brk_types=>ty_item.
    METHODS run
      IMPORTING
        it_sums   TYPE zif_ca_ops_brk_types=>tt_group_sum
        it_items  TYPE zif_ca_ops_brk_types=>tt_item
        it_hits   TYPE zif_ca_ops_brk_types=>tt_hit OPTIONAL
      EXPORTING
        et_groups TYPE zif_ca_ops_brk_types=>tt_group
        et_items  TYPE zif_ca_ops_brk_types=>tt_item_result.

    METHODS rules_of_area_and_any       FOR TESTING.
    METHODS invalid_rule_left_out       FOR TESTING.
    METHODS blank_parameter_reported    FOR TESTING.
    METHODS compare_numbers_and_lists   FOR TESTING.
    METHODS cleared_later_is_timing     FOR TESTING.
    METHODS first_match_wins            FOR TESTING.
    METHODS unexplained_is_other        FOR TESTING.
    METHODS link_exists_with_count      FOR TESTING.
    METHODS link_none_exists            FOR TESTING.
    METHODS month_end_day_window        FOR TESTING.
ENDCLASS.


CLASS ltc_brk_rules IMPLEMENTATION.

  METHOD setup.
    CLEAR: mt_rules, mt_conds, mt_buckets, mt_params.
    mt_buckets = VALUE #( ( bucket = gc-timing explained = abap_true active = abap_true )
                          ( bucket = gc-new_code explained = abap_true active = abap_true )
                          ( bucket = gc-redep explained = abap_true active = abap_true )
                          ( bucket = zif_ca_ops_brk_types=>gc_bucket_other active = abap_true ) ).
    mt_links = VALUE #( ( gc-link ) ).
    mt_params = VALUE #( ( name = 'ZT_BTC_NEW' values = VALUE #( ( `143` ) ( `452` ) ) )
                         ( name = 'ZT_EMPTY' ) ).
  ENDMETHOD.


  METHOD add_rule.
    INSERT VALUE #( area = iv_area rule_id = iv_rule_id seq = iv_seq bucket = iv_bucket active = abap_true
                    reason = 'Explained' ) INTO TABLE mt_rules.
  ENDMETHOD.


  METHOD add_cond.
    DATA(lv_no) = REDUCE i( INIT n = 0 FOR ls IN mt_conds WHERE ( rule_id = iv_rule_id ) NEXT n = n + 1 ) + 1.
    INSERT VALUE #( area = iv_area rule_id = iv_rule_id cond_no = lv_no cond_kind = iv_kind field = iv_field
                    operator = iv_op cond_value = iv_value link_id = iv_link_id min_count = iv_min_count )
           INTO TABLE mt_conds.
  ENDMETHOD.


  METHOD line.
    rs_item-ledger        = '0L'.
    rs_item-bukrs         = 'ZT01'.
    rs_item-gjahr         = '2026'.
    rs_item-belnr         = '0100000001'.
    rs_item-docln         = iv_docln.
    rs_item-assignment    = iv_assignment.
    rs_item-currency      = 'USD'.
    rs_item-amount        = iv_amount.
    rs_item-posting_date  = iv_date.
    rs_item-doc_type      = iv_doc_type.
    rs_item-debit_credit  = COND #( WHEN iv_amount >= 0 THEN zif_ca_ops_brk_types=>gc_debit ELSE 'H' ).
    rs_item-later         = iv_later.
  ENDMETHOD.


  METHOD run.
    zcl_ca_ops_brk_rules=>effective_rules( EXPORTING it_rules    = mt_rules
                                                     it_conds    = mt_conds
                                                     it_buckets  = mt_buckets
                                                     it_links    = mt_links
                                                     it_params   = mt_params
                                                     iv_area     = gc-area
                                                     iv_acct_id  = gc-acct
                                           IMPORTING et_rules    = DATA(lt_rules)
                                                     et_conds    = DATA(lt_conds) ).
    zcl_ca_ops_brk_rules=>classify( EXPORTING is_context = VALUE #( acct_id = gc-acct key_date = gc-key_date )
                                              it_sums    = it_sums
                                              it_items   = it_items
                                              it_rules   = lt_rules
                                              it_conds   = lt_conds
                                              it_hits    = it_hits
                                              it_params  = mt_params
                                              it_buckets = mt_buckets
                                    IMPORTING et_groups  = et_groups
                                              et_items   = et_items ).
  ENDMETHOD.


  " Rule: rules of the account's area and of every area (*) apply; inactive ones and other accounts' do not
  METHOD rules_of_area_and_any.
    TRY.
        add_rule( iv_rule_id = 'R_ANY' iv_seq = 10 iv_bucket = gc-timing ).
        add_rule( iv_rule_id = 'R_AREA' iv_seq = 20 iv_bucket = gc-timing iv_area = gc-area ).
        add_rule( iv_rule_id = 'R_OTHER_AREA' iv_seq = 30 iv_bucket = gc-timing iv_area = 'ZT_OPS_B' ).
        add_rule( iv_rule_id = 'R_OFF' iv_seq = 40 iv_bucket = gc-timing ).
        mt_rules[ rule_id = 'R_OFF' ]-active = abap_false.
        add_rule( iv_rule_id = 'R_PATTERN' iv_seq = 50 iv_bucket = gc-timing ).
        mt_rules[ rule_id = 'R_PATTERN' ]-acct_pattern = 'ZT_OTHER.*'.
        zcl_ca_ops_brk_rules=>effective_rules( EXPORTING it_rules    = mt_rules
                                                         it_conds    = mt_conds
                                                         it_buckets  = mt_buckets
                                                         it_links    = mt_links
                                                         it_params   = mt_params
                                                         iv_area     = gc-area
                                                         iv_acct_id  = gc-acct
                                               IMPORTING et_rules    = DATA(lt_rules) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rules ) exp = 2 msg = 'Area and * rules only' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rules[ 1 ]-rule_id exp = 'R_ANY' msg = 'In sequence order' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an unknown bucket, an operator of another kind or a link not effective takes the rule out (problem)
  METHOD invalid_rule_left_out.
    TRY.
        add_rule( iv_rule_id = 'R_BUCKET' iv_seq = 10 iv_bucket = 'NO_SUCH' ).
        add_rule( iv_rule_id = 'R_OP' iv_seq = 20 iv_bucket = gc-timing ).
        add_cond( iv_rule_id = 'R_OP' iv_kind = zif_ca_ops_brk_types=>gc_kind-field
                  iv_field = zif_ca_ops_brk_types=>gc_field-doc_type iv_op = zif_ca_ops_brk_types=>gc_op-ex ).
        add_rule( iv_rule_id = 'R_LINK' iv_seq = 30 iv_bucket = gc-timing ).
        add_cond( iv_rule_id = 'R_LINK' iv_kind = zif_ca_ops_brk_types=>gc_kind-link
                  iv_op = zif_ca_ops_brk_types=>gc_op-ex iv_link_id = 'NOT_EFFECTIVE' ).
        add_rule( iv_rule_id = 'R_FIELD' iv_seq = 40 iv_bucket = gc-timing ).
        add_cond( iv_rule_id = 'R_FIELD' iv_kind = zif_ca_ops_brk_types=>gc_kind-group
                  iv_field = 'NO_SUCH_FIELD' iv_op = zif_ca_ops_brk_types=>gc_op-eq iv_value = '1' ).
        zcl_ca_ops_brk_rules=>effective_rules( EXPORTING it_rules    = mt_rules
                                                         it_conds    = mt_conds
                                                         it_buckets  = mt_buckets
                                                         it_links    = mt_links
                                                         it_params   = mt_params
                                                         iv_area     = gc-area
                                                         iv_acct_id  = gc-acct
                                               IMPORTING et_rules    = DATA(lt_rules)
                                                         et_problems = DATA(lt_problems) ).
        cl_abap_unit_assert=>assert_initial( act = lt_rules msg = 'Every invalid rule left out' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( lt_problems[ msgno = zif_ca_ops_brk_types=>gc_msg-bucket_unknown ] )
                     AND line_exists( lt_problems[ msgno = zif_ca_ops_brk_types=>gc_msg-op_invalid ] )
                     AND line_exists( lt_problems[ msgno = zif_ca_ops_brk_types=>gc_msg-link_unknown ] )
                     AND line_exists( lt_problems[ msgno = zif_ca_ops_brk_types=>gc_msg-field_unknown ] ) )
          msg = 'One problem per kind' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a blank @ parameter keeps the rule (reported) but it explains nothing
  METHOD blank_parameter_reported.
    TRY.
        add_rule( iv_rule_id = 'R_EMPTY' iv_seq = 10 iv_bucket = gc-timing ).
        add_cond( iv_rule_id = 'R_EMPTY' iv_kind = zif_ca_ops_brk_types=>gc_kind-field
                  iv_field = zif_ca_ops_brk_types=>gc_field-doc_type iv_op = zif_ca_ops_brk_types=>gc_op-in
                  iv_value = '@ZT_EMPTY' ).
        zcl_ca_ops_brk_rules=>effective_rules( EXPORTING it_rules    = mt_rules
                                                         it_conds    = mt_conds
                                                         it_buckets  = mt_buckets
                                                         it_links    = mt_links
                                                         it_params   = mt_params
                                                         iv_area     = gc-area
                                                         iv_acct_id  = gc-acct
                                               IMPORTING et_rules    = DATA(lt_rules)
                                                         et_problems = DATA(lt_problems) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rules ) exp = 1 msg = 'Rule kept' ).
        cl_abap_unit_assert=>assert_equals( act = lt_problems[ 1 ]-msgno exp = zif_ca_ops_brk_types=>gc_msg-param_blank
                                            msg = 'Blank parameter reported' ).
        run( EXPORTING it_sums   = VALUE #( ( assignment = 'A1' currency = 'USD' amount = 10 line_count = 1
                                              first_date = gc-key_date ) )
                       it_items  = VALUE #( ( line( iv_assignment = 'A1' iv_docln = '000001' iv_date = gc-key_date
                                                    iv_amount = 10 ) ) )
             IMPORTING et_groups = DATA(lt_groups) ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-bucket exp = zif_ca_ops_brk_types=>gc_bucket_other
                                            msg = 'Blank list explains nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: numbers compared as numbers, lists by element, PCRE on the complete value, blank list never holds
  METHOD compare_numbers_and_lists.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_brk_rules=>compare(
                                                  iv_actual = '10' iv_operator = zif_ca_ops_brk_types=>gc_op-ge
                                                  it_values = VALUE #( ( `9` ) ) ) msg = '10 >= 9 as numbers' ).
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_brk_rules=>compare(
                                                  iv_actual = '452' iv_operator = zif_ca_ops_brk_types=>gc_op-in
                                                  it_values = VALUE #( ( `143` ) ( `452` ) ) ) msg = 'In the list' ).
        cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_brk_rules=>compare(
                                                   iv_actual = '165' iv_operator = zif_ca_ops_brk_types=>gc_op-in
                                                   it_values = VALUE #( ) ) msg = 'Blank list never holds' ).
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_brk_rules=>compare(
                                                  iv_actual = 'DZ' iv_operator = zif_ca_ops_brk_types=>gc_op-rx
                                                  it_values = VALUE #( ( `D.` ) ) ) msg = 'PCRE complete value' ).
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_brk_rules=>compare(
                                                  iv_actual = '' iv_operator = zif_ca_ops_brk_types=>gc_op-bl
                                                  it_values = VALUE #( ) ) msg = 'Blank without values' ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( zcl_ca_ops_brk_rules=>values_of( iv_value = '143, 452 ,' iv_operator = zif_ca_ops_brk_types=>gc_op-in
                                                         it_params = mt_params ) )
          exp = 2 msg = 'Comma list, blanks dropped' ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( zcl_ca_ops_brk_rules=>values_of( iv_value = '@zt_btc_new' iv_operator = zif_ca_ops_brk_types=>gc_op-in
                                                         it_params = mt_params ) )
          exp = 2 msg = 'Parameter list' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a group that lines after the key date bring to zero within the window is timing; later lines are context
  METHOD cleared_later_is_timing.
    TRY.
        add_rule( iv_rule_id = 'R_TIMING' iv_seq = 10 iv_bucket = gc-timing ).
        add_cond( iv_rule_id = 'R_TIMING' iv_kind = zif_ca_ops_brk_types=>gc_kind-group
                  iv_field = zif_ca_ops_brk_types=>gc_group-clears_later iv_op = zif_ca_ops_brk_types=>gc_op-eq
                  iv_value = 'X' ).
        add_cond( iv_rule_id = 'R_TIMING' iv_kind = zif_ca_ops_brk_types=>gc_kind-group
                  iv_field = zif_ca_ops_brk_types=>gc_group-days_to_clear iv_op = zif_ca_ops_brk_types=>gc_op-le
                  iv_value = '3' ).
        run( EXPORTING it_sums   = VALUE #( ( assignment = 'A1' currency = 'USD' amount = 100 line_count = 1
                                              first_date = '20261030' ) )
                       it_items  = VALUE #( ( line( iv_assignment = 'A1' iv_docln = '000001' iv_date = '20261030'
                                                    iv_amount = 100 ) )
                                            ( line( iv_assignment = 'A1' iv_docln = '000002' iv_date = '20261102'
                                                    iv_amount = -100 iv_later = abap_true ) ) )
             IMPORTING et_groups = DATA(lt_groups)
                       et_items  = DATA(lt_items) ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-bucket exp = gc-timing msg = 'Timing' ).
        cl_abap_unit_assert=>assert_true( act = lt_groups[ 1 ]-clears_later msg = 'Cleared later' ).
        cl_abap_unit_assert=>assert_true( act = lt_groups[ 1 ]-explained msg = 'Explained bucket' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-later_date exp = '20261102' msg = 'Clearing date' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-age_days exp = 1 msg = 'Age at the key date' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lt_groups[ 1 ]-reason CS 'R_TIMING' ) msg = 'Reason names the rule' ).
        cl_abap_unit_assert=>assert_true( act = lt_items[ 2 ]-item-later msg = 'Later line kept as context' ).
        cl_abap_unit_assert=>assert_initial( act = lt_items[ 2 ]-bucket msg = 'Later line not classified' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the first rule in sequence order whose conditions all hold explains the line
  METHOD first_match_wins.
    TRY.
        add_rule( iv_rule_id = 'R_LATE' iv_seq = 90 iv_bucket = gc-timing ).
        add_rule( iv_rule_id = 'R_EARLY' iv_seq = 10 iv_bucket = gc-new_code ).
        add_cond( iv_rule_id = 'R_EARLY' iv_kind = zif_ca_ops_brk_types=>gc_kind-field
                  iv_field = zif_ca_ops_brk_types=>gc_field-doc_type iv_op = zif_ca_ops_brk_types=>gc_op-in
                  iv_value = 'ZB,ZR' ).
        run( EXPORTING it_sums   = VALUE #( ( assignment = 'A1' currency = 'USD' amount = 5 line_count = 1
                                              first_date = gc-key_date ) )
                       it_items  = VALUE #( ( line( iv_assignment = 'A1' iv_docln = '000001' iv_date = gc-key_date
                                                    iv_amount = 5 iv_doc_type = 'ZB' ) ) )
             IMPORTING et_groups = DATA(lt_groups)
                       et_items  = DATA(lt_items) ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-rule_id exp = 'R_EARLY' msg = 'Lower sequence first' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-bucket exp = gc-new_code msg = 'Group bucket' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a group no rule explains is OTHER and not explained; currencies are separate groups
  METHOD unexplained_is_other.
    TRY.
        add_rule( iv_rule_id = 'R_NEVER' iv_seq = 10 iv_bucket = gc-timing ).
        add_cond( iv_rule_id = 'R_NEVER' iv_kind = zif_ca_ops_brk_types=>gc_kind-group
                  iv_field = zif_ca_ops_brk_types=>gc_group-lines iv_op = zif_ca_ops_brk_types=>gc_op-ge
                  iv_value = '5' ).
        DATA(ls_eur) = line( iv_assignment = 'A1' iv_docln = '000002' iv_date = gc-key_date iv_amount = 7 ).
        ls_eur-currency = 'EUR'.
        run( EXPORTING it_sums   = VALUE #( ( assignment = 'A1' currency = 'USD' amount = 5 line_count = 1
                                              first_date = gc-key_date )
                                            ( assignment = 'A1' currency = 'EUR' amount = 7 line_count = 1
                                              first_date = gc-key_date ) )
                       it_items  = VALUE #( ( line( iv_assignment = 'A1' iv_docln = '000001' iv_date = gc-key_date
                                                    iv_amount = 5 ) )
                                            ( ls_eur ) )
             IMPORTING et_groups = DATA(lt_groups)
                       et_items  = DATA(lt_items) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_groups ) exp = 2 msg = 'One group per currency' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-bucket exp = zif_ca_ops_brk_types=>gc_bucket_other
                                            msg = 'OTHER' ).
        cl_abap_unit_assert=>assert_false( act = lt_groups[ 1 ]-explained msg = 'Not explained' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 2 msg = 'Each line in its own group' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 2 ]-group_no exp = 2 msg = 'EUR line in the EUR group' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: LINK EX holds with at least MIN_COUNT linked rows of the listed values; the row is the evidence
  METHOD link_exists_with_count.
    TRY.
        add_rule( iv_rule_id = 'R_NEW_BTC' iv_seq = 10 iv_bucket = gc-new_code ).
        add_cond( iv_rule_id = 'R_NEW_BTC' iv_kind = zif_ca_ops_brk_types=>gc_kind-link iv_field = 'VGEXT'
                  iv_op = zif_ca_ops_brk_types=>gc_op-ex iv_value = '@ZT_BTC_NEW' iv_link_id = gc-link
                  iv_min_count = 2 ).
        DATA(ls_line) = line( iv_assignment = 'A1' iv_docln = '000001' iv_date = gc-key_date iv_amount = 5 ).
        DATA(lv_key) = zcl_ca_ops_brk_rules=>line_key( ls_line ).
        DATA(lt_one) = VALUE zif_ca_ops_brk_types=>tt_hit(
                         ( link_id = gc-link line_key = lv_key object_id = 'ZT_LINE' row_key = 'K1'
                           pairs = VALUE #( ( fieldname = 'VGEXT' value = '452' ) ) ) ).
        run( EXPORTING it_sums   = VALUE #( ( assignment = 'A1' currency = 'USD' amount = 5 line_count = 1
                                              first_date = gc-key_date ) )
                       it_items  = VALUE #( ( ls_line ) )
                       it_hits   = lt_one
             IMPORTING et_items  = DATA(lt_items) ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-bucket exp = zif_ca_ops_brk_types=>gc_bucket_other
                                            msg = 'One row of two needed' ).
        INSERT VALUE #( link_id = gc-link line_key = lv_key object_id = 'ZT_LINE' row_key = 'K2'
                        pairs = VALUE #( ( fieldname = 'VGEXT' value = '143' ) ) ) INTO TABLE lt_one.
        run( EXPORTING it_sums   = VALUE #( ( assignment = 'A1' currency = 'USD' amount = 5 line_count = 1
                                              first_date = gc-key_date ) )
                       it_items  = VALUE #( ( ls_line ) )
                       it_hits   = lt_one
             IMPORTING et_items  = lt_items ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-bucket exp = gc-new_code msg = 'Two rows: explained' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-link_object exp = 'ZT_LINE' msg = 'Evidence object' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-link_value exp = '452' msg = 'Evidence value' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: LINK NX holds when no linked row exists (e.g. a redeposit without a returns lot)
  METHOD link_none_exists.
    TRY.
        add_rule( iv_rule_id = 'R_NO_LOT' iv_seq = 10 iv_bucket = gc-redep ).
        add_cond( iv_rule_id = 'R_NO_LOT' iv_kind = zif_ca_ops_brk_types=>gc_kind-link
                  iv_op = zif_ca_ops_brk_types=>gc_op-nx iv_link_id = gc-link ).
        DATA(ls_line) = line( iv_assignment = 'A1' iv_docln = '000001' iv_date = gc-key_date iv_amount = 5 ).
        run( EXPORTING it_sums   = VALUE #( ( assignment = 'A1' currency = 'USD' amount = 5 line_count = 1
                                              first_date = gc-key_date ) )
                       it_items  = VALUE #( ( ls_line ) )
             IMPORTING et_items  = DATA(lt_items) ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-bucket exp = gc-redep msg = 'No linked row' ).
        run( EXPORTING it_sums   = VALUE #( ( assignment = 'A1' currency = 'USD' amount = 5 line_count = 1
                                              first_date = gc-key_date ) )
                       it_items  = VALUE #( ( ls_line ) )
                       it_hits   = VALUE #( ( link_id = gc-link line_key = zcl_ca_ops_brk_rules=>line_key( ls_line )
                                              object_id = 'ZT_LOT' row_key = 'L1' ) )
             IMPORTING et_items  = lt_items ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-bucket exp = zif_ca_ops_brk_types=>gc_bucket_other
                                            msg = 'A linked row exists' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PERIOD_END = days from the posting date to the end of its month (31 October -> 0, 29 October -> 2)
  METHOD month_end_day_window.
    TRY.
        add_rule( iv_rule_id = 'R_EOM' iv_seq = 10 iv_bucket = gc-timing ).
        add_cond( iv_rule_id = 'R_EOM' iv_kind = zif_ca_ops_brk_types=>gc_kind-days
                  iv_field = zif_ca_ops_brk_types=>gc_days-period_end iv_op = zif_ca_ops_brk_types=>gc_op-le
                  iv_value = '1' ).
        run( EXPORTING it_sums   = VALUE #( ( assignment = 'A1' currency = 'USD' amount = 5 line_count = 1
                                              first_date = '20261031' )
                                            ( assignment = 'A2' currency = 'USD' amount = 5 line_count = 1
                                              first_date = '20261029' ) )
                       it_items  = VALUE #( ( line( iv_assignment = 'A1' iv_docln = '000001' iv_date = '20261031'
                                                    iv_amount = 5 ) )
                                            ( line( iv_assignment = 'A2' iv_docln = '000002' iv_date = '20261029'
                                                    iv_amount = 5 ) ) )
             IMPORTING et_groups = DATA(lt_groups) ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-bucket exp = gc-timing msg = 'Last day of the month' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 2 ]-bucket exp = zif_ca_ops_brk_types=>gc_bucket_other
                                            msg = 'Two days before the end' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
