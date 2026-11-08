*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_inflight.clas.testclasses.abap
*& Purpose:
*& Unit tests of the in-flight check: ageing (business days after the
*& value date with class / house-bank / check calendar, missing value
*& date, issue-date classes in calendar days), flows and classes from
*& configuration (a new class by rows only), the rule combination (all
*& rows hold = excluded, some = inconsistent, none = open, must-not-hold,
*& purpose order, anomalies, unusable or unconfigured kinds, one collect
*& per kind) and the user rules 1-4 end to end with the delivered
*& evidence plug-ins (wire / ACH status and line, cheque B / V / blank,
*& collection BSEG XREF2, ACH return with and without returns lot, Stripe
*& not configured). Runtime DAO, payment trace repository, HCK DAO, clock
*& and test evidence kinds are doubles from the injectors, parameters the
*& delivered in-memory definitions; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (payments in flight, both flows, value date).
*& 2026-11-07 | Rules and evidence plug-ins, configured classes and calendars (user rules 1-5).
*& 2026-11-07 | Design review: mandatory rows (X / C / N) not configured or not usable leave the
*&            | purpose undetermined (no CLEARED on the indicator alone, no later purpose);
*&            | informational rows skipped; Stripe rows as seeded (C) and the explicit switch (blank);
*&            | test cheques and statement lines carry the house bank account (cheque link).
*& 2026-11-07 | Code review: every anomaly of an evidence is listed (every_anomaly_listed).
*& 2026-11-07 | Canonical payment outcome: the shared fixtures (ZCL_CD_OPS_PAY_FIXTURE) through the
*&            | check - retrieval excluded as RETRIEVED (not RETURNED), bank line without clearing
*&            | CLEARING_INCONSISTENT, two DPAYH runs cleared, every fixture as the evaluator says.
*& 2026-11-08 | Confirmed DPAYH status values: fixture wire returned excluded as RETURNED, the return whose
*&            | status is not updated yet stays in flight (aged, not listed), cheques voided / stopped
*&            | excluded as VOIDED, stopped cheque cashed CLEARING_INCONSISTENT "stopped cheque cashed".
*& 2026-11-08 | PAY_STATUS_LAG: bank evidence decides but the status lags beyond the grace (one finding per
*&            | payment, metric), within the grace silent, bank ACK older than the grace while ISSUED,
*&            | ACK source not configured (information, nothing judged).
*& 2026-11-08 | Status lag after a file-level ACK (collections, HCK_PAY_ACK_FILE_CLASSES): the FMON file of
*&            | the payment run (generation group LAUFD/LAUFI/HBKID of the source REGUT, FMON repository
*&            | double) acknowledged after the grace while ISSUED, within the grace, status CONFIRMED,
*&            | replaced failed file ignored and the regenerated file's ACK used, GROUP_FIELDS not
*&            | configured (one W, no lag, no read), two payment runs with separate files, payment-level
*&            | and file-level classes in one run.
*& 2026-11-08 | Table consolidation: runtime DAO double without get_evidence_settings (Stripe settings are
*&            | ZCA_PARAM parameters HCK_STRIPE_*, delivered blank = not configured).
*&---------------------------------------------------------------------*
CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    DATA mt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA mt_classes TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    DATA mt_banks TYPE zif_cd_hck_runtime_types=>tt_pm_bank.
    DATA mt_rules TYPE zif_cd_hck_runtime_types=>tt_clr_rule.
    DATA mt_roles TYPE zif_cd_hck_runtime_types=>tt_btc_role.
    DATA mt_outcomes TYPE zif_cd_hck_runtime_types=>tt_seq_outcome.
    DATA mt_gl_lines TYPE zif_cd_hck_runtime_types=>tt_gl_xref2_line.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
  METHOD zif_cd_hck_runtime_dao~get_issued_payments.
    LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_payment>)
         WHERE laufd BETWEEN iv_from AND iv_to.
      IF line_exists( it_methods[ table_line = <ls_payment>-pymet ] ).
        INSERT <ls_payment> INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_issued_payments_by_doc.
    LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF line_exists( it_docno[ table_line = <ls_payment>-doc1r ] ).
        INSERT <ls_payment> INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_pm_classes.
    rt_classes = mt_classes.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_pm_banks.
    rt_banks = mt_banks.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_clearing_rules.
    rt_rules = mt_rules.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_btc_roles.
    rt_roles = mt_roles.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_seq_outcomes.
    rt_outcomes = mt_outcomes.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_gl_lines_by_xref2.
    LOOP AT mt_gl_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF line_exists( it_keys[ bukrs = <ls_line>-bukrs xref2 = <ls_line>-xref2 ] ).
        INSERT <ls_line> INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_headers TYPE zif_cd_ops_trace_types=>tt_doc_header.
    DATA mt_returns TYPE zif_cd_ops_trace_types=>tt_return.
    DATA mt_checks TYPE zif_cd_ops_trace_types=>tt_check.
    DATA mt_lines TYPE zif_cd_ops_trace_types=>tt_bank_line.
    DATA mt_runs TYPE zif_cd_ops_trace_types=>tt_payment_run.
    "! Rows of the configured payment-level ACK source (TRACE_SRC_ACK)
    DATA mt_acks TYPE zif_cd_ops_trace_types=>tt_cfg_row.
    DATA mv_ack_reads TYPE i.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~read_configured_set.
    mv_ack_reads = mv_ack_reads + 1.
    LOOP AT mt_acks ASSIGNING FIELD-SYMBOL(<ls_ack>).
      IF line_exists( it_keys[ table_line = <ls_ack>-key1 ] ).
        INSERT <ls_ack> INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_doc_headers.
    rt_headers = mt_headers.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_returns.
    LOOP AT mt_returns ASSIGNING FIELD-SYMBOL(<ls_return>).
      IF line_exists( it_docno[ table_line = <ls_return>-selw1 ] ).
        INSERT <ls_return> INTO TABLE rt_returns.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_checks_by_doc.
    LOOP AT mt_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
      IF line_exists( it_docno[ table_line = <ls_check>-doc1r ] ).
        INSERT <ls_check> INTO TABLE rt_checks.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_payment_runs.
    LOOP AT mt_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      IF line_exists( it_docno[ table_line = <ls_run>-doc1r ] ).
        INSERT <ls_run> INTO TABLE rt_runs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_bank_lines.
    LOOP AT mt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF line_exists( it_ref[ table_line = <ls_line>-chect ] ).
        INSERT <ls_line> INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


"! FMON repository: the generating source, interfaces and the files of generation groups with ACKs
CLASS ltd_fmon_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_dao PARTIALLY IMPLEMENTED.
    DATA mt_sources TYPE zif_cd_fmon_types=>tt_src.
    DATA mt_ifaces TYPE zif_cd_fmon_types=>tt_iface.
    DATA mt_acks TYPE zif_cd_fmon_types=>tt_group_ack.
    "! Keys of the last group read and number of group reads
    DATA mt_keys TYPE zif_cd_fmon_types=>tt_group_key.
    DATA mv_reads TYPE i.
ENDCLASS.

