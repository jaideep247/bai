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
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Generic lookup rule R21 (ZCD_EBS_LOOKUP) - new validations by configuration.
*& 2026-11-06 | Audit A27 blocks-posting flag and A03 required rules (RULE_GROUP_EMPTY, RULE_UNUSABLE, NONE row).
*& 2026-11-06 | Audit A25 / A33: canonical account key, missing-currency check codes.
*& 2026-11-06 | Audit A14: R22 duplicate history (check code, message, look-back parameter).
*& 2026-11-06 | Audit A26 / A32 / A34 / A35: disposition, statement key, sign and gross-total check codes.
*& 2026-11-06 | Audit A28: reason mapping completeness and kind, FEBEP reason field.
*& 2026-11-06 | Audit A86: message TRAILER_FIELD_MISSING.
*& 2026-11-06 | Audit A65: key width check codes, messages and EBS_KEYLEN_DOCNO constant.
*& 2026-11-06 | Audit A66/A68: NO_DATA check code, EBS_EMPTY_FEED_OK, messages 527-529.
*& 2026-11-06 | Audit A69: messages for server file encoding and read errors.
*& 2026-11-06 | Audit A85: map action carried on the line.
*& 2026-11-06 | FS-CD review: in-flight grace (EBS_INFLIGHT_HOURS, AWAITING_LOT_TRANSFER).
*& 2026-11-06 | Audit A62: plug-in interface names for the factory RTTI check.
*& 2026-11-06 | Audit A98: MAP_CONFLICT check code and message.
*& 2026-11-06 | Audit A96: message FUNDS_LAYOUT.
*& 2026-11-06 | Audit A92-A94: CAMT entry status on the line; messages 536-540.
*& 2026-11-06 | Operating model (post-posting): line posting state, rule flag NEEDS_POSTING,
*&            | EBS_FEB_POSTED_FIELDS, check code POSTING_INCOMPLETE, messages 541-542.
*& 2026-11-06 | Return / NOC reason correction: EBS_FEB_REASON_FIELD removed (FEBEP has no reason);
*&            | check code REASON_AMBIGUOUS, messages 543-545 (lot reasons DFKKRP-RLGRD / DFKKNRP-FLGRD).
*& 2026-11-06 | Payment engine account scope (user decision): XBLNR / account types, derivation
*&            | constants GC_PE_ACCOUNT (same literals as CDS ZI_CD_EbsLineAcct), message 546.
*& 2026-11-07 | Dashboard date window GC_DASHBOARD-WINDOW_DAYS (single source, cds_abap_parity).
*& 2026-11-07 | Parameter names / defaults moved from code: EBS_CB_*, EBS_RESULT_MAX, EBS_CAMT_BAI_FALLBACK,
*&            | EBS_GL_LEDGER, EBS_RTRV_STATUS_FIELD default, parser classes, prefix EBS_PARSER_.
*& 2026-11-07 | GC_FINDING_CLASS (ZCD_EBS_RULE_DEF-FINDING_CLASS: DUPLICATE, POSTING).
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
  "! Reference document number of a statement line (FEBEP-XBLNR)
  TYPES ty_xblnr      TYPE c LENGTH 16.
  "! Payment engine bank account as derived from FEBEP-XBLNR (ZCL_CD_EBS_PE_SCOPE)
  TYPES ty_pe_account TYPE c LENGTH 10.

  "! User decision 2026-11-06: FEBEP-XBLNR = bank text (letters, e.g. JPMC, BOA, PNC) + payment
  "! engine bank account (10 characters) + counter, e.g. JPMC8XX1174412334 -> 8XX1174412.
  "! The CDS view ZI_CD_EbsLineAcct derives the same account with the same pattern and length
  "! as literals - a change here is a change there (docs/EBS_VALIDATION.md, section A0a)
  CONSTANTS:
    BEGIN OF gc_pe_account,
      "! Leading bank text removed from XBLNR (PCRE)
      bank_text_pcre TYPE string VALUE `^[A-Za-z]+`,
      "! Characters of the account after the bank text
      length         TYPE i VALUE 10,
    END OF gc_pe_account.

  "! EBS dashboard (CDS, docs/Dashboard_EBS_Validation.md): statements, lines, runs and findings
  "! of the last WINDOW_DAYS days (dats_add_days -31 in ZI_CD_EbsStmtBase, ZI_CD_EbsLineAcct,
  "! ZI_CD_EbsRunBase, ZI_CD_EbsFinding). CDS cannot read these constants: the literals there are
  "! compared with them by the portable check cds_abap_parity (tools/cds_abap_parity.py)
  CONSTANTS:
    BEGIN OF gc_dashboard,
      window_days TYPE i VALUE 31,
    END OF gc_dashboard.

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

  "! Category used for unmapped codes (requirements baseline X01)
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
      xblnr         TYPE ty_xblnr,
      "! NACHA return reason (R01..R85) or NOC code (C01..C07) from a bank file (parsers);
      "! blank from the FEB source - FEBEP carries no reason (R05 reads DFKKRP / DFKKNRP)
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
      "! A26: the map row expects the entry not to be posted (disposition NOT_POSTED)
      not_posted    TYPE abap_bool,
      "! A85: action of the map row (AUTO_POST / EXCEPTION / ON_ACCOUNT / BLOCK)
      map_action    TYPE zif_cd_ops_types=>ty_action,
      "! A93: CAMT entry status (Ntry/Sts or Ntry/Sts/Cd); only BOOK entries become lines
      entry_status  TYPE c LENGTH 4,
      "! Operating model 2026-11-06: posting state of an imported entry from the FEBEP
      "! posting-area flags (EBS_FEB_POSTED_FIELDS) - blank = unknown (bank file), P / O
      posting_state TYPE c LENGTH 1,
      "! Derived by the engine: state O, not NOT_POSTED and not blocked - the entry is
      "! expected to post but is not posted; its posting-dependent rules are not evaluated
      posting_open  TYPE abap_bool,
    END OF ty_line.
  "! Posting state of an imported entry (ty_line-posting_state)
  CONSTANTS:
    BEGIN OF gc_posting_state,
      unknown TYPE c LENGTH 1 VALUE ' ',
      posted  TYPE c LENGTH 1 VALUE 'P',
      open    TYPE c LENGTH 1 VALUE 'O',
    END OF gc_posting_state.

  "! A35: secondary key STMT - statement rules read their statement's lines by key
  TYPES tt_line TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY
                WITH NON-UNIQUE SORTED KEY stmt COMPONENTS stmt_key.

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
      "! A26: expected disposition - blank = posted as usual, NOT_POSTED = never posted
      disposition TYPE c LENGTH 10,
    END OF ty_btc_map.

  "! Expected disposition of a bank transaction code (ZCD_BTC_MAP-DISPOSITION)
  CONSTANTS:
    BEGIN OF gc_disposition,
      not_posted TYPE c LENGTH 10 VALUE 'NOT_POSTED',
    END OF gc_disposition.
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
      "! Findings of this assignment block posting in enforce mode (A27): rule default
      "! (ZCD_EBS_RULE_DEF-BLOCKS_POSTING) unless ZCD_BTC_RULE-BLOCKS_POSTING overrides
      blocks_posting TYPE abap_bool,
      "! Operating model 2026-11-06 (ZCD_EBS_RULE_DEF-NEEDS_POSTING): the rule reads SAP
      "! evidence of the posting or clearing - not evaluated for an entry expected to post
      "! but not posted (line rules) or for a statement holding such an entry (statement rules)
      needs_posting  TYPE abap_bool,
      "! Assignment is active but its rule definition is missing or inactive (A03)
      unusable    TYPE abap_bool,
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

  "! Rule ID of an assignment row that declares a rule group as intentionally without
  "! code-specific rules (A03: every other mapped group needs a usable rule)
  CONSTANTS gc_rule_none TYPE zif_cd_ops_types=>ty_rule_id VALUE 'NONE'.

  "! ZCD_BTC_RULE-BLOCKS_POSTING: Y = blocks, N = does not block, blank = rule default
  CONSTANTS:
    BEGIN OF gc_blocks_override,
      yes TYPE c LENGTH 1 VALUE 'Y',
      no  TYPE c LENGTH 1 VALUE 'N',
    END OF gc_blocks_override.

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

  "! ZCD_EBS_FLOW_PAT - flow derivation by XBLNR pattern (ported from ZB_BAI_GL_CONFIG);
  "! PATTERN is PCRE matched to the complete XBLNR, case ignored (ZCL_CD_OPS_UTIL=>PCRE_MATCH)
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

  "! Generic lookup of rule R21 (ZCD_EBS_LOOKUP): a new validation is configuration, not code
  TYPES:
    BEGIN OF ty_lookup_cfg,
      lookup_id      TYPE c LENGTH 10,
      table_name     TYPE c LENGTH 30,
      key_field      TYPE c LENGTH 30,
      "! DOCNO (payment document, padded), ZTNUM (check number), REFERENCE (as delivered)
      key_kind       TYPE c LENGTH 10,
      "! 0 = as delivered; > 0 = right-aligned with leading zeros to this length (REFERENCE)
      key_length     TYPE i,
      "! blank = the key must exist; otherwise one row needs an allowed status
      status_field   TYPE c LENGTH 30,
      allowed_values TYPE c LENGTH 255,
      not_found_code TYPE zif_cd_ops_types=>ty_check_code,
      status_code    TYPE zif_cd_ops_types=>ty_check_code,
      active         TYPE abap_bool,
    END OF ty_lookup_cfg.
  TYPES tt_lookup_cfg TYPE SORTED TABLE OF ty_lookup_cfg WITH UNIQUE KEY lookup_id.

  "! Key kinds of a lookup (ZCD_EBS_LOOKUP-KEY_KIND)
  CONSTANTS:
    BEGIN OF gc_lookup_key,
      docno     TYPE c LENGTH 10 VALUE 'DOCNO',
      ztnum     TYPE c LENGTH 10 VALUE 'ZTNUM',
      reference TYPE c LENGTH 10 VALUE 'REFERENCE',
    END OF gc_lookup_key.
  "! A62: interfaces the core factory checks by RTTI before it creates an EBS plug-in
  CONSTANTS:
    BEGIN OF gc_plugin_interface,
      rule   TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZIF_CD_EBS_RULE',
      parser TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZIF_CD_EBS_PARSER',
    END OF gc_plugin_interface.

  "! Customizing table of rule R21 (named in configuration messages)
  CONSTANTS gc_lookup_table TYPE c LENGTH 30 VALUE 'ZCD_EBS_LOOKUP'.

  "! ZCD_EBS_RULE_DEF-FINDING_CLASS: how the dashboard counts a rule's findings (ZI_CD_EbsFinding
  "! IsDuplicate / IsPostingIncomplete; literals there compared by the portable check cds_abap_parity)
  TYPES ty_finding_class TYPE c LENGTH 10.
  CONSTANTS:
    BEGIN OF gc_finding_class,
      duplicate TYPE ty_finding_class VALUE 'DUPLICATE',
      posting   TYPE ty_finding_class VALUE 'POSTING',
    END OF gc_finding_class.

  "! Parameters (ZCD_OPS_PARAM) read by EBS and their delivered defaults
  CONSTANTS:
    BEGIN OF gc_param,
      feb_debit_ind     TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_FEB_DEBIT_IND',
      feb_credit_ind    TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_FEB_CREDIT_IND',
      rtrv_status_field TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_RTRV_STATUS_FIELD',
      "! A07: DFKKCR field holding the company code (blank = not used; VERIFY-DDIC)
      dfkkcr_bukrs_field TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_DFKKCR_BUKRS_FIELD',
      "! Leading zeros of check numbers are not significant (X, default) or are (any other
      "! non-blank value, e.g. N - a blank value is the default X)
      ztnum_ignore_zeros TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_ZTNUM_IGNORE_ZEROS',
      keylen_ztnum       TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_KEYLEN_ZTNUM',
      "! A65: length of document-number keys; must not exceed the DDIC key width (12)
      keylen_docno       TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_KEYLEN_DOCNO',
      "! A14: look-back days of R22 when the rule row has no WINDOW_DAYS
      dup_lookback_days  TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_DUP_LOOKBACK_DAYS',
      "! A68: X = a run without statements is an intentionally empty feed (closes green)
      empty_feed_ok      TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_EMPTY_FEED_OK',
      "! FS-CD review: in-flight grace in hours (0 = off) for not-found payment/lot lookups
      inflight_hours     TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_INFLIGHT_HOURS',
      "! Operating model 2026-11-06: FEBEP posting-area completion fields (comma list); an
      "! entry is posted when every field holds X; NONE = posting state not read (unknown)
      feb_posted_fields  TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_FEB_POSTED_FIELDS',
      "! Circuit breaker: failed-line percentage, consecutive packages, minimum lines per package
      cb_fail_pct        TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_CB_FAIL_PCT',
      cb_packages        TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_CB_PACKAGES',
      cb_min_lines       TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_CB_MIN_LINES',
      "! Findings kept per run (the rest summarised)
      result_max         TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_RESULT_MAX',
      "! X: CAMT proprietary BAI codes reuse the BAI2 map rows (off: any other non-blank value)
      camt_bai_fallback  TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_CAMT_BAI_FALLBACK',
      "! Ledger of the G/L line reads (BSEG / ACDOCA)
      gl_ledger          TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_GL_LEDGER',
    END OF gc_param,
    BEGIN OF gc_param_default,
      feb_debit_ind  TYPE string VALUE `S`,
      feb_credit_ind TYPE string VALUE `H`,
      "! VERIFY-SE11: FEBEP-VB1OK / VB2OK (posting area 1 / 2 completed)
      feb_posted_fields TYPE string VALUE `VB1OK,VB2OK`,
      "! EBS_FEB_POSTED_FIELDS value that switches the posting-state read off
      feb_posted_off    TYPE string VALUE `NONE`,
      cb_fail_pct       TYPE i VALUE 50,
      cb_packages       TYPE i VALUE 3,
      cb_min_lines      TYPE i VALUE 20,
      result_max        TYPE i VALUE 100000,
      camt_bai_fallback TYPE string VALUE `X`,
      gl_ledger         TYPE string VALUE `0L`,
      "! VERIFY-DDIC: status field of ZCD_ACH_RTRV_LOG (v4 168; v4 468 uses ZZRETRIEVAL_STATUS)
      rtrv_status_field TYPE string VALUE `ZZ_RTRV_STATUS`,
      parser_bai2       TYPE string VALUE `ZCL_CD_EBS_PARSER_BAI2`,
      parser_camt       TYPE string VALUE `ZCL_CD_EBS_PARSER_CAMT`,
    END OF gc_param_default.

  "! Parameter-name prefixes completed at run time: EBS_PARSER_<format> = parser class
  CONSTANTS:
    BEGIN OF gc_param_prefix,
      parser TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_PARSER_',
    END OF gc_param_prefix.

  "! Keywords of rule parameters in ZCD_BTC_RULE (PARAM1..PARAM3)
  CONSTANTS:
    BEGIN OF gc_rule_keyword,
      alnum    TYPE string VALUE `ALNUM`,
      required TYPE string VALUE `REQUIRED`,
      optional TYPE string VALUE `OPTIONAL`,
      "! R07L PARAM3: a retrieval passing on PARAM1 also needs a returns-lot entry (A11)
      lot      TYPE string VALUE `LOT`,
      "! R05 PARAM2: the entry is a return (NACHA R codes) or a notification of change (C codes)
      return   TYPE string VALUE `RETURN`,
      noc      TYPE string VALUE `NOC`,
    END OF gc_rule_keyword.

  "! First character of a seeded placeholder in configuration (e.g. <payment engine reason>)
  CONSTANTS gc_placeholder_prefix TYPE c LENGTH 1 VALUE '<'.

  "! Characters of a numeric code (BAI2 type codes are three digits)
  CONSTANTS gc_digits TYPE c LENGTH 10 VALUE '0123456789'.

  "! Engine findings that are not about a rule: object key and pseudo rule ID
  CONSTANTS:
    BEGIN OF gc_engine,
      rule_id TYPE zif_cd_ops_types=>ty_rule_id VALUE 'ENG',
    END OF gc_engine.

  "! Statement keys of imported statements: FEB<KUKEY>
  CONSTANTS gc_feb_stmt_prefix TYPE c LENGTH 3 VALUE 'FEB'.
  "! Statement keys of a parsed file (not yet imported): S0001, S0002, ...
  CONSTANTS gc_file_stmt_prefix TYPE c LENGTH 1 VALUE 'S'.

  "! Check codes of the EBS rules (finding CHECK_CODE)
  CONSTANTS:
    BEGIN OF gc_check_code,
      lookup_not_found               TYPE zif_cd_ops_types=>ty_check_code VALUE 'LOOKUP_NOT_FOUND',
      lookup_status                  TYPE zif_cd_ops_types=>ty_check_code VALUE 'LOOKUP_STATUS',
      account_currency               TYPE zif_cd_ops_types=>ty_check_code VALUE 'ACCOUNT_CURRENCY',
      account_currency_missing       TYPE zif_cd_ops_types=>ty_check_code VALUE 'ACCOUNT_CURRENCY_MISSING',
      account_not_configured         TYPE zif_cd_ops_types=>ty_check_code VALUE 'ACCOUNT_NOT_CONFIGURED',
      amount_above_max               TYPE zif_cd_ops_types=>ty_check_code VALUE 'AMOUNT_ABOVE_MAX',
      amount_below_min               TYPE zif_cd_ops_types=>ty_check_code VALUE 'AMOUNT_BELOW_MIN',
      balance_arithmetic             TYPE zif_cd_ops_types=>ty_check_code VALUE 'BALANCE_ARITHMETIC',
      btc_coverage                   TYPE zif_cd_ops_types=>ty_check_code VALUE 'BTC_COVERAGE',
      cdi_unknown                    TYPE zif_cd_ops_types=>ty_check_code VALUE 'CDI_UNKNOWN',
      check_amount_mismatch          TYPE zif_cd_ops_types=>ty_check_code VALUE 'CHECK_AMOUNT_MISMATCH',
      check_not_found                TYPE zif_cd_ops_types=>ty_check_code VALUE 'CHECK_NOT_FOUND',
      check_status                   TYPE zif_cd_ops_types=>ty_check_code VALUE 'CHECK_STATUS',
      circuit_breaker                TYPE zif_cd_ops_types=>ty_check_code VALUE 'CIRCUIT_BREAKER',
      "! A68: the run selected no statement - nothing was evaluated
      no_data                        TYPE zif_cd_ops_types=>ty_check_code VALUE 'NO_DATA',
      "! Operating model 2026-11-06: entries expected to post are not posted (rule S13)
      posting_incomplete             TYPE zif_cd_ops_types=>ty_check_code VALUE 'POSTING_INCOMPLETE',
      "! FS-CD review: not found yet, statement within EBS_INFLIGHT_HOURS (W, NOTIFY)
      awaiting_lot_transfer          TYPE zif_cd_ops_types=>ty_check_code VALUE 'AWAITING_LOT_TRANSFER',
      "! A98: ZCD_BTC_MAP rows that normalise to one key (blank flow = '*') but differ
      map_conflict                   TYPE zif_cd_ops_types=>ty_check_code VALUE 'MAP_CONFLICT',
      "! PCRE patterns: a ZCD_EBS_FLOW_PAT pattern that does not compile (line blocked)
      flow_pattern_invalid           TYPE zif_cd_ops_types=>ty_check_code VALUE 'FLOW_PATTERN_INVALID',
      code_count_mismatch            TYPE zif_cd_ops_types=>ty_check_code VALUE 'CODE_COUNT_MISMATCH',
      code_total_mismatch            TYPE zif_cd_ops_types=>ty_check_code VALUE 'CODE_TOTAL_MISMATCH',
      currency_mismatch              TYPE zif_cd_ops_types=>ty_check_code VALUE 'CURRENCY_MISMATCH',
      currency_missing               TYPE zif_cd_ops_types=>ty_check_code VALUE 'CURRENCY_MISSING',
      declared_totals                TYPE zif_cd_ops_types=>ty_check_code VALUE 'DECLARED_TOTALS',
      duplicate_entry                TYPE zif_cd_ops_types=>ty_check_code VALUE 'DUPLICATE_ENTRY',
      duplicate_history              TYPE zif_cd_ops_types=>ty_check_code VALUE 'DUPLICATE_HISTORY',
      entries_not_accounted          TYPE zif_cd_ops_types=>ty_check_code VALUE 'ENTRIES_NOT_ACCOUNTED',
      entry_count                    TYPE zif_cd_ops_types=>ty_check_code VALUE 'ENTRY_COUNT',
      fi_doc_not_cleared             TYPE zif_cd_ops_types=>ty_check_code VALUE 'FI_DOC_NOT_CLEARED',
      fi_doc_not_found               TYPE zif_cd_ops_types=>ty_check_code VALUE 'FI_DOC_NOT_FOUND',
      gl_account_not_mapped          TYPE zif_cd_ops_types=>ty_check_code VALUE 'GL_ACCOUNT_NOT_MAPPED',
      gl_ne_closing                  TYPE zif_cd_ops_types=>ty_check_code VALUE 'GL_NE_CLOSING',
      gross_totals                   TYPE zif_cd_ops_types=>ty_check_code VALUE 'GROSS_TOTALS',
      house_bank_ambiguous           TYPE zif_cd_ops_types=>ty_check_code VALUE 'HOUSE_BANK_AMBIGUOUS',
      map_action_block               TYPE zif_cd_ops_types=>ty_check_code VALUE 'MAP_ACTION_BLOCK',
      not_posted                     TYPE zif_cd_ops_types=>ty_check_code VALUE 'NOT_POSTED',
      opening_ne_prior_closing       TYPE zif_cd_ops_types=>ty_check_code VALUE 'OPENING_NE_PRIOR_CLOSING',
      payment_not_found              TYPE zif_cd_ops_types=>ty_check_code VALUE 'PAYMENT_NOT_FOUND',
      payment_status                 TYPE zif_cd_ops_types=>ty_check_code VALUE 'PAYMENT_STATUS',
      posting_rule_mismatch          TYPE zif_cd_ops_types=>ty_check_code VALUE 'POSTING_RULE_MISMATCH',
      posting_rule_missing           TYPE zif_cd_ops_types=>ty_check_code VALUE 'POSTING_RULE_MISSING',
      posting_rule_unresolved        TYPE zif_cd_ops_types=>ty_check_code VALUE 'POSTING_RULE_UNRESOLVED',
      "! Return / NOC reason correction: lot items of one payment with different reasons
      reason_ambiguous               TYPE zif_cd_ops_types=>ty_check_code VALUE 'REASON_AMBIGUOUS',
      reason_invalid                 TYPE zif_cd_ops_types=>ty_check_code VALUE 'REASON_INVALID',
      reason_missing                 TYPE zif_cd_ops_types=>ty_check_code VALUE 'REASON_MISSING',
      reason_kind                    TYPE zif_cd_ops_types=>ty_check_code VALUE 'REASON_KIND',
      reason_map_incomplete          TYPE zif_cd_ops_types=>ty_check_code VALUE 'REASON_MAP_INCOMPLETE',
      reason_unmapped                TYPE zif_cd_ops_types=>ty_check_code VALUE 'REASON_UNMAPPED',
      ref_format                     TYPE zif_cd_ops_types=>ty_check_code VALUE 'REF_FORMAT',
      ref_missing                    TYPE zif_cd_ops_types=>ty_check_code VALUE 'REF_MISSING',
      "! A65: reference longer than the key it must become (never truncated)
      ref_too_long                   TYPE zif_cd_ops_types=>ty_check_code VALUE 'REF_TOO_LONG',
      "! A65: configured key length above the DDIC key width (configuration)
      key_length_config              TYPE zif_cd_ops_types=>ty_check_code VALUE 'KEY_LENGTH_CONFIG',
      retrieval_not_found            TYPE zif_cd_ops_types=>ty_check_code VALUE 'RETRIEVAL_NOT_FOUND',
      rule_group_empty               TYPE zif_cd_ops_types=>ty_check_code VALUE 'RULE_GROUP_EMPTY',
      rule_unusable                  TYPE zif_cd_ops_types=>ty_check_code VALUE 'RULE_UNUSABLE',
      retrieval_status               TYPE zif_cd_ops_types=>ty_check_code VALUE 'RETRIEVAL_STATUS',
      return_item_not_found          TYPE zif_cd_ops_types=>ty_check_code VALUE 'RETURN_ITEM_NOT_FOUND',
      return_lot_status              TYPE zif_cd_ops_types=>ty_check_code VALUE 'RETURN_LOT_STATUS',
      sign_mismatch                  TYPE zif_cd_ops_types=>ty_check_code VALUE 'SIGN_MISMATCH',
      stmt_already_imported          TYPE zif_cd_ops_types=>ty_check_code VALUE 'STMT_ALREADY_IMPORTED',
      stmt_date_future               TYPE zif_cd_ops_types=>ty_check_code VALUE 'STMT_DATE_FUTURE',
      stmt_date_missing              TYPE zif_cd_ops_types=>ty_check_code VALUE 'STMT_DATE_MISSING',
      stmt_date_stale                TYPE zif_cd_ops_types=>ty_check_code VALUE 'STMT_DATE_STALE',
      stmt_duplicate_in_file         TYPE zif_cd_ops_types=>ty_check_code VALUE 'STMT_DUPLICATE_IN_FILE',
      stmt_no_gap                    TYPE zif_cd_ops_types=>ty_check_code VALUE 'STMT_NO_GAP',
      stmt_no_repeat                 TYPE zif_cd_ops_types=>ty_check_code VALUE 'STMT_NO_REPEAT',
      unmapped_btc                   TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNMAPPED_BTC',
      value_date_window              TYPE zif_cd_ops_types=>ty_check_code VALUE 'VALUE_DATE_WINDOW',
    END OF gc_check_code.

  "! Message numbers (class ZCD_OPS) of this area's user-facing texts
  CONSTANTS:
    BEGIN OF gc_msg,
      unmapped_btc                TYPE zif_cd_ops_types=>ty_msgno VALUE '100',
      map_action_block            TYPE zif_cd_ops_types=>ty_msgno VALUE '101',
      circuit_breaker             TYPE zif_cd_ops_types=>ty_msgno VALUE '102',
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
      account_trailer_49          TYPE zif_cd_ops_types=>ty_msgno VALUE '158',
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
      control_total               TYPE zif_cd_ops_types=>ty_msgno VALUE '180',
      number_of_records           TYPE zif_cd_ops_types=>ty_msgno VALUE '181',
      group_trailer_98            TYPE zif_cd_ops_types=>ty_msgno VALUE '182',
      number_of_accounts          TYPE zif_cd_ops_types=>ty_msgno VALUE '183',
      file_trailer_99_control_tot TYPE zif_cd_ops_types=>ty_msgno VALUE '184',
      file_trailer_99_number_of   TYPE zif_cd_ops_types=>ty_msgno VALUE '185',
      file_trailer_99_number_of_2 TYPE zif_cd_ops_types=>ty_msgno VALUE '186',
      account                     TYPE zif_cd_ops_types=>ty_msgno VALUE '187',
      total_credits_100           TYPE zif_cd_ops_types=>ty_msgno VALUE '188',
      total_debits_400            TYPE zif_cd_ops_types=>ty_msgno VALUE '189',
      credit_item_count_100       TYPE zif_cd_ops_types=>ty_msgno VALUE '190',
      debit_item_count_400        TYPE zif_cd_ops_types=>ty_msgno VALUE '191',
      statement_txssummry         TYPE zif_cd_ops_types=>ty_msgno VALUE '192',
      ttlntries_nbofntries        TYPE zif_cd_ops_types=>ty_msgno VALUE '193',
      ttlntries_sum               TYPE zif_cd_ops_types=>ty_msgno VALUE '194',
      ttlntries_ttlnetntry_signed TYPE zif_cd_ops_types=>ty_msgno VALUE '195',
      ttlcdtntries                TYPE zif_cd_ops_types=>ty_msgno VALUE '196',
      ttldbtntries                TYPE zif_cd_ops_types=>ty_msgno VALUE '197',
      nbofntries                  TYPE zif_cd_ops_types=>ty_msgno VALUE '198',
      sum                         TYPE zif_cd_ops_types=>ty_msgno VALUE '199',
      second_file_header          TYPE zif_cd_ops_types=>ty_msgno VALUE '500',
      account_outside_group       TYPE zif_cd_ops_types=>ty_msgno VALUE '501',
      detail_outside_account      TYPE zif_cd_ops_types=>ty_msgno VALUE '502',
      acct_trailer_no_account     TYPE zif_cd_ops_types=>ty_msgno VALUE '503',
      group_trailer_no_group      TYPE zif_cd_ops_types=>ty_msgno VALUE '504',
      record_after_trailer        TYPE zif_cd_ops_types=>ty_msgno VALUE '505',
      stmt_date_missing           TYPE zif_cd_ops_types=>ty_msgno VALUE '506',
      report_result               TYPE zif_cd_ops_types=>ty_msgno VALUE '507',
      report_header               TYPE zif_cd_ops_types=>ty_msgno VALUE '508',
      report_saved                TYPE zif_cd_ops_types=>ty_msgno VALUE '509',
      report_path_missing         TYPE zif_cd_ops_types=>ty_msgno VALUE '510',
      lookup_not_found            TYPE zif_cd_ops_types=>ty_msgno VALUE '511',
      lookup_status               TYPE zif_cd_ops_types=>ty_msgno VALUE '512',
      rule_group_empty            TYPE zif_cd_ops_types=>ty_msgno VALUE '513',
      rule_unusable               TYPE zif_cd_ops_types=>ty_msgno VALUE '514',
      currency_missing            TYPE zif_cd_ops_types=>ty_msgno VALUE '515',
      account_currency_missing    TYPE zif_cd_ops_types=>ty_msgno VALUE '516',
      duplicate_history           TYPE zif_cd_ops_types=>ty_msgno VALUE '517',
      cdi_unknown                 TYPE zif_cd_ops_types=>ty_msgno VALUE '518',
      gross_credits               TYPE zif_cd_ops_types=>ty_msgno VALUE '519',
      gross_debits                TYPE zif_cd_ops_types=>ty_msgno VALUE '520',
      posting_rule_unresolved     TYPE zif_cd_ops_types=>ty_msgno VALUE '521',
      reason_map_incomplete       TYPE zif_cd_ops_types=>ty_msgno VALUE '522',
      reason_kind                 TYPE zif_cd_ops_types=>ty_msgno VALUE '523',
      trailer_field_missing       TYPE zif_cd_ops_types=>ty_msgno VALUE '524',
      ref_too_long                TYPE zif_cd_ops_types=>ty_msgno VALUE '525',
      key_length_config           TYPE zif_cd_ops_types=>ty_msgno VALUE '526',
      date_range                  TYPE zif_cd_ops_types=>ty_msgno VALUE '527',
      no_data                     TYPE zif_cd_ops_types=>ty_msgno VALUE '528',
      unevaluated                 TYPE zif_cd_ops_types=>ty_msgno VALUE '529',
      file_encoding               TYPE zif_cd_ops_types=>ty_msgno VALUE '530',
      file_read_error             TYPE zif_cd_ops_types=>ty_msgno VALUE '531',
      awaiting_lot_transfer       TYPE zif_cd_ops_types=>ty_msgno VALUE '532',
      map_conflict                TYPE zif_cd_ops_types=>ty_msgno VALUE '534',
      funds_layout                TYPE zif_cd_ops_types=>ty_msgno VALUE '535',
      camt_document               TYPE zif_cd_ops_types=>ty_msgno VALUE '536',
      invalid_count               TYPE zif_cd_ops_types=>ty_msgno VALUE '537',
      entry_not_booked            TYPE zif_cd_ops_types=>ty_msgno VALUE '538',
      batch_mismatch              TYPE zif_cd_ops_types=>ty_msgno VALUE '539',
      batch_detail_amount         TYPE zif_cd_ops_types=>ty_msgno VALUE '540',
      posting_incomplete          TYPE zif_cd_ops_types=>ty_msgno VALUE '541',
      posting_unevaluated         TYPE zif_cd_ops_types=>ty_msgno VALUE '542',
      lot_reason_missing          TYPE zif_cd_ops_types=>ty_msgno VALUE '543',
      lot_reason_unmapped         TYPE zif_cd_ops_types=>ty_msgno VALUE '544',
      lot_reason_ambiguous        TYPE zif_cd_ops_types=>ty_msgno VALUE '545',
      out_of_scope                TYPE zif_cd_ops_types=>ty_msgno VALUE '546',
      flow_pattern_invalid        TYPE zif_cd_ops_types=>ty_msgno VALUE '547',
    END OF gc_msg.

ENDINTERFACE.
