*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_parser_camt.clas.testclasses.abap
*& Purpose:
*& ABAP Unit tests for the camt.053/054 parser: statement, balances, entries,
*& TxDtls split, bank transaction codes, TxsSummry checks and exceptions.
*& Inputs are inline XML strings; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A92-A94: entry status in fixtures; batch reconciliation, status layouts, document gate, invalid amount / count.
*& 2026-11-06 | Modern-syntax sweep: string templates.
*&---------------------------------------------------------------------*
CLASS ltc_parser_camt DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    "! Scenario intent for the camt.053 base statement
    TYPES:
      BEGIN OF ty_flags,
        inconsistent_summary TYPE abap_bool,
        no_summary           TYPE abap_bool,
        prtry_reversal_entry TYPE abap_bool,
        batch_without_amount TYPE abap_bool,
        "! A92/A93: replaces the entries of the statement
        entries_xml          TYPE string,
      END OF ty_flags.

    CONSTANTS gc_file_name TYPE string VALUE `CAMT053_20261104.XML`.
    CONSTANTS gc_stmt_key TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'S0001'.
    CONSTANTS gc_usd TYPE zif_cd_ops_types=>ty_currency VALUE 'USD'.
    CONSTANTS gc_book_date TYPE d VALUE '20261103'.
    CONSTANTS gc_msgno_unreadable TYPE symsgno VALUE '151'.
    CONSTANTS gc_msgno_unsupported TYPE symsgno VALUE '152'.

    CONSTANTS:
      BEGIN OF gc_check,
        entry_count TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_ENTRY_COUNT',
        sum         TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_SUM_MISMATCH',
        dbt_sum     TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_DBT_SUM_MISMATCH',
        dbt_count   TYPE zif_cd_ops_types=>ty_check_code VALUE 'CAMT_DBT_ENTRY_COUNT',
        empty_file  TYPE zif_cd_ops_types=>ty_check_code VALUE 'EMPTY_FILE',
      END OF gc_check.

    DATA mv_content TYPE string.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS configure_return_notification.

    METHODS summary
      IMPORTING
        is_flags       TYPE ty_flags
      RETURNING
        VALUE(rv_xml) TYPE string.

    METHODS entries
      IMPORTING
        is_flags       TYPE ty_flags
      RETURNING
        VALUE(rv_xml) TYPE string.

    METHODS parse
      RETURNING
        VALUE(rs_file) TYPE zif_cd_ebs_types=>ty_file
      RAISING
        zcx_cd_ops_error.

    METHODS finding_keys
      IMPORTING
        it_findings    TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rt_keys) TYPE string_table.

    METHODS group_header_mapped FOR TESTING.
    METHODS stmt_header_mapped FOR TESTING.
    METHODS dbit_balance_is_negative FOR TESTING.
    METHODS entries_become_lines FOR TESTING.
    METHODS consistent_summary_no_finding FOR TESTING.
    METHODS summary_mismatch_s06_s12 FOR TESTING.
    METHODS no_summary_count_undeclared FOR TESTING.
    METHODS prtry_only_btc_scheme_prtry FOR TESTING.
    METHODS batch_no_tx_amount_one_line FOR TESTING.
    METHODS camt054_txdtls_split_lines FOR TESTING.
    METHODS camt054_counts_ntry_not_tx FOR TESTING.
    METHODS empty_content_is_s11 FOR TESTING.
    METHODS malformed_xml_raises FOR TESTING.
    METHODS unsupported_message_raises FOR TESTING.
    METHODS batch_details_mismatch FOR TESTING.
    METHODS batch_detail_currency_differs FOR TESTING.
    METHODS pending_v08_quarantined FOR TESTING.
    METHODS info_v02_quarantined FOR TESTING.
    METHODS booked_v02_layout_postable FOR TESTING.
    METHODS second_body_blocked FOR TESTING.
    METHODS wrong_namespace_blocked FOR TESTING.
    METHODS cross_format_child_blocked FOR TESTING.
    METHODS invalid_amount_blocks FOR TESTING.
    METHODS invalid_count_blocks FOR TESTING.

    "! Parse and require one finding with check code and severity
    METHODS assert_finding
      IMPORTING
        iv_check_code TYPE zif_cd_ops_types=>ty_check_code
        iv_severity   TYPE zif_cd_ops_types=>ty_severity
        iv_msg        TYPE string
      RETURNING
        VALUE(rs_file) TYPE zif_cd_ebs_types=>ty_file.

