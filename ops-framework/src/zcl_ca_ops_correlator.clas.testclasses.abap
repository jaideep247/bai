*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_correlator.clas.testclasses.abap
*& Purpose:
*& Domain tests of the alert correlation (pure logic on finding rows built
*& field by field): the key builder (field list, capture group, complete value,
*& unknown field, blank fields), the hashed key with the company code, which
*& rows are candidates, parent and children within the window (stored parent
*& and earlier row of the same batch), a new parent after the window. Does not
*& prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: alert correlation).
*&---------------------------------------------------------------------*
CLASS ltc_correlator DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        rule      TYPE zif_ca_ops_resp_types=>ty_corr_rule VALUE 'ZT_BANK',
        check     TYPE zif_ca_ops_types=>ty_check_code VALUE 'NO_BANK_ACK',
        file_a    TYPE zif_ca_ops_types=>ty_object_key VALUE 'BANK_A/FILE_0001',
        file_b    TYPE zif_ca_ops_types=>ty_object_key VALUE 'BANK_A/FILE_0002',
        file_c    TYPE zif_ca_ops_types=>ty_object_key VALUE 'BANK_C/FILE_0003',
        bank_capt TYPE zif_ca_ops_resp_types=>ty_long_pattern VALUE '([A-Z_]+)/.*',
        now       TYPE timestampl VALUE '20261111100000.0000000',
        recent    TYPE timestampl VALUE '20261111094000.0000000',
        old       TYPE timestampl VALUE '20261111080000.0000000',
        window    TYPE i VALUE 30,
        stored    TYPE zif_ca_ops_resp_types=>ty_uuid VALUE '000000000000000000000000000000E1',
        bukrs     TYPE bukrs VALUE 'ZT01',
      END OF gc.

    METHODS rule
      RETURNING
        VALUE(rs_rule) TYPE zif_ca_ops_resp_types=>ty_corr_rule_row.
    METHODS row
      IMPORTING
        iv_object_key TYPE zif_ca_ops_types=>ty_object_key
      RETURNING
        VALUE(rs_row) TYPE zca_ops_finding.
    METHODS correlate
      IMPORTING
        it_parents     TYPE zif_ca_ops_resp_types=>tt_corr_parent OPTIONAL
      CHANGING
        ct_rows        TYPE zcl_ca_ops_correlator=>tt_db_finding.

    METHODS key_from_field_list         FOR TESTING.
    METHODS key_from_capture_group      FOR TESTING.
    METHODS no_match_no_key             FOR TESTING.
    METHODS unknown_field_no_key        FOR TESTING.
    METHODS company_code_in_the_hash    FOR TESTING.
    METHODS only_new_open_exceptions    FOR TESTING.
    METHODS first_of_batch_is_parent    FOR TESTING.
    METHODS stored_parent_in_window     FOR TESTING.
    METHODS after_window_new_parent     FOR TESTING.
ENDCLASS.


