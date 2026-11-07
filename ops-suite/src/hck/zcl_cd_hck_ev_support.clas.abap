*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_support.clas.abap
*& Purpose:
*& Shared helpers of the evidence plug-ins of the in-flight check: payment
*& reference forms (as stored and without leading zeros), comma lists,
*& document keys, run-date window, required rule parameters, evidence rows
*& the one statement-line read by reference (FEBEP-CHECT through the
*& payment trace repository) and the one G/L line read by XREF2 (runtime
*& DAO), mapped back to the payment document. No SQL of its own;
*& read-only.
*& Modification log:
*& 2026-11-07 | Initial version (clearing / return evidence as plug-ins, user rule 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - helpers of the payment evidence plug-ins</p>
CLASS zcl_cd_hck_ev_support DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Statement line of a payment document
    TYPES:
      BEGIN OF ty_doc_line,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
        line  TYPE zif_cd_ops_trace_types=>ty_bank_line,
      END OF ty_doc_line.
    TYPES tt_doc_line TYPE STANDARD TABLE OF ty_doc_line WITH EMPTY KEY
                      WITH NON-UNIQUE SORTED KEY by_doc COMPONENTS doc1r.
    TYPES:
      BEGIN OF ty_doc_lines,
        lines  TYPE tt_doc_line,
        capped TYPE abap_bool,
      END OF ty_doc_lines.
    "! G/L line of a payment document (found by company code + XREF2 = AUGBL)
    TYPES:
      BEGIN OF ty_gl_doc,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
        line  TYPE zif_cd_hck_runtime_types=>ty_gl_xref2_line,
      END OF ty_gl_doc.
    TYPES tt_gl_doc TYPE STANDARD TABLE OF ty_gl_doc WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_gl_docs,
        lines  TYPE tt_gl_doc,
        capped TYPE abap_bool,
      END OF ty_gl_docs.

    "! Normalised reference (REF_KEY) and its stored form -> payment document
    TYPES:
      BEGIN OF ty_ref_doc,
        ref   TYPE string,
        raw   TYPE string,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
      END OF ty_ref_doc.
    TYPES tt_ref_doc TYPE HASHED TABLE OF ty_ref_doc WITH UNIQUE KEY ref.

    "! Reference without blanks and leading zeros (FEBEP-CHECT, XREF2 and ZTNUM may carry the
    "! number with or without them - VERIFY in QA1)
    CLASS-METHODS ref_key
      IMPORTING
        iv_ref        TYPE clike
      RETURNING
        VALUE(rv_key) TYPE string.

    "! Upper-case tokens of a comma list
    CLASS-METHODS tokens
      IMPORTING
        iv_list          TYPE clike
      RETURNING
        VALUE(rt_tokens) TYPE string_table.

    CLASS-METHODS docnos
      IMPORTING
        it_payments     TYPE zif_cd_hck_runtime_types=>tt_issued_payment
      RETURNING
        VALUE(rt_docno) TYPE zif_cd_ops_trace_types=>tt_docno.

    "! Earliest run date of the payments (statement lines are read from there)
    CLASS-METHODS earliest_run
      IMPORTING
        it_payments    TYPE zif_cd_hck_runtime_types=>tt_issued_payment
      RETURNING
        VALUE(rv_date) TYPE d.

    "! The parameter value of a rule, raising when it is blank
    "! @raising zcx_cd_ops_error | parameter blank (message 665)
    CLASS-METHODS required_param
      IMPORTING
        iv_value        TYPE clike
        iv_name         TYPE clike
        is_rule         TYPE zif_cd_hck_runtime_types=>ty_clr_rule
      RETURNING
        VALUE(rv_value) TYPE string
      RAISING
        zcx_cd_ops_error.

    "! Statement lines whose FEBEP-CHECT is one of the references (as given and normalised),
    "! posted on or after iv_from, with the payment document of the reference; one read
    CLASS-METHODS lines_by_ref
      IMPORTING
        it_ref_doc      TYPE tt_ref_doc
        iv_from         TYPE d
        iv_max_rows     TYPE i
      RETURNING
        VALUE(rs_lines) TYPE ty_doc_lines.

    "! Statement lines of the payment documents (FEBEP-CHECT = AUGBL), from the earliest run
    CLASS-METHODS lines_by_doc
      IMPORTING
        it_payments     TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        iv_max_rows     TYPE i
      RETURNING
        VALUE(rs_lines) TYPE ty_doc_lines.

    "! G/L lines (BSEG) of the payment documents by the stable key XREF2 = AUGBL (as stored and
    "! normalised) in the company code, fiscal years of the run dates up to the following year
    "! (calendar fiscal year assumed - VERIFY), optionally only the G/L accounts of iv_accounts
    CLASS-METHODS gl_lines_by_doc
      IMPORTING
        it_payments     TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        iv_accounts     TYPE clike
        iv_max_rows     TYPE i
      RETURNING
        VALUE(rs_lines) TYPE ty_gl_docs.

    "! Adds one hit to the evidence of a payment (found, detail appended)
    CLASS-METHODS add_hit
      IMPORTING
        iv_doc1r    TYPE zif_cd_hck_runtime_types=>ty_docno
        iv_detail   TYPE string
        iv_found    TYPE abap_bool DEFAULT abap_true
      CHANGING
        ct_evidence TYPE zif_cd_hck_runtime_types=>tt_evidence.

    "! Detail text of a statement line (statement / line, BAI code, amount, date)
    CLASS-METHODS line_text
      IMPORTING
        is_line        TYPE zif_cd_ops_trace_types=>ty_bank_line
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
    CONSTANTS gc_detail_sep TYPE string VALUE `; `.

ENDCLASS.



CLASS zcl_cd_hck_ev_support IMPLEMENTATION.

  METHOD ref_key.
    rv_key = condense( val = CONV string( iv_ref ) del = ` ` ).
    SHIFT rv_key LEFT DELETING LEADING '0'.
  ENDMETHOD.


  METHOD tokens.
    LOOP AT zcl_cd_ops_util=>split_list( iv_list ) ASSIGNING FIELD-SYMBOL(<lv_token>).
      INSERT to_upper( condense( <lv_token> ) ) INTO TABLE rt_tokens.
    ENDLOOP.
  ENDMETHOD.


  METHOD docnos.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      INSERT <ls_payment>-doc1r INTO TABLE rt_docno.
    ENDLOOP.
  ENDMETHOD.


  METHOD earliest_run.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF rv_date IS INITIAL OR <ls_payment>-laufd < rv_date.
        rv_date = <ls_payment>-laufd.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD required_param.
    rv_value = condense( CONV string( iv_value ) ).
    IF rv_value IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e665(zcd_ops) WITH is_rule-evidence_class iv_name |{ is_rule-flow }{ is_rule-method_class }|
                                   is_rule-purpose.
    ENDIF.
  ENDMETHOD.


  METHOD lines_by_ref.
    DATA lt_refs TYPE zif_cd_ops_trace_types=>tt_ref.
    IF it_ref_doc IS INITIAL OR iv_max_rows <= 0.
      RETURN.
    ENDIF.
    LOOP AT it_ref_doc ASSIGNING FIELD-SYMBOL(<ls_ref>).
      INSERT CONV #( <ls_ref>-ref ) INTO TABLE lt_refs.
      " The stored form (e.g. the CHAR 12 document number with leading zeros)
      INSERT CONV #( <ls_ref>-raw ) INTO TABLE lt_refs.
    ENDLOOP.
    DATA(lt_lines) = zcl_cd_ops_factory=>get_trace_dao( )->get_bank_lines( it_ref      = lt_refs
                                                                         iv_from     = iv_from
                                                                         iv_max_rows = iv_max_rows ).
    rs_lines-capped = xsdbool( lines( lt_lines ) >= iv_max_rows ).
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      READ TABLE it_ref_doc ASSIGNING FIELD-SYMBOL(<ls_doc>) WITH TABLE KEY ref = ref_key( <ls_line>-chect ).
      IF sy-subrc = 0.
        INSERT VALUE #( doc1r = <ls_doc>-doc1r line = <ls_line> ) INTO TABLE rs_lines-lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD lines_by_doc.
    DATA lt_ref_doc TYPE tt_ref_doc.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      INSERT VALUE #( ref   = ref_key( <ls_payment>-doc1r )
                      raw   = <ls_payment>-doc1r
                      doc1r = <ls_payment>-doc1r ) INTO TABLE lt_ref_doc.
    ENDLOOP.
    rs_lines = lines_by_ref( it_ref_doc  = lt_ref_doc
                             iv_from     = earliest_run( it_payments )
                             iv_max_rows = iv_max_rows ).
  ENDMETHOD.


  METHOD gl_lines_by_doc.
    TYPES:
      BEGIN OF ty_key_doc,
        bukrs TYPE c LENGTH 4,
        ref   TYPE string,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
      END OF ty_key_doc.
    DATA lt_key_doc TYPE HASHED TABLE OF ty_key_doc WITH UNIQUE KEY bukrs ref.
    DATA lt_keys TYPE zif_cd_hck_runtime_types=>tt_xref2_key.
    DATA lt_hkont TYPE zif_cd_hck_runtime_types=>tt_hkont.
    DATA lv_last TYPE d.
    IF it_payments IS INITIAL OR iv_max_rows <= 0.
      RETURN.
    ENDIF.
    LOOP AT tokens( iv_accounts ) ASSIGNING FIELD-SYMBOL(<lv_account>).
      INSERT CONV #( |{ <lv_account> ALPHA = IN WIDTH = 10 }| ) INTO TABLE lt_hkont.
    ENDLOOP.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      DATA(lv_ref) = ref_key( <ls_payment>-doc1r ).
      INSERT VALUE #( bukrs = <ls_payment>-bukrs xref2 = <ls_payment>-doc1r ) INTO TABLE lt_keys.
      INSERT VALUE #( bukrs = <ls_payment>-bukrs xref2 = lv_ref ) INTO TABLE lt_keys.
      INSERT VALUE #( bukrs = <ls_payment>-bukrs ref = lv_ref doc1r = <ls_payment>-doc1r ) INTO TABLE lt_key_doc.
      lv_last = nmax( val1 = lv_last val2 = <ls_payment>-laufd ).
    ENDLOOP.
    DATA(lv_first) = earliest_run( it_payments ).
    DATA(lt_lines) = zcl_cd_hck_factory=>get_runtime_dao( )->get_gl_lines_by_xref2(
                       it_keys       = lt_keys
                       iv_gjahr_from = CONV #( lv_first(4) )
                       iv_gjahr_to   = CONV #( lv_last(4) + 1 )
                       it_hkont      = lt_hkont
                       iv_max_rows   = iv_max_rows ).
    rs_lines-capped = xsdbool( lines( lt_lines ) >= iv_max_rows ).
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      READ TABLE lt_key_doc ASSIGNING FIELD-SYMBOL(<ls_doc>)
           WITH TABLE KEY bukrs = <ls_line>-bukrs ref = ref_key( <ls_line>-xref2 ).
      IF sy-subrc = 0.
        INSERT VALUE #( doc1r = <ls_doc>-doc1r line = <ls_line> ) INTO TABLE rs_lines-lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_hit.
    READ TABLE ct_evidence ASSIGNING FIELD-SYMBOL(<ls_evidence>) WITH TABLE KEY doc1r = iv_doc1r.
    IF sy-subrc <> 0.
      INSERT VALUE #( doc1r = iv_doc1r ) INTO TABLE ct_evidence ASSIGNING <ls_evidence>.
    ENDIF.
    IF iv_found = abap_true.
      <ls_evidence>-found = abap_true.
      <ls_evidence>-hits  = <ls_evidence>-hits + 1.
    ENDIF.
    IF iv_detail IS NOT INITIAL.
      <ls_evidence>-detail = COND #( WHEN <ls_evidence>-detail IS INITIAL THEN iv_detail
                                     ELSE |{ <ls_evidence>-detail }{ gc_detail_sep }{ iv_detail }| ).
    ENDIF.
  ENDMETHOD.


  METHOD line_text.
    rv_text = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_bank_line
                                     iv_v1    = |{ is_line-kukey }/{ is_line-esnum }|
                                     iv_v2    = is_line-vorgc
                                     iv_v3    = |{ is_line-kwbtr STYLE = SIMPLE }|
                                     iv_v4    = |{ is_line-budat DATE = ISO }| ).
  ENDMETHOD.

ENDCLASS.
