*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_trace_engine.clas.testclasses.abap
*& Purpose:
*& Tests of the 360 degree payment trace with an LTD read-repository double
*& injected through the core injector: full ACH and cheque chains, reversed
*& item with clearing-reset history (two attempts, bank evidence under the
*& original clearing reference), reversal without history, multiple
*& matches, incomplete bank evidence, unconfigured sources and an
*& unauthorised company code. Written before the engine changes. Does not
*& prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (360 degree payment trace).
*& 2026-11-06 | Return / NOC reasons: return reason RLGRD shown (current and historical clearing),
*&            | different reasons AMBIGUOUS; NOC evidence by clearing document / payment reference,
*&            | not found = NOT_APPLICABLE, never changes the verdict. Full chain lists the NOC row.
*& 2026-11-06 | Modern-syntax sweep: string templates.
*& 2026-11-07 | Parameters from the shared fake ZCL_CD_OPS_PARAMS_MEM (ZCL_CD_OPS_INJECTOR=>INJECT_PARAMS)
*&            | instead of a hand-written store double: the semantics of ZCL_CA_OPS_STORE.
*& 2026-11-07 | Parameters over ZCA_PARAM (ZCL_CD_OPS_PARAM_SEED) instead of ZCL_CD_OPS_PARAMS_MEM.
*& 2026-11-07 | Bank lines carry their statement account; a cheque number on another house bank
*&            | account is not the cheque's encashment (shared cheque link, design review).
*& 2026-11-07 | Canonical outcome: the evidence-chain tests inject an evaluator without verdict;
*&            | ltc_outcome traces the shared fixtures (ZCL_CD_OPS_PAY_FIXTURE) with the real
*&            | evaluator - retrieval, bank line without clearing, two runs, FIN in two sources.
*& 2026-11-08 | Table consolidation: runtime DAO double without get_evidence_settings (Stripe settings are
*&            | ZCA_PARAM parameters HCK_STRIPE_*, delivered blank = not configured).
*& 2026-11-08 | Table consolidation: runtime DAO double without get_pm_banks (house-bank calendars are
*&            | ZCD_HCK_PMCLASS rows).
*& 2026-11-08 | Payment worklist: request rule double (stage REQUEST_DUE shown as information), search by payment
*&            | reference (cheque number, payment document).
*& 2026-11-10 | bad_source_field_is_reported: CONFIGURATION row instead of a silently lost filter.
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao.
    TYPES:
      BEGIN OF ty_cfg,
        param TYPE zif_ca_ops_types=>ty_param_name,
        row   TYPE zif_cd_ops_trace_types=>ty_cfg_row,
      END OF ty_cfg.
    DATA mt_cfg TYPE STANDARD TABLE OF ty_cfg WITH EMPTY KEY.
    DATA mt_partners_src TYPE zif_cd_ops_trace_types=>tt_partner.
    DATA mt_partners TYPE zif_cd_ops_trace_types=>tt_partner.
    DATA mt_items TYPE zif_cd_ops_trace_types=>tt_item.
    DATA mt_headers TYPE zif_cd_ops_trace_types=>tt_doc_header.
    DATA mt_runs TYPE zif_cd_ops_trace_types=>tt_payment_run.
    DATA mt_checks TYPE zif_cd_ops_trace_types=>tt_check.
    DATA mt_bank TYPE zif_cd_ops_trace_types=>tt_bank_line.
    DATA mt_returns TYPE zif_cd_ops_trace_types=>tt_return.
    DATA mt_retrievals TYPE zif_cd_ops_trace_types=>tt_retrieval.
    DATA mt_files TYPE zif_cd_ops_trace_types=>tt_fmon_file.
    DATA mt_events TYPE zif_cd_ops_trace_types=>tt_fmon_event.
    DATA mt_sumc TYPE zif_cd_ops_trace_types=>tt_fikey.
    DATA mt_gl_docs TYPE zif_cd_ops_trace_types=>tt_gl_doc.
    DATA mt_gl_lines TYPE zif_cd_ops_trace_types=>tt_gl_line.
    DATA mv_kind TYPE zif_cd_ops_trace_types=>ty_kind.
    DATA mt_noc TYPE zif_cd_ops_trace_types=>tt_noc.
    "! The partner read by source field fails (field not in BUT000)
    DATA mv_source_field_fails TYPE abap_bool.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~read_configured.
    LOOP AT mt_cfg INTO DATA(ls_cfg) WHERE param = is_source-param AND row-key1 = is_key-key1.
      IF iv_match_key2 = abap_true AND is_source-key2_field IS NOT INITIAL AND ls_cfg-row-key2 <> is_key-key2.
        CONTINUE.
      ENDIF.
      IF lines( rt_rows ) >= iv_max_rows.
        RETURN.
      ENDIF.
      INSERT ls_cfg-row INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~read_configured_set.
    LOOP AT mt_cfg INTO DATA(ls_cfg) WHERE param = is_source-param.
      IF line_exists( it_keys[ table_line = ls_cfg-row-key1 ] ).
        INSERT ls_cfg-row INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~read_configured_after.
    CLEAR rt_rows.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_partners.
    IF mv_source_field_fails = abap_true AND iv_source_field IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e201(zcd_ops) WITH iv_source_field 'BUT000'.
    ENDIF.
    rt_partners = COND #( WHEN iv_source_field IS NOT INITIAL THEN mt_partners_src ELSE mt_partners ).
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_items_by_fin.
    rt_items = VALUE #( FOR ls IN mt_items WHERE ( fin = iv_fin ) ( ls ) ).
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_items_by_clearing.
    rt_items = VALUE #( FOR ls IN mt_items WHERE ( augbl = iv_augbl ) ( ls ) ).
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_doc_headers.
    LOOP AT mt_headers INTO DATA(ls_header).
      IF line_exists( it_docno[ table_line = ls_header-opbel ] ).
        INSERT ls_header INTO TABLE rt_headers.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_payment_runs.
    LOOP AT mt_runs INTO DATA(ls_run).
      IF line_exists( it_docno[ table_line = ls_run-doc1r ] ).
        INSERT ls_run INTO TABLE rt_runs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_checks_by_doc.
    LOOP AT mt_checks INTO DATA(ls_check).
      IF line_exists( it_docno[ table_line = ls_check-doc1r ] ).
        INSERT ls_check INTO TABLE rt_checks.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_checks_by_number.
    rt_checks = VALUE #( FOR ls IN mt_checks WHERE ( ztnum = iv_ztnum ) ( ls ) ).
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_bank_lines.
    LOOP AT mt_bank INTO DATA(ls_line) WHERE budat >= iv_from.
      IF line_exists( it_ref[ table_line = ls_line-chect ] ).
        INSERT ls_line INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_returns.
    LOOP AT mt_returns INTO DATA(ls_return).
      IF line_exists( it_docno[ table_line = ls_return-selw1 ] ).
        INSERT ls_return INTO TABLE rt_returns.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_retrievals.
    LOOP AT mt_retrievals INTO DATA(ls_rtrv).
      IF line_exists( it_docno[ table_line = ls_rtrv-augbl ] ).
        INSERT ls_rtrv INTO TABLE rt_retrievals.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_fmon_files.
    LOOP AT mt_files INTO DATA(ls_file) WHERE business_date BETWEEN iv_from AND iv_to.
      IF line_exists( it_file_ref[ table_line = ls_file-file_ref ] ).
        INSERT ls_file INTO TABLE rt_files.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_fmon_events.
    LOOP AT mt_events INTO DATA(ls_event).
      IF line_exists( it_file_id[ table_line = ls_event-file_id ] ).
        INSERT ls_event INTO TABLE rt_events.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_summary_keys.
    LOOP AT mt_sumc INTO DATA(ls_key).
      IF line_exists( it_fikey[ fikey = ls_key-fikey bukrs = ls_key-bukrs ] ).
        INSERT ls_key INTO TABLE rt_fikey.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_gl_documents.
    LOOP AT mt_gl_docs INTO DATA(ls_doc).
      IF line_exists( it_fikey[ fikey = ls_doc-awkey bukrs = ls_doc-bukrs ] ) AND iv_awtyp IS NOT INITIAL.
        INSERT ls_doc INTO TABLE rt_docs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_gl_clearing_lines.
    LOOP AT mt_gl_lines INTO DATA(ls_line) WHERE xref2 = iv_xref2.
      IF line_exists( it_keys[ bukrs = ls_line-bukrs belnr = ls_line-belnr gjahr = ls_line-gjahr ] ).
        INSERT ls_line INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_method_kind.
    rv_kind = mv_kind.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_noc_items.
    " As the database: exact INFOF values only
    LOOP AT mt_noc ASSIGNING FIELD-SYMBOL(<ls_noc>).
      IF line_exists( it_infof[ table_line = <ls_noc>-infof ] ).
        INSERT <ls_noc> INTO TABLE rt_items.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
    DATA mt_denied TYPE STANDARD TABLE OF bukrs WITH EMPTY KEY.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~is_allowed.
    rv_allowed = xsdbool( NOT line_exists( mt_denied[ table_line = iv_bukrs ] ) ).
  ENDMETHOD.
