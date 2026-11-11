*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_agg_query.clas.abap
*& Purpose:
*& Pure logic of the no-code aggregate check (ZCA_OPS_AGG): validates a row
*& against the approved-table list and the runtime DDIC of its table and
*& builds the SQL of one database aggregate (COUNT of the matching rows, or
*& COUNT and MIN of a date for AGE, grouped by the company-code field), and
*& turns the result rows into findings by the row's AMBER / RED limits.
*& No SQL, no database: the data access runs what this class built.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework; the framework's equivalent of a
*&            | consumer's generic aggregate: COUNT / AGE with a status condition per company code).
*& 2026-11-11 | Process catalogue: window MAX_AGE_DAYS (rows at most n days old), operator NI (none of a
*&            | list, status and condition), a date / time window instead of the age limits (outage check;
*&            | TIME_FIELD bounds the first and last day; message 255).
*& 2026-11-11 | Explainable results: a finding names its aggregate row (CFG_RULE).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - aggregate check builder (pure)</p>
"! Security: the table must be approved for the area (ZCA_OPS_TABWL); every field name must
"! exist in the runtime DDIC of that table; operators come from a fixed list; character
"! literals go through CL_ABAP_DYN_PRG=>QUOTE, numeric literals must be numbers. Nothing of
"! the configuration is concatenated into SQL unchecked.
CLASS zcl_ca_ops_agg_query DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Validated SQL of one aggregate row
    "! @parameter is_window | measured in this date / time window instead of MIN_AGE_DAYS / MAX_AGE_DAYS
    "! @raising zcx_ca_ops_error | 086 not approved, 082 no fields, 083 unknown field, 088 operator,
    "! 089 not a number, 090 function, 091 not a date, 103 company-code field required, 255 time field / window
    CLASS-METHODS build
      IMPORTING
        is_agg          TYPE zif_ca_ops_chk_types=>ty_agg
        it_fields       TYPE zif_ca_ops_chk_types=>tt_field
        iv_approved     TYPE abap_bool
        iv_bukrs_aware  TYPE abap_bool
        iv_today        TYPE d
        is_window       TYPE zif_ca_ops_chk_types=>ty_window OPTIONAL
      RETURNING
        VALUE(rs_query) TYPE zif_ca_ops_chk_types=>ty_agg_query
      RAISING
        zcx_ca_ops_error.

    "! Findings of the result rows: the value (rows, or days of the oldest row) at or above RED is an
    "! error (owned exception), at or above AMBER a warning; below both nothing (auto-resolve)
    CLASS-METHODS to_findings
      IMPORTING
        is_agg             TYPE zif_ca_ops_chk_types=>ty_agg
        it_rows            TYPE zif_ca_ops_chk_types=>tt_agg_row
        iv_today           TYPE d
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

    "! Value of a result row: COUNT = rows, AGE = days since the oldest date (0 without rows)
    CLASS-METHODS value_of
      IMPORTING
        is_agg          TYPE zif_ca_ops_chk_types=>ty_agg
        is_row          TYPE zif_ca_ops_chk_types=>ty_agg_row
        iv_today        TYPE d
      RETURNING
        VALUE(rv_value) TYPE i.

  PRIVATE SECTION.
    "! A decimal number literal accepted as a condition value
    CONSTANTS gc_number_pattern TYPE string VALUE `[-+]?[0-9]+(\.[0-9]+)?`.
    "! SQL set operators of IN / NI
    CONSTANTS:
      BEGIN OF gc_sql_set,
        in_set TYPE string VALUE `IN`,
        not_in TYPE string VALUE `NOT IN`,
      END OF gc_sql_set.
    "! Names of the result columns (components of ZIF_CA_OPS_CHK_TYPES=>TY_AGG_ROW)
    CONSTANTS:
      BEGIN OF gc_column,
        company_code TYPE string VALUE `COMPANY_CODE`,
        row_count    TYPE string VALUE `ROW_COUNT`,
        oldest       TYPE string VALUE `OLDEST`,
      END OF gc_column.

    CLASS-METHODS field_kind
      IMPORTING
        iv_field       TYPE clike
        iv_tabname     TYPE zif_ca_ops_chk_types=>ty_tabname
        it_fields      TYPE zif_ca_ops_chk_types=>tt_field
      RETURNING
        VALUE(rv_kind) TYPE zif_ca_ops_chk_types=>ty_type_kind
      RAISING
        zcx_ca_ops_error.

    CLASS-METHODS is_numeric_kind
      IMPORTING
        iv_kind           TYPE zif_ca_ops_chk_types=>ty_type_kind
      RETURNING
        VALUE(rv_numeric) TYPE abap_bool.

    CLASS-METHODS literal
      IMPORTING
        iv_value          TYPE clike
        iv_field          TYPE zif_ca_ops_chk_types=>ty_fieldname
        iv_kind           TYPE zif_ca_ops_chk_types=>ty_type_kind
      RETURNING
        VALUE(rv_literal) TYPE string
      RAISING
        zcx_ca_ops_error.

    "! One DDIC-checked condition with quoted literals; blank field = no condition
    CLASS-METHODS condition
      IMPORTING
        iv_field      TYPE zif_ca_ops_chk_types=>ty_fieldname
        iv_operator   TYPE zif_ca_ops_chk_types=>ty_operator
        iv_value      TYPE zif_ca_ops_chk_types=>ty_cond_value
        iv_status     TYPE abap_bool
        iv_tabname    TYPE zif_ca_ops_chk_types=>ty_tabname
        it_fields     TYPE zif_ca_ops_chk_types=>tt_field
      RETURNING
        VALUE(rv_sql) TYPE string
      RAISING
        zcx_ca_ops_error.

    CLASS-METHODS date_literal
      IMPORTING
        iv_date           TYPE d
      RETURNING
        VALUE(rv_literal) TYPE string.

    CLASS-METHODS time_literal
      IMPORTING
        iv_time           TYPE t
      RETURNING
        VALUE(rv_literal) TYPE string.

    "! Conditions of the date / time window (outage check); the time bounds only the first and last day
    CLASS-METHODS window_conditions
      IMPORTING
        iv_date_field   TYPE zif_ca_ops_chk_types=>ty_fieldname
        iv_time_field   TYPE zif_ca_ops_chk_types=>ty_fieldname
        is_window       TYPE zif_ca_ops_chk_types=>ty_window
      RETURNING
        VALUE(rt_where) TYPE string_table.

