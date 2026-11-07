*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cheque_link.clas.abap
*& Purpose:
*& One rule for tying a bank statement line (FEBEP) to a cheque of the
*& register (DFKKCR), shared by the payment trace and the in-flight check
*& of the morning report: a line fits a cheque only when FEBEP-CHECT is the
*& cheque number - its last N characters, N = 0 the whole number - as
*& given or without leading zeros, AND the line's statement account (FEBKO
*& company code, house bank, account ID) is the cheque's paying house bank
*& account (company code of the payment, DFKKCR-HBKID / HKTID). Every
*& eligible cheque is kept: a line that fits several cheques of the same
*& account is ambiguous and attributed to none (no cashing evidence is
*& inherited); a line of another account never fits. A side without the
*& full account identity fits nothing. Pure logic: no SQL, no state.
*& Modification log:
*& 2026-11-07 | Initial version (design review: cheque suffix collisions across house bank accounts).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - statement line to cheque link (number + account)</p>
CLASS zcl_cd_ops_cheque_link DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! A statement line with the cheques it fits (at least one)
    TYPES:
      BEGIN OF ty_link,
        line       TYPE zif_cd_ops_trace_types=>ty_bank_line,
        "! Payment document (DFKKCR-DOC1R) of the one cheque the line fits; blank when ambiguous
        doc1r      TYPE zif_cd_ops_trace_types=>ty_docno,
        ztnum      TYPE zif_cd_ops_trace_types=>ty_ref,
        "! Eligible cheques (same number form and same account); more than one = ambiguous
        candidates TYPE i,
        "! Payment documents of every eligible cheque (ambiguous lines: each is told)
        docs       TYPE zif_cd_ops_trace_types=>tt_docno,
        "! Text of an ambiguous line (statement / line, count, account, cheque numbers)
        detail     TYPE string,
      END OF ty_link.
    TYPES tt_link TYPE STANDARD TABLE OF ty_link WITH EMPTY KEY.

    "! The last iv_length characters of the cheque number (blanks removed); all when shorter or 0
    CLASS-METHODS suffix
      IMPORTING
        iv_ztnum         TYPE clike
        iv_length        TYPE i
      RETURNING
        VALUE(rv_suffix) TYPE string.

    "! Comparable form of a reference: blanks and leading zeros removed (FEBEP-CHECT and ZTNUM may
    "! carry the number with or without them - VERIFY in QA1)
    CLASS-METHODS ref_key
      IMPORTING
        iv_ref        TYPE clike
      RETURNING
        VALUE(rv_key) TYPE string.

    "! Account identity company code / house bank / account ID; blank when a part is missing
    CLASS-METHODS account_key
      IMPORTING
        iv_bukrs      TYPE clike
        iv_hbkid      TYPE clike
        iv_hktid      TYPE clike
      RETURNING
        VALUE(rv_key) TYPE string.

    "! FEBEP-CHECT values to read for the cheques: the number form as given and without leading zeros
    CLASS-METHODS query_refs
      IMPORTING
        it_checks      TYPE zif_cd_ops_trace_types=>tt_check
        iv_length      TYPE i
      RETURNING
        VALUE(rt_refs) TYPE zif_cd_ops_trace_types=>tt_ref.

    "! The lines that fit at least one cheque (number form AND account), with every eligible cheque.
    "! it_checks carry the paying company code in BUKRS (the caller fills it from the payment).
    CLASS-METHODS link
      IMPORTING
        it_checks       TYPE zif_cd_ops_trace_types=>tt_check
        it_lines        TYPE zif_cd_ops_trace_types=>tt_bank_line
        iv_length       TYPE i
      RETURNING
        VALUE(rt_links) TYPE tt_link.

  PRIVATE SECTION.
    CONSTANTS gc_account_sep TYPE string VALUE `/`.
    CONSTANTS gc_list_sep TYPE string VALUE `, `.

ENDCLASS.



