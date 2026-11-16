*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_coll_c_refund.clas.abap
*& Purpose:
*& Check COLL_R3_REFUND of process BASE_REQ_LIFE (area CD_COLL, control
*& BASE_REJECTS, proposal P2 - the control's main check): a collections
*& payment request the source (BASE) rejected after SAP sent SCHEDULED
*& (meaning confirmed 2026-11-10) must end in a successful Stripe premium
*& refund called by SAP. Requests whose latest status is COLL_REJECT_VALUE
*& are matched with SAP's refund log (COLL_SRC_REFUND, by the request key,
*& one set read for all rejected requests): a refund row with a value of
*& COLL_REFUND_OK closes it; a failed row only (COLL_REFUND_FAILED) is
*& PREMIUM_REFUND_FAILED (E); no successful row after COLL_R3_AMBER_H /
*& _RED_H hours is PREMIUM_REFUND_MISSING (W / E) - company code, amount,
*& currency, age in hours, deadline, control; one exposure finding per
*& currency. Sources, values and limits are parameters (area CD_OPS);
*& blank or a placeholder raises (CHECK_FAILED: no verdict, never green).
*& Registered in ZCA_OPS_CHECK; run by ZCL_CA_OPS_CHECK_RUNNER, which
*& stamps GROUP1 = process and GROUP2 = check. Read only.
*& Modification log:
*& 2026-11-10 | Initial version (scaffold tools/abaptools/new_process.py).
*& 2026-11-16 | Completed (build R): rule R3 - rejected request without a successful refund, failed refund.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Check COLL_R3_REFUND</p>
CLASS zcl_cd_coll_c_refund DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

ENDCLASS.



CLASS zcl_cd_coll_c_refund IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    DATA lt_items TYPE zif_cd_hck_cheque_types=>tt_item.
    DATA lt_keys TYPE zif_cd_ops_trace_types=>tt_key_value.
    DATA lt_ok TYPE zif_cd_ops_trace_types=>tt_key_value.
    DATA lt_failed TYPE zif_cd_ops_trace_types=>tt_key_value.
    DATA lv_code TYPE zif_ca_ops_types=>ty_check_code.
    DATA lv_message TYPE string.

    DATA(lo_rules) = NEW zcl_cd_coll_rules( is_check = is_check is_context = is_context ).
    DATA(lv_reject) = lo_rules->required( zif_cd_coll_types=>gc_param-reject_value ).
    DATA(lt_ok_values) = zcl_ca_ops_util=>split_list( to_upper( lo_rules->required( zif_cd_coll_types=>gc_param-refund_ok ) ) ).
    DATA(lv_failed_list) = lo_rules->required( zif_cd_coll_types=>gc_param-refund_failed ).
    DATA(lt_failed_values) = zcl_ca_ops_util=>split_list( to_upper( lv_failed_list ) ).
    DATA(ls_limits) = lo_rules->limits( iv_amber = zif_cd_coll_types=>gc_param-r3_amber
                                        iv_red   = zif_cd_coll_types=>gc_param-r3_red ).
    DATA(ls_refund_src) = lo_rules->source( zif_cd_coll_types=>gc_param-src_refund ).

    DATA(lt_requests) = lo_rules->requests_in( lv_reject ).
    rs_result-item_count = lines( lt_requests ).
    rs_result-partial    = lo_rules->capped( ).
    IF rs_result-partial = abap_true.
      INSERT lo_rules->capped_finding( ) INTO TABLE rs_result-findings.
    ENDIF.
    IF lt_requests IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      INSERT <ls_request>-key INTO TABLE lt_keys.
    ENDLOOP.
    " Every refund row of the rejected requests in one read (the refund log keyed by the request key)
    DATA(lv_cap) = lines( lt_keys ) * zif_cd_coll_types=>gc_default-max_list.
    DATA(lt_refunds) = zcl_cd_ops_factory=>get_trace_dao( )->read_configured_set( is_source   = ls_refund_src
                                                                                  it_keys     = lt_keys
                                                                                  iv_max_rows = lv_cap ).
    IF lines( lt_refunds ) >= lv_cap.
      rs_result-partial = abap_true.
    ENDIF.
    LOOP AT lt_refunds ASSIGNING FIELD-SYMBOL(<ls_refund>).
      DATA(lv_status) = to_upper( condense( CONV string( <ls_refund>-status ) ) ).
      DATA(lv_key) = CONV zif_cd_ops_trace_types=>ty_key_value( condense( <ls_refund>-key1 ) ).
      IF line_exists( lt_ok_values[ table_line = lv_status ] ).
        INSERT lv_key INTO TABLE lt_ok.
      ELSEIF line_exists( lt_failed_values[ table_line = lv_status ] ).
        INSERT lv_key INTO TABLE lt_failed.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_requests ASSIGNING <ls_request>.
      IF line_exists( lt_ok[ table_line = <ls_request>-key ] ).
        CONTINUE.
      ENDIF.
      DATA(lv_severity) = zcl_cd_coll_rules=>severity_of( iv_hours = <ls_request>-hours is_limits = ls_limits ).
      IF line_exists( lt_failed[ table_line = <ls_request>-key ] ).
        " Customer charged for a rejected premium and the refund call failed: an error at once
        lv_code     = zif_cd_coll_types=>gc_code-refund_failed.
        lv_severity = zif_ca_ops_types=>gc_severity-error.
        lv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_coll_types=>gc_msg-refund_failed
                                             iv_v1    = <ls_request>-key
                                             iv_v2    = lv_failed_list ).
      ELSEIF lv_severity IS NOT INITIAL.
        lv_code    = zif_cd_coll_types=>gc_code-refund_missing.
        lv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_coll_types=>gc_msg-refund_missing
                                            iv_v1    = <ls_request>-key
                                            iv_v2    = <ls_request>-hours ).
      ELSE.
        CONTINUE.
      ENDIF.
      INSERT lo_rules->item_of( is_request = <ls_request> iv_limit_h = ls_limits-red ) INTO TABLE lt_items.
      IF lines( lt_items ) > zif_cd_coll_types=>gc_default-max_list.
        CONTINUE.
      ENDIF.
      INSERT lo_rules->item_finding( is_request  = <ls_request>
                                     iv_code     = lv_code
                                     iv_severity = lv_severity
                                     iv_limit_h  = ls_limits-red
                                     iv_message  = lv_message ) INTO TABLE rs_result-findings.
    ENDLOOP.
    INSERT LINES OF zcl_cd_hck_exposure=>total_findings( it_totals   = zcl_cd_hck_exposure=>totals( lt_items )
                                                         iv_control  = zif_cd_coll_types=>gc_control
                                                         iv_in_hours = abap_true ) INTO TABLE rs_result-findings.
  ENDMETHOD.

ENDCLASS.
