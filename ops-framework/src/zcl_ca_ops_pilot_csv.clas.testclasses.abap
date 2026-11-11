*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pilot_csv.clas.testclasses.abap
*& Purpose:
*& Pure tests of the pilot pack CSV: one header per record kind and a line
*& per record, rates and averages from the summed figures and their counts
*& (blank without a count, never 0), quoting of a field with the separator
*& or a quote. No doubles; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (build F: pilot pack).
*&---------------------------------------------------------------------*
CLASS ltc_pilot_csv DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS headers_and_records        FOR TESTING.
    METHODS rates_from_sums_and_counts FOR TESTING.
    METHODS no_count_no_rate           FOR TESTING.
    METHODS separator_quoted           FOR TESTING.
ENDCLASS.


CLASS ltc_pilot_csv IMPLEMENTATION.

  " Rule: DAY, BREAK and BASELINE records, each kind after its header line
  METHOD headers_and_records.
    DATA ls_day TYPE zif_ca_ops_pilot_types=>ty_day.
    DATA ls_break TYPE zif_ca_ops_pilot_types=>ty_break.
    DATA ls_baseline TYPE zif_ca_ops_pilot_types=>ty_baseline.
    TRY.
        ls_day-raiseddate  = '20261102'.
        ls_day-area        = 'ZT_OPS_A'.
        ls_day-checkid     = 'ZT_CHECK'.
        ls_day-raisedcount = 4.
        ls_break-area       = 'ZT_OPS_A'.
        ls_break-accountid  = 'ZT_CLEARING'.
        ls_break-keydate    = '20261101'.
        ls_break-groupcount = 10.
        ls_break-explainedcount = 9.
        ls_baseline-area         = 'ZT_OPS_A'.
        ls_baseline-check_id     = 'ZT_CHECK'.
        ls_baseline-baseline_min = 1440.
        DATA(lt_lines) = zcl_ca_ops_pilot_csv=>lines( it_days      = VALUE #( ( ls_day ) )
                                                      it_breaks    = VALUE #( ( ls_break ) )
                                                      it_baselines = VALUE #( ( ls_baseline ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 6 msg = 'Three headers, three records' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ] exp = zif_ca_ops_pilot_types=>gc_header_day
                                            msg = 'Day header first' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lt_lines[ 2 ] CS 'DAY;20261102;ZT_OPS_A;;ZT_CHECK;4;' )
                                          msg = 'Day record' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lt_lines[ 4 ] CS ';10;9;0;90.0' ) msg = 'Share explained' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 6 ] exp = `BASELINE;ZT_OPS_A;ZT_CHECK;1440;`
                                            msg = 'Baseline record' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a rate or average divides the summed figure by its own count
  METHOD rates_from_sums_and_counts.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_pilot_csv=>ratio( iv_value = 1 iv_count = 4 iv_factor = 100 )
                                            exp = `25.0` msg = 'False-positive rate in percent' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_pilot_csv=>ratio( iv_value = CONV decfloat34( '90.0' )
                                                                               iv_count = 3 )
                                            exp = `30.0` msg = 'Average minutes' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without a count the figure is blank, never 0 (not measured is not zero)
  METHOD no_count_no_rate.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_pilot_csv=>ratio( iv_value = 0 iv_count = 0 )
                                             msg = 'Blank' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a field with the separator or a quote is quoted, quotes doubled
  METHOD separator_quoted.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_pilot_csv=>field( 'A;B' ) exp = `"A;B"` msg = 'Separator' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_pilot_csv=>field( 'A"B' ) exp = `"A""B"` msg = 'Quote' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_pilot_csv=>field( 'AB' ) exp = `AB` msg = 'Plain' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
