*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_paym_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS unit tests of the generated payment model (cl_cds_test_environment,
*& the adapter views doubled): amounts are totalled per currency and flow,
*& the trend compares with the same weekday last week, a payment links to
*& several requests and a request to several payments, the feeder reference
*& is masked unless the feeder row marks it visible; ledger model: a
*& payment's share of the batch summary, totals per currency, reversed G/L
*& documents left out, batch key transfer status, the journal line and the
*& G/L documents of a batch key from the released views (I_JournalEntryItem,
*& I_JournalEntry, I_CompanyCode, I_GLAccountText doubled), journal
*& aggregated per reconciled account and day; the old and new clearing
*& document linked on the change timeline. Generated - never edit.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Generated from the product template (payment model, ledger and
*&            | document-change model).
*& 2026-11-11 | Released views: ltc_acct_day doubles I_JournalEntryItem (was
*&            | the journal table); new ltc_journal, ltc_gl_doc.
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


"! ZR_CD_PAYMLEDGER: the payment's SHARE of the batch summary per account and currency - never a G/L line of its own
CLASS ltc_ledger DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        pay     TYPE c LENGTH 2 VALUE 'P1',
        batch   TYPE c LENGTH 2 VALUE 'K1',
        bukrs   TYPE c LENGTH 4 VALUE 'ZT01',
        account TYPE c LENGTH 10 VALUE 'GLA1',
        usd     TYPE c LENGTH 5 VALUE 'USD',
        cad     TYPE c LENGTH 5 VALUE 'CAD',
        gl_doc  TYPE c LENGTH 10 VALUE 'GD1',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS share_of_the_summary FOR TESTING.
    METHODS currencies_kept_apart FOR TESTING.

    METHODS pay_sum
      IMPORTING
        iv_currency   TYPE clike
        iv_amount     TYPE decfloat34
      RETURNING
        VALUE(rs_sum) TYPE zi_cd_ledgpaysum.
    METHODS batch
      IMPORTING
        iv_currency     TYPE clike
        iv_amount       TYPE decfloat34
      RETURNING
        VALUE(rs_batch) TYPE zi_cd_ledgbatch.
ENDCLASS.


