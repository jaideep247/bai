*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_brk_types.intf.abap
*& Purpose:
*& Types and constants of the clearing-account break analysis
*& (docs/BREAK_ANALYSIS.md): accounts, variance buckets, bucket rules and
*& their conditions (kinds, operators, the fields of a journal line and of
*& its group), the grouped journal read, the lines, the linked rows of the
*& link registry, the snapshot (header, groups, lines), configuration
*& problems, check codes, parameters (prefix BRK_, area CA_OPS) and the
*& messages 280-299 of ZCA_OPS. Read-only analysis: no posting, no
*& clearing, no matching. No logic.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - break analysis types</p>
INTERFACE zif_ca_ops_brk_types
  PUBLIC.

  TYPES ty_acct_id    TYPE c LENGTH 20.
  TYPES ty_bucket     TYPE c LENGTH 20.
  TYPES ty_rule_id    TYPE c LENGTH 20.
  TYPES ty_layer_id   TYPE c LENGTH 10.
  TYPES ty_cond_kind  TYPE c LENGTH 5.
  TYPES ty_field      TYPE c LENGTH 30.
  TYPES ty_operator   TYPE c LENGTH 2.
  TYPES ty_value      TYPE c LENGTH 120.
  TYPES ty_assignment TYPE c LENGTH 18.
  TYPES ty_reason     TYPE c LENGTH 255.
  TYPES ty_text       TYPE c LENGTH 60.
  TYPES ty_pattern    TYPE c LENGTH 70.
  TYPES ty_ledger     TYPE c LENGTH 2.
  TYPES ty_docln      TYPE c LENGTH 6.
  TYPES ty_recon_key  TYPE c LENGTH 20.
  TYPES ty_link_key   TYPE c LENGTH 70.
  TYPES ty_link_value TYPE c LENGTH 40.
  TYPES ty_status     TYPE c LENGTH 1.
  "! Key of a journal line inside one analysis (ledger / company code / year / document / line)
  TYPES ty_line_key   TYPE c LENGTH 40.

  "! Bucket of a line or group that no rule explains (never counts as explained)
  CONSTANTS gc_bucket_other TYPE ty_bucket VALUE 'OTHER'.
  "! Area of a rule that applies to every area (product rules)
  CONSTANTS gc_area_any TYPE zif_ca_ops_types=>ty_area VALUE '*'.
  "! A condition value starting with it names a value-list parameter of area CA_OPS (e.g. @BRK_DOCTYPES_RETURN)
  CONSTANTS gc_param_marker TYPE c LENGTH 1 VALUE '@'.
  "! Debit / credit indicator of a debit journal line (DRCRK)
  CONSTANTS gc_debit TYPE c LENGTH 1 VALUE 'S'.
  "! Separator of a value list
  CONSTANTS gc_list_separator TYPE c LENGTH 1 VALUE ','.
  "! Separator of the parts of a line key, a linked row's key and a group's object key
  CONSTANTS gc_key_separator TYPE c LENGTH 1 VALUE '/'.
  "! Link registry object of the analysed lines (journal entry line, released view I_JournalEntryItem)
  CONSTANTS gc_item_object TYPE zif_ca_ops_link_types=>ty_object_id VALUE 'S4_JOURNAL_ITEM'.

  "! Kind of a condition
  CONSTANTS:
    BEGIN OF gc_kind,
      "! A field of the open line (GC_FIELD)
      field TYPE ty_cond_kind VALUE 'FIELD',
      "! A value of the line's group (GC_GROUP)
      group TYPE ty_cond_kind VALUE 'GROUP',
      "! A day window of the line (GC_DAYS)
      days  TYPE ty_cond_kind VALUE 'DAYS',
      "! A linked object of the line, read through the link registry (LINK_ID)
      link  TYPE ty_cond_kind VALUE 'LINK',
    END OF gc_kind.

  "! Operators of a condition
  CONSTANTS:
    BEGIN OF gc_op,
      eq TYPE ty_operator VALUE 'EQ',
      ne TYPE ty_operator VALUE 'NE',
      in TYPE ty_operator VALUE 'IN',
      ni TYPE ty_operator VALUE 'NI',
      ge TYPE ty_operator VALUE 'GE',
      le TYPE ty_operator VALUE 'LE',
      gt TYPE ty_operator VALUE 'GT',
      lt TYPE ty_operator VALUE 'LT',
      "! PCRE matched to the complete value
      rx TYPE ty_operator VALUE 'RX',
      "! Blank / not blank (no value)
      bl TYPE ty_operator VALUE 'BL',
      nb TYPE ty_operator VALUE 'NB',
      "! LINK: a linked row (with a field value of the list) exists at least MIN_COUNT times / none exists
      ex TYPE ty_operator VALUE 'EX',
      nx TYPE ty_operator VALUE 'NX',
    END OF gc_op.

  "! Fields of a journal line a FIELD condition may compare
  CONSTANTS:
    BEGIN OF gc_field,
      posting_date  TYPE ty_field VALUE 'POSTING_DATE',
      document_date TYPE ty_field VALUE 'DOCUMENT_DATE',
      doc_type      TYPE ty_field VALUE 'DOC_TYPE',
      debit_credit  TYPE ty_field VALUE 'DEBIT_CREDIT',
      assignment    TYPE ty_field VALUE 'ASSIGNMENT',
      ref_type      TYPE ty_field VALUE 'REF_TYPE',
      recon_key     TYPE ty_field VALUE 'RECON_KEY',
      amount        TYPE ty_field VALUE 'AMOUNT',
      currency      TYPE ty_field VALUE 'CURRENCY',
    END OF gc_field.

  "! Values of a group a GROUP condition may compare
  CONSTANTS:
    BEGIN OF gc_group,
      "! Lines of the group up to the key date, of them debits (S) and credits (H)
      lines          TYPE ty_field VALUE 'LINES',
      debits         TYPE ty_field VALUE 'DEBITS',
      credits        TYPE ty_field VALUE 'CREDITS',
      "! Net at the key date
      net_amount     TYPE ty_field VALUE 'NET_AMOUNT',
      "! Days from the oldest line to the key date
      age_days       TYPE ty_field VALUE 'AGE_DAYS',
      "! X = lines after the key date bring the group to zero
      clears_later   TYPE ty_field VALUE 'CLEARS_LATER',
      "! Document type of the first line after the key date
      later_doc_type TYPE ty_field VALUE 'LATER_DOC_TYPE',
      "! Days from the key date to the first line after it
      days_to_clear  TYPE ty_field VALUE 'DAYS_TO_CLEAR',
    END OF gc_group.

  "! Day windows of a DAYS condition (compared as numbers)
  CONSTANTS:
    BEGIN OF gc_days,
      "! Days from the posting date to the end of its posting month (0 = posted on the last day)
      period_end TYPE ty_field VALUE 'PERIOD_END',
      "! Days from the posting date to the key date
      key_date   TYPE ty_field VALUE 'KEY_DATE',
    END OF gc_days.

  "! Fields of the journal line as the link registry object S4_JOURNAL_ITEM names them (source rows of a link)
  CONSTANTS:
    BEGIN OF gc_item_field,
      ledger      TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'LEDGER',
      company     TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'COMPANYCODE',
      year        TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'FISCALYEAR',
      document    TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'ACCOUNTINGDOCUMENT',
      line        TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'LEDGERGLLINEITEM',
      account     TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'GLACCOUNT',
      assignment  TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'ASSIGNMENTREFERENCE',
    END OF gc_item_field.

  "! Status of a snapshot
  CONSTANTS:
    BEGIN OF gc_status,
      complete TYPE ty_status VALUE 'S',
      "! A cap was reached (groups or lines): the snapshot holds the oldest groups only
      partial  TYPE ty_status VALUE 'P',
    END OF gc_status.

  "! Object types and check codes of the findings of ZCL_CA_OPS_CHK_BREAK and of the configuration problems
  CONSTANTS:
    BEGIN OF gc_object_type,
      group   TYPE zif_ca_ops_types=>ty_object_type VALUE 'BRK_GROUP',
      account TYPE zif_ca_ops_types=>ty_object_type VALUE 'BRK_ACCT',
      rule    TYPE zif_ca_ops_types=>ty_object_type VALUE 'BRK_RULE',
    END OF gc_object_type.
  CONSTANTS:
    BEGIN OF gc_code,
      "! A group no rule explains (bucket OTHER), older than BRK_UNEXPLAINED_DAYS
      unexplained  TYPE zif_ca_ops_types=>ty_check_code VALUE 'BREAK_UNEXPLAINED',
      "! No snapshot of an active account, or the latest is older than BRK_STALE_DAYS
      no_snapshot  TYPE zif_ca_ops_types=>ty_check_code VALUE 'BREAK_NO_SNAPSHOT',
      "! The latest snapshot is partial (a cap was reached)
      partial      TYPE zif_ca_ops_types=>ty_check_code VALUE 'BREAK_PARTIAL',
      "! A bucket rule cannot be applied (its condition or bucket is invalid)
      rule_invalid TYPE zif_ca_ops_types=>ty_check_code VALUE 'BREAK_RULE_INVALID',
    END OF gc_code.
  CONSTANTS gc_rule_id TYPE zif_ca_ops_types=>ty_rule_id VALUE 'BREAK'.

  "! Parameters of the break analysis (area CA_OPS, prefix BRK_)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Ledger of the journal lines when the account names none [0L]
      ledger      TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_LEDGER',
      "! Days of lines before the key date [62]
      lookback    TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_LOOKBACK_DAYS',
      "! Days of lines after the key date that may clear a group [10]
      forward     TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_FORWARD_DAYS',
      "! Groups of one account read at most [20000]
      max_groups  TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_MAX_GROUPS',
      "! Assignments per read of the lines (IN list) [500]
      package     TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_PACKAGE_SIZE',
      "! Lines of one account read at most [200000]
      max_items   TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_MAX_ITEMS',
      "! Rows one read of a linked object returns at most [5000]
      link_rows   TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_LINK_MAX_ROWS',
      "! An unexplained group older than this many days is a finding [5]
      unexplained TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_UNEXPLAINED_DAYS',
      "! A snapshot whose key date is older than this many days is stale [2]
      stale_days  TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_STALE_DAYS',
      "! Findings of one account at most (the rest summarised) [500]
      max_finds   TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_MAX_FINDINGS',
      "! Key date of the report without one: today minus this many days [1]
      key_lag     TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_KEY_DATE_LAG',
      "! Named by the product bucket rules as @ values (config/breaks): last days of a month and days to clear
      "! that count as timing [3], document types of a retrieval and of a return that clear a group [blank]
      timing_days TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_TIMING_DAYS',
      doc_retrieval TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_DOCTYPES_RETRIEVAL',
      doc_return  TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_DOCTYPES_RETURN',
      "! Bank transaction code lists a customer's LINK rules name as @ values (blank in the product; the customer
      "! layer maintains them): new / unmapped codes, redeposit, cheque paid / stop, codes sent cumulated
      btc_new       TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_BTC_NEW',
      btc_redeposit TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_BTC_REDEPOSIT',
      btc_cheque    TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_BTC_CHEQUE',
      btc_cumulated TYPE zif_ca_ops_types=>ty_param_name VALUE 'BRK_BTC_CUMULATED',
      "! Retention of the snapshots, purge target BREAK (ZCL_CA_OPS_BRK_PURGE, registry ZCA_OPS_PURGE) [400]
      retention   TYPE zif_ca_ops_types=>ty_param_name VALUE 'RETENTION_DAYS_BREAK',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_default,
      ledger      TYPE zif_ca_ops_types=>ty_param_value VALUE '0L',
      lookback    TYPE i VALUE 62,
      forward     TYPE i VALUE 10,
      max_groups  TYPE i VALUE 20000,
      package     TYPE i VALUE 500,
      max_items   TYPE i VALUE 200000,
      link_rows   TYPE i VALUE 5000,
      unexplained TYPE i VALUE 5,
      stale_days  TYPE i VALUE 2,
      max_finds   TYPE i VALUE 500,
      key_lag     TYPE i VALUE 1,
      timing_days TYPE i VALUE 3,
      retention   TYPE i VALUE 400,
    END OF gc_default.

  "! Messages of ZCA_OPS (280-299)
  CONSTANTS:
    BEGIN OF gc_msg,
      summary        TYPE zif_ca_ops_types=>ty_msgno VALUE '280',
      unexplained    TYPE zif_ca_ops_types=>ty_msgno VALUE '281',
      no_snapshot    TYPE zif_ca_ops_types=>ty_msgno VALUE '282',
      partial        TYPE zif_ca_ops_types=>ty_msgno VALUE '283',
      bucket_unknown TYPE zif_ca_ops_types=>ty_msgno VALUE '284',
      field_unknown  TYPE zif_ca_ops_types=>ty_msgno VALUE '285',
      op_invalid     TYPE zif_ca_ops_types=>ty_msgno VALUE '286',
      link_unknown   TYPE zif_ca_ops_types=>ty_msgno VALUE '287',
      param_blank    TYPE zif_ca_ops_types=>ty_msgno VALUE '288',
      pattern        TYPE zif_ca_ops_types=>ty_msgno VALUE '289',
      process_off    TYPE zif_ca_ops_types=>ty_msgno VALUE '290',
      group_cap      TYPE zif_ca_ops_types=>ty_msgno VALUE '291',
      item_cap       TYPE zif_ca_ops_types=>ty_msgno VALUE '292',
      link_failed    TYPE zif_ca_ops_types=>ty_msgno VALUE '293',
      more_findings  TYPE zif_ca_ops_types=>ty_msgno VALUE '294',
    END OF gc_msg.

  "! A clearing account of the analysis (ZCA_OPS_BRKACC)
  TYPES:
    BEGIN OF ty_account,
      area          TYPE zif_ca_ops_types=>ty_area,
      acct_id       TYPE ty_acct_id,
      bukrs         TYPE bukrs,
      hkont         TYPE saknr,
      ledger        TYPE ty_ledger,
      process_id    TYPE zif_ca_ops_chk_types=>ty_process_id,
      lookback_days TYPE i,
      forward_days  TYPE i,
      max_groups    TYPE i,
      description   TYPE ty_text,
      active        TYPE abap_bool,
    END OF ty_account.
  TYPES tt_account TYPE STANDARD TABLE OF ty_account WITH EMPTY KEY.

  "! A variance bucket (ZCA_OPS_BRKBKT)
  TYPES:
    BEGIN OF ty_bucket_row,
      bucket      TYPE ty_bucket,
      description TYPE ty_text,
      explained   TYPE abap_bool,
      layer_id    TYPE ty_layer_id,
      seq         TYPE i,
      active      TYPE abap_bool,
    END OF ty_bucket_row.
  TYPES tt_bucket TYPE SORTED TABLE OF ty_bucket_row WITH UNIQUE KEY bucket.

  "! A bucket rule (ZCA_OPS_BRKRUL)
  TYPES:
    BEGIN OF ty_rule,
      area         TYPE zif_ca_ops_types=>ty_area,
      rule_id      TYPE ty_rule_id,
      layer_id     TYPE ty_layer_id,
      seq          TYPE i,
      bucket       TYPE ty_bucket,
      acct_pattern TYPE ty_pattern,
      reason       TYPE ty_value,
      description  TYPE ty_text,
      active       TYPE abap_bool,
    END OF ty_rule.
  TYPES tt_rule TYPE STANDARD TABLE OF ty_rule WITH EMPTY KEY.

  "! A condition of a rule (ZCA_OPS_BRKCND)
  TYPES:
    BEGIN OF ty_cond,
      area       TYPE zif_ca_ops_types=>ty_area,
      rule_id    TYPE ty_rule_id,
      cond_no    TYPE n LENGTH 3,
      cond_kind  TYPE ty_cond_kind,
      field      TYPE ty_field,
      operator   TYPE ty_operator,
      cond_value TYPE ty_value,
      link_id    TYPE zif_ca_ops_link_types=>ty_link_id,
      min_count  TYPE i,
    END OF ty_cond.
  TYPES tt_cond TYPE STANDARD TABLE OF ty_cond WITH EMPTY KEY.

  "! The values of the @ parameters the conditions name (resolved once per analysis)
  TYPES:
    BEGIN OF ty_param_list,
      name   TYPE zif_ca_ops_types=>ty_param_name,
      values TYPE string_table,
    END OF ty_param_list.
  TYPES tt_param_list TYPE SORTED TABLE OF ty_param_list WITH UNIQUE KEY name.

  "! One group of the grouped journal read: assignment and currency that do not net to zero at the key date
  TYPES:
    BEGIN OF ty_group_sum,
      assignment TYPE ty_assignment,
      currency   TYPE zif_ca_ops_types=>ty_currency,
      amount     TYPE zif_ca_ops_types=>ty_amount,
      line_count TYPE i,
      first_date TYPE d,
      last_date  TYPE d,
    END OF ty_group_sum.
  TYPES tt_group_sum TYPE STANDARD TABLE OF ty_group_sum WITH EMPTY KEY.

  "! A journal line of a group (up to the key date, or LATER = after it)
  TYPES:
    BEGIN OF ty_item,
      ledger        TYPE ty_ledger,
      bukrs         TYPE bukrs,
      gjahr         TYPE gjahr,
      belnr         TYPE belnr_d,
      docln         TYPE ty_docln,
      hkont         TYPE saknr,
      assignment    TYPE ty_assignment,
      currency      TYPE zif_ca_ops_types=>ty_currency,
      amount        TYPE zif_ca_ops_types=>ty_amount,
      posting_date  TYPE d,
      document_date TYPE d,
      doc_type      TYPE c LENGTH 2,
      debit_credit  TYPE c LENGTH 1,
      ref_type      TYPE c LENGTH 5,
      recon_key     TYPE ty_recon_key,
      later         TYPE abap_bool,
    END OF ty_item.
  TYPES tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

  "! A row of a linked object read for a line (link registry): the line, the link, the row's masked key and values
  TYPES:
    BEGIN OF ty_hit,
      link_id   TYPE zif_ca_ops_link_types=>ty_link_id,
      line_key  TYPE ty_line_key,
      object_id TYPE zif_ca_ops_link_types=>ty_object_id,
      row_key   TYPE ty_link_key,
      pairs     TYPE zif_ca_ops_link_types=>tt_pair,
    END OF ty_hit.
  TYPES tt_hit TYPE STANDARD TABLE OF ty_hit WITH NON-UNIQUE SORTED KEY line COMPONENTS link_id line_key.

  "! A configuration problem: a rule or condition that cannot be applied (the rule is left out)
  TYPES:
    BEGIN OF ty_problem,
      rule_id TYPE ty_rule_id,
      msgno   TYPE zif_ca_ops_types=>ty_msgno,
      v1      TYPE zif_ca_ops_types=>ty_msgv,
      v2      TYPE zif_ca_ops_types=>ty_msgv,
      v3      TYPE zif_ca_ops_types=>ty_msgv,
      v4      TYPE zif_ca_ops_types=>ty_msgv,
    END OF ty_problem.
  TYPES tt_problem TYPE STANDARD TABLE OF ty_problem WITH EMPTY KEY.

  "! A classified group of the snapshot (ZCA_OPS_BRKGRP)
  TYPES:
    BEGIN OF ty_group,
      group_no     TYPE i,
      assignment   TYPE ty_assignment,
      currency     TYPE zif_ca_ops_types=>ty_currency,
      amount       TYPE zif_ca_ops_types=>ty_amount,
      line_count   TYPE i,
      first_date   TYPE d,
      last_date    TYPE d,
      age_days     TYPE i,
      later_amount TYPE zif_ca_ops_types=>ty_amount,
      clears_later TYPE abap_bool,
      later_date   TYPE d,
      bucket       TYPE ty_bucket,
      explained    TYPE abap_bool,
      rule_id      TYPE ty_rule_id,
      reason       TYPE ty_reason,
      recon_key    TYPE ty_recon_key,
    END OF ty_group.
  TYPES tt_group TYPE STANDARD TABLE OF ty_group WITH EMPTY KEY.

  "! A classified line of the snapshot (ZCA_OPS_BRKITM)
  TYPES:
    BEGIN OF ty_item_result,
      group_no    TYPE i,
      item_no     TYPE i,
      item        TYPE ty_item,
      bucket      TYPE ty_bucket,
      rule_id     TYPE ty_rule_id,
      link_object TYPE zif_ca_ops_link_types=>ty_object_id,
      link_key    TYPE ty_link_key,
      link_value  TYPE ty_link_value,
    END OF ty_item_result.
  TYPES tt_item_result TYPE STANDARD TABLE OF ty_item_result WITH EMPTY KEY.

  "! What the classification needs besides the rows
  TYPES:
    BEGIN OF ty_context,
      acct_id  TYPE ty_acct_id,
      key_date TYPE d,
    END OF ty_context.

  "! Header of a snapshot (ZCA_OPS_BRKRUN)
  TYPES:
    BEGIN OF ty_snapshot,
      snap_id     TYPE zif_ca_ops_types=>ty_run_id,
      area        TYPE zif_ca_ops_types=>ty_area,
      acct_id     TYPE ty_acct_id,
      bukrs       TYPE bukrs,
      hkont       TYPE saknr,
      ledger      TYPE ty_ledger,
      key_date    TYPE d,
      from_date   TYPE d,
      to_date     TYPE d,
      status      TYPE ty_status,
      cfg_version TYPE zif_ca_ops_types=>ty_cfg_version,
      group_count TYPE i,
      item_count  TYPE i,
      other_count TYPE i,
      started_at  TYPE timestampl,
      ended_at    TYPE timestampl,
      created_by  TYPE syuname,
      message     TYPE zif_ca_ops_types=>ty_message,
    END OF ty_snapshot.
  TYPES tt_snapshot TYPE STANDARD TABLE OF ty_snapshot WITH EMPTY KEY.

  "! Result of the analysis of one account (report, tests)
  TYPES:
    BEGIN OF ty_analysis,
      snapshot TYPE ty_snapshot,
      groups   TYPE tt_group,
      items    TYPE tt_item_result,
      problems TYPE tt_problem,
      "! X = not analysed (business process not in effect)
      skipped  TYPE abap_bool,
    END OF ty_analysis.
  TYPES tt_analysis TYPE STANDARD TABLE OF ty_analysis WITH EMPTY KEY.

  "! An unexplained group of the latest snapshot of an account (ZCL_CA_OPS_CHK_BREAK)
  TYPES:
    BEGIN OF ty_open_break,
      snap_id    TYPE zif_ca_ops_types=>ty_run_id,
      group_no   TYPE i,
      assignment TYPE ty_assignment,
      currency   TYPE zif_ca_ops_types=>ty_currency,
      amount     TYPE zif_ca_ops_types=>ty_amount,
      first_date TYPE d,
      age_days   TYPE i,
      line_count TYPE i,
    END OF ty_open_break.
  TYPES tt_open_break TYPE STANDARD TABLE OF ty_open_break WITH EMPTY KEY.

ENDINTERFACE.
