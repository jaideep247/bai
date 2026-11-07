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
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Configured patterns are PCRE (user decision 2026-11-06): pcre_valid, pcre_match
*&              (whole value, case-insensitive), pcre_literals (specificity).
*& 2026-11-07 | param_int: the one integer-parameter helper (replaces five private copies).
*& 2026-11-07 | rag_from_value removed (no caller).
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

    "! Configured pattern compiles as PCRE (case-insensitive, as it is matched).
    "! Blank is valid. The one check behind every pattern validation (configuration
    "! apps, runtime configuration load, pattern check and migration reports).
    CLASS-METHODS pcre_valid
      IMPORTING
        iv_pattern      TYPE clike
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! The complete value matches the PCRE pattern, case ignored - never a partial
    "! match. Trailing blanks of a character field are not part of value or pattern.
    "! An invalid pattern never matches: callers validate with pcre_valid first and
    "! report an invalid pattern as a configuration finding.
    CLASS-METHODS pcre_match
      IMPORTING
        iv_value        TYPE clike
        iv_pattern      TYPE clike
      RETURNING
        VALUE(rv_match) TYPE abap_bool.

    "! The complete value matches at least one of the patterns (see pcre_match)
    CLASS-METHODS pcre_match_any
      IMPORTING
        iv_value        TYPE clike
        it_patterns     TYPE zif_cd_ops_types=>tt_pcre
      RETURNING
        VALUE(rv_match) TYPE abap_bool.

    "! First pattern of the list that is not valid PCRE (blank = all valid)
    CLASS-METHODS pcre_first_invalid
      IMPORTING
        it_patterns       TYPE zif_cd_ops_types=>tt_pcre
      RETURNING
        VALUE(rv_pattern) TYPE string.

    "! Literal characters of a PCRE pattern (escaped characters count, character
    "! classes, quantifiers and metacharacters do not): the more, the more specific
    CLASS-METHODS pcre_literals
      IMPORTING
        iv_pattern      TYPE clike
      RETURNING
        VALUE(rv_count) TYPE i.

    "! Integer parameter: the value of iv_name, iv_default when not maintained, blank or not
    "! a number (decimals rounded). The one helper for numeric parameters of every area.
    CLASS-METHODS param_int
      IMPORTING
        io_params       TYPE REF TO zif_cd_ops_params
        iv_name         TYPE zif_cd_ops_types=>ty_param_name
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

    "! Safe string to decimal; returns iv_default on conversion error
    CLASS-METHODS to_decimal
      IMPORTING
        iv_value        TYPE clike
        iv_default      TYPE decfloat34 DEFAULT 0
      RETURNING
        VALUE(rv_value) TYPE decfloat34.

  PRIVATE SECTION.
    "! PCRE syntax characters (not text): escape, class and quantifier brackets,
    "! metacharacters without a literal meaning, characters of an escape sequence
    CONSTANTS:
      BEGIN OF gc_pcre,
        escape      TYPE string VALUE `\`,
        class_open  TYPE string VALUE `[`,
        class_close TYPE string VALUE `]`,
        count_open  TYPE string VALUE `{`,
        count_close TYPE string VALUE `}`,
        meta        TYPE string VALUE `.*+?()|^$`,
        word        TYPE string VALUE `abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789`,
      END OF gc_pcre.

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
    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      DATA(lv_rank) = severity_rank( <ls_finding>-severity ).
      IF lv_rank > lv_best_rank.
        lv_best_rank = lv_rank.
        rv_severity  = <ls_finding>-severity.
      ENDIF.
    ENDLOOP.
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


  METHOD pcre_valid.
    TRY.
        cl_abap_regex=>create_pcre( pattern     = CONV string( iv_pattern )
                                    ignore_case = abap_true ).
        rv_valid = abap_true.
      CATCH cx_sy_invalid_regex cx_sy_regex_too_complex.
        rv_valid = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD pcre_match.
    TRY.
        " matches( ) is anchored to the whole value; case = abap_false ignores case
        rv_match = xsdbool( matches( val  = CONV string( iv_value )
                                     pcre = CONV string( iv_pattern )
                                     case = abap_false ) ).
      CATCH cx_sy_invalid_regex cx_sy_regex_too_complex.
        rv_match = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD pcre_match_any.
    LOOP AT it_patterns ASSIGNING FIELD-SYMBOL(<lv_pattern>).
      IF pcre_match( iv_value = iv_value iv_pattern = <lv_pattern> ) = abap_true.
        rv_match = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD pcre_first_invalid.
    LOOP AT it_patterns ASSIGNING FIELD-SYMBOL(<lv_pattern>).
      IF pcre_valid( <lv_pattern> ) = abap_false.
        rv_pattern = <lv_pattern>.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD pcre_literals.
    DATA lv_close TYPE string.
    DATA lv_escaped TYPE abap_bool.
    DATA(lv_pattern) = CONV string( iv_pattern ).
    DO strlen( lv_pattern ) TIMES.
      DATA(lv_char) = substring( val = lv_pattern off = sy-index - 1 len = 1 ).
      IF lv_escaped = abap_true.
        " \. or \* is a literal; \d, \w, \s ... are classes
        lv_escaped = abap_false.
        IF lv_close IS INITIAL AND lv_char NA gc_pcre-word.
          rv_count += 1.
        ENDIF.
      ELSEIF lv_char = gc_pcre-escape.
        lv_escaped = abap_true.
      ELSEIF lv_close IS NOT INITIAL.
        IF lv_char = lv_close.
          CLEAR lv_close.
        ENDIF.
      ELSEIF lv_char = gc_pcre-class_open.
        lv_close = gc_pcre-class_close.
      ELSEIF lv_char = gc_pcre-count_open.
        lv_close = gc_pcre-count_close.
      ELSEIF lv_char NA gc_pcre-meta.
        rv_count += 1.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD param_int.
    rv_value = to_decimal( iv_value   = io_params->get_param( iv_name )
                           iv_default = iv_default ).
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