CLASS ltc_ledger IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_PAYMLEDGER' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD pay_sum.
    rs_sum-paymentdocument = gc-pay.
    rs_sum-batchkey        = gc-batch.
    rs_sum-companycode     = gc-bukrs.
    rs_sum-glaccount       = gc-account.
    rs_sum-currency        = iv_currency.
    rs_sum-paymentamount   = iv_amount.
    rs_sum-itemcount       = 1.
  ENDMETHOD.


  METHOD batch.
    rs_batch-batchkey       = gc-batch.
    rs_batch-companycode    = gc-bukrs.
    rs_batch-glaccount      = gc-account.
    rs_batch-currency       = iv_currency.
    rs_batch-glreferencekey = gc-batch.
    rs_batch-amount         = iv_amount.
    rs_batch-linecount      = 1.
  ENDMETHOD.


  METHOD setup.
    DATA lt_sums TYPE STANDARD TABLE OF zi_cd_ledgpaysum WITH EMPTY KEY.
    DATA lt_batches TYPE STANDARD TABLE OF zi_cd_ledgbatch WITH EMPTY KEY.
    DATA lt_totals TYPE STANDARD TABLE OF zi_cd_ledggltot WITH EMPTY KEY.
    DATA lt_keys TYPE STANDARD TABLE OF zi_cd_ledgglkey WITH EMPTY KEY.
    DATA ls_total TYPE zi_cd_ledggltot.
    DATA ls_key TYPE zi_cd_ledgglkey.
    go_env->clear_doubles( ).
    " The payment cleared USD 30 of a batch of USD 120 (transferred in full) and CAD 10 of a CAD batch of 40
    INSERT pay_sum( iv_currency = gc-usd iv_amount = 30 ) INTO TABLE lt_sums.
    INSERT pay_sum( iv_currency = gc-cad iv_amount = 10 ) INTO TABLE lt_sums.
    INSERT batch( iv_currency = gc-usd iv_amount = 120 ) INTO TABLE lt_batches.
    INSERT batch( iv_currency = gc-cad iv_amount = 40 ) INTO TABLE lt_batches.
    ls_total-batchkey    = gc-batch.
    ls_total-companycode = gc-bukrs.
    ls_total-glaccount   = gc-account.
    ls_total-currency    = gc-usd.
    ls_total-glamount    = 120.
    ls_total-gllinecount = 1.
    INSERT ls_total INTO TABLE lt_totals.
    ls_key-batchkey            = gc-batch.
    ls_key-companycode         = gc-bukrs.
    ls_key-activedocumentcount = 1.
    ls_key-firstgldocument     = gc-gl_doc.
    INSERT ls_key INTO TABLE lt_keys.
    go_env->insert_test_data( lt_sums ).
    go_env->insert_test_data( lt_batches ).
    go_env->insert_test_data( lt_totals ).
    go_env->insert_test_data( lt_keys ).
  ENDMETHOD.


  METHOD share_of_the_summary.
    TRY.
        SELECT sharepercent, prorataglamount, transferstatus, gldocument FROM zr_cd_paymledger
          WHERE paymentdocument = @gc-pay AND currency = @gc-usd
          ORDER BY batchkey, glaccount
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One row per batch, account, currency' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 1 ]-sharepercent ) exp = CONV decfloat34( 25 )
                                            msg = '30 of a batch of 120 is a 25 % share' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 1 ]-prorataglamount ) exp = CONV decfloat34( 30 )
                                            msg = 'Pro-rata G/L amount = share x consolidated G/L total' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 1 ]-transferstatus ) exp = `TRANSFERRED`
                                            msg = 'Batch total equals its G/L total' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 1 ]-gldocument ) exp = CONV string( gc-gl_doc )
                                            msg = 'The batch G/L document, labelled as the batch''s' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD currencies_kept_apart.
    TRY.
        SELECT currency, batchamount, sharepercent, transferstatus FROM zr_cd_paymledger
          WHERE paymentdocument = @gc-pay
          ORDER BY currency INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One row per currency' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 1 ]-batchamount ) exp = CONV decfloat34( 40 )
                                            msg = 'CAD batch total alone, never added to USD' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 1 ]-sharepercent ) exp = CONV decfloat34( 25 )
                                            msg = 'CAD share within the CAD batch' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 1 ]-transferstatus ) exp = `DIFFERENCE`
                                            msg = 'CAD batch without CAD journal total differs' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZI_CD_LEDGGLTOT: G/L total per batch key, account and currency - reversed G/L documents left out
CLASS ltc_gl_total DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        batch    TYPE c LENGTH 2 VALUE 'K1',
        bukrs    TYPE c LENGTH 4 VALUE 'ZT01',
        year     TYPE n LENGTH 4 VALUE '2026',
        account  TYPE c LENGTH 10 VALUE 'GLA1',
        usd      TYPE c LENGTH 5 VALUE 'USD',
        cad      TYPE c LENGTH 5 VALUE 'CAD',
        doc      TYPE c LENGTH 10 VALUE 'GD1',
        reversed TYPE c LENGTH 10 VALUE 'GD2',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS reversed_doc_excluded FOR TESTING.

    METHODS line
      IMPORTING
        iv_doc         TYPE clike
        iv_line        TYPE clike
        iv_currency    TYPE clike
        iv_amount      TYPE decfloat34
      RETURNING
        VALUE(rs_line) TYPE zi_cd_ledgjrnl.
ENDCLASS.