ENDCLASS.


CLASS ltc_parser_camt IMPLEMENTATION.

  METHOD configure_scenario.
    mv_content =
      |<?xml version="1.0" encoding="UTF-8"?>| &&
      |<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>| &&
      |<GrpHdr><MsgId>MSG-20261104-0001</MsgId><CreDtTm>2026-11-04T06:30:15</CreDtTm>| &&
      |<MsgRcpt><Nm>EXAMPLE LIFE INSURANCE CO</Nm><Id><OrgId><AnyBIC>EXLIUS33XXX</AnyBIC></OrgId></Id>| &&
      |</MsgRcpt></GrpHdr>| &&
      |<Stmt><Id>STMT-20261103-001</Id><ElctrncSeqNb>307</ElctrncSeqNb><LglSeqNb>41</LglSeqNb>| &&
      |<CreDtTm>2026-11-04T06:30:00</CreDtTm>| &&
      |<FrToDt><FrDtTm>2026-11-03T00:00:00</FrDtTm><ToDtTm>2026-11-03T23:59:59</ToDtTm></FrToDt>| &&
      |<Acct><Id><Othr><Id>000123456789</Id></Othr></Id><Ccy>USD</Ccy>| &&
      |<Svcr><FinInstnId><BICFI>EXMPUS33XXX</BICFI></FinInstnId></Svcr></Acct>| &&
      |<Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="USD">1000.00</Amt>| &&
      |<CdtDbtInd>DBIT</CdtDbtInd><Dt><Dt>2026-11-03</Dt></Dt></Bal>| &&
      |<Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="USD">250.00</Amt>| &&
      |<CdtDbtInd>CRDT</CdtDbtInd><Dt><Dt>2026-11-03</Dt></Dt></Bal>| &&
      summary( is_flags ) &&
      entries( is_flags ) &&
      |</Stmt></BkToCstmrStmt></Document>|.
  ENDMETHOD.

  METHOD summary.
    IF is_flags-no_summary = abap_true.
      RETURN.
    ENDIF.
    IF is_flags-inconsistent_summary = abap_true.
      rv_xml = |<TxsSummry><TtlNtries><NbOfNtries>3</NbOfNtries><Sum>1800.00</Sum></TtlNtries>| &&
               |<TtlCdtNtries><NbOfNtries>1</NbOfNtries><Sum>1500.00</Sum></TtlCdtNtries>| &&
               |<TtlDbtNtries><NbOfNtries>2</NbOfNtries><Sum>300.00</Sum></TtlDbtNtries></TxsSummry>|.
      RETURN.
    ENDIF.
    rv_xml = |<TxsSummry><TtlNtries><NbOfNtries>2</NbOfNtries><Sum>1750.00</Sum>| &&
             |<TtlNetNtry><Amt>1250.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></TtlNetNtry></TtlNtries>| &&
             |<TtlCdtNtries><NbOfNtries>1</NbOfNtries><Sum>1500.00</Sum></TtlCdtNtries>| &&
             |<TtlDbtNtries><NbOfNtries>1</NbOfNtries><Sum>250.00</Sum></TtlDbtNtries></TxsSummry>|.
  ENDMETHOD.

  METHOD entries.
    IF is_flags-entries_xml IS NOT INITIAL.
      rv_xml = is_flags-entries_xml.
      RETURN.
    ENDIF.
    IF is_flags-prtry_reversal_entry = abap_true.
      rv_xml = |<Ntry><Amt Ccy="USD">75.25</Amt><CdtDbtInd>DBIT</CdtDbtInd><RvslInd>true</RvslInd>| &&
               |<Sts><Cd>BOOK</Cd></Sts>| &&
               |<BookgDt><DtTm>2026-11-03T10:15:00</DtTm></BookgDt>| &&
               |<BkTxCd><Prtry><Cd>NTRF+166</Cd><Issr>BAI</Issr></Prtry></BkTxCd>| &&
               |<NtryDtls><TxDtls><Refs><EndToEndId>NOTPROVIDED</EndToEndId><InstrId>INS-9</InstrId>| &&
               |</Refs></TxDtls></NtryDtls><AddtlNtryInf>REVERSAL OF PREMIUM 1001</AddtlNtryInf></Ntry>|.
      RETURN.
    ENDIF.
    IF is_flags-batch_without_amount = abap_true.
      rv_xml = |<Ntry><Amt Ccy="USD">500.00</Amt><CdtDbtInd>CRDT</CdtDbtInd><Sts><Cd>BOOK</Cd></Sts>| &&
               |<BookgDt><Dt>2026-11-03</Dt></BookgDt><AcctSvcrRef>BNK-0009</AcctSvcrRef>| &&
               |<BkTxCd><Domn><Cd>PMNT</Cd><Fmly><Cd>RCDT</Cd><SubFmlyCd>BOOK</SubFmlyCd></Fmly></Domn></BkTxCd>| &&
               |<NtryDtls><TxDtls><Refs><EndToEndId>E2E-A</EndToEndId></Refs></TxDtls>| &&
               |<TxDtls><Refs><EndToEndId>E2E-B</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>|.
      RETURN.
    ENDIF.
    rv_xml = |<Ntry><NtryRef>1</NtryRef><Amt Ccy="USD">1500.00</Amt><CdtDbtInd>CRDT</CdtDbtInd>| &&
             |<Sts><Cd>BOOK</Cd></Sts><BookgDt><Dt>2026-11-03</Dt></BookgDt><ValDt><Dt>2026-11-04</Dt></ValDt>| &&
             |<AcctSvcrRef>BNK-0001</AcctSvcrRef>| &&
             |<BkTxCd><Domn><Cd>PMNT</Cd><Fmly><Cd>RCDT</Cd><SubFmlyCd>ESCT</SubFmlyCd></Fmly></Domn></BkTxCd>| &&
             |<NtryDtls><TxDtls><Refs><MsgId>PAYER-MSG-77</MsgId><EndToEndId>E2E-PREM-1001</EndToEndId></Refs>| &&
             |<Amt Ccy="USD">1500.00</Amt><AddtlTxInf>PREMIUM POLICY 1001</AddtlTxInf></TxDtls></NtryDtls></Ntry>| &&
             |<Ntry><Amt Ccy="USD">250.00</Amt><CdtDbtInd>DBIT</CdtDbtInd><Sts><Cd>BOOK</Cd></Sts>| &&
             |<BookgDt><Dt>2026-11-03</Dt></BookgDt><ValDt><Dt>2026-11-03</Dt></ValDt>| &&
             |<AcctSvcrRef>BNK-0002</AcctSvcrRef>| &&
             |<BkTxCd><Domn><Cd>PMNT</Cd><Fmly><Cd>ICHQ</Cd><SubFmlyCd>CCHQ</SubFmlyCd></Fmly></Domn></BkTxCd>| &&
             |<NtryDtls><TxDtls><Refs><EndToEndId>NOTPROVIDED</EndToEndId><ChqNb>10045</ChqNb></Refs>| &&
             |</TxDtls></NtryDtls></Ntry>|.
  ENDMETHOD.

  METHOD configure_return_notification.
    mv_content =
      |<?xml version="1.0" encoding="UTF-8"?>| &&
      |<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.054.001.02"><BkToCstmrDbtCdtNtfctn>| &&
      |<GrpHdr><MsgId>NTF-20261104-0007</MsgId><CreDtTm>2026-11-04T07:05:00+00:00</CreDtTm></GrpHdr>| &&
      |<Ntfctn><Id>NTF-0007-01</Id><CreDtTm>2026-11-04T07:05:00+00:00</CreDtTm>| &&
      |<Acct><Id><Othr><Id>000555000111</Id></Othr></Id><Ccy>USD</Ccy></Acct>| &&
      |<Ntry><Amt Ccy="USD">300.00</Amt><CdtDbtInd>CRDT</CdtDbtInd><Sts>BOOK</Sts>| &&
      |<BookgDt><Dt>2026-11-04</Dt></BookgDt><ValDt><Dt>2026-11-04</Dt></ValDt>| &&
      |<AcctSvcrRef>RTN-BATCH-77</AcctSvcrRef>| &&
      |<BkTxCd><Domn><Cd>PMNT</Cd><Fmly><Cd>ICDT</Cd><SubFmlyCd>RRTN</SubFmlyCd></Fmly></Domn></BkTxCd>| &&
      |<NtryDtls><TxDtls><Refs><EndToEndId>DISB-000001</EndToEndId></Refs>| &&
      |<AmtDtls><TxAmt><Amt Ccy="USD">100.00</Amt></TxAmt></AmtDtls>| &&
      |<RtrInf><Rsn><Cd>R01</Cd></Rsn></RtrInf></TxDtls>| &&
      |<TxDtls><Refs><InstrId>INS-000002</InstrId><EndToEndId>DISB-000002</EndToEndId></Refs>| &&
      |<AmtDtls><TxAmt><Amt Ccy="USD">200.00</Amt></TxAmt></AmtDtls>| &&
      |<RtrInf><Rsn><Cd>R03</Cd></Rsn></RtrInf></TxDtls></NtryDtls></Ntry>| &&
      |</Ntfctn></BkToCstmrDbtCdtNtfctn></Document>|.
  ENDMETHOD.

  METHOD parse.
    DATA(lo_cut) = NEW zcl_cd_ebs_parser_camt( ).
    rs_file = lo_cut->zif_cd_ebs_parser~parse( iv_content   = mv_content
                                               iv_file_name = gc_file_name ).
  ENDMETHOD.

  METHOD finding_keys.
    rt_keys = VALUE #( FOR f IN it_findings ( |{ f-object_key }/{ f-rule_id }/{ f-check_code }/{ f-severity }| ) ).
    SORT rt_keys.
  ENDMETHOD.

  " GrpHdr: MsgId -> file id, CreDtTm -> created date/time, MsgRcpt/Id preferred over Nm
  METHOD group_header_mapped.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_file) = parse( ).
        CLEAR: ls_file-statements, ls_file-lines, ls_file-findings.
        cl_abap_unit_assert=>assert_equals(
          act = ls_file
          exp = VALUE zif_cd_ebs_types=>ty_file( format       = zif_cd_ebs_types=>gc_format-camt053
                                                  file_name    = gc_file_name
                                                  file_id      = 'MSG-20261104-0001'
                                                  receiver_id  = 'EXLIUS33XXX'
                                                  created_date = '20261104'
                                                  created_time = '063015'
                                                  record_count = 2 )
          msg = 'Group header not mapped as expected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " Stmt: Id, ElctrncSeqNb, LglSeqNb, ToDtTm date, Acct Othr/Id, Ccy, Svcr BICFI, TxsSummry totals
  METHOD stmt_header_mapped.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_file) = parse( ).
        DATA(ls_stmt) = ls_file-statements[ 1 ].
        CLEAR ls_stmt-balances.
        cl_abap_unit_assert=>assert_equals(
          act = ls_stmt
          exp = VALUE zif_cd_ebs_types=>ty_statement( stmt_key       = gc_stmt_key
                                                       format         = zif_cd_ebs_types=>gc_format-camt053
                                                       source         = zif_cd_ebs_types=>gc_source-file
                                                       bank_id        = 'EXMPUS33XXX'
                                                       account_no     = '000123456789'
                                                       currency       = gc_usd
                                                       stmt_id        = 'STMT-20261103-001'
                                                       stmt_no        = '307'
                                                       legal_seq_no   = '41'
                                                       stmt_date      = gc_book_date
                                                       created_date   = '20261104'
                                                       created_time   = '063000'
                                                       has_opening    = abap_true
                                                       opening_bal    = '-1000.00'
                                                       has_closing    = abap_true
                                                       closing_bal    = '250.00'
                                                       has_totals     = abap_true
                                                       total_credits  = '1500.00'
                                                       total_debits   = '250.00'
                                                       credit_count   = 1
                                                       debit_count    = 1
                                                       declared_count = 2 )
          msg = 'Statement header not mapped as expected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " Bal: CdtDbtInd DBIT gives a negative signed balance; type from Tp/CdOrPrtry/Cd
  METHOD dbit_balance_is_negative.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_file-statements[ 1 ]-balances
          exp = VALUE zif_cd_ebs_types=>tt_balance(
                  currency = gc_usd bal_date = gc_book_date
                  ( bal_type = zif_cd_ebs_types=>gc_balance-opening_booked amount = '-1000.00' )
                  ( bal_type = zif_cd_ebs_types=>gc_balance-closing_booked amount = '250.00' ) )
          msg = 'Balances not mapped with sign' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " Ntry: ISO BkTxCd, CRDT/DBIT, refs; reference = ChqNb, else EndToEndId (NOTPROVIDED ignored)
  METHOD entries_become_lines.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_file) = parse( ).
        DATA(lt_exp) = VALUE zif_cd_ebs_types=>tt_line(
          stmt_key = gc_stmt_key scheme = zif_cd_ebs_types=>gc_scheme-iso domain = 'PMNT'
          currency = gc_usd booking_date = gc_book_date entry_status = 'BOOK'
          ( line_no = 1 btc_code = 'PMNT-RCDT-ESCT' family = 'RCDT' subfamily = 'ESCT'
            cdi = zif_cd_ebs_types=>gc_cdi-credit amount = '1500.00' value_date = '20261104'
            reference = 'E2E-PREM-1001' end_to_end_id = 'E2E-PREM-1001' bank_ref = 'BNK-0001'
            cust_ref = 'PAYER-MSG-77' addtl_info = 'PREMIUM POLICY 1001' )
          ( line_no = 2 btc_code = 'PMNT-ICHQ-CCHQ' family = 'ICHQ' subfamily = 'CCHQ'
            cdi = zif_cd_ebs_types=>gc_cdi-debit amount = '250.00' value_date = gc_book_date
            reference = '10045' check_no = '10045' bank_ref = 'BNK-0002' ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_file-lines
                                            exp = lt_exp
                                            msg = 'Entry lines not mapped as expected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " TxsSummry consistent with entries (count, abs sum, net, credit, debit): no findings
  METHOD consistent_summary_no_finding.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals( act = ls_file-findings
                                            exp = VALUE zif_cd_ops_types=>tt_finding( )
                                            msg = 'Consistent statement must not produce findings' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " TxsSummry inconsistent: sums are S06 severity B, counts are S12 severity E
  METHOD summary_mismatch_s06_s12.
    TRY.
        configure_scenario( VALUE #( inconsistent_summary = abap_true ) ).
        DATA(ls_file) = parse( ).
        DATA(lt_exp) = VALUE string_table(
          ( |{ gc_stmt_key }/S06/{ gc_check-dbt_sum }/B| )
          ( |{ gc_stmt_key }/S06/{ gc_check-sum }/B| )
          ( |{ gc_stmt_key }/S12/{ gc_check-dbt_count }/E| )
          ( |{ gc_stmt_key }/S12/{ gc_check-entry_count }/E| ) ).
        SORT lt_exp.
        cl_abap_unit_assert=>assert_equals( act = finding_keys( ls_file-findings )
                                            exp = lt_exp
                                            msg = 'Summary mismatches not reported as S06/B and S12/E' ).
        cl_abap_unit_assert=>assert_equals( act = ls_file-findings[ check_code = gc_check-sum ]-amount
                                            exp = CONV zif_cd_ops_types=>ty_amount( '-50.00' )
                                            msg = 'S06 amount must be found minus expected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " No TxsSummry: declared_count = -1, has_totals false, no findings
  METHOD no_summary_count_undeclared.
    TRY.
        configure_scenario( VALUE #( no_summary = abap_true ) ).
        DATA(ls_file) = parse( ).
        DATA(ls_stmt) = ls_file-statements[ 1 ].
        cl_abap_unit_assert=>assert_equals(
          act = VALUE zif_cd_ebs_types=>ty_statement( has_totals     = ls_stmt-has_totals
                                                       declared_count = ls_stmt-declared_count )
          exp = VALUE zif_cd_ebs_types=>ty_statement( has_totals     = abap_false
                                                       declared_count = -1 )
          msg = 'Undeclared totals must give has_totals false and declared_count -1' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_file-findings )
                                            exp = 0
                                            msg = 'Statement without TxsSummry must not produce findings' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " BkTxCd without Domn: scheme PRTRY, btc_code = Prtry/Cd; RvslInd true; InstrId when no EndToEndId
  METHOD prtry_only_btc_scheme_prtry.
    TRY.
        configure_scenario( VALUE #( no_summary = abap_true prtry_reversal_entry = abap_true ) ).
        DATA(ls_file) = parse( ).
        DATA(lt_exp) = VALUE zif_cd_ebs_types=>tt_line(
          ( stmt_key = gc_stmt_key line_no = 1 scheme = zif_cd_ebs_types=>gc_scheme-prtry
            btc_code = 'NTRF+166' prtry_code = 'NTRF+166' prtry_issuer = 'BAI'
            cdi = zif_cd_ebs_types=>gc_cdi-debit amount = '75.25' currency = gc_usd reversal = abap_true
            booking_date = gc_book_date reference = 'INS-9' instr_id = 'INS-9' entry_status = 'BOOK'
            addtl_info = 'REVERSAL OF PREMIUM 1001' ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_file-lines
                                            exp = lt_exp
                                            msg = 'Proprietary code / reversal entry not mapped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " A92: several TxDtls without per-transaction amount: one entry-level line (entry references,
  " never the first detail's) plus a CAMT_DETAIL_AMOUNT_MISSING exception
  METHOD batch_no_tx_amount_one_line.
    TRY.
        configure_scenario( VALUE #( no_summary = abap_true batch_without_amount = abap_true ) ).
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE string_table( FOR l IN ls_file-lines ( |{ l-line_no }/{ l-amount }/{ l-reference }| ) )
          exp = VALUE string_table( ( `1/500.00/BNK-0009` ) )
          msg = 'Batch entry without transaction amounts must stay one entry-level line' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_file-findings[ check_code = 'CAMT_DETAIL_AMOUNT_MISSING'
                                                        severity   = zif_cd_ops_types=>gc_severity-error ] ) )
          msg = 'A detail without amount must give a batch-level exception' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " camt.054: one line per TxDtls (AmtDtls/TxAmt/Amt fallback), RtrInf/Rsn/Cd -> return_reason
  METHOD camt054_txdtls_split_lines.
    TRY.
        configure_return_notification( ).
        DATA(ls_file) = parse( ).
        DATA(lt_exp) = VALUE zif_cd_ebs_types=>tt_line(
          stmt_key = gc_stmt_key scheme = zif_cd_ebs_types=>gc_scheme-iso btc_code = 'PMNT-ICDT-RRTN'
          domain = 'PMNT' family = 'ICDT' subfamily = 'RRTN' cdi = zif_cd_ebs_types=>gc_cdi-credit
          currency = gc_usd booking_date = '20261104' value_date = '20261104' bank_ref = 'RTN-BATCH-77'
          entry_status = 'BOOK'
          ( line_no = 1 amount = '100.00' reference = 'DISB-000001' end_to_end_id = 'DISB-000001'
            return_reason = 'R01' )
          ( line_no = 2 amount = '200.00' reference = 'DISB-000002' end_to_end_id = 'DISB-000002'
            instr_id = 'INS-000002' return_reason = 'R03' ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_file-lines
                                            exp = lt_exp
                                            msg = 'camt.054 return transactions not split into lines' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " camt.054: format CAMT054; record_count counts Ntry elements, not TxDtls
  METHOD camt054_counts_ntry_not_tx.
    TRY.
        configure_return_notification( ).
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals(
          act = |{ ls_file-format }/{ ls_file-record_count }/{ lines( ls_file-statements ) }/{ lines( ls_file-findings ) }|
          exp = |{ zif_cd_ebs_types=>gc_format-camt054 }/1/1/0|
          msg = 'camt.054 must count one entry, one statement, no findings' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " S11: empty content is not an exception but an EMPTY_FILE finding with severity B
  METHOD empty_content_is_s11.
    TRY.
        mv_content = | \n |.
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE string_table( FOR f IN ls_file-findings ( |{ f-rule_id }/{ f-check_code }/{ f-severity }| ) )
          exp = VALUE string_table( ( |S11/{ gc_check-empty_file }/B| ) )
          msg = 'Empty content must give one S11 EMPTY_FILE finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " Unreadable input: XML that is not well-formed raises ZCX_CD_OPS_ERROR (151)
  METHOD malformed_xml_raises.
    mv_content = `<Document><BkToCstmrStmt><GrpHdr></BkToCstmrStmt></Document>`.
    TRY.
        parse( ).
        cl_abap_unit_assert=>fail( msg = 'Malformed XML must raise ZCX_CD_OPS_ERROR' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = gc_msgno_unreadable
                                            msg = 'Message 151 expected for malformed XML' ).
    ENDTRY.
  ENDMETHOD.

  " Unsupported message: a Document that is not camt.053/054 (here pain.001) raises (152)
  METHOD unsupported_message_raises.
    mv_content = |<?xml version="1.0"?><Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03">| &&
                 |<CstmrCdtTrfInitn><GrpHdr><MsgId>X</MsgId></GrpHdr></CstmrCdtTrfInitn></Document>|.
    TRY.
        parse( ).
        cl_abap_unit_assert=>fail( msg = 'pain.001 content must raise ZCX_CD_OPS_ERROR' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = gc_msgno_unsupported
                                            msg = 'Message 152 expected for unsupported message type' ).
    ENDTRY.
  ENDMETHOD.


  METHOD assert_finding.
    TRY.
        rs_file = parse( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( rs_file-findings[ check_code = iv_check_code severity = iv_severity ] ) )
          msg = iv_msg ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " A92: details 100.00 + 150.00 against an entry of 500.00 - no detail lines, one blocked entry line
  METHOD batch_details_mismatch.
    configure_scenario( VALUE #( no_summary = abap_true entries_xml =
      `<Ntry><Amt Ccy="USD">500.00</Amt><CdtDbtInd>CRDT</CdtDbtInd><Sts><Cd>BOOK</Cd></Sts>` &&
      `<BookgDt><Dt>2026-11-03</Dt></BookgDt><AcctSvcrRef>BNK-0010</AcctSvcrRef>` &&
      `<NtryDtls><TxDtls><Refs><EndToEndId>E2E-A</EndToEndId></Refs><Amt Ccy="USD">100.00</Amt></TxDtls>` &&
      `<TxDtls><Refs><EndToEndId>E2E-B</EndToEndId></Refs><Amt Ccy="USD">150.00</Amt></TxDtls></NtryDtls></Ntry>` ) ).
    DATA(ls_file) = assert_finding( iv_check_code = 'CAMT_BATCH_MISMATCH'
                                    iv_severity   = zif_cd_ops_types=>gc_severity-block
                                    iv_msg        = 'Details that do not add up to the entry must block' ).
    cl_abap_unit_assert=>assert_equals(
      act = VALUE string_table( FOR l IN ls_file-lines ( |{ l-amount }/{ l-reference }| ) )
      exp = VALUE string_table( ( `500.00/BNK-0010` ) )
      msg = 'Only one entry-level line may be emitted for an unreconciled batch' ).
  ENDMETHOD.

  " A92: a detail in another currency than its entry does not reconcile
  METHOD batch_detail_currency_differs.
    configure_scenario( VALUE #( no_summary = abap_true entries_xml =
      `<Ntry><Amt Ccy="USD">300.00</Amt><CdtDbtInd>CRDT</CdtDbtInd><Sts><Cd>BOOK</Cd></Sts>` &&
      `<BookgDt><Dt>2026-11-03</Dt></BookgDt><AcctSvcrRef>BNK-0011</AcctSvcrRef>` &&
      `<NtryDtls><TxDtls><Amt Ccy="USD">100.00</Amt></TxDtls>` &&
      `<TxDtls><Amt Ccy="EUR">200.00</Amt></TxDtls></NtryDtls></Ntry>` ) ).
    assert_finding( iv_check_code = 'CAMT_BATCH_MISMATCH'
                    iv_severity   = zif_cd_ops_types=>gc_severity-block
                    iv_msg        = 'A detail currency other than the entry currency must block' ).
  ENDMETHOD.

  " A93: v08 layout Sts/Cd = PDNG - quarantined as a finding, no line, not counted as booked
  METHOD pending_v08_quarantined.
    configure_scenario( VALUE #( no_summary = abap_true entries_xml =
      `<Ntry><Amt Ccy="USD">80.00</Amt><CdtDbtInd>CRDT</CdtDbtInd><Sts><Cd>PDNG</Cd></Sts>` &&
      `<BookgDt><Dt>2026-11-03</Dt></BookgDt><AcctSvcrRef>BNK-0012</AcctSvcrRef></Ntry>` ) ).
    DATA(ls_file) = assert_finding( iv_check_code = 'ENTRY_NOT_BOOKED'
                                    iv_severity   = zif_cd_ops_types=>gc_severity-warning
                                    iv_msg        = 'A pending entry must be quarantined as a finding' ).
    cl_abap_unit_assert=>assert_initial( act = ls_file-lines msg = 'A pending entry must not become a line' ).
  ENDMETHOD.

  " A93: v02 layout Sts = INFO - quarantined as well
  METHOD info_v02_quarantined.
    configure_scenario( VALUE #( no_summary = abap_true entries_xml =
      `<Ntry><Amt Ccy="USD">80.00</Amt><CdtDbtInd>DBIT</CdtDbtInd><Sts>INFO</Sts>` &&
      `<BookgDt><Dt>2026-11-03</Dt></BookgDt><AcctSvcrRef>BNK-0013</AcctSvcrRef></Ntry>` ) ).
    DATA(ls_file) = assert_finding( iv_check_code = 'ENTRY_NOT_BOOKED'
                                    iv_severity   = zif_cd_ops_types=>gc_severity-warning
                                    iv_msg        = 'An information entry must be quarantined as a finding' ).
    cl_abap_unit_assert=>assert_initial( act = ls_file-lines msg = 'An information entry must not become a line' ).
  ENDMETHOD.

  " A93: v02 layout Sts = BOOK is postable and carries its status into the line
  METHOD booked_v02_layout_postable.
    TRY.
        configure_scenario( VALUE #( no_summary = abap_true entries_xml =
          `<Ntry><Amt Ccy="USD">80.00</Amt><CdtDbtInd>CRDT</CdtDbtInd><Sts>BOOK</Sts>` &&
          `<BookgDt><Dt>2026-11-03</Dt></BookgDt><AcctSvcrRef>BNK-0014</AcctSvcrRef></Ntry>` ) ).
        DATA(ls_file) = parse( ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( ls_file-lines[ 1 ]-entry_status OPTIONAL ) exp = 'BOOK'
                                            msg = 'A booked entry must become a line with status BOOK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " A94: a document with a second message body is not accepted (blocking CAMT_DOCUMENT)
  METHOD second_body_blocked.
    mv_content = |<?xml version="1.0"?><Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">| &&
                 |<BkToCstmrStmt><GrpHdr><MsgId>A</MsgId></GrpHdr></BkToCstmrStmt>| &&
                 |<BkToCstmrStmt><GrpHdr><MsgId>B</MsgId></GrpHdr></BkToCstmrStmt></Document>|.
    assert_finding( iv_check_code = 'CAMT_DOCUMENT'
                    iv_severity   = zif_cd_ops_types=>gc_severity-block
                    iv_msg        = 'A second message body must block' ).
  ENDMETHOD.

  " A94: a namespace / version outside the approved list is not accepted
  METHOD wrong_namespace_blocked.
    configure_scenario( VALUE #( ) ).
    REPLACE FIRST OCCURRENCE OF `camt.053.001.08` IN mv_content WITH `camt.053.001.99`.
    assert_finding( iv_check_code = 'CAMT_DOCUMENT'
                    iv_severity   = zif_cd_ops_types=>gc_severity-block
                    iv_msg        = 'An unapproved namespace version must block' ).
  ENDMETHOD.

  " A94: a camt.054 Ntfctn inside a camt.053 message is not read as a statement
  METHOD cross_format_child_blocked.
    mv_content = |<?xml version="1.0"?><Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">| &&
                 |<BkToCstmrStmt><GrpHdr><MsgId>A</MsgId></GrpHdr>| &&
                 |<Ntfctn><Id>N1</Id></Ntfctn></BkToCstmrStmt></Document>|.
    DATA(ls_file) = assert_finding( iv_check_code = 'CAMT_DOCUMENT'
                                    iv_severity   = zif_cd_ops_types=>gc_severity-block
                                    iv_msg        = 'A statement element of another message type must block' ).
    cl_abap_unit_assert=>assert_initial( act = ls_file-statements msg = 'The foreign element must not become a statement' ).
  ENDMETHOD.

  " A94: an amount that is not a decimal blocks (no silent zero)
  METHOD invalid_amount_blocks.
    configure_scenario( VALUE #( no_summary = abap_true entries_xml =
      `<Ntry><Amt Ccy="USD">12,50</Amt><CdtDbtInd>CRDT</CdtDbtInd><Sts><Cd>BOOK</Cd></Sts>` &&
      `<BookgDt><Dt>2026-11-03</Dt></BookgDt></Ntry>` ) ).
    assert_finding( iv_check_code = 'INVALID_AMOUNT'
                    iv_severity   = zif_cd_ops_types=>gc_severity-block
                    iv_msg        = 'An invalid amount must block' ).
  ENDMETHOD.

  " A94: a count that is not a number blocks (no silent zero)
  METHOD invalid_count_blocks.
    configure_scenario( VALUE #( ) ).
    REPLACE FIRST OCCURRENCE OF `<NbOfNtries>2</NbOfNtries>` IN mv_content WITH `<NbOfNtries>two</NbOfNtries>`.
    assert_finding( iv_check_code = 'INVALID_COUNT'
                    iv_severity   = zif_cd_ops_types=>gc_severity-block
                    iv_msg        = 'An invalid count must block' ).
  ENDMETHOD.

ENDCLASS.
