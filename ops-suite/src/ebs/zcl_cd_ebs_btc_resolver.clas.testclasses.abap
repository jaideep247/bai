*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_btc_resolver.clas.testclasses.abap
*& Purpose:
*& Domain tests for BTC mapping, flow derivation and the zero-suspense rule
*& (master prompt R14 / acceptance test 7). No doubles: the resolver is pure
*& logic over configuration passed in. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltc_resolver DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        bukrs      TYPE c LENGTH 4 VALUE 'US01',
        hbkid      TYPE c LENGTH 5 VALUE 'JPMC1',
        hktid      TYPE c LENGTH 5 VALUE 'DISB1',
        account    TYPE zif_cd_ebs_types=>ty_text35 VALUE '000123456789',
        bank_jpmc  TYPE zif_cd_ebs_types=>ty_bank_key VALUE 'JPMC',
        stmt_key   TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'S0001',
        code_168   TYPE zif_cd_ebs_types=>ty_btc_code VALUE '168',
        code_999   TYPE zif_cd_ebs_types=>ty_btc_code VALUE '999',
        iso_ret    TYPE zif_cd_ebs_types=>ty_btc_code VALUE 'PMNT-ICDT-ARET',
        cat_d02    TYPE zif_cd_ebs_types=>ty_category VALUE 'D02',
        cat_k02    TYPE zif_cd_ebs_types=>ty_category VALUE 'K02',
        cat_n01    TYPE zif_cd_ebs_types=>ty_category VALUE 'N01',
        group_168d TYPE zif_cd_ebs_types=>ty_rule_group VALUE 'BAI168D',
      END OF gc_test.

    DATA mt_map      TYPE zif_cd_ebs_types=>tt_btc_map.
    DATA mt_patterns TYPE zif_cd_ebs_types=>tt_flow_pattern.
    DATA mt_accounts TYPE zif_cd_ebs_types=>tt_account_cfg.
    DATA mt_stmts    TYPE zif_cd_ebs_types=>tt_statement.
    DATA mt_lines    TYPE zif_cd_ebs_types=>tt_line.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.

    METHODS setup.
    METHODS add_map_row
      IMPORTING
        iv_scheme   TYPE zif_cd_ebs_types=>ty_scheme
        iv_code     TYPE zif_cd_ebs_types=>ty_btc_code
        iv_bank     TYPE zif_cd_ebs_types=>ty_bank_key OPTIONAL
        iv_flow     TYPE zif_cd_ebs_types=>ty_flow DEFAULT zif_cd_ebs_types=>gc_flow-any
        iv_category TYPE zif_cd_ebs_types=>ty_category
        iv_group    TYPE zif_cd_ebs_types=>ty_rule_group OPTIONAL
        iv_action   TYPE zif_cd_ops_types=>ty_action OPTIONAL
        iv_active   TYPE abap_bool DEFAULT abap_true.
    METHODS add_line
      IMPORTING
        iv_scheme TYPE zif_cd_ebs_types=>ty_scheme DEFAULT zif_cd_ebs_types=>gc_scheme-bai2
        iv_code   TYPE zif_cd_ebs_types=>ty_btc_code
        iv_prtry  TYPE zif_cd_ebs_types=>ty_btc_code OPTIONAL
        iv_issuer TYPE zif_cd_ebs_types=>ty_text35 OPTIONAL
        iv_xblnr  TYPE zif_cd_ebs_types=>ty_line-xblnr OPTIONAL.
    METHODS run_resolver
      IMPORTING
        iv_bai_fallback TYPE abap_bool DEFAULT abap_true.
    METHODS first_line
      RETURNING
        VALUE(rs_line) TYPE zif_cd_ebs_types=>ty_line.

    METHODS bai_code_maps_to_category    FOR TESTING.
    METHODS bank_row_beats_default_row   FOR TESTING.
    METHODS flow_row_beats_any_flow_row  FOR TESTING.
    METHODS unmapped_btc_always_blocks   FOR TESTING.
    METHODS inactive_row_is_unmapped     FOR TESTING.
    METHODS iso_family_row_covers_subfam FOR TESTING.
    METHODS camt_bai_prtry_reuses_bai    FOR TESTING.
    METHODS bai_fallback_can_be_disabled FOR TESTING.
    METHODS xblnr_pattern_beats_account  FOR TESTING.
    METHODS account_flow_is_default      FOR TESTING.
    METHODS block_action_blocks_noc_line FOR TESTING.
    METHODS group_defaults_to_category   FOR TESTING.
    METHODS statement_gets_account_cfg   FOR TESTING.