CLASS ltc_gl_total IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CD_LEDGGLTOT' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD line.
    rs_line-companycode           = gc-bukrs.
    rs_line-fiscalyear            = gc-year.
    rs_line-gldocument            = iv_doc.
    rs_line-journalline           = iv_line.
    rs_line-glaccount             = gc-account.
    rs_line-transactioncurrency   = iv_currency.
    rs_line-amountintranscurrency = iv_amount.
  ENDMETHOD.


  METHOD setup.
    DATA lt_docs TYPE STANDARD TABLE OF zi_cd_ledggldoc WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF zi_cd_ledgjrnl WITH EMPTY KEY.
    DATA ls_doc TYPE zi_cd_ledggldoc.
    go_env->clear_doubles( ).
    ls_doc-batchkey    = gc-batch.
    ls_doc-companycode = gc-bukrs.
    ls_doc-fiscalyear  = gc-year.
    ls_doc-gldocument  = gc-doc.
    INSERT ls_doc INTO TABLE lt_docs.
    ls_doc-gldocument  = gc-reversed.
    ls_doc-isreversed  = abap_true.
    INSERT ls_doc INTO TABLE lt_docs.
    " GD1: USD 100 + 20 and CAD 5; GD2 (reversed): USD 999
    INSERT line( iv_doc = gc-doc iv_line = '000001' iv_currency = gc-usd iv_amount = 100 ) INTO TABLE lt_lines.
    INSERT line( iv_doc = gc-doc iv_line = '000002' iv_currency = gc-usd iv_amount = 20 ) INTO TABLE lt_lines.
    INSERT line( iv_doc = gc-doc iv_line = '000003' iv_currency = gc-cad iv_amount = 5 ) INTO TABLE lt_lines.
    INSERT line( iv_doc = gc-reversed iv_line = '000001' iv_currency = gc-usd iv_amount = 999 ) INTO TABLE lt_lines.
    go_env->insert_test_data( lt_docs ).
    go_env->insert_test_data( lt_lines ).
  ENDMETHOD.


  METHOD reversed_doc_excluded.
    TRY.
        SELECT currency, glamount, gllinecount FROM zi_cd_ledggltot
          WHERE batchkey = @gc-batch
          ORDER BY currency INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One total per currency' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 1 ]-glamount ) exp = CONV decfloat34( 5 )
                                            msg = 'CAD total alone' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 2 ]-glamount ) exp = CONV decfloat34( 120 )
                                            msg = 'USD total without the reversed G/L document' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-gllinecount exp = 2 msg = 'Two USD lines of GD1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_LEDGBATCH: the batch key level - transferred, not transferred, difference
CLASS ltc_batch_key DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        equal   TYPE c LENGTH 2 VALUE 'K1',
        missing TYPE c LENGTH 2 VALUE 'K2',
        differs TYPE c LENGTH 2 VALUE 'K3',
        bukrs   TYPE c LENGTH 4 VALUE 'ZT01',
        account TYPE c LENGTH 10 VALUE 'GLA1',
        usd     TYPE c LENGTH 5 VALUE 'USD',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS transfer_status_per_key FOR TESTING.

    METHODS batch
      IMPORTING
        iv_key          TYPE clike
        iv_amount       TYPE decfloat34
      RETURNING
        VALUE(rs_batch) TYPE zi_cd_ledgbatch.
    METHODS total
      IMPORTING
        iv_key          TYPE clike
        iv_amount       TYPE decfloat34
      RETURNING
        VALUE(rs_total) TYPE zi_cd_ledggltot.
    METHODS key
      IMPORTING
        iv_key        TYPE clike
      RETURNING
        VALUE(rs_key) TYPE zi_cd_ledgglkey.
ENDCLASS.


