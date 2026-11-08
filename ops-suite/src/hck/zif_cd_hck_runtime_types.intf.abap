*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_runtime_types.intf.abap
*& Purpose:
*& Types and constants of the read-only runtime checks of the morning
*& report: number ranges nearly exhausted (NRIV), qRFC / bgRFC queues in
*& error or stuck, payments issued but not cleared on the bank statement.
*& Check codes, parameter names and defaults, message numbers and the
*& delivered (VERIFY-DDIC) table and field names of the queue reads.
*& Modification log:
*& 2026-11-07 | Initial version (checks E_NUMRANGE, E_QUEUES, A_INFLIGHT).
*& 2026-11-07 | Clearing / return evidence by rule table ZCD_HCK_CLRRULE and evidence plug-ins
*&            | (ZIF_CD_HCK_EVIDENCE); method class CRD (card collections); BSAS assignment
*&            | read replaced by BSEG XREF2; CLEARING_ / RETURN_INCONSISTENT (user rules 1-5);
*&            | BAI lifecycle per payment: roles ZCD_HCK_BTCROLE, outcomes ZCD_HCK_SEQOUT (user
*&            | correction of rule 4), UNEXPECTED_SEQUENCE, PENDING_OUTCOME_MISSING.
*& 2026-11-07 | Cheque lifecycle (581 / 255 / corrections): statement link by cheque number, outcome
*&            | rows with register state and own finding, amount compared with the register.
*& 2026-11-07 | Design review: REQUIRED X / C / N mandatory (an unusable mandatory kind leaves the
*&            | purpose undetermined, CLEARING_UNDETERMINED), unmapped monetary bank codes
*&            | (BTC_ROLE_MISSING, exclusions HCK_BTC_INFO_<scheme>), cheque link by suffix and
*&            | house bank account (CHEQUE_LINK_AMBIGUOUS).
*& 2026-11-07 | Code review of the cheque lifecycle: every anomaly of an evidence (TY_EVIDENCE-MORE),
*&            | correction lines (compare C), voided state, register missing, outcome finding catalogue.
*& 2026-11-07 | Purpose RETRIEVED after RETURNED (canonical payment outcome: a retrieval is not a return).
*& 2026-11-08 | Confirmed DPAYH status values: evidence PENDING (status job not yet run) and EV_DATE
*&            | (newest record of the evidence); message 682 (waiting for the payment status job).
*& 2026-11-08 | Status lag: check code PAY_STATUS_LAG, parameters HCK_PAY_STATUS_LAG_MIN (grace, 120 min)
*&            | and HCK_PAY_STATUS_ACK_OPEN (statuses that must change after the bank ACK), messages 683-687.
*& 2026-11-08 | Comment only: several cheques on one payment document are a defensive path - a stop and
*&            | reissue creates a new payment document and cheque number (user 2026-11-08).
*& 2026-11-08 | Status lag after a file-level ACK: parameters HCK_PAY_ACK_FILE_CLASSES (flow + classes
*&            | acknowledged per file) and HCK_PAY_ACK_FILE_SRC (FMON source of the generation group),
*&            | DPAYH payment run fields GC_RUN_FIELD, messages 301, 312, 346, 688, 689.
*& 2026-11-08 | Table consolidation: approved tables (HCK / READ) and drift tables (HCK / DRIFT) read from
*&            | ZCD_OPS_TABWL (was ZCD_HCK_TABWL, ZCD_HCK_DRIFT).
*& 2026-11-08 | Table consolidation: Stripe evidence settings are ZCA_PARAM parameters HCK_STRIPE_*
*&            | (GC_PARAM; ZCD_HCK_EVSET retired, TY_SETTING / GC_SETTING removed).
*& 2026-11-08 | Table consolidation: TY_PM_CLASS with key HBKID (blank = class row, filled = calendar of a
*&            | house bank; ZCD_HCK_PMBANK merged); TY_PM_BANK removed.
*& 2026-11-08 | A_INFLIGHT at scale: codes PAY_SNAPSHOT_STALE, PAY_EVALUATED_LIVE (message 374); PARAM4
*&            | (TOP_N) retired - examples per finding are ZCA_PARAM PAYOUT_EXAMPLES.
*& 2026-11-08 | Customer posting areas: method classes from ZPMC (PAY_METHODS string, built from one entry per payment
*&            | method; GC_PAY_METHODS_SEP), lifecycle roles from ZBTR.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - number range, queue, in-flight types</p>
"! Shared by ZCL_CD_HCK_C_NUMRANGE, ZCL_CD_HCK_C_QUEUES, ZCL_CD_HCK_C_INFLIGHT and
"! their data access ZIF_CD_HCK_RUNTIME_DAO. Read-only: nothing here writes SAP data.
INTERFACE zif_cd_hck_runtime_types
  PUBLIC.

  " ------------------------------------------------------------ number ranges
  "! NRIV-OBJECT (number range object, SNRO)
  TYPES ty_nr_object TYPE c LENGTH 10.
  TYPES tt_nr_object TYPE SORTED TABLE OF ty_nr_object WITH UNIQUE KEY table_line.
  "! NRIV-FROMNUMBER / TONUMBER / NRLEVEL: character fields (VERIFY-DDIC CHAR 20)
  TYPES ty_nr_number TYPE c LENGTH 20.
  TYPES ty_year TYPE n LENGTH 4.

  "! One internal interval of NRIV (EXTERNIND blank) - VERIFY-DDIC field names
  TYPES:
    BEGIN OF ty_nr_interval,
      object     TYPE ty_nr_object,
      subobject  TYPE c LENGTH 6,
      nrrangenr  TYPE c LENGTH 2,
      toyear     TYPE ty_year,
      fromnumber TYPE ty_nr_number,
      tonumber   TYPE ty_nr_number,
      nrlevel    TYPE ty_nr_number,
    END OF ty_nr_interval.
  TYPES tt_nr_interval TYPE STANDARD TABLE OF ty_nr_interval WITH EMPTY KEY.

  "! Year of a number range interval that is not year-dependent (NRIV-TOYEAR)
  CONSTANTS gc_nr_no_year TYPE ty_year VALUE '0000'.
  "! A number range limit or level is converted only when it consists of digits
  CONSTANTS gc_pcre_digits TYPE string VALUE `\d+`.

  " ------------------------------------------------------------ queues
  "! Queue source kind - also the threshold key (DIM1, 4 characters)
  TYPES ty_queue_kind TYPE c LENGTH 4.
  "! Problem class of a queue state: ERROR, HOLD or STUCK
  TYPES ty_queue_class TYPE c LENGTH 5.
  TYPES ty_queue_name TYPE c LENGTH 70.
  TYPES ty_queue_state TYPE c LENGTH 20.
  TYPES ty_tcode TYPE c LENGTH 20.

  CONSTANTS:
    BEGIN OF gc_queue_kind,
      outbound TYPE ty_queue_kind VALUE 'QOUT',
      inbound  TYPE ty_queue_kind VALUE 'QIN',
      bgrfc    TYPE ty_queue_kind VALUE 'BGRF',
    END OF gc_queue_kind.

  CONSTANTS:
    BEGIN OF gc_queue_class,
      error TYPE ty_queue_class VALUE 'ERROR',
      hold  TYPE ty_queue_class VALUE 'HOLD',
      stuck TYPE ty_queue_class VALUE 'STUCK',
    END OF gc_queue_class.

  "! Monitor transaction support uses per source (named in the finding; nothing is called)
  CONSTANTS:
    BEGIN OF gc_queue_tcode,
      outbound TYPE ty_tcode VALUE 'SMQ1',
      inbound  TYPE ty_tcode VALUE 'SMQ2',
      bgrfc    TYPE ty_tcode VALUE 'SBGRFCMON',
    END OF gc_queue_tcode.

  "! Where the entries of one queue source are read: table and the fields by role. The
  "! names are validated against the runtime DDIC before the read (unknown name = the source
  "! is reported QUEUE_CONFIG_INVALID, never read as empty)
  TYPES:
    BEGIN OF ty_queue_source,
      kind        TYPE ty_queue_kind,
      tabname     TYPE zif_cd_hck_types=>ty_tabname,
      name_field  TYPE zif_cd_hck_types=>ty_fieldname,
      dest_field  TYPE zif_cd_hck_types=>ty_fieldname,
      state_field TYPE zif_cd_hck_types=>ty_fieldname,
      date_field  TYPE zif_cd_hck_types=>ty_fieldname,
      time_field  TYPE zif_cd_hck_types=>ty_fieldname,
      "! The table name is configuration (bgRFC): it must be on ZCD_OPS_TABWL (HCK / READ)
      configured  TYPE abap_bool,
    END OF ty_queue_source.

  "! Entries of one queue, destination, state and day (oldest time of the day)
  TYPES:
    BEGIN OF ty_queue_group,
      name    TYPE ty_queue_name,
      dest    TYPE ty_queue_name,
      state   TYPE ty_queue_state,
      qdate   TYPE d,
      qtime   TYPE t,
      entries TYPE int8,
    END OF ty_queue_group.
  TYPES tt_queue_group TYPE STANDARD TABLE OF ty_queue_group WITH EMPTY KEY.

  "! Outbound qRFC queue entries (SMQ1). VERIFY-DDIC: every field name below
  CONSTANTS:
    BEGIN OF gc_trfcqout,
      tabname     TYPE zif_cd_hck_types=>ty_tabname VALUE 'TRFCQOUT',
      name_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QNAME',
      dest_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'DEST',
      state_field TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QSTATE',
      date_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QRFCDATUM',
      time_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QRFCUZEIT',
    END OF gc_trfcqout.

  "! Inbound qRFC queue entries (SMQ2). VERIFY-DDIC: every field name below (no destination)
  CONSTANTS:
    BEGIN OF gc_trfcqin,
      tabname     TYPE zif_cd_hck_types=>ty_tabname VALUE 'TRFCQIN',
      name_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QNAME',
      state_field TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QSTATE',
      date_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QRFCDATUM',
      time_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QRFCUZEIT',
    END OF gc_trfcqin.

  "! Names of the bgRFC source specification (PARAM4 of the queue check, NAME=VALUE;...)
  CONSTANTS:
    BEGIN OF gc_spec,
      table TYPE string VALUE `TABLE`,
      name  TYPE string VALUE `NAME`,
      dest  TYPE string VALUE `DEST`,
      state TYPE string VALUE `STATE`,
      date  TYPE string VALUE `DATE`,
      time  TYPE string VALUE `TIME`,
    END OF gc_spec.

  " ------------------------------------------------------------ payments in flight
  "! D disbursement (TFK042Z-XEINZ blank), C collection (XEINZ = X)
  TYPES ty_flow TYPE c LENGTH 1.
  "! Method class (result METHOD_CLASS of the posting area ZPMC, e.g. WIR, ACH, CHQ, CRD): an open list of
  "! configuration, never a fixed domain. Three characters: flow + class is the 4-character
  "! threshold key (ZCD_HCK_THRESH-BUKRS)
  TYPES ty_method_class TYPE c LENGTH 3.
  "! Flow + method class, e.g. DWIR: the metric dimension and the threshold key
  TYPES ty_flow_class TYPE c LENGTH 4.
  TYPES ty_pymet TYPE c LENGTH 1.
  TYPES tt_pymet TYPE SORTED TABLE OF ty_pymet WITH UNIQUE KEY table_line.
  "! DFKKOP-AUGBL / DPAYH-DOC1R width (as ZIF_CD_OPS_TRACE_TYPES=>TY_DOCNO)
  TYPES ty_docno TYPE c LENGTH 12.
  "! BSEG-XREF2 (reference key 2; carries AUGBL for ACH and card collections)
  TYPES ty_xref2 TYPE c LENGTH 12.
  TYPES ty_hkont TYPE c LENGTH 10.
  TYPES tt_hkont TYPE SORTED TABLE OF ty_hkont WITH UNIQUE KEY table_line.

  CONSTANTS:
    BEGIN OF gc_flow,
      disbursement TYPE ty_flow VALUE 'D',
      collection   TYPE ty_flow VALUE 'C',
    END OF gc_flow.

  "! How a method class is aged: business days after the value date (run date when missing)
  "! or calendar days after the issue (run) date
  TYPES ty_age_basis TYPE c LENGTH 10.
  CONSTANTS:
    BEGIN OF gc_age_basis,
      value_date TYPE ty_age_basis VALUE 'VALUE_DATE',
      issue_date TYPE ty_age_basis VALUE 'ISSUE_DATE',
    END OF gc_age_basis.

  "! DPAYH-HBKID (house bank of the payment)
  TYPES ty_hbkid TYPE c LENGTH 5.
  "! Method class of a flow from the customer posting area ZPMC (FQC0, 2026-11-08; was
  "! ZCD_HCK_PMCLASS): the class row (HBKID blank) gathers the payment methods of the entries with
  "! house bank '*' (one entry per payment method), or the factory calendar of one house bank of
  "! the class (HBKID filled: an entry with that house bank; only CALENDAR is used, e.g. UK / German
  "! bank holidays of an international ACH bank). A payment method maps to a class by the '*'
  "! entries only - one entry per flow + payment method, so exactly one class per flow.
  TYPES:
    BEGIN OF ty_pm_class,
      flow         TYPE ty_flow,
      method_class TYPE ty_method_class,
      "! House bank of a calendar override; blank = the class row (all house banks)
      hbkid        TYPE ty_hbkid,
      "! SAP payment methods of the class (comma list of the ZPMC entries; class row only)
      pay_methods  TYPE string,
      "! Ageing basis (class row only)
      age_basis    TYPE ty_age_basis,
      "! Factory calendar of the business days (class row: blank = PARAM1 of the check)
      calendar     TYPE zif_cd_hck_types=>ty_calendar,
      description  TYPE zif_cd_hck_types=>ty_text,
    END OF ty_pm_class.
  TYPES tt_pm_class TYPE SORTED TABLE OF ty_pm_class WITH UNIQUE KEY flow method_class hbkid.
  "! Separator of TY_PM_CLASS-PAY_METHODS
  CONSTANTS gc_pay_methods_sep TYPE string VALUE `,`.

  "! Payment of a payment run (DPAYH, proposal runs excluded, DOC1R filled) with its flow.
  "! VERIFY-DDIC: DPAYH-BUKRS, PYMET, HBKID, VALUT, RWBTR, WAERS; TFK042Z-XEINZ via T001-LAND1
  TYPES:
    BEGIN OF ty_issued_payment,
      doc1r    TYPE ty_docno,
      laufd    TYPE d,
      laufi    TYPE c LENGTH 6,
      bukrs    TYPE c LENGTH 4,
      pymet    TYPE ty_pymet,
      "! House bank (calendar override per bank, ZPMC entry with a house bank)
      hbkid    TYPE ty_hbkid,
      valut    TYPE d,
      amount   TYPE zif_cd_ops_types=>ty_amount,
      currency TYPE zif_cd_ops_types=>ty_currency,
      "! TFK042Z-XEINZ: X = collection, blank = disbursement
      xeinz    TYPE abap_bool,
      "! Set by the check (not read): flow D / C and method class of the payment method
      flow     TYPE ty_flow,
      class    TYPE ty_method_class,
    END OF ty_issued_payment.
  TYPES tt_issued_payment TYPE STANDARD TABLE OF ty_issued_payment WITH EMPTY KEY.

  "! Company code + XREF2 of a G/L line (collections: XREF2 = AUGBL)
  TYPES:
    BEGIN OF ty_xref2_key,
      bukrs TYPE c LENGTH 4,
      xref2 TYPE ty_xref2,
    END OF ty_xref2_key.
  TYPES tt_xref2_key TYPE SORTED TABLE OF ty_xref2_key WITH UNIQUE KEY bukrs xref2.

  "! G/L line (BSEG) found by company code + XREF2 with its clearing document
  TYPES:
    BEGIN OF ty_gl_xref2_line,
      bukrs TYPE c LENGTH 4,
      belnr TYPE c LENGTH 10,
      gjahr TYPE n LENGTH 4,
      buzei TYPE n LENGTH 3,
      xref2 TYPE ty_xref2,
      "! Assignment: AUGBL after the payment run; Stripe payout processing sets the descriptor
      zuonr TYPE c LENGTH 18,
      augbl TYPE c LENGTH 10,
    END OF ty_gl_xref2_line.
  TYPES tt_gl_xref2_line TYPE STANDARD TABLE OF ty_gl_xref2_line WITH EMPTY KEY.

  " ------------------------------------------------------------ clearing / return rules
  "! Purpose of a rule row (ZCD_HCK_CLRRULE-PURPOSE)
  TYPES ty_purpose TYPE c LENGTH 10.
  "! X = mandatory, must hold and indicates the purpose; C = mandatory corroboration, must hold
  "! but never indicates the purpose on its own; N = mandatory, must not hold; blank =
  "! informational, shown in the detail only (never decides). A mandatory row whose kind is
  "! not configured or not usable leaves the purpose undetermined (no positive conclusion);
  "! only an informational row may be skipped
  TYPES ty_required TYPE c LENGTH 1.
  TYPES ty_rule_seq TYPE n LENGTH 3.
  TYPES ty_rule_param TYPE c LENGTH 40.

  "! Purposes in the order they decide: the first purpose with evidence decides (a voided
  "! cheque or a returned payment is never judged as cleared)
  CONSTANTS:
    BEGIN OF gc_purpose,
      voided   TYPE ty_purpose VALUE 'VOIDED',
      returned TYPE ty_purpose VALUE 'RETURNED',
      "! Money recalled by a manual retrieval (ACH 466 -> 166): not a return (canonical outcome
      "! RETRIEVED); decides after RETURNED, so a retrieval followed by a return is RETURNED
      retrieved TYPE ty_purpose VALUE 'RETRIEVED',
      "! Outcome not final yet but expected (e.g. redeposit of a failed collection): not late
      pending   TYPE ty_purpose VALUE 'PENDING',
      cleared   TYPE ty_purpose VALUE 'CLEARED',
      "! Consistency of a state in flight (e.g. Stripe payout processed, F.13 still open): all
      "! rows hold = still in flight and aged, some = CLEARING_INCONSISTENT
      in_flight TYPE ty_purpose VALUE 'IN_FLIGHT',
    END OF gc_purpose.

  CONSTANTS:
    BEGIN OF gc_required,
      must_hold     TYPE ty_required VALUE 'X',
      condition     TYPE ty_required VALUE 'C',
      must_not_hold TYPE ty_required VALUE 'N',
      info          TYPE ty_required VALUE ' ',
    END OF gc_required.

  "! Expectation of the evidence ZCL_CD_HCK_EV_GL_ZUONR (PARAM1): BSEG-ZUONR still = AUGBL
  "! (ACH collections, F.13 clears one-to-one) or changed (Stripe: statement descriptor)
  TYPES ty_zuonr_expect TYPE c LENGTH 10.
  CONSTANTS:
    BEGIN OF gc_zuonr_expect,
      equal   TYPE ty_zuonr_expect VALUE 'EQUAL',
      changed TYPE ty_zuonr_expect VALUE 'CHANGED',
    END OF gc_zuonr_expect.

  "! Names of the rule parameters (named in the message of a missing parameter)
  CONSTANTS:
    BEGIN OF gc_rule_param,
      param1 TYPE string VALUE `PARAM1`,
    END OF gc_rule_param.

  "! Interface every evidence plug-in (ZCD_HCK_CLRRULE-EVIDENCE_CLASS) implements
  CONSTANTS gc_evidence_intf TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZIF_CD_HCK_EVIDENCE'.

  "! One active row of ZCD_HCK_CLRRULE: evidence kind and its parameters for flow + method
  "! class + purpose; rows of one purpose are AND-combined (REQUIRED X / N)
  TYPES:
    BEGIN OF ty_clr_rule,
      flow           TYPE ty_flow,
      method_class   TYPE ty_method_class,
      purpose        TYPE ty_purpose,
      seq            TYPE ty_rule_seq,
      evidence_class TYPE zif_cd_ops_types=>ty_class_name,
      param1         TYPE ty_rule_param,
      param2         TYPE ty_rule_param,
      param3         TYPE ty_rule_param,
      required       TYPE ty_required,
      description    TYPE zif_cd_hck_types=>ty_text,
    END OF ty_clr_rule.
  TYPES tt_clr_rule TYPE SORTED TABLE OF ty_clr_rule WITH UNIQUE KEY flow method_class purpose seq.

  " ------------------------------------------------------------ BAI lifecycle of a payment
  "! Code of a statement line in its scheme (BAI2 type code, ISO Domain-Family-Sub-family, PRTRY;
  "! as ZBTM) and its role in the lifecycle of one payment reference
  TYPES ty_scheme TYPE c LENGTH 5.
  TYPES ty_btc_code TYPE c LENGTH 35.
  TYPES ty_btc_role TYPE c LENGTH 15.
  TYPES ty_outcome TYPE c LENGTH 20.
  TYPES ty_seq_pattern TYPE c LENGTH 200.
  "! Separator of the ordered role sequence matched by ZCD_HCK_SEQOUT-SEQ_PATTERN
  CONSTANTS gc_role_sep TYPE string VALUE `,`.

  "! Customer posting area ZBTR usage LIFECYCLE (was ZCD_HCK_BTCROLE): the same code means
  "! different things per flow + method class; the scheme
  "! of a line comes from the statement format (ZCL_CD_EBS_SRC_FEB=>LINE_CODE: BAI2 / ISO / PRTRY)
  TYPES:
    BEGIN OF ty_btc_role_row,
      flow           TYPE ty_flow,
      method_class   TYPE ty_method_class,
      scheme         TYPE ty_scheme,
      btc_code       TYPE ty_btc_code,
      role           TYPE ty_btc_role,
      "! X: the amount of a line of this role is compared with the returns lot (DFKKRP),
      "! R: with the payment amount of the cheque (DPAYH-RWBTR of the AUGBL)
      compare_amount TYPE c LENGTH 1,
    END OF ty_btc_role_row.
  TYPES tt_btc_role TYPE SORTED TABLE OF ty_btc_role_row WITH UNIQUE KEY flow method_class scheme btc_code.

  CONSTANTS:
    BEGIN OF gc_compare,
      returns_lot TYPE c LENGTH 1 VALUE 'X',
      register    TYPE c LENGTH 1 VALUE 'R',
      "! The bank corrected the line before (e.g. 399 / 699): an earlier R line is not compared -
      "! its amount was superseded and the cheque is cleared manually in FPCHR
      correction  TYPE c LENGTH 1 VALUE 'C',
    END OF gc_compare.

  "! Statement link of the lifecycle evidence (PARAM2): blank = FEBEP-CHECT = AUGBL, ZTNUM =
  "! FEBEP-CHECT = last PARAM3 characters of the cheque number DFKKCR-ZTNUM (default 13)
  CONSTANTS gc_link_cheque TYPE string VALUE `ZTNUM`.
  "! Token of a status list (PARAM1 of the cheque status evidence) for the blank (open) state
  CONSTANTS gc_state_blank TYPE string VALUE `BLANK`.
  "! DFKKCR-STATE of a voided cheque (confirmed 2026-11-07): of several cheques of one payment
  "! document the newest cheque not voided decides the payment (defensive: a stop and reissue
  "! creates a new payment document and cheque number, user 2026-11-08)
  CONSTANTS gc_state_voided TYPE string VALUE `V`.

  "! ZCD_HCK_SEQOUT: the first active pattern (by SEQ) matching the whole role sequence decides
  TYPES:
    BEGIN OF ty_seq_outcome,
      flow            TYPE ty_flow,
      method_class    TYPE ty_method_class,
      seq             TYPE ty_rule_seq,
      seq_pattern     TYPE ty_seq_pattern,
      outcome         TYPE ty_outcome,
      "! Returns lot items (DFKKRP) expected: 0 .. 9, blank = not checked
      expected_dfkkrp TYPE c LENGTH 1,
      "! Pending outcome: calendar days after the last line it may stay (0 = no limit)
      max_age_days    TYPE i,
      "! Severity when the evidence does not match (blank = E)
      severity        TYPE zif_cd_ops_types=>ty_severity,
      description     TYPE zif_cd_hck_types=>ty_text,
      "! The row applies only when the register state (DFKKCR-STATE, cheque link) is in this list
      reg_state       TYPE ty_rule_param,
      "! Reaching this outcome is itself a finding with this code (e.g. CHEQUE_CLARIFICATION)
      finding         TYPE zif_cd_ops_types=>ty_check_code,
    END OF ty_seq_outcome.
  TYPES tt_seq_outcome TYPE SORTED TABLE OF ty_seq_outcome WITH UNIQUE KEY flow method_class seq.

  CONSTANTS:
    BEGIN OF gc_outcome,
      cleared          TYPE ty_outcome VALUE 'CLEARED',
      in_flight        TYPE ty_outcome VALUE 'IN_FLIGHT',
      returned         TYPE ty_outcome VALUE 'RETURNED',
      retrieved        TYPE ty_outcome VALUE 'RETRIEVED',
      retrieval_failed TYPE ty_outcome VALUE 'RETRIEVAL_FAILED',
      redeposit        TYPE ty_outcome VALUE 'REDEPOSIT_PENDING',
      "! A monetary line on the payment reference has no role and is not an approved exclusion:
      "! the lifecycle is not known (never CLEARED / RETURNED)
      indeterminate    TYPE ty_outcome VALUE 'INDETERMINATE',
    END OF gc_outcome.

  " ------------------------------------------------------------ configured source
  "! Confirmed: DFKKOP-AUGBL = payment document (the open items a payment cleared)
  CONSTANTS gc_dfkkop_augbl TYPE zif_cd_hck_types=>ty_fieldname VALUE 'AUGBL'.

  "! A configured table read by payment reference: the fields by role (names validated before
  "! the read; blank = role not read)
  TYPES:
    BEGIN OF ty_ref_source,
      tabname        TYPE zif_cd_hck_types=>ty_tabname,
      ref_field      TYPE zif_cd_hck_types=>ty_fieldname,
      type_field     TYPE zif_cd_hck_types=>ty_fieldname,
      amount_field   TYPE zif_cd_hck_types=>ty_fieldname,
      currency_field TYPE zif_cd_hck_types=>ty_fieldname,
      group_field    TYPE zif_cd_hck_types=>ty_fieldname,
      date_field     TYPE zif_cd_hck_types=>ty_fieldname,
      status_field   TYPE zif_cd_hck_types=>ty_fieldname,
    END OF ty_ref_source.

  "! One row of a configured source (aliases = components)
  TYPES:
    BEGIN OF ty_ref_row,
      ref      TYPE c LENGTH 70,
      rtype    TYPE c LENGTH 40,
      amount   TYPE zif_cd_ops_types=>ty_amount,
      currency TYPE zif_cd_ops_types=>ty_currency,
      grp      TYPE c LENGTH 70,
      rdate    TYPE d,
      status   TYPE c LENGTH 40,
    END OF ty_ref_row.
  TYPES tt_ref_row TYPE STANDARD TABLE OF ty_ref_row WITH EMPTY KEY.
  TYPES tt_ref_value TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_ref WITH UNIQUE KEY table_line.

  "! A further anomaly of the evidence of one payment (every anomaly is reported)
  TYPES:
    BEGIN OF ty_anomaly,
      code     TYPE zif_cd_ops_types=>ty_check_code,
      severity TYPE zif_cd_ops_types=>ty_severity,
      detail   TYPE string,
    END OF ty_anomaly.
  TYPES tt_anomaly TYPE STANDARD TABLE OF ty_anomaly WITH EMPTY KEY.

  "! Evidence of one kind for one payment; a payment without a row has no evidence
  TYPES:
    BEGIN OF ty_evidence,
      doc1r      TYPE ty_docno,
      found      TYPE abap_bool,
      "! Matching records (statement lines, lot items, G/L lines, cheques)
      hits       TYPE i,
      "! Anomaly of the evidence itself: finding code (UNEXPECTED_SEQUENCE, RETURN_INCONSISTENT,
      "! PENDING_OUTCOME_MISSING) and its severity; the payment is listed there, never aged
      anomaly    TYPE zif_cd_ops_types=>ty_check_code,
      severity   TYPE zif_cd_ops_types=>ty_severity,
      "! Short evidence text for the finding (keys, status values, sequence)
      detail     TYPE string,
      "! Anomalies after the primary one (ANOMALY), in the order found; each is its own finding
      more       TYPE tt_anomaly,
      "! Not found yet, but expected to follow: the payment status is one of the statuses the hourly
      "! payment status job has not updated yet (PARAM2 of ZCL_CD_HCK_EV_PAY_STATUS). A mandatory row
      "! that is pending keeps a purpose indicated by other evidence in flight - never inconsistent
      pending    TYPE abap_bool,
      "! Date of the newest record of the evidence (posting date of the last statement line of the
      "! lifecycle); blank when the kind has none
      ev_date    TYPE d,
    END OF ty_evidence.
  TYPES tt_evidence TYPE HASHED TABLE OF ty_evidence WITH UNIQUE KEY doc1r.

  TYPES:
    BEGIN OF ty_evidence_result,
      evidence TYPE tt_evidence,
      "! A read of the kind reached the row cap (result may be incomplete)
      capped   TYPE abap_bool,
      "! Table of the capped read (named in TECH_READ_CAPPED)
      source   TYPE zif_cd_hck_types=>ty_tabname,
      "! The kind's settings are not maintained: informational rows are skipped, a mandatory row
      "! leaves its purpose undetermined (configuration finding)
      unconfigured TYPE abap_bool,
    END OF ty_evidence_result.

  " ------------------------------------------------------------ check codes
  CONSTANTS:
    BEGIN OF gc_code,
      "! Number range interval at or above the amber usage
      nr_usage_high      TYPE zif_cd_ops_types=>ty_check_code VALUE 'NR_USAGE_HIGH',
      "! A configured number range object has no internal interval of this or next year
      nr_no_interval     TYPE zif_cd_ops_types=>ty_check_code VALUE 'NR_NO_INTERVAL',
      "! Limits or level of an interval are not numeric / not a valid interval
      nr_not_numeric     TYPE zif_cd_ops_types=>ty_check_code VALUE 'NR_NOT_NUMERIC',
      queue_error        TYPE zif_cd_ops_types=>ty_check_code VALUE 'QUEUE_ERROR',
      queue_hold         TYPE zif_cd_ops_types=>ty_check_code VALUE 'QUEUE_HOLD',
      queue_stuck        TYPE zif_cd_ops_types=>ty_check_code VALUE 'QUEUE_STUCK',
      "! A queue source could not be read (DDIC, whitelist): nothing measured for it
      queue_config       TYPE zif_cd_ops_types=>ty_check_code VALUE 'QUEUE_CONFIG_INVALID',
      "! bgRFC source not configured (PARAM4 blank) - listed, not measured
      queue_not_watched  TYPE zif_cd_ops_types=>ty_check_code VALUE 'QUEUE_NOT_MONITORED',
      "! Payments of a flow / method class not cleared on the bank statement past the limit
      payment_not_clear  TYPE zif_cd_ops_types=>ty_check_code VALUE 'PAYMENT_NOT_CLEARED',
      "! Payments aged from the run date because the value date is missing
      value_date_missing TYPE zif_cd_ops_types=>ty_check_code VALUE 'VALUE_DATE_MISSING',
      "! Configuration of the in-flight check incomplete (calendar, method class, rules)
      inflight_config    TYPE zif_cd_ops_types=>ty_check_code VALUE 'INFLIGHT_CONFIG',
      "! No ZCD_HCK_THRESH limits for a metric the check classifies by - not evaluated
      limits_missing     TYPE zif_cd_ops_types=>ty_check_code VALUE 'LIMITS_NOT_CONFIGURED',
      "! A read reached its row cap: the result may be incomplete
      read_capped        TYPE zif_cd_ops_types=>ty_check_code VALUE 'TECH_READ_CAPPED',
      "! Some but not all evidence of CLEARED (or VOIDED) holds (user rules 1, 2)
      clearing_inconsist TYPE zif_cd_ops_types=>ty_check_code VALUE 'CLEARING_INCONSISTENT',
      "! Some but not all evidence of RETURNED holds, amounts differ, several lines (rule 4)
      return_inconsist   TYPE zif_cd_ops_types=>ty_check_code VALUE 'RETURN_INCONSISTENT',
      "! A ZCD_HCK_CLRRULE row cannot be used (class, parameters): its purpose is not judged
      clrrule_invalid    TYPE zif_cd_ops_types=>ty_check_code VALUE 'CLEARING_RULE_INVALID',
      "! The ordered BAI roles of a payment match no active ZCD_HCK_SEQOUT pattern
      unexpected_seq     TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNEXPECTED_SEQUENCE',
      "! A pending outcome (e.g. redeposit) is older than its MAX_AGE_DAYS
      pending_overdue    TYPE zif_cd_ops_types=>ty_check_code VALUE 'PENDING_OUTCOME_MISSING',
      "! Amount of the cheque-paid line differs from the payment amount (manual clearing in FPCHR)
      cheque_amount      TYPE zif_cd_ops_types=>ty_check_code VALUE 'CHEQUE_AMOUNT_MISMATCH',
      "! A mandatory evidence row (REQUIRED X / C / N) is not configured or not usable: no
      "! positive conclusion for the payment, it stays in flight (design review 2026-11-07)
      undetermined       TYPE zif_cd_ops_types=>ty_check_code VALUE 'CLEARING_UNDETERMINED',
      "! A monetary statement line of the payment has no role in ZBTR (LIFECYCLE) and is not an
      "! approved exclusion (HCK_BTC_INFO_<scheme>): lifecycle INDETERMINATE
      btc_role_missing   TYPE zif_cd_ops_types=>ty_check_code VALUE 'BTC_ROLE_MISSING',
      "! A statement line fits several cheques of the same house bank account (cheque number
      "! suffix): no cashing evidence is inherited
      cheque_ambiguous   TYPE zif_cd_ops_types=>ty_check_code VALUE 'CHEQUE_LINK_AMBIGUOUS',
      "! The outcome row that matches needs the cheque register state but the payment has no
      "! cheque register row (DFKKCR) for the link of the rule
      register_missing   TYPE zif_cd_ops_types=>ty_check_code VALUE 'CHEQUE_REGISTER_MISSING',
      "! Outcome findings of cheques (ZCD_HCK_SEQOUT-FINDING): several 581 / 255, correction
      cheque_clarify     TYPE zif_cd_ops_types=>ty_check_code VALUE 'CHEQUE_CLARIFICATION',
      manual_clearing    TYPE zif_cd_ops_types=>ty_check_code VALUE 'MANUAL_CLEARING_REQUIRED',
      "! The bank evidence decides (or the bank ACK is in) but DPAYH-ZZ_PAYMENT_STATUS has not
      "! followed within the grace period (hourly payment status job): one finding per payment
      status_lag         TYPE zif_cd_ops_types=>ty_check_code VALUE 'PAY_STATUS_LAG',
      "! The payment outcome snapshot is behind more than MON_STALE_AFTER_MIN_CORE (or never ran): the
      "! counts may miss the newest evidence - evidence PARTIAL, never GREEN on stale data
      snapshot_stale     TYPE zif_cd_ops_types=>ty_check_code VALUE 'PAY_SNAPSHOT_STALE',
      "! Payments the snapshot has not reached (or whose versions all say AMBIGUOUS) evaluated live
      evaluated_live     TYPE zif_cd_ops_types=>ty_check_code VALUE 'PAY_EVALUATED_LIVE',
    END OF gc_code.

  " ------------------------------------------------------------ parameters (ZCA_PARAM)
  "! Hard ceilings of the row caps HCK_MAX_TECH_ROWS / HCK_INFLIGHT_MAX_ROWS
  CONSTANTS gc_max_tech_rows TYPE i VALUE 50000.
  CONSTANTS gc_max_inflight_rows TYPE i VALUE 50000.

  CONSTANTS:
    BEGIN OF gc_param,
      "! qRFC / bgRFC states that are an error (comma list)
      queue_err_states  TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_QUEUE_ERR_STATES',
      "! States that hold a queue (stopped)
      queue_hold_states TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_QUEUE_HOLD_STATES',
      "! States that are normal unless older than the check's age limit (stuck)
      queue_wait_states TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_QUEUE_WAIT_STATES',
      "! Rows of one technical read (NRIV intervals, queue groups)
      max_tech_rows     TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_MAX_TECH_ROWS',
      "! Payments read per window (DPAYH)
      inflight_max_rows TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_INFLIGHT_MAX_ROWS',
      "! Minutes after the bank evidence / the bank ACK before a status that did not follow is a
      "! PAY_STATUS_LAG (the payment status job runs hourly)
      status_lag_min    TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_PAY_STATUS_LAG_MIN',
      "! Payment statuses that must have changed once the bank ACK of the payment is received
      status_ack_open   TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_PAY_STATUS_ACK_OPEN',
      "! Flow + method classes acknowledged per file (comma list, e.g. CACH): their status lag after
      "! the bank ACK uses the ACK of the payment run's file (FMON generation group); every other
      "! class is acknowledged per payment (TRACE_SRC_ACK)
      ack_file_classes  TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_PAY_ACK_FILE_CLASSES',
      "! FMON source (ZCD_FMON_SRC) whose GROUP_FIELDS name the payment run of a file
      ack_file_src      TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_PAY_ACK_FILE_SRC',
      "! Stripe payout evidence (ZCL_CD_HCK_EV_STRIPE; table consolidation 2026-11-08, were the rows
      "! of ZCD_HCK_EVSET set STRIPE): chain payment document (DFKKOP-AUGBL) -> payment intent ID
      "! (DFKKOP field STRIPE_DFKKOP_FIELD) -> payout log row (STRIPE_TABLE, field
      "! STRIPE_INTENT_FIELD). Table / field names are validated against the DDIC and ZCD_OPS_TABWL
      "! (HCK / READ) before each read; delivered blank (landscape-specific, VERIFY-SE11) = the
      "! evidence kind is not configured
      stripe_table        TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_STRIPE_TABLE',
      stripe_intent_field TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_STRIPE_INTENT_FIELD',
      stripe_dfkkop_field TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_STRIPE_DFKKOP_FIELD',
      "! Optional fields of the payout log: record type, payout ID (filled = in a payout), ACK status
      stripe_type_field   TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_STRIPE_TYPE_FIELD',
      stripe_payout_field TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_STRIPE_PAYOUT_FIELD',
      stripe_ack_field    TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_STRIPE_ACK_FIELD',
      "! Optional comma lists: record types that count / refund (anomaly), ACK values that count /
      "! partial ACK (anomaly); blank = condition not used
      stripe_charge       TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_STRIPE_CHARGE',
      stripe_refund       TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_STRIPE_REFUND',
      stripe_ack_full     TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_STRIPE_ACK_FULL',
      stripe_ack_partial  TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_STRIPE_ACK_PARTIAL',
    END OF gc_param.

  "! Parameter names completed at run time: HCK_BTC_INFO_<scheme> (BAI2, ISO, PRTRY of
  "! ZIF_CD_EBS_TYPES=>GC_SCHEME) = approved informational bank codes of the scheme (comma list):
  "! codes that never concern the payment; a line of such a code is ignored by the lifecycle
  CONSTANTS:
    BEGIN OF gc_param_prefix,
      btc_info TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_BTC_INFO_',
    END OF gc_param_prefix.

  CONSTANTS:
    BEGIN OF gc_param_default,
      queue_err_states  TYPE string VALUE `SYSFAIL,CPICERR`,
      queue_hold_states TYPE string VALUE `STOP,WAITSTOP`,
      queue_wait_states TYPE string VALUE `READY,RUNNING`,
      max_tech_rows     TYPE i VALUE 5000,
      inflight_max_rows TYPE i VALUE 5000,
      status_lag_min    TYPE i VALUE 120,
      status_ack_open   TYPE string VALUE `ISSUED`,
      "! Collections ACH and card per file; disbursements (wire, ACH, cheque - cheque VERIFY) per payment
      ack_file_classes  TYPE string VALUE `CACH,CCRD`,
      ack_file_src      TYPE string VALUE `REGUT`,
    END OF gc_param_default.

  "! DPAYH fields of the payment run a generation group field (ZCD_FMON_SRC-GROUP_FIELDS of the source
  "! HCK_PAY_ACK_FILE_SRC) may name: the payment's value is the DPAYH field of the same name, so the
  "! generation group key is built from the same values as FMON builds it from the file's source row
  CONSTANTS:
    BEGIN OF gc_run_field,
      laufd TYPE string VALUE `LAUFD`,
      laufi TYPE string VALUE `LAUFI`,
      hbkid TYPE string VALUE `HBKID`,
    END OF gc_run_field.

  "! Defaults of the check parameters (PARAM1-4 of ZCD_HCK_DEF) when blank
  CONSTANTS:
    BEGIN OF gc_check_default,
      "! E_QUEUES PARAM3: READY / RUNNING older than this is stuck (minutes)
      queue_stuck_min TYPE i VALUE 30,
      "! A_INFLIGHT PARAM2 / PARAM3: look-back of VALUE_DATE classes and of ISSUE_DATE classes
      inflight_days   TYPE i VALUE 10,
      cheque_days     TYPE i VALUE 120,
      "! Longest day range counted in business days (calendar reads per run)
      max_calendar    TYPE i VALUE 400,
      "! Evidence ZCL_CD_HCK_EV_STMT_CHEQUE PARAM1: FEBEP-CHECT = last 13 characters of ZTNUM
      ztnum_suffix    TYPE i VALUE 13,
    END OF gc_check_default.

  " ------------------------------------------------------------ messages (class ZCD_OPS)
  CONSTANTS:
    BEGIN OF gc_msg,
      nr_usage            TYPE zif_cd_ops_types=>ty_msgno VALUE '376',
      nr_no_interval      TYPE zif_cd_ops_types=>ty_msgno VALUE '377',
      nr_not_numeric      TYPE zif_cd_ops_types=>ty_msgno VALUE '378',
      read_capped         TYPE zif_cd_ops_types=>ty_msgno VALUE '379',
      queue_group         TYPE zif_cd_ops_types=>ty_msgno VALUE '380',
      queue_detail        TYPE zif_cd_ops_types=>ty_msgno VALUE '381',
      queue_source_failed TYPE zif_cd_ops_types=>ty_msgno VALUE '382',
      bgrfc_not_watched   TYPE zif_cd_ops_types=>ty_msgno VALUE '383',
      limits_missing      TYPE zif_cd_ops_types=>ty_msgno VALUE '386',
      no_calendar         TYPE zif_cd_ops_types=>ty_msgno VALUE '387',
      not_cleared         TYPE zif_cd_ops_types=>ty_msgno VALUE '388',
      payment_line        TYPE zif_cd_ops_types=>ty_msgno VALUE '389',
      payment_age         TYPE zif_cd_ops_types=>ty_msgno VALUE '390',
      run_date_used       TYPE zif_cd_ops_types=>ty_msgno VALUE '391',
      value_date_missing  TYPE zif_cd_ops_types=>ty_msgno VALUE '392',
      class_not_watched   TYPE zif_cd_ops_types=>ty_msgno VALUE '393',
      inconsistent        TYPE zif_cd_ops_types=>ty_msgno VALUE '395',
      evidence_line       TYPE zif_cd_ops_types=>ty_msgno VALUE '396',
      evidence_held       TYPE zif_cd_ops_types=>ty_msgno VALUE '397',
      evidence_missing    TYPE zif_cd_ops_types=>ty_msgno VALUE '398',
      evidence_forbidden  TYPE zif_cd_ops_types=>ty_msgno VALUE '399',
      evidence_anomaly    TYPE zif_cd_ops_types=>ty_msgno VALUE '650',
      rule_invalid        TYPE zif_cd_ops_types=>ty_msgno VALUE '651',
      no_cleared_rule     TYPE zif_cd_ops_types=>ty_msgno VALUE '652',
      evidence_info       TYPE zif_cd_ops_types=>ty_msgno VALUE '653',
      ev_bank_line        TYPE zif_cd_ops_types=>ty_msgno VALUE '655',
      ev_status           TYPE zif_cd_ops_types=>ty_msgno VALUE '656',
      ev_return_item      TYPE zif_cd_ops_types=>ty_msgno VALUE '657',
      ev_gl_line          TYPE zif_cd_ops_types=>ty_msgno VALUE '658',
      ev_sequence         TYPE zif_cd_ops_types=>ty_msgno VALUE '654',
      ev_outcome          TYPE zif_cd_ops_types=>ty_msgno VALUE '659',
      ev_lot_count        TYPE zif_cd_ops_types=>ty_msgno VALUE '660',
      ev_amount_differs   TYPE zif_cd_ops_types=>ty_msgno VALUE '661',
      ev_no_pattern       TYPE zif_cd_ops_types=>ty_msgno VALUE '662',
      ev_pending_age      TYPE zif_cd_ops_types=>ty_msgno VALUE '663',
      ev_lot_no_line      TYPE zif_cd_ops_types=>ty_msgno VALUE '664',
      evidence_unconfig   TYPE zif_cd_ops_types=>ty_msgno VALUE '667',
      ev_ref_row          TYPE zif_cd_ops_types=>ty_msgno VALUE '668',
      ev_zuonr            TYPE zif_cd_ops_types=>ty_msgno VALUE '669',
      ev_zuonr_changed    TYPE zif_cd_ops_types=>ty_msgno VALUE '670',
      ev_cheque           TYPE zif_cd_ops_types=>ty_msgno VALUE '672',
      ev_cheque_amount    TYPE zif_cd_ops_types=>ty_msgno VALUE '673',
      evidence_mandatory  TYPE zif_cd_ops_types=>ty_msgno VALUE '674',
      undetermined        TYPE zif_cd_ops_types=>ty_msgno VALUE '675',
      unusable_unconfig   TYPE zif_cd_ops_types=>ty_msgno VALUE '676',
      unusable_invalid    TYPE zif_cd_ops_types=>ty_msgno VALUE '677',
      ev_role_missing     TYPE zif_cd_ops_types=>ty_msgno VALUE '678',
      ev_indeterminate    TYPE zif_cd_ops_types=>ty_msgno VALUE '679',
      ev_other_cheque     TYPE zif_cd_ops_types=>ty_msgno VALUE '680',
      ev_register_missing TYPE zif_cd_ops_types=>ty_msgno VALUE '681',
      evidence_pending    TYPE zif_cd_ops_types=>ty_msgno VALUE '682',
      lag_bank            TYPE zif_cd_ops_types=>ty_msgno VALUE '683',
      lag_ack             TYPE zif_cd_ops_types=>ty_msgno VALUE '684',
      lag_ack_unconfig    TYPE zif_cd_ops_types=>ty_msgno VALUE '685',
      lag_ack_failed      TYPE zif_cd_ops_types=>ty_msgno VALUE '686',
      lag_detail          TYPE zif_cd_ops_types=>ty_msgno VALUE '687',
      lag_file_ack        TYPE zif_cd_ops_types=>ty_msgno VALUE '688',
      lag_file_detail     TYPE zif_cd_ops_types=>ty_msgno VALUE '689',
      file_ack_unconfig   TYPE zif_cd_ops_types=>ty_msgno VALUE '301',
      file_ack_field      TYPE zif_cd_ops_types=>ty_msgno VALUE '312',
      file_ack_no_iface   TYPE zif_cd_ops_types=>ty_msgno VALUE '346',
      evaluated_live      TYPE zif_cd_ops_types=>ty_msgno VALUE '374',
    END OF gc_msg.

ENDINTERFACE.
