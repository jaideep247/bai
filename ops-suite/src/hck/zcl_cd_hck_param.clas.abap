*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_param.clas.abap
*& Purpose:
*& Parsing of check parameters (PARAM1-4 of ZCD_HCK_DEF): comma or
*& semicolon lists of PCRE patterns, numbers with a safe default; and the
*& effective row caps of the TBTCO / aggregate reads (parameters HCK_MAX_*,
*& read through ZCL_CD_OPS_FACTORY=>GET_PARAMS, cut to the hard ceilings).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | PCRE patterns (user decision 2026-11-06): patterns( ) returns the list items as PCRE
*&              (complete value, case ignored), check_patterns( ) raises message 373 for an invalid one;
*&              pattern_range( ) with CP / EQ rows removed.
*& 2026-11-07 | Row caps as parameters: row_cap (parameter or default, cut to the hard ceiling), job_rows_cap,
*&            | job_names_cap, agg_rows_cap.
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

    "! Effective row cap: the parameter (its default when not maintained, blank, not a number
    "! or not positive), never above the hard ceiling. Reaching it still fails loudly where
    "! the caller did so before (cap = possibly incomplete result).
    CLASS-METHODS row_cap
      IMPORTING
        iv_name       TYPE zif_cd_ops_types=>ty_param_name
        iv_default    TYPE i
        iv_ceiling    TYPE i
      RETURNING
        VALUE(rv_cap) TYPE i.

    "! TBTCO job runs per read (HCK_MAX_JOB_ROWS, default 5,000, ceiling 50,000)
    CLASS-METHODS job_rows_cap
      RETURNING
        VALUE(rv_cap) TYPE i.

    "! Distinct TBTCO job names per window (HCK_MAX_JOB_NAMES, default 20,000, ceiling 200,000)
    CLASS-METHODS job_names_cap
      RETURNING
        VALUE(rv_cap) TYPE i.

    "! Groups of an aggregate check (HCK_MAX_AGG_ROWS, default 5,000, ceiling 50,000)
    CLASS-METHODS agg_rows_cap
      RETURNING
        VALUE(rv_cap) TYPE i.

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


  METHOD row_cap.
    rv_cap = zcl_cd_ops_util=>param_int( io_params  = zcl_cd_ops_factory=>get_params( )
                                         iv_name    = iv_name
                                         iv_default = iv_default ).
    IF rv_cap <= 0.
      rv_cap = iv_default.
    ENDIF.
    rv_cap = nmin( val1 = rv_cap val2 = iv_ceiling ).
  ENDMETHOD.


  METHOD job_rows_cap.
    rv_cap = row_cap( iv_name    = zif_cd_hck_types=>gc_param-max_job_rows
                      iv_default = zif_cd_hck_types=>gc_param_default-max_job_rows
                      iv_ceiling = zif_cd_hck_types=>gc_max_job_rows ).
  ENDMETHOD.


  METHOD job_names_cap.
    rv_cap = row_cap( iv_name    = zif_cd_hck_types=>gc_param-max_job_names
                      iv_default = zif_cd_hck_types=>gc_param_default-max_job_names
                      iv_ceiling = zif_cd_hck_types=>gc_max_job_names ).
  ENDMETHOD.


  METHOD agg_rows_cap.
    rv_cap = row_cap( iv_name    = zif_cd_hck_types=>gc_param-max_agg_rows
                      iv_default = zif_cd_hck_types=>gc_param_default-max_agg_rows
                      iv_ceiling = zif_cd_hck_dao=>gc_max_agg_rows ).
  ENDMETHOD.

ENDCLASS.
