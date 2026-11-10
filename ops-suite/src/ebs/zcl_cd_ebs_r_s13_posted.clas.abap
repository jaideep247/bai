*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s13_posted.clas.abap
*& Purpose:
*& S13 (imported statements only): every entry expected to post is posted.
*& An entry the engine marked POSTING_OPEN (FEBEP posting-area flags not
*& complete, map disposition not NOT_POSTED, not blocked) means a predecessor
*& job (FEBP posting, payment clearing) has not finished or left entries
*& unposted - one POSTING_INCOMPLETE finding per statement with the count. Pure.
*& Modification log:
*& 2026-11-06 | Initial version (operating model: post-posting detective control).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check S13 - entries expected to post are posted</p>
CLASS zcl_cd_ebs_r_s13_posted DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_s13_posted IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_statements ASSIGNING FIELD-SYMBOL(<ls_statement>) WHERE source = zif_cd_ebs_types=>gc_source-feb.
      DATA(lv_open) = 0.
      DATA(lv_amount) = CONV zif_ca_ops_types=>ty_amount( 0 ).
      LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>) USING KEY stmt
           WHERE stmt_key = <ls_statement>-stmt_key AND posting_open = abap_true.
        lv_open += 1.
        lv_amount += <ls_line>-amount.
      ENDLOOP.
      IF lv_open > 0.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule       = is_rule
                 is_statement  = <ls_statement>
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-posting_incomplete
                 iv_amount     = lv_amount
                 iv_message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-posting_incomplete
                                                        iv_v1    = lv_open
                                                        iv_v2    = lv_amount ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
