*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r07_payment.clas.abap
*& Purpose:
*& R07: the payment document behind the bank reference must exist in the
*& payment run (DPAYH-DOC1R). PARAM1 = allowed payment statuses (comma list,
*& e.g. RETURNED for BAI 168 / 195D, RETRIEVED for BAI 166D). Legacy parity:
*& v4 195D and 168D.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Any productive run with an allowed status passes; message lists every status (audit 2026-11-06).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A65: overlength / malformed reference rejected (REF_TOO_LONG / REF_FORMAT / KEY_LENGTH_CONFIG).
*& 2026-11-06 | FS-CD review: not found within EBS_INFLIGHT_HOURS of the statement is AWAITING_LOT_TRANSFER.
*& 2026-11-06 | Performance fix 4: register rows by sorted secondary key (USING KEY); field symbols.
*& 2026-11-08 | Header only: seeded statuses RETRIEVED (166D) / RETURNED (195D), user decision; no code change.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R07 - payment exists in DPAYH (status)</p>
CLASS zcl_cd_ebs_r_r07_payment DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r07_payment IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA(lt_payments) = sap_dao( )->get_payments( docno_keys( it_lines ) ).
    DATA(lt_allowed) = value_list( is_rule-param1 ).
    DATA lv_statuses TYPE string.
    DATA lv_found TYPE abap_bool.
    DATA lv_ok TYPE abap_bool.
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      DATA(ls_rejection) = docno_rejection( is_rule = is_rule is_line = <ls_line> ).
      IF ls_rejection IS NOT INITIAL.
        INSERT ls_rejection INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      DATA(lv_key) = docno_key( line_reference( <ls_line> ) ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.
      " Several productive runs can carry the document: any run with an allowed status
      " satisfies the rule; the first row returned is not authoritative
      CLEAR: lv_statuses, lv_found, lv_ok.
      LOOP AT lt_payments ASSIGNING FIELD-SYMBOL(<ls_payment>) USING KEY by_doc1r WHERE doc1r = lv_key.
        lv_found = abap_true.
        IF lt_allowed IS INITIAL OR in_list( iv_value = <ls_payment>-status it_list = lt_allowed ) = abap_true.
          lv_ok = abap_true.
          EXIT.
        ENDIF.
        lv_statuses = condense( |{ lv_statuses } { <ls_payment>-status }| ).
      ENDLOOP.
      IF lv_found = abap_false.
        INSERT not_found_finding(
                 is_rule = is_rule is_line = <ls_line> it_statements = it_statements
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-payment_not_found
                 iv_message =
                   zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-payment_not_found
                                          iv_v1 = lv_key ) ) INTO TABLE rt_findings.
      ELSEIF lv_ok = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-payment_status
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-payment_status
                                                     iv_v1    = lv_key
                                                     iv_v2    = lv_statuses
                                                     iv_v3    = is_rule-param1 ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
