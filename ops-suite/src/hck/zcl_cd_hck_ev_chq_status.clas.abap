*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_chq_status.clas.abap
*& Purpose:
*& Evidence kind "cheque status": a cheque of the payment document
*& (DFKKCR-DOC1R = AUGBL) has its status DFKKCR-STATE in PARAM1 (comma
*& list; confirmed values B = cashed, V = voided, blank = open or returned;
*& token BLANK = the blank state; required).
*& Every cheque read adds its status to the detail; found only for a
*& listed value of the deciding cheque of the payment (newest not voided:
*& a voided cheque and its reissue never make the payment voided). The
*& cheques come from the read shared with the other cheque kinds
*& (ZCL_CD_HCK_EV_SUPPORT=>CHECKS_OF: one DFKKCR read per payment and run).
*& Read-only: no cheque status is changed.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 2: cheque status B / V / blank, field STATE confirmed).
*& 2026-11-07 | Token BLANK for the blank state (a returned cheque keeps STATE blank today).
*& 2026-11-07 | Code review: the deciding (live) cheque only; DFKKCR read shared (checks_of).
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
    IF it_payments IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_checks) = zcl_cd_hck_ev_support=>checks_of( it_payments ).
    DATA(lt_live) = zcl_cd_hck_ev_support=>live_cheques( lt_checks ).
    LOOP AT lt_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
      DATA(lv_state) = to_upper( condense( CONV string( <ls_check>-state ) ) ).
      " Only the deciding cheque of the payment counts; the others are shown
      DATA(ls_live) = VALUE zif_cd_ops_trace_types=>ty_check( lt_live[ doc1r = <ls_check>-doc1r ] OPTIONAL ).
      DATA(lv_live) = xsdbool( ls_live-ztnum = <ls_check>-ztnum AND ls_live-hbkid = <ls_check>-hbkid
                               AND ls_live-hktid = <ls_check>-hktid ).
      DATA(lv_listed) = xsdbool( ( lv_state IS NOT INITIAL AND line_exists( lt_values[ table_line = lv_state ] ) )
                                 OR ( lv_state IS INITIAL
                                      AND line_exists( lt_values[ table_line = zif_cd_hck_runtime_types=>gc_state_blank ] ) ) ).
      zcl_cd_hck_ev_support=>add_hit(
        EXPORTING iv_doc1r    = <ls_check>-doc1r
                  iv_found    = xsdbool( lv_live = abap_true AND lv_listed = abap_true )
                  iv_detail   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_status
                                                       iv_v1    = zif_cd_ops_trace_types=>gc_table-dfkkcr
                                                       iv_v2    = lv_state )
        CHANGING  ct_evidence = rs_result-evidence ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
