*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_types.intf.abap
*& Purpose:
*& One model for BAI2 and CAMT.053/054. Parsers (file, pre-import) and the
*& FEBKO/FEBEP reader (post-import) both produce these structures; every rule
*& works on them and never on a format-specific record.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | 275/575 not validated (business decision): R20 removed, sweep test.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - format-neutral statement model</p>
"! One model for BAI2 and CAMT.053/054. Parsers (file, pre-import) and the
"! FEBKO/FEBEP reader (post-import) both produce these structures; every rule
"! works on them and never on a format-specific record.
INTERFACE zif_cd_ebs_types
  PUBLIC.

  TYPES ty_format     TYPE c LENGTH 8.
  TYPES ty_scheme     TYPE c LENGTH 5.
  TYPES ty_btc_code   TYPE c LENGTH 35.
  TYPES ty_flow       TYPE c LENGTH 1.
  TYPES ty_cdi        TYPE c LENGTH 1.
  TYPES ty_category   TYPE c LENGTH 4.
  TYPES ty_rule_group TYPE c LENGTH 10.
  TYPES ty_stmt_key   TYPE c LENGTH 20.
  TYPES ty_bank_key   TYPE c LENGTH 15.
  TYPES ty_text35     TYPE c LENGTH 35.
  TYPES ty_kukey      TYPE n LENGTH 8.
  TYPES ty_esnum      TYPE n LENGTH 5.
  TYPES ty_bal_type   TYPE c LENGTH 4.
  TYPES ty_paymeth    TYPE c LENGTH 10.
  TYPES ty_source     TYPE c LENGTH 4.

  CONSTANTS:
    BEGIN OF gc_format,
      bai2    TYPE ty_format VALUE 'BAI2',
      camt053 TYPE ty_format VALUE 'CAMT053',
      camt054 TYPE ty_format VALUE 'CAMT054',
    END OF gc_format.

  "! Code scheme of a bank transaction code
  CONSTANTS:
    BEGIN OF gc_scheme,
      bai2  TYPE ty_scheme VALUE 'BAI2',
      iso   TYPE ty_scheme VALUE 'ISO',
      prtry TYPE ty_scheme VALUE 'PRTRY',
    END OF gc_scheme.

  CONSTANTS:
    BEGIN OF gc_cdi,
      credit TYPE ty_cdi VALUE 'C',
      debit  TYPE ty_cdi VALUE 'D',
      any    TYPE ty_cdi VALUE '*',
    END OF gc_cdi.

  CONSTANTS:
    BEGIN OF gc_flow,
      disbursement TYPE ty_flow VALUE 'D',
      collection   TYPE ty_flow VALUE 'C',
      unknown      TYPE ty_flow VALUE ' ',
      any          TYPE ty_flow VALUE '*',
    END OF gc_flow.

  CONSTANTS:
    BEGIN OF gc_source,
      feb  TYPE ty_source VALUE 'FEB',
      file TYPE ty_source VALUE 'FILE',
    END OF gc_source.

  "! Category used for unmapped codes (master prompt X01)
  CONSTANTS gc_category_unmapped TYPE ty_category VALUE 'X01'.

  "! Balance type codes (ISO 20022 names; BAI2 010 -> OPBD, 015 -> CLBD)
  CONSTANTS:
    BEGIN OF gc_balance,
      opening_booked TYPE ty_bal_type VALUE 'OPBD',
      closing_booked TYPE ty_bal_type VALUE 'CLBD',
      opening_avail  TYPE ty_bal_type VALUE 'OPAV',
      closing_avail  TYPE ty_bal_type VALUE 'CLAV',
      interim_booked TYPE ty_bal_type VALUE 'ITBD',
      prev_closing   TYPE ty_bal_type VALUE 'PRCD',
    END OF gc_balance.

  TYPES:
    BEGIN OF ty_balance,
      bal_type TYPE ty_bal_type,
      "! Signed: credit balance positive, debit balance negative
      amount   TYPE zif_cd_ops_types=>ty_amount,
      currency TYPE zif_cd_ops_types=>ty_currency,
      bal_date TYPE d,
    END OF ty_balance.
  TYPES tt_balance TYPE STANDARD TABLE OF ty_balance WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_statement,
      stmt_key       TYPE ty_stmt_key,
      format         TYPE ty_format,
      source         TYPE ty_source,
      "! FEBKO key (post-import source only)
      kukey          TYPE ty_kukey,
      bukrs          TYPE c LENGTH 4,
      hbkid          TYPE c LENGTH 5,
      hktid          TYPE c LENGTH 5,
      "! Bank identifier: BAI2 originator ID, CAMT servicer BIC/Id
      bank_id        TYPE ty_text35,
      "! Account: BAI2 customer account number, CAMT IBAN or Othr/Id
      account_no     TYPE ty_text35,
      currency       TYPE zif_cd_ops_types=>ty_currency,
      "! CAMT Stmt/Id or Ntfctn/Id; BAI2 file id + group
      stmt_id        TYPE ty_text35,
      "! Statement sequence: FEBKO-AZNUM, CAMT ElctrncSeqNb, BAI2 file id
      stmt_no        TYPE c LENGTH 10,
      legal_seq_no   TYPE c LENGTH 10,
      stmt_date      TYPE d,
      created_date   TYPE d,
      created_time   TYPE t,
      has_opening    TYPE abap_bool,
      opening_bal    TYPE zif_cd_ops_types=>ty_amount,
      has_closing    TYPE abap_bool,
      closing_bal    TYPE zif_cd_ops_types=>ty_amount,
      balances       TYPE tt_balance,
      "! Totals declared by the bank in the statement (BAI2 100/400, CAMT TxsSummry)
      has_totals     TYPE abap_bool,
      total_credits  TYPE zif_cd_ops_types=>ty_amount,
      total_debits   TYPE zif_cd_ops_types=>ty_amount,
      credit_count   TYPE i,
      debit_count    TYPE i,
      "! Declared number of entries; -1 = not declared
      declared_count TYPE i,
      "! Default flow of the account (from ZCD_EBS_ACCT), D or C
      flow_default   TYPE ty_flow,
      "! Engine-derived from ZCD_EBS_ACCT (bank-specific BTC map rows); parsers leave initial
      bank_key       TYPE ty_bank_key,
    END OF ty_statement.
  TYPES tt_statement TYPE STANDARD TABLE OF ty_statement WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_line,
      stmt_key      TYPE ty_stmt_key,
      line_no       TYPE i,
      kukey         TYPE ty_kukey,
      esnum         TYPE ty_esnum,
      "! Raw transaction code as delivered
      scheme        TYPE ty_scheme,
      "! BAI2: type code ('168'); ISO: 'DOMN-FMLY-SUBF' ('PMNT-ICDT-ESCT'); PRTRY: code
      btc_code      TYPE ty_btc_code,
      domain        TYPE c LENGTH 4,
      family        TYPE c LENGTH 4,
      subfamily     TYPE c LENGTH 4,
      prtry_code    TYPE ty_btc_code,
      prtry_issuer  TYPE ty_text35,
      "! C = credit, D = debit
      cdi           TYPE ty_cdi,
      "! Always positive; direction is in CDI
      amount        TYPE zif_cd_ops_types=>ty_amount,
      currency      TYPE zif_cd_ops_types=>ty_currency,
      reversal      TYPE abap_bool,
      booking_date  TYPE d,
      value_date    TYPE d,
      "! Primary payment reference (FEBEP-CHECT; CAMT EndToEndId/ChqNb; BAI2 bank/customer ref)
      reference     TYPE ty_text35,
      end_to_end_id TYPE ty_text35,
      instr_id      TYPE ty_text35,
      bank_ref      TYPE ty_text35,
      cust_ref      TYPE ty_text35,
      check_no      TYPE ty_text35,
      xblnr         TYPE c LENGTH 16,
      "! NACHA return reason (R01..R85) or NOC code (C01..C07)
      return_reason TYPE c LENGTH 4,
      addtl_info    TYPE c LENGTH 255,
      "! Posting result (post-import source only)
      belnr         TYPE c LENGTH 10,
      gjahr         TYPE n LENGTH 4,
      posting_rule  TYPE c LENGTH 4,
      "! Derived by the engine - parsers leave these initial
      flow_type     TYPE ty_flow,
      category      TYPE ty_category,
      rule_group    TYPE ty_rule_group,
      exp_cdi       TYPE ty_cdi,
      pay_method    TYPE ty_paymeth,
      map_posting   TYPE c LENGTH 4,
      blocked       TYPE abap_bool,
    END OF ty_line.
  TYPES tt_line TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

  "! Result of parsing one bank file
  TYPES:
    BEGIN OF ty_file,
      format        TYPE ty_format,
      file_name     TYPE string,
      file_id       TYPE ty_text35,
      sender_id     TYPE ty_text35,
      receiver_id   TYPE ty_text35,
      created_date  TYPE d,
      created_time  TYPE t,
      "! Physical records (BAI2) or entries (CAMT) read
      record_count  TYPE i,
      "! File control total declared by the bank (BAI2 99, CAMT GrpHdr/CtrlSum)
      control_total TYPE zif_cd_ops_types=>ty_amount,
      statements    TYPE tt_statement,
      lines         TYPE tt_line,
      "! Structural / control-total findings (S06, S11, S12, S00)
      findings      TYPE zif_cd_ops_types=>tt_finding,
    END OF ty_file.

  "! One unit of work handed from a source to the engine
  TYPES:
    BEGIN OF ty_package,
      statements TYPE tt_statement,
      lines      TYPE tt_line,
      findings   TYPE zif_cd_ops_types=>tt_finding,
    END OF ty_package.

  "! ---- Configuration (customizing) ----

  "! ZCD_BTC_MAP
  TYPES:
    BEGIN OF ty_btc_map,
      scheme      TYPE ty_scheme,
      btc_code    TYPE ty_btc_code,
      bank_key    TYPE ty_bank_key,
      flow_type   TYPE ty_flow,
      category    TYPE ty_category,
      rule_group  TYPE ty_rule_group,
      exp_cdi     TYPE ty_cdi,
      pay_method  TYPE ty_paymeth,
      posting_rule TYPE c LENGTH 4,
      ret_reason  TYPE c LENGTH 4,
      action      TYPE zif_cd_ops_types=>ty_action,
      active      TYPE abap_bool,
      description TYPE c LENGTH 60,
    END OF ty_btc_map.
  TYPES tt_btc_map TYPE STANDARD TABLE OF ty_btc_map WITH EMPTY KEY.

  "! ZCD_BTC_RULE joined with ZCD_EBS_RULE_DEF
  TYPES:
    BEGIN OF ty_rule_cfg,
      rule_group  TYPE ty_rule_group,
      rule_id     TYPE zif_cd_ops_types=>ty_rule_id,
      seq         TYPE i,
      level       TYPE c LENGTH 1,
      class_name  TYPE zif_cd_ops_types=>ty_class_name,
      severity    TYPE zif_cd_ops_types=>ty_severity,
      action      TYPE zif_cd_ops_types=>ty_action,
      param1      TYPE c LENGTH 40,
      param2      TYPE c LENGTH 40,
      param3      TYPE c LENGTH 40,
      tolerance   TYPE zif_cd_ops_types=>ty_amount,
      window_days TYPE i,
      active      TYPE abap_bool,
      description TYPE c LENGTH 60,
    END OF ty_rule_cfg.
  TYPES tt_rule_cfg TYPE STANDARD TABLE OF ty_rule_cfg WITH EMPTY KEY.

  "! Rule level: S = statement, L = line
  CONSTANTS:
    BEGIN OF gc_level,
      statement TYPE c LENGTH 1 VALUE 'S',
      line      TYPE c LENGTH 1 VALUE 'L',
    END OF gc_level.

  "! Rule group that applies to every statement / every mapped line
  CONSTANTS gc_rule_group_all TYPE ty_rule_group VALUE '*'.

  "! ZCD_EBS_ACCT - house bank account configuration
  TYPES:
    BEGIN OF ty_account_cfg,
      bukrs        TYPE c LENGTH 4,
      hbkid        TYPE c LENGTH 5,
      hktid        TYPE c LENGTH 5,
      account_no   TYPE ty_text35,
      bank_key     TYPE ty_bank_key,
      format       TYPE ty_format,
      flow_default TYPE ty_flow,
      currency     TYPE zif_cd_ops_types=>ty_currency,
      gl_account   TYPE c LENGTH 10,
      active       TYPE abap_bool,
    END OF ty_account_cfg.
  TYPES tt_account_cfg TYPE STANDARD TABLE OF ty_account_cfg WITH EMPTY KEY.

  "! ZCD_EBS_FLOW_PAT - flow derivation by XBLNR pattern (ported from ZB_BAI_GL_CONFIG)
  TYPES:
    BEGIN OF ty_flow_pattern,
      priority  TYPE i,
      pattern   TYPE c LENGTH 30,
      flow_type TYPE ty_flow,
    END OF ty_flow_pattern.
  TYPES tt_flow_pattern TYPE STANDARD TABLE OF ty_flow_pattern WITH EMPTY KEY.

  "! ZCD_EBS_RSN_MAP - NACHA return / NOC reason to payment engine return reason
  TYPES:
    BEGIN OF ty_reason_map,
      reason      TYPE c LENGTH 4,
      fica_reason TYPE c LENGTH 3,
      is_noc      TYPE abap_bool,
    END OF ty_reason_map.
  TYPES tt_reason_map TYPE SORTED TABLE OF ty_reason_map WITH UNIQUE KEY reason.

  "! Message numbers (class ZCD_OPS) of this area's user-facing texts
  CONSTANTS:
    BEGIN OF gc_msg,
      unmapped_btc                TYPE zif_cd_ops_types=>ty_msgno VALUE '100',
      map_action_block            TYPE zif_cd_ops_types=>ty_msgno VALUE '101',
      circuit_breaker             TYPE zif_cd_ops_types=>ty_msgno VALUE '102',
      validation_could_not_run    TYPE zif_cd_ops_types=>ty_msgno VALUE '103',
      rule_failed                 TYPE zif_cd_ops_types=>ty_msgno VALUE '104',
      file_is_empty_expected_bai2 TYPE zif_cd_ops_types=>ty_msgno VALUE '105',
      type_code_in_line_is        TYPE zif_cd_ops_types=>ty_msgno VALUE '106',
      type_code_in_line_is_2      TYPE zif_cd_ops_types=>ty_msgno VALUE '107',
      account_expected_account_tr TYPE zif_cd_ops_types=>ty_msgno VALUE '108',
      account_statement_without_d TYPE zif_cd_ops_types=>ty_msgno VALUE '109',
      file_expected_file_trailer  TYPE zif_cd_ops_types=>ty_msgno VALUE '110',
      file_expected_at_least_one  TYPE zif_cd_ops_types=>ty_msgno VALUE '111',
      expected_found_records      TYPE zif_cd_ops_types=>ty_msgno VALUE '112',
      expected_found              TYPE zif_cd_ops_types=>ty_msgno VALUE '113',
      line_expected_amount_of_dig TYPE zif_cd_ops_types=>ty_msgno VALUE '114',
      line_expected_date_yymmdd_f TYPE zif_cd_ops_types=>ty_msgno VALUE '115',
      line_expected_time_hhmm_fou TYPE zif_cd_ops_types=>ty_msgno VALUE '116',
      file_is_empty_expected_camt TYPE zif_cd_ops_types=>ty_msgno VALUE '117',
      file_expected_at_least_on_2 TYPE zif_cd_ops_types=>ty_msgno VALUE '118',
      statement_expected_entries  TYPE zif_cd_ops_types=>ty_msgno VALUE '119',
      expected_found_entries      TYPE zif_cd_ops_types=>ty_msgno VALUE '120',
      expected_found_entries_2    TYPE zif_cd_ops_types=>ty_msgno VALUE '121',
      element_expected_decimal_am TYPE zif_cd_ops_types=>ty_msgno VALUE '122',
      element_expected_date_yyyy  TYPE zif_cd_ops_types=>ty_msgno VALUE '123',
      sign_mismatch               TYPE zif_cd_ops_types=>ty_msgno VALUE '124',
      amount_below_min            TYPE zif_cd_ops_types=>ty_msgno VALUE '125',
      amount_above_max            TYPE zif_cd_ops_types=>ty_msgno VALUE '126',
      currency_mismatch           TYPE zif_cd_ops_types=>ty_msgno VALUE '127',
      ref_missing                 TYPE zif_cd_ops_types=>ty_msgno VALUE '128',
      ref_format                  TYPE zif_cd_ops_types=>ty_msgno VALUE '129',
      reason_missing              TYPE zif_cd_ops_types=>ty_msgno VALUE '130',
      reason_unmapped             TYPE zif_cd_ops_types=>ty_msgno VALUE '131',
      reason_invalid              TYPE zif_cd_ops_types=>ty_msgno VALUE '132',
      payment_not_found           TYPE zif_cd_ops_types=>ty_msgno VALUE '133',
      payment_status              TYPE zif_cd_ops_types=>ty_msgno VALUE '134',
      house_bank_ambiguous        TYPE zif_cd_ops_types=>ty_msgno VALUE '135',
      check_not_found             TYPE zif_cd_ops_types=>ty_msgno VALUE '136',
      check_status                TYPE zif_cd_ops_types=>ty_msgno VALUE '137',
      retrieval_not_found         TYPE zif_cd_ops_types=>ty_msgno VALUE '138',
      retrieval_status            TYPE zif_cd_ops_types=>ty_msgno VALUE '139',
      return_item_not_found       TYPE zif_cd_ops_types=>ty_msgno VALUE '140',
      return_lot_status           TYPE zif_cd_ops_types=>ty_msgno VALUE '141',
      check_amount_mismatch       TYPE zif_cd_ops_types=>ty_msgno VALUE '142',
      duplicate_entry             TYPE zif_cd_ops_types=>ty_msgno VALUE '143',
      value_date_window           TYPE zif_cd_ops_types=>ty_msgno VALUE '144',
      house_bank_ambiguous_2      TYPE zif_cd_ops_types=>ty_msgno VALUE '145',
      code_total_mismatch         TYPE zif_cd_ops_types=>ty_msgno VALUE '146',
      code_count_mismatch         TYPE zif_cd_ops_types=>ty_msgno VALUE '147',
      posting_rule_missing        TYPE zif_cd_ops_types=>ty_msgno VALUE '148',
      posting_rule_mismatch       TYPE zif_cd_ops_types=>ty_msgno VALUE '149',
      gl_account_not_mapped       TYPE zif_cd_ops_types=>ty_msgno VALUE '153',
      gl_ne_closing               TYPE zif_cd_ops_types=>ty_msgno VALUE '154',
      not_posted                  TYPE zif_cd_ops_types=>ty_msgno VALUE '155',
      fi_doc_not_found            TYPE zif_cd_ops_types=>ty_msgno VALUE '156',
      fi_doc_not_cleared          TYPE zif_cd_ops_types=>ty_msgno VALUE '157',
      opening_ne_prior_closing    TYPE zif_cd_ops_types=>ty_msgno VALUE '159',
      balance_arithmetic          TYPE zif_cd_ops_types=>ty_msgno VALUE '162',
      declared_totals             TYPE zif_cd_ops_types=>ty_msgno VALUE '163',
      stmt_no_gap                 TYPE zif_cd_ops_types=>ty_msgno VALUE '164',
      stmt_no_repeat              TYPE zif_cd_ops_types=>ty_msgno VALUE '165',
      account_not_configured      TYPE zif_cd_ops_types=>ty_msgno VALUE '166',
      account_currency            TYPE zif_cd_ops_types=>ty_msgno VALUE '167',
      stmt_date_future            TYPE zif_cd_ops_types=>ty_msgno VALUE '168',
      stmt_date_stale             TYPE zif_cd_ops_types=>ty_msgno VALUE '169',
      stmt_duplicate_in_file      TYPE zif_cd_ops_types=>ty_msgno VALUE '170',
      stmt_already_imported       TYPE zif_cd_ops_types=>ty_msgno VALUE '171',
      btc_coverage                TYPE zif_cd_ops_types=>ty_msgno VALUE '172',
      entries_not_accounted       TYPE zif_cd_ops_types=>ty_msgno VALUE '173',
      entry_count                 TYPE zif_cd_ops_types=>ty_msgno VALUE '174',
      run_counts_1                TYPE zif_cd_ops_types=>ty_msgno VALUE '175',
      run_counts_2                TYPE zif_cd_ops_types=>ty_msgno VALUE '176',
      unknown_record              TYPE zif_cd_ops_types=>ty_msgno VALUE '177',
      group_trailer_missing       TYPE zif_cd_ops_types=>ty_msgno VALUE '178',
      released_by                 TYPE zif_cd_ops_types=>ty_msgno VALUE '179',
    END OF gc_msg.

ENDINTERFACE.