CLASS ltc_batch_key IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_LEDGBATCH' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD batch.
    rs_batch-batchkey       = iv_key.
    rs_batch-companycode    = gc-bukrs.
    rs_batch-glaccount      = gc-account.
    rs_batch-currency       = gc-usd.
    rs_batch-glreferencekey = iv_key.
    rs_batch-amount         = iv_amount.
  ENDMETHOD.


  METHOD total.
    rs_total-batchkey    = iv_key.
    rs_total-companycode = gc-bukrs.
    rs_total-glaccount   = gc-account.
    rs_total-currency    = gc-usd.
    rs_total-glamount    = iv_amount.
  ENDMETHOD.


  METHOD key.
    rs_key-batchkey            = iv_key.
    rs_key-companycode         = gc-bukrs.
    rs_key-activedocumentcount = 1.
  ENDMETHOD.


  METHOD setup.
    DATA lt_batches TYPE STANDARD TABLE OF zi_cd_ledgbatch WITH EMPTY KEY.
    DATA lt_totals TYPE STANDARD TABLE OF zi_cd_ledggltot WITH EMPTY KEY.
    DATA lt_keys TYPE STANDARD TABLE OF zi_cd_ledgglkey WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " K1 transferred in full, K2 without G/L document, K3 transferred with 10 less on the account
    INSERT batch( iv_key = gc-equal iv_amount = 100 ) INTO TABLE lt_batches.
    INSERT batch( iv_key = gc-missing iv_amount = 50 ) INTO TABLE lt_batches.
    INSERT batch( iv_key = gc-differs iv_amount = 70 ) INTO TABLE lt_batches.
    INSERT total( iv_key = gc-equal iv_amount = 100 ) INTO TABLE lt_totals.
    INSERT total( iv_key = gc-differs iv_amount = 60 ) INTO TABLE lt_totals.
    INSERT key( gc-equal ) INTO TABLE lt_keys.
    INSERT key( gc-differs ) INTO TABLE lt_keys.
    go_env->insert_test_data( lt_batches ).
    go_env->insert_test_data( lt_totals ).
    go_env->insert_test_data( lt_keys ).
  ENDMETHOD.


  METHOD transfer_status_per_key.
    TRY.
        SELECT batchkey, transferstatus, difference, istransferred FROM zr_cd_ledgbatch
          ORDER BY batchkey INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3 msg = 'One row per batch key' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 1 ]-transferstatus ) exp = `TRANSFERRED`
                                            msg = 'K1 subledger = G/L' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 2 ]-transferstatus ) exp = `NOT_TRANSFERRED`
                                            msg = 'K2 has no G/L document' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-istransferred exp = abap_false msg = 'K2 not transferred' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 3 ]-transferstatus ) exp = `DIFFERENCE`
                                            msg = 'K3 G/L total differs' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 3 ]-difference ) exp = CONV decfloat34( 10 )
                                            msg = 'Difference = subledger - G/L' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZI_CD_LEDGJRNL: the journal line from the released views - configured ledger only, header attributes, account
"! text in the company code's chart of accounts, a line of a reversed document flagged (released views doubled)
CLASS ltc_journal DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        ledger       TYPE c LENGTH 2 VALUE 'L1',
        other_ledger TYPE c LENGTH 2 VALUE 'L2',
        bukrs        TYPE c LENGTH 4 VALUE 'ZT01',
        year         TYPE n LENGTH 4 VALUE '2026',
        chart        TYPE c LENGTH 4 VALUE 'ZCOA',
        other_chart  TYPE c LENGTH 4 VALUE 'ZOTH',
        account      TYPE c LENGTH 10 VALUE 'GLA1',
        text         TYPE c LENGTH 50 VALUE 'Clearing account',
        other_text   TYPE c LENGTH 50 VALUE 'Text of another chart of accounts',
        doc          TYPE c LENGTH 10 VALUE 'GD1',
        reversed     TYPE c LENGTH 10 VALUE 'GD2',
        reversal     TYPE c LENGTH 10 VALUE 'GD3',
        doc_type     TYPE c LENGTH 2 VALUE 'ZT',
        transfer     TYPE c LENGTH 5 VALUE 'FKKSU',
        batch        TYPE c LENGTH 20 VALUE 'K1',
        usd          TYPE c LENGTH 5 VALUE 'USD',
        day          TYPE d VALUE '20261110',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS configured_ledger_only FOR TESTING.
    METHODS header_and_account_text FOR TESTING.
    METHODS reversed_doc_flagged FOR TESTING.

    METHODS item
      IMPORTING
        iv_ledger      TYPE clike
        iv_doc         TYPE clike
        iv_amount      TYPE decfloat34
      RETURNING
        VALUE(rs_item) TYPE i_journalentryitem.
    METHODS header
      IMPORTING
        iv_doc           TYPE clike
        iv_reverse_doc   TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_header) TYPE i_journalentry.
ENDCLASS.


