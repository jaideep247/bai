*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_recon_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the three-way reconciliation views on cl_cds_test_environment
*& doubles of FEBEP / FEBKO and ZCD_HCK_METRIC: the bank line carries the
*& payment engine account of XBLNR exactly as EBS derives it (bank text
*& removed, 10 characters, upper case), the company code and house bank of
*& the statement, the line currency or else the statement currency; the
*& result view keeps only the RC_* metrics and splits the group key into
*& company code, G/L account and currency with the ISO day as posting date.
*& Does not prove live SAP runtime behavior.
*& VERIFY-ADT: REPLACE_REGEXPR (PCRE) and SUBSTRING / CONCAT casts on 7.58,
*& create( i_select_base_dependencies = abap_true ) for the FEBEP / FEBKO join.
*& Modification log:
*& 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
*&---------------------------------------------------------------------*
CLASS ltc_recon_cds DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        kukey    TYPE c LENGTH 8 VALUE '00000001',
        kukey2   TYPE c LENGTH 8 VALUE '00000002',
        bukrs    TYPE c LENGTH 4 VALUE 'US01',
        hbkid    TYPE c LENGTH 5 VALUE 'JPMC1',
        hktid    TYPE c LENGTH 5 VALUE 'COLL1',
        xblnr    TYPE c LENGTH 16 VALUE 'JPMC8xx1174412334',
        account  TYPE c LENGTH 10 VALUE '8XX1174412',
        usd      TYPE c LENGTH 5 VALUE 'USD',
        cad      TYPE c LENGTH 5 VALUE 'CAD',
        day      TYPE d VALUE '20261105',
        group    TYPE c LENGTH 35 VALUE 'US01/0011401000/USD',
        run_id   TYPE x LENGTH 16 VALUE '0A0B0C0D0E0F00112233445566778899',
        check_id TYPE c LENGTH 20 VALUE 'A_RECON_3WAY',
        other    TYPE c LENGTH 30 VALUE 'OVERDUE',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS bank_line_account_from_xblnr FOR TESTING.
    METHODS bank_line_currency_fallback  FOR TESTING.
    METHODS results_split_group_key      FOR TESTING.
ENDCLASS.


CLASS ltc_recon_cds IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZI_CD_HCKRCBANKLINE' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZI_CD_HCKRECON' i_select_base_dependencies = abap_true ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_hdr TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA ls_hdr TYPE febko.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA ls_line TYPE febep.
    go_env->clear_doubles( ).
    ls_hdr-kukey = gc_test-kukey.
    ls_hdr-bukrs = gc_test-bukrs.
    ls_hdr-hbkid = gc_test-hbkid.
    ls_hdr-hktid = gc_test-hktid.
    ls_hdr-azdat = gc_test-day.
    ls_hdr-waers = gc_test-usd.
    INSERT ls_hdr INTO TABLE lt_hdr.
    go_env->insert_test_data( i_data = lt_hdr ).
    ls_line-kukey = gc_test-kukey.
    ls_line-esnum = 1.
    ls_line-xblnr = gc_test-xblnr.
    ls_line-vorgc = '166'.
    ls_line-epvoz = 'H'.
    ls_line-kwbtr = 100.
    ls_line-budat = gc_test-day.
    INSERT ls_line INTO TABLE lt_lines.
    ls_line-esnum = 2.
    ls_line-kwaer = gc_test-cad.
    INSERT ls_line INTO TABLE lt_lines.
    " A line without its statement header is not a statement line
    ls_line-kukey = gc_test-kukey2.
    INSERT ls_line INTO TABLE lt_lines.
    go_env->insert_test_data( i_data = lt_lines ).
  ENDMETHOD.


  " Rule: the account of a bank line is the XBLNR account as EBS derives it (scope of the bank leg)
  METHOD bank_line_account_from_xblnr.
    TRY.
        SELECT esnum, peaccount, companycode, housebank, housebankaccount FROM zi_cd_hckrcbankline
          ORDER BY esnum INTO TABLE @DATA(lt_lines).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 2 msg = 'Lines of the statement only' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-peaccount exp = gc_test-account
                                            msg = 'Bank text removed, 10 characters, upper case' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-companycode exp = gc_test-bukrs
                                            msg = 'Company code of the statement' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-housebankaccount exp = gc_test-hktid
                                            msg = 'House bank account of the statement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the line currency, else the statement currency (as the EBS FEB source)
  METHOD bank_line_currency_fallback.
    TRY.
        SELECT esnum, currency FROM zi_cd_hckrcbankline ORDER BY esnum INTO TABLE @DATA(lt_lines).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-currency exp = gc_test-usd
                                            msg = 'Statement currency when the line has none' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 2 ]-currency exp = gc_test-cad msg = 'Line currency' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only RC_* metrics; the group key splits into company code / G/L account / currency
  METHOD results_split_group_key.
    DATA lt_metrics TYPE STANDARD TABLE OF zcd_hck_metric WITH EMPTY KEY.
    DATA ls_metric TYPE zcd_hck_metric.
    TRY.
        ls_metric-run_id   = gc_test-run_id.
        ls_metric-check_id = gc_test-check_id.
        ls_metric-metric   = zif_cd_hck_recon_types=>gc_metric-diff_bank_gl.
        ls_metric-dim1     = gc_test-group.
        ls_metric-dim2     = '2026-11-05'.
        ls_metric-value    = 40.
        INSERT ls_metric INTO TABLE lt_metrics.
        ls_metric-metric   = zif_cd_hck_recon_types=>gc_metric-days.
        ls_metric-dim2     = zif_cd_hck_recon_types=>gc_status-break.
        ls_metric-value    = 1.
        INSERT ls_metric INTO TABLE lt_metrics.
        ls_metric-metric   = gc_test-other.
        INSERT ls_metric INTO TABLE lt_metrics.
        go_env->insert_test_data( i_data = lt_metrics ).
        SELECT metric, companycode, glaccount, currency, postingdate, metricvalue FROM zi_cd_hckrecon
          ORDER BY metric INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Other metrics left out' ).
        DATA(ls_diff) = lt_rows[ metric = zif_cd_hck_recon_types=>gc_metric-diff_bank_gl ].
        cl_abap_unit_assert=>assert_equals( act = ls_diff-companycode exp = gc_test-bukrs msg = 'Company code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_diff-glaccount exp = '0011401000' msg = 'G/L account' ).
        cl_abap_unit_assert=>assert_equals( act = ls_diff-currency exp = gc_test-usd msg = 'Currency' ).
        cl_abap_unit_assert=>assert_equals( act = ls_diff-postingdate exp = gc_test-day msg = 'Posting day' ).
        cl_abap_unit_assert=>assert_initial( act = lt_rows[ metric = zif_cd_hck_recon_types=>gc_metric-days ]-postingdate
                                             msg = 'Status rows have no day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
