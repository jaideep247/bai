*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_finding.clas.testclasses.abap
*& Purpose:
*& Domain tests of the finding builder: object key, grouping, signed amount and
*& severity/action taken from the rule configuration. No doubles. Written after
*& the class (characterisation tests). Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (TDD gap closure).
*&---------------------------------------------------------------------*
CLASS ltc_finding DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        stmt_key TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'S0001',
        line_no  TYPE i VALUE 7,
        amount   TYPE zif_cd_ops_types=>ty_amount VALUE '125.00',
        account  TYPE zif_cd_ebs_types=>ty_text35 VALUE '000123456789',
      END OF gc_test.

    METHODS debit_line
      RETURNING
        VALUE(rs_line) TYPE zif_cd_ebs_types=>ty_line.

    METHODS line_key_is_stmt_slash_line  FOR TESTING.
    METHODS debit_amount_is_negative     FOR TESTING.
    METHODS line_grouped_by_code_and_cat FOR TESTING.
    METHODS rule_config_sets_sev_action  FOR TESTING.
    METHODS stmt_grouped_by_account      FOR TESTING.
ENDCLASS.


CLASS ltc_finding IMPLEMENTATION.

  METHOD debit_line.
    rs_line-stmt_key  = gc_test-stmt_key.
    rs_line-line_no   = gc_test-line_no.
    rs_line-scheme    = zif_cd_ebs_types=>gc_scheme-bai2.
    rs_line-btc_code  = '475'.
    rs_line-category  = 'K01'.
    rs_line-cdi       = zif_cd_ebs_types=>gc_cdi-debit.
    rs_line-amount    = gc_test-amount.
    rs_line-currency  = 'USD'.
    rs_line-reference = '000123'.
  ENDMETHOD.


  " Line findings are keyed <stmt_key>/<line_no> so drill-down finds the entry
  METHOD line_key_is_stmt_slash_line.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_finding=>line_key( debit_line( ) )
                                        exp = |{ gc_test-stmt_key }/{ gc_test-line_no }|
                                        msg = 'Line key must be stmt_key/line_no' ).
  ENDMETHOD.


  " A debit entry is stored with a negative amount so totals net correctly
  METHOD debit_amount_is_negative.
    DATA(ls_finding) = zcl_cd_ebs_finding=>for_line( is_line       = debit_line( )
                                                     iv_rule_id    = 'R08'
                                                     iv_check_code = 'CHECK_AMOUNT_MISMATCH'
                                                     iv_severity   = zif_cd_ops_types=>gc_severity-error
                                                     iv_message    = 'test' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = - gc_test-amount
                                        msg = 'Debit amount must be negative' ).
  ENDMETHOD.


  " Dashboard grouping: group1 = scheme:code, group2 = category
  METHOD line_grouped_by_code_and_cat.
    DATA(ls_finding) = zcl_cd_ebs_finding=>for_line( is_line       = debit_line( )
                                                     iv_rule_id    = 'R08'
                                                     iv_check_code = 'CHECK_AMOUNT_MISMATCH'
                                                     iv_severity   = zif_cd_ops_types=>gc_severity-error
                                                     iv_message    = 'test' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-group1 exp = 'BAI2:475' msg = 'group1 must be scheme:code' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-group2 exp = 'K01' msg = 'group2 must be the category' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_type exp = zcl_cd_ebs_finding=>gc_object_type-line
                                        msg = 'Object type must be LINE' ).
  ENDMETHOD.


  " Severity and action of a rule finding come from customizing, not from the rule class
  METHOD rule_config_sets_sev_action.
    DATA ls_rule TYPE zif_cd_ebs_types=>ty_rule_cfg.
    ls_rule-rule_id  = 'S01'.
    ls_rule-severity = zif_cd_ops_types=>gc_severity-block.
    ls_rule-action   = zif_cd_ops_types=>gc_action-block.
    DATA(ls_finding) = zcl_cd_ebs_finding=>for_rule_line( is_rule       = ls_rule
                                                          is_line       = debit_line( )
                                                          iv_check_code = 'X'
                                                          iv_message    = 'test' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-block
                                        msg = 'Severity must come from the rule configuration' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-action exp = zif_cd_ops_types=>gc_action-block
                                        msg = 'Action must come from the rule configuration' ).
  ENDMETHOD.


  " Statement findings are keyed by statement and grouped by account and bank
  METHOD stmt_grouped_by_account.
    DATA ls_statement TYPE zif_cd_ebs_types=>ty_statement.
    ls_statement-stmt_key   = gc_test-stmt_key.
    ls_statement-account_no = gc_test-account.
    ls_statement-bank_key   = 'JPMC'.
    DATA(ls_finding) = zcl_cd_ebs_finding=>for_statement( is_statement  = ls_statement
                                                          iv_rule_id    = 'S02'
                                                          iv_check_code = 'BALANCE_ARITHMETIC'
                                                          iv_severity   = zif_cd_ops_types=>gc_severity-block
                                                          iv_message    = 'test' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = CONV zif_cd_ops_types=>ty_object_key( gc_test-stmt_key )
                                        msg = 'Statement finding must be keyed by stmt_key' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-group1 exp = CONV zif_cd_ops_types=>ty_group( gc_test-account )
                                        msg = 'group1 must be the account' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-group2 exp = 'JPMC' msg = 'group2 must be the bank key' ).
  ENDMETHOD.

ENDCLASS.