CLASS ltd_fmon_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_dao~get_sources.
    rt_sources = mt_sources.
  ENDMETHOD.

  METHOD zif_cd_fmon_dao~get_ifaces.
    rt_ifaces = mt_ifaces.
  ENDMETHOD.

  METHOD zif_cd_fmon_dao~get_group_acks.
    mv_reads = mv_reads + 1.
    mt_keys = it_keys.
    LOOP AT mt_acks ASSIGNING FIELD-SYMBOL(<ls_ack>).
      IF line_exists( it_keys[ iface_id = <ls_ack>-iface_id gen_group = <ls_ack>-gen_group ] ).
        INSERT <ls_ack> INTO TABLE rt_acks.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_hck_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    TYPES:
      BEGIN OF ty_holiday,
        calendar TYPE zif_cd_hck_types=>ty_calendar,
        date     TYPE d,
      END OF ty_holiday.
    "! Non-working days per test calendar (every other day works)
    DATA mt_holidays TYPE SORTED TABLE OF ty_holiday WITH UNIQUE KEY calendar date.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_hck_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~is_working_day.
    mv_calls = mv_calls + 1.
    rv_working = xsdbool( NOT line_exists( mt_holidays[ calendar = iv_calendar date = iv_date ] ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261111'.
  ENDMETHOD.
ENDCLASS.


"! Test evidence kind: found for the listed documents, optional anomaly, unconfigured or failing
CLASS ltd_evidence DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.
    DATA mt_found TYPE SORTED TABLE OF zif_cd_hck_runtime_types=>ty_docno WITH UNIQUE KEY table_line.
    DATA mv_anomaly_doc TYPE zif_cd_hck_runtime_types=>ty_docno.
    DATA mv_unconfigured TYPE abap_bool.
    DATA mv_fail TYPE abap_bool.
    "! The anomaly document also gets a further anomaly (PENDING_OUTCOME_MISSING)
    DATA mv_more TYPE abap_bool.
    DATA mv_calls TYPE i.
    DATA mv_asked TYPE i.
ENDCLASS.

CLASS ltd_evidence IMPLEMENTATION.
  METHOD zif_cd_hck_evidence~collect.
    mv_calls = mv_calls + 1.
    mv_asked = mv_asked + lines( it_payments ).
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e665(zcd_ops) WITH is_rule-evidence_class is_rule-param1
                                                                  is_rule-flow is_rule-purpose.
    ENDIF.
    rs_result-unconfigured = mv_unconfigured.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF line_exists( mt_found[ table_line = <ls_payment>-doc1r ] ).
        INSERT VALUE #( doc1r = <ls_payment>-doc1r found = abap_true hits = 1 detail = is_rule-evidence_class )
          INTO TABLE rs_result-evidence.
      ENDIF.
      IF <ls_payment>-doc1r = mv_anomaly_doc.
        INSERT VALUE #( doc1r    = <ls_payment>-doc1r
                        anomaly  = zif_cd_hck_runtime_types=>gc_code-unexpected_seq
                        severity = zif_cd_ops_types=>gc_severity-warning
                        more     = COND #( WHEN mv_more = abap_true
                                           THEN VALUE #( ( code     = zif_cd_hck_runtime_types=>gc_code-pending_overdue
                                                           severity = zif_cd_ops_types=>gc_severity-error ) ) ) )
          INTO TABLE rs_result-evidence.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_inflight DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check    TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_INFLIGHT',
      gc_calendar TYPE zif_cd_hck_types=>ty_param VALUE 'US',
      gc_uk       TYPE zif_cd_hck_types=>ty_calendar VALUE 'GB',
      gc_wire     TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'E',
      gc_ach      TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'G',
      gc_cheque   TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'C',
      gc_coll_ach TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'H',
      gc_card     TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'B',
      gc_bukrs    TYPE c LENGTH 4 VALUE 'US01',
      gc_barclays TYPE zif_cd_hck_runtime_types=>ty_hbkid VALUE 'BARC1',
      "! House bank account of the test cheques and of every test statement line
      gc_chq_bank    TYPE zif_cd_hck_runtime_types=>ty_hbkid VALUE 'JPMC1',
      gc_chq_account TYPE c LENGTH 5 VALUE 'CHK01',
      gc_usd      TYPE zif_cd_ops_types=>ty_currency VALUE 'USD',
      gc_amount   TYPE zif_cd_ops_types=>ty_amount VALUE '-250.00',
      "! Wednesday; Tuesday 2026-11-10 is a holiday of the US test calendar, Monday of the UK one
      gc_today    TYPE d VALUE '20261111',
      gc_holiday  TYPE d VALUE '20261110',
      gc_monday   TYPE d VALUE '20261109',
      gc_friday   TYPE d VALUE '20261106',
      gc_doc1     TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_doc2     TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002',
      gc_doc3     TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300003',
      gc_doc4     TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300004',
      gc_doc5     TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300005',
      gc_doc6     TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300006',
      "! Names of the test evidence kinds (injected plug-ins)
      gc_ev_a     TYPE zif_cd_ops_types=>ty_class_name VALUE 'LTD_EVIDENCE_A',
      gc_ev_b     TYPE zif_cd_ops_types=>ty_class_name VALUE 'LTD_EVIDENCE_B',
      gc_ev_c     TYPE zif_cd_ops_types=>ty_class_name VALUE 'LTD_EVIDENCE_C',
      "! Morning report time of the status-lag tests (grace 120 min: limit 06:00 today)
      gc_morning  TYPE t VALUE '080000',
      "! Payment-level ACK source as the payment trace configures it (test names)
      gc_ack_spec TYPE string VALUE `TABLE=ZCD_WIRE_ACK;KEY=AUGBL;STATUS=ACK_STATUS;DATE=ACK_DATE;TIME=ACK_TIME`,
      "! FMON configuration of the file-level ACK (test names): the generating source with its payment
      "! run fields, the collection interface acknowledged per file and a disbursement one per payment
      gc_regut        TYPE zif_cd_fmon_types=>ty_src_id VALUE 'REGUT',
      gc_group_fields TYPE zif_cd_fmon_types=>ty_field_list VALUE 'LAUFD,LAUFI,HBKID',
      gc_coll_iface   TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_COLL_OUT',
      gc_disb_iface   TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_PNC_DISB_OUT',
      gc_pnc          TYPE zif_cd_hck_runtime_types=>ty_hbkid VALUE 'PNC1',
      gc_run_a        TYPE c LENGTH 6 VALUE 'COLL01',
      gc_run_b        TYPE c LENGTH 6 VALUE 'COLL02',
      "! Generation group keys of the two collection runs of Friday as FMON builds them (run date,
      "! run ID, house bank joined by '/')
      gc_group_a      TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261106/COLL01/PNC1',
      gc_group_b      TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261106/COLL02/PNC1'.

    "! Confirmed DPAYH-ZZ_PAYMENT_STATUS values (2026-11-08) and ACK statuses of the tests
    CONSTANTS:
      BEGIN OF gc_status,
        issued    TYPE c LENGTH 20 VALUE 'ISSUED',
        confirmed TYPE c LENGTH 20 VALUE 'CONFIRMED',
        ack       TYPE c LENGTH 40 VALUE 'ACK',
        nack      TYPE c LENGTH 40 VALUE 'NACK',
      END OF gc_status.

    CONSTANTS:
      BEGIN OF gc_class,
        wire   TYPE zif_cd_hck_runtime_types=>ty_method_class VALUE 'WIR',
        ach    TYPE zif_cd_hck_runtime_types=>ty_method_class VALUE 'ACH',
        cheque TYPE zif_cd_hck_runtime_types=>ty_method_class VALUE 'CHQ',
        card   TYPE zif_cd_hck_runtime_types=>ty_method_class VALUE 'CRD',
      END OF gc_class.

    CONSTANTS:
      BEGIN OF gc_key,
        d_wire   TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'DWIR',
        d_ach    TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'DACH',
        d_cheque TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'DCHQ',
        c_ach    TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'CACH',
        c_card   TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'CCRD',
        c_cheque TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'CCHQ',
      END OF gc_key.

    DATA mo_dao TYPE REF TO ltd_runtime_dao.
    DATA mo_trace TYPE REF TO ltd_trace_dao.
    DATA mo_fmon TYPE REF TO ltd_fmon_dao.
    DATA mo_hck_dao TYPE REF TO ltd_hck_dao.
    DATA mo_ev_a TYPE REF TO ltd_evidence.
    DATA mo_ev_b TYPE REF TO ltd_evidence.
    DATA mo_ev_c TYPE REF TO ltd_evidence.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.
    DATA mt_thresholds TYPE zif_cd_hck_types=>tt_threshold.

    METHODS setup.
    METHODS teardown.
    " ageing
    METHODS wire_value_date_boundary    FOR TESTING.
    METHODS holiday_is_not_a_business_day FOR TESTING.
    METHODS no_calendar_counts_all_days FOR TESTING.
    METHODS bank_calendar_overrides     FOR TESTING.
    METHODS missing_value_date_run_date FOR TESTING.
    METHODS flows_reported_separately   FOR TESTING.
    METHODS issue_date_calendar_days    FOR TESTING.
    METHODS empty_data_measures_zero    FOR TESTING.
    METHODS method_in_two_classes_raises FOR TESTING.
    METHODS limits_missing_warns        FOR TESTING.
    METHODS read_cap_and_top_n          FOR TESTING.
    METHODS reversed_payment_excluded   FOR TESTING.
    METHODS currencies_never_summed     FOR TESTING.
    " rule combination
    METHODS all_rows_hold_excluded      FOR TESTING.
    METHODS partial_rows_inconsistent   FOR TESTING.
    METHODS no_evidence_stays_open      FOR TESTING.
    METHODS must_not_hold_violated      FOR TESTING.
    METHODS purpose_order_returned_first FOR TESTING.
    METHODS partial_return_return_code  FOR TESTING.
    METHODS anomaly_listed_not_aged     FOR TESTING.
    METHODS every_anomaly_listed        FOR TESTING.
    METHODS unusable_kind_fails_closed  FOR TESTING.
    METHODS info_row_unconfigured_skipped FOR TESTING.
    METHODS mandatory_unconfig_no_clear FOR TESTING.
    METHODS invalid_indicator_blocks_later FOR TESTING.
    METHODS one_collect_per_kind        FOR TESTING.
    METHODS class_without_rule_unwatched FOR TESTING.
    METHODS new_class_by_configuration  FOR TESTING.
    " user rules end to end
    METHODS rule1_wire_status_and_line  FOR TESTING.
    METHODS rule2_cheque_b_v_blank      FOR TESTING.
    METHODS rule3_collection_xref2      FOR TESTING.
    METHODS rule4_ach_return_with_lot   FOR TESTING.
    METHODS rule4_ach_return_lot_missing FOR TESTING.
    METHODS stripe_unconfigured_no_clear FOR TESTING.
    METHODS stripe_info_switch_bseg_decide FOR TESTING.
    " shared fixtures of the canonical payment outcome (same data as trace and dashboard tests)
    METHODS fixture_retrieval_not_return FOR TESTING.
    METHODS fixture_line_not_cleared     FOR TESTING.
    METHODS fixture_two_runs_cleared     FOR TESTING.
    METHODS fixture_agrees_with_outcome  FOR TESTING.
    METHODS fixture_returned_excluded    FOR TESTING.
    METHODS fixture_return_lag_in_flight FOR TESTING.
    METHODS fixture_cheques_voided       FOR TESTING.
    METHODS fixture_stopped_cashed       FOR TESTING.
    " status lag (PAY_STATUS_LAG)
    METHODS lag_after_grace_reported     FOR TESTING.
    METHODS lag_within_grace_silent      FOR TESTING.
    METHODS ack_lag_after_grace          FOR TESTING.
    METHODS ack_source_unconfigured      FOR TESTING.
    " status lag after a file-level ACK (collections)
    METHODS file_ack_lag_after_grace     FOR TESTING.
    METHODS file_ack_within_grace        FOR TESTING.
    METHODS file_ack_confirmed_silent    FOR TESTING.
    METHODS file_ack_replaced_ignored    FOR TESTING.
    METHODS file_ack_group_unconfigured  FOR TESTING.
    METHODS file_ack_two_runs_apart      FOR TESTING.
    METHODS ack_levels_in_one_run        FOR TESTING.
    "! A collection ACH payment in flight (test kind A finds nothing) of a Friday run with its status
    METHODS add_collection
      IMPORTING
        iv_doc    TYPE zif_cd_hck_runtime_types=>ty_docno
        iv_status TYPE clike
        iv_laufi  TYPE clike.
    "! A file of a generation group of the collection interface (FMON registry) with an optional ACK
    METHODS add_file
      IMPORTING
        iv_id    TYPE i
        iv_group TYPE zif_cd_fmon_types=>ty_file_ref
        iv_first TYPE timestampl
        iv_ack   TYPE timestampl OPTIONAL.
    "! Time stamp of a local date and time (the report's time zone)
    METHODS local_ts
      IMPORTING
        iv_date      TYPE d
        iv_time      TYPE t
      RETURNING
        VALUE(rv_ts) TYPE timestampl.
    "! The PAY_STATUS_LAG findings of a result
    METHODS lags
      IMPORTING
        is_result     TYPE zif_cd_hck_types=>ty_check_result
      RETURNING
        VALUE(rt_lag) TYPE zif_cd_ops_types=>tt_finding.
    "! A wire in flight (test kind A finds nothing) with its DPAYH status and an optional bank ACK
    METHODS add_acked_wire
      IMPORTING
        iv_doc        TYPE zif_cd_hck_runtime_types=>ty_docno
        iv_status     TYPE clike
        iv_ack_status TYPE clike OPTIONAL
        iv_ack_date   TYPE d OPTIONAL
        iv_ack_time   TYPE t OPTIONAL.

    "! Configuration and data of the shared fixtures (all scenarios, delivered rules)
    METHODS load_fixtures
      RETURNING
        VALUE(ro_fixture) TYPE REF TO zcl_cd_ops_pay_fixture.

    METHODS add_class
      IMPORTING
        iv_flow     TYPE zif_cd_hck_runtime_types=>ty_flow
        iv_class    TYPE zif_cd_hck_runtime_types=>ty_method_class
        iv_methods  TYPE clike
        iv_basis    TYPE zif_cd_hck_runtime_types=>ty_age_basis DEFAULT zif_cd_hck_runtime_types=>gc_age_basis-value_date
        iv_calendar TYPE zif_cd_hck_types=>ty_calendar OPTIONAL.
    METHODS add_rule
      IMPORTING
        iv_key      TYPE zif_cd_hck_runtime_types=>ty_flow_class
        iv_purpose  TYPE zif_cd_hck_runtime_types=>ty_purpose DEFAULT zif_cd_hck_runtime_types=>gc_purpose-cleared
        iv_seq      TYPE zif_cd_hck_runtime_types=>ty_rule_seq
        iv_class    TYPE zif_cd_ops_types=>ty_class_name
        iv_param1   TYPE clike OPTIONAL
        iv_required TYPE zif_cd_hck_runtime_types=>ty_required DEFAULT zif_cd_hck_runtime_types=>gc_required-must_hold.
    "! Delivered seed rules of user rules 1-4 (real evidence plug-ins) instead of the test kinds
    METHODS seed_rules.
    METHODS limit
      IMPORTING
        iv_key   TYPE zif_cd_hck_runtime_types=>ty_flow_class
        iv_amber TYPE zif_cd_hck_types=>ty_value
        iv_red   TYPE zif_cd_hck_types=>ty_value.
    METHODS add_payment
      IMPORTING
        iv_doc        TYPE zif_cd_hck_runtime_types=>ty_docno
        iv_pymet      TYPE zif_cd_hck_runtime_types=>ty_pymet DEFAULT gc_wire
        iv_laufd      TYPE d DEFAULT gc_friday
        iv_valut      TYPE d OPTIONAL
        iv_collection TYPE abap_bool DEFAULT abap_false
        iv_currency   TYPE zif_cd_ops_types=>ty_currency DEFAULT gc_usd
        iv_hbkid      TYPE zif_cd_hck_runtime_types=>ty_hbkid OPTIONAL
        iv_laufi      TYPE clike OPTIONAL.
    METHODS add_line
      IMPORTING
        iv_chect TYPE clike
        iv_code  TYPE clike OPTIONAL
        iv_budat TYPE d DEFAULT gc_friday
        iv_esnum TYPE i DEFAULT 1
        iv_kwbtr TYPE zif_cd_ops_types=>ty_amount DEFAULT gc_amount.
    METHODS act
      IMPORTING
        iv_calendar      TYPE zif_cd_hck_types=>ty_param DEFAULT gc_calendar
        iv_top_n         TYPE zif_cd_hck_types=>ty_param OPTIONAL
        iv_time          TYPE t OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
    METHODS metric
      IMPORTING
        is_result       TYPE zif_cd_hck_types=>ty_check_result
        iv_metric       TYPE zif_cd_hck_types=>ty_metric_name
        iv_key          TYPE zif_cd_hck_runtime_types=>ty_flow_class DEFAULT gc_key-d_wire
        iv_dim2         TYPE clike OPTIONAL
      RETURNING
        VALUE(rv_value) TYPE zif_cd_hck_types=>ty_value.
    METHODS finding
      IMPORTING
        is_result         TYPE zif_cd_hck_types=>ty_check_result
        iv_code           TYPE zif_cd_ops_types=>ty_check_code DEFAULT zif_cd_hck_runtime_types=>gc_code-payment_not_clear
        iv_key            TYPE zif_cd_hck_runtime_types=>ty_flow_class DEFAULT gc_key-d_wire
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.
    METHODS lists
      IMPORTING
        is_finding    TYPE zif_cd_ops_types=>ty_finding
        iv_doc        TYPE clike
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.
ENDCLASS.


