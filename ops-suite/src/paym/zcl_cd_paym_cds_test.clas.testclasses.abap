*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_paym_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS unit tests of the generated payment model (cl_cds_test_environment,
*& the adapter views doubled): amounts are totalled per currency and flow,
*& the trend compares with the same weekday last week, a payment links to
*& several requests and a request to several payments, the feeder reference
*& is masked unless the feeder row marks it visible. Generated - never edit.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Generated from the product template (payment model).
*&---------------------------------------------------------------------*
"! ZR_CD_PAYMCUBE: two currencies are never added; collections and disbursements stay apart
CLASS ltc_cube DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        day   TYPE d VALUE '20261110',
        bukrs TYPE c LENGTH 4 VALUE 'ZT01',
        usd   TYPE c LENGTH 5 VALUE 'USD',
        cad   TYPE c LENGTH 5 VALUE 'CAD',
        src   TYPE c LENGTH 10 VALUE 'SRC1',
        disb  TYPE c LENGTH 1 VALUE 'D',
        coll  TYPE c LENGTH 1 VALUE 'C',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS amounts_per_currency FOR TESTING.
    METHODS flows_kept_apart FOR TESTING.

    METHODS fact
      IMPORTING
        iv_doc         TYPE clike
        iv_flow        TYPE clike
        iv_currency    TYPE clike
        iv_amount      TYPE decfloat34
        iv_late        TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_fact) TYPE zi_cd_paymfact.
ENDCLASS.


CLASS ltc_cube IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_PAYMCUBE' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD fact.
    rs_fact-businessdate    = gc-day.
    rs_fact-paymentdocument = iv_doc.
    rs_fact-companycode     = gc-bukrs.
    rs_fact-flow            = iv_flow.
    rs_fact-source          = gc-src.
    rs_fact-currency        = iv_currency.
    rs_fact-companycurrency = gc-usd.
    rs_fact-amount          = iv_amount.
    rs_fact-islate          = iv_late.
  ENDMETHOD.


  METHOD setup.
    DATA lt_facts TYPE STANDARD TABLE OF zi_cd_paymfact WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " USD 100 + 50 (one late), CAD 70 - disbursements; USD 30 - a collection of the same day and source
    lt_facts = VALUE #( ( fact( iv_doc = 'P1' iv_flow = gc-disb iv_currency = gc-usd iv_amount = 100 ) )
                        ( fact( iv_doc = 'P2' iv_flow = gc-disb iv_currency = gc-usd iv_amount = 50 iv_late = abap_true ) )
                        ( fact( iv_doc = 'P3' iv_flow = gc-disb iv_currency = gc-cad iv_amount = 70 ) )
                        ( fact( iv_doc = 'P4' iv_flow = gc-coll iv_currency = gc-usd iv_amount = 30 ) ) ).
    go_env->insert_test_data( lt_facts ).
  ENDMETHOD.


  METHOD amounts_per_currency.
    TRY.
        SELECT currency, itemcount, latecount, amount, islocalcurrency FROM zr_cd_paymcube
          WHERE businessdate = @gc-day AND flow = @gc-disb
          ORDER BY currency INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One row per currency' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-currency exp = gc-cad msg = 'CAD row' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 1 ]-amount ) exp = CONV decfloat34( 70 )
                                            msg = 'CAD total alone, never added to USD' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-islocalcurrency exp = abap_false
                                            msg = 'CAD is not the company code currency' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 2 ]-amount ) exp = CONV decfloat34( 150 )
                                            msg = 'USD total of the two USD payments' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-itemcount exp = 2 msg = 'Two USD payments' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-latecount exp = 1 msg = 'One of them late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD flows_kept_apart.
    TRY.
        SELECT flow, amount FROM zr_cd_paymcube
          WHERE businessdate = @gc-day AND currency = @gc-usd
          ORDER BY flow INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Collections and disbursements apart' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 1 ]-amount ) exp = CONV decfloat34( 30 )
                                            msg = 'Collection total (absolute amount, own row)' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 2 ]-amount ) exp = CONV decfloat34( 150 )
                                            msg = 'Disbursement total (absolute amount, own row)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_PAYMTREND: the same weekday of the previous week, per category and currency
CLASS ltc_trend DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        day       TYPE d VALUE '20261110',
        last_week TYPE d VALUE '20261103',
        bukrs     TYPE c LENGTH 4 VALUE 'ZT01',
        usd       TYPE c LENGTH 5 VALUE 'USD',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS same_weekday_last_week FOR TESTING.
ENDCLASS.


CLASS ltc_trend IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_PAYMTREND' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_days TYPE STANDARD TABLE OF zi_cd_paymtrendb WITH EMPTY KEY.
    DATA lt_totals TYPE STANDARD TABLE OF zi_cd_paymday WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_days = VALUE #( ( businessdate = gc-day companycode = gc-bukrs currency = gc-usd itemcount = 40
                         comparedate = '20261117' )
                       ( businessdate = gc-last_week companycode = gc-bukrs currency = gc-usd itemcount = 1000
                         comparedate = gc-day ) ).
    lt_totals = VALUE #( ( businessdate = gc-day companycode = gc-bukrs daycount = 40 )
                         ( businessdate = gc-last_week companycode = gc-bukrs daycount = 2000000 ) ).
    go_env->insert_test_data( lt_days ).
    go_env->insert_test_data( lt_totals ).
  ENDMETHOD.


  METHOD same_weekday_last_week.
    TRY.
        SELECT businessdate, itemcount, prevweekcount, ispeakday FROM zr_cd_paymtrend
          ORDER BY businessdate INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One row per day and category' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-prevweekcount exp = 1000
                                            msg = 'Tuesday compared with the Tuesday before' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-prevweekcount exp = 0
                                            msg = 'No payments a week earlier = 0' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-ispeakday exp = abap_true
                                            msg = 'Two million payments mark a peak day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_PAYMREQLINK: a payment settles several requests, a request is paid by several payments (n:m)
CLASS ltc_link DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        pay_1 TYPE c LENGTH 2 VALUE 'P1',
        pay_2 TYPE c LENGTH 2 VALUE 'P2',
        req_a TYPE c LENGTH 4 VALUE 'REQA',
        req_b TYPE c LENGTH 4 VALUE 'REQB',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS payment_to_many_requests FOR TESTING.
    METHODS request_to_many_payments FOR TESTING.
ENDCLASS.


CLASS ltc_link IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_PAYMREQLINK' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_links TYPE STANDARD TABLE OF zi_cd_paymreqlink WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " P1 settles REQA and REQB; REQB is paid partly by P1 and partly by P2
    lt_links = VALUE #( ( paymentdocument = gc-pay_1 requestreference = gc-req_a )
                        ( paymentdocument = gc-pay_1 requestreference = gc-req_b )
                        ( paymentdocument = gc-pay_2 requestreference = gc-req_b ) ).
    go_env->insert_test_data( lt_links ).
  ENDMETHOD.


  METHOD payment_to_many_requests.
    TRY.
        SELECT requestreference FROM zr_cd_paymreqlink WHERE paymentdocument = @gc-pay_1
          ORDER BY requestreference INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'P1 settled two requests' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD request_to_many_payments.
    TRY.
        SELECT paymentdocument FROM zr_cd_paymreqlink WHERE requestreference = @gc-req_b
          ORDER BY paymentdocument INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'REQB paid by two payments' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
