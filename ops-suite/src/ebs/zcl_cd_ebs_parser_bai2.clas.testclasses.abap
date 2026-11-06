*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_parser_bai2.clas.testclasses.abap
*& Purpose:
*& ABAP Unit tests for the BAI2 parser: records, 88 continuation, funds
*& types, balances, lines and S00/S06/S11/S12 findings. Inputs are inline
*& strings (no file access); does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A86: negative fixtures for empty 49/98/99 trailer fields (TRAILER_FIELD_MISSING).
*&---------------------------------------------------------------------*
CLASS ltc_parser_bai2 DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    "! Scenario intent: which defect the base file carries
    TYPES:
      BEGIN OF ty_flags,
        bad_account_total TYPE abap_bool,
        bad_record_count  TYPE abap_bool,
        no_file_trailer   TYPE abap_bool,
        bad_item_count    TYPE abap_bool,
        "! A86: replaces the 49 / 98 / 99 trailer of the base file
        account_trailer   TYPE string,
        group_trailer     TYPE string,
        file_trailer      TYPE string,
      END OF ty_flags.

    CONSTANTS gc_file_name TYPE string VALUE `BAI2_20261104.TXT`.
    CONSTANTS gc_stmt_key TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'S0001'.
    CONSTANTS gc_usd TYPE zif_cd_ops_types=>ty_currency VALUE 'USD'.
    CONSTANTS gc_as_of TYPE d VALUE '20261103'.
    CONSTANTS gc_msgno_not_bai2 TYPE symsgno VALUE '150'.

    CONSTANTS:
      BEGIN OF gc_check,
        acct_total   TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_ACCT_CTRL_TOTAL',
        record_count TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_RECORD_COUNT',
        item_count   TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_ITEM_COUNT',
        missing_trl  TYPE zif_cd_ops_types=>ty_check_code VALUE 'MISSING_TRAILER',
        empty_file   TYPE zif_cd_ops_types=>ty_check_code VALUE 'EMPTY_FILE',
        info_skipped TYPE zif_cd_ops_types=>ty_check_code VALUE 'INFO_CODE_SKIPPED',
        trl_missing  TYPE zif_cd_ops_types=>ty_check_code VALUE 'TRAILER_FIELD_MISSING',
      END OF gc_check.

    DATA mv_content TYPE string.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    "! Content with 88 continuation, signed balances, funds types S, D, Z and an 890
    METHODS configure_funds_scenario.

    METHODS parse
      RETURNING
        VALUE(rs_file) TYPE zif_cd_ebs_types=>ty_file
      RAISING
        zcx_cd_ops_error.

    METHODS finding
      IMPORTING
        it_findings       TYPE zif_cd_ops_types=>tt_finding
        iv_check_code     TYPE zif_cd_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

    METHODS file_header_fields_mapped FOR TESTING.
    METHODS account_maps_to_statement FOR TESTING.
    METHODS status_codes_map_balances FOR TESTING.
    METHODS detail_records_become_lines FOR TESTING.
    METHODS consistent_file_no_findings FOR TESTING.
    METHODS continuation_88_extends_03 FOR TESTING.
    METHODS signed_balance_negative FOR TESTING.
    METHODS funds_type_s_shifts_refs FOR TESTING.
    METHODS funds_type_d_shifts_refs FOR TESTING.
    METHODS continuation_88_extends_text FOR TESTING.
    METHODS non_monetary_890_skipped FOR TESTING.
    METHODS acct_total_mismatch_blocks FOR TESTING.
    METHODS acct_record_count_mismatch FOR TESTING.
    METHODS item_count_mismatch_s12 FOR TESTING.
    METHODS missing_99_is_s00 FOR TESTING.
    METHODS empty_content_is_s11 FOR TESTING.
    METHODS not_bai2_raises FOR TESTING.
    METHODS trailer_49_total_missing FOR TESTING.
    METHODS trailer_49_count_missing FOR TESTING.
    METHODS trailer_98_fields_missing FOR TESTING.
    METHODS trailer_99_fields_missing FOR TESTING.
    METHODS trailer_zero_is_declared FOR TESTING.

    "! Findings as OBJECT_TYPE/RULE_ID/CHECK_CODE/SEVERITY
    METHODS finding_codes
      IMPORTING
        it_findings     TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rt_codes) TYPE string_table.