CLASS ltc_inflight IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_dao ).
    mo_hck_dao = NEW #( ).
    INSERT VALUE #( calendar = gc_calendar date = gc_holiday ) INTO TABLE mo_hck_dao->mt_holidays.
    INSERT VALUE #( calendar = gc_uk date = gc_monday ) INTO TABLE mo_hck_dao->mt_holidays.
    zcl_cd_hck_injector=>inject_dao( mo_hck_dao ).
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    " FMON as configured for the file-level ACK: source REGUT with its payment run fields, the
    " collection interface acknowledged per file, a disbursement interface acknowledged per payment
    mo_fmon = NEW #( ).
    DATA(ls_src) = VALUE zif_cd_fmon_types=>ty_src( ).
    ls_src-src_id       = gc_regut.
    ls_src-active       = abap_true.
    ls_src-group_fields = gc_group_fields.
    INSERT ls_src INTO TABLE mo_fmon->mt_sources.
    DATA(ls_iface) = VALUE zif_cd_fmon_types=>ty_iface( ).
    ls_iface-iface_id     = gc_coll_iface.
    ls_iface-direction    = zif_cd_fmon_types=>gc_direction-outbound.
    ls_iface-ack_expected = abap_true.
    ls_iface-ack_level    = zif_cd_fmon_types=>gc_ack_level-file.
    ls_iface-active       = abap_true.
    INSERT ls_iface INTO TABLE mo_fmon->mt_ifaces.
    ls_iface-iface_id  = gc_disb_iface.
    ls_iface-ack_level = zif_cd_fmon_types=>gc_ack_level-payment.
    INSERT ls_iface INTO TABLE mo_fmon->mt_ifaces.
    zcl_cd_fmon_injector=>inject_dao( mo_fmon ).
    mo_params = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    mo_ev_a = NEW #( ).
    mo_ev_b = NEW #( ).
    mo_ev_c = NEW #( ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_ev_a io_instance = mo_ev_a ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_ev_b io_instance = mo_ev_b ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_ev_c io_instance = mo_ev_c ).
    " Classes as seeded (collections ACH also by the CAMT methods; card = Stripe B)
    add_class( iv_flow = zif_cd_hck_runtime_types=>gc_flow-disbursement iv_class = gc_class-wire iv_methods = gc_wire ).
    add_class( iv_flow = zif_cd_hck_runtime_types=>gc_flow-disbursement iv_class = gc_class-ach iv_methods = |A,{ gc_ach }| ).
    add_class( iv_flow    = zif_cd_hck_runtime_types=>gc_flow-disbursement
               iv_class   = gc_class-cheque
               iv_methods = gc_cheque
               iv_basis   = zif_cd_hck_runtime_types=>gc_age_basis-issue_date ).
    add_class( iv_flow = zif_cd_hck_runtime_types=>gc_flow-collection iv_class = gc_class-ach iv_methods = |1,{ gc_coll_ach }| ).
    add_class( iv_flow = zif_cd_hck_runtime_types=>gc_flow-collection iv_class = gc_class-card iv_methods = gc_card ).
    " Every class is cleared by test kind A unless a test configures more
    add_rule( iv_key = gc_key-d_wire iv_seq = '010' iv_class = gc_ev_a ).
    add_rule( iv_key = gc_key-d_ach iv_seq = '010' iv_class = gc_ev_a ).
    add_rule( iv_key = gc_key-d_cheque iv_seq = '010' iv_class = gc_ev_a ).
    add_rule( iv_key = gc_key-c_ach iv_seq = '010' iv_class = gc_ev_a ).
    add_rule( iv_key = gc_key-c_card iv_seq = '010' iv_class = gc_ev_a ).
    " Seed limits: wire 1 / 2 business days after the value date, ACH and card 2 / 3, cheques 61 / 91 days
    limit( iv_key = gc_key-d_wire iv_amber = 1 iv_red = 2 ).
    limit( iv_key = gc_key-d_ach iv_amber = 2 iv_red = 3 ).
    limit( iv_key = gc_key-c_ach iv_amber = 2 iv_red = 3 ).
    limit( iv_key = gc_key-c_card iv_amber = 2 iv_red = 3 ).
    limit( iv_key = gc_key-d_cheque iv_amber = 61 iv_red = 91 ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_fmon_injector=>reset( ).
    CLEAR: mo_dao, mo_trace, mo_fmon, mo_hck_dao, mo_params, mt_thresholds, mo_ev_a, mo_ev_b, mo_ev_c.
  ENDMETHOD.


  METHOD add_class.
    DATA ls_class TYPE zif_cd_hck_runtime_types=>ty_pm_class.
    ls_class-flow         = iv_flow.
    ls_class-method_class = iv_class.
    ls_class-pay_methods  = iv_methods.
    ls_class-age_basis    = iv_basis.
    ls_class-calendar     = iv_calendar.
    INSERT ls_class INTO TABLE mo_dao->mt_classes.
  ENDMETHOD.


  METHOD add_rule.
    DATA ls_rule TYPE zif_cd_hck_runtime_types=>ty_clr_rule.
    ls_rule-flow           = iv_key(1).
    ls_rule-method_class   = iv_key+1(3).
    ls_rule-purpose        = iv_purpose.
    ls_rule-seq            = iv_seq.
    ls_rule-evidence_class = iv_class.
    ls_rule-param1         = iv_param1.
    ls_rule-required       = iv_required.
    INSERT ls_rule INTO TABLE mo_dao->mt_rules.
  ENDMETHOD.


  METHOD seed_rules.
    DATA ls_role TYPE zif_cd_hck_runtime_types=>ty_btc_role_row.
    DATA ls_outcome TYPE zif_cd_hck_runtime_types=>ty_seq_outcome.
    CLEAR mo_dao->mt_rules.
    " Rule 1: wire disbursement cleared = statement line AND DPAYH status CLEARED
    add_rule( iv_key = gc_key-d_wire iv_seq = '010' iv_class = 'ZCL_CD_HCK_EV_STMT_DOC' ).
    add_rule( iv_key = gc_key-d_wire iv_seq = '020' iv_class = 'ZCL_CD_HCK_EV_PAY_STATUS' iv_param1 = 'CLEARED' ).
    " ACH disbursement: lifecycle outcome AND status; returned / retrieved by the lifecycle
    add_rule( iv_key = gc_key-d_ach iv_seq = '010' iv_class = 'ZCL_CD_HCK_EV_BTC_SEQ' iv_param1 = 'CLEARED,RETRIEVAL_FAILED' ).
    add_rule( iv_key = gc_key-d_ach iv_seq = '020' iv_class = 'ZCL_CD_HCK_EV_PAY_STATUS' iv_param1 = 'CLEARED' ).
    add_rule( iv_key     = gc_key-d_ach
              iv_purpose = zif_cd_hck_runtime_types=>gc_purpose-returned
              iv_seq     = '010'
              iv_class   = 'ZCL_CD_HCK_EV_BTC_SEQ'
              iv_param1  = 'RETURNED,RETRIEVED' ).
    " Rule 2: cheque cleared = state B AND statement line of the cheque number; voided = V and no line
    add_rule( iv_key = gc_key-d_cheque iv_seq = '010' iv_class = 'ZCL_CD_HCK_EV_CHQ_STATUS' iv_param1 = 'B' ).
    add_rule( iv_key = gc_key-d_cheque iv_seq = '020' iv_class = 'ZCL_CD_HCK_EV_STMT_CHEQUE' iv_param1 = '13' ).
    add_rule( iv_key     = gc_key-d_cheque
              iv_purpose = zif_cd_hck_runtime_types=>gc_purpose-voided
              iv_seq     = '010'
              iv_class   = 'ZCL_CD_HCK_EV_CHQ_STATUS'
              iv_param1  = 'V' ).
    add_rule( iv_key      = gc_key-d_cheque
              iv_purpose  = zif_cd_hck_runtime_types=>gc_purpose-voided
              iv_seq      = '020'
              iv_class    = 'ZCL_CD_HCK_EV_STMT_CHEQUE'
              iv_param1   = '13'
              iv_required = zif_cd_hck_runtime_types=>gc_required-must_not_hold ).
    " Rule 3: collection ACH cleared = lifecycle CLEARED AND BSEG XREF2 cleared
    add_rule( iv_key = gc_key-c_ach iv_seq = '010' iv_class = 'ZCL_CD_HCK_EV_BTC_SEQ' iv_param1 = 'CLEARED' ).
    add_rule( iv_key = gc_key-c_ach iv_seq = '020' iv_class = 'ZCL_CD_HCK_EV_GL_XREF2' ).
    " Card (seed): BSEG XREF2 cleared (X) AND Stripe payout row (C, settings not maintained in the test)
    add_rule( iv_key = gc_key-c_card iv_seq = '010' iv_class = 'ZCL_CD_HCK_EV_GL_XREF2' ).
    add_rule( iv_key      = gc_key-c_card
              iv_seq      = '020'
              iv_class    = 'ZCL_CD_HCK_EV_STRIPE'
              iv_param1   = 'STRIPE'
              iv_required = zif_cd_hck_runtime_types=>gc_required-condition ).
    " Roles and outcomes (subset of the seed)
    ls_role-flow = zif_cd_hck_runtime_types=>gc_flow-disbursement.
    ls_role-method_class = gc_class-ach.
    ls_role-scheme = 'BAI2'.
    ls_role-btc_code = '466'.
    ls_role-role = 'ORIGINAL'.
    INSERT ls_role INTO TABLE mo_dao->mt_roles.
    ls_role-btc_code = '168'.
    ls_role-role = 'RETURNED'.
    ls_role-compare_amount = abap_true.
    INSERT ls_role INTO TABLE mo_dao->mt_roles.
    ls_role-flow = zif_cd_hck_runtime_types=>gc_flow-collection.
    ls_role-btc_code = '166'.
    ls_role-role = 'COLLECTED'.
    ls_role-compare_amount = abap_false.
    INSERT ls_role INTO TABLE mo_dao->mt_roles.
    ls_outcome-flow = zif_cd_hck_runtime_types=>gc_flow-disbursement.
    ls_outcome-method_class = gc_class-ach.
    ls_outcome-seq = '010'.
    ls_outcome-seq_pattern = 'ORIGINAL'.
    ls_outcome-outcome = 'CLEARED'.
    ls_outcome-expected_dfkkrp = '0'.
    INSERT ls_outcome INTO TABLE mo_dao->mt_outcomes.
    ls_outcome-seq = '020'.
    ls_outcome-seq_pattern = 'ORIGINAL,RETURNED'.
    ls_outcome-outcome = 'RETURNED'.
    ls_outcome-expected_dfkkrp = '1'.
    INSERT ls_outcome INTO TABLE mo_dao->mt_outcomes.
    ls_outcome-flow = zif_cd_hck_runtime_types=>gc_flow-collection.
    ls_outcome-seq = '010'.
    ls_outcome-seq_pattern = 'COLLECTED'.
    ls_outcome-outcome = 'CLEARED'.
    ls_outcome-expected_dfkkrp = '0'.
    INSERT ls_outcome INTO TABLE mo_dao->mt_outcomes.
  ENDMETHOD.


  METHOD limit.
    DATA ls_threshold TYPE zif_cd_hck_types=>ty_threshold.
    ls_threshold-check_id        = gc_check.
    ls_threshold-metric          = zcl_cd_hck_c_inflight=>gc_metric-age_oldest.
    ls_threshold-bukrs           = iv_key.
    ls_threshold-amber           = iv_amber.
    ls_threshold-red             = iv_red.
    ls_threshold-higher_is_worse = abap_true.
    ls_threshold-baseline_mode   = zif_cd_hck_types=>gc_baseline-none.
    INSERT ls_threshold INTO TABLE mt_thresholds.
  ENDMETHOD.


  METHOD add_payment.
    DATA ls_payment TYPE zif_cd_hck_runtime_types=>ty_issued_payment.
    ls_payment-doc1r    = iv_doc.
    ls_payment-laufd    = iv_laufd.
    ls_payment-bukrs    = gc_bukrs.
    ls_payment-pymet    = iv_pymet.
    ls_payment-hbkid    = iv_hbkid.
    ls_payment-laufi    = iv_laufi.
    ls_payment-valut    = iv_valut.
    ls_payment-amount   = gc_amount.
    ls_payment-currency = iv_currency.
    ls_payment-xeinz    = iv_collection.
    INSERT ls_payment INTO TABLE mo_dao->mt_payments.
  ENDMETHOD.


  METHOD add_line.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    ls_line-kukey = '00000101'.
    ls_line-esnum = iv_esnum.
    ls_line-chect = iv_chect.
    ls_line-vorgc = iv_code.
    ls_line-budat = iv_budat.
    ls_line-kwbtr = iv_kwbtr.
    " Statement account (FEBKO): the house bank account of the test cheques
    ls_line-bukrs = gc_bukrs.
    ls_line-hbkid = gc_chq_bank.
    ls_line-hktid = gc_chq_account.
    INSERT ls_line INTO TABLE mo_trace->mt_lines.
  ENDMETHOD.


  METHOD act.
    DATA ls_def TYPE zif_cd_hck_types=>ty_check_def.
    DATA ls_context TYPE zif_cd_hck_types=>ty_context.
    ls_def-check_id        = gc_check.
    ls_def-param1          = iv_calendar.
    ls_def-param4          = iv_top_n.
    ls_context-report_date = gc_today.
    ls_context-now_date    = gc_today.
    ls_context-now_time    = iv_time.
    rs_result = NEW zcl_cd_hck_c_inflight( )->zif_cd_hck_check~execute( is_def        = ls_def
                                                                        it_thresholds = mt_thresholds
                                                                        is_context    = ls_context ).
  ENDMETHOD.


  METHOD metric.
    rv_value = VALUE #( is_result-metrics[ metric = iv_metric dim1 = iv_key dim2 = iv_dim2 ]-value OPTIONAL ).
  ENDMETHOD.


  METHOD finding.
    rs_finding = VALUE #( is_result-findings[ check_code = iv_code reference = iv_key ] OPTIONAL ).
  ENDMETHOD.


  METHOD lists.
    rv_yes = xsdbool( find( val = is_finding-details sub = CONV string( iv_doc ) ) >= 0 ).
  ENDMETHOD.


  " Rule: a wire is late once its value date has passed by the grace (amber 1 = one business
  " day after); value date today is not late
  METHOD wire_value_date_boundary.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_today ).
        add_payment( iv_doc = gc_doc2 iv_valut = '20261108' ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = 2 msg = 'Two wires not cleared' ).
        " 2026-11-08 -> 09 (working), 10 (holiday), 11 (working) = 2 business days: critical
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest )
                                            exp = 2 msg = 'Oldest: 2 business days' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-warn_count )
                                            exp = 1 msg = 'Value date today is not late' ).
        cl_abap_unit_assert=>assert_equals( act = finding( ls_result )-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Critical payment: error' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-crit_amount
                                                          iv_dim2   = gc_usd )
                                            exp = CONV zif_cd_hck_types=>ty_value( abs( gc_amount ) )
                                            msg = 'Critical amount per currency' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a holiday of the factory calendar between value date and today is not counted
  METHOD holiday_is_not_a_business_day.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_monday ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest )
                                            exp = 1 msg = 'Holiday not counted' ).
        cl_abap_unit_assert=>assert_equals( act = finding( ls_result )-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Late, not critical: warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without any factory calendar every day counts (warning says so)
  METHOD no_calendar_counts_all_days.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_monday ).
        DATA(ls_result) = act( iv_calendar = space ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest )
                                            exp = 2 msg = 'Calendar days' ).
        cl_abap_unit_assert=>assert_equals( act = mo_hck_dao->mv_calls exp = 0 msg = 'No calendar read' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                                                          severity   = zif_cd_ops_types=>gc_severity-warning ] ) )
          msg = 'Missing calendar: warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the calendar of the house bank (ZCD_HCK_PMBANK) wins over the class and the check
  " calendar - UK holiday Monday, US holiday Tuesday (international ACH via Barclays)
  METHOD bank_calendar_overrides.
    DATA ls_bank TYPE zif_cd_hck_runtime_types=>ty_pm_bank.
    TRY.
        ls_bank-flow         = zif_cd_hck_runtime_types=>gc_flow-disbursement.
        ls_bank-method_class = gc_class-wire.
        ls_bank-hbkid        = gc_barclays.
        ls_bank-calendar     = gc_uk.
        INSERT ls_bank INTO TABLE mo_dao->mt_banks.
        " Friday -> 07 08 (weekend counts in the test), 09 UK holiday, 10, 11 = 4 UK business days
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday iv_hbkid = gc_barclays iv_currency = 'GBP' ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest )
                                            exp = 4 msg = 'UK calendar of the bank used' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_hck_dao->mt_holidays[ calendar = gc_uk ] ) )
                                          msg = 'UK calendar configured' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without value date the payment is aged from the run date and the finding says so
  METHOD missing_value_date_run_date.
    TRY.
        add_payment( iv_doc = gc_doc1 ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest )
                                            exp = 4 msg = 'Aged from the run date' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( find( val = finding( ls_result )-details
                               sub = zcl_cd_ops_util=>text( zif_cd_hck_runtime_types=>gc_msg-run_date_used ) ) >= 0 )
          msg = 'Detail says the run date was used' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-value_date_missing ] ) )
          msg = 'Missing value dates listed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: collections (XEINZ = X) are measured and reported apart from disbursements
  METHOD flows_reported_separately.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_coll_ach iv_valut = gc_friday iv_collection = abap_true ).
        add_payment( iv_doc = gc_doc2 iv_pymet = gc_ach iv_valut = gc_monday ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-crit_count
                                                          iv_key    = gc_key-c_ach )
                                            exp = 1 msg = 'Collection ACH critical' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-warn_count
                                                          iv_key    = gc_key-d_ach )
                                            exp = 0 msg = 'Disbursement ACH within grace' ).
        cl_abap_unit_assert=>assert_initial( act = finding( is_result = ls_result iv_key = gc_key-d_ach )
                                             msg = 'No finding of flow D' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: ISSUE_DATE classes (cheques) age in calendar days from issue: 60 days is not late, 61 is
  METHOD issue_date_calendar_days.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_cheque iv_laufd = '20260912' ).
        add_payment( iv_doc = gc_doc2 iv_pymet = gc_cheque iv_laufd = '20260911' ).
        add_payment( iv_doc = gc_doc3 iv_pymet = gc_cheque iv_laufd = '20260801' ).
        INSERT gc_doc3 INTO TABLE mo_ev_a->mt_found.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-d_cheque )
                                            exp = 2 msg = 'Two cheques open, one cleared' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest
                                                          iv_key    = gc_key-d_cheque )
                                            exp = 61 msg = 'Calendar days from issue' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-warn_count
                                                          iv_key    = gc_key-d_cheque )
                                            exp = 1 msg = '60 days not late, 61 late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: nothing in flight measures zero for every watched flow / class
  METHOD empty_data_measures_zero.
    TRY.
        DATA(ls_result) = act( ).
        " 5 classes x (4 counts + PAY_INCONSISTENT + PAY_EXCLUDED of CLEARED)
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-metrics ) exp = 30 msg = 'Six metrics x five keys' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Nothing to report' ).
        cl_abap_unit_assert=>assert_equals( act = mo_ev_a->mv_calls exp = 0 msg = 'No payments: no evidence read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment method in two classes of one flow is a configuration error, never a guess
  METHOD method_in_two_classes_raises.
    add_class( iv_flow = zif_cd_hck_runtime_types=>gc_flow-disbursement iv_class = 'ACI' iv_methods = gc_ach ).
    add_rule( iv_key = 'DACI' iv_seq = '010' iv_class = gc_ev_a ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Ambiguous mapping must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Configuration error raised' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a watched key without limits is not judged (warning); a class without methods is listed
  METHOD limits_missing_warns.
    TRY.
        DELETE mt_thresholds WHERE bukrs = gc_key-c_ach.
        add_class( iv_flow = zif_cd_hck_runtime_types=>gc_flow-collection iv_class = gc_class-wire iv_methods = space ).
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_coll_ach iv_valut = gc_friday iv_collection = abap_true ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-limits_missing ]-severity OPTIONAL )
          exp = zif_cd_ops_types=>gc_severity-warning
          msg = 'Limits missing: warning' ).
        cl_abap_unit_assert=>assert_initial( act = finding( is_result = ls_result iv_key = gc_key-c_ach )
                                             msg = 'Not judged without limits' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-c_ach )
                                            exp = 1 msg = 'Still counted' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                                                          severity   = zif_cd_ops_types=>gc_severity-info ] ) )
          msg = 'Class without payment methods: listed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a read that reaches HCK_INFLIGHT_MAX_ROWS is reported; PARAM4 limits the listed payments
  METHOD read_cap_and_top_n.
    TRY.
        mo_params->set( iv_name = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows iv_value = '2' ).
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc2 iv_valut = gc_friday ).
        DATA(ls_result) = act( iv_top_n = '1' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-read_capped ] ) )
          msg = 'Cap reached: reported' ).
        SPLIT finding( ls_result )-details AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_lines).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 msg = 'Top 1 listed' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-warn_count )
                                            exp = 2 msg = 'Counts are complete' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a reversed payment (DFKKKO-STBEL) is not in flight and no evidence is read for it
  METHOD reversed_payment_excluded.
    DATA ls_header TYPE zif_cd_ops_trace_types=>ty_doc_header.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        ls_header-opbel = gc_doc1.
        ls_header-stbel = '000000900001'.
        INSERT ls_header INTO TABLE mo_trace->mt_headers.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = 0 msg = 'Reversed: not in flight' ).
        cl_abap_unit_assert=>assert_equals( act = mo_ev_a->mv_asked exp = 0 msg = 'No evidence asked for it' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: amounts are reported per currency (USD / EUR / GBP), never summed across currencies
  METHOD currencies_never_summed.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc2 iv_valut = gc_friday iv_currency = 'EUR' ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-warn_amount
                                                          iv_dim2   = 'EUR' )
                                            exp = CONV zif_cd_hck_types=>ty_value( abs( gc_amount ) )
                                            msg = 'EUR on its own' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-warn_amount
                                                          iv_dim2   = gc_usd )
                                            exp = CONV zif_cd_hck_types=>ty_value( abs( gc_amount ) )
                                            msg = 'USD on its own' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: all required rows of a purpose hold = excluded, counted per purpose
  METHOD all_rows_hold_excluded.
    TRY.
        add_rule( iv_key = gc_key-d_wire iv_seq = '020' iv_class = gc_ev_b ).
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        INSERT gc_doc1 INTO TABLE mo_ev_a->mt_found.
        INSERT gc_doc1 INTO TABLE mo_ev_b->mt_found.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = 0 msg = 'Cleared: not open' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 1 msg = 'Counted as cleared' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Nothing to report' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: some but not all required rows hold = CLEARING_INCONSISTENT naming what held, not aged
  METHOD partial_rows_inconsistent.
    TRY.
        add_rule( iv_key = gc_key-d_wire iv_seq = '020' iv_class = gc_ev_b ).
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        INSERT gc_doc1 INTO TABLE mo_ev_a->mt_found.
        DATA(ls_result) = act( ).
        DATA(ls_finding) = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Inconsistency: error' ).
        cl_abap_unit_assert=>assert_true( act = lists( is_finding = ls_finding iv_doc = gc_ev_a ) msg = 'Names what held' ).
        cl_abap_unit_assert=>assert_true( act = lists( is_finding = ls_finding iv_doc = gc_ev_b ) msg = 'Names what is missing' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = 0 msg = 'Listed, not aged' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-inconsistent )
                                            exp = 1 msg = 'Counted inconsistent' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no row of any purpose holds = in flight (aged)
  METHOD no_evidence_stays_open.
    TRY.
        add_rule( iv_key = gc_key-d_wire iv_seq = '020' iv_class = gc_ev_b ).
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = 1 msg = 'In flight' ).
        cl_abap_unit_assert=>assert_initial(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist )
          msg = 'Not inconsistent' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a must-not-hold row (N) that holds makes the purpose inconsistent
  METHOD must_not_hold_violated.
    TRY.
        add_rule( iv_key = gc_key-d_wire iv_seq = '020' iv_class = gc_ev_b
                  iv_required = zif_cd_hck_runtime_types=>gc_required-must_not_hold ).
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc2 iv_valut = gc_friday ).
        INSERT gc_doc1 INTO TABLE mo_ev_a->mt_found.
        INSERT gc_doc1 INTO TABLE mo_ev_b->mt_found.
        INSERT gc_doc2 INTO TABLE mo_ev_a->mt_found.
        DATA(ls_result) = act( ).
        DATA(ls_finding) = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist ).
        cl_abap_unit_assert=>assert_true( act = lists( is_finding = ls_finding iv_doc = gc_doc1 ) msg = 'Forbidden evidence' ).
        cl_abap_unit_assert=>assert_false( act = lists( is_finding = ls_finding iv_doc = gc_doc2 ) msg = 'Absent: consistent' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 1 msg = 'One cleared' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: purposes decide in order VOIDED, RETURNED, PENDING, CLEARED - a complete return is never
  " judged as an incomplete clearing
  METHOD purpose_order_returned_first.
    TRY.
        add_rule( iv_key = gc_key-d_wire iv_seq = '020' iv_class = gc_ev_b ).
        add_rule( iv_key = gc_key-d_wire iv_purpose = zif_cd_hck_runtime_types=>gc_purpose-returned
                  iv_seq = '010' iv_class = gc_ev_c ).
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        INSERT gc_doc1 INTO TABLE mo_ev_a->mt_found.
        INSERT gc_doc1 INTO TABLE mo_ev_c->mt_found.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-returned )
                                            exp = 1 msg = 'Returned decides' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No clearing inconsistency' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a partial RETURNED purpose is RETURN_INCONSISTENT
  METHOD partial_return_return_code.
    TRY.
        add_rule( iv_key = gc_key-d_wire iv_purpose = zif_cd_hck_runtime_types=>gc_purpose-returned
                  iv_seq = '010' iv_class = gc_ev_b ).
        add_rule( iv_key = gc_key-d_wire iv_purpose = zif_cd_hck_runtime_types=>gc_purpose-returned
                  iv_seq = '020' iv_class = gc_ev_c ).
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        INSERT gc_doc1 INTO TABLE mo_ev_c->mt_found.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_true(
          act = lists( is_finding = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-return_inconsist )
                       iv_doc     = gc_doc1 )
          msg = 'Return inconsistency listed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an anomaly of an evidence is its own finding (code and severity of the evidence), not aged
  METHOD anomaly_listed_not_aged.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        mo_ev_a->mv_anomaly_doc = gc_doc1.
        DATA(ls_result) = act( ).
        DATA(ls_finding) = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-unexpected_seq ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Severity of the evidence' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = 0 msg = 'Not aged' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an evidence class that does not implement the interface (or raises) is CLEARING_RULE_INVALID;
  " its purpose is not judged, the payment stays in flight (fail closed)
  METHOD unusable_kind_fails_closed.
    TRY.
        add_rule( iv_key = gc_key-d_wire iv_seq = '020' iv_class = 'ZCL_CD_OPS_UTIL' ).
        add_rule( iv_key = gc_key-d_ach iv_seq = '020' iv_class = gc_ev_b ).
        mo_ev_b->mv_fail = abap_true.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc2 iv_pymet = gc_ach iv_valut = gc_friday ).
        INSERT gc_doc1 INTO TABLE mo_ev_a->mt_found.
        INSERT gc_doc2 INTO TABLE mo_ev_a->mt_found.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( FILTER #( ls_result-findings USING KEY primary_key
                                 WHERE check_code = zif_cd_hck_runtime_types=>gc_code-clrrule_invalid ) )
          exp = 2 msg = 'Both unusable kinds reported' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = 1 msg = 'Wire stays in flight' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-d_ach )
                                            exp = 1 msg = 'ACH stays in flight' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an informational row (REQUIRED blank) whose kind is not configured is listed
  " (information) and skipped: the mandatory rows decide
  METHOD info_row_unconfigured_skipped.
    TRY.
        add_rule( iv_key      = gc_key-d_wire
                  iv_seq      = '020'
                  iv_class    = gc_ev_b
                  iv_required = zif_cd_hck_runtime_types=>gc_required-info ).
        mo_ev_b->mv_unconfigured = abap_true.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        INSERT gc_doc1 INTO TABLE mo_ev_a->mt_found.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config ]-severity OPTIONAL )
          exp = zif_cd_ops_types=>gc_severity-info
          msg = 'Not configured: information' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 1 msg = 'Kind A alone decides' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance (design review 2): a valid clearing indicator whose mandatory corroborating source
  " (C) is not configured gives no CLEARED - the purpose is undetermined, the payment stays in
  " flight and is aged, CLEARING_UNDETERMINED lists it, the kind is a configuration warning
  METHOD mandatory_unconfig_no_clear.
    TRY.
        add_rule( iv_key      = gc_key-d_wire
                  iv_seq      = '020'
                  iv_class    = gc_ev_b
                  iv_required = zif_cd_hck_runtime_types=>gc_required-condition ).
        mo_ev_b->mv_unconfigured = abap_true.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_monday ).
        INSERT gc_doc1 INTO TABLE mo_ev_a->mt_found.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 0 msg = 'Never CLEARED on the indicator alone' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = 1 msg = 'Stays in flight' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-undetermined )
                                            exp = 1 msg = 'Counted as undetermined' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-inconsistent )
                                            exp = 0 msg = 'Not an inconsistency' ).
        DATA(ls_finding) = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-undetermined ).
        cl_abap_unit_assert=>assert_true( act = lists( is_finding = ls_finding iv_doc = gc_doc1 )
                                          msg = 'Undetermined payment listed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Undetermined: warning' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config ]-severity OPTIONAL )
          exp = zif_cd_ops_types=>gc_severity-warning
          msg = 'Mandatory kind not configured: configuration warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an indicator (X) of an earlier purpose that cannot be read leaves the payment undetermined:
  " a later purpose (CLEARED) gives no positive conclusion either
  METHOD invalid_indicator_blocks_later.
    TRY.
        add_rule( iv_key     = gc_key-d_wire
                  iv_purpose = zif_cd_hck_runtime_types=>gc_purpose-returned
                  iv_seq     = '010'
                  iv_class   = gc_ev_b ).
        mo_ev_b->mv_fail = abap_true.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        INSERT gc_doc1 INTO TABLE mo_ev_a->mt_found.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 0 msg = 'No CLEARED while RETURNED is undetermined' ).
        cl_abap_unit_assert=>assert_true(
          act = lists( is_finding = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-undetermined )
                       iv_doc     = gc_doc1 )
          msg = 'Listed as undetermined' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-clrrule_invalid ] ) )
          msg = 'The unusable kind is reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Code review 4: every anomaly of an evidence is its own finding, the primary one first
  METHOD every_anomaly_listed.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        mo_ev_a->mv_anomaly_doc = gc_doc1.
        mo_ev_a->mv_more        = abap_true.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_true(
          act = lists( is_finding = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-unexpected_seq )
                       iv_doc     = gc_doc1 )
          msg = 'Primary anomaly listed' ).
        cl_abap_unit_assert=>assert_true(
          act = lists( is_finding = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-pending_overdue )
                       iv_doc     = gc_doc1 )
          msg = 'Further anomaly listed too' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one collect per evidence kind and parameters for all flows / classes (batch, never per payment)
  METHOD one_collect_per_kind.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc2 iv_pymet = gc_ach iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc3 iv_pymet = gc_coll_ach iv_valut = gc_friday iv_collection = abap_true ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_ev_a->mv_calls exp = 1 msg = 'One collect' ).
        cl_abap_unit_assert=>assert_equals( act = mo_ev_a->mv_asked exp = 3 msg = 'For every payment' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a class without a CLEARED rule is not watched (listed), its payments are not read
  METHOD class_without_rule_unwatched.
    TRY.
        DELETE mo_dao->mt_rules WHERE flow = zif_cd_hck_runtime_types=>gc_flow-collection
                                  AND method_class = gc_class-card.
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_card iv_valut = gc_friday iv_collection = abap_true ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-metrics[ dim1 = gc_key-c_card ] ) )
                                           msg = 'Card not measured' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                                                          severity   = zif_cd_ops_types=>gc_severity-info ] ) )
          msg = 'Listed as not monitored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a new class (collection cheques, method Q) is evaluated from configuration rows only:
  " class row, evidence rows of a delivered kind, limits - no code change
  METHOD new_class_by_configuration.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    TRY.
        add_class( iv_flow    = zif_cd_hck_runtime_types=>gc_flow-collection
                   iv_class   = gc_class-cheque
                   iv_methods = 'Q'
                   iv_basis   = zif_cd_hck_runtime_types=>gc_age_basis-issue_date ).
        add_rule( iv_key = gc_key-c_cheque iv_seq = '010' iv_class = 'ZCL_CD_HCK_EV_CHQ_STATUS' iv_param1 = 'B' ).
        limit( iv_key = gc_key-c_cheque iv_amber = 30 iv_red = 45 ).
        add_payment( iv_doc = gc_doc1 iv_pymet = 'Q' iv_laufd = '20260920' iv_collection = abap_true ).
        add_payment( iv_doc = gc_doc2 iv_pymet = 'Q' iv_laufd = '20260920' iv_collection = abap_true ).
        ls_check-doc1r = gc_doc1.
        ls_check-state = 'B'.
        INSERT ls_check INTO TABLE mo_trace->mt_checks.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-c_cheque
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 1 msg = 'Cashed collection cheque cleared' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest
                                                          iv_key    = gc_key-c_cheque )
                                            exp = 52 msg = 'Open one aged in calendar days' ).
        cl_abap_unit_assert=>assert_equals( act = finding( is_result = ls_result iv_key = gc_key-c_cheque )-severity
                                            exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Late beyond its own limits' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User rule 1: wire disbursement cleared = statement line (CHECT = AUGBL) AND DPAYH-ZZ_PAYMENT_STATUS
  " CLEARED; only one of the two = CLEARING_INCONSISTENT
  METHOD rule1_wire_status_and_line.
    TRY.
        seed_rules( ).
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc2 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc3 iv_valut = gc_friday ).
        add_line( iv_chect = '300001' iv_code = '495' ).
        add_line( iv_chect = '300002' iv_code = '495' ).
        INSERT VALUE #( doc1r = gc_doc1 laufd = gc_friday status = 'CLEARED' ) INTO TABLE mo_trace->mt_runs.
        INSERT VALUE #( doc1r = gc_doc2 laufd = gc_friday status = 'SENT' ) INTO TABLE mo_trace->mt_runs.
        INSERT VALUE #( doc1r = gc_doc3 laufd = gc_friday status = 'CLEARED' ) INTO TABLE mo_trace->mt_runs.
        DATA(ls_result) = act( ).
        DATA(ls_finding) = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 1 msg = 'Line and status: cleared' ).
        cl_abap_unit_assert=>assert_true( act = lists( is_finding = ls_finding iv_doc = gc_doc2 )
                                          msg = 'On the statement but status not CLEARED' ).
        cl_abap_unit_assert=>assert_true( act = lists( is_finding = ls_finding iv_doc = gc_doc3 )
                                          msg = 'Status CLEARED but no statement line' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User rule 2: cheque B + statement line (CHECT = last 13 of ZTNUM) cleared; V voided (counted
  " apart); blank open; B without line, blank with line and V with line inconsistent
  METHOD rule2_cheque_b_v_blank.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    TRY.
        seed_rules( ).
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_cheque iv_laufd = '20260801' ).
        add_payment( iv_doc = gc_doc2 iv_pymet = gc_cheque iv_laufd = '20260801' ).
        add_payment( iv_doc = gc_doc3 iv_pymet = gc_cheque iv_laufd = '20260801' ).
        add_payment( iv_doc = gc_doc4 iv_pymet = gc_cheque iv_laufd = '20260801' ).
        add_payment( iv_doc = gc_doc5 iv_pymet = gc_cheque iv_laufd = '20260801' ).
        add_payment( iv_doc = gc_doc6 iv_pymet = gc_cheque iv_laufd = '20260801' ).
        " doc1 B + line, doc2 V, doc3 blank, doc4 B no line, doc5 blank + line, doc6 V + line
        DATA(lt_states) = VALUE string_table( ( `B` ) ( `V` ) ( `` ) ( `B` ) ( `` ) ( `V` ) ).
        DATA(lt_docs) = VALUE string_table( ( CONV #( gc_doc1 ) ) ( CONV #( gc_doc2 ) ) ( CONV #( gc_doc3 ) )
                                            ( CONV #( gc_doc4 ) ) ( CONV #( gc_doc5 ) ) ( CONV #( gc_doc6 ) ) ).
        LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<lv_doc>).
          CLEAR ls_check.
          ls_check-doc1r = <lv_doc>.
          ls_check-state = lt_states[ sy-tabix ].
          ls_check-ztnum = |XX99{ sy-tabix }000000000077|.
          ls_check-hbkid = gc_chq_bank.
          ls_check-hktid = gc_chq_account.
          INSERT ls_check INTO TABLE mo_trace->mt_checks.
        ENDLOOP.
        add_line( iv_chect = '1000000000077' iv_budat = '20260805' ).
        add_line( iv_chect = '5000000000077' iv_budat = '20260805' iv_esnum = 2 ).
        add_line( iv_chect = '6000000000077' iv_budat = '20260805' iv_esnum = 3 ).
        DATA(ls_result) = act( ).
        DATA(ls_finding) = finding( is_result = ls_result
                                    iv_code   = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                    iv_key    = gc_key-d_cheque ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-d_cheque
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 1 msg = 'B with line: cashed' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-d_cheque
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-voided )
                                            exp = 1 msg = 'V without line: voided, counted apart' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-d_cheque )
                                            exp = 1 msg = 'Blank without line: open and aged' ).
        cl_abap_unit_assert=>assert_true( act = lists( is_finding = ls_finding iv_doc = gc_doc4 ) msg = 'B without line' ).
        cl_abap_unit_assert=>assert_true( act = lists( is_finding = ls_finding iv_doc = gc_doc5 ) msg = 'Line, status blank' ).
        cl_abap_unit_assert=>assert_true( act = lists( is_finding = ls_finding iv_doc = gc_doc6 ) msg = 'Line, status V' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User rule 3: collection cleared = lifecycle CLEARED (166) AND BSEG line XREF2 = AUGBL with AUGBL
  " filled; an open BSEG line = CLEARING_INCONSISTENT
  METHOD rule3_collection_xref2.
    DATA ls_gl TYPE zif_cd_hck_runtime_types=>ty_gl_xref2_line.
    TRY.
        seed_rules( ).
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_coll_ach iv_valut = gc_friday iv_collection = abap_true ).
        add_payment( iv_doc = gc_doc2 iv_pymet = gc_coll_ach iv_valut = gc_friday iv_collection = abap_true ).
        add_line( iv_chect = '300001' iv_code = '166' ).
        add_line( iv_chect = '300002' iv_code = '166' iv_esnum = 2 ).
        ls_gl-bukrs = gc_bukrs.
        ls_gl-xref2 = gc_doc1.
        ls_gl-belnr = '0100000001'.
        ls_gl-augbl = '0200000001'.
        INSERT ls_gl INTO TABLE mo_dao->mt_gl_lines.
        ls_gl-xref2 = gc_doc2.
        ls_gl-belnr = '0100000002'.
        CLEAR ls_gl-augbl.
        INSERT ls_gl INTO TABLE mo_dao->mt_gl_lines.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-c_ach
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 1 msg = 'Collected and G/L line cleared' ).
        cl_abap_unit_assert=>assert_true(
          act = lists( is_finding = finding( is_result = ls_result
                                             iv_code   = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                             iv_key    = gc_key-c_ach )
                       iv_doc     = gc_doc2 )
          msg = 'Collected but G/L line open' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User rule 4: ACH disbursement 466 -> 168 with one returns lot item = returned (excluded)
  METHOD rule4_ach_return_with_lot.
    DATA ls_return TYPE zif_cd_ops_trace_types=>ty_return.
    TRY.
        seed_rules( ).
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_ach iv_valut = gc_friday ).
        add_line( iv_chect = '300001' iv_code = '466' iv_budat = gc_friday ).
        add_line( iv_chect = '300001' iv_code = '168' iv_budat = gc_monday iv_esnum = 2 ).
        ls_return-selw1  = gc_doc1.
        ls_return-amount = abs( gc_amount ).
        INSERT ls_return INTO TABLE mo_trace->mt_returns.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-d_ach
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-returned )
                                            exp = 1 msg = 'Consistent return excluded' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Nothing to report' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User rule 4: 466 -> 168 without a returns lot = RETURN_INCONSISTENT (missing returns lot)
  METHOD rule4_ach_return_lot_missing.
    TRY.
        seed_rules( ).
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_ach iv_valut = gc_friday ).
        add_line( iv_chect = '300001' iv_code = '466' iv_budat = gc_friday ).
        add_line( iv_chect = '300001' iv_code = '168' iv_budat = gc_monday iv_esnum = 2 ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_true(
          act = lists( is_finding = finding( is_result = ls_result
                                             iv_code   = zif_cd_hck_runtime_types=>gc_code-return_inconsist
                                             iv_key    = gc_key-d_ach )
                       iv_doc     = gc_doc1 )
          msg = 'Missing returns lot listed' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-d_ach )
                                            exp = 0 msg = 'Listed, not aged' ).
        " The lifecycle kind serves CLEARED and RETURNED rows: the anomaly is listed once
        SPLIT finding( is_result = ls_result
                       iv_code   = zif_cd_hck_runtime_types=>gc_code-return_inconsist
                       iv_key    = gc_key-d_ach )-details AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_lines).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 msg = 'Listed once' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Card (seed rows, REQUIRED C on the Stripe row): while the Stripe settings are not maintained the
  " payment is not cleared on BSEG alone - clearing not determinable, in flight
  METHOD stripe_unconfigured_no_clear.
    DATA ls_gl TYPE zif_cd_hck_runtime_types=>ty_gl_xref2_line.
    TRY.
        seed_rules( ).
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_card iv_valut = gc_friday iv_collection = abap_true ).
        ls_gl-bukrs = gc_bukrs.
        ls_gl-xref2 = gc_doc1.
        ls_gl-augbl = '0200000001'.
        INSERT ls_gl INTO TABLE mo_dao->mt_gl_lines.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-c_card
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 0 msg = 'Not cleared on BSEG alone' ).
        cl_abap_unit_assert=>assert_true(
          act = lists( is_finding = finding( is_result = ls_result
                                             iv_code   = zif_cd_hck_runtime_types=>gc_code-undetermined
                                             iv_key    = gc_key-c_card )
                       iv_doc     = gc_doc1 )
          msg = 'Clearing not determinable: Stripe evidence not configured' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                                                          severity   = zif_cd_ops_types=>gc_severity-warning ] ) )
          msg = 'Stripe evidence not configured: warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Card, explicit configuration choice: Stripe rows informational (REQUIRED blank) while the fields
  " are not maintained - the BSEG XREF2 row alone decides (documented trade-off)
  METHOD stripe_info_switch_bseg_decide.
    DATA ls_gl TYPE zif_cd_hck_runtime_types=>ty_gl_xref2_line.
    TRY.
        seed_rules( ).
        DELETE mo_dao->mt_rules WHERE flow = zif_cd_hck_runtime_types=>gc_flow-collection
                                  AND method_class = gc_class-card AND seq = '020'.
        add_rule( iv_key      = gc_key-c_card
                  iv_seq      = '020'
                  iv_class    = 'ZCL_CD_HCK_EV_STRIPE'
                  iv_param1   = 'STRIPE'
                  iv_required = zif_cd_hck_runtime_types=>gc_required-info ).
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_card iv_valut = gc_friday iv_collection = abap_true ).
        ls_gl-bukrs = gc_bukrs.
        ls_gl-xref2 = gc_doc1.
        ls_gl-augbl = '0200000001'.
        INSERT ls_gl INTO TABLE mo_dao->mt_gl_lines.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-c_card
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = 1 msg = 'BSEG decides by configuration choice' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                                                          severity   = zif_cd_ops_types=>gc_severity-info ] ) )
          msg = 'Stripe evidence not configured: information' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD load_fixtures.
    ro_fixture = NEW #( gc_today ).
    mo_dao->mt_classes  = ro_fixture->classes( ).
    mo_dao->mt_rules    = ro_fixture->rules( ).
    mo_dao->mt_roles    = ro_fixture->roles( ).
    mo_dao->mt_outcomes = ro_fixture->outcomes( ).
    CLEAR: mo_dao->mt_payments, mo_trace->mt_lines, mo_trace->mt_runs, mo_trace->mt_returns, mo_trace->mt_checks.
    LOOP AT ro_fixture->scenarios( ) ASSIGNING FIELD-SYMBOL(<ls_scenario>).
      INSERT LINES OF ro_fixture->issued_payments( <ls_scenario> ) INTO TABLE mo_dao->mt_payments.
      INSERT LINES OF ro_fixture->payment_runs( <ls_scenario> ) INTO TABLE mo_trace->mt_runs.
      INSERT LINES OF <ls_scenario>-lines INTO TABLE mo_trace->mt_lines.
      INSERT LINES OF <ls_scenario>-returns INTO TABLE mo_trace->mt_returns.
      INSERT LINES OF <ls_scenario>-checks INTO TABLE mo_trace->mt_checks.
    ENDLOOP.
  ENDMETHOD.


  " Shared fixture: 466 -> 166 without returns lot is excluded as RETRIEVED, never as RETURNED
  METHOD fixture_retrieval_not_return.
    TRY.
        load_fixtures( ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-d_ach
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-retrieved )
                                            exp = 1 msg = 'Retrieval excluded as RETRIEVED' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-d_ach
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-returned )
                                            exp = 0 msg = 'Not counted as a return' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture: the wire's statement line without DPAYH status CLEARED is CLEARING_INCONSISTENT
  METHOD fixture_line_not_cleared.
    TRY.
        DATA(lo_fixture) = load_fixtures( ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_true(
          act = lists( is_finding = finding( is_result = ls_result
                                             iv_code   = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                             iv_key    = gc_key-d_wire )
                       iv_doc     = lo_fixture->scenario( zcl_cd_ops_pay_fixture=>gc_scenario-bank_line )-augbl )
          msg = 'Line without clearing listed as inconsistent' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture: a wire paid in two DPAYH runs is cleared (both run rows of the window excluded)
  METHOD fixture_two_runs_cleared.
    TRY.
        DATA(lo_fixture) = load_fixtures( ).
        DATA(ls_result) = act( ).
        DATA(lv_cleared) = 0.
        DATA(lv_in_flight) = 0.
        LOOP AT lo_fixture->scenarios( ) ASSIGNING FIELD-SYMBOL(<ls_scenario>) WHERE pymet = zcl_cd_ops_pay_fixture=>gc_wire.
          CASE <ls_scenario>-evaluated.
            WHEN zif_cd_ops_payout_types=>gc_outcome-cleared.
              lv_cleared = lv_cleared + lines( <ls_scenario>-runs ).
            WHEN zif_cd_ops_payout_types=>gc_outcome-in_flight.
              lv_in_flight = lv_in_flight + lines( <ls_scenario>-runs ).
          ENDCASE.
        ENDLOOP.
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-cleared )
                                            exp = lv_cleared msg = 'Every cleared wire run row excluded' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = lv_in_flight msg = 'Only the wire whose status is not updated in flight' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture (2026-11-08): the wire return with status RETURNED is excluded as RETURNED
  METHOD fixture_returned_excluded.
    TRY.
        load_fixtures( ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-d_wire
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-returned )
                                            exp = 1 msg = 'Returned wire excluded as RETURNED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture (2026-11-08): returned on the bank, DPAYH status still CONFIRMED - in flight (aged),
  " never RETURN_INCONSISTENT
  METHOD fixture_return_lag_in_flight.
    TRY.
        DATA(lo_fixture) = load_fixtures( ).
        DATA(ls_result) = act( ).
        DATA(lv_doc) = lo_fixture->scenario( zcl_cd_ops_pay_fixture=>gc_scenario-return_lag )-augbl.
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-d_wire )
                                            exp = 1 msg = 'The return whose status lags stays in flight' ).
        cl_abap_unit_assert=>assert_false(
          act = lists( is_finding = finding( is_result = ls_result
                                             iv_code   = zif_cd_hck_runtime_types=>gc_code-return_inconsist
                                             iv_key    = gc_key-d_wire )
                       iv_doc     = lv_doc )
          msg = 'Not listed as RETURN_INCONSISTENT' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture (user decision 2026-11-08): V without STOPPED, STOPPED with state blank, STOPPED and
  " V - all three excluded as VOIDED
  METHOD fixture_cheques_voided.
    TRY.
        load_fixtures( ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                                          iv_key    = gc_key-d_cheque
                                                          iv_dim2   = zif_cd_hck_runtime_types=>gc_purpose-voided )
                                            exp = 3 msg = 'Voided and stopped cheques excluded as VOIDED' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-d_cheque )
                                            exp = 0 msg = 'No cheque in flight' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture (user decision 2026-11-08): a stopped cheque that was cashed is listed in
  " CLEARING_INCONSISTENT and the detail says "stopped cheque cashed"
  METHOD fixture_stopped_cashed.
    TRY.
        DATA(lo_fixture) = load_fixtures( ).
        DATA(ls_result) = act( ).
        DATA(ls_finding) = finding( is_result = ls_result
                                    iv_code   = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                    iv_key    = gc_key-d_cheque ).
        cl_abap_unit_assert=>assert_true(
          act = lists( is_finding = ls_finding
                       iv_doc     = lo_fixture->scenario( zcl_cd_ops_pay_fixture=>gc_scenario-chq_stop_cash )-augbl )
          msg = 'Stopped cheque cashed listed' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_finding-details
                                                               sub = zcl_cd_ops_pay_fixture=>gc_stopped_cashed ) >= 0 )
                                          msg = 'Detail: stopped cheque cashed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Status lag (b): the 195 of the wire return is on yesterday's statement, DPAYH still CONFIRMED at
  " 08:00 today - more than 120 minutes after the end of the line's day: one PAY_STATUS_LAG (W) for that
  " payment only (decided payments never lag), metric per flow + class
  METHOD lag_after_grace_reported.
    TRY.
        DATA(lo_fixture) = load_fixtures( ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        DATA(lv_doc) = lo_fixture->scenario( zcl_cd_ops_pay_fixture=>gc_scenario-return_lag )-augbl.
        DATA(lt_lag) = VALUE zif_cd_ops_types=>tt_finding( ).
        LOOP AT ls_result-findings ASSIGNING FIELD-SYMBOL(<ls_finding>)
             WHERE check_code = zif_cd_hck_runtime_types=>gc_code-status_lag.
          INSERT <ls_finding> INTO TABLE lt_lag.
        ENDLOOP.
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lag ) exp = 1 msg = 'One lagging payment in the fixtures' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lag[ 1 ]-reference exp = CONV zif_cd_ops_types=>ty_reference( lv_doc )
                                            msg = 'The return whose status lags' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lag[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Warning' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = lt_lag[ 1 ]-message
                                                               sub = condense( gc_status-confirmed ) ) >= 0 )
                                          msg = 'The status that did not follow is named' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-status_lag
                                                          iv_key    = gc_key-d_wire )
                                            exp = 1 msg = 'Metric DWIR' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-status_lag
                                                          iv_key    = gc_key-d_cheque )
                                            exp = 0 msg = 'Zero is measured' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Status lag (b) within the grace (HCK_PAY_STATUS_LAG_MIN 600: limit yesterday 22:00): nothing reported,
  " the payment stays in flight
  METHOD lag_within_grace_silent.
    TRY.
        mo_params->set( iv_name = zif_cd_hck_runtime_types=>gc_param-status_lag_min iv_value = '600' ).
        load_fixtures( ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-findings[
                                                            check_code = zif_cd_hck_runtime_types=>gc_code-status_lag ] ) )
                                           msg = 'Within the grace: no lag' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-d_wire )
                                            exp = 1 msg = 'Still in flight' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD add_acked_wire.
    add_payment( iv_doc = iv_doc iv_valut = gc_today ).
    INSERT VALUE #( doc1r = iv_doc laufd = gc_friday status = iv_status ) INTO TABLE mo_trace->mt_runs.
    IF iv_ack_status IS SUPPLIED.
      INSERT VALUE #( key1    = iv_doc
                      status  = iv_ack_status
                      ev_date = iv_ack_date
                      ev_time = iv_ack_time ) INTO TABLE mo_trace->mt_acks.
    ENDIF.
  ENDMETHOD.


  " Status lag (a): the bank ACK of a disbursement (payment-level ACK source of the payment trace) is
  " older than the grace and DPAYH still says ISSUED - reported; an ACK inside the grace, a payment
  " already CONFIRMED and a NACK are not; one ACK read for all
  METHOD ack_lag_after_grace.
    TRY.
        mo_params->set( iv_name = zif_cd_ops_trace_types=>gc_param-src_ack iv_value = gc_ack_spec ).
        add_acked_wire( iv_doc = gc_doc1 iv_status = gc_status-issued iv_ack_status = gc_status-ack
                        iv_ack_date = gc_holiday iv_ack_time = '100000' ).
        add_acked_wire( iv_doc = gc_doc2 iv_status = gc_status-issued iv_ack_status = gc_status-ack
                        iv_ack_date = gc_today iv_ack_time = '073000' ).
        add_acked_wire( iv_doc = gc_doc3 iv_status = gc_status-confirmed iv_ack_status = gc_status-ack
                        iv_ack_date = gc_holiday iv_ack_time = '100000' ).
        add_acked_wire( iv_doc = gc_doc4 iv_status = gc_status-issued iv_ack_status = gc_status-nack
                        iv_ack_date = gc_holiday iv_ack_time = '100000' ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        DATA(lt_lag) = VALUE zif_cd_ops_types=>tt_finding( ).
        LOOP AT ls_result-findings ASSIGNING FIELD-SYMBOL(<ls_finding>)
             WHERE check_code = zif_cd_hck_runtime_types=>gc_code-status_lag.
          INSERT <ls_finding> INTO TABLE lt_lag.
        ENDLOOP.
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lag ) exp = 1 msg = 'Only the old ACK with status ISSUED' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lag[ 1 ]-reference exp = CONV zif_cd_ops_types=>ty_reference( gc_doc1 )
                                            msg = 'Payment 1' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_ack_reads exp = 1 msg = 'One ACK read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Status lag (a) without a configured ACK source: said once as information, nothing judged, no read
  METHOD ack_source_unconfigured.
    TRY.
        add_acked_wire( iv_doc = gc_doc1 iv_status = gc_status-issued ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        DATA(lv_key) = CONV zif_cd_ops_types=>ty_object_key( |{ gc_check }/{ zif_cd_hck_runtime_types=>gc_code-status_lag }/| &&
                                                             |{ zif_cd_ops_trace_types=>gc_param-src_ack }| ).
        DATA(ls_info) = VALUE #( ls_result-findings[ object_key = lv_key ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_info-check_code exp = zif_cd_hck_runtime_types=>gc_code-inflight_config
                                            msg = 'ACK source not configured: configuration finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_info-severity exp = zif_cd_ops_types=>gc_severity-info
                                            msg = 'Information' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-findings[
                                                            check_code = zif_cd_hck_runtime_types=>gc_code-status_lag ] ) )
                                           msg = 'No lag without ACK evidence' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_ack_reads exp = 0 msg = 'No read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD add_collection.
    add_payment( iv_doc        = iv_doc
                 iv_pymet      = gc_coll_ach
                 iv_valut      = gc_today
                 iv_collection = abap_true
                 iv_hbkid      = gc_pnc
                 iv_laufi      = iv_laufi ).
    INSERT VALUE #( doc1r = iv_doc laufd = gc_friday laufi = iv_laufi status = iv_status ) INTO TABLE mo_trace->mt_runs.
  ENDMETHOD.


  METHOD add_file.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_group_ack.
    ls_file-file_id        = CONV zif_cd_fmon_types=>ty_file_id( iv_id ).
    ls_file-iface_id       = gc_coll_iface.
    ls_file-gen_group      = iv_group.
    ls_file-file_ref       = |ACH_COLL_FILE_{ iv_id }|.
    ls_file-file_name      = |ACH_COLL_FILE_{ iv_id }.txt|.
    ls_file-first_event_at = iv_first.
    ls_file-ack_at         = iv_ack.
    INSERT ls_file INTO TABLE mo_fmon->mt_acks.
  ENDMETHOD.


  METHOD local_ts.
    CONVERT DATE iv_date TIME iv_time INTO TIME STAMP rv_ts TIME ZONE sy-zonlo.
  ENDMETHOD.


  METHOD lags.
    LOOP AT is_result-findings ASSIGNING FIELD-SYMBOL(<ls_finding>)
         WHERE check_code = zif_cd_hck_runtime_types=>gc_code-status_lag.
      INSERT <ls_finding> INTO TABLE rt_lag.
    ENDLOOP.
  ENDMETHOD.


  " File-level ACK (user 2026-11-08: collections are acknowledged per file): the file of the payment's run
  " (generation group run date / run ID / house bank, built as FMON builds it) was acknowledged yesterday
  " 10:00, the status still says ISSUED at 08:00 today - one PAY_STATUS_LAG (W); one FMON read, only the
  " interface acknowledged per file
  METHOD file_ack_lag_after_grace.
    TRY.
        add_collection( iv_doc = gc_doc1 iv_status = gc_status-issued iv_laufi = gc_run_a ).
        add_file( iv_id    = 1
                  iv_group = gc_group_a
                  iv_first = local_ts( iv_date = gc_holiday iv_time = '080000' )
                  iv_ack   = local_ts( iv_date = gc_holiday iv_time = '100000' ) ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        DATA(lt_lag) = lags( ls_result ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lag ) exp = 1 msg = 'One lagging collection' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lag[ 1 ]-reference exp = CONV zif_cd_ops_types=>ty_reference( gc_doc1 )
                                            msg = 'The collection whose status lags' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lag[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Warning' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = lt_lag[ 1 ]-message sub = condense( gc_status-issued ) ) >= 0 )
                                          msg = 'The status that did not follow is named' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = lt_lag[ 1 ]-details sub = `ACH_COLL_FILE_1.txt` ) >= 0 )
                                          msg = 'The acknowledged file is named' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-status_lag
                                                          iv_key    = gc_key-c_ach )
                                            exp = 1 msg = 'Metric CACH' ).
        cl_abap_unit_assert=>assert_equals( act = mo_fmon->mv_reads exp = 1 msg = 'One FMON read' ).
        cl_abap_unit_assert=>assert_equals( act = mo_fmon->mt_keys
                                            exp = VALUE zif_cd_fmon_types=>tt_group_key( ( iface_id  = gc_coll_iface
                                                                                           gen_group = gc_group_a ) )
                                            msg = 'Group key as FMON builds it, file-level interface only' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_ack_reads exp = 0 msg = 'No payment-level ACK read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " File-level ACK today 07:30, report 08:00 (grace 120 min): nothing reported
  METHOD file_ack_within_grace.
    TRY.
        add_collection( iv_doc = gc_doc1 iv_status = gc_status-issued iv_laufi = gc_run_a ).
        add_file( iv_id    = 1
                  iv_group = gc_group_a
                  iv_first = local_ts( iv_date = gc_today iv_time = '060000' )
                  iv_ack   = local_ts( iv_date = gc_today iv_time = '073000' ) ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        cl_abap_unit_assert=>assert_initial( act = lags( ls_result ) msg = 'Within the grace: no lag' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-status_lag
                                                          iv_key    = gc_key-c_ach )
                                            exp = 0 msg = 'Zero is measured' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The status already followed the file ACK (CONFIRMED): no candidate, no FMON read, no lag
  METHOD file_ack_confirmed_silent.
    TRY.
        add_collection( iv_doc = gc_doc1 iv_status = gc_status-confirmed iv_laufi = gc_run_a ).
        add_file( iv_id    = 1
                  iv_group = gc_group_a
                  iv_first = local_ts( iv_date = gc_holiday iv_time = '080000' )
                  iv_ack   = local_ts( iv_date = gc_holiday iv_time = '100000' ) ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        cl_abap_unit_assert=>assert_initial( act = lags( ls_result ) msg = 'Status CONFIRMED: no lag' ).
        cl_abap_unit_assert=>assert_equals( act = mo_fmon->mv_reads exp = 0 msg = 'No FMON read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Regenerated files (FMON rule 9): run A - file 1 failed and was replaced by file 2, acknowledged
  " yesterday 10:00: the lag names file 2. Run B - file 3 has an old ACK but was replaced by file 4
  " that has no ACK yet: a replaced file never counts and no ACK at all is FMON's finding - no lag
  METHOD file_ack_replaced_ignored.
    TRY.
        add_collection( iv_doc = gc_doc1 iv_status = gc_status-issued iv_laufi = gc_run_a ).
        add_collection( iv_doc = gc_doc2 iv_status = gc_status-issued iv_laufi = gc_run_b ).
        add_file( iv_id = 1 iv_group = gc_group_a iv_first = local_ts( iv_date = gc_holiday iv_time = '080000' ) ).
        add_file( iv_id    = 2
                  iv_group = gc_group_a
                  iv_first = local_ts( iv_date = gc_holiday iv_time = '090000' )
                  iv_ack   = local_ts( iv_date = gc_holiday iv_time = '100000' ) ).
        add_file( iv_id    = 3
                  iv_group = gc_group_b
                  iv_first = local_ts( iv_date = gc_holiday iv_time = '080000' )
                  iv_ack   = local_ts( iv_date = gc_holiday iv_time = '090000' ) ).
        add_file( iv_id = 4 iv_group = gc_group_b iv_first = local_ts( iv_date = gc_holiday iv_time = '110000' ) ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        DATA(lt_lag) = lags( ls_result ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lag ) exp = 1 msg = 'Only run A lags' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lag[ 1 ]-reference exp = CONV zif_cd_ops_types=>ty_reference( gc_doc1 )
                                            msg = 'Payment of run A' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = lt_lag[ 1 ]-details sub = `ACH_COLL_FILE_2.txt` ) >= 0 )
                                          msg = 'The regenerated file decides' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( find( val = lt_lag[ 1 ]-details sub = `ACH_COLL_FILE_1.txt` ) >= 0 )
                                           msg = 'The replaced file is not named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " GROUP_FIELDS not configured on the source: the file-level case is not evaluable - one INFLIGHT_CONFIG
  " W for the run, no lag, no FMON group read
  METHOD file_ack_group_unconfigured.
    TRY.
        CLEAR mo_fmon->mt_sources.
        DATA(ls_src) = VALUE zif_cd_fmon_types=>ty_src( ).
        ls_src-src_id = gc_regut.
        ls_src-active = abap_true.
        INSERT ls_src INTO TABLE mo_fmon->mt_sources.
        add_collection( iv_doc = gc_doc1 iv_status = gc_status-issued iv_laufi = gc_run_a ).
        add_collection( iv_doc = gc_doc2 iv_status = gc_status-issued iv_laufi = gc_run_b ).
        add_file( iv_id    = 1
                  iv_group = gc_group_a
                  iv_first = local_ts( iv_date = gc_holiday iv_time = '080000' )
                  iv_ack   = local_ts( iv_date = gc_holiday iv_time = '100000' ) ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        DATA(lv_key) = CONV zif_cd_ops_types=>ty_object_key( |{ gc_check }/{ zif_cd_hck_runtime_types=>gc_code-status_lag }/| &&
                                                             |{ zif_cd_hck_runtime_types=>gc_param-ack_file_src }| ).
        DATA(lv_count) = 0.
        LOOP AT ls_result-findings TRANSPORTING NO FIELDS WHERE object_key = lv_key.
          lv_count = lv_count + 1.
        ENDLOOP.
        cl_abap_unit_assert=>assert_equals( act = lv_count exp = 1 msg = 'One configuration finding for the run' ).
        DATA(ls_config) = ls_result-findings[ object_key = lv_key ].
        cl_abap_unit_assert=>assert_equals( act = ls_config-check_code exp = zif_cd_hck_runtime_types=>gc_code-inflight_config
                                            msg = 'Configuration finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_config-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Not evaluable: warning' ).
        cl_abap_unit_assert=>assert_initial( act = lags( ls_result ) msg = 'No lag without the link' ).
        cl_abap_unit_assert=>assert_equals( act = mo_fmon->mv_reads exp = 0 msg = 'No group read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Two payment runs, each with its own file: run A acknowledged yesterday (lag), run B today 07:30
  " (within the grace) - judged per run, one FMON read for both groups
  METHOD file_ack_two_runs_apart.
    TRY.
        add_collection( iv_doc = gc_doc1 iv_status = gc_status-issued iv_laufi = gc_run_a ).
        add_collection( iv_doc = gc_doc2 iv_status = gc_status-issued iv_laufi = gc_run_b ).
        add_file( iv_id    = 1
                  iv_group = gc_group_a
                  iv_first = local_ts( iv_date = gc_holiday iv_time = '080000' )
                  iv_ack   = local_ts( iv_date = gc_holiday iv_time = '100000' ) ).
        add_file( iv_id    = 2
                  iv_group = gc_group_b
                  iv_first = local_ts( iv_date = gc_today iv_time = '060000' )
                  iv_ack   = local_ts( iv_date = gc_today iv_time = '073000' ) ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        DATA(lt_lag) = lags( ls_result ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lag ) exp = 1 msg = 'Only run A lags' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lag[ 1 ]-reference exp = CONV zif_cd_ops_types=>ty_reference( gc_doc1 )
                                            msg = 'Payment of run A' ).
        cl_abap_unit_assert=>assert_equals( act = mo_fmon->mv_reads exp = 1 msg = 'One FMON read' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_fmon->mt_keys ) exp = 2 msg = 'Both groups in it' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Configuration decides the ACK per class: a wire (DWIR, per payment: TRACE_SRC_ACK) and a collection
  " (CACH, per file: FMON) in one run - both lag, each by its own ACK, one read of each source
  METHOD ack_levels_in_one_run.
    TRY.
        mo_params->set( iv_name = zif_cd_ops_trace_types=>gc_param-src_ack iv_value = gc_ack_spec ).
        add_acked_wire( iv_doc = gc_doc1 iv_status = gc_status-issued iv_ack_status = gc_status-ack
                        iv_ack_date = gc_holiday iv_ack_time = '100000' ).
        add_collection( iv_doc = gc_doc2 iv_status = gc_status-issued iv_laufi = gc_run_a ).
        add_file( iv_id    = 1
                  iv_group = gc_group_a
                  iv_first = local_ts( iv_date = gc_holiday iv_time = '080000' )
                  iv_ack   = local_ts( iv_date = gc_holiday iv_time = '100000' ) ).
        DATA(ls_result) = act( iv_time = gc_morning ).
        cl_abap_unit_assert=>assert_equals( act = lines( lags( ls_result ) ) exp = 2 msg = 'Both lag' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-status_lag
                                                          iv_key    = gc_key-d_wire )
                                            exp = 1 msg = 'Wire by its payment-level ACK' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-status_lag
                                                          iv_key    = gc_key-c_ach )
                                            exp = 1 msg = 'Collection by its file ACK' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_ack_reads exp = 1 msg = 'One payment-level ACK read' ).
        cl_abap_unit_assert=>assert_equals( act = mo_fmon->mv_reads exp = 1 msg = 'One FMON read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Agreement: what the check excludes / lists per fixture is the evaluator's canonical outcome
  METHOD fixture_agrees_with_outcome.
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    TRY.
        DATA(lo_fixture) = load_fixtures( ).
        DATA(ls_result) = act( ).
        LOOP AT lo_fixture->scenarios( ) ASSIGNING FIELD-SYMBOL(<ls_scenario>).
          INSERT <ls_scenario>-augbl INTO TABLE lt_docno.
        ENDLOOP.
        DATA(lo_outcome) = zcl_cd_ops_factory=>get_pay_outcome( ).
        lo_outcome->load( iv_context = gc_check iv_max_rows = 1000 ).
        DATA(ls_evaluation) = lo_outcome->evaluate_documents( lt_docno ).
        LOOP AT lo_fixture->scenarios( ) ASSIGNING <ls_scenario>.
          DATA(ls_verdict) = ls_evaluation-verdicts[ KEY by_doc doc1r = <ls_scenario>-augbl ].
          cl_abap_unit_assert=>assert_equals( act = ls_verdict-outcome exp = <ls_scenario>-evaluated
                                              msg = |{ <ls_scenario>-id }: evaluator outcome| ).
          CASE ls_verdict-status.
            WHEN zif_cd_ops_payout_types=>gc_status-inconsistent.
              cl_abap_unit_assert=>assert_true(
                act = lists( is_finding = finding( is_result = ls_result
                                                   iv_code   = ls_verdict-finding
                                                   iv_key    = |{ ls_verdict-flow }{ ls_verdict-class }| )
                             iv_doc     = <ls_scenario>-augbl )
                msg = |{ <ls_scenario>-id }: listed by the check| ).
            WHEN zif_cd_ops_payout_types=>gc_status-open.
              cl_abap_unit_assert=>assert_true(
                act = xsdbool( metric( is_result = ls_result
                                       iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                       iv_key    = |{ ls_verdict-flow }{ ls_verdict-class }| ) > 0 )
                msg = |{ <ls_scenario>-id }: in flight in the check| ).
            WHEN OTHERS.
              cl_abap_unit_assert=>assert_true(
                act = xsdbool( metric( is_result = ls_result
                                       iv_metric = zcl_cd_hck_c_inflight=>gc_metric-excluded
                                       iv_key    = |{ ls_verdict-flow }{ ls_verdict-class }|
                                       iv_dim2   = ls_verdict-purpose ) > 0 )
                msg = |{ <ls_scenario>-id }: excluded by the check as { ls_verdict-purpose }| ).
          ENDCASE.
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
