*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_numrange.clas.abap
*& Purpose:
*& Technical health: number ranges nearly exhausted. Reads the internal
*& intervals (NRIV, EXTERNIND blank) of the configured number range objects
*& that are not year-dependent or valid in the current / next year and
*& measures the usage (NRLEVEL - FROMNUMBER) / (TONUMBER - FROMNUMBER) x 100
*& per object / subobject / interval / year. Read-only: no interval is
*& changed or extended.
*& Modification log:
*& 2026-11-07 | Initial version (number range exhaustion, morning report).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - number ranges nearly exhausted (NRIV)</p>
"! PARAM1 = number range objects (SNRO names, comma list, exact). Metric NR_USED_PCT (level)
"! per interval, DIM1 = object/subobject/interval/year; limits (amber 85 / red 95) in
"! ZCD_HCK_THRESH, row '*'. One finding per interval at or above amber names object,
"! interval, usage and the numbers left. NRLEVEL initial = nothing issued (0 %).
CLASS zcl_cd_hck_c_numrange DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'NR_USED_PCT'.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_number,
        valid TYPE abap_bool,
        value TYPE zif_cd_hck_types=>ty_value,
      END OF ty_number.

    TYPES:
      BEGIN OF ty_usage,
        valid TYPE abap_bool,
        pct   TYPE zif_cd_hck_types=>ty_value,
        left  TYPE zif_cd_hck_types=>ty_value,
      END OF ty_usage.

    "! Digits only (blank = zero); anything else is not a number of an internal interval
    CLASS-METHODS to_number
      IMPORTING
        iv_value         TYPE zif_cd_hck_runtime_types=>ty_nr_number
      RETURNING
        VALUE(rs_number) TYPE ty_number.

    CLASS-METHODS usage
      IMPORTING
        is_interval     TYPE zif_cd_hck_runtime_types=>ty_nr_interval
      RETURNING
        VALUE(rs_usage) TYPE ty_usage.

ENDCLASS.