ENDCLASS.


CLASS ltc_resolver IMPLEMENTATION.

  METHOD setup.
    DATA ls_account TYPE zif_cd_ebs_types=>ty_account_cfg.
    DATA ls_stmt    TYPE zif_cd_ebs_types=>ty_statement.

    CLEAR: mt_map, mt_patterns, mt_accounts, mt_stmts, mt_lines, mt_findings.

    ls_account-bukrs        = gc_test-bukrs.
    ls_account-hbkid        = gc_test-hbkid.
    ls_account-hktid        = gc_test-hktid.
    ls_account-account_no   = gc_test-account.
    ls_account-bank_key     = gc_test-bank_jpmc.
    ls_account-flow_default = zif_cd_ebs_types=>gc_flow-disbursement.
    ls_account-active       = abap_true.
    INSERT ls_account INTO TABLE mt_accounts.

    ls_stmt-stmt_key   = gc_test-stmt_key.
    ls_stmt-bukrs      = gc_test-bukrs.
    ls_stmt-hbkid      = gc_test-hbkid.
    ls_stmt-hktid      = gc_test-hktid.
    ls_stmt-account_no = gc_test-account.
    INSERT ls_stmt INTO TABLE mt_stmts.
  ENDMETHOD.


  METHOD add_map_row.
    DATA ls_map TYPE zif_cd_ebs_types=>ty_btc_map.
    ls_map-scheme     = iv_scheme.
    ls_map-btc_code   = iv_code.
    ls_map-bank_key   = iv_bank.
    ls_map-flow_type  = iv_flow.
    ls_map-category   = iv_category.
    ls_map-rule_group = iv_group.
    ls_map-action     = iv_action.
    ls_map-active     = iv_active.
    ls_map-exp_cdi    = zif_cd_ebs_types=>gc_cdi-credit.
    INSERT ls_map INTO TABLE mt_map.
  ENDMETHOD.


  METHOD add_line.
    DATA ls_line TYPE zif_cd_ebs_types=>ty_line.
    ls_line-stmt_key     = gc_test-stmt_key.
    ls_line-line_no      = lines( mt_lines ) + 1.
    ls_line-scheme       = iv_scheme.
    ls_line-btc_code     = iv_code.
    ls_line-prtry_code   = iv_prtry.
    ls_line-prtry_issuer = iv_issuer.
    ls_line-xblnr        = iv_xblnr.
    ls_line-cdi          = zif_cd_ebs_types=>gc_cdi-credit.
    ls_line-amount       = '100.00'.
    IF iv_scheme = zif_cd_ebs_types=>gc_scheme-iso.
      SPLIT iv_code AT '-' INTO ls_line-domain ls_line-family ls_line-subfamily.
    ENDIF.
    INSERT ls_line INTO TABLE mt_lines.
  ENDMETHOD.


  METHOD run_resolver.
    DATA(lo_cut) = NEW zcl_cd_ebs_btc_resolver( it_map          = mt_map
                                                 it_patterns     = mt_patterns
                                                 it_accounts     = mt_accounts
                                                 iv_bai_fallback = iv_bai_fallback ).
    lo_cut->enrich_statements( CHANGING ct_statements = mt_stmts ).
    mt_findings = lo_cut->resolve( EXPORTING it_statements = mt_stmts
                                   CHANGING  ct_lines      = mt_lines ).
  ENDMETHOD.


  METHOD first_line.
    READ TABLE mt_lines INTO rs_line INDEX 1.
  ENDMETHOD.


  " A mapped BAI2 type code receives the category of its map row and no finding
  METHOD bai_code_maps_to_category.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_d02 iv_group = gc_test-group_168d ).
        add_line( iv_code = gc_test-code_168 ).

        run_resolver( ).

        DATA(ls_line) = first_line( ).
        cl_abap_unit_assert=>assert_equals( act = ls_line-category exp = gc_test-cat_d02
                                            msg = 'Mapped code must take the category of its map row' ).
        cl_abap_unit_assert=>assert_equals( act = ls_line-rule_group exp = gc_test-group_168d
                                            msg = 'Mapped code must take the rule group of its map row' ).
        cl_abap_unit_assert=>assert_false( act = ls_line-blocked
                                           msg = 'A mapped code must not be blocked' ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'A mapped code must not raise a finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Registry fallback: the bank-specific row wins over the blank-bank default row
  METHOD bank_row_beats_default_row.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_k02 ).
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_bank = gc_test-bank_jpmc iv_category = gc_test-cat_d02 ).
        add_line( iv_code = gc_test-code_168 ).

        run_resolver( ).

        cl_abap_unit_assert=>assert_equals( act = first_line( )-category exp = gc_test-cat_d02
                                            msg = 'Bank-specific map row must win over the default row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The row for the line's flow (D) wins over the any-flow row (*)
  METHOD flow_row_beats_any_flow_row.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_k02 ).
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_flow = zif_cd_ebs_types=>gc_flow-disbursement iv_category = gc_test-cat_d02 ).
        add_line( iv_code = gc_test-code_168 ).

        run_resolver( ).

        cl_abap_unit_assert=>assert_equals( act = first_line( )-category exp = gc_test-cat_d02
                                            msg = 'Flow-specific row must win over the any-flow row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " R14 / acceptance test 7: an unmapped code is blocked with a B finding - never suspense
  METHOD unmapped_btc_always_blocks.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_d02 ).
        add_line( iv_code = gc_test-code_999 ).

        run_resolver( ).

        DATA(ls_line) = first_line( ).
        cl_abap_unit_assert=>assert_true( act = ls_line-blocked
                                          msg = 'Unmapped code must be blocked' ).
        cl_abap_unit_assert=>assert_equals( act = ls_line-category
                                            exp = zif_cd_ebs_types=>gc_category_unmapped
                                            msg = 'Unmapped code must carry category X01' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mt_findings ) exp = 1
                                            msg = 'Exactly one finding per unmapped line' ).
        DATA(ls_finding) = mt_findings[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_finding-rule_id exp = 'R14'
                                            msg = 'Unmapped code is rule R14' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity
                                            exp = zif_cd_ops_types=>gc_severity-block
                                            msg = 'Unmapped code must have severity B' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-action
                                            exp = zif_cd_ops_types=>gc_action-block
                                            msg = 'Unmapped code must have action BLOCK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A deactivated map row counts as unmapped (switching a code off cannot open suspense)
  METHOD inactive_row_is_unmapped.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_d02 iv_active = abap_false ).
        add_line( iv_code = gc_test-code_168 ).

        run_resolver( ).

        cl_abap_unit_assert=>assert_true( act = first_line( )-blocked
                                          msg = 'Inactive map row must leave the line blocked' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A CAMT family-level row (DOMN-FMLY) covers every sub-family not mapped on its own
  METHOD iso_family_row_covers_subfam.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-iso iv_code = 'PMNT-ICDT'
                     iv_category = gc_test-cat_d02 ).
        add_line( iv_scheme = zif_cd_ebs_types=>gc_scheme-iso iv_code = gc_test-iso_ret ).

        run_resolver( ).

        cl_abap_unit_assert=>assert_equals( act = first_line( )-category exp = gc_test-cat_d02
                                            msg = 'Family-level ISO row must map the sub-family code' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " CAMT line whose proprietary code is a BAI type code reuses the BAI2 mapping
  METHOD camt_bai_prtry_reuses_bai.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_d02 ).
        add_line( iv_scheme = zif_cd_ebs_types=>gc_scheme-iso iv_code = 'PMNT-XXXX-YYYY'
                  iv_prtry = gc_test-code_168 iv_issuer = 'BAI' ).

        run_resolver( ).

        cl_abap_unit_assert=>assert_equals( act = first_line( )-category exp = gc_test-cat_d02
                                            msg = 'Proprietary BAI code must reuse the BAI2 map row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The BAI fallback is a parameter; switched off, the proprietary code stays unmapped
  METHOD bai_fallback_can_be_disabled.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_d02 ).
        add_line( iv_scheme = zif_cd_ebs_types=>gc_scheme-iso iv_code = 'PMNT-XXXX-YYYY'
                  iv_prtry = gc_test-code_168 iv_issuer = 'BAI' ).

        run_resolver( iv_bai_fallback = abap_false ).

        cl_abap_unit_assert=>assert_true( act = first_line( )-blocked
                                          msg = 'Without fallback the line must stay unmapped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Flow derivation: an XBLNR pattern (ported from ZB_BAI_GL_CONFIG) beats the account default
  METHOD xblnr_pattern_beats_account.
    DATA ls_pattern TYPE zif_cd_ebs_types=>ty_flow_pattern.
    TRY.
        ls_pattern-priority  = 10.
        ls_pattern-pattern   = '*COLL*'.
        ls_pattern-flow_type = zif_cd_ebs_types=>gc_flow-collection.
        INSERT ls_pattern INTO TABLE mt_patterns.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_d02 ).
        add_line( iv_code = gc_test-code_168 iv_xblnr = 'JPMC-COLL-0001' ).

        run_resolver( ).

        cl_abap_unit_assert=>assert_equals( act = first_line( )-flow_type
                                            exp = zif_cd_ebs_types=>gc_flow-collection
                                            msg = 'XBLNR pattern must decide the flow before the account' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Without a pattern hit the account's default flow applies
  METHOD account_flow_is_default.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_d02 ).
        add_line( iv_code = gc_test-code_168 ).

        run_resolver( ).

        cl_abap_unit_assert=>assert_equals( act = first_line( )-flow_type
                                            exp = zif_cd_ebs_types=>gc_flow-disbursement
                                            msg = 'Account default flow must apply' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " N01: a map row with action BLOCK (NOC is never posted) blocks the line without an error
  METHOD block_action_blocks_noc_line.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_n01 iv_action = zif_cd_ops_types=>gc_action-block ).
        add_line( iv_code = gc_test-code_168 ).

        run_resolver( ).

        cl_abap_unit_assert=>assert_true( act = first_line( )-blocked
                                          msg = 'Map action BLOCK must block the line' ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-severity
                                            exp = zif_cd_ops_types=>gc_severity-info
                                            msg = 'A configured block is information, not an error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A map row without rule group validates with the rules of its category
  METHOD group_defaults_to_category.
    TRY.
        add_map_row( iv_scheme = zif_cd_ebs_types=>gc_scheme-bai2 iv_code = gc_test-code_168
                     iv_category = gc_test-cat_d02 ).
        add_line( iv_code = gc_test-code_168 ).

        run_resolver( ).

        cl_abap_unit_assert=>assert_equals( act = first_line( )-rule_group
                                            exp = CONV zif_cd_ebs_types=>ty_rule_group( gc_test-cat_d02 )
                                            msg = 'Rule group must default to the category' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The statement inherits bank key and default flow from ZCD_EBS_ACCT
  METHOD statement_gets_account_cfg.
    TRY.
        run_resolver( ).

        DATA(ls_stmt) = mt_stmts[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_stmt-bank_key exp = gc_test-bank_jpmc
                                            msg = 'Statement must take the bank key of its account' ).
        cl_abap_unit_assert=>assert_equals( act = ls_stmt-flow_default
                                            exp = zif_cd_ebs_types=>gc_flow-disbursement
                                            msg = 'Statement must take the default flow of its account' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
