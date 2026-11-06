*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r07_payment.clas.abap
*& Purpose:
*& R07: the payment document behind the bank reference must exist in the
*& payment run (DPAYH-DOC1R). PARAM1 = allowed payment statuses (comma list,
*& e.g. RETURNED for BAI 168). Legacy parity: v4 195D and 168D.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(lv_key) = docno_key( line_reference( ls_line ) ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(ls_payment) = VALUE #( lt_payments[ doc1r = lv_key ] OPTIONAL ).
      IF ls_payment IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'PAYMENT_NOT_FOUND'
                 iv_message = |No payment run entry (DPAYH) for document { lv_key }| ) INTO TABLE rt_findings.
      ELSEIF lt_allowed IS NOT INITIAL AND in_list( iv_value = ls_payment-status it_list = lt_allowed ) = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'PAYMENT_STATUS'
                 iv_message = |Payment { lv_key } status { ls_payment-status }, expected { is_rule-param1 }| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
