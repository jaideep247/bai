*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_agg_query.clas.abap
*& Purpose:
*& Pure validation of a ZCD_HCK_AGG row against the whitelist and the DDIC
*& field list, building a dynamic WHERE from checked names and quoted literals.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | condition( ) and date_literal( ) public for ZCL_CD_HCK_VALUE_QUERY.
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Query keeps its definition (audit A56).
*& 2026-11-06 | Expected group set: a missing group measures zero (audit A103).
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-07 | Cap reached against the effective cap ZCL_CD_HCK_PARAM=>AGG_ROWS_CAP (parameter HCK_MAX_AGG_ROWS).
*& 2026-11-08 | Table consolidation: approved tables (HCK / READ) and drift tables (HCK / DRIFT) read from
*&            | ZCD_OPS_TABWL (was ZCD_HCK_TABWL, ZCD_HCK_DRIFT).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - generic aggregate builder (pure)</p>
"! Security: table must be approved (ZCD_OPS_TABWL HCK / READ); every field name
"! must exist in the runtime DDIC of that table; operators come from a
"! fixed list; character literals go through CL_ABAP_DYN_PRG=>QUOTE and
"! numeric literals must match a number pattern. Nothing from customizing
"! is concatenated into SQL unchecked.
CLASS zcl_cd_hck_agg_query DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! @raising zcx_cd_ops_error | 302 not whitelisted, 303 no fields, 304 unknown field,
    "! 305 operator, 306 non-numeric value, 307 invalid date mode, 309 not a date, 317/318 SUM
    CLASS-METHODS build
      IMPORTING
        is_def          TYPE zif_cd_hck_types=>ty_agg_def
        it_fields       TYPE zif_cd_hck_types=>tt_field
        iv_whitelisted  TYPE abap_bool
        iv_ref_date     TYPE d
      RETURNING
        VALUE(rs_query) TYPE zif_cd_hck_types=>ty_agg_query
      RAISING
        zcx_cd_ops_error.

    "! METRIC = AGG_ID, DIM1 = group value ('*' without grouping or rows),
    "! DIM2 = counted day in DAY mode; VALUE = COUNT or SUM.
    "! A103: every expected group without a row measures 0 (instead of '*')
    CLASS-METHODS to_metrics
      IMPORTING
        is_def           TYPE zif_cd_hck_types=>ty_agg_def
        it_rows          TYPE zif_cd_hck_types=>tt_agg_row
        iv_ref_date      TYPE d
        it_expected      TYPE zif_cd_hck_types=>tt_group_value OPTIONAL
      RETURNING
        VALUE(rt_metrics) TYPE zif_cd_hck_types=>tt_metric.

    "! Validate one definition (whitelist + DDIC via the DAO) and run it. A failure raises
    "! and measures nothing - it is never reported as zero volume (A103)
    "! @raising zcx_cd_ops_error | validation (302-318) or SQL error (308)
    CLASS-METHODS measure
      IMPORTING
        is_def            TYPE zif_cd_hck_types=>ty_agg_def
        iv_ref_date       TYPE d
        io_dao            TYPE REF TO zif_cd_hck_dao
        it_expected       TYPE zif_cd_hck_types=>tt_group_value OPTIONAL
      RETURNING
        VALUE(rt_metrics) TYPE zif_cd_hck_types=>tt_metric
      RAISING
        zcx_cd_ops_error.

    "! One DDIC-checked condition (EQ NE GT LT GE LE IN) with a quoted literal;
    "! also used by ZCL_CD_HCK_VALUE_QUERY (USAA known-table checks)
    CLASS-METHODS condition
      IMPORTING
        iv_field      TYPE zif_cd_hck_types=>ty_fieldname
        iv_operator   TYPE zif_cd_hck_types=>ty_operator
        iv_value      TYPE zif_cd_hck_types=>ty_cond_value
        iv_tabname    TYPE zif_cd_hck_types=>ty_tabname
        it_fields     TYPE zif_cd_hck_types=>tt_field
      RETURNING
        VALUE(rv_sql) TYPE string
      RAISING
        zcx_cd_ops_error.
    "! Quoted DATS literal for a WHERE clause
    CLASS-METHODS date_literal
      IMPORTING
        iv_date           TYPE d
      RETURNING
        VALUE(rv_literal) TYPE string.
  PRIVATE SECTION.
    "! A decimal number literal accepted as a condition value
    CONSTANTS gc_number_pattern TYPE string VALUE `[-+]?[0-9]+(\.[0-9]+)?`.

    CLASS-METHODS field_kind
      IMPORTING
        iv_field       TYPE zif_cd_hck_types=>ty_fieldname
        iv_tabname     TYPE zif_cd_hck_types=>ty_tabname
        it_fields      TYPE zif_cd_hck_types=>tt_field
      RETURNING
        VALUE(rv_kind) TYPE zif_cd_hck_types=>ty_type_kind
      RAISING
        zcx_cd_ops_error.

    CLASS-METHODS is_numeric_kind
      IMPORTING
        iv_kind           TYPE zif_cd_hck_types=>ty_type_kind
      RETURNING
        VALUE(rv_numeric) TYPE abap_bool.

    CLASS-METHODS literal
      IMPORTING
        iv_value          TYPE clike
        iv_field          TYPE zif_cd_hck_types=>ty_fieldname
        iv_kind           TYPE zif_cd_hck_types=>ty_type_kind
      RETURNING
        VALUE(rv_literal) TYPE string
      RAISING
        zcx_cd_ops_error.



    CLASS-METHODS reference_day
      IMPORTING
        is_def         TYPE zif_cd_hck_types=>ty_agg_def
        iv_ref_date    TYPE d
      RETURNING
        VALUE(rv_date) TYPE d.

