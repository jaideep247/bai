*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_chq_no_id.clas.abap
*& Purpose:
*& Check C_CHQ_NO_ID (control MISSING_CHECK_IDS, proposal P6, build R): the
*& cheque payments of the payment runs of the day before the report date
*& (DPAYH: no proposal run, payment document DOC1R filled, payment method of
*& PARAM1 METHODS) without a cheque register row (DFKKCR of the same payment
*& document and run date) that carries a cheque number - the condition the
*& reference system's test tool treats as an error. One finding per payment
*& (payment document, run, company code, method, amount, currency, deadline
*& = report date), one exposure finding per currency, metric CHEQUE_NO_ID.
*& Cheque methods still unset (blank or a placeholder) raise: no verdict,
*& never green. A read that reaches its cap is partial.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - cheque payments without cheque number</p>
"! PARAM1 METHODS=<cheque payment methods>;OFFSET=1;DAYS=1;MAX=200;ROWS=5000
"! PARAM3 CONTROL=MISSING_CHECK_IDS
CLASS zcl_cd_hck_c_chq_no_id DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

ENDCLASS.



CLASS zcl_cd_hck_c_chq_no_id IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_methods TYPE zif_cd_hck_cheque_types=>tt_pymet.
    DATA lt_items TYPE zif_cd_hck_cheque_types=>tt_item.

    DATA(lt_opt) = zcl_cd_hck_value_query=>parse( is_def-param1 ).
    DATA(lv_methods) = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = zif_cd_hck_cheque_types=>gc_spec-methods ).
    IF zcl_cd_hck_exposure=>is_unset( lv_methods ) = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e904(zcd_ops) WITH is_def-check_id zif_cd_hck_cheque_types=>gc_spec-methods.
    ENDIF.
    LOOP AT zcl_ca_ops_util=>split_list( lv_methods ) ASSIGNING FIELD-SYMBOL(<lv_method>).
      INSERT CONV #( to_upper( <lv_method> ) ) INTO TABLE lt_methods.
    ENDLOOP.
    DATA(lv_offset) = zcl_cd_hck_param=>int(
                        iv_value   = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = zif_cd_hck_cheque_types=>gc_spec-offset )
                        iv_default = zif_cd_hck_cheque_types=>gc_default-offset ).
    DATA(lv_days) = zcl_cd_hck_param=>int(
                      iv_value   = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = zif_cd_hck_cheque_types=>gc_spec-days )
                      iv_default = zif_cd_hck_cheque_types=>gc_default-run_days ).
    DATA(lv_max) = zcl_cd_hck_param=>int(
                     iv_value   = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = zif_cd_hck_cheque_types=>gc_spec-max )
                     iv_default = zif_cd_hck_cheque_types=>gc_default-max ).
    DATA(lv_rows) = zcl_cd_hck_param=>int(
                      iv_value   = zcl_cd_hck_value_query=>value( it_spec = lt_opt iv_name = zif_cd_hck_cheque_types=>gc_spec-rows )
                      iv_default = zif_cd_hck_cheque_types=>gc_default-rows ).
    DATA(lv_control) = zcl_cd_hck_value_query=>value( it_spec    = zcl_cd_hck_value_query=>parse( is_def-param3 )
                                                      iv_name    = zif_cd_hck_cheque_types=>gc_spec-control
                                                      iv_default = zif_cd_hck_cheque_types=>gc_default-no_id_ctl ).
    DATA(lv_to) = CONV d( is_context-report_date - lv_offset ).
    DATA(lv_from) = CONV d( lv_to - nmax( val1 = 0 val2 = lv_days - 1 ) ).

    DATA(lt_payments) = zcl_cd_hck_factory=>get_cheque_dao( )->get_payments_without_cheque(
                          iv_from     = lv_from
                          iv_to       = lv_to
                          it_methods  = lt_methods
                          iv_max_rows = lv_rows ).
    IF lines( lt_payments ) >= lv_rows.
      rs_result-completion = zif_cd_hck_types=>gc_completion-partial.
      rs_result-evidence   = zif_cd_hck_types=>gc_evidence-partial.
      INSERT VALUE #( object_key = is_def-check_id
                      check_code = zif_cd_hck_cheque_types=>gc_code-read_capped
                      severity   = zif_ca_ops_types=>gc_severity-warning
                      action     = zif_ca_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-read_capped
                                                          iv_v1    = is_def-check_id
                                                          iv_v2    = lv_rows
                                                          iv_v3    = lv_from
                                                          iv_v4    = lv_to ) )
        INTO TABLE rs_result-findings.
    ENDIF.

    LOOP AT lt_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      INSERT VALUE #( object_key = <ls_payment>-doc1r
                      reference  = |{ <ls_payment>-laufd }/{ <ls_payment>-laufi }|
                      bukrs      = <ls_payment>-bukrs
                      amount     = <ls_payment>-amount
                      currency   = <ls_payment>-currency
                      age        = nmax( val1 = 0 val2 = is_context-report_date - <ls_payment>-laufd )
                      event_date = <ls_payment>-laufd
                      deadline   = is_context-report_date ) INTO TABLE lt_items.
    ENDLOOP.
    INSERT VALUE #( metric = zif_cd_hck_cheque_types=>gc_metric-no_id_count dim1 = zif_cd_hck_types=>gc_default_key
                    value = lines( lt_items ) ) INTO TABLE rs_result-metrics.

    LOOP AT lt_payments ASSIGNING <ls_payment> FROM 1 TO lv_max.
      DATA(ls_item) = lt_items[ sy-tabix ].
      INSERT VALUE #(
        object_key    = ls_item-object_key
        check_code    = zif_cd_hck_cheque_types=>gc_code-cheque_no_id
        severity      = zif_ca_ops_types=>gc_severity-error
        action        = zif_ca_ops_types=>gc_action-exception
        reference     = ls_item-reference
        amount        = ls_item-amount
        currency      = ls_item-currency
        company_code  = ls_item-bukrs
        pay_method    = <ls_payment>-pymet
        business_date = ls_item-event_date
        item_count    = 1
        message       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_cheque_types=>gc_msg-cheque_no_id
                                               iv_v1    = <ls_payment>-doc1r
                                               iv_v2    = ls_item-reference
                                               iv_v3    = <ls_payment>-pymet
                                               iv_v4    = <ls_payment>-hbkid )
        context       = zcl_cd_hck_exposure=>context( is_item     = ls_item
                                                      iv_control  = lv_control
                                                      iv_evidence = |{ <ls_payment>-doc1r } { ls_item-reference }| ) )
        INTO TABLE rs_result-findings.
    ENDLOOP.
    INSERT LINES OF zcl_cd_hck_exposure=>total_findings( it_totals  = zcl_cd_hck_exposure=>totals( lt_items )
                                                         iv_control = lv_control ) INTO TABLE rs_result-findings.
  ENDMETHOD.

ENDCLASS.
