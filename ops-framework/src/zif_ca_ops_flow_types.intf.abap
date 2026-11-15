*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_flow_types.intf.abap
*& Purpose:
*& Types and constants of the account flow reconciliation
*& (docs/ACCOUNT_FLOW.md): flows, accounts by role, posting stages, the
*& checks that control a stage, the ordered stage rules, the evaluation of
*& what existing checks account for in each closing position (header and
*& items), the plug-in source rows, configuration problems, parameters
*& (prefix FLOW_, area CA_OPS) and the messages 320-338 of ZCA_OPS. The
*& dashboard itself is CDS; read-only towards business data. No logic.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - account flow types</p>
INTERFACE zif_ca_ops_flow_types
  PUBLIC.

  TYPES ty_flow_id   TYPE c LENGTH 10.
  TYPES ty_flow_acct TYPE c LENGTH 20.
  TYPES ty_role      TYPE zca_ops_flow_role.
  TYPES ty_stage_id  TYPE c LENGTH 20.
  TYPES ty_rule_id   TYPE c LENGTH 20.
  TYPES ty_rule_seq  TYPE n LENGTH 4.
  TYPES ty_check_id  TYPE c LENGTH 35.
  TYPES ty_category  TYPE c LENGTH 10.
  TYPES ty_status    TYPE c LENGTH 1.
  TYPES ty_reason    TYPE c LENGTH 120.
  TYPES ty_text      TYPE c LENGTH 60.
  TYPES ty_ledger    TYPE c LENGTH 2.

  "! Roles of an account (column of the dashboard)
  CONSTANTS:
    BEGIN OF gc_role,
      receivable    TYPE ty_role VALUE 'RECEIVABLE',
      payable       TYPE ty_role VALUE 'PAYABLE',
      "! Outside the control chain (expense, revenue): shown, marked "no control point", never evaluated
      outside       TYPE ty_role VALUE 'OUTSIDE',
      settlement    TYPE ty_role VALUE 'SETTLEMENT',
      clearing      TYPE ty_role VALUE 'CLEARING',
      cash          TYPE ty_role VALUE 'CASH',
      clarification TYPE ty_role VALUE 'CLARIFICATION',
    END OF gc_role.

  "! Where the lines of an account (G) or of a rule (G / F) come from
  CONSTANTS:
    BEGIN OF gc_source,
      "! Journal lines (released view I_JournalEntryItem)
      journal TYPE c LENGTH 1 VALUE 'G',
      "! Lines of FI-CA documents (business partner items and G/L items of the subledger)
      fica    TYPE c LENGTH 1 VALUE 'F',
    END OF gc_source.

  "! A reserved row of the dashboard (domain ZCA_OPS_FLOW_ROW, texts of ZI_CA_OpsFlowRowT)
  TYPES ty_row       TYPE zca_ops_flow_row.
  "! Control tag of a stage (domain ZCA_OPS_FLOW_TAG, derived in ZI_CA_OpsFlowCube / ZI_CA_OpsFlowStgTag)
  TYPES ty_tag       TYPE zca_ops_flow_tag.
  "! Evaluation status of an account on the dashboard (domain ZCA_OPS_FLOW_EVST, derived in ZI_CA_OpsFlowPos)
  TYPES ty_eval_status TYPE zca_ops_flow_evst.

  "! Reserved rows of the dashboard (a stage may not be named so; a rule may name OTHER only)
  CONSTANTS:
    BEGIN OF gc_stage,
      other       TYPE ty_row VALUE 'OTHER',
      movement    TYPE ty_row VALUE 'MOVEMENT',
      opening     TYPE ty_row VALUE 'OPENING',
      closing     TYPE ty_row VALUE 'CLOSING',
      unexplained TYPE ty_row VALUE 'UNEXPLAINED',
    END OF gc_stage.

  "! Control tags (the dashboard derives them; documented here for the plug-ins and tests)
  CONSTANTS:
    BEGIN OF gc_tag,
      reconciled TYPE ty_tag VALUE 'R',
      open       TYPE ty_tag VALUE 'O',
      pending    TYPE ty_tag VALUE 'P',
      none       TYPE ty_tag VALUE 'N',
    END OF gc_tag.

  "! Evaluation status of an account on the dashboard
  CONSTANTS:
    BEGIN OF gc_eval_status,
      evaluated     TYPE ty_eval_status VALUE 'E',
      not_evaluated TYPE ty_eval_status VALUE 'N',
      no_control    TYPE ty_eval_status VALUE 'X',
    END OF gc_eval_status.

  "! Tile an evaluated account feeds (EVAL_CATEGORY)
  CONSTANTS:
    BEGIN OF gc_category,
      transit TYPE ty_category VALUE 'TRANSIT',
      clarify TYPE ty_category VALUE 'CLARIFY',
      open    TYPE ty_category VALUE 'OPEN',
      bank    TYPE ty_category VALUE 'BANK',
    END OF gc_category.

  "! Status of an evaluation item: what a source accounts for, or why it could not say
  CONSTANTS:
    BEGIN OF gc_item_status,
      evaluated     TYPE ty_status VALUE 'E',
      not_evaluated TYPE ty_status VALUE 'N',
    END OF gc_item_status.

  "! Sign rule of an evaluation item amount: blank = signed as the journal (debit +); B = an unsigned amount (a
  "! finding's amount) that takes the sign of the account's closing position
  CONSTANTS gc_sign_of_balance TYPE c LENGTH 1 VALUE 'B'.

  "! Status of an evaluation
  CONSTANTS:
    BEGIN OF gc_status,
      complete TYPE ty_status VALUE 'S',
      "! At least one account could not be evaluated (its items say why)
      partial  TYPE ty_status VALUE 'P',
    END OF gc_status.

  "! Rule criteria (configuration problems name them)
  CONSTANTS:
    BEGIN OF gc_criterion,
      ref_type   TYPE ty_text VALUE 'REF_TYPE',
      doc_type   TYPE ty_text VALUE 'DOC_TYPE',
      origin     TYPE ty_text VALUE 'ORIGIN',
      main_trans TYPE ty_text VALUE 'MAIN_TRANS',
      sub_trans  TYPE ty_text VALUE 'SUB_TRANS',
    END OF gc_criterion.

  "! Parameters of the account flow reconciliation (area CA_OPS, prefix FLOW_)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Ledger of the journal lines when the flow names none (read by the dashboard CDS and versioned) [0L]
      ledger    TYPE zif_ca_ops_types=>ty_param_name VALUE 'FLOW_LEDGER',
      "! Key date of the evaluation without one: today minus this many days [0]
      key_lag   TYPE zif_ca_ops_types=>ty_param_name VALUE 'FLOW_KEY_DATE_LAG',
      "! Evaluations older than this many days are removed by the next evaluation of the flow [400]
      retention TYPE zif_ca_ops_types=>ty_param_name VALUE 'FLOW_RETENTION_DAYS',
      "! A break analysis snapshot at most this many days before the key date accounts for a clearing account [2]
      break_age TYPE zif_ca_ops_types=>ty_param_name VALUE 'FLOW_BREAK_MAX_AGE_DAYS',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_default,
      ledger    TYPE zif_ca_ops_types=>ty_param_value VALUE '0L',
      key_lag   TYPE i VALUE 0,
      retention TYPE i VALUE 400,
      break_age TYPE i VALUE 2,
    END OF gc_default.

  "! Messages of ZCA_OPS (320-338; 340 is the configuration app's)
  CONSTANTS:
    BEGIN OF gc_msg,
      summary        TYPE zif_ca_ops_types=>ty_msgno VALUE '320',
      not_evaluated  TYPE zif_ca_ops_types=>ty_msgno VALUE '321',
      no_source      TYPE zif_ca_ops_types=>ty_msgno VALUE '322',
      process_off    TYPE zif_ca_ops_types=>ty_msgno VALUE '323',
      rule_stage     TYPE zif_ca_ops_types=>ty_msgno VALUE '324',
      rule_criterion TYPE zif_ca_ops_types=>ty_msgno VALUE '325',
      role_twice     TYPE zif_ca_ops_types=>ty_msgno VALUE '326',
      no_stage       TYPE zif_ca_ops_types=>ty_msgno VALUE '327',
      role_missing   TYPE zif_ca_ops_types=>ty_msgno VALUE '328',
      rule_open      TYPE zif_ca_ops_types=>ty_msgno VALUE '329',
      source_invalid TYPE zif_ca_ops_types=>ty_msgno VALUE '330',
      no_snapshot    TYPE zif_ca_ops_types=>ty_msgno VALUE '331',
      snap_partial   TYPE zif_ca_ops_types=>ty_msgno VALUE '332',
      no_check       TYPE zif_ca_ops_types=>ty_msgno VALUE '333',
      source_failed  TYPE zif_ca_ops_types=>ty_msgno VALUE '334',
      purged         TYPE zif_ca_ops_types=>ty_msgno VALUE '335',
      no_flow        TYPE zif_ca_ops_types=>ty_msgno VALUE '336',
      no_answer      TYPE zif_ca_ops_types=>ty_msgno VALUE '338',
    END OF gc_msg.

  "! Plug-in interface of a source (ZCA_OPS_FLWACC-EVAL_CLASS)
  CONSTANTS gc_source_interface TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_FLOW_SOURCE'.

  "! Kinds of the configuration version lines (ZCL_CA_OPS_CFG_VERSION)
  CONSTANTS:
    BEGIN OF gc_version_kind,
      flow    TYPE ty_text VALUE 'FLOW',
      account TYPE ty_text VALUE 'ACCOUNT',
      stage   TYPE ty_text VALUE 'STAGE',
      tile    TYPE ty_text VALUE 'TILE',
      control TYPE ty_text VALUE 'CONTROL',
      rule    TYPE ty_text VALUE 'RULE',
      param   TYPE ty_text VALUE 'PARAM',
    END OF gc_version_kind.

  "! An account flow (ZCA_OPS_FLOW)
  TYPES:
    BEGIN OF ty_flow,
      area        TYPE zif_ca_ops_types=>ty_area,
      flow_id     TYPE ty_flow_id,
      description TYPE ty_text,
      direction   TYPE c LENGTH 1,
      jrnl_ledger TYPE ty_ledger,
      process_id  TYPE c LENGTH 20,
      active      TYPE abap_bool,
    END OF ty_flow.
  TYPES tt_flow TYPE STANDARD TABLE OF ty_flow WITH EMPTY KEY.

  "! An account of a flow in its role (ZCA_OPS_FLWACC)
  TYPES:
    BEGIN OF ty_account,
      area          TYPE zif_ca_ops_types=>ty_area,
      flow_id       TYPE ty_flow_id,
      flow_acct     TYPE ty_flow_acct,
      role          TYPE ty_role,
      bukrs         TYPE bukrs,
      currency      TYPE zif_ca_ops_types=>ty_currency,
      hkont_from    TYPE saknr,
      hkont_to      TYPE saknr,
      line_source   TYPE c LENGTH 1,
      seq           TYPE i,
      eval_class    TYPE zif_ca_ops_types=>ty_class_name,
      eval_category TYPE ty_category,
      description   TYPE ty_text,
      active        TYPE abap_bool,
    END OF ty_account.
  TYPES tt_account TYPE STANDARD TABLE OF ty_account WITH EMPTY KEY.

  "! A posting stage of a flow (ZCA_OPS_FLWSTG)
  TYPES:
    BEGIN OF ty_stage,
      area        TYPE zif_ca_ops_types=>ty_area,
      flow_id     TYPE ty_flow_id,
      stage_id    TYPE ty_stage_id,
      seq         TYPE i,
      description TYPE ty_text,
      expect_from TYPE ty_role,
      expect_to   TYPE ty_role,
      active      TYPE abap_bool,
    END OF ty_stage.
  TYPES tt_stage TYPE STANDARD TABLE OF ty_stage WITH EMPTY KEY.

  "! A tile row (ZCA_OPS_FLWTIL): the debit (D) or credit (C) of a stage on the accounts of a role feeds a tile
  TYPES:
    BEGIN OF ty_tile,
      area        TYPE zif_ca_ops_types=>ty_area,
      flow_id     TYPE ty_flow_id,
      tile        TYPE c LENGTH 10,
      stage_id    TYPE ty_stage_id,
      role        TYPE ty_role,
      side        TYPE c LENGTH 1,
      description TYPE ty_text,
      active      TYPE abap_bool,
    END OF ty_tile.
  TYPES tt_tile TYPE STANDARD TABLE OF ty_tile WITH EMPTY KEY.

  "! A check that controls a stage (ZCA_OPS_FLWCTL)
  TYPES:
    BEGIN OF ty_control,
      area        TYPE zif_ca_ops_types=>ty_area,
      flow_id     TYPE ty_flow_id,
      stage_id    TYPE ty_stage_id,
      check_area  TYPE zif_ca_ops_types=>ty_area,
      check_id    TYPE ty_check_id,
      description TYPE ty_text,
      active      TYPE abap_bool,
    END OF ty_control.
  TYPES tt_control TYPE STANDARD TABLE OF ty_control WITH EMPTY KEY.

  "! A stage rule (ZCA_OPS_FLWRUL): the first by sequence whose filled criteria all hold gives a line its stage
  TYPES:
    BEGIN OF ty_rule,
      area         TYPE zif_ca_ops_types=>ty_area,
      flow_id      TYPE ty_flow_id,
      rule_seq     TYPE ty_rule_seq,
      rule_id      TYPE ty_rule_id,
      stage_id     TYPE ty_stage_id,
      line_source  TYPE c LENGTH 1,
      ref_type     TYPE c LENGTH 5,
      doc_type     TYPE c LENGTH 2,
      origin       TYPE c LENGTH 2,
      main_trans   TYPE c LENGTH 4,
      sub_trans    TYPE c LENGTH 4,
      debit_credit TYPE c LENGTH 1,
      description  TYPE ty_text,
      active       TYPE abap_bool,
    END OF ty_rule.
  TYPES tt_rule TYPE STANDARD TABLE OF ty_rule WITH EMPTY KEY.

  "! The configuration of one flow, read once per evaluation
  TYPES:
    BEGIN OF ty_config,
      flow     TYPE ty_flow,
      accounts TYPE tt_account,
      stages   TYPE tt_stage,
      tiles    TYPE tt_tile,
      controls TYPE tt_control,
      rules    TYPE tt_rule,
    END OF ty_config.

  "! A configuration problem (messages 324-329)
  TYPES:
    BEGIN OF ty_problem,
      msgno TYPE zif_ca_ops_types=>ty_msgno,
      v1    TYPE zif_ca_ops_types=>ty_msgv,
      v2    TYPE zif_ca_ops_types=>ty_msgv,
      v3    TYPE zif_ca_ops_types=>ty_msgv,
      v4    TYPE zif_ca_ops_types=>ty_msgv,
    END OF ty_problem.
  TYPES tt_problem TYPE STANDARD TABLE OF ty_problem WITH EMPTY KEY.

  "! What a source accounts for in one currency of an account (ZIF_CA_OPS_FLOW_SOURCE)
  TYPES:
    BEGIN OF ty_source_row,
      currency   TYPE zif_ca_ops_types=>ty_currency,
      "! Signed as the journal (debit +), or unsigned with SIGN_RULE = GC_SIGN_OF_BALANCE
      amount     TYPE zif_ca_ops_types=>ty_amount,
      item_count TYPE i,
      sign_rule  TYPE c LENGTH 1,
      "! E evaluated, N not evaluated (REASON says why)
      status     TYPE ty_status,
      reason     TYPE ty_reason,
    END OF ty_source_row.
  TYPES tt_source_row TYPE STANDARD TABLE OF ty_source_row WITH EMPTY KEY.

  "! An evaluation (ZCA_OPS_FLWEVL)
  TYPES:
    BEGIN OF ty_eval,
      eval_id       TYPE zif_ca_ops_types=>ty_run_id,
      area          TYPE zif_ca_ops_types=>ty_area,
      flow_id       TYPE ty_flow_id,
      key_date      TYPE d,
      status        TYPE ty_status,
      cfg_version   TYPE zif_ca_ops_types=>ty_cfg_version,
      acct_count    TYPE i,
      not_evaluated TYPE i,
      started_at    TYPE timestampl,
      ended_at      TYPE timestampl,
      created_by    TYPE syuname,
      message       TYPE c LENGTH 255,
    END OF ty_eval.

  "! An evaluation item (ZCA_OPS_FLWEVI)
  TYPES:
    BEGIN OF ty_eval_item,
      item_no      TYPE i,
      flow_acct    TYPE ty_flow_acct,
      role         TYPE ty_role,
      bukrs        TYPE bukrs,
      currency     TYPE zif_ca_ops_types=>ty_currency,
      category     TYPE ty_category,
      amount       TYPE zif_ca_ops_types=>ty_amount,
      item_count   TYPE i,
      sign_rule    TYPE c LENGTH 1,
      status       TYPE ty_status,
      source_class TYPE zif_ca_ops_types=>ty_class_name,
      reason       TYPE ty_reason,
    END OF ty_eval_item.
  TYPES tt_eval_item TYPE STANDARD TABLE OF ty_eval_item WITH EMPTY KEY.

  "! The result of one flow (report ZCA_OPS_FLOW_RUN)
  TYPES:
    BEGIN OF ty_result,
      eval     TYPE ty_eval,
      items    TYPE tt_eval_item,
      problems TYPE tt_problem,
      "! X = not evaluated (business process not in effect)
      skipped  TYPE abap_bool,
      "! Evaluations removed by the retention (FLOW_RETENTION_DAYS)
      purged   TYPE i,
    END OF ty_result.
  TYPES tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

  "! A check named by a stage control (area, check ID of the findings)
  TYPES:
    BEGIN OF ty_check_ref,
      check_area TYPE zif_ca_ops_types=>ty_area,
      check_id   TYPE ty_check_id,
    END OF ty_check_ref.
  TYPES tt_check_ref TYPE SORTED TABLE OF ty_check_ref WITH UNIQUE KEY check_area check_id.

  "! A break analysis snapshot that may account for a clearing account (ZCA_OPS_BRKRUN)
  TYPES:
    BEGIN OF ty_break_snap,
      snap_id  TYPE zif_ca_ops_types=>ty_run_id,
      acct_id  TYPE c LENGTH 20,
      hkont    TYPE saknr,
      key_date TYPE d,
      status   TYPE ty_status,
    END OF ty_break_snap.
  TYPES tt_break_snap TYPE STANDARD TABLE OF ty_break_snap WITH EMPTY KEY.

  "! An amount per currency read for a source (sum and number of items)
  TYPES:
    BEGIN OF ty_currency_sum,
      currency   TYPE zif_ca_ops_types=>ty_currency,
      amount     TYPE zif_ca_ops_types=>ty_amount,
      item_count TYPE i,
    END OF ty_currency_sum.
  TYPES tt_currency_sum TYPE STANDARD TABLE OF ty_currency_sum WITH EMPTY KEY.

  TYPES tt_run_id TYPE STANDARD TABLE OF zif_ca_ops_types=>ty_run_id WITH EMPTY KEY.

ENDINTERFACE.