ENDCLASS.



CLASS zcl_cd_hck_agg_query IMPLEMENTATION.

  METHOD build.
    DATA lt_where TYPE string_table.

    IF iv_whitelisted = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e302(zcd_ops) WITH is_def-tabname.
    ENDIF.
    IF it_fields IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e303(zcd_ops) WITH is_def-tabname.
    ENDIF.

    rs_query-def      = is_def.
    rs_query-ref_date = iv_ref_date.
    rs_query-agg_id   = is_def-agg_id.
    rs_query-tabname  = to_upper( is_def-tabname ).
    rs_query-agg_func = to_upper( is_def-agg_func ).

    CASE rs_query-agg_func.
      WHEN zif_cd_hck_types=>gc_agg_func-count.
      WHEN zif_cd_hck_types=>gc_agg_func-sum.
        rs_query-sum_field = to_upper( is_def-sum_field ).
        IF is_numeric_kind( field_kind( iv_field   = rs_query-sum_field
                                        iv_tabname = rs_query-tabname
                                        it_fields  = it_fields ) ) = abap_false.
          RAISE EXCEPTION TYPE zcx_cd_ops_error
            MESSAGE e318(zcd_ops) WITH rs_query-sum_field rs_query-tabname.
        ENDIF.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e317(zcd_ops) WITH is_def-agg_func is_def-check_id.
    ENDCASE.

    IF is_def-group_field IS NOT INITIAL.
      rs_query-group_field = to_upper( is_def-group_field ).
      field_kind( iv_field   = rs_query-group_field
                  iv_tabname = rs_query-tabname
                  it_fields  = it_fields ).
    ENDIF.

    IF is_def-date_mode <> zif_cd_hck_types=>gc_date_mode-none.
      DATA(lv_date_field) = CONV zif_cd_hck_types=>ty_fieldname( to_upper( is_def-date_field ) ).
      IF field_kind( iv_field   = lv_date_field
                     iv_tabname = rs_query-tabname
                     it_fields  = it_fields ) <> cl_abap_typedescr=>typekind_date.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e309(zcd_ops) WITH lv_date_field rs_query-tabname.
      ENDIF.
      DATA(lv_day) = date_literal( reference_day( is_def      = is_def
                                                  iv_ref_date = iv_ref_date ) ).
      CASE is_def-date_mode.
        WHEN zif_cd_hck_types=>gc_date_mode-age.
          INSERT |{ lv_date_field } <= { lv_day }| INTO TABLE lt_where.
          INSERT |{ lv_date_field } > { date_literal( '00000000' ) }| INTO TABLE lt_where.
        WHEN zif_cd_hck_types=>gc_date_mode-day.
          INSERT |{ lv_date_field } = { lv_day }| INTO TABLE lt_where.
        WHEN OTHERS.
          RAISE EXCEPTION TYPE zcx_cd_ops_error
            MESSAGE e307(zcd_ops) WITH is_def-agg_id is_def-check_id is_def-date_mode.
      ENDCASE.
    ENDIF.

    INSERT LINES OF VALUE string_table(
      ( condition( iv_field = is_def-cond1_field iv_operator = is_def-cond1_op iv_value = is_def-cond1_value
                   iv_tabname = rs_query-tabname it_fields = it_fields ) )
      ( condition( iv_field = is_def-cond2_field iv_operator = is_def-cond2_op iv_value = is_def-cond2_value
                   iv_tabname = rs_query-tabname it_fields = it_fields ) )
      ( condition( iv_field = is_def-cond3_field iv_operator = is_def-cond3_op iv_value = is_def-cond3_value
                   iv_tabname = rs_query-tabname it_fields = it_fields ) ) ) INTO TABLE lt_where.
    DELETE lt_where WHERE table_line IS INITIAL.

    rs_query-where_clause = concat_lines_of( table = lt_where
                                             sep   = ` AND ` ).
  ENDMETHOD.


  METHOD to_metrics.
    DATA ls_metric TYPE zif_cd_hck_types=>ty_metric.

    ls_metric-metric = is_def-agg_id.
    IF is_def-date_mode = zif_cd_hck_types=>gc_date_mode-day.
      ls_metric-dim2 = reference_day( is_def      = is_def
                                      iv_ref_date = iv_ref_date ).
    ENDIF.

    IF it_rows IS INITIAL AND it_expected IS INITIAL.
      ls_metric-dim1 = zif_cd_hck_types=>gc_default_key.
      INSERT ls_metric INTO TABLE rt_metrics.
      RETURN.
    ENDIF.

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      ls_metric-dim1  = COND #( WHEN is_def-group_field IS INITIAL OR <ls_row>-group_value IS INITIAL
                                THEN zif_cd_hck_types=>gc_default_key
                                ELSE <ls_row>-group_value ).
      ls_metric-value = COND #( WHEN to_upper( is_def-agg_func ) = zif_cd_hck_types=>gc_agg_func-sum
                                THEN <ls_row>-total
                                ELSE <ls_row>-row_count ).
      INSERT ls_metric INTO TABLE rt_metrics.
    ENDLOOP.

    " A103: an expected group (e.g. company code) with no rows measured zero - a silent
    " company next to an active one stays visible to its lower-is-worse threshold
    CLEAR ls_metric-value.
    " Sweep: measured groups by hash (was a scan of the metrics per expected group)
    DATA lt_measured TYPE HASHED TABLE OF zif_cd_hck_types=>ty_dim WITH UNIQUE KEY table_line.
    LOOP AT rt_metrics ASSIGNING FIELD-SYMBOL(<ls_measured>).
      INSERT <ls_measured>-dim1 INTO TABLE lt_measured.
    ENDLOOP.
    LOOP AT it_expected ASSIGNING FIELD-SYMBOL(<lv_expected>).
      ls_metric-dim1 = <lv_expected>.
      INSERT ls_metric-dim1 INTO TABLE lt_measured.
      IF sy-subrc = 0.
        INSERT ls_metric INTO TABLE rt_metrics.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD measure.
    DATA lt_fields TYPE zif_cd_hck_types=>tt_field.
    DATA(lv_whitelisted) = io_dao->is_table_whitelisted( is_def-tabname ).
    IF lv_whitelisted = abap_true.
      lt_fields = io_dao->get_table_fields( is_def-tabname ).
    ENDIF.
    DATA(ls_query) = build( is_def         = is_def
                            it_fields      = lt_fields
                            iv_whitelisted = lv_whitelisted
                            iv_ref_date    = iv_ref_date ).
    DATA(lt_rows) = io_dao->aggregate( ls_query ).
    " a result at the row cap may be cut off: an absent group is unknown, not zero
    rt_metrics = to_metrics( is_def      = is_def
                             it_rows     = lt_rows
                             iv_ref_date = iv_ref_date
                             it_expected = COND #( WHEN lines( lt_rows ) < zcl_cd_hck_param=>agg_rows_cap( )
                                                   THEN it_expected ) ).
  ENDMETHOD.


  METHOD field_kind.
    DATA(lv_field) = to_upper( condense( iv_field ) ).
    READ TABLE it_fields INTO DATA(ls_field) WITH KEY fieldname = lv_field.
    IF sy-subrc <> 0 OR lv_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e304(zcd_ops) WITH lv_field iv_tabname.
    ENDIF.
    rv_kind = ls_field-type_kind.
  ENDMETHOD.


  METHOD is_numeric_kind.
    " I int4, b int1, s int2, 8 int8, P packed, F float, a/e decfloat
    rv_numeric = xsdbool( iv_kind = cl_abap_typedescr=>typekind_int OR iv_kind = cl_abap_typedescr=>typekind_int1
                       OR iv_kind = cl_abap_typedescr=>typekind_int2 OR iv_kind = cl_abap_typedescr=>typekind_int8
                       OR iv_kind = cl_abap_typedescr=>typekind_packed OR iv_kind = cl_abap_typedescr=>typekind_float
                       OR iv_kind = cl_abap_typedescr=>typekind_decfloat16
                       OR iv_kind = cl_abap_typedescr=>typekind_decfloat34 ).
  ENDMETHOD.


  METHOD literal.
    " trim only - internal blanks of a literal are significant
    DATA(lv_value) = shift_right( val = shift_left( val = CONV string( iv_value ) sub = ` ` ) sub = ` ` ).
    IF is_numeric_kind( iv_kind ) = abap_false.
      rv_literal = cl_abap_dyn_prg=>quote( lv_value ).
      RETURN.
    ENDIF.
    IF NOT matches( val = lv_value pcre = gc_number_pattern ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e306(zcd_ops) WITH lv_value iv_field.
    ENDIF.
    rv_literal = lv_value.
  ENDMETHOD.


  METHOD condition.
    DATA lt_literals TYPE string_table.

    IF iv_field IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_field) = CONV zif_cd_hck_types=>ty_fieldname( to_upper( condense( iv_field ) ) ).
    DATA(lv_kind) = field_kind( iv_field   = lv_field
                                iv_tabname = iv_tabname
                                it_fields  = it_fields ).
    DATA(lv_operator) = to_upper( iv_operator ).

    IF lv_operator = zif_cd_hck_types=>gc_operator-in_set.
      LOOP AT zcl_cd_ops_util=>split_list( iv_value ) ASSIGNING FIELD-SYMBOL(<lv_token>).
        INSERT literal( iv_value = <lv_token> iv_field = lv_field iv_kind = lv_kind ) INTO TABLE lt_literals.
      ENDLOOP.
      IF lt_literals IS INITIAL.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e306(zcd_ops) WITH iv_value lv_field.
      ENDIF.
      rv_sql = |{ lv_field } IN ( { concat_lines_of( table = lt_literals sep = `, ` ) } )|.
      RETURN.
    ENDIF.

    DATA(lv_sql_operator) = SWITCH string( lv_operator
                                           WHEN zif_cd_hck_types=>gc_operator-eq THEN `=`
                                           WHEN zif_cd_hck_types=>gc_operator-ne THEN `<>`
                                           WHEN zif_cd_hck_types=>gc_operator-gt THEN `>`
                                           WHEN zif_cd_hck_types=>gc_operator-lt THEN `<`
                                           WHEN zif_cd_hck_types=>gc_operator-ge THEN `>=`
                                           WHEN zif_cd_hck_types=>gc_operator-le THEN `<=` ).
    IF lv_sql_operator IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e305(zcd_ops) WITH iv_operator lv_field.
    ENDIF.
    rv_sql = |{ lv_field } { lv_sql_operator } { literal( iv_value = iv_value iv_field = lv_field iv_kind = lv_kind ) }|.
  ENDMETHOD.


  METHOD date_literal.
    rv_literal = cl_abap_dyn_prg=>quote( CONV string( iv_date ) ).
  ENDMETHOD.


  METHOD reference_day.
    rv_date = iv_ref_date - is_def-age_days_min.
  ENDMETHOD.

ENDCLASS.