ENDCLASS.


CLASS ltc_parser_bai2 IMPLEMENTATION.

  METHOD configure_scenario.
    DATA(lv_account_trailer) = COND string(
      WHEN is_flags-bad_account_total = abap_true THEN `49,+604000099,5/`
      WHEN is_flags-bad_record_count = abap_true  THEN `49,+604000000,6/`
      WHEN is_flags-account_trailer IS NOT INITIAL THEN is_flags-account_trailer
      ELSE `49,+604000000,5/` ).
    DATA(lv_credit_count) = COND string( WHEN is_flags-bad_item_count = abap_true THEN `3` ELSE `2` ).
    DATA(lv_file_trailer) = COND string( WHEN is_flags-no_file_trailer = abap_true THEN ``
                                         WHEN is_flags-file_trailer IS NOT INITIAL THEN |\n{ is_flags-file_trailer }|
                                         ELSE |\n99,+604000000,1,9/| ).
    DATA(lv_group_trailer) = COND string( WHEN is_flags-group_trailer IS NOT INITIAL THEN is_flags-group_trailer
                                          ELSE `98,+604000000,1,7/` ).
    mv_content = |01,BANKSNDR,CUSTRCVR,261104,0630,1104A,80,,2/\n| &&
                 |02,CUSTRCVR,999000001,1,261103,2400,USD,2/\n| &&
                 |03,000123456789,USD,010,+150000000,,,015,+151250000,,,040,148000000,,,| &&
                 |045,149250000,,,100,2000000,{ lv_credit_count },,400,750000,1,/\n| &&
                 |16,165,1500000,0,BR0001,INV20261103,ACH CREDIT ACME CORP/\n| &&
                 |16,195,500000,V,261104,0900,BR0002,,WIRE IN, REF 77/\n| &&
                 |16,475,750000,0,BR0003,10045/\n| &&
                 |{ lv_account_trailer }\n| &&
                 lv_group_trailer &&
                 lv_file_trailer.
  ENDMETHOD.

  METHOD configure_funds_scenario.
    mv_content = |01,BANKSNDR,CUSTRCVR,261104,0630,1104B,80,,2/\n| &&
                 |02,CUSTRCVR,999000001,1,261103,,USD,2/\n| &&
                 |03,000987654321,USD,010,-25000,,,015,+75000,,/\n| &&
                 |88,100,150000,2,,400,50000,1,/\n| &&
                 |16,142,100000,S,60000,30000,10000,BR1001,CR1001,LOCKBOX DEPOSIT/\n| &&
                 |16,174,50000,D,2,1,30000,2,20000,BR1002,CR1002,FIRST PART OF TEXT\n| &&
                 |88,SECOND PART\n| &&
                 |16,451,50000,Z,BR1003,,ACH DEBIT/\n| &&
                 |16,890,,,BR1004,,INFO ONLY/\n| &&
                 |49,+450000,8/\n| &&
                 |98,+450000,1,10/\n| &&
                 |99,+450000,1,12/|.
  ENDMETHOD.

  METHOD parse.
    DATA(lo_cut) = NEW zcl_cd_ebs_parser_bai2( ).
    rs_file = lo_cut->zif_cd_ebs_parser~parse( iv_content   = mv_content
                                               iv_file_name = gc_file_name ).
  ENDMETHOD.

  METHOD finding.
    rs_finding = VALUE #( it_findings[ check_code = iv_check_code ] OPTIONAL ).
  ENDMETHOD.

  " BAI2 01: sender, receiver, creation date/time, file id; 99 control total; physical record count
  METHOD file_header_fields_mapped.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_file) = parse( ).
        DATA(ls_exp) = VALUE zif_cd_ebs_types=>ty_file(
          format        = zif_cd_ebs_types=>gc_format-bai2
          file_name     = gc_file_name
          file_id       = '1104A'
          sender_id     = 'BANKSNDR'
          receiver_id   = 'CUSTRCVR'
          created_date  = '20261104'
          created_time  = '063000'
          record_count  = 9
          control_total = '6040000.00' ).
        CLEAR: ls_file-statements, ls_file-lines, ls_file-findings.
        cl_abap_unit_assert=>assert_equals( act = ls_file
                                            exp = ls_exp
                                            msg = 'File header/trailer fields not mapped as expected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 03: one statement per account; key S0001, as-of date from 02, totals 100/400
  METHOD account_maps_to_statement.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_file-statements )
                                            exp = 1
                                            msg = 'One 03 account must give one statement' ).
        DATA(ls_stmt) = ls_file-statements[ 1 ].
        CLEAR ls_stmt-balances.
        DATA(ls_exp) = VALUE zif_cd_ebs_types=>ty_statement(
          stmt_key       = gc_stmt_key
          format         = zif_cd_ebs_types=>gc_format-bai2
          source         = zif_cd_ebs_types=>gc_source-file
          bank_id        = '999000001'
          account_no     = '000123456789'
          currency       = gc_usd
          stmt_id        = '1104A-1-000123456789'
          stmt_no        = '1104A'
          stmt_date      = gc_as_of
          created_date   = '20261104'
          created_time   = '063000'
          has_opening    = abap_true
          opening_bal    = '1500000.00'
          has_closing    = abap_true
          closing_bal    = '1512500.00'
          has_totals     = abap_true
          total_credits  = '20000.00'
          total_debits   = '7500.00'
          credit_count   = 2
          debit_count    = 1
          declared_count = 3 ).
        cl_abap_unit_assert=>assert_equals( act = ls_stmt
                                            exp = ls_exp
                                            msg = 'Statement header not mapped as expected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 03 status codes: 010 OPBD, 015 CLBD, 040 OPAV, 045 CLAV (dated with as-of date)
  METHOD status_codes_map_balances.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_file) = parse( ).
        DATA(lt_exp) = VALUE zif_cd_ebs_types=>tt_balance(
          currency = gc_usd bal_date = gc_as_of
          ( bal_type = zif_cd_ebs_types=>gc_balance-opening_booked amount = '1500000.00' )
          ( bal_type = zif_cd_ebs_types=>gc_balance-closing_booked amount = '1512500.00' )
          ( bal_type = zif_cd_ebs_types=>gc_balance-opening_avail  amount = '1480000.00' )
          ( bal_type = zif_cd_ebs_types=>gc_balance-closing_avail  amount = '1492500.00' ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_file-statements[ 1 ]-balances
                                            exp = lt_exp
                                            msg = 'Balance table not mapped as expected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 16: cdi from type code range, reference = cust ref else bank ref, 475 cust ref = check no
  METHOD detail_records_become_lines.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_file) = parse( ).
        DATA(lt_exp) = VALUE zif_cd_ebs_types=>tt_line(
          stmt_key = gc_stmt_key scheme = zif_cd_ebs_types=>gc_scheme-bai2 currency = gc_usd booking_date = gc_as_of
          ( line_no = 1 btc_code = '165' cdi = zif_cd_ebs_types=>gc_cdi-credit amount = '15000.00'
            value_date = gc_as_of reference = 'INV20261103' bank_ref = 'BR0001' cust_ref = 'INV20261103'
            addtl_info = 'ACH CREDIT ACME CORP' )
          ( line_no = 2 btc_code = '195' cdi = zif_cd_ebs_types=>gc_cdi-credit amount = '5000.00'
            value_date = '20261104' reference = 'BR0002' bank_ref = 'BR0002'
            addtl_info = 'WIRE IN, REF 77' )
          ( line_no = 3 btc_code = '475' cdi = zif_cd_ebs_types=>gc_cdi-debit amount = '7500.00'
            value_date = gc_as_of reference = '10045' bank_ref = 'BR0003' cust_ref = '10045'
            check_no = '10045' ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_file-lines
                                            exp = lt_exp
                                            msg = 'Detail lines not mapped as expected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 49/98/99: consistent totals and counts produce no findings
  METHOD consistent_file_no_findings.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals( act = ls_file-findings
                                            exp = VALUE zif_cd_ops_types=>tt_finding( )
                                            msg = 'A consistent file must not produce findings' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 88: continuation appends the 100/400 summary groups to the preceding 03
  METHOD continuation_88_extends_03.
    TRY.
        configure_funds_scenario( ).
        DATA(ls_file) = parse( ).
        DATA(ls_stmt) = ls_file-statements[ 1 ].
        cl_abap_unit_assert=>assert_equals(
          act = VALUE zif_cd_ebs_types=>ty_statement( has_totals     = ls_stmt-has_totals
                                                       total_credits  = ls_stmt-total_credits
                                                       credit_count   = ls_stmt-credit_count
                                                       total_debits   = ls_stmt-total_debits
                                                       debit_count    = ls_stmt-debit_count
                                                       declared_count = ls_stmt-declared_count )
          exp = VALUE zif_cd_ebs_types=>ty_statement( has_totals     = abap_true
                                                       total_credits  = '1500.00'
                                                       credit_count   = 2
                                                       total_debits   = '500.00'
                                                       debit_count    = 1
                                                       declared_count = 3 )
          msg = '88 continuation of 03 not applied' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 03: balances are signed; '-' gives a negative (debit) balance
  METHOD signed_balance_negative.
    TRY.
        configure_funds_scenario( ).
        DATA(ls_file) = parse( ).
        DATA(ls_stmt) = ls_file-statements[ 1 ].
        DATA(lt_exp) = VALUE zif_cd_ebs_types=>tt_balance(
          currency = gc_usd bal_date = gc_as_of
          ( bal_type = zif_cd_ebs_types=>gc_balance-opening_booked amount = '-250.00' )
          ( bal_type = zif_cd_ebs_types=>gc_balance-closing_booked amount = '750.00' ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_stmt-balances
                                            exp = lt_exp
                                            msg = 'Signed balances not mapped' ).
        cl_abap_unit_assert=>assert_equals( act = ls_stmt-opening_bal
                                            exp = CONV zif_cd_ops_types=>ty_amount( '-250.00' )
                                            msg = 'Opening balance must be negative' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 funds type S: three availability amounts precede bank and customer reference
  METHOD funds_type_s_shifts_refs.
    TRY.
        configure_funds_scenario( ).
        DATA(ls_file) = parse( ).
        DATA(ls_line) = ls_file-lines[ 1 ].
        DATA(ls_exp) = VALUE zif_cd_ebs_types=>ty_line(
          stmt_key = gc_stmt_key line_no = 1 scheme = zif_cd_ebs_types=>gc_scheme-bai2 btc_code = '142'
          cdi = zif_cd_ebs_types=>gc_cdi-credit amount = '1000.00' currency = gc_usd
          booking_date = gc_as_of value_date = gc_as_of reference = 'CR1001' bank_ref = 'BR1001'
          cust_ref = 'CR1001' addtl_info = 'LOCKBOX DEPOSIT' ).
        cl_abap_unit_assert=>assert_equals( act = ls_line
                                            exp = ls_exp
                                            msg = 'Funds type S must shift references by three fields' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 funds type D: count n then n (days, amount) pairs precede the references
  METHOD funds_type_d_shifts_refs.
    TRY.
        configure_funds_scenario( ).
        DATA(ls_file) = parse( ).
        DATA(ls_line) = ls_file-lines[ 2 ].
        cl_abap_unit_assert=>assert_equals(
          act = VALUE zif_cd_ebs_types=>ty_line( btc_code = ls_line-btc_code amount = ls_line-amount
                                                  bank_ref = ls_line-bank_ref cust_ref = ls_line-cust_ref
                                                  reference = ls_line-reference )
          exp = VALUE zif_cd_ebs_types=>ty_line( btc_code = '174' amount = '500.00' bank_ref = 'BR1002'
                                                  cust_ref = 'CR1002' reference = 'CR1002' )
          msg = 'Funds type D must shift references by 1 + 2n fields' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 88 after 16: continues the free-text field of the detail record
  METHOD continuation_88_extends_text.
    TRY.
        configure_funds_scenario( ).
        DATA(ls_file) = parse( ).
        DATA(ls_line) = ls_file-lines[ 2 ].
        cl_abap_unit_assert=>assert_equals( act = ls_line-addtl_info
                                            exp = CONV zif_cd_ebs_types=>ty_line-addtl_info( 'FIRST PART OF TEXT SECOND PART' )
                                            msg = '88 continuation of 16 text not appended' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 890 (7xx-9xx): informational, no line; only an I finding is recorded
  METHOD non_monetary_890_skipped.
    TRY.
        configure_funds_scenario( ).
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals( act = VALUE string_table( FOR l IN ls_file-lines ( CONV #( l-btc_code ) ) )
                                            exp = VALUE string_table( ( `142` ) ( `174` ) ( `451` ) )
                                            msg = 'Type code 890 must not become a line' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE string_table( FOR f IN ls_file-findings ( |{ f-rule_id }/{ f-check_code }/{ f-severity }| ) )
          exp = VALUE string_table( ( |S00/{ gc_check-info_skipped }/I| ) )
          msg = 'Only one information finding expected for the skipped 890' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 49: control total = algebraic sum of 03 + 16 amounts; mismatch is S06 severity B
  METHOD acct_total_mismatch_blocks.
    TRY.
        configure_scenario( VALUE #( bad_account_total = abap_true ) ).
        DATA(ls_finding) = finding( it_findings  = parse( )-findings
                                    iv_check_code = gc_check-acct_total ).
        CLEAR ls_finding-message.
        cl_abap_unit_assert=>assert_equals(
          act = ls_finding
          exp = VALUE zif_cd_ops_types=>ty_finding( object_type = 'STMT' object_key = gc_stmt_key rule_id = 'S06'
                                                     check_code = gc_check-acct_total
                                                     severity = zif_cd_ops_types=>gc_severity-block
                                                     amount = '-0.99' currency = gc_usd )
          msg = 'Account control total mismatch must block (S06/B)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 49: number of records = 03 + 16 + 88 + 49 of the account; mismatch is S12 severity E
  METHOD acct_record_count_mismatch.
    TRY.
        configure_scenario( VALUE #( bad_record_count = abap_true ) ).
        DATA(lt_findings) = parse( )-findings.
        cl_abap_unit_assert=>assert_equals(
          act = VALUE string_table( FOR f IN lt_findings ( |{ f-object_key }/{ f-rule_id }/{ f-check_code }/{ f-severity }| ) )
          exp = VALUE string_table( ( |{ gc_stmt_key }/S12/{ gc_check-record_count }/E| ) )
          msg = 'Account record count mismatch must give exactly one S12/E finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 03 item count of 100 = number of credit 16 records; mismatch is S12 severity E
  METHOD item_count_mismatch_s12.
    TRY.
        configure_scenario( VALUE #( bad_item_count = abap_true ) ).
        DATA(lt_findings) = parse( )-findings.
        cl_abap_unit_assert=>assert_equals(
          act = VALUE string_table( FOR f IN lt_findings ( |{ f-rule_id }/{ f-check_code }/{ f-severity }| ) )
          exp = VALUE string_table( ( |S12/{ gc_check-item_count }/E| ) )
          msg = 'Credit item count mismatch must give exactly one S12/E finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BAI2 99: a file without file trailer is structurally incomplete (S00 MISSING_TRAILER, E)
  METHOD missing_99_is_s00.
    TRY.
        configure_scenario( VALUE #( no_file_trailer = abap_true ) ).
        DATA(lt_findings) = parse( )-findings.
        cl_abap_unit_assert=>assert_equals(
          act = VALUE string_table( FOR f IN lt_findings ( |{ f-object_type }/{ f-rule_id }/{ f-check_code }/{ f-severity }| ) )
          exp = VALUE string_table( ( |FILE/S00/{ gc_check-missing_trl }/E| ) )
          msg = 'Missing 99 must give exactly one S00 MISSING_TRAILER finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " S11: empty content is not an exception but an EMPTY_FILE finding with severity B
  METHOD empty_content_is_s11.
    TRY.
        mv_content = | \n\n |.
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE string_table( FOR f IN ls_file-findings ( |{ f-rule_id }/{ f-check_code }/{ f-severity }| ) )
          exp = VALUE string_table( ( |S11/{ gc_check-empty_file }/B| ) )
          msg = 'Empty content must give one S11 EMPTY_FILE finding' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_file-statements )
                                            exp = 0
                                            msg = 'Empty content must not give statements' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " Unreadable input: content whose first record is not 01 raises ZCX_CD_OPS_ERROR (150)
  METHOD not_bai2_raises.
    mv_content = `<?xml version="1.0"?><Document/>`.
    TRY.
        parse( ).
        cl_abap_unit_assert=>fail( msg = 'Non-BAI2 content must raise ZCX_CD_OPS_ERROR' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = gc_msgno_not_bai2
                                            msg = 'Message 150 expected for non-BAI2 content' ).
    ENDTRY.
  ENDMETHOD.


  METHOD finding_codes.
    rt_codes = VALUE #( FOR f IN it_findings ( |{ f-object_type }/{ f-rule_id }/{ f-check_code }/{ f-severity }| ) ).
  ENDMETHOD.

  " A86 BAI2 49: an empty account control total is TRAILER_FIELD_MISSING (S06, B), not the computed total
  METHOD trailer_49_total_missing.
    TRY.
        configure_scenario( VALUE #( account_trailer = `49,,5/` ) ).
        cl_abap_unit_assert=>assert_equals(
          act = finding_codes( parse( )-findings )
          exp = VALUE string_table( ( |STMT/S06/{ gc_check-trl_missing }/B| ) )
          msg = 'An empty 49 control total must be reported as missing, never self-satisfied' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " A86 BAI2 49: an empty number of records is TRAILER_FIELD_MISSING (S12, E), not the computed count
  METHOD trailer_49_count_missing.
    TRY.
        configure_scenario( VALUE #( account_trailer = `49,+604000000,/` ) ).
        cl_abap_unit_assert=>assert_equals(
          act = finding_codes( parse( )-findings )
          exp = VALUE string_table( ( |STMT/S12/{ gc_check-trl_missing }/E| ) )
          msg = 'An empty 49 record count must be reported as missing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " A86 BAI2 98: empty group total, number of accounts and number of records - one finding each
  METHOD trailer_98_fields_missing.
    TRY.
        configure_scenario( VALUE #( group_trailer = `98,,,/` ) ).
        cl_abap_unit_assert=>assert_equals(
          act = finding_codes( parse( )-findings )
          exp = VALUE string_table( ( |FILE/S06/{ gc_check-trl_missing }/B| )
                                    ( |FILE/S12/{ gc_check-trl_missing }/E| )
                                    ( |FILE/S12/{ gc_check-trl_missing }/E| ) )
          msg = 'Each empty 98 field must be reported as missing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " A86 BAI2 99: a trailer without total and counts (99/) - one finding each, file total stays undeclared
  METHOD trailer_99_fields_missing.
    TRY.
        configure_scenario( VALUE #( file_trailer = `99/` ) ).
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals(
          act = finding_codes( ls_file-findings )
          exp = VALUE string_table( ( |FILE/S06/{ gc_check-trl_missing }/B| )
                                    ( |FILE/S12/{ gc_check-trl_missing }/E| )
                                    ( |FILE/S12/{ gc_check-trl_missing }/E| ) )
          msg = 'Each missing 99 field must be reported as missing' ).
        cl_abap_unit_assert=>assert_initial( act = ls_file-control_total
                                             msg = 'A missing file total must not be filled with the computed total' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " A86: zero is a declaration, not an omission - a declared 0 is compared (mismatch), not 'missing'
  METHOD trailer_zero_is_declared.
    TRY.
        configure_scenario( VALUE #( account_trailer = `49,+604000000,0/` ) ).
        cl_abap_unit_assert=>assert_equals(
          act = finding_codes( parse( )-findings )
          exp = VALUE string_table( ( |STMT/S12/{ gc_check-record_count }/E| ) )
          msg = 'A declared zero count must be compared, not treated as missing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
