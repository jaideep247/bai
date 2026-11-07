*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_pay_status.clas.abap
*& Purpose:
*& Evidence kind "payment status": the live payment status
*& DPAYH-ZZ_PAYMENT_STATUS of the newest payment run row of the payment
*& document (proposal runs excluded) is one of the values in PARAM1
*& (comma list, e.g. CLEARED; required). Every payment read gets a row
*& with its status as detail, found only for a listed value. One read for
*& all payments (shared EBS read through the payment trace repository).
*& Read-only.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 1: DPAYH-ZZ_PAYMENT_STATUS = CLEARED, configurable).
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
    DATA lt_seen TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA(lt_values) = zcl_cd_hck_ev_support=>tokens(
                        zcl_cd_hck_ev_support=>required_param( iv_value = is_rule-param1
                                                               iv_name  = zif_cd_hck_runtime_types=>gc_rule_param-param1
                                                               is_rule  = is_rule ) ).
    DATA(lt_docno) = zcl_cd_hck_ev_support=>docnos( it_payments ).
    IF lt_docno IS INITIAL.
      RETURN.
    ENDIF.
    " Newest run first per document (shared read): the first row of a document is its status
    LOOP AT zcl_cd_ops_factory=>get_trace_dao( )->get_payment_runs( lt_docno ) ASSIGNING FIELD-SYMBOL(<ls_run>).
      INSERT <ls_run>-doc1r INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_status) = to_upper( condense( CONV string( <ls_run>-status ) ) ).
      zcl_cd_hck_ev_support=>add_hit(
        EXPORTING iv_doc1r    = <ls_run>-doc1r
                  iv_found    = xsdbool( line_exists( lt_values[ table_line = lv_status ] ) )
                  iv_detail   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_status
                                                       iv_v1    = zif_cd_ops_trace_types=>gc_table-dpayh
                                                       iv_v2    = lv_status )
        CHANGING  ct_evidence = rs_result-evidence ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
