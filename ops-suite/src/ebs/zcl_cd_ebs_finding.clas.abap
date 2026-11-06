*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_finding.clas.abap
*& Purpose:
*& Builds EBS findings for statements and lines in one consistent shape
*& (object key, grouping, reference, amount). Pure; no database access.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - finding builder</p>
CLASS zcl_cd_ebs_finding DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF gc_object_type,
        line      TYPE zif_cd_ops_types=>ty_object_type VALUE 'LINE',
        statement TYPE zif_cd_ops_types=>ty_object_type VALUE 'STMT',
        file      TYPE zif_cd_ops_types=>ty_object_type VALUE 'FILE',
        run       TYPE zif_cd_ops_types=>ty_object_type VALUE 'RUN',
      END OF gc_object_type.

    "! Object key of a line: <stmt_key>/<line_no>
    CLASS-METHODS line_key
      IMPORTING
        is_line       TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rv_key) TYPE zif_cd_ops_types=>ty_object_key.

    CLASS-METHODS for_line
      IMPORTING
        is_line           TYPE zif_cd_ebs_types=>ty_line
        iv_rule_id        TYPE zif_cd_ops_types=>ty_rule_id
        iv_check_code     TYPE zif_cd_ops_types=>ty_check_code
        iv_severity       TYPE zif_cd_ops_types=>ty_severity
        iv_action         TYPE zif_cd_ops_types=>ty_action OPTIONAL
        iv_message        TYPE clike
        iv_details        TYPE string OPTIONAL
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

    CLASS-METHODS for_statement
      IMPORTING
        is_statement      TYPE zif_cd_ebs_types=>ty_statement
        iv_rule_id        TYPE zif_cd_ops_types=>ty_rule_id
        iv_check_code     TYPE zif_cd_ops_types=>ty_check_code
        iv_severity       TYPE zif_cd_ops_types=>ty_severity
        iv_action         TYPE zif_cd_ops_types=>ty_action OPTIONAL
        iv_message        TYPE clike
        iv_amount         TYPE zif_cd_ops_types=>ty_amount OPTIONAL
        iv_details        TYPE string OPTIONAL
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

    "! Finding from a rule configuration row (severity and action come from customizing)
    CLASS-METHODS for_rule_line
      IMPORTING
        is_rule           TYPE zif_cd_ebs_types=>ty_rule_cfg
        is_line           TYPE zif_cd_ebs_types=>ty_line
        iv_check_code     TYPE zif_cd_ops_types=>ty_check_code
        iv_message        TYPE clike
        iv_details        TYPE string OPTIONAL
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

    CLASS-METHODS for_rule_statement
      IMPORTING
        is_rule           TYPE zif_cd_ebs_types=>ty_rule_cfg
        is_statement      TYPE zif_cd_ebs_types=>ty_statement
        iv_check_code     TYPE zif_cd_ops_types=>ty_check_code
        iv_message        TYPE clike
        iv_amount         TYPE zif_cd_ops_types=>ty_amount OPTIONAL
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

ENDCLASS.



CLASS zcl_cd_ebs_finding IMPLEMENTATION.

  METHOD line_key.
    rv_key = |{ is_line-stmt_key }/{ is_line-line_no }|.
  ENDMETHOD.


  METHOD for_line.
    rs_finding-object_type = gc_object_type-line.
    rs_finding-object_key  = line_key( is_line ).
    rs_finding-group1      = |{ is_line-scheme }:{ is_line-btc_code }|.
    rs_finding-group2      = is_line-category.
    rs_finding-rule_id     = iv_rule_id.
    rs_finding-check_code  = iv_check_code.
    rs_finding-severity    = iv_severity.
    rs_finding-action      = iv_action.
    rs_finding-amount      = COND #( WHEN is_line-cdi = zif_cd_ebs_types=>gc_cdi-debit
                                     THEN - is_line-amount
                                     ELSE is_line-amount ).
    rs_finding-currency    = is_line-currency.
    rs_finding-reference   = is_line-reference.
    rs_finding-message     = iv_message.
    rs_finding-details     = iv_details.
  ENDMETHOD.


  METHOD for_statement.
    rs_finding-object_type = gc_object_type-statement.
    rs_finding-object_key  = is_statement-stmt_key.
    rs_finding-group1      = is_statement-account_no.
    rs_finding-group2      = is_statement-bank_key.
    rs_finding-rule_id     = iv_rule_id.
    rs_finding-check_code  = iv_check_code.
    rs_finding-severity    = iv_severity.
    rs_finding-action      = iv_action.
    rs_finding-amount      = iv_amount.
    rs_finding-currency    = is_statement-currency.
    rs_finding-reference   = is_statement-stmt_id.
    rs_finding-message     = iv_message.
    rs_finding-details     = iv_details.
  ENDMETHOD.


  METHOD for_rule_line.
    rs_finding = for_line( is_line       = is_line
                           iv_rule_id    = is_rule-rule_id
                           iv_check_code = iv_check_code
                           iv_severity   = is_rule-severity
                           iv_action     = is_rule-action
                           iv_message    = iv_message
                           iv_details    = iv_details ).
  ENDMETHOD.


  METHOD for_rule_statement.
    rs_finding = for_statement( is_statement  = is_statement
                                iv_rule_id    = is_rule-rule_id
                                iv_check_code = iv_check_code
                                iv_severity   = is_rule-severity
                                iv_action     = is_rule-action
                                iv_message    = iv_message
                                iv_amount     = iv_amount ).
  ENDMETHOD.

ENDCLASS.