CLASS ltc_correlator IMPLEMENTATION.

  METHOD rule.
    rs_rule-area          = gc-area.
    rs_rule-corr_rule     = gc-rule.
    rs_rule-check_pattern = 'NO_BANK_.*'.
    rs_rule-key_fields    = 'OBJECT_KEY'.
    rs_rule-key_pattern   = gc-bank_capt.
    rs_rule-window_min    = gc-window.
  ENDMETHOD.


  METHOD row.
    rs_row-area        = gc-area.
    rs_row-object_type = 'FILE'.
    rs_row-object_key  = iv_object_key.
    rs_row-check_code  = gc-check.
    rs_row-severity    = zif_ca_ops_types=>gc_severity-error.
    rs_row-disposition = zif_ca_ops_types=>gc_disposition-open.
  ENDMETHOD.


  METHOD correlate.
    DATA(lt_items) = zcl_ca_ops_correlator=>select( it_rules = VALUE #( ( rule( ) ) ) it_rows = ct_rows ).
    TRY.
        zcl_ca_ops_correlator=>assign( EXPORTING it_items   = lt_items
                                                 it_parents = it_parents
                                                 iv_now     = gc-now
                                       CHANGING  ct_rows    = ct_rows ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the key is the listed finding fields joined with '|', in the order of the list
  METHOD key_from_field_list.
    DATA(ls_rule) = rule( ).
    ls_rule-key_fields = 'check_code, OBJECT_TYPE'.
    CLEAR ls_rule-key_pattern.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_correlator=>key( is_rule = ls_rule is_row = row( gc-file_a ) )
                                        exp = `NO_BANK_ACK|FILE`
                                        msg = 'Fields in list order, any case' ).
  ENDMETHOD.


  " Rule: with a key pattern the key is its first capture group on the complete value
  METHOD key_from_capture_group.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_correlator=>key( is_rule = rule( ) is_row = row( gc-file_a ) )
                                        exp = `BANK_A`
                                        msg = 'The bank of the file is the key' ).
  ENDMETHOD.


  " Rule: a key pattern that does not match the complete value correlates nothing
  METHOD no_match_no_key.
    DATA(ls_rule) = rule( ).
    ls_rule-key_pattern = '([A-Z]+)'.
    cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_correlator=>key( is_rule = ls_rule is_row = row( gc-file_a ) )
                                         msg = 'A partial match is no match' ).
  ENDMETHOD.


  " Rule: an unknown key field never correlates; all key fields blank neither
  METHOD unknown_field_no_key.
    DATA(ls_rule) = rule( ).
    ls_rule-key_fields = 'OBJECT_KEY,AMOUNT'.
    cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_correlator=>key( is_rule = ls_rule is_row = row( gc-file_a ) )
                                         msg = 'AMOUNT is not a key field' ).
    ls_rule-key_fields = 'GROUP1,GROUP2'.
    CLEAR ls_rule-key_pattern.
    cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_correlator=>key( is_rule = ls_rule is_row = row( gc-file_a ) )
                                         msg = 'Blank key fields give no key' ).
  ENDMETHOD.


  " Rule: the company code is part of the hashed key - two company codes never share a parent
  METHOD company_code_in_the_hash.
    cl_abap_unit_assert=>assert_differs(
        act = zcl_ca_ops_correlator=>hash( iv_area = gc-area iv_rule = gc-rule iv_bukrs = space iv_key = `BANK_A` )
        exp = zcl_ca_ops_correlator=>hash( iv_area = gc-area iv_rule = gc-rule iv_bukrs = gc-bukrs iv_key = `BANK_A` )
        msg = 'Another company code is another key' ).
  ENDMETHOD.


  " Rule: only new open exceptions (B / E / W, not inherited) are correlated
  METHOD only_new_open_exceptions.
    DATA(lt_rows) = VALUE zcl_ca_ops_correlator=>tt_db_finding( ( row( gc-file_a ) ) ( row( gc-file_b ) ) ( row( gc-file_c ) ) ).
    lt_rows[ 2 ]-severity    = zif_ca_ops_types=>gc_severity-info.
    lt_rows[ 2 ]-disposition = zif_ca_ops_types=>gc_disposition-information.
    lt_rows[ 3 ]-corr_id     = gc-stored.
    DATA(lt_items) = zcl_ca_ops_correlator=>select( it_rules = VALUE #( ( rule( ) ) ) it_rows = lt_rows ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 1 msg = 'Information and inherited rows are left' ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-index exp = 1 msg = 'The new open exception' ).
  ENDMETHOD.


  " Rule: the first exception of a key in the batch is the parent, later ones of the key its children;
  " another key is a parent of its own
  METHOD first_of_batch_is_parent.
    DATA(lt_rows) = VALUE zcl_ca_ops_correlator=>tt_db_finding( ( row( gc-file_a ) ) ( row( gc-file_b ) ) ( row( gc-file_c ) ) ).
    correlate( CHANGING ct_rows = lt_rows ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-corr_role exp = zif_ca_ops_resp_types=>gc_corr_role-parent
                                        msg = 'The first file of bank A is the parent' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-corr_role exp = zif_ca_ops_resp_types=>gc_corr_role-child
                                        msg = 'The second file of bank A is a child' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-corr_id exp = lt_rows[ 1 ]-corr_id
                                        msg = 'The child carries the parent group' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-corr_role exp = zif_ca_ops_resp_types=>gc_corr_role-parent
                                        msg = 'Bank C is a parent of its own' ).
    cl_abap_unit_assert=>assert_differs( act = lt_rows[ 3 ]-corr_id exp = lt_rows[ 1 ]-corr_id
                                         msg = 'Two keys, two groups' ).
  ENDMETHOD.


  " Rule: an open parent stored earlier whose window still runs makes the new exception its child
  METHOD stored_parent_in_window.
    DATA(lt_rows) = VALUE zcl_ca_ops_correlator=>tt_db_finding( ( row( gc-file_b ) ) ).
    DATA(lv_key) = zcl_ca_ops_correlator=>hash( iv_area = gc-area iv_rule = gc-rule iv_bukrs = space iv_key = `BANK_A` ).
    correlate( EXPORTING it_parents = VALUE #( ( corr_key = lv_key corr_id = gc-stored first_seen_at = gc-recent ) )
               CHANGING  ct_rows    = lt_rows ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-corr_id exp = gc-stored msg = 'Child of the stored parent' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-corr_role exp = zif_ca_ops_resp_types=>gc_corr_role-child
                                        msg = 'Role child' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-corr_key exp = lv_key msg = 'The key is kept' ).
  ENDMETHOD.


  " Rule: after the parent's window a new exception of the key is a new parent
  METHOD after_window_new_parent.
    DATA(lt_rows) = VALUE zcl_ca_ops_correlator=>tt_db_finding( ( row( gc-file_b ) ) ).
    DATA(lv_key) = zcl_ca_ops_correlator=>hash( iv_area = gc-area iv_rule = gc-rule iv_bukrs = space iv_key = `BANK_A` ).
    correlate( EXPORTING it_parents = VALUE #( ( corr_key = lv_key corr_id = gc-stored first_seen_at = gc-old ) )
               CHANGING  ct_rows    = lt_rows ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-corr_role exp = zif_ca_ops_resp_types=>gc_corr_role-parent
                                        msg = 'Two hours later: a new parent' ).
    cl_abap_unit_assert=>assert_differs( act = lt_rows[ 1 ]-corr_id exp = gc-stored msg = 'A new group' ).
  ENDMETHOD.

ENDCLASS.