CLASS ltc_journal IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CD_LEDGJRNL' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD item.
    rs_item-ledger                      = iv_ledger.
    rs_item-sourceledger                = iv_ledger.
    rs_item-companycode                 = gc-bukrs.
    rs_item-fiscalyear                  = gc-year.
    rs_item-accountingdocument          = iv_doc.
    rs_item-ledgergllineitem            = '000001'.
    rs_item-glaccount                   = gc-account.
    rs_item-postingdate                 = gc-day.
    rs_item-transactioncurrency         = gc-usd.
    rs_item-amountintransactioncurrency = iv_amount.
  ENDMETHOD.


  METHOD header.
    rs_header-companycode                    = gc-bukrs.
    rs_header-fiscalyear                     = gc-year.
    rs_header-accountingdocument             = iv_doc.
    rs_header-accountingdocumenttype         = gc-doc_type.
    rs_header-postingdate                    = gc-day.
    rs_header-accountingdocumentcreationdate = gc-day.
    rs_header-referencedocumenttype          = gc-transfer.
    rs_header-originalreferencedocument      = gc-batch.
    rs_header-reversedocument                = iv_reverse_doc.
    IF iv_reverse_doc IS NOT INITIAL.
      rs_header-reversedocumentfiscalyear = gc-year.
    ENDIF.
  ENDMETHOD.


  METHOD setup.
    DATA lt_cfg TYPE STANDARD TABLE OF zi_cd_ledgcfg WITH EMPTY KEY.
    DATA lt_items TYPE STANDARD TABLE OF i_journalentryitem WITH EMPTY KEY.
    DATA lt_headers TYPE STANDARD TABLE OF i_journalentry WITH EMPTY KEY.
    DATA lt_companies TYPE STANDARD TABLE OF i_companycode WITH EMPTY KEY.
    DATA lt_texts TYPE STANDARD TABLE OF i_glaccounttext WITH EMPTY KEY.
    DATA ls_cfg TYPE zi_cd_ledgcfg.
    DATA ls_company TYPE i_companycode.
    DATA ls_text TYPE i_glaccounttext.
    go_env->clear_doubles( ).
    ls_cfg-ledger = gc-ledger.
    INSERT ls_cfg INTO TABLE lt_cfg.
    ls_company-companycode     = gc-bukrs.
    ls_company-chartofaccounts = gc-chart.
    INSERT ls_company INTO TABLE lt_companies.
    " The account's text in the company code's chart of accounts and in another chart (never shown)
    ls_text-chartofaccounts   = gc-chart.
    ls_text-glaccount         = gc-account.
    ls_text-language          = sy-langu.
    ls_text-glaccountlongname = gc-text.
    INSERT ls_text INTO TABLE lt_texts.
    ls_text-chartofaccounts   = gc-other_chart.
    ls_text-glaccountlongname = gc-other_text.
    INSERT ls_text INTO TABLE lt_texts.
    " GD1 in the configured ledger and in another ledger; GD2 reversed by GD3
    INSERT header( gc-doc ) INTO TABLE lt_headers.
    INSERT header( iv_doc = gc-reversed iv_reverse_doc = gc-reversal ) INTO TABLE lt_headers.
    INSERT item( iv_ledger = gc-ledger iv_doc = gc-doc iv_amount = 100 ) INTO TABLE lt_items.
    INSERT item( iv_ledger = gc-other_ledger iv_doc = gc-doc iv_amount = 999 ) INTO TABLE lt_items.
    INSERT item( iv_ledger = gc-ledger iv_doc = gc-reversed iv_amount = 40 ) INTO TABLE lt_items.
    go_env->insert_test_data( lt_cfg ).
    go_env->insert_test_data( lt_companies ).
    go_env->insert_test_data( lt_texts ).
    go_env->insert_test_data( lt_headers ).
    go_env->insert_test_data( lt_items ).
  ENDMETHOD.


  METHOD configured_ledger_only.
    TRY.
        SELECT ledger, gldocument, amountintranscurrency FROM zi_cd_ledgjrnl
          ORDER BY gldocument INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Lines of the configured ledger only' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 1 ]-ledger ) exp = CONV string( gc-ledger )
                                            msg = 'Ledger of the parameter' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 1 ]-amountintranscurrency )
                                            exp = CONV decfloat34( 100 )
                                            msg = 'Amount in transaction currency of the line' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD header_and_account_text.
    TRY.
        SELECT documenttype, entrydate, glaccounttext, referencetype, referencekey FROM zi_cd_ledgjrnl
          WHERE gldocument = @gc-doc INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One line of GD1' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 1 ]-documenttype ) exp = CONV string( gc-doc_type )
                                            msg = 'Document type from the header' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-entrydate exp = gc-day msg = 'Entry date from the header' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 1 ]-glaccounttext ) exp = CONV string( gc-text )
                                            msg = 'Account text in the chart of accounts of the company code' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 1 ]-referencetype ) exp = CONV string( gc-transfer )
                                            msg = 'Reference type from the header' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 1 ]-referencekey ) exp = CONV string( gc-batch )
                                            msg = 'Reference key from the header' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD reversed_doc_flagged.
    TRY.
        SELECT gldocument, reversaldocument, isreversal FROM zi_cd_ledgjrnl
          ORDER BY gldocument INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'GD1 and GD2' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-isreversal exp = abap_false msg = 'GD1 not reversed' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-isreversal exp = abap_true
                                            msg = 'Line of a reversed document flagged' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 2 ]-reversaldocument )
                                            exp = CONV string( gc-reversal )
                                            msg = 'Reversal document from the header' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZI_CD_LEDGGLDOC: the G/L documents of a batch key found on the released header view by reference type + key +
