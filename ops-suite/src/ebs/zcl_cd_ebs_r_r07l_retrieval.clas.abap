*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r07l_retrieval.clas.abap
*& Purpose:
*& R07L: the ACH retrieval (ZCD_ACH_RTRV_LOG by clearing document) must exist
*& with a status in PARAM1 (default AF). Legacy parity: v4 168D and 468D.
*& PARAM2: statuses that pass on their own (166D: AP). PARAM3 = LOT: a retrieval
*& passing on PARAM1 also needs a returns-lot entry (DFKKRP-SELW1) - the 166D
*& retrieval-log chain of the first framework (business decision A11).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Any logged attempt with an allowed status passes (audit 2026-11-06).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A11: PARAM2 statuses pass alone (AP), PARAM3 LOT requires a returns-lot entry.
*& 2026-11-06 | Audit A65: overlength / malformed reference rejected (REF_TOO_LONG / REF_FORMAT / KEY_LENGTH_CONFIG).
*& 2026-11-06 | FS-CD review: not found within EBS_INFLIGHT_HOURS of the statement is AWAITING_LOT_TRANSFER.
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
    DATA(lt_alone)   = value_list( is_rule-param2 ).
    DATA(lv_need_lot) = xsdbool( condense( CONV string( is_rule-param3 ) ) = zif_cd_ebs_types=>gc_rule_keyword-lot ).
    DATA lt_items TYPE zif_cd_ebs_sap_dao=>tt_return_item.
    DATA lv_statuses TYPE string.
    DATA lv_found TYPE abap_bool.
    DATA lv_ok TYPE abap_bool.
    DATA lv_alone TYPE abap_bool.
    IF lv_need_lot = abap_true.
      lt_items = sap_dao( )->get_return_items( docno_keys( it_lines ) ).
    ENDIF.
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
      " Several attempts can be logged: an attempt with an allowed status satisfies the
      " rule even when a failed attempt was written after it
      CLEAR: lv_statuses, lv_found, lv_ok, lv_alone.
      LOOP AT lt_retrievals INTO DATA(ls_retrieval) WHERE augbl = lv_key.
        lv_found = abap_true.
        IF in_list( iv_value = ls_retrieval-status it_list = lt_alone ) = abap_true.
          lv_alone = abap_true.
          EXIT.
        ENDIF.
        IF in_list( iv_value = ls_retrieval-status it_list = lt_allowed ) = abap_true.
          lv_ok = abap_true.
        ELSE.
          lv_statuses = condense( |{ lv_statuses } { ls_retrieval-status }| ).
        ENDIF.
      ENDLOOP.
      IF lv_found = abap_false.
        INSERT not_found_finding(
                 is_rule = is_rule is_line = ls_line it_statements = it_statements
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-retrieval_not_found
                 iv_message =
                   zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-retrieval_not_found
                                          iv_v1 = lv_key ) ) INTO TABLE rt_findings.
      ELSEIF lv_alone = abap_true.
        CONTINUE.
      ELSEIF lv_ok = abap_true AND lv_need_lot = abap_true AND NOT line_exists( lt_items[ selw1 = lv_key ] ).
        INSERT not_found_finding(
                 is_rule = is_rule is_line = ls_line it_statements = it_statements
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-return_item_not_found
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-return_item_not_found
                                                     iv_v1    = lv_key ) ) INTO TABLE rt_findings.
      ELSEIF lv_ok = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-retrieval_status
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-retrieval_status
                                                     iv_v1    = lv_key
                                                     iv_v2    = lv_statuses
                                                     iv_v3    = is_rule-param1 ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