CLASS zcl_cd_hck_c_numrange IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_objects TYPE zif_cd_hck_runtime_types=>tt_nr_object.
    DATA lt_found TYPE zif_cd_hck_runtime_types=>tt_nr_object.

    LOOP AT zcl_cd_ops_util=>split_list( is_def-param1 ) ASSIGNING FIELD-SYMBOL(<lv_object>).
      INSERT CONV zif_cd_hck_runtime_types=>ty_nr_object( to_upper( condense( <lv_object> ) ) ) INTO TABLE lt_objects.
    ENDLOOP.
    IF lt_objects IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e375(zcd_ops) WITH is_def-check_id.
    ENDIF.

    DATA(lv_year_from) = CONV zif_cd_hck_runtime_types=>ty_year( is_context-now_date(4) ).
    DATA(lv_year_to)   = CONV zif_cd_hck_runtime_types=>ty_year( lv_year_from + 1 ).
    DATA(lv_cap) = zcl_cd_hck_param=>row_cap( iv_name    = zif_cd_hck_runtime_types=>gc_param-max_tech_rows
                                              iv_default = zif_cd_hck_runtime_types=>gc_param_default-max_tech_rows
                                              iv_ceiling = zif_cd_hck_runtime_types=>gc_max_tech_rows ).
    DATA(lt_intervals) = zcl_cd_hck_factory=>get_runtime_dao( )->get_number_ranges( it_objects   = lt_objects
                                                                                     iv_year_from = lv_year_from
                                                                                     iv_year_to   = lv_year_to
                                                                                     iv_max_rows  = lv_cap ).
    IF lines( lt_intervals ) >= lv_cap.
      INSERT VALUE #( object_key = is_def-check_id
                      check_code = zif_cd_hck_runtime_types=>gc_code-read_capped
                      severity   = zif_cd_ops_types=>gc_severity-warning
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-read_capped
                                                          iv_v1    = zif_cd_hck_runtime_types=>gc_param-max_tech_rows
                                                          iv_v2    = lv_cap
                                                          iv_v3    = is_def-check_id ) ) INTO TABLE rs_result-findings.
    ENDIF.

    " The usage limits classify every interval; without them nothing is judged (never green)
    DATA(ls_limit) = zcl_cd_hck_threshold=>resolve( it_thresholds = it_thresholds
                                                    iv_metric     = gc_metric
                                                    iv_key        = zif_cd_hck_types=>gc_default_key ).
    ls_limit-baseline_mode = zif_cd_hck_types=>gc_baseline-none.
    DATA(lv_limits_set) = xsdbool( ls_limit-amber <> 0 OR ls_limit-red <> 0 ).
    IF lv_limits_set = abap_false.
      INSERT VALUE #( object_key = is_def-check_id
                      check_code = zif_cd_hck_runtime_types=>gc_code-limits_missing
                      severity   = zif_cd_ops_types=>gc_severity-warning
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-limits_missing
                                                          iv_v1    = is_def-check_id
                                                          iv_v2    = gc_metric ) ) INTO TABLE rs_result-findings.
    ENDIF.

    LOOP AT lt_intervals ASSIGNING FIELD-SYMBOL(<ls_interval>).
      INSERT <ls_interval>-object INTO TABLE lt_found.
      DATA(lv_interval) = |{ <ls_interval>-subobject }/{ <ls_interval>-nrrangenr }/{ <ls_interval>-toyear }|.
      DATA(lv_dim) = CONV zif_cd_hck_types=>ty_dim( |{ <ls_interval>-object }/{ lv_interval }| ).
      DATA(ls_usage) = usage( <ls_interval> ).
      IF ls_usage-valid = abap_false.
        INSERT VALUE #( object_key = |{ is_def-check_id }/{ lv_dim }|
                        check_code = zif_cd_hck_runtime_types=>gc_code-nr_not_numeric
                        severity   = zif_cd_ops_types=>gc_severity-warning
                        action     = zif_cd_ops_types=>gc_action-notify
                        reference  = <ls_interval>-object
                        message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-nr_not_numeric
                                                            iv_v1    = <ls_interval>-object
                                                            iv_v2    = lv_interval ) ) INTO TABLE rs_result-findings.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( metric = gc_metric
                      dim1   = lv_dim
                      value  = ls_usage-pct
                      kind   = zif_cd_hck_types=>gc_metric_kind-level ) INTO TABLE rs_result-metrics.
      IF lv_limits_set = abap_false.
        CONTINUE.
      ENDIF.
      DATA(lv_rag) = zcl_cd_hck_threshold=>evaluate( iv_value     = ls_usage-pct
                                                     is_threshold = ls_limit
                                                     it_history   = VALUE #( ) )-rag.
      IF lv_rag <> zif_cd_ops_types=>gc_rag-red AND lv_rag <> zif_cd_ops_types=>gc_rag-amber.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ lv_dim }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-nr_usage_high
                      severity   = COND #( WHEN lv_rag = zif_cd_ops_types=>gc_rag-red
                                           THEN zif_cd_ops_types=>gc_severity-error
                                           ELSE zif_cd_ops_types=>gc_severity-warning )
                      action     = zif_cd_ops_types=>gc_action-notify
                      reference  = <ls_interval>-object
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-nr_usage
                                                          iv_v1    = <ls_interval>-object
                                                          iv_v2    = lv_interval
                                                          iv_v3    = |{ ls_usage-pct STYLE = SIMPLE }|
                                                          iv_v4    = |{ ls_usage-left STYLE = SIMPLE }| ) )
             INTO TABLE rs_result-findings.
    ENDLOOP.

    " A configured object without an internal interval of this or next year is not watched
    LOOP AT lt_objects ASSIGNING FIELD-SYMBOL(<lv_configured>).
      IF line_exists( lt_found[ table_line = <lv_configured> ] ).
        CONTINUE.
      ENDIF.
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ <lv_configured> }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-nr_no_interval
                      severity   = zif_cd_ops_types=>gc_severity-warning
                      action     = zif_cd_ops_types=>gc_action-notify
                      reference  = <lv_configured>
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-nr_no_interval
                                                          iv_v1    = <lv_configured>
                                                          iv_v2    = lv_year_from
                                                          iv_v3    = lv_year_to ) ) INTO TABLE rs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD to_number.
    DATA(lv_text) = condense( iv_value ).
    IF lv_text IS INITIAL.
      rs_number-valid = abap_true.
      RETURN.
    ENDIF.
    IF zcl_cd_ops_util=>pcre_match( iv_value   = lv_text
                                    iv_pattern = zif_cd_hck_runtime_types=>gc_pcre_digits ) = abap_false.
      RETURN.
    ENDIF.
    rs_number-valid = abap_true.
    rs_number-value = zcl_cd_ops_util=>to_decimal( lv_text ).
  ENDMETHOD.


  METHOD usage.
    DATA(ls_from)  = to_number( is_interval-fromnumber ).
    DATA(ls_to)    = to_number( is_interval-tonumber ).
    DATA(ls_level) = to_number( is_interval-nrlevel ).
    IF ls_from-valid = abap_false OR ls_to-valid = abap_false OR ls_level-valid = abap_false
       OR ls_to-value <= ls_from-value.
      RETURN.
    ENDIF.
    rs_usage-valid = abap_true.
    " NRLEVEL initial (or below the interval): nothing issued yet - 0 %, every number left
    IF ls_level-value < ls_from-value.
      rs_usage-left = ls_to-value - ls_from-value + 1.
      RETURN.
    ENDIF.
    DATA(lv_level) = nmin( val1 = ls_level-value val2 = ls_to-value ).
    rs_usage-pct  = round( val = ( lv_level - ls_from-value ) / ( ls_to-value - ls_from-value )
                                 * zcl_cd_hck_threshold=>gc_percent
                           dec = 2 ).
    rs_usage-left = ls_to-value - lv_level.
  ENDMETHOD.

ENDCLASS.
