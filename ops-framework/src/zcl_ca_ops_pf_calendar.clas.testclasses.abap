*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_calendar.clas.testclasses.abap
*& Purpose:
*& Tests of the delivered factory calendar: a blank calendar ID makes
*& every day a business day (n days on = the date plus n); with a
*& calendar the function modules answer (replaced in test seams
*& PF_TO_FACTORY_DATE / PF_TO_DATE): a moved date is no business day and
*& the n-th business day comes from the factory date; a calendar error is
*& message 393. Does not prove live SAP runtime behavior (V176).
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
CLASS ltc_pf_calendar DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS blank_calendar_every_day FOR TESTING RAISING zcx_ca_ops_error.
    METHODS moved_date_not_business  FOR TESTING RAISING zcx_ca_ops_error.
    METHODS calendar_error_393       FOR TESTING.
ENDCLASS.


CLASS ltc_pf_calendar IMPLEMENTATION.

  METHOD blank_calendar_every_day.
    DATA(lo_cut) = CAST zif_ca_ops_pf_calendar( NEW zcl_ca_ops_pf_calendar( ) ).
    cl_abap_unit_assert=>assert_true( act = lo_cut->is_business_day( iv_calendar_id = '' iv_date = '20261121' )
                                      msg = 'Every day' ).
    cl_abap_unit_assert=>assert_equals( act = lo_cut->add_business_days( iv_calendar_id = '' iv_date = '20261121' iv_days = 2 )
                                        exp = '20261123' msg = 'Plus two days' ).
  ENDMETHOD.


  METHOD moved_date_not_business.
    TEST-INJECTION pf_to_factory_date.
      ev_factory_date = 100.
      lv_indicator = '+'.
      lv_subrc = 0.
    END-TEST-INJECTION.
    TEST-INJECTION pf_to_date.
      rv_date = '20261123'.
      lv_subrc = 0.
    END-TEST-INJECTION.
    DATA(lo_cut) = CAST zif_ca_ops_pf_calendar( NEW zcl_ca_ops_pf_calendar( ) ).
    cl_abap_unit_assert=>assert_false( act = lo_cut->is_business_day( iv_calendar_id = 'ZT' iv_date = '20261121' )
                                       msg = 'Moved: not a working day' ).
    cl_abap_unit_assert=>assert_equals( act = lo_cut->add_business_days( iv_calendar_id = 'ZT' iv_date = '20261121' iv_days = 0 )
                                        exp = '20261123' msg = 'From the factory date' ).
  ENDMETHOD.


  METHOD calendar_error_393.
    TEST-INJECTION pf_to_factory_date.
      lv_subrc = 4.
    END-TEST-INJECTION.
    TRY.
        NEW zcl_ca_ops_pf_calendar( )->zif_ca_ops_pf_calendar~is_business_day( iv_calendar_id = 'ZT' iv_date = '20261121' ).
        cl_abap_unit_assert=>fail( msg = 'Error expected' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '393' msg = '393' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
