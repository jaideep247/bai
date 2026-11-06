*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_rule.intf.abap
*& Purpose:
*& One class per rule, configured in ZCD_EBS_RULE_DEF and assigned to rule
*& groups in ZCD_BTC_RULE. Statement rules (level S) receive all statements and
*& lines of a package; line rules (level L) receive only the lines of the rule
*& group being validated. Rules never write and never commit.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - rule strategy (R01-R20, S01-S12)</p>
"! One class per rule, configured in ZCD_EBS_RULE_DEF and assigned to rule
"! groups in ZCD_BTC_RULE. Statement rules (level S) receive all statements and
"! lines of a package; line rules (level L) receive only the lines of the rule
"! group being validated. Rules never write and never commit.
INTERFACE zif_cd_ebs_rule
  PUBLIC.

  METHODS execute
    IMPORTING
      is_rule            TYPE zif_cd_ebs_types=>ty_rule_cfg
      it_statements      TYPE zif_cd_ebs_types=>tt_statement
      it_lines           TYPE zif_cd_ebs_types=>tt_line
    RETURNING
      VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
