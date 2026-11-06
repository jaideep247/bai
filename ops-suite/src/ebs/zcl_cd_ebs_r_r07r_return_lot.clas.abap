*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r07r_return_lot.clas.abap
*& Purpose:
*& R07R: a returned payment must be in a returns lot (DFKKRP-SELW1 = payment
*& document) whose lot status is in PARAM1 (default 5). Legacy parity: v4 166D
*& and 168D (v4 matched DFKKRP-OPBEL; see parity document).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Any returns lot with an allowed status passes (audit 2026-11-06).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A65: overlength / malformed reference rejected (REF_TOO_LONG / REF_FORMAT / KEY_LENGTH_CONFIG).
*& 2026-11-06 | FS-CD review: not found within EBS_INFLIGHT_HOURS of the statement is AWAITING_LOT_TRANSFER.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R07R - returns lot item and lot status</p>
CLASS zcl_cd_ebs_r_r07r_return_lot DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r07r_return_lot IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA(lt_items) = sap_dao( )->get_return_items( docno_keys( it_lines ) ).
    DATA(lt_allowed) = value_list( iv_values = is_rule-param1 iv_default = `5` ).
    DATA lv_statuses TYPE string.
    DATA lv_found TYPE abap_bool.
    DATA lv_ok TYPE abap_bool.
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(ls_rejection) = docno_rejection( is_rule = is_rule is_line = ls_line ).
      IF ls_rejection IS NOT INITIAL.
        INSERT ls_rejection INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      DATA(lv_key) = docno_key( line_reference( ls_line ) ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.
      " A payment can sit in several returns lots: a lot with an allowed status satisfies the rule
      CLEAR: lv_statuses, lv_found, lv_ok.
      LOOP AT lt_items INTO DATA(ls_item) WHERE selw1 = lv_key.
        lv_found = abap_true.
        IF in_list( iv_value = ls_item-lot_stars it_list = lt_allowed ) = abap_true.
          lv_ok = abap_true.
          EXIT.
        ENDIF.
        lv_statuses = condense( |{ lv_statuses } { ls_item-lot_stars }| ).
      ENDLOOP.
      IF lv_found = abap_false.
        INSERT not_found_finding(
                 is_rule = is_rule is_line = ls_line it_statements = it_statements
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-return_item_not_found
                 iv_message =
                   zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-return_item_not_found
                                          iv_v1 = lv_key ) ) INTO TABLE rt_findings.
      ELSEIF lv_ok = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-return_lot_status
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-return_lot_status
                                                     iv_v1    = lv_key
                                                     iv_v2    = lv_statuses
                                                     iv_v3    = is_rule-param1 ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
