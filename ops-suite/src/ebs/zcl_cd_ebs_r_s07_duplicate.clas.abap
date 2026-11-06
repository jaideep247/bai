*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s07_duplicate.clas.abap
*& Purpose:
*& S07: a statement may appear once: not twice in the same file and, for a
*& file not yet imported, not already in FEBKO (same account, number, date).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check S07 - duplicate statement</p>
CLASS zcl_cd_ebs_r_s07_duplicate DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_s07_duplicate IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    TYPES:
      BEGIN OF ty_key,
        account_no TYPE zif_cd_ebs_types=>ty_text35,
        stmt_no    TYPE zif_cd_ebs_types=>ty_statement-stmt_no,
        stmt_date  TYPE d,
      END OF ty_key.
    DATA lt_seen TYPE HASHED TABLE OF ty_key WITH UNIQUE KEY table_line.
    DATA ls_key TYPE ty_key.
    LOOP AT it_statements INTO DATA(ls_statement).
      ls_key-account_no = ls_statement-account_no.
      ls_key-stmt_no    = ls_statement-stmt_no.
      ls_key-stmt_date  = ls_statement-stmt_date.
      INSERT ls_key INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'STMT_DUPLICATE_IN_FILE'
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-stmt_duplicate_in_file
                                                     iv_v1    = ls_statement-stmt_no
                                                     iv_v2    = ls_statement-account_no ) )
          INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      IF ls_statement-source = zif_cd_ebs_types=>gc_source-file AND ls_statement-hbkid IS NOT INITIAL
         AND feb_dao( )->statement_exists( iv_bukrs = ls_statement-bukrs iv_hbkid = ls_statement-hbkid
                                           iv_hktid = ls_statement-hktid iv_aznum = CONV #( ls_statement-stmt_no )
                                           iv_azdat = ls_statement-stmt_date ) = abap_true.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'STMT_ALREADY_IMPORTED'
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-stmt_already_imported
                                                     iv_v1    = ls_statement-stmt_no
                                                     iv_v2    = |{ ls_statement-stmt_date DATE = ISO }| ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
