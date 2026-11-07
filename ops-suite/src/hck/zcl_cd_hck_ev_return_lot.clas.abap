*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_return_lot.clas.abap
*& Purpose:
*& Evidence kind "returns lot item": a returns lot item (DFKKRP) with
*& SELW1 = the payment document AUGBL (confirmed join path), with lot,
*& return reason and amount in the detail. No parameters. One read for all
*& payments (shared EBS read through the payment trace repository).
*& Read-only: no returns lot is created or posted.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 4: returns lot DFKKRP by SELW1).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Evidence - returns lot item DFKKRP-SELW1 = payment doc.</p>
CLASS zcl_cd_hck_ev_return_lot DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.

ENDCLASS.



CLASS zcl_cd_hck_ev_return_lot IMPLEMENTATION.

  METHOD zif_cd_hck_evidence~collect.
    DATA(lt_docno) = zcl_cd_hck_ev_support=>docnos( it_payments ).
    IF lt_docno IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT zcl_cd_ops_factory=>get_trace_dao( )->get_returns( lt_docno ) ASSIGNING FIELD-SYMBOL(<ls_return>).
      zcl_cd_hck_ev_support=>add_hit(
        EXPORTING iv_doc1r    = <ls_return>-selw1
                  iv_detail   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_return_item
                                                       iv_v1    = <ls_return>-opbel
                                                       iv_v2    = <ls_return>-rlgrd
                                                       iv_v3    = |{ <ls_return>-amount STYLE = SIMPLE }| )
        CHANGING  ct_evidence = rs_result-evidence ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
