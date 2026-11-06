*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r09_duplicate.clas.abap
*& Purpose:
*& R09: an entry with the same statement, reference, amount, sign, code and
*& value date as an earlier entry is a duplicate; the first occurrence passes.
*& Entries without reference are not compared. Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R09 - duplicate entry</p>
CLASS zcl_cd_ebs_r_r09_duplicate DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r09_duplicate IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    TYPES:
      BEGIN OF ty_key,
        stmt_key   TYPE zif_cd_ebs_types=>ty_stmt_key,
        reference  TYPE zif_cd_ebs_types=>ty_text35,
        amount     TYPE zif_cd_ops_types=>ty_amount,
        cdi        TYPE zif_cd_ebs_types=>ty_cdi,
        btc_code   TYPE zif_cd_ebs_types=>ty_btc_code,
        value_date TYPE d,
      END OF ty_key.
    DATA lt_seen TYPE HASHED TABLE OF ty_key WITH UNIQUE KEY table_line.
    DATA ls_key TYPE ty_key.
    LOOP AT it_lines INTO DATA(ls_line) WHERE reference IS NOT INITIAL.
      ls_key-stmt_key   = ls_line-stmt_key.
      ls_key-reference  = ls_line-reference.
      ls_key-amount     = ls_line-amount.
      ls_key-cdi        = ls_line-cdi.
      ls_key-btc_code   = ls_line-btc_code.
      ls_key-value_date = ls_line-value_date.
      INSERT ls_key INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-duplicate_entry
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-duplicate_entry
                                                     iv_v1    = ls_line-reference ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