"! company code; a reversed document listed with IsReversed (I_JournalEntry doubled)
CLASS ltc_gl_doc DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        batch       TYPE c LENGTH 2 VALUE 'K1',
        bukrs       TYPE c LENGTH 4 VALUE 'ZT01',
        other_bukrs TYPE c LENGTH 4 VALUE 'ZT02',
        year        TYPE n LENGTH 4 VALUE '2026',
        account     TYPE c LENGTH 10 VALUE 'GLA1',
        account_2   TYPE c LENGTH 10 VALUE 'GLA2',
        usd         TYPE c LENGTH 5 VALUE 'USD',
        transfer    TYPE c LENGTH 5 VALUE 'FKKSU',
        other_ref   TYPE c LENGTH 5 VALUE 'ZOTH',
        doc         TYPE c LENGTH 10 VALUE 'GD1',
        reversed    TYPE c LENGTH 10 VALUE 'GD2',
        reversal    TYPE c LENGTH 10 VALUE 'GD3',
        other_type  TYPE c LENGTH 10 VALUE 'GD4',
        other_cc    TYPE c LENGTH 10 VALUE 'GD5',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS documents_of_the_key FOR TESTING.

    METHODS header
      IMPORTING
        iv_doc           TYPE clike
        iv_bukrs         TYPE clike DEFAULT gc-bukrs
        iv_ref_type      TYPE clike DEFAULT gc-transfer
        iv_reverse_doc   TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_header) TYPE i_journalentry.
ENDCLASS.


CLASS ltc_gl_doc IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CD_LEDGGLDOC' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD header.
    rs_header-companycode               = iv_bukrs.
    rs_header-fiscalyear                = gc-year.
    rs_header-accountingdocument        = iv_doc.
    rs_header-referencedocumenttype     = iv_ref_type.
    rs_header-originalreferencedocument = gc-batch.
    rs_header-reversedocument           = iv_reverse_doc.
  ENDMETHOD.


  METHOD setup.
    DATA lt_batches TYPE STANDARD TABLE OF zi_cd_ledgbatch WITH EMPTY KEY.
    DATA lt_headers TYPE STANDARD TABLE OF i_journalentry WITH EMPTY KEY.
    DATA ls_batch TYPE zi_cd_ledgbatch.
    go_env->clear_doubles( ).
    " The batch key K1 on two accounts (one document list, not two)
    ls_batch-batchkey       = gc-batch.
    ls_batch-companycode    = gc-bukrs.
    ls_batch-glaccount      = gc-account.
    ls_batch-currency       = gc-usd.
    ls_batch-glreferencekey = gc-batch.
    INSERT ls_batch INTO TABLE lt_batches.
    ls_batch-glaccount      = gc-account_2.
    INSERT ls_batch INTO TABLE lt_batches.
    " GD1 active, GD2 reversed by GD3; GD4 another reference type, GD5 another company code - not the key's
    INSERT header( gc-doc ) INTO TABLE lt_headers.
    INSERT header( iv_doc = gc-reversed iv_reverse_doc = gc-reversal ) INTO TABLE lt_headers.
    INSERT header( iv_doc = gc-other_type iv_ref_type = gc-other_ref ) INTO TABLE lt_headers.
    INSERT header( iv_doc = gc-other_cc iv_bukrs = gc-other_bukrs ) INTO TABLE lt_headers.
    go_env->insert_test_data( lt_batches ).
    go_env->insert_test_data( lt_headers ).
  ENDMETHOD.


  METHOD documents_of_the_key.
    TRY.
        SELECT gldocument, isreversed, reversaldocument FROM zi_cd_ledggldoc
          WHERE batchkey = @gc-batch
          ORDER BY gldocument INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2
                                            msg = 'Reference type + key + company code; one row per document' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-isreversed exp = abap_false msg = 'GD1 active' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-isreversed exp = abap_true msg = 'GD2 reversed' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 2 ]-reversaldocument )
                                            exp = CONV string( gc-reversal )
                                            msg = 'Its reversal document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZI_CD_LEDGACCTDAY: journal aggregated per reconciled account, currency and day in the configured ledger
