*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_agg_query.clas.testclasses.abap
*& Purpose:
*& Tests of the pure aggregate builder: SQL of COUNT and AGE rows (status
*& condition, company-code grouping, dates), every refusal (table not
*& approved 086, unknown field 083, status operator 088, number 089,
*& function 090, date field 091, company-code field 103) and the findings
*& of the result rows (red error, amber warning, below nothing, company
*& code and value). No database; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
CLASS ltc_agg_query DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        check_id TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_PENDING',
        agg_id   TYPE zif_ca_ops_chk_types=>ty_agg_id VALUE 'R1',
        table    TYPE zif_ca_ops_chk_types=>ty_tabname VALUE 'ZT_REQUEST',
        status   TYPE zif_ca_ops_chk_types=>ty_fieldname VALUE 'STATUS',
        bukrs    TYPE zif_ca_ops_chk_types=>ty_fieldname VALUE 'BUKRS',
        date     TYPE zif_ca_ops_chk_types=>ty_fieldname VALUE 'REQ_DATE',
        amount   TYPE zif_ca_ops_chk_types=>ty_fieldname VALUE 'AMOUNT',
        pending  TYPE zif_ca_ops_chk_types=>ty_cond_value VALUE 'PENDING',
        today    TYPE d VALUE '20261110',
        company  TYPE bukrs VALUE '1000',
      END OF gc.

    DATA mt_fields TYPE zif_ca_ops_chk_types=>tt_field.
    DATA ms_agg TYPE zif_ca_ops_chk_types=>ty_agg.

    METHODS setup.
    "! Build with the test table's fields; the message number of a refusal (blank = built)
    METHODS build_refusal
      IMPORTING
        iv_approved     TYPE abap_bool DEFAULT abap_true
        iv_bukrs_aware  TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_msgno) TYPE symsgno.

    METHODS count_by_company_code       FOR TESTING.
    METHODS age_reads_oldest_date       FOR TESTING.
    METHODS status_in_list_is_quoted    FOR TESTING.
    METHODS unapproved_table_refused    FOR TESTING.
    METHODS unknown_field_refused       FOR TESTING.
    METHODS status_range_op_refused     FOR TESTING.
    METHODS text_in_number_refused      FOR TESTING.
    METHODS unknown_function_refused    FOR TESTING.
    METHODS age_without_date_refused    FOR TESTING.
    METHODS per_company_needs_field     FOR TESTING.
    METHODS red_is_error_amber_warning  FOR TESTING.
    METHODS below_limits_no_finding     FOR TESTING.
    METHODS age_value_in_days           FOR TESTING.
ENDCLASS.


