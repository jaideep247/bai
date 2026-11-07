*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_fixture.clas.abap
*& Purpose:
*& Shared negative fixtures of the canonical payment outcome (test support
*& only, like ZCL_CD_OPS_PARAM_SEED; never called by production code): one
*& definition of each scenario - configuration (method classes, rules,
*& bank code roles, sequence outcomes as delivered), DPAYH runs, statement
*& lines, returns lot items, request log rows, the open item and the
*& expected canonical outcome - used by every consumer's tests: the
*& evaluator, the morning report check A_INFLIGHT, the payment trace, the
*& 5-minute snapshot and the transactions dashboard CDS tests (rows of
*& DFKKOP / DPAYH / FEBEP / ZCD_PAY_OUTCOME for cl_cds_test_environment).
*& Same data, same expected outcome: the consumers agree. Dates relative to
*& the given day. Reads and writes nothing.
*& Modification log:
*& 2026-11-07 | Initial version (one canonical payment outcome model: shared negative fixtures).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - shared test fixtures</p>
"! Scenarios GC_SCENARIO: retrieval without return, bank line without clearing, two DPAYH runs,
"! FIN in two sources, SUCCESS older than 30 days; HISTORY: two versions of one payment.
CLASS zcl_cd_ops_pay_fixture DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_scenario_id TYPE c LENGTH 20.

    CONSTANTS:
      BEGIN OF gc_scenario,
        "! ACH disbursement 466 -> 166 (retrieved), no returns lot: RETRIEVED, never RETURNED
        retrieval   TYPE ty_scenario_id VALUE 'RETRIEVAL_NO_RETURN',
        "! Wire with its statement line (495) but DPAYH status not CLEARED: INCONSISTENT, not settled
        bank_line   TYPE ty_scenario_id VALUE 'LINE_NO_CLEARING',
        "! Wire paid in two runs (re-run): the latest run (run date, then run ID) decides
        two_runs    TYPE ty_scenario_id VALUE 'TWO_DPAYH_RUNS',
        "! Cleared wire whose FIN has SUCCESS rows in two sources: AMBIGUOUS, never one picked
        two_sources TYPE ty_scenario_id VALUE 'FIN_TWO_SOURCES',
        "! Cleared wire; request SUCCESS 40 days ago, failed retry today: still PROCESSED
        success_old TYPE ty_scenario_id VALUE 'SUCCESS_OLD',
      END OF gc_scenario.

    CONSTANTS gc_bukrs TYPE c LENGTH 4 VALUE 'US01'.
    CONSTANTS gc_country TYPE c LENGTH 3 VALUE 'US'.
    CONSTANTS gc_currency TYPE zif_cd_ops_types=>ty_currency VALUE 'USD'.
    CONSTANTS gc_amount TYPE zif_cd_ops_types=>ty_amount VALUE '-250.00'.
    CONSTANTS gc_wire TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'E'.
    CONSTANTS gc_ach TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'G'.
    CONSTANTS gc_scheme TYPE zif_cd_hck_runtime_types=>ty_scheme VALUE 'BAI2'.
    CONSTANTS gc_kukey TYPE n LENGTH 8 VALUE '00009001'.
    CONSTANTS:
      BEGIN OF gc_source,
        pclm TYPE zif_cd_ops_trace_types=>ty_source VALUE 'PCLM',
        orci TYPE zif_cd_ops_trace_types=>ty_source VALUE 'ORCI',
      END OF gc_source.
    CONSTANTS:
      BEGIN OF gc_request_status,
        success TYPE c LENGTH 20 VALUE 'SUCCESS',
        failed  TYPE c LENGTH 20 VALUE 'FAILED',
      END OF gc_request_status.
    CONSTANTS:
      BEGIN OF gc_pay_status,
        cleared TYPE c LENGTH 20 VALUE 'CLEARED',
        sent    TYPE c LENGTH 20 VALUE 'SENT',
      END OF gc_pay_status.

    "! One DPAYH row of the scenario's payment document
    TYPES:
      BEGIN OF ty_run,
        laufd  TYPE d,
        laufi  TYPE c LENGTH 6,
        status TYPE c LENGTH 20,
        valut  TYPE d,
      END OF ty_run.
    TYPES tt_run TYPE STANDARD TABLE OF ty_run WITH EMPTY KEY.

    "! One request log attempt (ZCD_PAYM_REQ_LOG; field names of the table are VERIFY-SE11)
    TYPES:
      BEGIN OF ty_request,
        fin          TYPE zif_cd_ops_trace_types=>ty_fin,
        source       TYPE zif_cd_ops_trace_types=>ty_source,
        counter      TYPE i,
        status       TYPE c LENGTH 20,
        request_date TYPE d,
      END OF ty_request.
    TYPES tt_request TYPE STANDARD TABLE OF ty_request WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_scenario,
        id               TYPE ty_scenario_id,
        fin              TYPE zif_cd_ops_trace_types=>ty_fin,
        "! Open item cleared by the payment (DFKKOP-OPBEL) and its posting date
        opbel            TYPE zif_cd_ops_trace_types=>ty_docno,
        budat            TYPE d,
        augbl            TYPE zif_cd_ops_trace_types=>ty_docno,
        pymet            TYPE zif_cd_hck_runtime_types=>ty_pymet,
        runs             TYPE tt_run,
        lines            TYPE zif_cd_ops_trace_types=>tt_bank_line,
        returns          TYPE zif_cd_ops_trace_types=>tt_return,
        requests         TYPE tt_request,
        "! Expected canonical outcome (and the run it is judged on)
        expected         TYPE zif_cd_ops_payout_types=>ty_outcome,
        expected_laufd   TYPE d,
        expected_laufi   TYPE c LENGTH 6,
        "! Outcome the evaluator gives before the source attribution (AMBIGUOUS scenarios)
        evaluated        TYPE zif_cd_ops_payout_types=>ty_outcome,
      END OF ty_scenario.
    TYPES tt_scenario TYPE STANDARD TABLE OF ty_scenario WITH EMPTY KEY.

    TYPES tt_dfkkop TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    TYPES tt_dpayh TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    TYPES tt_febep TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    TYPES tt_outcome_row TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.

    METHODS constructor
      IMPORTING
        iv_today TYPE d.

    METHODS scenarios
      RETURNING
        VALUE(rt_scenarios) TYPE tt_scenario.

    METHODS scenario
      IMPORTING
        iv_id              TYPE ty_scenario_id
      RETURNING
        VALUE(rs_scenario) TYPE ty_scenario.

    "! Method classes as delivered: D WIR (E), D ACH (G), value-date aged
    METHODS classes
      RETURNING
        VALUE(rt_classes) TYPE zif_cd_hck_runtime_types=>tt_pm_class.

    "! Rules as delivered (config/hck_seed.md section 8c): wire CLEARED = lifecycle CLEARED AND DPAYH
    "! status CLEARED, RETURNED = lifecycle RETURNED; ACH CLEARED = lifecycle CLEARED / RETRIEVAL_FAILED
    "! AND status CLEARED, RETURNED = lifecycle RETURNED, RETRIEVED = lifecycle RETRIEVED
    METHODS rules
      RETURNING
        VALUE(rt_rules) TYPE zif_cd_hck_runtime_types=>tt_clr_rule.

    "! Bank code roles of D WIR / D ACH (BAI2)
    METHODS roles
      RETURNING
        VALUE(rt_roles) TYPE zif_cd_hck_runtime_types=>tt_btc_role.

    "! Sequence outcomes of D WIR / D ACH
    METHODS outcomes
      RETURNING
        VALUE(rt_outcomes) TYPE zif_cd_hck_runtime_types=>tt_seq_outcome.

    "! DPAYH rows of the scenario as the runtime DAO returns them (flow and class not set)
    METHODS issued_payments
      IMPORTING
        is_scenario        TYPE ty_scenario
      RETURNING
        VALUE(rt_payments) TYPE zif_cd_hck_runtime_types=>tt_issued_payment.

    "! DPAYH status rows as the trace repository returns them (newest run first)
    METHODS payment_runs
      IMPORTING
        is_scenario    TYPE ty_scenario
      RETURNING
        VALUE(rt_runs) TYPE zif_cd_ops_trace_types=>tt_payment_run.

    "! The open item of the scenario as the trace repository returns it
    METHODS item
      IMPORTING
        is_scenario    TYPE ty_scenario
      RETURNING
        VALUE(rs_item) TYPE zif_cd_ops_trace_types=>ty_item.

    "! Database rows for the CDS test environment
    METHODS dfkkop_rows
      IMPORTING
        is_scenario    TYPE ty_scenario
      RETURNING
        VALUE(rt_rows) TYPE tt_dfkkop.

    METHODS dpayh_rows
      IMPORTING
        is_scenario    TYPE ty_scenario
      RETURNING
        VALUE(rt_rows) TYPE tt_dpayh.

    METHODS febep_rows
      IMPORTING
        is_scenario    TYPE ty_scenario
      RETURNING
        VALUE(rt_rows) TYPE tt_febep.

    "! The current version the snapshot writes for each source of the FIN (expected outcome)
    METHODS outcome_rows
      IMPORTING
        is_scenario    TYPE ty_scenario
        iv_valid_from  TYPE zif_cd_ops_payout_types=>ty_timestamp
      RETURNING
        VALUE(rt_rows) TYPE tt_outcome_row.

    "! Two versions of the cleared wire of TWO_DPAYH_RUNS: IN_FLIGHT from iv_first, CLEARED from
    "! iv_second (the first closed at iv_second)
    METHODS history
      IMPORTING
        iv_first       TYPE zif_cd_ops_payout_types=>ty_timestamp
        iv_second      TYPE zif_cd_ops_payout_types=>ty_timestamp
      RETURNING
        VALUE(rt_rows) TYPE tt_outcome_row.

  PRIVATE SECTION.
    "! Fixture data (declarations: the only place values belong)
    CONSTANTS:
      BEGIN OF gc_fin,
        retrieval   TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009001',
        bank_line   TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009002',
        two_runs    TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009003',
        two_sources TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009004',
        success_old TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009005',
      END OF gc_fin.
    CONSTANTS:
      BEGIN OF gc_opbel,
        retrieval   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '100000009001',
        bank_line   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '100000009002',
        two_runs    TYPE zif_cd_ops_trace_types=>ty_docno VALUE '100000009003',
        two_sources TYPE zif_cd_ops_trace_types=>ty_docno VALUE '100000009004',
        success_old TYPE zif_cd_ops_trace_types=>ty_docno VALUE '100000009005',
      END OF gc_opbel.
    CONSTANTS:
      BEGIN OF gc_augbl,
        retrieval   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000900001',
        bank_line   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000900002',
        two_runs    TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000900003',
        two_sources TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000900004',
        success_old TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000900005',
      END OF gc_augbl.
    CONSTANTS:
      BEGIN OF gc_btc,
        wire_original TYPE zif_cd_hck_runtime_types=>ty_btc_code VALUE '495',
        wire_returned TYPE zif_cd_hck_runtime_types=>ty_btc_code VALUE '195',
        ach_original  TYPE zif_cd_hck_runtime_types=>ty_btc_code VALUE '466',
        ach_returned  TYPE zif_cd_hck_runtime_types=>ty_btc_code VALUE '168',
        ach_retrieved TYPE zif_cd_hck_runtime_types=>ty_btc_code VALUE '166',
      END OF gc_btc.
    CONSTANTS:
      BEGIN OF gc_role,
        original  TYPE zif_cd_hck_runtime_types=>ty_btc_role VALUE 'ORIGINAL',
        returned  TYPE zif_cd_hck_runtime_types=>ty_btc_role VALUE 'RETURNED',
        retrieved TYPE zif_cd_hck_runtime_types=>ty_btc_role VALUE 'RETRIEVED',
      END OF gc_role.
    CONSTANTS:
      BEGIN OF gc_pattern,
        original  TYPE zif_cd_hck_runtime_types=>ty_seq_pattern VALUE 'ORIGINAL',
        returned  TYPE zif_cd_hck_runtime_types=>ty_seq_pattern VALUE 'ORIGINAL,RETURNED',
        retrieved TYPE zif_cd_hck_runtime_types=>ty_seq_pattern VALUE 'ORIGINAL,RETRIEVED',
      END OF gc_pattern.
    CONSTANTS:
      BEGIN OF gc_run,
        ach  TYPE c LENGTH 6 VALUE 'ACH001',
        wire TYPE c LENGTH 6 VALUE 'WIR001',
        rerun TYPE c LENGTH 6 VALUE 'WIR002',
      END OF gc_run.
    CONSTANTS:
      BEGIN OF gc_class,
        wire TYPE zif_cd_hck_runtime_types=>ty_method_class VALUE 'WIR',
        ach  TYPE zif_cd_hck_runtime_types=>ty_method_class VALUE 'ACH',
      END OF gc_class.
    CONSTANTS:
      BEGIN OF gc_seq,
        first  TYPE zif_cd_hck_runtime_types=>ty_rule_seq VALUE '010',
        second TYPE zif_cd_hck_runtime_types=>ty_rule_seq VALUE '020',
        third  TYPE zif_cd_hck_runtime_types=>ty_rule_seq VALUE '030',
      END OF gc_seq.
    CONSTANTS:
      BEGIN OF gc_lot_items,
        none TYPE c LENGTH 1 VALUE '0',
        one  TYPE c LENGTH 1 VALUE '1',
      END OF gc_lot_items.
    "! ACH lifecycle outcomes that clear (retrieval failed = the payment stays paid)
    CONSTANTS gc_ach_cleared TYPE zif_cd_hck_runtime_types=>ty_rule_param VALUE 'CLEARED,RETRIEVAL_FAILED'.

    DATA mv_today TYPE d.
    DATA mt_scenarios TYPE tt_scenario.

    METHODS build.

    METHODS add_line
      IMPORTING
        iv_doc   TYPE zif_cd_ops_trace_types=>ty_docno
        iv_code  TYPE clike
        iv_days  TYPE i
        iv_esnum TYPE i
      CHANGING
        cs_scenario TYPE ty_scenario.

    METHODS add_run
      IMPORTING
        iv_days   TYPE i
        iv_laufi  TYPE clike
        iv_status TYPE clike
      CHANGING
        cs_scenario TYPE ty_scenario.

    METHODS add_request
      IMPORTING
        iv_source  TYPE zif_cd_ops_trace_types=>ty_source
        iv_counter TYPE i DEFAULT 1
        iv_status  TYPE clike DEFAULT gc_request_status-success
        iv_days    TYPE i
      CHANGING
        cs_scenario TYPE ty_scenario.