ENDCLASS.



CLASS zcl_ca_ops_agg_query IMPLEMENTATION.

  METHOD build.
    DATA lt_where TYPE string_table.

    IF iv_approved = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e086(zca_ops) WITH is_agg-tabname is_agg-area.
    ENDIF.
    IF it_fields IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e082(zca_ops) WITH is_agg-tabname.
    ENDIF.
    rs_query-tabname = to_upper( condense( is_agg-tabname ) ).
    DATA(lv_func) = CONV zif_ca_ops_chk_types=>ty_agg_func( to_upper( condense( is_agg-agg_func ) ) ).
    IF lv_func <> zif_ca_ops_chk_types=>gc_agg_func-count AND lv_func <> zif_ca_ops_chk_types=>gc_agg_func-age.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e090(zca_ops) WITH is_agg-agg_id is_agg-agg_func.
    ENDIF.

    " One result per company code, so every finding carries its company code (never a mixed count)
    IF is_agg-bukrs_field IS NOT INITIAL.
      rs_query-group_field = to_upper( condense( is_agg-bukrs_field ) ).
      field_kind( iv_field   = rs_query-group_field
                  iv_tabname = rs_query-tabname
                  it_fields  = it_fields ).
    ELSEIF iv_bukrs_aware = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e103(zca_ops) WITH is_agg-agg_id is_agg-check_id.
    ENDIF.

    " Dates: initial dates never count; only rows at least MIN_AGE_DAYS old (future dates never)
    DATA(lv_date_field) = CONV zif_ca_ops_chk_types=>ty_fieldname( to_upper( condense( is_agg-date_field ) ) ).
    IF lv_date_field IS NOT INITIAL.
      IF field_kind( iv_field   = lv_date_field
                     iv_tabname = rs_query-tabname
                     it_fields  = it_fields ) <> cl_abap_typedescr=>typekind_date.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e091(zca_ops) WITH is_agg-agg_id lv_date_field rs_query-tabname.
      ENDIF.
      INSERT |{ lv_date_field } > { date_literal( zif_ca_ops_chk_types=>gc_initial_date ) }| INTO TABLE lt_where.
    ELSEIF lv_func = zif_ca_ops_chk_types=>gc_agg_func-age OR is_window IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e091(zca_ops) WITH is_agg-agg_id lv_date_field rs_query-tabname.
    ENDIF.
    " The time field goes with the date field (a TIMS field of the table)
    DATA(lv_time_field) = CONV zif_ca_ops_chk_types=>ty_fieldname( to_upper( condense( is_agg-time_field ) ) ).
    IF lv_time_field IS NOT INITIAL
       AND ( lv_date_field IS INITIAL
             OR field_kind( iv_field   = lv_time_field
                            iv_tabname = rs_query-tabname
                            it_fields  = it_fields ) <> cl_abap_typedescr=>typekind_time ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e255(zca_ops) WITH is_agg-agg_id lv_time_field rs_query-tabname.
    ENDIF.
    IF is_window IS NOT INITIAL.
      " Outage check: the rows of the window, whatever their age
      IF is_window-from_date IS INITIAL OR is_window-to_date < is_window-from_date.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e255(zca_ops) WITH is_agg-agg_id is_window-from_date rs_query-tabname.
      ENDIF.
      INSERT LINES OF window_conditions( iv_date_field = lv_date_field
                                         iv_time_field = lv_time_field
                                         is_window     = is_window ) INTO TABLE lt_where.
    ELSEIF lv_date_field IS NOT INITIAL.
      " Only rows at least MIN_AGE_DAYS old (future dates never) and, with a window, at most MAX_AGE_DAYS old
      DATA(lv_latest) = CONV d( iv_today - is_agg-min_age_days ).
      INSERT |{ lv_date_field } <= { date_literal( lv_latest ) }| INTO TABLE lt_where.
      IF is_agg-max_age_days > 0.
        DATA(lv_earliest) = CONV d( iv_today - is_agg-max_age_days ).
        INSERT |{ lv_date_field } >= { date_literal( lv_earliest ) }| INTO TABLE lt_where.
      ENDIF.
    ENDIF.

    INSERT condition( iv_field    = is_agg-status_field
                      iv_operator = is_agg-status_op
                      iv_value    = is_agg-status_value
                      iv_status   = abap_true
                      iv_tabname  = rs_query-tabname
                      it_fields   = it_fields ) INTO TABLE lt_where.
    INSERT condition( iv_field    = is_agg-cond_field
                      iv_operator = is_agg-cond_op
                      iv_value    = is_agg-cond_value
                      iv_status   = abap_false
                      iv_tabname  = rs_query-tabname
                      it_fields   = it_fields ) INTO TABLE lt_where.
    DELETE lt_where WHERE table_line IS INITIAL.
    rs_query-where_clause = concat_lines_of( table = lt_where
                                             sep   = ` AND ` ).

    rs_query-select_list = COND #( WHEN rs_query-group_field IS NOT INITIAL
                                   THEN |{ rs_query-group_field } AS { gc_column-company_code }, | )
                           && |COUNT(*) AS { gc_column-row_count }|.
    IF lv_func = zif_ca_ops_chk_types=>gc_agg_func-age.
      rs_query-select_list = |{ rs_query-select_list }, MIN( { lv_date_field } ) AS { gc_column-oldest }|.
    ENDIF.
  ENDMETHOD.


  METHOD to_findings.
    DATA(lv_age) = xsdbool( to_upper( condense( is_agg-agg_func ) ) = zif_ca_ops_chk_types=>gc_agg_func-age ).
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_value) = value_of( is_agg    = is_agg
                                 is_row    = <ls_row>
                                 iv_today  = iv_today ).
      DATA(lv_severity) = COND zif_ca_ops_types=>ty_severity(
                            WHEN is_agg-red > 0 AND lv_value >= is_agg-red THEN zif_ca_ops_types=>gc_severity-error
                            WHEN is_agg-amber > 0 AND lv_value >= is_agg-amber THEN zif_ca_ops_types=>gc_severity-warning ).
      IF lv_severity IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_limit) = COND i( WHEN lv_severity = zif_ca_ops_types=>gc_severity-error THEN is_agg-red
                               ELSE is_agg-amber ).
      INSERT VALUE #( object_type  = zif_ca_ops_chk_types=>gc_object_type-aggregate
                      object_key   = |{ is_agg-check_id }/{ is_agg-agg_id }|
                      rule_id      = is_agg-agg_id
                      check_code   = COND #( WHEN is_agg-check_code IS NOT INITIAL THEN is_agg-check_code
                                             WHEN lv_age = abap_true THEN zif_ca_ops_chk_types=>gc_code-agg_age
                                             ELSE zif_ca_ops_chk_types=>gc_code-agg_count )
                      severity     = lv_severity
                      action       = zif_ca_ops_types=>gc_action-exception
                      reference    = is_agg-tabname
                      company_code = <ls_row>-company_code
                      item_count   = <ls_row>-row_count
                      cfg_rule     = is_agg-agg_id
                      message      = zcl_ca_ops_util=>text(
                                       iv_msgno = COND #( WHEN lv_age = abap_true
                                                          THEN zif_ca_ops_chk_types=>gc_msg-agg_age
                                                          ELSE zif_ca_ops_chk_types=>gc_msg-agg_count )
                                       iv_v1    = is_agg-agg_id
                                       iv_v2    = <ls_row>-company_code
                                       iv_v3    = lv_value
                                       iv_v4    = lv_limit ) ) INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD value_of.
    IF to_upper( condense( is_agg-agg_func ) ) <> zif_ca_ops_chk_types=>gc_agg_func-age.
      rv_value = is_row-row_count.
      RETURN.
    ENDIF.
    IF is_row-row_count > 0 AND is_row-oldest IS NOT INITIAL AND is_row-oldest < iv_today.
      rv_value = iv_today - is_row-oldest.
    ENDIF.
  ENDMETHOD.


  METHOD field_kind.
    DATA(lv_field) = CONV zif_ca_ops_chk_types=>ty_fieldname( to_upper( condense( iv_field ) ) ).
    READ TABLE it_fields INTO DATA(ls_field) WITH TABLE KEY fieldname = lv_field.
    IF sy-subrc <> 0 OR lv_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e083(zca_ops) WITH lv_field iv_tabname.
    ENDIF.
    rv_kind = ls_field-type_kind.
  ENDMETHOD.


  METHOD is_numeric_kind.
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
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e089(zca_ops) WITH lv_value iv_field.
    ENDIF.
    rv_literal = lv_value.
  ENDMETHOD.


  METHOD condition.
    DATA lt_literals TYPE string_table.

    IF iv_field IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_field) = CONV zif_ca_ops_chk_types=>ty_fieldname( to_upper( condense( iv_field ) ) ).
    DATA(lv_kind) = field_kind( iv_field   = lv_field
                                iv_tabname = iv_tabname
                                it_fields  = it_fields ).
    DATA(lv_operator) = CONV zif_ca_ops_chk_types=>ty_operator( to_upper( iv_operator ) ).

    IF lv_operator = zif_ca_ops_chk_types=>gc_operator-in_set OR lv_operator = zif_ca_ops_chk_types=>gc_operator-not_in.
      LOOP AT zcl_ca_ops_util=>split_list( iv_value ) ASSIGNING FIELD-SYMBOL(<lv_token>).
        INSERT literal( iv_value = <lv_token> iv_field = lv_field iv_kind = lv_kind ) INTO TABLE lt_literals.
      ENDLOOP.
      IF lt_literals IS INITIAL.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e089(zca_ops) WITH iv_value lv_field.
      ENDIF.
      rv_sql = |{ lv_field } { COND string( WHEN lv_operator = zif_ca_ops_chk_types=>gc_operator-not_in
                                            THEN gc_sql_set-not_in ELSE gc_sql_set-in_set ) } | &&
               |( { concat_lines_of( table = lt_literals sep = `, ` ) } )|.
      RETURN.
    ENDIF.

    " The status condition selects a status: equal or not equal only
    DATA(lv_sql_operator) = SWITCH string( lv_operator
                                           WHEN zif_ca_ops_chk_types=>gc_operator-eq THEN `=`
                                           WHEN zif_ca_ops_chk_types=>gc_operator-ne THEN `<>` ).
    IF lv_sql_operator IS INITIAL AND iv_status = abap_false.
      lv_sql_operator = SWITCH string( lv_operator
                                       WHEN zif_ca_ops_chk_types=>gc_operator-gt THEN `>`
                                       WHEN zif_ca_ops_chk_types=>gc_operator-lt THEN `<`
                                       WHEN zif_ca_ops_chk_types=>gc_operator-ge THEN `>=`
                                       WHEN zif_ca_ops_chk_types=>gc_operator-le THEN `<=` ).
    ENDIF.
    IF lv_sql_operator IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e088(zca_ops) WITH iv_operator lv_field.
    ENDIF.
    rv_sql = |{ lv_field } { lv_sql_operator } { literal( iv_value = iv_value iv_field = lv_field iv_kind = lv_kind ) }|.
  ENDMETHOD.


  METHOD date_literal.
    rv_literal = cl_abap_dyn_prg=>quote( CONV string( iv_date ) ).
  ENDMETHOD.


  METHOD time_literal.
    rv_literal = cl_abap_dyn_prg=>quote( CONV string( iv_time ) ).
  ENDMETHOD.


  METHOD window_conditions.
    DATA(lv_from) = date_literal( is_window-from_date ).
    DATA(lv_to) = date_literal( is_window-to_date ).
    IF iv_time_field IS INITIAL.
      INSERT |{ iv_date_field } >= { lv_from }| INTO TABLE rt_where.
      INSERT |{ iv_date_field } <= { lv_to }| INTO TABLE rt_where.
      RETURN.
    ENDIF.
    INSERT |( { iv_date_field } > { lv_from } OR ( { iv_date_field } = { lv_from } | &&
           |AND { iv_time_field } >= { time_literal( is_window-from_time ) } ) )| INTO TABLE rt_where.
    INSERT |( { iv_date_field } < { lv_to } OR ( { iv_date_field } = { lv_to } | &&
           |AND { iv_time_field } <= { time_literal( is_window-to_time ) } ) )| INTO TABLE rt_where.
  ENDMETHOD.

ENDCLASS.
