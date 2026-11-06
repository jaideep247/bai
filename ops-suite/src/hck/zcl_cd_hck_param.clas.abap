*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_param.clas.abap
*& Purpose:
*& Pure parsing of check parameters (PARAM1-4 of ZCD_HCK_DEF): comma or
*& semicolon lists of PCRE patterns, numbers with a safe default.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | PCRE patterns (user decision 2026-11-06): patterns( ) returns the list items as PCRE
*&              (complete value, case ignored), check_patterns( ) raises message 373 for an invalid one;
*&              pattern_range( ) with CP / EQ rows removed.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - check parameter parsing (pure)</p>
CLASS zcl_cd_hck_param DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! 'ZCD_PAYM_.*, ZCD_POST_GL' -> two PCRE patterns, each matched to the complete
    "! value with case ignored. A list item cannot contain ',' or ';' (separators).
    CLASS-METHODS patterns
      IMPORTING
        iv_list            TYPE clike
      RETURNING
        VALUE(rt_patterns) TYPE zif_cd_ops_types=>tt_pcre.

    "! A pattern that is not valid PCRE is a configuration error of the check (E373),
    "! never an empty selection
    CLASS-METHODS check_patterns
      IMPORTING
        it_patterns TYPE zif_cd_ops_types=>tt_pcre
        iv_check_id TYPE zif_cd_hck_types=>ty_check_id
      RAISING
        zcx_cd_ops_error.

    CLASS-METHODS int
      IMPORTING
        iv_value        TYPE clike
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

ENDCLASS.



CLASS zcl_cd_hck_param IMPLEMENTATION.

  METHOD patterns.
    rt_patterns = zcl_cd_ops_util=>split_list( iv_list ).
  ENDMETHOD.


  METHOD check_patterns.
    DATA(lv_invalid) = zcl_cd_ops_util=>pcre_first_invalid( it_patterns ).
    IF lv_invalid IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e373(zcd_ops) WITH iv_check_id lv_invalid.
    ENDIF.
  ENDMETHOD.


  METHOD int.
    rv_value = zcl_cd_ops_util=>to_decimal( iv_value   = iv_value
                                            iv_default = iv_default ).
  ENDMETHOD.

ENDCLASS.