"! (the released view I_JournalEntryItem doubled, field by field)
CLASS ltc_acct_day DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        ledger       TYPE c LENGTH 2 VALUE 'L1',
        other_ledger TYPE c LENGTH 2 VALUE 'L2',
        bukrs        TYPE c LENGTH 4 VALUE 'ZT01',
        account      TYPE c LENGTH 10 VALUE 'GLA1',
        other_acct   TYPE c LENGTH 10 VALUE 'GLA9',
        usd          TYPE c LENGTH 5 VALUE 'USD',
        cad          TYPE c LENGTH 5 VALUE 'CAD',
        day          TYPE d VALUE '20261110',
        next_day     TYPE d VALUE '20261111',
        transfer     TYPE c LENGTH 10 VALUE 'FKKSU',
        other_ref    TYPE c LENGTH 10 VALUE 'ZOTH',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS aggregated_per_account_day FOR TESTING.

    METHODS jrnl
      IMPORTING
        iv_ledger      TYPE clike
        iv_account     TYPE clike
        iv_currency    TYPE clike
        iv_day         TYPE d
        iv_ref         TYPE clike
        iv_amount      TYPE decfloat34
        iv_docln       TYPE clike
      RETURNING
        VALUE(rs_line) TYPE i_journalentryitem.
ENDCLASS.


CLASS ltc_acct_day IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CD_LEDGACCTDAY' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD jrnl.
    rs_line-ledger                      = iv_ledger.
    rs_line-sourceledger                = iv_ledger.
    rs_line-companycode                 = gc-bukrs.
    rs_line-fiscalyear                  = '2026'.
    rs_line-accountingdocument          = 'GD1'.
    rs_line-ledgergllineitem            = iv_docln.
    rs_line-glaccount                   = iv_account.
    rs_line-transactioncurrency         = iv_currency.
    rs_line-postingdate                 = iv_day.
    rs_line-referencedocumenttype       = iv_ref.
    rs_line-amountintransactioncurrency = iv_amount.
  ENDMETHOD.


  METHOD setup.
    DATA lt_lines TYPE STANDARD TABLE OF i_journalentryitem WITH EMPTY KEY.
    DATA lt_cfg TYPE STANDARD TABLE OF zi_cd_ledgcfg WITH EMPTY KEY.
    DATA lt_accounts TYPE STANDARD TABLE OF zi_cd_ledgacct WITH EMPTY KEY.
    DATA ls_cfg TYPE zi_cd_ledgcfg.
    DATA ls_account TYPE zi_cd_ledgacct.
    go_env->clear_doubles( ).
    ls_cfg-ledger = gc-ledger.
    INSERT ls_cfg INTO TABLE lt_cfg.
    ls_account-companycode = gc-bukrs.
    ls_account-glaccount   = gc-account.
    ls_account-currency    = gc-usd.
    INSERT ls_account INTO TABLE lt_accounts.
    " Day: batch transfer 100 + other posting 50; next day 7; CAD (account not reconciled in CAD), another
    " ledger and an account that is not reconciled are left out
    INSERT jrnl( iv_ledger = gc-ledger iv_account = gc-account iv_currency = gc-usd iv_day = gc-day
                 iv_ref = gc-transfer iv_amount = 100 iv_docln = '000001' ) INTO TABLE lt_lines.
    INSERT jrnl( iv_ledger = gc-ledger iv_account = gc-account iv_currency = gc-usd iv_day = gc-day
                 iv_ref = gc-other_ref iv_amount = 50 iv_docln = '000002' ) INTO TABLE lt_lines.
    INSERT jrnl( iv_ledger = gc-ledger iv_account = gc-account iv_currency = gc-usd iv_day = gc-next_day
                 iv_ref = gc-transfer iv_amount = 7 iv_docln = '000003' ) INTO TABLE lt_lines.
    INSERT jrnl( iv_ledger = gc-ledger iv_account = gc-account iv_currency = gc-cad iv_day = gc-day
                 iv_ref = gc-transfer iv_amount = 9 iv_docln = '000004' ) INTO TABLE lt_lines.
    INSERT jrnl( iv_ledger = gc-other_ledger iv_account = gc-account iv_currency = gc-usd iv_day = gc-day
                 iv_ref = gc-transfer iv_amount = 1000 iv_docln = '000005' ) INTO TABLE lt_lines.
    INSERT jrnl( iv_ledger = gc-ledger iv_account = gc-other_acct iv_currency = gc-usd iv_day = gc-day
                 iv_ref = gc-transfer iv_amount = 3 iv_docln = '000006' ) INTO TABLE lt_lines.
    go_env->insert_test_data( lt_cfg ).
    go_env->insert_test_data( lt_accounts ).
    go_env->insert_test_data( lt_lines ).
  ENDMETHOD.


  METHOD aggregated_per_account_day.
    TRY.
        SELECT postingdate, currency, journalamount, transferamount, journallinecount FROM zi_cd_ledgacctday
          ORDER BY postingdate INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One row per reconciled account and day' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 1 ]-journalamount ) exp = CONV decfloat34( 150 )
                                            msg = 'Day total of the ledger, USD only' ).
        cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_rows[ 1 ]-transferamount ) exp = CONV decfloat34( 100 )
                                            msg = 'Batch transfers apart from other postings' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-journallinecount exp = 2 msg = 'Two lines on the day' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-postingdate exp = gc-next_day msg = 'Next day apart' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_PAYMCHANGE: the old and the new clearing document linked; a reset without re-clearing is critical
