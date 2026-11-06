*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_util.clas.abap
*& Purpose:
*& Stateless helpers. No database access.
*& B=4, E=3, W=2, I=1, other=0
*& Worst severity in a finding list (blank when empty)
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | text( ): user-facing texts are ZCD_OPS messages (phase 5, remove hardcoding).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - pure helper functions</p>
"! Stateless helpers. No database access.
CLASS zcl_cd_ops_util DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! Text of message ZCD_OPS / iv_msgno with up to four variables. The one place where
    "! the suite builds a user-facing text: texts are T100 text elements (SE91,
    "! translatable), never literals in code. Variables keep string-template formatting
    "! and are cut at 50 characters (message variable length).
    CLASS-METHODS text
      IMPORTING
        iv_msgno       TYPE zif_cd_ops_types=>ty_msgno
        iv_v1          TYPE simple OPTIONAL
        iv_v2          TYPE simple OPTIONAL
        iv_v3          TYPE simple OPTIONAL
        iv_v4          TYPE simple OPTIONAL
        "! Appended after the message text, not truncated (exception texts, messages)
        iv_tail        TYPE string OPTIONAL
      RETURNING
        VALUE(rv_text) TYPE string.

    "! B=4, E=3, W=2, I=1, other=0
    CLASS-METHODS severity_rank
      IMPORTING
        iv_severity    TYPE zif_cd_ops_types=>ty_severity
      RETURNING
        VALUE(rv_rank) TYPE i.

    "! Worst severity in a finding list (blank when empty)
    CLASS-METHODS worst_severity
      IMPORTING
        it_findings        TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rv_severity) TYPE zif_cd_ops_types=>ty_severity.

    "! RAG from a measured value and amber/red thresholds.
    "! iv_higher_is_worse = abap_true: value >= red -> R, >= amber -> A.
    CLASS-METHODS rag_from_value
      IMPORTING
        iv_value           TYPE decfloat34
        iv_amber           TYPE decfloat34
        iv_red             TYPE decfloat34
        iv_higher_is_worse TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rv_rag)      TYPE zif_cd_ops_types=>ty_rag.

    "! RAG from findings: any B/E -> R, any W -> A, else G
    CLASS-METHODS rag_from_findings
      IMPORTING
        it_findings   TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rv_rag) TYPE zif_cd_ops_types=>ty_rag.

    "! Worse of two RAG values (R > A > G > grey)
    CLASS-METHODS worse_rag
      IMPORTING
        iv_rag1       TYPE zif_cd_ops_types=>ty_rag
        iv_rag2       TYPE zif_cd_ops_types=>ty_rag
      RETURNING
        VALUE(rv_rag) TYPE zif_cd_ops_types=>ty_rag.

    "! Normalise a bank reference to a document key:
    "! condense, strip leading zeros, left-pad with zeros to iv_length.
    "! iv_length = 0 returns the condensed reference unchanged.
    CLASS-METHODS normalize_key
      IMPORTING
        iv_reference  TYPE clike
        iv_length     TYPE i
      RETURNING
        VALUE(rv_key) TYPE string.

    "! Escape &, <, >, " for HTML output
    CLASS-METHODS html_escape
      IMPORTING
        iv_text        TYPE clike
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Split a comma/semicolon separated list into trimmed, non-empty tokens
    CLASS-METHODS split_list
      IMPORTING
        iv_list          TYPE clike
      RETURNING
        VALUE(rt_tokens) TYPE string_table.

    "! Milliseconds between two long time stamps
    CLASS-METHODS elapsed_ms
      IMPORTING
        iv_from      TYPE timestampl
        iv_to        TYPE timestampl
      RETURNING
        VALUE(rv_ms) TYPE i.

    "! Safe string to decimal; returns iv_default on conversion error
    CLASS-METHODS to_decimal
      IMPORTING
        iv_value        TYPE clike
        iv_default      TYPE decfloat34 DEFAULT 0
      RETURNING
        VALUE(rv_value) TYPE decfloat34.

ENDCLASS.