CLASS ltc_agg_query IMPLEMENTATION.

  METHOD setup.
    CLEAR: mt_fields, ms_agg.
    INSERT VALUE #( fieldname = gc-status type_kind = cl_abap_typedescr=>typekind_char ) INTO TABLE mt_fields.
    INSERT VALUE #( fieldname = gc-bukrs type_kind = cl_abap_typedescr=>typekind_char ) INTO TABLE mt_fields.
    INSERT VALUE #( fieldname = gc-date type_kind = cl_abap_typedescr=>typekind_date ) INTO TABLE mt_fields.
    INSERT VALUE #( fieldname = gc-amount type_kind = cl_abap_typedescr=>typekind_packed ) INTO TABLE mt_fields.
    ms_agg-area         = gc-area.
    ms_agg-check_id     = gc-check_id.
    ms_agg-agg_id       = gc-agg_id.
    ms_agg-tabname      = gc-table.
    ms_agg-agg_func     = zif_ca_ops_chk_types=>gc_agg_func-count.
    ms_agg-status_field = gc-status.
    ms_agg-status_op    = zif_ca_ops_chk_types=>gc_operator-eq.
    ms_agg-status_value = gc-pending.
    ms_agg-amber        = 5.
    ms_agg-red          = 10.
  ENDMETHOD.


  METHOD build_refusal.
    TRY.
        zcl_ca_ops_agg_query=>build( is_agg         = ms_agg
                                     it_fields      = mt_fields
                                     iv_approved    = iv_approved
                                     iv_bukrs_aware = iv_bukrs_aware
                                     iv_today       = gc-today ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        rv_msgno = lx_error->if_t100_message~t100key-msgno.
    ENDTRY.
  ENDMETHOD.


  " Rule: COUNT per company code - one database aggregate grouped by the company-code field
  METHOD count_by_company_code.
    TRY.
        ms_agg-bukrs_field = gc-bukrs.
        DATA(ls_query) = zcl_ca_ops_agg_query=>build( is_agg         = ms_agg
                                                      it_fields      = mt_fields
                                                      iv_approved    = abap_true
                                                      iv_bukrs_aware = abap_true
                                                      iv_today       = gc-today ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-select_list
                                            exp = `BUKRS AS COMPANY_CODE, COUNT(*) AS ROW_COUNT`
                                            msg = 'Count per company code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-where_clause exp = `STATUS = 'PENDING'`
                                            msg = 'Status condition with a quoted literal' ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-group_field exp = gc-bukrs
                                            msg = 'Grouped by the company-code field' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: AGE reads COUNT and the oldest date; initial and future dates never count
  METHOD age_reads_oldest_date.
    TRY.
        ms_agg-agg_func     = zif_ca_ops_chk_types=>gc_agg_func-age.
        ms_agg-date_field   = gc-date.
        ms_agg-min_age_days = 1.
        DATA(ls_query) = zcl_ca_ops_agg_query=>build( is_agg         = ms_agg
                                                      it_fields      = mt_fields
                                                      iv_approved    = abap_true
                                                      iv_bukrs_aware = abap_false
                                                      iv_today       = gc-today ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-select_list
                                            exp = `COUNT(*) AS ROW_COUNT, MIN( REQ_DATE ) AS OLDEST`
                                            msg = 'Count and oldest date, area-level' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_query-where_clause
          exp = `REQ_DATE > '00000000' AND REQ_DATE <= '20261109' AND STATUS = 'PENDING'`
          msg = 'Rows at least one day old, filled dates only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: IN takes a comma list; every value is quoted on its own
  METHOD status_in_list_is_quoted.
    TRY.
        ms_agg-status_op    = zif_ca_ops_chk_types=>gc_operator-in_set.
        ms_agg-status_value = 'PENDING,SCHEDULED'.
        DATA(ls_query) = zcl_ca_ops_agg_query=>build( is_agg         = ms_agg
                                                      it_fields      = mt_fields
                                                      iv_approved    = abap_true
                                                      iv_bukrs_aware = abap_false
                                                      iv_today       = gc-today ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-where_clause
                                            exp = `STATUS IN ( 'PENDING', 'SCHEDULED' )`
                                            msg = 'IN list quoted value by value' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a table not approved for the area is never read (086)
  METHOD unapproved_table_refused.
    cl_abap_unit_assert=>assert_equals( act = build_refusal( iv_approved = abap_false ) exp = '086'
                                        msg = 'Unapproved table refused' ).
  ENDMETHOD.


  " Rule: a field not in the DDIC of the table is refused (083)
  METHOD unknown_field_refused.
    ms_agg-status_field = 'NO_SUCH_FIELD'.
    cl_abap_unit_assert=>assert_equals( act = build_refusal( ) exp = '083' msg = 'Unknown field refused' ).
  ENDMETHOD.


  " Rule: the status condition is EQ, NE or IN - a range is no status (088)
  METHOD status_range_op_refused.
    ms_agg-status_op = zif_ca_ops_chk_types=>gc_operator-gt.
    cl_abap_unit_assert=>assert_equals( act = build_refusal( ) exp = '088' msg = 'GT on the status refused' ).
  ENDMETHOD.


  " Rule: a numeric field takes numbers only (089)
  METHOD text_in_number_refused.
    ms_agg-cond_field = gc-amount.
    ms_agg-cond_op    = zif_ca_ops_chk_types=>gc_operator-gt.
    ms_agg-cond_value = 'ONE'.
    cl_abap_unit_assert=>assert_equals( act = build_refusal( ) exp = '089' msg = 'Text in a number refused' ).
  ENDMETHOD.


  " Rule: only COUNT and AGE (090)
  METHOD unknown_function_refused.
    ms_agg-agg_func = 'SUM'.
    cl_abap_unit_assert=>assert_equals( act = build_refusal( ) exp = '090' msg = 'SUM refused' ).
  ENDMETHOD.


  " Rule: AGE needs a date field (091)
  METHOD age_without_date_refused.
    ms_agg-agg_func = zif_ca_ops_chk_types=>gc_agg_func-age.
    cl_abap_unit_assert=>assert_equals( act = build_refusal( ) exp = '091' msg = 'AGE without date refused' ).
  ENDMETHOD.


  " Rule: a check that reports per company code needs the company-code field (103)
  METHOD per_company_needs_field.
    cl_abap_unit_assert=>assert_equals( act = build_refusal( iv_bukrs_aware = abap_true ) exp = '103'
                                        msg = 'Company-code aware check without field refused' ).
  ENDMETHOD.


  " Rule: at or above RED an error (exception), at or above AMBER a warning, each with its company code
  METHOD red_is_error_amber_warning.
    TRY.
        DATA(lt_rows) = VALUE zif_ca_ops_chk_types=>tt_agg_row( ( company_code = gc-company row_count = 10 )
                                                                ( company_code = '2000' row_count = 5 ) ).
        DATA(lt_findings) = zcl_ca_ops_agg_query=>to_findings( is_agg   = ms_agg
                                                               it_rows  = lt_rows
                                                               iv_today = gc-today ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_findings ) exp = 2 msg = 'Two findings' ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'Red limit reached: error' ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-company_code exp = gc-company
                                            msg = 'Company code on the finding' ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-check_code exp = zif_ca_ops_chk_types=>gc_code-agg_count
                                            msg = 'Default check code of COUNT' ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-object_key exp = 'ZT_PENDING/R1'
                                            msg = 'Object key check / aggregate' ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 2 ]-severity exp = zif_ca_ops_types=>gc_severity-warning
                                            msg = 'Amber limit reached: warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: below both limits nothing is raised (the runner resolves the earlier exception)
  METHOD below_limits_no_finding.
    TRY.
        DATA(lt_findings) = zcl_ca_ops_agg_query=>to_findings(
                              is_agg   = ms_agg
                              it_rows  = VALUE #( ( company_code = gc-company row_count = 4 ) )
                              iv_today = gc-today ).
        cl_abap_unit_assert=>assert_initial( act = lt_findings msg = 'Below amber: no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: AGE = days since the oldest date; no rows = 0
  METHOD age_value_in_days.
    TRY.
        ms_agg-agg_func = zif_ca_ops_chk_types=>gc_agg_func-age.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_agg_query=>value_of( is_agg   = ms_agg
                                                is_row   = VALUE #( row_count = 3 oldest = '20261031' )
                                                iv_today = gc-today )
          exp = 10
          msg = 'Ten days since the oldest row' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_agg_query=>value_of( is_agg   = ms_agg
                                                is_row   = VALUE #( row_count = 0 )
                                                iv_today = gc-today )
          exp = 0
          msg = 'No rows: age 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