ENDCLASS.


"! Evaluator double of the evidence-chain tests: no verdict (OUTCOME row NOT_APPLICABLE, verdict unchanged)
"! Request rule double: the due date and stage of the requests of the scenario
CLASS ltd_request DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_request PARTIALLY IMPLEMENTED.
    DATA mt_requests TYPE zif_cd_ops_payout_types=>tt_request.
ENDCLASS.

CLASS ltd_request IMPLEMENTATION.
  METHOD zif_cd_ops_pay_request~evaluate.
    LOOP AT mt_requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      IF line_exists( it_keys[ fin = <ls_request>-fin source = <ls_request>-source ] ).
        INSERT <ls_request> INTO TABLE rt_requests.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_no_outcome DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_outcome PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_no_outcome IMPLEMENTATION.
  METHOD zif_cd_ops_pay_outcome~load.
    CLEAR rs_config.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome~evaluate_documents.
    CLEAR rs_evaluation.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome~sources_of.
    CLEAR rt_sources.
  ENDMETHOD.
ENDCLASS.



CLASS ltc_trace DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES ty_status TYPE zif_cd_ops_trace_types=>ty_status.
    TYPES tt_status TYPE STANDARD TABLE OF ty_status WITH EMPTY KEY.

    "! Scenario intent; the base scenario is a fully evidenced ACH disbursement
    TYPES:
      BEGIN OF ty_flags,
        cheque            TYPE abap_bool,
        reissued          TYPE abap_bool,
        reversal_no_hist  TYPE abap_bool,
        two_success       TYPE abap_bool,
        failed_after_ok   TYPE abap_bool,
        two_bank_lines    TYPE abap_bool,
        no_ack            TYPE abap_bool,
        nack              TYPE abap_bool,
        no_bank_line      TYPE abap_bool,
        no_history_cfg    TYPE abap_bool,
        no_regut_cfg      TYPE abap_bool,
        no_chq_hist_cfg   TYPE abap_bool,
        unauthorised      TYPE abap_bool,
        partner_mismatch  TYPE abap_bool,
        partner_legacy    TYPE abap_bool,
        "! Returns lot item on the current clearing (with return reason RLGRD)
        returned          TYPE abap_bool,
        "! A second returns lot item with another return reason
        two_reasons       TYPE abap_bool,
        "! NOC lot item whose INFOF holds the clearing document / the FIN (payment reference)
        noc_by_augbl      TYPE abap_bool,
        noc_by_fin        TYPE abap_bool,
        "! The cheque number is on a statement of another house bank account
        cheque_other_acct TYPE abap_bool,
      END OF ty_flags.

    CONSTANTS:
      BEGIN OF gc,
        fin        TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0001',
        source     TYPE zif_cd_ops_trace_types=>ty_source VALUE 'PCLM',
        member     TYPE zif_cd_ops_trace_types=>ty_key_value VALUE '123456789',
        partner    TYPE zif_cd_ops_trace_types=>ty_partner VALUE 'BP0001',
        other_bp   TYPE zif_cd_ops_trace_types=>ty_partner VALUE 'BP0009',
        bukrs      TYPE zif_cd_ops_trace_types=>ty_bukrs VALUE 'US01',
        item       TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000100001',
        current    TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000200001',
        original   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000200000',
        reversal   TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000300001',
        laufd      TYPE d VALUE '20261102',
        laufi      TYPE c LENGTH 6 VALUE 'PCLM1',
        old_laufd  TYPE d VALUE '20261025',
        file_ref   TYPE zif_cd_ops_trace_types=>ty_file_ref VALUE 'ACH_PNC_20261102_001',
        ztnum      TYPE zif_cd_ops_trace_types=>ty_ref VALUE '0000123456',
        fikey      TYPE c LENGTH 12 VALUE 'FK20261102',
        old_fikey  TYPE c LENGTH 12 VALUE 'FK20261025',
        belnr      TYPE c LENGTH 10 VALUE '0100000001',
        gjahr      TYPE n LENGTH 4 VALUE '2026',
        success    TYPE c LENGTH 7 VALUE 'SUCCESS',
        failed     TYPE c LENGTH 6 VALUE 'FAILED',
        mailed     TYPE c LENGTH 2 VALUE '10',
        reason_rev TYPE c LENGTH 2 VALUE '05',
        hist_date  TYPE c LENGTH 8 VALUE '20261101',
        hist_time  TYPE c LENGTH 6 VALUE '080000',
        rlgrd      TYPE c LENGTH 3 VALUE 'R01',
        rlgrd_2    TYPE c LENGTH 3 VALUE 'R03',
        flgrd      TYPE c LENGTH 3 VALUE 'C01',
        flgrd_2    TYPE c LENGTH 3 VALUE 'C02',
        noc_lot    TYPE c LENGTH 12 VALUE 'NOC000000001',
      END OF gc.
    CONSTANTS gc_file_id TYPE zif_cd_ops_trace_types=>ty_file_id VALUE '00000000000000000000000000000001'.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.
    DATA mo_auth TYPE REF TO ltd_auth.
    DATA mo_request TYPE REF TO ltd_request.

    METHODS setup.
    METHODS teardown.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS configure_request
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS configure_file
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS configure_bank_and_gl
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS configure_reissue.
    METHODS configure_return_and_noc
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS run_trace
      IMPORTING
        is_input         TYPE zif_cd_ops_trace_types=>ty_trace_input OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zif_cd_ops_trace_types=>ty_trace_result.
    "! Statuses of the rows of a stage (of one attempt, when given)
    METHODS statuses
      IMPORTING
        is_result          TYPE zif_cd_ops_trace_types=>ty_trace_result
        iv_stage           TYPE zif_cd_ops_trace_types=>ty_stage
        iv_attempt         TYPE i OPTIONAL
      RETURNING
        VALUE(rt_statuses) TYPE tt_status.
    METHODS param
      IMPORTING
        iv_name  TYPE zif_ca_ops_types=>ty_param_name
        iv_value TYPE string.
    METHODS add_cfg
      IMPORTING
        iv_param TYPE zif_ca_ops_types=>ty_param_name
        is_row   TYPE zif_cd_ops_trace_types=>ty_cfg_row.

    METHODS ach_full_chain_is_complete    FOR TESTING.
    METHODS every_verified_row_has_source FOR TESTING.
    METHODS cheque_encashed_by_ztnum      FOR TESTING.
    METHODS cheque_other_account_missing  FOR TESTING.
    METHODS reissue_traces_two_attempts   FOR TESTING.
    METHODS reversal_without_history      FOR TESTING.
    METHODS reversal_history_unavailable  FOR TESTING.
    METHODS two_success_rows_ambiguous    FOR TESTING.
    METHODS success_row_not_last_counter  FOR TESTING.
    METHODS two_bank_lines_ambiguous      FOR TESTING.
    METHODS sent_without_ack_gap_ack      FOR TESTING.
    METHODS nack_fails_the_trace          FOR TESTING.
    METHODS ack_without_bank_line_gap     FOR TESTING.
    METHODS history_unconfigured_unavail  FOR TESTING.
    METHODS regut_unconfigured_unavail    FOR TESTING.
    METHODS chq_hist_unconfigured_unavail FOR TESTING.
    METHODS unauthorised_not_missing      FOR TESTING.
    METHODS partner_mismatch_ambiguous    FOR TESTING.
    METHODS partner_without_source_noted  FOR TESTING.
    METHODS bad_source_field_is_reported  FOR TESTING.
    METHODS clearing_doc_input_traces     FOR TESTING.
    METHODS unknown_fin_is_not_found      FOR TESTING.
    METHODS member_number_is_masked       FOR TESTING.
    METHODS return_shows_return_reason    FOR TESTING.
    METHODS historical_return_has_reason  FOR TESTING.
    METHODS two_return_reasons_ambiguous  FOR TESTING.
    METHODS noc_found_by_clearing_doc     FOR TESTING.
    METHODS noc_found_by_payment_ref      FOR TESTING.
    METHODS no_noc_is_not_applicable      FOR TESTING.
    METHODS noc_never_changes_verdict     FOR TESTING.
    METHODS request_due_shown_as_info     FOR TESTING.
    METHODS reference_finds_cheque        FOR TESTING.
    METHODS reference_is_payment_doc      FOR TESTING.