CLASS zcl_cd_ops_cheque_link IMPLEMENTATION.

  METHOD suffix.
    rv_suffix = condense( val = CONV string( iv_ztnum ) del = ` ` ).
    IF iv_length <= 0.
      RETURN.
    ENDIF.
    DATA(lv_offset) = strlen( rv_suffix ) - iv_length.
    IF lv_offset > 0.
      rv_suffix = substring( val = rv_suffix off = lv_offset ).
    ENDIF.
  ENDMETHOD.


  METHOD ref_key.
    rv_key = condense( val = CONV string( iv_ref ) del = ` ` ).
    SHIFT rv_key LEFT DELETING LEADING '0'.
  ENDMETHOD.


  METHOD account_key.
    DATA(lv_bukrs) = to_upper( condense( CONV string( iv_bukrs ) ) ).
    DATA(lv_hbkid) = to_upper( condense( CONV string( iv_hbkid ) ) ).
    DATA(lv_hktid) = to_upper( condense( CONV string( iv_hktid ) ) ).
    IF lv_bukrs IS INITIAL OR lv_hbkid IS INITIAL OR lv_hktid IS INITIAL.
      RETURN.
    ENDIF.
    rv_key = |{ lv_bukrs }{ gc_account_sep }{ lv_hbkid }{ gc_account_sep }{ lv_hktid }|.
  ENDMETHOD.


  METHOD query_refs.
    LOOP AT it_checks ASSIGNING FIELD-SYMBOL(<ls_check>) WHERE ztnum IS NOT INITIAL.
      DATA(lv_suffix) = suffix( iv_ztnum = <ls_check>-ztnum iv_length = iv_length ).
      INSERT CONV #( lv_suffix ) INTO TABLE rt_refs.
      INSERT CONV #( ref_key( lv_suffix ) ) INTO TABLE rt_refs.
    ENDLOOP.
    " Sorted unique: each form once
    DELETE rt_refs WHERE table_line IS INITIAL.
  ENDMETHOD.


  METHOD link.
    TYPES:
      BEGIN OF ty_candidate,
        ref     TYPE string,
        account TYPE string,
        ztnum   TYPE zif_cd_ops_trace_types=>ty_ref,
        doc1r   TYPE zif_cd_ops_trace_types=>ty_docno,
      END OF ty_candidate.
    DATA lt_candidates TYPE SORTED TABLE OF ty_candidate WITH NON-UNIQUE KEY ref account.
    DATA lt_numbers TYPE string_table.
    DATA ls_link TYPE ty_link.

    " Every cheque with its number form and account (a cheque without full identity fits nothing)
    LOOP AT it_checks ASSIGNING FIELD-SYMBOL(<ls_check>) WHERE ztnum IS NOT INITIAL.
      DATA(lv_account) = account_key( iv_bukrs = <ls_check>-bukrs iv_hbkid = <ls_check>-hbkid iv_hktid = <ls_check>-hktid ).
      IF lv_account IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( ref     = ref_key( suffix( iv_ztnum = <ls_check>-ztnum iv_length = iv_length ) )
                      account = lv_account
                      ztnum   = <ls_check>-ztnum
                      doc1r   = <ls_check>-doc1r ) INTO TABLE lt_candidates.
    ENDLOOP.

    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      lv_account = account_key( iv_bukrs = <ls_line>-bukrs iv_hbkid = <ls_line>-hbkid iv_hktid = <ls_line>-hktid ).
      DATA(lv_ref) = ref_key( <ls_line>-chect ).
      IF lv_account IS INITIAL OR lv_ref IS INITIAL.
        CONTINUE.
      ENDIF.
      CLEAR: ls_link, lt_numbers.
      LOOP AT lt_candidates ASSIGNING FIELD-SYMBOL(<ls_candidate>) WHERE ref = lv_ref AND account = lv_account.
        ls_link-candidates = ls_link-candidates + 1.
        INSERT <ls_candidate>-doc1r INTO TABLE ls_link-docs.
        INSERT condense( CONV string( <ls_candidate>-ztnum ) ) INTO TABLE lt_numbers.
        ls_link-doc1r = <ls_candidate>-doc1r.
        ls_link-ztnum = <ls_candidate>-ztnum.
      ENDLOOP.
      IF ls_link-candidates = 0.
        CONTINUE.
      ENDIF.
      ls_link-line = <ls_line>.
      IF ls_link-candidates > 1.
        " Several cheques of one account: no cheque inherits the line
        CLEAR: ls_link-doc1r, ls_link-ztnum.
        ls_link-detail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_trace_types=>gc_msg-cheque_ambiguous
                                                iv_v1    = |{ <ls_line>-kukey }/{ <ls_line>-esnum }|
                                                iv_v2    = ls_link-candidates
                                                iv_v3    = lv_account
                                                iv_tail  = concat_lines_of( table = lt_numbers sep = gc_list_sep ) ).
      ENDIF.
      INSERT ls_link INTO TABLE rt_links.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