CLASS ltc_change DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        old_doc TYPE c LENGTH 4 VALUE 'PAY1',
        new_doc TYPE c LENGTH 4 VALUE 'PAY2',
        bukrs   TYPE c LENGTH 4 VALUE 'ZT01',
        reset   TYPE c LENGTH 16 VALUE 'CLEARING_RESET',
        reclear TYPE c LENGTH 16 VALUE 'RECLEARING',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS old_and_new_linked FOR TESTING.
ENDCLASS.


CLASS ltc_change IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_PAYMCHANGE' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_events TYPE STANDARD TABLE OF zi_cd_docevtall WITH EMPTY KEY.
    DATA ls_event TYPE zi_cd_docevtall.
    go_env->clear_doubles( ).
    " PAY1 reset (no new clearing yet) and later re-cleared by PAY2
    ls_event-paymentdocument  = gc-old_doc.
    ls_event-eventtype        = gc-reset.
    ls_event-eventdocument    = gc-old_doc.
    ls_event-companycode      = gc-bukrs.
    ls_event-originaldocument = gc-old_doc.
    ls_event-eventdate        = '20261110'.
    INSERT ls_event INTO TABLE lt_events.
    ls_event-eventtype        = gc-reclear.
    ls_event-eventdocument    = gc-new_doc.
    ls_event-newdocument      = gc-new_doc.
    ls_event-eventdate        = '20261111'.
    INSERT ls_event INTO TABLE lt_events.
    go_env->insert_test_data( lt_events ).
  ENDMETHOD.


  METHOD old_and_new_linked.
    TRY.
        SELECT eventtype, originaldocument, newdocument, eventcriticality FROM zr_cd_paymchange
          WHERE paymentdocument = @gc-old_doc
          ORDER BY eventdate INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Reset and re-clearing on the timeline' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-eventcriticality exp = 1
                                            msg = 'Reset without new clearing document is critical' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 2 ]-originaldocument ) exp = CONV string( gc-old_doc )
                                            msg = 'Re-clearing names the OLD clearing document' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 2 ]-newdocument ) exp = CONV string( gc-new_doc )
                                            msg = 'and the NEW one' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