ENDCLASS.


CLASS ltc_trace IMPLEMENTATION.

  METHOD setup.
    mo_dao   = NEW #( ).
    mo_params = NEW #( ).
    mo_auth  = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    zcl_ca_ops_injector=>inject_auth( mo_auth ).
    " The canonical outcome is tested in ltc_outcome: no verdict here, the evidence chain unchanged
    zcl_cd_ops_injector=>inject_pay_outcome( NEW ltd_no_outcome( ) ).
    " The request rule is tested in ZCL_CD_OPS_PAY_REQUEST: here only what it says is shown
    mo_request = NEW #( ).
    zcl_cd_ops_injector=>inject_pay_request( mo_request ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_params, mo_auth.
  ENDMETHOD.


  METHOD param.
    mo_params->set( iv_name = iv_name iv_value = iv_value ).
  ENDMETHOD.


  METHOD add_cfg.
    INSERT VALUE #( param = iv_param row = is_row ) INTO TABLE mo_dao->mt_cfg.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_item TYPE zif_cd_ops_trace_types=>ty_item.
    DATA ls_header TYPE zif_cd_ops_trace_types=>ty_doc_header.
    DATA ls_run TYPE zif_cd_ops_trace_types=>ty_payment_run.

    " Sources (names are examples - VERIFY-SE11 in the target system)
    param( iv_name  = zif_cd_ops_trace_types=>gc_param-src_request
           iv_value = |TABLE=ZCD_PAYM_REQ_LOG;KEY=ZZ_FIN_TRANS_NUM;KEY2=SOURCE;REF=COUNTER;| &&
                      |STATUS=ZZ_STATUS;DATE=ERDAT;TIME=ERZET;INFO=ZZ_MEMBER_NO| ).
    IF is_flags-no_history_cfg = abap_false.
      param( iv_name = zif_cd_ops_trace_types=>gc_param-src_history
             iv_value = `TABLE=DFKKRAPT;KEY=OPBEL;REF=AUGBL;DATE=RADAT;TIME=RATIM` ).
    ENDIF.
    IF is_flags-no_regut_cfg = abap_false.
      param( iv_name = zif_cd_ops_trace_types=>gc_param-src_regut
             iv_value = `TABLE=ZCDT_REGUT;KEY=LAUFD;KEY2=LAUFI;REF=FILE_KEY;DATE=CRDATE;TIME=CRTIME` ).
    ENDIF.
    IF is_flags-no_chq_hist_cfg = abap_false.
      param( iv_name = zif_cd_ops_trace_types=>gc_param-src_chq_hist
             iv_value = `TABLE=ZCD_CHECK_HIST;KEY=ZTNUM;STATUS=ZECT_STATUS;DATE=ERDAT;TIME=ERZET` ).
    ENDIF.
    param( iv_name = zif_cd_ops_trace_types=>gc_param-bp_source_field iv_value = `ZZ_SOURCE` ).
    configure_request( is_flags ).

    " Open item of the FIN, cleared by the payment document
    ls_item-opbel = gc-item.
    ls_item-opupk = '0001'.
    ls_item-bukrs = gc-bukrs.
    ls_item-gpart = gc-partner.
    ls_item-betrh = '100.00'.
    ls_item-waers = 'USD'.
    ls_item-budat = '20261101'.
    ls_item-pymet = COND #( WHEN is_flags-cheque = abap_true THEN 'C' ELSE 'E' ).
    ls_item-augbl = gc-current.
    ls_item-augdt = gc-laufd.
    ls_item-fin   = gc-fin.
    IF is_flags-reversal_no_hist = abap_true.
      ls_item-augbl = gc-reversal.
      ls_item-augrd = gc-reason_rev.
    ENDIF.
    INSERT ls_item INTO TABLE mo_dao->mt_items.

    ls_header-opbel = gc-item.
    INSERT ls_header INTO TABLE mo_dao->mt_headers.
    ls_header-opbel = gc-current.
    ls_header-fikey = gc-fikey.
    ls_header-cpudt = gc-laufd.
    ls_header-cputm = '120500'.
    INSERT ls_header INTO TABLE mo_dao->mt_headers.

    ls_run-doc1r  = gc-current.
    ls_run-laufd  = gc-laufd.
    ls_run-laufi  = gc-laufi.
    ls_run-status = 'PAID'.
    INSERT ls_run INTO TABLE mo_dao->mt_runs.
    configure_file( is_flags ).
    configure_bank_and_gl( is_flags ).
    IF is_flags-reissued = abap_true.
      configure_reissue( ).
    ENDIF.
    configure_return_and_noc( is_flags ).
    IF is_flags-unauthorised = abap_true.
      INSERT CONV bukrs( gc-bukrs ) INTO TABLE mo_auth->mt_denied.
    ENDIF.
  ENDMETHOD.


  METHOD configure_request.
    DATA ls_cfg TYPE zif_cd_ops_trace_types=>ty_cfg_row.
    " Request: SUCCESS row (counter 1)
    ls_cfg-key1    = gc-fin.
    ls_cfg-key2    = gc-source.
    ls_cfg-ref     = '1'.
    ls_cfg-status  = gc-success.
    ls_cfg-ev_date = '20261101'.
    ls_cfg-ev_time = '101500'.
    ls_cfg-info    = gc-member.
    add_cfg( iv_param = zif_cd_ops_trace_types=>gc_param-src_request is_row = ls_cfg ).
    IF is_flags-two_success = abap_true.
      ls_cfg-ref = '2'.
      add_cfg( iv_param = zif_cd_ops_trace_types=>gc_param-src_request is_row = ls_cfg ).
    ENDIF.
    IF is_flags-failed_after_ok = abap_true OR is_flags-two_success = abap_true.
      ls_cfg-ref    = '3'.
      ls_cfg-status = gc-failed.
      add_cfg( iv_param = zif_cd_ops_trace_types=>gc_param-src_request is_row = ls_cfg ).
    ENDIF.
    " Partner: with source, else without (legacy)
    IF is_flags-partner_legacy = abap_true.
      INSERT gc-partner INTO TABLE mo_dao->mt_partners.
    ELSEIF is_flags-partner_mismatch = abap_true.
      INSERT gc-other_bp INTO TABLE mo_dao->mt_partners_src.
    ELSE.
      INSERT gc-partner INTO TABLE mo_dao->mt_partners_src.
    ENDIF.
  ENDMETHOD.


  METHOD configure_file.
    DATA ls_cfg TYPE zif_cd_ops_trace_types=>ty_cfg_row.
    DATA ls_file TYPE zif_cd_ops_trace_types=>ty_fmon_file.
    DATA ls_event TYPE zif_cd_ops_trace_types=>ty_fmon_event.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.

    " Generated file register row and file monitoring events
    ls_cfg-key1    = gc-laufd.
    ls_cfg-key2    = gc-laufi.
    ls_cfg-ref     = gc-file_ref.
    ls_cfg-ev_date = gc-laufd.
    ls_cfg-ev_time = '121000'.
    add_cfg( iv_param = zif_cd_ops_trace_types=>gc_param-src_regut is_row = ls_cfg ).
    ls_file-file_id       = gc_file_id.
    ls_file-iface_id      = 'ACH_PNC_DISB_OUT'.
    ls_file-file_ref      = gc-file_ref.
    ls_file-file_name     = gc-file_ref.
    ls_file-business_date = gc-laufd.
    INSERT ls_file INTO TABLE mo_dao->mt_files.
    ls_event-file_id  = gc_file_id.
    ls_event-event_no = 1.
    ls_event-stage    = zif_cd_fmon_types=>gc_stage-generated.
    ls_event-event_at = '20261102121000.0000000'.
    ls_event-src_id   = 'REGUT'.
    INSERT ls_event INTO TABLE mo_dao->mt_events.
    ls_event-event_no = 2.
    ls_event-stage    = zif_cd_fmon_types=>gc_stage-sent.
    ls_event-event_at = '20261102130000.0000000'.
    INSERT ls_event INTO TABLE mo_dao->mt_events.
    IF is_flags-no_ack = abap_false.
      ls_event-event_no = 3.
      ls_event-stage    = COND #( WHEN is_flags-nack = abap_true THEN zif_cd_fmon_types=>gc_stage-nack
                                  ELSE zif_cd_fmon_types=>gc_stage-ack ).
      ls_event-event_at = '20261102150000.0000000'.
      ls_event-src_id   = 'ACHACK'.
      INSERT ls_event INTO TABLE mo_dao->mt_events.
    ENDIF.
    mo_dao->mv_kind = zif_cd_ops_trace_types=>gc_kind-disbursement.

    " Cheque: register row and IRIS status (mailed)
    IF is_flags-cheque = abap_true.
      ls_check-ztnum = gc-ztnum.
      ls_check-bukrs = gc-bukrs.
      ls_check-hbkid = 'JPMC1'.
      ls_check-hktid = 'CHK01'.
      ls_check-doc1r = gc-current.
      INSERT ls_check INTO TABLE mo_dao->mt_checks.
      CLEAR ls_cfg.
      ls_cfg-key1    = gc-ztnum.
      ls_cfg-status  = gc-mailed.
      ls_cfg-ev_date = '20261104'.
      ls_cfg-ev_time = '090000'.
      add_cfg( iv_param = zif_cd_ops_trace_types=>gc_param-src_chq_hist is_row = ls_cfg ).
    ENDIF.
  ENDMETHOD.


  METHOD configure_bank_and_gl.
    DATA ls_bank TYPE zif_cd_ops_trace_types=>ty_bank_line.
    DATA ls_fikey TYPE zif_cd_ops_trace_types=>ty_fikey.
    DATA ls_gl_doc TYPE zif_cd_ops_trace_types=>ty_gl_doc.
    DATA ls_gl_line TYPE zif_cd_ops_trace_types=>ty_gl_line.

    " Bank statement line: CHECT = clearing reference (ACH) or cheque number (method C)
    IF is_flags-no_bank_line = abap_false.
      ls_bank-kukey = '00000101'.
      ls_bank-esnum = '00001'.
      ls_bank-chect = COND #( WHEN is_flags-cheque = abap_true THEN gc-ztnum ELSE CONV #( gc-current ) ).
      ls_bank-budat = '20261103'.
      " Statement account (FEBKO): the cheque's house bank account unless the scenario says otherwise
      ls_bank-bukrs = gc-bukrs.
      ls_bank-hbkid = COND #( WHEN is_flags-cheque_other_acct = abap_true THEN 'BOA01' ELSE 'JPMC1' ).
      ls_bank-hktid = 'CHK01'.
      INSERT ls_bank INTO TABLE mo_dao->mt_bank.
      IF is_flags-two_bank_lines = abap_true.
        ls_bank-kukey = '00000102'.
        INSERT ls_bank INTO TABLE mo_dao->mt_bank.
      ENDIF.
    ENDIF.

    " G/L transfer: DFKKKO-FIKEY = DFKKSUMC-FIKEY = BKPF-AWKEY; clearing line XREF2 = AUGBL
    ls_fikey-fikey = gc-fikey.
    ls_fikey-bukrs = gc-bukrs.
    INSERT ls_fikey INTO TABLE mo_dao->mt_sumc.
    ls_gl_doc-bukrs = gc-bukrs.
    ls_gl_doc-belnr = gc-belnr.
    ls_gl_doc-gjahr = gc-gjahr.
    ls_gl_doc-awkey = gc-fikey.
    ls_gl_doc-budat = '20261103'.
    ls_gl_doc-cpudt = '20261103'.
    ls_gl_doc-cputm = '220000'.
    INSERT ls_gl_doc INTO TABLE mo_dao->mt_gl_docs.
    ls_gl_line-bukrs = gc-bukrs.
    ls_gl_line-belnr = gc-belnr.
    ls_gl_line-gjahr = gc-gjahr.
    ls_gl_line-buzei = '001'.
    ls_gl_line-hkont = '0021000100'.
    ls_gl_line-xref2 = gc-current.
    INSERT ls_gl_line INTO TABLE mo_dao->mt_gl_lines.
  ENDMETHOD.


  METHOD configure_reissue.
    DATA ls_cfg TYPE zif_cd_ops_trace_types=>ty_cfg_row.
    DATA ls_run TYPE zif_cd_ops_trace_types=>ty_payment_run.
    DATA ls_bank TYPE zif_cd_ops_trace_types=>ty_bank_line.
    DATA ls_return TYPE zif_cd_ops_trace_types=>ty_return.
    DATA ls_header TYPE zif_cd_ops_trace_types=>ty_doc_header.

    " The original clearing was reset (history row) and its money came back (return)
    ls_cfg-key1    = gc-item.
    ls_cfg-ref     = gc-original.
    ls_cfg-ev_date = gc-hist_date.
    ls_cfg-ev_time = gc-hist_time.
    add_cfg( iv_param = zif_cd_ops_trace_types=>gc_param-src_history is_row = ls_cfg ).
    ls_run-doc1r  = gc-original.
    ls_run-laufd  = gc-old_laufd.
    ls_run-laufi  = gc-laufi.
    ls_run-status = 'PAID'.
    INSERT ls_run INTO TABLE mo_dao->mt_runs.
    ls_bank-kukey = '00000090'.
    ls_bank-esnum = '00003'.
    ls_bank-chect = gc-original.
    ls_bank-budat = '20261026'.
    INSERT ls_bank INTO TABLE mo_dao->mt_bank.
    ls_return-selw1     = gc-original.
    ls_return-opbel     = '000000400001'.
    ls_return-lot_stars = '1'.
    ls_return-rlgrd     = gc-rlgrd.
    INSERT ls_return INTO TABLE mo_dao->mt_returns.
    ls_header-opbel = gc-original.
    ls_header-fikey = gc-old_fikey.
    INSERT ls_header INTO TABLE mo_dao->mt_headers.
  ENDMETHOD.


  METHOD configure_return_and_noc.
    DATA ls_return TYPE zif_cd_ops_trace_types=>ty_return.
    DATA ls_noc TYPE zif_cd_ops_trace_types=>ty_noc.
    IF is_flags-returned = abap_true OR is_flags-two_reasons = abap_true.
      ls_return-selw1     = gc-current.
      ls_return-opbel     = '000000400002'.
      ls_return-lot_stars = '1'.
      ls_return-rlgrd     = gc-rlgrd.
      INSERT ls_return INTO TABLE mo_dao->mt_returns.
    ENDIF.
    IF is_flags-two_reasons = abap_true.
      ls_return-opbel = '000000400003'.
      ls_return-rlgrd = gc-rlgrd_2.
      INSERT ls_return INTO TABLE mo_dao->mt_returns.
    ENDIF.
    ls_noc-keyn1 = gc-noc_lot.
    IF is_flags-noc_by_augbl = abap_true.
      ls_noc-posna = 1.
      ls_noc-infof = gc-current.
      ls_noc-flgrd = gc-flgrd.
      INSERT ls_noc INTO TABLE mo_dao->mt_noc.
    ENDIF.
    IF is_flags-noc_by_fin = abap_true.
      ls_noc-posna = 2.
      ls_noc-infof = gc-fin.
      ls_noc-flgrd = COND #( WHEN is_flags-noc_by_augbl = abap_true THEN gc-flgrd_2 ELSE gc-flgrd ).
      INSERT ls_noc INTO TABLE mo_dao->mt_noc.
    ENDIF.
  ENDMETHOD.


  METHOD run_trace.
    DATA(ls_input) = is_input.
    IF ls_input IS INITIAL.
      ls_input-fin    = gc-fin.
      ls_input-source = gc-source.
    ENDIF.
    rs_result = NEW zcl_cd_ops_trace_engine( )->trace( ls_input ).
  ENDMETHOD.


  METHOD statuses.
    LOOP AT is_result-rows INTO DATA(ls_row) WHERE stage = iv_stage.
      IF iv_attempt IS SUPPLIED AND ls_row-attempt <> iv_attempt.
        CONTINUE.
      ENDIF.
      INSERT ls_row-status INTO TABLE rt_statuses.
    ENDLOOP.
  ENDMETHOD.


  " Rule: an ACH disbursement with evidence at every stage is COMPLETE, in timeline order
  METHOD ach_full_chain_is_complete.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-complete
                                            msg = 'Full ACH evidence must give COMPLETE' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-first_gap_stage msg = 'No gap expected' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-attempts exp = 1 msg = 'One payment attempt' ).
        DATA(lt_stages) = VALUE string_table( FOR ls IN ls_result-rows ( CONV #( ls-stage ) ) ).
        cl_abap_unit_assert=>assert_equals(
          act = lt_stages
          exp = VALUE string_table( ( `REQUEST` ) ( `SAP_ITEM` ) ( `CLEAR_HISTORY` ) ( `PAYMENT` )
                                    ( `FILE_GENERATED` ) ( `PRISM_HANDOFF` ) ( `BANK_ACK` ) ( `SETTLEMENT` )
                                    ( `NOC` ) ( `FICA_CLEARING` ) ( `FICA_CLEARING` ) ( `GL` ) )
          msg = 'Every stage once in timeline order (clearing: DFKKOP and BSEG line; NOC evidence row)' ).
        DATA(lt_not_verified) = VALUE tt_status( FOR ls IN ls_result-rows
                                                 WHERE ( status <> zif_cd_ops_trace_types=>gc_status-verified
                                                         AND stage <> zif_cd_ops_trace_types=>gc_stage-noc )
                                                 ( ls-status ) ).
        cl_abap_unit_assert=>assert_initial( act = lt_not_verified msg = 'Every row must be VERIFIED' ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result iv_stage = zif_cd_ops_trace_types=>gc_stage-noc )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-not_applicable ) )
                                            msg = 'Without a NOC the NOC row is NOT_APPLICABLE' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a VERIFIED stage names its source table, record key and timestamp
  METHOD every_verified_row_has_source.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = run_trace( ).
        LOOP AT ls_result-rows INTO DATA(ls_row) WHERE status = zif_cd_ops_trace_types=>gc_status-verified
                                                   AND stage <> zif_cd_ops_trace_types=>gc_stage-history.
          cl_abap_unit_assert=>assert_not_initial( act = ls_row-source_table msg = |{ ls_row-stage }: source table| ).
          cl_abap_unit_assert=>assert_not_initial( act = ls_row-record_key msg = |{ ls_row-stage }: record key| ).
          cl_abap_unit_assert=>assert_not_initial( act = ls_row-evidence_date msg = |{ ls_row-stage }: evidence date| ).
        ENDLOOP.
        DATA(ls_bank) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-settlement ].
        cl_abap_unit_assert=>assert_equals( act = ls_bank-source_table exp = zif_cd_ops_trace_types=>gc_table-febep
                                            msg = 'Settlement evidence is the FEBEP line' ).
        cl_abap_unit_assert=>assert_equals( act = ls_bank-record_key exp = |00000101/00001/{ gc-current }|
                                            msg = 'FEBEP key KUKEY / ESNUM / CHECT' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (design review 3): the same cheque number on a statement of another house bank account is
  " not this cheque's encashment - the settlement stays MISSING, never inherited
  METHOD cheque_other_account_missing.
    TRY.
        configure_scenario( VALUE #( cheque = abap_true cheque_other_acct = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ls_result-rows[ stage  = zif_cd_ops_trace_types=>gc_stage-settlement
                                                      reason = zif_cd_ops_trace_types=>gc_reason-encashed ] ) )
          msg = 'No encashment from another account' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-rows[ stage        = zif_cd_ops_trace_types=>gc_stage-settlement
                                                      source_table = zif_cd_ops_trace_types=>gc_table-febep
                                                      status       = zif_cd_ops_trace_types=>gc_status-missing ] ) )
          msg = 'Settlement missing' ).
        cl_abap_unit_assert=>assert_differs( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-complete
                                             msg = 'Never COMPLETE' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: method C - DFKKCR-DOC1R = AUGBL, encashment FEBEP-CHECT = DFKKCR-ZTNUM
  METHOD cheque_encashed_by_ztnum.
    TRY.
        configure_scenario( VALUE #( cheque = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-complete
                                            msg = 'Cheque issued, mailed and encashed must be COMPLETE' ).
        DATA(ls_payment) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-payment ].
        cl_abap_unit_assert=>assert_equals( act = ls_payment-source_table exp = zif_cd_ops_trace_types=>gc_table-dfkkcr
                                            msg = 'Cheque payment evidence is the cheque register' ).
        DATA(ls_encash) = ls_result-rows[ stage  = zif_cd_ops_trace_types=>gc_stage-settlement
                                          reason = zif_cd_ops_trace_types=>gc_reason-encashed ].
        cl_abap_unit_assert=>assert_equals( act = ls_encash-record_key exp = |00000101/00001/{ gc-ztnum }|
                                            msg = 'Encashment found by the cheque number' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-rows[ stage  = zif_cd_ops_trace_types=>gc_stage-settlement
                                                      reason = zif_cd_ops_trace_types=>gc_reason-cheque_status ] ) )
          msg = 'Cheque status history is shown' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ls_result-rows[ source_table = zif_cd_ops_trace_types=>gc_table-bseg ] ) )
          msg = 'No XREF2 clearing line for method C' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a reset clearing is a separate attempt traced under the ORIGINAL clearing reference
  METHOD reissue_traces_two_attempts.
    TRY.
        configure_scenario( VALUE #( reissued = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-attempts exp = 2 msg = 'Original and reissue' ).
        DATA(ls_old_bank) = ls_result-rows[ attempt = 1
                                            stage   = zif_cd_ops_trace_types=>gc_stage-settlement
                                            status  = zif_cd_ops_trace_types=>gc_status-verified ].
        cl_abap_unit_assert=>assert_equals( act = ls_old_bank-clearing_ref exp = gc-original
                                            msg = 'Attempt 1 is the original clearing reference' ).
        cl_abap_unit_assert=>assert_equals( act = ls_old_bank-attempt_kind exp = zif_cd_ops_trace_types=>gc_attempt-historical
                                            msg = 'Attempt 1 comes from the clearing-reset history' ).
        cl_abap_unit_assert=>assert_equals( act = ls_old_bank-record_key exp = |00000090/00003/{ gc-original }|
                                            msg = 'Bank line found under the original reference' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-rows[ attempt = 1 reason = zif_cd_ops_trace_types=>gc_reason-returned ] ) )
          msg = 'Return of the original payment is shown' ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result
                                                            iv_stage  = zif_cd_ops_trace_types=>gc_stage-settlement
                                                            iv_attempt = 2 )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-verified ) )
                                            msg = 'Reissue settled under the current reference' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-complete
                                            msg = 'The current attempt decides the verdict' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: reversal evidence without a history row is REVERSAL_HISTORY_MISSING, never a pass
  METHOD reversal_without_history.
    TRY.
        configure_scenario( VALUE #( reversal_no_hist = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_history) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-history ].
        cl_abap_unit_assert=>assert_equals( act = ls_history-status exp = zif_cd_ops_trace_types=>gc_status-missing
                                            msg = 'Missing history must be MISSING' ).
        cl_abap_unit_assert=>assert_equals( act = ls_history-reason exp = zif_cd_ops_trace_types=>gc_reason-history_missing
                                            msg = 'Reason REVERSAL_HISTORY_MISSING' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-first_gap_stage exp = zif_cd_ops_trace_types=>gc_stage-history
                                            msg = 'The missing history is the first gap' ).
        cl_abap_unit_assert=>assert_differs( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-complete
                                             msg = 'Never COMPLETE' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-attempts exp = 0
                                            msg = 'The reversal clearing is not a payment attempt' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: reversal evidence while the history source is not configured is flagged explicitly
  METHOD reversal_history_unavailable.
    TRY.
        configure_scenario( VALUE #( reversal_no_hist = abap_true no_history_cfg = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_history) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-history ].
        cl_abap_unit_assert=>assert_equals( act = ls_history-status exp = zif_cd_ops_trace_types=>gc_status-unavailable
                                            msg = 'History source not configured: UNAVAILABLE' ).
        cl_abap_unit_assert=>assert_equals( act = ls_history-reason exp = zif_cd_ops_trace_types=>gc_reason-history_missing
                                            msg = 'Reversed item names REVERSAL_HISTORY_MISSING' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: two SUCCESS rows for one FIN + source are AMBIGUOUS, both shown, none picked
  METHOD two_success_rows_ambiguous.
    TRY.
        configure_scenario( VALUE #( two_success = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result
                                                            iv_stage  = zif_cd_ops_trace_types=>gc_stage-request )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-ambiguous )
                                                                   ( zif_cd_ops_trace_types=>gc_status-ambiguous ) )
                                            msg = 'Both SUCCESS rows shown as AMBIGUOUS; the FAILED row not shown' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-ambiguous
                                            msg = 'Verdict AMBIGUOUS' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the SUCCESS row counts, never the highest COUNTER (a failed retry may follow it)
  METHOD success_row_not_last_counter.
    TRY.
        configure_scenario( VALUE #( failed_after_ok = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(lt_request) = VALUE zif_cd_ops_trace_types=>tt_trace_row(
          FOR ls IN ls_result-rows WHERE ( stage = zif_cd_ops_trace_types=>gc_stage-request ) ( ls ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_request ) exp = 1 msg = 'Only the SUCCESS row' ).
        cl_abap_unit_assert=>assert_equals( act = lt_request[ 1 ]-record_key exp = |{ gc-fin }/{ gc-source }/1|
                                            msg = 'Counter 1 (SUCCESS), not counter 3 (FAILED)' ).
        cl_abap_unit_assert=>assert_equals( act = lt_request[ 1 ]-status exp = zif_cd_ops_trace_types=>gc_status-verified
                                            msg = 'One SUCCESS row is VERIFIED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: two bank lines for one clearing reference are AMBIGUOUS, both listed
  METHOD two_bank_lines_ambiguous.
    TRY.
        configure_scenario( VALUE #( two_bank_lines = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result
                                                            iv_stage  = zif_cd_ops_trace_types=>gc_stage-settlement )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-ambiguous )
                                                                   ( zif_cd_ops_trace_types=>gc_status-ambiguous ) )
                                            msg = 'Both FEBEP candidates listed as AMBIGUOUS' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-ambiguous
                                            msg = 'Verdict AMBIGUOUS' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: sent to PRISM without an acknowledgement - first missing milestone BANK_ACK
  METHOD sent_without_ack_gap_ack.
    TRY.
        configure_scenario( VALUE #( no_ack = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-first_gap_stage exp = zif_cd_ops_trace_types=>gc_stage-bank_ack
                                            msg = 'First gap BANK_ACK' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-incomplete
                                            msg = 'Incomplete, never COMPLETE' ).
        cl_abap_unit_assert=>assert_true(
          act = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-bank_ack ]-first_gap
          msg = 'The BANK_ACK row is highlighted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a NACK is positive evidence of failure
  METHOD nack_fails_the_trace.
    TRY.
        configure_scenario( VALUE #( nack = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result
                                                            iv_stage  = zif_cd_ops_trace_types=>gc_stage-bank_ack )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-failed ) )
                                            msg = 'NACK_REJECTED is FAILED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-failed
                                            msg = 'Verdict FAILED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: acknowledged but no bank statement line - first missing milestone SETTLEMENT
  METHOD ack_without_bank_line_gap.
    TRY.
        configure_scenario( VALUE #( no_bank_line = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_payment) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-payment
                                           status = zif_cd_ops_trace_types=>gc_status-verified ].
        cl_abap_unit_assert=>assert_equals( act = ls_payment-clearing_ref
                                            exp = gc-current
                                            msg = 'The verified payment uses the current clearing reference' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-first_gap_stage
                                            exp = zif_cd_ops_trace_types=>gc_stage-settlement
                                            msg = 'First gap SETTLEMENT' ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result
                                                            iv_stage  = zif_cd_ops_trace_types=>gc_stage-settlement )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-missing ) )
                                            msg = 'Settlement MISSING' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-incomplete
                                            msg = 'Incomplete, never COMPLETE' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an unconfigured history source is UNAVAILABLE - absence of reversal is not proven
  METHOD history_unconfigured_unavail.
    TRY.
        configure_scenario( VALUE #( no_history_cfg = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_history) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-history ].
        cl_abap_unit_assert=>assert_equals( act = ls_history-status exp = zif_cd_ops_trace_types=>gc_status-unavailable
                                            msg = 'Not configured: UNAVAILABLE' ).
        cl_abap_unit_assert=>assert_equals( act = ls_history-reason exp = zif_cd_ops_trace_types=>gc_reason-not_configured
                                            msg = 'Reason SOURCE_NOT_CONFIGURED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-incomplete
                                            msg = 'Never COMPLETE without the history' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: payment run -> file only through the configured register; unconfigured never VERIFIED
  METHOD regut_unconfigured_unavail.
    TRY.
        configure_scenario( VALUE #( no_regut_cfg = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result
                                                            iv_stage  = zif_cd_ops_trace_types=>gc_stage-file )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-unavailable ) )
                                            msg = 'FILE_GENERATED UNAVAILABLE' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-prism ]-reason
                                            exp = zif_cd_ops_trace_types=>gc_reason-no_link
                                            msg = 'PRISM handoff has no file to look for' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-first_gap_stage exp = zif_cd_ops_trace_types=>gc_stage-file
                                            msg = 'First gap FILE_GENERATED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an unconfigured cheque history is shown as UNAVAILABLE, not skipped
  METHOD chq_hist_unconfigured_unavail.
    TRY.
        configure_scenario( VALUE #( cheque = abap_true no_chq_hist_cfg = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-rows[ stage  = zif_cd_ops_trace_types=>gc_stage-settlement
                                                      status = zif_cd_ops_trace_types=>gc_status-unavailable
                                                      reason = zif_cd_ops_trace_types=>gc_reason-not_configured ] ) )
          msg = 'Cheque history not configured: UNAVAILABLE row' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-incomplete
                                            msg = 'Never COMPLETE without the cheque status' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an item of a company code the user may not display is 'not authorised', never missing
  METHOD unauthorised_not_missing.
    TRY.
        configure_scenario( VALUE #( unauthorised = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_item) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-sap_item ].
        cl_abap_unit_assert=>assert_equals( act = ls_item-status exp = zif_cd_ops_trace_types=>gc_status-unavailable
                                            msg = 'UNAVAILABLE' ).
        cl_abap_unit_assert=>assert_equals( act = ls_item-reason exp = zif_cd_ops_trace_types=>gc_reason-not_authorised
                                            msg = 'Reason NOT_AUTHORISED' ).
        cl_abap_unit_assert=>assert_initial( act = ls_item-record_key msg = 'No key of the hidden item' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ls_result-rows[ status = zif_cd_ops_trace_types=>gc_status-missing ] ) )
          msg = 'Nothing is reported as MISSING' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-incomplete
                                            msg = 'Never COMPLETE' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the request's partner owns none of the items - the link is flagged, nothing picked
  METHOD partner_mismatch_ambiguous.
    TRY.
        configure_scenario( VALUE #( partner_mismatch = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_item) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-sap_item ].
        cl_abap_unit_assert=>assert_equals( act = ls_item-status exp = zif_cd_ops_trace_types=>gc_status-ambiguous
                                            msg = 'AMBIGUOUS' ).
        cl_abap_unit_assert=>assert_equals( act = ls_item-reason exp = zif_cd_ops_trace_types=>gc_reason-partner_mismatch
                                            msg = 'Reason PARTNER_MISMATCH' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-attempts exp = 0 msg = 'Not traced further' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-ambiguous
                                            msg = 'Verdict AMBIGUOUS' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: partner with SOURCE first, then without it (legacy PCLM) - and say so
  METHOD partner_without_source_noted.
    TRY.
        configure_scenario( VALUE #( partner_legacy = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_item) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-sap_item ].
        cl_abap_unit_assert=>assert_equals( act = ls_item-status exp = zif_cd_ops_trace_types=>gc_status-verified
                                            msg = 'Legacy partner still verifies the item' ).
        cl_abap_unit_assert=>assert_equals( act = ls_item-reason exp = zif_cd_ops_trace_types=>gc_reason-partner_legacy
                                            msg = 'Reason PARTNER_WITHOUT_SOURCE' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (B17): a source field the partner read refuses is reported as a configuration row;
  " the trace continues without the filter and the row never decides the verdict
  METHOD bad_source_field_is_reported.
    TRY.
        configure_scenario( VALUE #( partner_legacy = abap_true ) ).
        mo_dao->mv_source_field_fails = abap_true.
        DATA(ls_result) = run_trace( ).
        DATA(ls_config) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-config ].
        cl_abap_unit_assert=>assert_equals( act = ls_config-reason exp = zif_cd_ops_trace_types=>gc_reason-not_configured
                                            msg = 'Configuration row SOURCE_NOT_CONFIGURED' ).
        cl_abap_unit_assert=>assert_false( act = ls_config-first_gap
                                           msg = 'A configuration row is never the first gap' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-sap_item ]-status
                                            exp = zif_cd_ops_trace_types=>gc_status-verified
                                            msg = 'The items still verify without the filter' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a clearing document alone finds the items and, through their FIN, the request
  METHOD clearing_doc_input_traces.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = run_trace( VALUE #( clearing_doc = gc-current ) ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result
                                                            iv_stage  = zif_cd_ops_trace_types=>gc_stage-request )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-verified ) )
                                            msg = 'Request found through the FIN of the item' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-complete
                                            msg = 'Full chain from the clearing document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (2026-11-08): the due date and stage of the request are shown (the worklist's rule) - a request
  " not paid by its due date is a FAILED information row that never changes the evidence verdict
  METHOD request_due_shown_as_info.
    TRY.
        configure_scenario( VALUE #( ) ).
        INSERT VALUE #( fin = gc-fin source = gc-source due_date = gc-laufd overdue = abap_true
                        stage = zif_cd_ops_payout_types=>gc_req_stage-not_in_run ) INTO TABLE mo_request->mt_requests.
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result
                                                            iv_stage  = zif_cd_ops_trace_types=>gc_stage-request_due )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-failed ) )
                                            msg = 'Not paid by the due date' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-complete
                                            msg = 'Information only: the evidence chain is complete' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (2026-11-08): a payment reference that is a cheque number finds the cheque's payment (keyed
  " DFKKCR read by the number as given / without leading zeros / its last 13 characters zero-padded)
  METHOD reference_finds_cheque.
    TRY.
        configure_scenario( VALUE #( cheque = abap_true ) ).
        DATA(ls_result) = run_trace( VALUE #( check_no = gc-ztnum ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-complete
                                            msg = 'Traced from the cheque number' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment reference that is the payment document (FEBEP-CHECT = AUGBL) traces it
  METHOD reference_is_payment_doc.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = run_trace( VALUE #( check_no = gc-current ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-complete
                                            msg = 'Traced from the payment document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: nothing found for the keys is NOT_FOUND, not an empty COMPLETE
  METHOD unknown_fin_is_not_found.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = run_trace( VALUE #( fin = 'FIN9999' source = gc-source ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-not_found
                                            msg = 'Unknown FIN is NOT_FOUND' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: member numbers and bank data keep only their last four characters
  METHOD member_number_is_masked.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_trace_engine=>mask( gc-member ) exp = `*****6789`
                                            msg = 'Last four characters only' ).
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_request) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-request ].
        cl_abap_unit_assert=>assert_char_np( act = ls_request-detail exp = |*{ gc-member }*|
                                             msg = 'The member number never appears unmasked' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.



  " Return / NOC reasons 2026-11-06: a returns lot item on the clearing shows its return
  " reason DFKKRP-RLGRD in the evidence; the return still fails the payment
  METHOD return_shows_return_reason.
    TRY.
        configure_scenario( VALUE #( returned = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_return) = ls_result-rows[ attempt = 1 reason = zif_cd_ops_trace_types=>gc_reason-returned ].
        cl_abap_unit_assert=>assert_equals( act = ls_return-status exp = zif_cd_ops_trace_types=>gc_status-failed
                                            msg = 'A return is positive evidence of a failure' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_return-detail exp = |*{ gc-rlgrd }*|
                                             msg = 'The return reason RLGRD is shown' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-failed
                                            msg = 'A returned payment fails the trace' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The return of a reversed item sits under the historical clearing reference: its return
  " reason is shown on that attempt as well
  METHOD historical_return_has_reason.
    TRY.
        configure_scenario( VALUE #( reissued = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_return) = ls_result-rows[ attempt = 1 reason = zif_cd_ops_trace_types=>gc_reason-returned ].
        cl_abap_unit_assert=>assert_equals( act = ls_return-clearing_ref exp = gc-original
                                            msg = 'The return belongs to the original clearing reference' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_return-detail exp = |*{ gc-rlgrd }*|
                                             msg = 'The historical return shows its reason' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Two returns lot items of one clearing with different return reasons: one AMBIGUOUS row
  " listing both, next to the FAILED item rows
  METHOD two_return_reasons_ambiguous.
    TRY.
        configure_scenario( VALUE #( two_reasons = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_ambiguous) = ls_result-rows[ reason = zif_cd_ops_trace_types=>gc_reason-return_reason_ambiguous ].
        cl_abap_unit_assert=>assert_equals( act = ls_ambiguous-status exp = zif_cd_ops_trace_types=>gc_status-ambiguous
                                            msg = 'Different return reasons are AMBIGUOUS' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_ambiguous-detail exp = |*{ gc-rlgrd }*{ gc-rlgrd_2 }*|
                                             msg = 'Every return reason is listed' ).
        cl_abap_unit_assert=>assert_equals( act = lines( VALUE tt_status( FOR ls IN ls_result-rows
                                                                          WHERE ( reason = zif_cd_ops_trace_types=>gc_reason-returned )
                                                                          ( ls-status ) ) )
                                            exp = 2 msg = 'Both returns lot items are shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " NOC lot item whose INFOF holds the clearing document (AUGBL): VERIFIED evidence with lot,
  " item and NOC reason FLGRD
  METHOD noc_found_by_clearing_doc.
    TRY.
        configure_scenario( VALUE #( noc_by_augbl = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_noc) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-noc ].
        cl_abap_unit_assert=>assert_equals( act = ls_noc-status exp = zif_cd_ops_trace_types=>gc_status-verified
                                            msg = 'A NOC found by the clearing document is VERIFIED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_noc-source_table exp = zif_cd_ops_trace_types=>gc_table-dfkknrp
                                            msg = 'The NOC evidence names DFKKNRP' ).
        cl_abap_unit_assert=>assert_equals( act = ls_noc-record_key exp = |{ gc-noc_lot }/000001|
                                            msg = 'Record key KEYN1 / POSNA' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_noc-detail exp = |*{ gc-flgrd }*|
                                             msg = 'The NOC reason FLGRD is shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " NOC lot item whose INFOF holds the payment reference (the FIN of the item) instead of AUGBL
  METHOD noc_found_by_payment_ref.
    TRY.
        configure_scenario( VALUE #( noc_by_fin = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result iv_stage = zif_cd_ops_trace_types=>gc_stage-noc )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-verified ) )
                                            msg = 'A NOC found by the payment reference is VERIFIED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " No NOC item: NOT_APPLICABLE with reason NO_NOC_ITEM - never MISSING, no gap
  METHOD no_noc_is_not_applicable.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = run_trace( ).
        DATA(ls_noc) = ls_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-noc ].
        cl_abap_unit_assert=>assert_equals( act = ls_noc-status exp = zif_cd_ops_trace_types=>gc_status-not_applicable
                                            msg = 'No NOC is not applicable' ).
        cl_abap_unit_assert=>assert_equals( act = ls_noc-reason exp = zif_cd_ops_trace_types=>gc_reason-no_noc
                                            msg = 'Reason NO_NOC_ITEM' ).
        cl_abap_unit_assert=>assert_false( act = ls_noc-first_gap msg = 'A missing NOC is never a gap' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A NOC is information (account data change), not a failure: even two NOC items with
  " different reasons (AMBIGUOUS) leave a complete payment COMPLETE, without a gap
  METHOD noc_never_changes_verdict.
    TRY.
        configure_scenario( VALUE #( noc_by_augbl = abap_true noc_by_fin = abap_true ) ).
        DATA(ls_result) = run_trace( ).
        cl_abap_unit_assert=>assert_equals( act = statuses( is_result = ls_result iv_stage = zif_cd_ops_trace_types=>gc_stage-noc )
                                            exp = VALUE tt_status( ( zif_cd_ops_trace_types=>gc_status-ambiguous )
                                                                   ( zif_cd_ops_trace_types=>gc_status-ambiguous ) )
                                            msg = 'Two NOC items with different reasons are AMBIGUOUS, both listed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_cd_ops_trace_types=>gc_verdict-complete
                                            msg = 'A NOC never changes the verdict' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-first_gap_stage msg = 'A NOC is never the first gap' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
"! Runtime DAO double of the outcome tests: configuration and DPAYH rows of the shared fixtures
CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    DATA mt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA mt_classes TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    DATA mt_rules TYPE zif_cd_hck_runtime_types=>tt_clr_rule.
    DATA mt_roles TYPE zif_cd_hck_runtime_types=>tt_btc_role.
    DATA mt_outcomes TYPE zif_cd_hck_runtime_types=>tt_seq_outcome.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
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

  METHOD zif_cd_hck_runtime_dao~get_clearing_rules.
    rt_rules = mt_rules.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_btc_roles.
    rt_roles = mt_roles.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_seq_outcomes.
    rt_outcomes = mt_outcomes.
  ENDMETHOD.

ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock PARTIALLY IMPLEMENTED.
    CONSTANTS gc_today TYPE d VALUE '20261111'.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~today.
    rv_date = gc_today.
  ENDMETHOD.
ENDCLASS.


"! The trace shows the canonical outcome of the shared fixtures (ZCL_CD_OPS_PAY_FIXTURE) - the same
"! verdict as A_INFLIGHT and the transactions dashboard - with the real evaluator
CLASS ltc_outcome DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_request_spec TYPE string VALUE `TABLE=ZCD_PAYM_REQ_LOG;KEY=ZZ_FIN_TRANS_NUM;KEY2=SOURCE;STATUS=ZZ_STATUS`.

    DATA mo_fixture TYPE REF TO zcl_cd_ops_pay_fixture.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_runtime TYPE REF TO ltd_runtime_dao.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.

    METHODS retrieval_shown_not_returned FOR TESTING.
    METHODS line_without_clearing_failed FOR TESTING.
    METHODS latest_run_shown             FOR TESTING.
    METHODS two_sources_ambiguous        FOR TESTING.
    METHODS outcome_never_changes_verdict FOR TESTING.

    METHODS trace
      IMPORTING
        iv_id            TYPE zcl_cd_ops_pay_fixture=>ty_scenario_id
      RETURNING
        VALUE(rs_result) TYPE zif_cd_ops_trace_types=>ty_trace_result.

    METHODS outcome_row
      IMPORTING
        is_result     TYPE zif_cd_ops_trace_types=>ty_trace_result
      RETURNING
        VALUE(rs_row) TYPE zif_cd_ops_trace_types=>ty_trace_row.
ENDCLASS.


CLASS ltc_outcome IMPLEMENTATION.

  METHOD setup.
    mo_fixture = NEW #( ltd_clock=>gc_today ).
    mo_dao = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_dao ).
    mo_runtime = NEW #( ).
    mo_runtime->mt_classes  = mo_fixture->classes( ).
    mo_runtime->mt_rules    = mo_fixture->rules( ).
    mo_runtime->mt_roles    = mo_fixture->roles( ).
    mo_runtime->mt_outcomes = mo_fixture->outcomes( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_runtime ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_ca_ops_injector=>inject_auth( NEW ltd_auth( ) ).
    zcl_cd_ops_injector=>inject_pay_request( NEW ltd_request( ) ).
    mo_params = NEW #( ).
    mo_params->set( iv_name = zif_cd_ops_trace_types=>gc_param-src_request iv_value = gc_request_spec ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_fixture, mo_dao, mo_runtime, mo_params.
  ENDMETHOD.


  METHOD trace.
    DATA ls_cfg TYPE ltd_dao=>ty_cfg.
    DATA(ls_scenario) = mo_fixture->scenario( iv_id ).
    INSERT mo_fixture->item( ls_scenario ) INTO TABLE mo_dao->mt_items.
    INSERT LINES OF mo_fixture->payment_runs( ls_scenario ) INTO TABLE mo_dao->mt_runs.
    INSERT LINES OF ls_scenario-lines INTO TABLE mo_dao->mt_bank.
    INSERT LINES OF ls_scenario-returns INTO TABLE mo_dao->mt_returns.
    INSERT LINES OF mo_fixture->issued_payments( ls_scenario ) INTO TABLE mo_runtime->mt_payments.
    LOOP AT ls_scenario-requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      ls_cfg-param       = zif_cd_ops_trace_types=>gc_param-src_request.
      ls_cfg-row-key1    = <ls_request>-fin.
      ls_cfg-row-key2    = <ls_request>-source.
      ls_cfg-row-ref     = <ls_request>-counter.
      ls_cfg-row-status  = <ls_request>-status.
      INSERT ls_cfg INTO TABLE mo_dao->mt_cfg.
    ENDLOOP.
    rs_result = NEW zcl_cd_ops_trace_engine( )->trace( VALUE #( fin    = ls_scenario-fin
                                                                source = zcl_cd_ops_pay_fixture=>gc_source-pclm ) ).
  ENDMETHOD.


  METHOD outcome_row.
    rs_row = VALUE #( is_result-rows[ stage = zif_cd_ops_trace_types=>gc_stage-outcome ] OPTIONAL ).
  ENDMETHOD.


  " Same fixture as A_INFLIGHT and the dashboard: a retrieval is RETRIEVED, never RETURNED
  METHOD retrieval_shown_not_returned.
    TRY.
        DATA(ls_result) = trace( zcl_cd_ops_pay_fixture=>gc_scenario-retrieval ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-outcome exp = zif_cd_ops_payout_types=>gc_outcome-retrieved
                                            msg = 'Trace outcome RETRIEVED' ).
        cl_abap_unit_assert=>assert_equals( act = outcome_row( ls_result )-status exp = zif_cd_ops_trace_types=>gc_status-verified
                                            msg = 'Outcome row verified' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A bank line without clearing is INCONSISTENT (row FAILED), never settled
  METHOD line_without_clearing_failed.
    TRY.
        DATA(ls_result) = trace( zcl_cd_ops_pay_fixture=>gc_scenario-bank_line ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-outcome exp = zif_cd_ops_payout_types=>gc_outcome-inconsistent
                                            msg = 'Trace outcome INCONSISTENT' ).
        cl_abap_unit_assert=>assert_equals( act = outcome_row( ls_result )-status exp = zif_cd_ops_trace_types=>gc_status-failed
                                            msg = 'Outcome row FAILED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Two DPAYH runs: the row names the latest run
  METHOD latest_run_shown.
    TRY.
        DATA(ls_scenario) = mo_fixture->scenario( zcl_cd_ops_pay_fixture=>gc_scenario-two_runs ).
        DATA(ls_result) = trace( ls_scenario-id ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-outcome exp = ls_scenario-expected msg = 'CLEARED' ).
        cl_abap_unit_assert=>assert_equals( act = outcome_row( ls_result )-evidence_date exp = ls_scenario-expected_laufd
                                            msg = 'Run date of the latest run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A FIN in two sources is AMBIGUOUS in the trace too (the input source does not pick one)
  METHOD two_sources_ambiguous.
    TRY.
        DATA(ls_result) = trace( zcl_cd_ops_pay_fixture=>gc_scenario-two_sources ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-outcome exp = zif_cd_ops_payout_types=>gc_outcome-ambiguous
                                            msg = 'Trace outcome AMBIGUOUS' ).
        cl_abap_unit_assert=>assert_equals( act = outcome_row( ls_result )-status exp = zif_cd_ops_trace_types=>gc_status-ambiguous
                                            msg = 'Outcome row AMBIGUOUS' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The outcome is shown, the evidence verdict is judged without it (an INCONSISTENT outcome is
  " not a FAILED trace by itself)
  METHOD outcome_never_changes_verdict.
    TRY.
        DATA(ls_result) = trace( zcl_cd_ops_pay_fixture=>gc_scenario-bank_line ).
        cl_abap_unit_assert=>assert_differs( act = ls_result-first_gap_stage exp = zif_cd_ops_trace_types=>gc_stage-outcome
                                             msg = 'OUTCOME is never the first gap' ).
        cl_abap_unit_assert=>assert_false( act = outcome_row( ls_result )-first_gap msg = 'No gap flag on the outcome row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
