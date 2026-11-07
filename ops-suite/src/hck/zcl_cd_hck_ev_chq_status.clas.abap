*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_chq_status.clas.abap
*& Purpose:
*& Evidence kind "cheque status": a cheque of the payment document
*& (DFKKCR-DOC1R = AUGBL) has its status DFKKCR-STATE in PARAM1 (comma
*& list; confirmed values B = cashed, V = voided, blank = open; required).
*& Every cheque read adds its status to the detail; found only for a
*& listed value. One read for all payments (payment trace repository).
*& Read-only: no cheque status is changed.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 2: cheque status B / V / blank, field STATE confirmed).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Evidence - cheque status DFKKCR-STATE in a list of values</p>
CLASS zcl_cd_hck_ev_chq_status DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.

ENDCLASS.



CLASS zcl_cd_hck_ev_chq_status IMPLEMENTATION.

  METHOD zif_cd_hck_evidence~collect.
    DATA(lt_values) = zcl_cd_hck_ev_support=>tokens(
                        zcl_cd_hck_ev_support=>required_param( iv_value = is_rule-param1
                                                               iv_name  = zif_cd_hck_runtime_types=>gc_rule_param-param1
                                                               is_rule  = is_rule ) ).
    DATA(lt_docno) = zcl_cd_hck_ev_support=>docnos( it_payments ).
    IF lt_docno IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT zcl_cd_ops_factory=>get_trace_dao( )->get_checks_by_doc( lt_docno ) ASSIGNING FIELD-SYMBOL(<ls_check>).
      DATA(lv_state) = to_upper( condense( CONV string( <ls_check>-state ) ) ).
      zcl_cd_hck_ev_support=>add_hit(
        EXPORTING iv_doc1r    = <ls_check>-doc1r
                  iv_found    = xsdbool( lv_state IS NOT INITIAL AND line_exists( lt_values[ table_line = lv_state ] ) )
                  iv_detail   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_status
                                                       iv_v1    = zif_cd_ops_trace_types=>gc_table-dfkkcr
                                                       iv_v2    = lv_state )
        CHANGING  ct_evidence = rs_result-evidence ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
