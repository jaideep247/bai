*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r07l_retrieval.clas.abap
*& Purpose:
*& R07L: the ACH retrieval (ZCD_ACH_RTRV_LOG by clearing document) must exist
*& with a status in PARAM1 (default AF). Legacy parity: v4 168D and 468D.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R07L - ACH retrieval log status</p>
CLASS zcl_cd_ebs_r_r07l_retrieval DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r07l_retrieval IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA(lt_retrievals) = sap_dao( )->get_retrievals( docno_keys( it_lines ) ).
    DATA(lt_allowed) = value_list( iv_values = is_rule-param1 iv_default = `AF` ).
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(lv_key) = docno_key( line_reference( ls_line ) ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(ls_retrieval) = VALUE #( lt_retrievals[ augbl = lv_key ] OPTIONAL ).
      IF ls_retrieval IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'RETRIEVAL_NOT_FOUND'
                 iv_message = |No ACH retrieval log for document { lv_key }| ) INTO TABLE rt_findings.
      ELSEIF in_list( iv_value = ls_retrieval-status it_list = lt_allowed ) = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'RETRIEVAL_STATUS'
                 iv_message = |Retrieval { lv_key } status { ls_retrieval-status }, expected { is_rule-param1 }| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
