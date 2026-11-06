*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r07r_return_lot.clas.abap
*& Purpose:
*& R07R: a returned payment must be in a returns lot (DFKKRP-SELW1 = payment
*& document) whose lot status is in PARAM1 (default 5). Legacy parity: v4 166D
*& and 168D (v4 matched DFKKRP-OPBEL; see parity document).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Any returns lot with an allowed status passes (audit 2026-11-06).
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
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'RETURN_ITEM_NOT_FOUND'
                 iv_message = |Payment { lv_key } is in no returns lot| ) INTO TABLE rt_findings.
      ELSEIF lv_ok = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'RETURN_LOT_STATUS'
                 iv_message = |Returns lot(s) of { lv_key } have status { lv_statuses }, expected { is_rule-param1 }| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
