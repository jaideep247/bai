*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_pay_status.clas.abap
*& Purpose:
*& Evidence kind "payment status": the live payment status
*& DPAYH-ZZ_PAYMENT_STATUS of the newest payment run row of the payment
*& document (proposal runs excluded) is one of the values in PARAM1
*& (comma list, e.g. CLEARED; required). PARAM2 (optional): statuses the
*& hourly payment status job has not updated yet (e.g. ISSUED,CONFIRMED) -
*& such a payment is not found but PENDING: a purpose its other evidence
*& indicates stays in flight instead of inconsistent (the morning report
*& reports PAY_STATUS_LAG after the grace period). Every payment read gets
*& a row with its status as detail, found only for a listed value. One
*& read per payment and collection, shared with the cheque status kind
*& (ZCL_CD_HCK_EV_SUPPORT=>STATUS_OF through the payment trace repository).
*& Read-only.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 1: DPAYH-ZZ_PAYMENT_STATUS = CLEARED, configurable).
*& 2026-11-08 | PARAM2 pending statuses (confirmed status values ISSUED / CONFIRMED / CLEARED /
*&            | RETURNED / RETRIEVED / STOPPED, hourly status job); status read shared (status_of).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Evidence - DPAYH-ZZ_PAYMENT_STATUS in a list of values</p>
CLASS zcl_cd_hck_ev_pay_status DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.

ENDCLASS.



CLASS zcl_cd_hck_ev_pay_status IMPLEMENTATION.

  METHOD zif_cd_hck_evidence~collect.
    DATA(lt_values) = zcl_cd_hck_ev_support=>tokens(
                        zcl_cd_hck_ev_support=>required_param( iv_value = is_rule-param1
                                                               iv_name  = zif_cd_hck_runtime_types=>gc_rule_param-param1
                                                               is_rule  = is_rule ) ).
    DATA(lt_pending) = zcl_cd_hck_ev_support=>tokens( is_rule-param2 ).
    IF it_payments IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT zcl_cd_hck_ev_support=>status_of( it_payments ) ASSIGNING FIELD-SYMBOL(<ls_status>).
      DATA(lv_found) = xsdbool( line_exists( lt_values[ table_line = <ls_status>-status ] ) ).
      zcl_cd_hck_ev_support=>add_hit(
        EXPORTING iv_doc1r    = <ls_status>-doc1r
                  iv_found    = lv_found
                  iv_detail   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_status
                                                       iv_v1    = zif_cd_ops_trace_types=>gc_table-dpayh
                                                       iv_v2    = <ls_status>-status )
        CHANGING  ct_evidence = rs_result-evidence ).
      " Not updated yet by the payment status job: expected to follow, not missing
      IF lv_found = abap_false AND line_exists( lt_pending[ table_line = <ls_status>-status ] ).
        rs_result-evidence[ doc1r = <ls_status>-doc1r ]-pending = abap_true.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
