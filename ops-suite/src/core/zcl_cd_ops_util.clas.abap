*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_util.clas.abap
*& Purpose:
*& Stateless helpers of the payment engine suite. No database access.
*& The generic helpers (severity ranking, RAG, PCRE, lists, HTML, time,
*& integer parameters, exception trace and error class, job link, amount
*& format) are in the framework utility ZCL_CA_OPS_UTIL; this class keeps
*& the texts of message class ZCD_OPS and the bank reference / account
*& helpers of the payment engine.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | text( ): user-facing texts are ZCD_OPS messages (phase 5, remove hardcoding).
*& 2026-11-10 | account_label (house bank / account ID or masked number).
*& 2026-11-10 | Generic helpers moved to the reusable framework ZCA_OPS (ZCL_CA_OPS_UTIL); text( ) builds
*&            | ZCD_OPS texts through ZCL_CA_OPS_UTIL=>MESSAGE_TEXT.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - payment engine helpers</p>
"! Texts of message class ZCD_OPS and the bank reference / account helpers. No database access.
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
        iv_msgno       TYPE zif_ca_ops_types=>ty_msgno
        iv_v1          TYPE simple OPTIONAL
        iv_v2          TYPE simple OPTIONAL
        iv_v3          TYPE simple OPTIONAL
        iv_v4          TYPE simple OPTIONAL
        "! Appended after the message text, not truncated (exception texts, messages)
        iv_tail        TYPE string OPTIONAL
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Normalise a bank reference to a document key:
    "! condense, strip leading zeros, left-pad with zeros to iv_length.
    "! iv_length = 0 returns the condensed reference unchanged.
    CLASS-METHODS normalize_key
      IMPORTING
        iv_reference  TYPE clike
        iv_length     TYPE i
      RETURNING
        VALUE(rv_key) TYPE string.

    "! A bank account for a text that may be e-mailed: house bank / account ID when both are
    "! known, else the account number masked to its last four characters (never in full)
    CLASS-METHODS account_label
      IMPORTING
        iv_account      TYPE clike
        iv_hbkid        TYPE clike OPTIONAL
        iv_hktid        TYPE clike OPTIONAL
      RETURNING
        VALUE(rv_label) TYPE string.

  PRIVATE SECTION.
    "! Account masking: visible trailing characters and the mask in front of them
    CONSTANTS gc_account_visible TYPE i VALUE 4.
    CONSTANTS gc_account_mask TYPE string VALUE `****`.

ENDCLASS.



CLASS zcl_cd_ops_util IMPLEMENTATION.

  METHOD text.
    rv_text = zcl_ca_ops_util=>message_text( iv_msgid = zif_cd_ops_types=>gc_message_class
                                             iv_msgno = iv_msgno
                                             iv_v1    = COND string( WHEN iv_v1 IS SUPPLIED THEN |{ iv_v1 }| )
                                             iv_v2    = COND string( WHEN iv_v2 IS SUPPLIED THEN |{ iv_v2 }| )
                                             iv_v3    = COND string( WHEN iv_v3 IS SUPPLIED THEN |{ iv_v3 }| )
                                             iv_v4    = COND string( WHEN iv_v4 IS SUPPLIED THEN |{ iv_v4 }| )
                                             iv_tail  = iv_tail ).
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


  METHOD account_label.
    IF iv_hbkid IS NOT INITIAL AND iv_hktid IS NOT INITIAL.
      rv_label = |{ condense( CONV string( iv_hbkid ) ) }/{ condense( CONV string( iv_hktid ) ) }|.
      RETURN.
    ENDIF.
    DATA(lv_account) = condense( CONV string( iv_account ) ).
    DATA(lv_length) = strlen( lv_account ).
    IF lv_length = 0.
      RETURN.
    ENDIF.
    " a short number is masked completely: four visible characters would be the whole number
    rv_label = COND #( WHEN lv_length <= gc_account_visible THEN gc_account_mask
                       ELSE |{ gc_account_mask }{ substring( val = lv_account
                                                             off = lv_length - gc_account_visible
                                                             len = gc_account_visible ) }| ).
  ENDMETHOD.

ENDCLASS.