ENDCLASS.



CLASS zcl_cd_ops_pay_fixture IMPLEMENTATION.

  METHOD constructor.
    mv_today = iv_today.
    build( ).
  ENDMETHOD.


  METHOD scenarios.
    rt_scenarios = mt_scenarios.
  ENDMETHOD.


  METHOD scenario.
    rs_scenario = VALUE #( mt_scenarios[ id = iv_id ] OPTIONAL ).
  ENDMETHOD.


  METHOD build.
    DATA ls_scenario TYPE ty_scenario.

    " Retrieval without return: 466 then 166 on the ACH payment, no returns lot item
    ls_scenario-id     = gc_scenario-retrieval.
    ls_scenario-fin    = gc_fin-retrieval.
    ls_scenario-opbel  = gc_opbel-retrieval.
    ls_scenario-augbl  = gc_augbl-retrieval.
    ls_scenario-pymet  = gc_ach.
    ls_scenario-budat  = mv_today - 4.
    add_run( EXPORTING iv_days = 3 iv_laufi = gc_run-ach iv_status = gc_pay_status-cleared CHANGING cs_scenario = ls_scenario ).
    add_line( EXPORTING iv_doc = ls_scenario-augbl iv_code = gc_btc-ach_original iv_days = 3 iv_esnum = 1
              CHANGING  cs_scenario = ls_scenario ).
    add_line( EXPORTING iv_doc = ls_scenario-augbl iv_code = gc_btc-ach_retrieved iv_days = 1 iv_esnum = 2
              CHANGING  cs_scenario = ls_scenario ).
    add_request( EXPORTING iv_source = gc_source-pclm iv_days = 4 CHANGING cs_scenario = ls_scenario ).
    ls_scenario-expected = zif_cd_ops_payout_types=>gc_outcome-retrieved.
    INSERT ls_scenario INTO TABLE mt_scenarios.

    " Bank line without clearing: the wire is on the statement, DPAYH status not CLEARED
    CLEAR ls_scenario.
    ls_scenario-id     = gc_scenario-bank_line.
    ls_scenario-fin    = gc_fin-bank_line.
    ls_scenario-opbel  = gc_opbel-bank_line.
    ls_scenario-augbl  = gc_augbl-bank_line.
    ls_scenario-pymet  = gc_wire.
    ls_scenario-budat  = mv_today - 3.
    add_run( EXPORTING iv_days = 2 iv_laufi = gc_run-wire iv_status = gc_pay_status-sent CHANGING cs_scenario = ls_scenario ).
    add_line( EXPORTING iv_doc = ls_scenario-augbl iv_code = gc_btc-wire_original iv_days = 1 iv_esnum = 3
              CHANGING  cs_scenario = ls_scenario ).
    add_request( EXPORTING iv_source = gc_source-pclm iv_days = 3 CHANGING cs_scenario = ls_scenario ).
    ls_scenario-expected = zif_cd_ops_payout_types=>gc_outcome-inconsistent.
    INSERT ls_scenario INTO TABLE mt_scenarios.

    " Two DPAYH runs of one document: the older SENT, the newer CLEARED
    CLEAR ls_scenario.
    ls_scenario-id     = gc_scenario-two_runs.
    ls_scenario-fin    = gc_fin-two_runs.
    ls_scenario-opbel  = gc_opbel-two_runs.
    ls_scenario-augbl  = gc_augbl-two_runs.
    ls_scenario-pymet  = gc_wire.
    ls_scenario-budat  = mv_today - 6.
    add_run( EXPORTING iv_days = 5 iv_laufi = gc_run-wire iv_status = gc_pay_status-sent CHANGING cs_scenario = ls_scenario ).
    add_run( EXPORTING iv_days = 2 iv_laufi = gc_run-rerun iv_status = gc_pay_status-cleared CHANGING cs_scenario = ls_scenario ).
    add_line( EXPORTING iv_doc = ls_scenario-augbl iv_code = gc_btc-wire_original iv_days = 1 iv_esnum = 4
              CHANGING  cs_scenario = ls_scenario ).
    add_request( EXPORTING iv_source = gc_source-pclm iv_days = 6 CHANGING cs_scenario = ls_scenario ).
    ls_scenario-expected = zif_cd_ops_payout_types=>gc_outcome-cleared.
    INSERT ls_scenario INTO TABLE mt_scenarios.

    " FIN in two sources: SUCCESS in PCLM and in ORCI
    CLEAR ls_scenario.
    ls_scenario-id     = gc_scenario-two_sources.
    ls_scenario-fin    = gc_fin-two_sources.
    ls_scenario-opbel  = gc_opbel-two_sources.
    ls_scenario-augbl  = gc_augbl-two_sources.
    ls_scenario-pymet  = gc_wire.
    ls_scenario-budat  = mv_today - 3.
    add_run( EXPORTING iv_days = 2 iv_laufi = gc_run-wire iv_status = gc_pay_status-cleared CHANGING cs_scenario = ls_scenario ).
    add_line( EXPORTING iv_doc = ls_scenario-augbl iv_code = gc_btc-wire_original iv_days = 1 iv_esnum = 5
              CHANGING  cs_scenario = ls_scenario ).
    add_request( EXPORTING iv_source = gc_source-pclm iv_days = 3 CHANGING cs_scenario = ls_scenario ).
    add_request( EXPORTING iv_source = gc_source-orci iv_days = 3 CHANGING cs_scenario = ls_scenario ).
    ls_scenario-expected  = zif_cd_ops_payout_types=>gc_outcome-ambiguous.
    ls_scenario-evaluated = zif_cd_ops_payout_types=>gc_outcome-cleared.
    INSERT ls_scenario INTO TABLE mt_scenarios.

    " SUCCESS 40 days ago, a failed retry today (counter 2): processed, the payment cleared
    CLEAR ls_scenario.
    ls_scenario-id     = gc_scenario-success_old.
    ls_scenario-fin    = gc_fin-success_old.
    ls_scenario-opbel  = gc_opbel-success_old.
    ls_scenario-augbl  = gc_augbl-success_old.
    ls_scenario-pymet  = gc_wire.
    ls_scenario-budat  = mv_today - 3.
    add_run( EXPORTING iv_days = 2 iv_laufi = gc_run-wire iv_status = gc_pay_status-cleared CHANGING cs_scenario = ls_scenario ).
    add_line( EXPORTING iv_doc = ls_scenario-augbl iv_code = gc_btc-wire_original iv_days = 1 iv_esnum = 6
              CHANGING  cs_scenario = ls_scenario ).
    add_request( EXPORTING iv_source = gc_source-pclm iv_days = 40 CHANGING cs_scenario = ls_scenario ).
    add_request( EXPORTING iv_source  = gc_source-pclm
                           iv_counter = 2
                           iv_status  = gc_request_status-failed
                           iv_days    = 0
                 CHANGING  cs_scenario = ls_scenario ).
    ls_scenario-expected = zif_cd_ops_payout_types=>gc_outcome-cleared.
    INSERT ls_scenario INTO TABLE mt_scenarios.

    " The run judged: the latest one (run date, then run ID)
    LOOP AT mt_scenarios ASSIGNING FIELD-SYMBOL(<ls_scenario>).
      DATA(lt_runs) = <ls_scenario>-runs.
      SORT lt_runs BY laufd DESCENDING laufi DESCENDING.
      <ls_scenario>-expected_laufd = lt_runs[ 1 ]-laufd.
      <ls_scenario>-expected_laufi = lt_runs[ 1 ]-laufi.
      IF <ls_scenario>-evaluated IS INITIAL.
        <ls_scenario>-evaluated = <ls_scenario>-expected.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_run.
    DATA ls_run TYPE ty_run.
    ls_run-laufd  = mv_today - iv_days.
    ls_run-laufi  = iv_laufi.
    ls_run-status = iv_status.
    ls_run-valut  = mv_today - iv_days.
    INSERT ls_run INTO TABLE cs_scenario-runs.
  ENDMETHOD.


  METHOD add_line.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    ls_line-kukey = gc_kukey.
    ls_line-esnum = iv_esnum.
    ls_line-chect = iv_doc.
    ls_line-vorgc = iv_code.
    ls_line-budat = mv_today - iv_days.
    ls_line-kwbtr = gc_amount.
    ls_line-bukrs = gc_bukrs.
    INSERT ls_line INTO TABLE cs_scenario-lines.
  ENDMETHOD.


  METHOD add_request.
    DATA ls_request TYPE ty_request.
    ls_request-fin          = cs_scenario-fin.
    ls_request-source       = iv_source.
    ls_request-counter      = iv_counter.
    ls_request-status       = iv_status.
    ls_request-request_date = mv_today - iv_days.
    INSERT ls_request INTO TABLE cs_scenario-requests.
  ENDMETHOD.


  METHOD classes.
    DATA ls_class TYPE zif_cd_hck_runtime_types=>ty_pm_class.
    ls_class-flow         = zif_cd_hck_runtime_types=>gc_flow-disbursement.
    ls_class-age_basis    = zif_cd_hck_runtime_types=>gc_age_basis-value_date.
    ls_class-method_class = gc_class-wire.
    ls_class-pay_methods  = gc_wire.
    INSERT ls_class INTO TABLE rt_classes.
    ls_class-method_class = gc_class-ach.
    ls_class-pay_methods  = gc_ach.
    INSERT ls_class INTO TABLE rt_classes.
  ENDMETHOD.


  METHOD rules.
    DATA ls_rule TYPE zif_cd_hck_runtime_types=>ty_clr_rule.
    ls_rule-flow     = zif_cd_hck_runtime_types=>gc_flow-disbursement.
    ls_rule-required = zif_cd_hck_runtime_types=>gc_required-must_hold.
    " Rule 1: wire cleared = bank code lifecycle CLEARED (495) AND DPAYH status CLEARED; returned (195)
    ls_rule-method_class   = gc_class-wire.
    ls_rule-purpose        = zif_cd_hck_runtime_types=>gc_purpose-cleared.
    ls_rule-seq            = gc_seq-first.
    ls_rule-evidence_class = 'ZCL_CD_HCK_EV_BTC_SEQ'.
    ls_rule-param1         = zif_cd_hck_runtime_types=>gc_outcome-cleared.
    INSERT ls_rule INTO TABLE rt_rules.
    ls_rule-seq            = gc_seq-second.
    ls_rule-evidence_class = 'ZCL_CD_HCK_EV_PAY_STATUS'.
    ls_rule-param1         = gc_pay_status-cleared.
    INSERT ls_rule INTO TABLE rt_rules.
    ls_rule-purpose        = zif_cd_hck_runtime_types=>gc_purpose-returned.
    ls_rule-seq            = gc_seq-first.
    ls_rule-evidence_class = 'ZCL_CD_HCK_EV_BTC_SEQ'.
    ls_rule-param1         = zif_cd_hck_runtime_types=>gc_outcome-returned.
    INSERT ls_rule INTO TABLE rt_rules.
    " ACH: lifecycle CLEARED AND status CLEARED; RETURNED and RETRIEVED by the lifecycle
    ls_rule-method_class   = gc_class-ach.
    ls_rule-seq            = gc_seq-first.
    ls_rule-evidence_class = 'ZCL_CD_HCK_EV_BTC_SEQ'.
    ls_rule-param1         = gc_ach_cleared.
    INSERT ls_rule INTO TABLE rt_rules.
    ls_rule-seq            = gc_seq-second.
    ls_rule-evidence_class = 'ZCL_CD_HCK_EV_PAY_STATUS'.
    ls_rule-param1         = gc_pay_status-cleared.
    INSERT ls_rule INTO TABLE rt_rules.
    ls_rule-purpose        = zif_cd_hck_runtime_types=>gc_purpose-returned.
    ls_rule-seq            = gc_seq-first.
    ls_rule-evidence_class = 'ZCL_CD_HCK_EV_BTC_SEQ'.
    ls_rule-param1         = zif_cd_hck_runtime_types=>gc_outcome-returned.
    INSERT ls_rule INTO TABLE rt_rules.
    ls_rule-purpose        = zif_cd_hck_runtime_types=>gc_purpose-retrieved.
    ls_rule-param1         = zif_cd_hck_runtime_types=>gc_outcome-retrieved.
    INSERT ls_rule INTO TABLE rt_rules.
  ENDMETHOD.


  METHOD roles.
    DATA ls_role TYPE zif_cd_hck_runtime_types=>ty_btc_role_row.
    ls_role-flow   = zif_cd_hck_runtime_types=>gc_flow-disbursement.
    ls_role-scheme = gc_scheme.
    ls_role-method_class = gc_class-wire.
    ls_role-btc_code     = gc_btc-wire_original.
    ls_role-role         = gc_role-original.
    INSERT ls_role INTO TABLE rt_roles.
    ls_role-btc_code       = gc_btc-wire_returned.
    ls_role-role           = gc_role-returned.
    ls_role-compare_amount = zif_cd_hck_runtime_types=>gc_compare-returns_lot.
    INSERT ls_role INTO TABLE rt_roles.
    ls_role-btc_code       = gc_btc-wire_original.
    ls_role-role           = gc_role-original.
    ls_role-compare_amount = space.
    ls_role-method_class = gc_class-ach.
    ls_role-btc_code     = gc_btc-ach_original.
    INSERT ls_role INTO TABLE rt_roles.
    ls_role-btc_code       = gc_btc-ach_returned.
    ls_role-role           = gc_role-returned.
    ls_role-compare_amount = zif_cd_hck_runtime_types=>gc_compare-returns_lot.
    INSERT ls_role INTO TABLE rt_roles.
    ls_role-btc_code       = gc_btc-ach_retrieved.
    ls_role-role           = gc_role-retrieved.
    ls_role-compare_amount = space.
    INSERT ls_role INTO TABLE rt_roles.
  ENDMETHOD.


  METHOD outcomes.
    DATA ls_outcome TYPE zif_cd_hck_runtime_types=>ty_seq_outcome.
    ls_outcome-flow = zif_cd_hck_runtime_types=>gc_flow-disbursement.
    " Wire: ORIGINAL -> CLEARED, ORIGINAL,RETURNED -> RETURNED (one returns lot item); no redeposit
    ls_outcome-method_class    = gc_class-wire.
    ls_outcome-seq             = gc_seq-first.
    ls_outcome-seq_pattern     = gc_pattern-original.
    ls_outcome-outcome         = zif_cd_hck_runtime_types=>gc_outcome-cleared.
    ls_outcome-expected_dfkkrp = gc_lot_items-none.
    INSERT ls_outcome INTO TABLE rt_outcomes.
    ls_outcome-seq             = gc_seq-second.
    ls_outcome-seq_pattern     = gc_pattern-returned.
    ls_outcome-outcome         = zif_cd_hck_runtime_types=>gc_outcome-returned.
    ls_outcome-expected_dfkkrp = gc_lot_items-one.
    INSERT ls_outcome INTO TABLE rt_outcomes.
    " ACH: ORIGINAL -> CLEARED, ORIGINAL,RETURNED -> RETURNED, ORIGINAL,RETRIEVED -> RETRIEVED
    ls_outcome-method_class    = gc_class-ach.
    ls_outcome-seq             = gc_seq-first.
    ls_outcome-seq_pattern     = gc_pattern-original.
    ls_outcome-outcome         = zif_cd_hck_runtime_types=>gc_outcome-cleared.
    ls_outcome-expected_dfkkrp = gc_lot_items-none.
    INSERT ls_outcome INTO TABLE rt_outcomes.
    ls_outcome-seq             = gc_seq-second.
    ls_outcome-seq_pattern     = gc_pattern-returned.
    ls_outcome-outcome         = zif_cd_hck_runtime_types=>gc_outcome-returned.
    ls_outcome-expected_dfkkrp = gc_lot_items-one.
    INSERT ls_outcome INTO TABLE rt_outcomes.
    ls_outcome-seq             = gc_seq-third.
    ls_outcome-seq_pattern     = gc_pattern-retrieved.
    ls_outcome-outcome         = zif_cd_hck_runtime_types=>gc_outcome-retrieved.
    ls_outcome-expected_dfkkrp = gc_lot_items-none.
    INSERT ls_outcome INTO TABLE rt_outcomes.
  ENDMETHOD.


  METHOD issued_payments.
    DATA ls_payment TYPE zif_cd_hck_runtime_types=>ty_issued_payment.
    LOOP AT is_scenario-runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      CLEAR ls_payment.
      ls_payment-doc1r    = is_scenario-augbl.
      ls_payment-laufd    = <ls_run>-laufd.
      ls_payment-laufi    = <ls_run>-laufi.
      ls_payment-bukrs    = gc_bukrs.
      ls_payment-pymet    = is_scenario-pymet.
      ls_payment-valut    = <ls_run>-valut.
      ls_payment-amount   = gc_amount.
      ls_payment-currency = gc_currency.
      INSERT ls_payment INTO TABLE rt_payments.
    ENDLOOP.
  ENDMETHOD.


  METHOD payment_runs.
    DATA ls_run TYPE zif_cd_ops_trace_types=>ty_payment_run.
    DATA(lt_runs) = is_scenario-runs.
    SORT lt_runs BY laufd DESCENDING laufi DESCENDING.
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      ls_run-doc1r  = is_scenario-augbl.
      ls_run-laufd  = <ls_run>-laufd.
      ls_run-laufi  = <ls_run>-laufi.
      ls_run-status = <ls_run>-status.
      INSERT ls_run INTO TABLE rt_runs.
    ENDLOOP.
  ENDMETHOD.


  METHOD item.
    rs_item-opbel = is_scenario-opbel.
    rs_item-bukrs = gc_bukrs.
    rs_item-betrh = gc_amount.
    rs_item-waers = gc_currency.
    rs_item-budat = is_scenario-budat.
    rs_item-pymet = is_scenario-pymet.
    rs_item-augbl = is_scenario-augbl.
    rs_item-augdt = is_scenario-expected_laufd.
    rs_item-fin   = is_scenario-fin.
  ENDMETHOD.


  METHOD dfkkop_rows.
    DATA ls_row TYPE dfkkop.
    ls_row-opbel            = is_scenario-opbel.
    ls_row-bukrs            = gc_bukrs.
    ls_row-budat            = is_scenario-budat.
    ls_row-waers            = gc_currency.
    ls_row-pymet            = is_scenario-pymet.
    ls_row-augbl            = is_scenario-augbl.
    ls_row-augdt            = is_scenario-expected_laufd.
    ls_row-zz_fin_trans_num = is_scenario-fin.
    INSERT ls_row INTO TABLE rt_rows.
  ENDMETHOD.


  METHOD dpayh_rows.
    DATA ls_row TYPE dpayh.
    LOOP AT is_scenario-runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      CLEAR ls_row.
      ls_row-laufd             = <ls_run>-laufd.
      ls_row-laufi             = <ls_run>-laufi.
      ls_row-doc1r             = is_scenario-augbl.
      ls_row-valut             = <ls_run>-valut.
      ls_row-zz_payment_status = <ls_run>-status.
      INSERT ls_row INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD febep_rows.
    DATA ls_row TYPE febep.
    LOOP AT is_scenario-lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      CLEAR ls_row.
      ls_row-kukey = <ls_line>-kukey.
      ls_row-esnum = <ls_line>-esnum.
      ls_row-chect = <ls_line>-chect.
      ls_row-budat = <ls_line>-budat.
      ls_row-vorgc = <ls_line>-vorgc.
      INSERT ls_row INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD outcome_rows.
    DATA ls_row TYPE zcd_pay_outcome.
    DATA lt_sources TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_source WITH UNIQUE KEY table_line.
    LOOP AT is_scenario-requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      INSERT <ls_request>-source INTO TABLE lt_sources.
    ENDLOOP.
    LOOP AT lt_sources ASSIGNING FIELD-SYMBOL(<lv_source>).
      CLEAR ls_row.
      ls_row-fin_id       = is_scenario-fin.
      ls_row-source       = <lv_source>.
      ls_row-bukrs        = gc_bukrs.
      ls_row-augbl        = is_scenario-augbl.
      ls_row-laufd        = is_scenario-expected_laufd.
      ls_row-laufi        = is_scenario-expected_laufi.
      ls_row-valid_from   = iv_valid_from.
      ls_row-valid_to     = zif_cd_ops_payout_types=>gc_valid_to_open.
      ls_row-outcome      = is_scenario-expected.
      ls_row-evaluated_at = iv_valid_from.
      IF is_scenario-expected = zif_cd_ops_payout_types=>gc_outcome-ambiguous.
        ls_row-finding = zif_cd_ops_payout_types=>gc_code-source_ambiguous.
      ENDIF.
      INSERT ls_row INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD history.
    DATA(ls_scenario) = scenario( gc_scenario-two_runs ).
    DATA(lt_current) = outcome_rows( is_scenario = ls_scenario iv_valid_from = iv_second ).
    DATA(ls_first) = lt_current[ 1 ].
    ls_first-valid_from   = iv_first.
    ls_first-valid_to     = iv_second.
    ls_first-outcome      = zif_cd_ops_payout_types=>gc_outcome-in_flight.
    ls_first-evaluated_at = iv_first.
    INSERT ls_first INTO TABLE rt_rows.
    INSERT LINES OF lt_current INTO TABLE rt_rows.
  ENDMETHOD.

ENDCLASS.
