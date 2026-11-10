*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_types.intf.abap
*& Purpose:
*& Shared by Health Check (HCK), File Monitoring (FMON) and EBS Validation (EBS).
*& Every finding of every payment engine area is written to the framework store (ZCA_OPS_RUN /
*& ZCA_OPS_FINDING); generic types and constants are in ZIF_CA_OPS_TYPES.
*& B = block (never post), E = error, W = warning, I = information
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Payment engine area CORE and exception dispositions.
*& 2026-11-06 | Object-key and group sets (reconciliation scope).
*& 2026-11-06 | Message class constant and message number / variable types (texts as messages).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Alert claim / repeat / partial statuses, intent key, SLG1 external ID, escalation override (A17, A45, A46).
*& 2026-11-06 | Plug-in interface names for the factory interface check (audit A62).
*& 2026-11-06 | Run status NO_DATA (N) for runs without input (audit A68).
*& 2026-11-06 | Alert message carries intent key and raise time (webhook de-duplication).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-06 | Messages 742-747 (PCRE patterns: alert rule pattern invalid, pattern check and migration).
*& 2026-11-07 | Transactions dashboard date windows GC_TRX_DASHBOARD (single source, cds_abap_parity).
*& 2026-11-07 | Core parameter names / prefixes / defaults (GC_PARAM, GC_PARAM_PREFIX, GC_PARAM_DEFAULT);
*&            | TT_PARAM_RANGE and GC_RANGE for ZIF_CA_OPS_PARAMS=>GET_RANGE.
*& 2026-11-07 | Channel HTTP removed with the webhook channel (read-only scope).
*& 2026-11-07 | Alert message without INTENT_KEY / OCCURRED_AT (only the removed webhook read them; the claim keeps both).
*& 2026-11-07 | Parameters in the framework ZCA_PARAM: areas GC_PARAM_AREA, name prefix -> area
*&            | GC_PARAM_AREA_PREFIX, TT_PARAM_ERROR (ZIF_CA_OPS_PARAMS=>GET_ERRORS); TT_KV removed.
*& 2026-11-07 | Transactions dashboard retention (400 days) and date kinds (canonical payment outcome).
*& 2026-11-08 | Table consolidation: GC_TABWL_PURPOSE (ZCD_OPS_TABWL, one approved-table list per area and
*&            | purpose).
*& 2026-11-08 | Table consolidation: parameters MON_STALE_AFTER_MIN_<area> (area prefix MON_ -> CD_OPS; was
*&            | ZCD_OPS_MONCFG).
*& 2026-11-08 | GC_RANGE-SIGN_EXCLUDE (a range that leaves a value out, e.g. the PAY_STATUS_PENDING marker).
*& 2026-11-08 | Prefix POSTAREA_ -> CD_OPS: posting areas of the mapping tables (customer posting areas).
*& 2026-11-08 | Transactions dashboard on the payment worklist: GC_TRX_DASHBOARD-RETENTION_DAYS retired (no 400-day
*&            | driver), date kinds WORKLIST / RUN / VALUE / DUE (POSTING retired).
*& 2026-11-10 | GC_MSGNO_FREE removed: the PRISM handled-manually save no longer turns a failed closure into a warning.
*& 2026-11-10 | Error class (GC_ERROR_CLASS, rules GC_ERROR_RULE; TY_FINDING-ERROR_CLASS), job link of a
*&            | run (TY_RUN-JOBNAME / JOBCOUNT / SYSID), TABWL purpose LOOKUP (EBS R21), messages 802-805.
*& 2026-11-10 | Missing bank ACK alert (user request 2026-11-10): labels of the detail lines GC_ACK_MSG
*&            | (messages 816-837), label separator, alert subject and table.
*& 2026-11-10 | Logical file names / paths (FILE) of the EBS input file and the morning report export,
*&            | S_DATASET activities (directory traversal fix).
*& 2026-11-10 | Generic part moved to the reusable framework ZCA_OPS (ZIF_CA_OPS_TYPES: runs, findings,
*&            | severities, RAG, dispositions, error classes, alerting, framework parameters); this interface
*&            | keeps the payment engine constants. Areas are parameter areas of ZCA_PARAM (CD_EBS, CD_FMON,
*&            | CD_HCK, CD_OPS; was EBS / FMON / HCK / CORE), typed ZIF_CA_OPS_TYPES=>TY_AREA.
*& 2026-11-10 | GC_ACK_TEMPLATE: e-mail template of the missing bank ACK alert (alert e-mail templates).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - shared types and constants</p>
"! Payment engine constants; the generic types are in ZIF_CA_OPS_TYPES (framework ZCA_OPS).
INTERFACE zif_cd_ops_types
  PUBLIC.

  "! Message class holding every text of the suite (translatable, SE91); the framework's own texts
  "! are messages of class ZCA_OPS (ZIF_CA_OPS_TYPES=>GC_MESSAGE_CLASS)
  CONSTANTS gc_message_class TYPE symsgid VALUE 'ZCD_OPS'.

  "! Transactions dashboard (CDS, docs/Dashboard_Transactions.md): KPI cards and the returns / NOC
  "! items of the last ITEM_WINDOW_DAYS days and the payment runs of the last EVIDENCE_WINDOW_DAYS
  "! days. CDS cannot read constants: the literals there are compared by the portable check
  "! cds_abap_parity (tools/cds_abap_parity.py)
  CONSTANTS:
    BEGIN OF gc_trx_dashboard,
      item_window_days     TYPE i VALUE 30,
      evidence_window_days TYPE i VALUE 45,
    END OF gc_trx_dashboard.

  "! Date kinds of the transactions dashboard filter (ZR_CD_TrxFlow parameter P_DateKind)
  CONSTANTS:
    BEGIN OF gc_trx_date_kind,
      worklist TYPE c LENGTH 10 VALUE 'WORKLIST',
      run      TYPE c LENGTH 10 VALUE 'RUN',
      value    TYPE c LENGTH 10 VALUE 'VALUE',
      due      TYPE c LENGTH 10 VALUE 'DUE',
    END OF gc_trx_date_kind.

  "! Payment engine parameter-name prefixes completed at run time (MON_STALE_AFTER_MIN_<area>); the
  "! framework's prefixes (ALERT_<route>, RETENTION_DAYS_<target>, SLA_DAYS_<area>_<severity>) are in
  "! ZIF_CA_OPS_TYPES=>GC_PARAM_PREFIX
  CONSTANTS:
    BEGIN OF gc_param_prefix,
      "! Minutes after the last completed run of a payment engine area before its monitor is stale
      "! (table consolidation 2026-11-08, was ZCD_OPS_MONCFG): the HCK self-check reads it through
      "! the parameter API, the "as of" CDS views of the dashboards through ZI_CD_OpsStaleCfg
      "! (cds_abap_parity: the CDS holds this prefix and GC_PARAM_AREA-OPS as literals)
      stale_after_min TYPE zif_ca_ops_types=>ty_param_name VALUE 'MON_STALE_AFTER_MIN_',
    END OF gc_param_prefix.

  "! Parameter areas of the suite in the framework ZCA_PARAM (config/param_areas.csv)
  CONSTANTS:
    BEGIN OF gc_param_area,
      ops  TYPE zif_ca_ops_types=>ty_area VALUE 'CD_OPS',
      ebs  TYPE zif_ca_ops_types=>ty_area VALUE 'CD_EBS',
      fmon TYPE zif_ca_ops_types=>ty_area VALUE 'CD_FMON',
      hck  TYPE zif_ca_ops_types=>ty_area VALUE 'CD_HCK',
    END OF gc_param_area.

  "! Name prefixes that decide the area of a payment engine parameter (registered with the framework
  "! adapter by ZCL_CD_OPS_FACTORY=>GET_PARAMS, ZCL_CA_OPS_PARAMS=>AREA_OF): TRACE_ PAYOUT_ MON_
  "! POSTAREA_ -> CD_OPS, EBS_ -> CD_EBS, FMON_ -> CD_FMON, HCK_ -> CD_HCK; the framework's ALERT_ SLA_
  "! PURGE_ RETENTION_ -> CA_OPS (purge targets of the suite name their area in ZCA_OPS_PURGE)
  CONSTANTS:
    BEGIN OF gc_param_area_prefix,
      trace     TYPE zif_ca_ops_types=>ty_param_name VALUE 'TRACE_',
      "! Payment outcome snapshot (canonical payment outcome, 2026-11-07)
      payout    TYPE zif_ca_ops_types=>ty_param_name VALUE 'PAYOUT_',
      "! Monitor freshness of every area (table consolidation 2026-11-08, was ZCD_OPS_MONCFG)
      monitor   TYPE zif_ca_ops_types=>ty_param_name VALUE 'MON_',
      "! Customer posting areas of the mapping tables (2026-11-08, ZIF_CD_OPS_POSTAREA_TYPES)
      postarea  TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_',
      ebs       TYPE zif_ca_ops_types=>ty_param_name VALUE 'EBS_',
      fmon      TYPE zif_ca_ops_types=>ty_param_name VALUE 'FMON_',
      hck       TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_',
    END OF gc_param_area_prefix.

  "! Payment engine areas: parameter areas of ZCA_PARAM (config/param_areas.csv), the area of every
  "! run, finding, alert rule, lock and authorisation of the suite (one area register, 2026-11-10)
  CONSTANTS:
    BEGIN OF gc_pe_area,
      health_check TYPE zif_ca_ops_types=>ty_area VALUE 'CD_HCK',
      file_monitor TYPE zif_ca_ops_types=>ty_area VALUE 'CD_FMON',
      ebs          TYPE zif_ca_ops_types=>ty_area VALUE 'CD_EBS',
      "! Cross-area objects of the suite: payment worklist, trace, transactions dashboard, purge targets
      core         TYPE zif_ca_ops_types=>ty_area VALUE 'CD_OPS',
    END OF gc_pe_area.

  "! ZCD_OPS_TABWL-PURPOSE: what the reader of the payment engine area does with an approved
  "! table (table consolidation 2026-11-08): FMON SOURCE, HCK READ / DRIFT
  TYPES ty_tabwl_purpose TYPE c LENGTH 10.
  CONSTANTS:
    BEGIN OF gc_tabwl_purpose,
      "! FMON dynamic reader (ZCD_FMON_SRC / _LOTCFG tables, payment trace sources; audit A51)
      source TYPE ty_tabwl_purpose VALUE 'SOURCE',
      "! HCK aggregates, value queries, queue and evidence sources (counts / references only)
      read   TYPE ty_tabwl_purpose VALUE 'READ',
      "! HCK configuration drift: the whole table is hashed against the golden baseline
      drift  TYPE ty_tabwl_purpose VALUE 'DRIFT',
      "! EBS lookup rule R21 (ZCD_EBS_LOOKUP): key and status fields only, field-level rows
      lookup TYPE ty_tabwl_purpose VALUE 'LOOKUP',
    END OF gc_tabwl_purpose.

  "! Classification of ZCX_CD_OPS_ERROR=>CLASSIFY (ZCL_CA_OPS_UTIL=>ERROR_CLASS): ZCD_OPS message
  "! numbers of lock / timeout and of configuration / authorisation failures (comma lists - extend them
  "! with every new message of the kind); the framework's own messages are in ZIF_CA_OPS_TYPES
  CONSTANTS:
    BEGIN OF gc_error_rule,
      transient_msgno TYPE string VALUE `313,335,369,763`,
      config_msgno    TYPE string VALUE `050,051,200,201,202,303,304,703,812,813`,
    END OF gc_error_rule.

  "! Logical paths / file names (transaction FILE) of the suite's application server files
  "! (ZCL_CA_OPS_FILE_PATH=>PHYSICAL); created in FILE as a setup step (Implementation_Order.md)
  CONSTANTS:
    BEGIN OF gc_logical_file,
      "! EBS validation: bank file read before import (ZCD_EBS_VALIDATE)
      BEGIN OF ebs_input,
        path TYPE pathintern VALUE 'ZCD_OPS_EBS_IN',
        file TYPE fileintern VALUE 'ZCD_OPS_EBS_IN',
      END OF ebs_input,
      "! Morning report: CSV export (ZCD_MORNING_REPORT)
      BEGIN OF hck_export,
        path TYPE pathintern VALUE 'ZCD_OPS_HCK_OUT',
        file TYPE fileintern VALUE 'ZCD_OPS_HCK_OUT',
      END OF hck_export,
    END OF gc_logical_file.

  "! Missing or late bank ACK (user request 2026-11-10): file monitoring writes the evidence of
  "! the file(s) into ZCA_OPS_FINDING-DETAILS as labelled lines ("<label>: <value>", one block per
  "! file, blocks separated by an empty line, the marker line first); the alert section
  "! ZCL_CD_OPS_ACK_MAIL reads the same labels back. Labels are ZCD_OPS messages (no variables).
  CONSTANTS:
    BEGIN OF gc_ack_msg,
      marker        TYPE zif_ca_ops_types=>ty_msgno VALUE '837',
      house_bank    TYPE zif_ca_ops_types=>ty_msgno VALUE '816',
      bank          TYPE zif_ca_ops_types=>ty_msgno VALUE '817',
      file_name     TYPE zif_ca_ops_types=>ty_msgno VALUE '818',
      iface         TYPE zif_ca_ops_types=>ty_msgno VALUE '819',
      pay_method    TYPE zif_ca_ops_types=>ty_msgno VALUE '820',
      payments      TYPE zif_ca_ops_types=>ty_msgno VALUE '821',
      amount        TYPE zif_ca_ops_types=>ty_msgno VALUE '822',
      pay_run       TYPE zif_ca_ops_types=>ty_msgno VALUE '823',
      business_date TYPE zif_ca_ops_types=>ty_msgno VALUE '824',
      generated     TYPE zif_ca_ops_types=>ty_msgno VALUE '825',
      sent          TYPE zif_ca_ops_types=>ty_msgno VALUE '826',
      delivered     TYPE zif_ca_ops_types=>ty_msgno VALUE '827',
      ack_due       TYPE zif_ca_ops_types=>ty_msgno VALUE '828',
      overdue       TYPE zif_ca_ops_types=>ty_msgno VALUE '829',
      ack_level     TYPE zif_ca_ops_types=>ty_msgno VALUE '830',
      earlier_file  TYPE zif_ca_ops_types=>ty_msgno VALUE '831',
      missed_stage  TYPE zif_ca_ops_types=>ty_msgno VALUE '832',
      "! Subject: Missing bank ACK: &1 file(s), &2 payments, &3
      subject       TYPE zif_ca_ops_types=>ty_msgno VALUE '833',
      total         TYPE zif_ca_ops_types=>ty_msgno VALUE '834',
      unknown       TYPE zif_ca_ops_types=>ty_msgno VALUE '835',
      "! &1 h &2 min
      hours_minutes TYPE zif_ca_ops_types=>ty_msgno VALUE '836',
    END OF gc_ack_msg.
  "! Between label and value of a detail line
  CONSTANTS gc_ack_label_separator TYPE string VALUE `: `.
  "! E-mail template of a message with missing / late bank ACK files when its rule names none
  "! (SAP e-mail template, ops-suite/templates/zcd_ops_alert_ack.md): the subject and the file
  "! table of ZCL_CD_OPS_ACK_MAIL are its SUBJECT and TABLE_SECTION
  CONSTANTS gc_ack_template TYPE zif_ca_ops_types=>ty_template_id VALUE 'ZCD_OPS_ALERT_ACK'.

  "! Message numbers (class ZCD_OPS) of this area's user-facing texts
  CONSTANTS:
    BEGIN OF gc_msg,
      pattern_invalid             TYPE zif_ca_ops_types=>ty_msgno VALUE '743',
      pattern_too_long            TYPE zif_ca_ops_types=>ty_msgno VALUE '744',
      "! Open exceptions of request &1 could not be read - record not saved (FMON handled-manually save)
      exc_open_read_failed        TYPE zif_ca_ops_types=>ty_msgno VALUE '788',
    END OF gc_msg.

ENDINTERFACE.
