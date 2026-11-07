*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_stmt_cheque.clas.abap
*& Purpose:
*& Evidence kind "statement line of the cheque": a bank statement line
*& (FEBEP) whose CHECT is the last PARAM1 characters (default 13) of the
*& cheque number DFKKCR-ZTNUM of the payment document (DFKKCR-DOC1R =
*& AUGBL), as given or without leading zeros, posted on or after the
*& payment run. One cheque read and one statement-line read for all
*& payments, capped. Read-only.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 2: FEBEP-CHECT = last 13 characters of ZTNUM).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Evidence - statement line with CHECT = cheque no. suffix</p>
CLASS zcl_cd_hck_ev_stmt_cheque DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.

    "! The last iv_length characters of the cheque number (blanks removed); all when shorter
    CLASS-METHODS suffix
      IMPORTING
        iv_ztnum         TYPE clike
        iv_length        TYPE i
      RETURNING
        VALUE(rv_suffix) TYPE string.

ENDCLASS.



CLASS zcl_cd_hck_ev_stmt_cheque IMPLEMENTATION.

  METHOD zif_cd_hck_evidence~collect.
    DATA lt_ref_doc TYPE zcl_cd_hck_ev_support=>tt_ref_doc.
    DATA(lv_length) = nmax( val1 = 1
                            val2 = zcl_cd_hck_param=>int( iv_value   = is_rule-param1
                                                          iv_default = zif_cd_hck_runtime_types=>gc_check_default-ztnum_suffix ) ).
    DATA(lt_docno) = zcl_cd_hck_ev_support=>docnos( it_payments ).
    IF lt_docno IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT zcl_cd_ops_factory=>get_trace_dao( )->get_checks_by_doc( lt_docno ) ASSIGNING FIELD-SYMBOL(<ls_check>)
         WHERE ztnum IS NOT INITIAL.
      DATA(lv_suffix) = suffix( iv_ztnum = <ls_check>-ztnum iv_length = lv_length ).
      INSERT VALUE #( ref   = zcl_cd_hck_ev_support=>ref_key( lv_suffix )
                      raw   = lv_suffix
                      doc1r = <ls_check>-doc1r ) INTO TABLE lt_ref_doc.
    ENDLOOP.
    DATA(ls_lines) = zcl_cd_hck_ev_support=>lines_by_ref( it_ref_doc  = lt_ref_doc
                                                         iv_from     = zcl_cd_hck_ev_support=>earliest_run( it_payments )
                                                         iv_max_rows = iv_max_rows ).
    rs_result-capped = ls_lines-capped.
    rs_result-source = zif_cd_ops_trace_types=>gc_table-febep.
    LOOP AT ls_lines-lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      zcl_cd_hck_ev_support=>add_hit( EXPORTING iv_doc1r    = <ls_line>-doc1r
                                                iv_detail   = zcl_cd_hck_ev_support=>line_text( <ls_line>-line )
                                      CHANGING  ct_evidence = rs_result-evidence ).
    ENDLOOP.
  ENDMETHOD.


  METHOD suffix.
    rv_suffix = condense( val = CONV string( iv_ztnum ) del = ` ` ).
    DATA(lv_offset) = strlen( rv_suffix ) - iv_length.
    IF lv_offset > 0.
      rv_suffix = substring( val = rv_suffix off = lv_offset ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