CLASS zcl_cd_ops_util IMPLEMENTATION.

  METHOD text.
    DATA lv_v1 TYPE zif_cd_ops_types=>ty_msgv.
    DATA lv_v2 TYPE zif_cd_ops_types=>ty_msgv.
    DATA lv_v3 TYPE zif_cd_ops_types=>ty_msgv.
    DATA lv_v4 TYPE zif_cd_ops_types=>ty_msgv.
    IF iv_v1 IS SUPPLIED.
      lv_v1 = |{ iv_v1 }|.
    ENDIF.
    IF iv_v2 IS SUPPLIED.
      lv_v2 = |{ iv_v2 }|.
    ENDIF.
    IF iv_v3 IS SUPPLIED.
      lv_v3 = |{ iv_v3 }|.
    ENDIF.
    IF iv_v4 IS SUPPLIED.
      lv_v4 = |{ iv_v4 }|.
    ENDIF.
    MESSAGE ID zif_cd_ops_types=>gc_message_class TYPE zif_cd_ops_types=>gc_msgty_info NUMBER iv_msgno
            WITH lv_v1 lv_v2 lv_v3 lv_v4 INTO rv_text.
    IF iv_tail IS NOT INITIAL.
      rv_text = |{ rv_text } { iv_tail }|.
    ENDIF.
  ENDMETHOD.


  METHOD severity_rank.
    rv_rank = SWITCH #( iv_severity
                        WHEN zif_cd_ops_types=>gc_severity-block   THEN 4
                        WHEN zif_cd_ops_types=>gc_severity-error   THEN 3
                        WHEN zif_cd_ops_types=>gc_severity-warning THEN 2
                        WHEN zif_cd_ops_types=>gc_severity-info    THEN 1
                        ELSE 0 ).
  ENDMETHOD.


  METHOD worst_severity.
    DATA lv_best_rank TYPE i.
    LOOP AT it_findings INTO DATA(ls_finding).
      DATA(lv_rank) = severity_rank( ls_finding-severity ).
      IF lv_rank > lv_best_rank.
        lv_best_rank = lv_rank.
        rv_severity  = ls_finding-severity.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD rag_from_value.
    IF iv_higher_is_worse = abap_true.
      rv_rag = COND #( WHEN iv_value >= iv_red   THEN zif_cd_ops_types=>gc_rag-red
                       WHEN iv_value >= iv_amber THEN zif_cd_ops_types=>gc_rag-amber
                       ELSE zif_cd_ops_types=>gc_rag-green ).
    ELSE.
      rv_rag = COND #( WHEN iv_value <= iv_red   THEN zif_cd_ops_types=>gc_rag-red
                       WHEN iv_value <= iv_amber THEN zif_cd_ops_types=>gc_rag-amber
                       ELSE zif_cd_ops_types=>gc_rag-green ).
    ENDIF.
  ENDMETHOD.


  METHOD rag_from_findings.
    DATA(lv_rank) = severity_rank( worst_severity( it_findings ) ).
    rv_rag = COND #( WHEN lv_rank >= 3 THEN zif_cd_ops_types=>gc_rag-red
                     WHEN lv_rank = 2  THEN zif_cd_ops_types=>gc_rag-amber
                     ELSE zif_cd_ops_types=>gc_rag-green ).
  ENDMETHOD.


  METHOD worse_rag.
    DATA(lv_rank1) = SWITCH i( iv_rag1 WHEN zif_cd_ops_types=>gc_rag-red   THEN 3
                                       WHEN zif_cd_ops_types=>gc_rag-amber THEN 2
                                       WHEN zif_cd_ops_types=>gc_rag-green THEN 1
                                       ELSE 0 ).
    DATA(lv_rank2) = SWITCH i( iv_rag2 WHEN zif_cd_ops_types=>gc_rag-red   THEN 3
                                       WHEN zif_cd_ops_types=>gc_rag-amber THEN 2
                                       WHEN zif_cd_ops_types=>gc_rag-green THEN 1
                                       ELSE 0 ).
    rv_rag = COND #( WHEN lv_rank1 >= lv_rank2 THEN iv_rag1 ELSE iv_rag2 ).
  ENDMETHOD.


  METHOD normalize_key.
    rv_key = condense( val = CONV string( iv_reference ) del = ` ` ).
    IF iv_length <= 0 OR rv_key IS INITIAL.
      RETURN.
    ENDIF.
    SHIFT rv_key LEFT DELETING LEADING '0'.
    IF strlen( rv_key ) < iv_length.
      rv_key = |{ rv_key WIDTH = iv_length ALIGN = RIGHT PAD = '0' }|.
    ENDIF.
  ENDMETHOD.


  METHOD html_escape.
    rv_text = escape( val = CONV string( iv_text ) format = cl_abap_format=>e_html_text ).
  ENDMETHOD.


  METHOD split_list.
    DATA(lv_list) = translate( val = CONV string( iv_list ) from = `;` to = `,` ).
    SPLIT lv_list AT `,` INTO TABLE DATA(lt_raw).
    LOOP AT lt_raw INTO DATA(lv_token).
      lv_token = condense( lv_token ).
      IF lv_token IS NOT INITIAL.
        INSERT lv_token INTO TABLE rt_tokens.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD elapsed_ms.
    TRY.
        DATA(lv_seconds) = cl_abap_tstmp=>subtract( tstmp1 = iv_to
                                                    tstmp2 = iv_from ).
        rv_ms = lv_seconds * 1000.
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        rv_ms = 0.
    ENDTRY.
  ENDMETHOD.


  METHOD to_decimal.
    DATA(lv_text) = condense( CONV string( iv_value ) ).
    IF lv_text IS INITIAL.
      rv_value = iv_default.
      RETURN.
    ENDIF.
    TRY.
        rv_value = lv_text.
      CATCH cx_sy_conversion_error.
        rv_value = iv_default.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
