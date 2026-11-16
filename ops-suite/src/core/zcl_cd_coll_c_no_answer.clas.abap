*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_coll_c_no_answer.clas.abap
*& Purpose:
*& Check COLL_R2_SCHEDULED of process BASE_REQ_LIFE (area CD_COLL, control
*& BASE_REJECTS, proposal P2): a collections payment request whose latest
*& status is SCHEDULED (sent to the source BASE via PRISM, confirmed
*& 2026-11-10) without an answer of the source (SRCPOSTED or a reject)
*& after COLL_R2_AMBER_H hours is a warning, after COLL_R2_RED_H hours an
*& error - one finding per request with company code, amount, currency,
*& age in hours, deadline and the control, one exposure finding per
*& currency. Source and limits are parameters (area CD_OPS); blank or a
*& placeholder raises (the runner records CHECK_FAILED: no verdict, never
*& green). Registered in ZCA_OPS_CHECK; run by ZCL_CA_OPS_CHECK_RUNNER,
*& which stamps GROUP1 = process and GROUP2 = check. Read only.
*& Modification log:
*& 2026-11-10 | Initial version (scaffold tools/abaptools/new_process.py).
*& 2026-11-16 | Completed (build R): rule R2 over the configured request status source, limits in hours.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Check COLL_R2_SCHEDULED</p>
CLASS zcl_cd_coll_c_no_answer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

ENDCLASS.



CLASS zcl_cd_coll_c_no_answer IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    DATA lt_items TYPE zif_cd_hck_cheque_types=>tt_item.
    DATA(lo_rules) = NEW zcl_cd_coll_rules( is_check = is_check is_context = is_context ).
    DATA(ls_limits) = lo_rules->limits( iv_amber = zif_cd_coll_types=>gc_param-r2_amber
                                        iv_red   = zif_cd_coll_types=>gc_param-r2_red ).
    DATA(lt_requests) = lo_rules->requests_in( zif_cd_coll_types=>gc_status_scheduled ).
    rs_result-item_count = lines( lt_requests ).
    rs_result-partial    = lo_rules->capped( ).
    IF rs_result-partial = abap_true.
      INSERT lo_rules->capped_finding( ) INTO TABLE rs_result-findings.
    ENDIF.
    LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      DATA(lv_severity) = zcl_cd_coll_rules=>severity_of( iv_hours = <ls_request>-hours is_limits = ls_limits ).
      IF lv_severity IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT lo_rules->item_of( is_request = <ls_request> iv_limit_h = ls_limits-red ) INTO TABLE lt_items.
      IF lines( lt_items ) > zif_cd_coll_types=>gc_default-max_list.
        CONTINUE.
      ENDIF.
      INSERT lo_rules->item_finding(
               is_request = <ls_request>
               iv_code    = zif_cd_coll_types=>gc_code-no_answer
               iv_severity = lv_severity
               iv_limit_h = ls_limits-red
               iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_coll_types=>gc_msg-no_answer
                                                   iv_v1    = <ls_request>-key
                                                   iv_v2    = <ls_request>-hours ) ) INTO TABLE rs_result-findings.
    ENDLOOP.
    INSERT LINES OF zcl_cd_hck_exposure=>total_findings( it_totals   = zcl_cd_hck_exposure=>totals( lt_items )
                                                         iv_control  = zif_cd_coll_types=>gc_control
                                                         iv_in_hours = abap_true ) INTO TABLE rs_result-findings.
  ENDMETHOD.

ENDCLASS.
