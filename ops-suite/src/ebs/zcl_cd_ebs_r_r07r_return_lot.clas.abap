*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r07r_return_lot.clas.abap
*& Purpose:
*& R07R: a returned payment must be in a returns lot (DFKKRP-SELW1 = payment
*& document) whose lot status is in PARAM1 (default 5). Legacy parity: v4 166D
*& and 168D (v4 matched DFKKRP-OPBEL; see parity document).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(lv_key) = docno_key( line_reference( ls_line ) ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(ls_item) = VALUE #( lt_items[ selw1 = lv_key ] OPTIONAL ).
      IF ls_item IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'RETURN_ITEM_NOT_FOUND'
                 iv_message = |Payment { lv_key } is in no returns lot| ) INTO TABLE rt_findings.
      ELSEIF in_list( iv_value = ls_item-lot_stars it_list = lt_allowed ) = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'RETURN_LOT_STATUS'
                 iv_message = |Returns lot of { lv_key } has status { ls_item-lot_stars }, expected { is_rule-param1 }| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
