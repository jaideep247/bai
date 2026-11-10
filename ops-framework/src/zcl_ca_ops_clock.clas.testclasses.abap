*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_clock.clas.testclasses.abap
*& Purpose:
*& Unit tests of the system clock: today and time are the system fields,
*& now is a UTC time stamp between two readings taken around the call;
*& does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-10 | Moved from ZCL_CD_OPS_CLOCK to the reusable framework ZCA_OPS (test include).
*&---------------------------------------------------------------------*
CLASS ltc_clock DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zif_ca_ops_clock.

    METHODS setup.
    METHODS teardown.
    METHODS now_is_current_time_stamp FOR TESTING.
    METHODS today_is_system_date FOR TESTING.
    METHODS time_is_system_time FOR TESTING.
ENDCLASS.


CLASS ltc_clock IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_ca_ops_clock( ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.


  " Rule: now( ) is the current UTC time stamp (between two readings around the call)
  METHOD now_is_current_time_stamp.
    DATA lv_before TYPE timestampl.
    DATA lv_after TYPE timestampl.
    TRY.
        GET TIME STAMP FIELD lv_before.
        DATA(lv_now) = mo_cut->now( ).
        GET TIME STAMP FIELD lv_after.
        cl_abap_unit_assert=>assert_true( act = xsdbool( lv_now >= lv_before AND lv_now <= lv_after )
                                          msg = 'now( ) lies between the two readings' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: today( ) is the system date
  METHOD today_is_system_date.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->today( ) exp = sy-datum msg = 'today( ) = sy-datum' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: time( ) is the system time (same second or the next one)
  METHOD time_is_system_time.
    TRY.
        DATA(lv_before) = sy-uzeit.
        DATA(lv_time) = mo_cut->time( ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lv_time >= lv_before OR lv_before > lv_time + 1 )
                                          msg = 'time( ) = sy-uzeit' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
