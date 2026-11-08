*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_proc.clas.testclasses.abap
*& Purpose:
*& Application tests of the instant PRISM unit through the real FMON engine
*& (ZCL_CD_FMON_ENGINE=>RUN_EVENT) with LTD_* doubles (FMON DAO, PRISM DAO,
*& store, alert, clock): stage applied, SLA finding closed / opened, PRISM_FAILED
*& opened, unknown file deferred, version conflict retried and left to the
*& 5-minute run; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (instant PRISM processing, user decision 2026-11-06).
*& 2026-11-06 | Modern-syntax sweep: no trailing RETURN.
*& 2026-11-06 | PRISM throttle: the unit applies the same queue allowance as the batch run
*&              (ACH queue, positive pay not counted, throttle 0, PRISM_QUEUE_LONG).
*& 2026-11-06 | Interface name pattern seeds are PCRE.
*& 2026-11-07 | Store double: get_param delegates to the shared fake ZCL_CD_OPS_PARAMS_MEM; the blank
*&            | FMON_PRISM_INSTANT simulation is marked (not reachable through the real store).
*& 2026-11-07 | Parameters over ZCA_PARAM (ZCL_CD_OPS_PARAM_SEED): FMON_PRISM_INSTANT is BOOL, registry-only
*&            | mode is a value row with blank value - the simulation in the store double is gone.
*& 2026-11-07 | Regenerated files (user 2026-11-07), instant path: a regenerated file whose earlier
*&            | generation was delivered is FILE_REGENERATED_NOT_FAILED in the unit, a failure answered
*&            | by a later generation is FILE_REPLACED, a duplicate-name rejection PRISM_DUPLICATE_NAME
*&            | (DAO doubles serve the generations of the group and the PRISM failures).
*& 2026-11-08 | Table consolidation: SLA rows of the DAO double carry KIND DURATION and DAY_TYPE '*'.
*&---------------------------------------------------------------------*
CLASS ltd_fmon_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_dao PARTIALLY IMPLEMENTED.
    DATA mt_ifaces TYPE zif_cd_fmon_types=>tt_iface.
    DATA mt_slas TYPE zif_cd_fmon_types=>tt_sla.
    DATA mt_srcs TYPE zif_cd_fmon_types=>tt_src.
    DATA mt_maps TYPE zif_cd_fmon_types=>tt_srcmap.
    DATA mt_checks TYPE zif_cd_fmon_types=>tt_chk.
    DATA mt_existing TYPE zif_cd_fmon_types=>tt_file.
    DATA mt_old_events TYPE zif_cd_fmon_types=>tt_event.
    DATA mt_saved TYPE zif_cd_fmon_types=>tt_file.
    DATA mt_events TYPE zif_cd_fmon_types=>tt_event.
    DATA mv_save_calls TYPE i.
    DATA mv_eval_calls TYPE i.
    "! Every save finds a newer version (another process changed the file, audit A04)
    DATA mv_conflict_all TYPE abap_bool.
    "! Other generations of the generation groups (ZCD_FMON_FILE index GRP)
    DATA mt_group_files TYPE zif_cd_fmon_types=>tt_file.
ENDCLASS.


CLASS ltd_fmon_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_dao~get_group_files.
    LOOP AT mt_group_files ASSIGNING FIELD-SYMBOL(<ls_file>).
      IF line_exists( it_keys[ iface_id = <ls_file>-iface_id gen_group = <ls_file>-gen_group ] ).
        INSERT <ls_file> INTO TABLE rt_files.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_ifaces.
    rt_ifaces = mt_ifaces.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_slas.
    rt_slas = mt_slas.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_calendars.
    CLEAR rt_cals.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_sources.
    rt_sources = mt_srcs.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_source_maps.
    rt_maps = mt_maps.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_lot_configs.
    CLEAR rt_cfgs.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_checks.
    rt_checks = mt_checks.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~find_files_by_ref.
    LOOP AT mt_existing ASSIGNING FIELD-SYMBOL(<ls_file>).
      IF line_exists( it_keys[ iface_id = <ls_file>-iface_id file_ref = <ls_file>-file_ref ] ).
        INSERT <ls_file> INTO TABLE rt_files.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_eval_files.
    mv_eval_calls += 1.
    rt_files = mt_existing.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_history.
    CLEAR rt_files.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_events.
    rt_events = mt_old_events.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~save_files.
    mv_save_calls += 1.
    IF mv_conflict_all = abap_true.
      rt_conflicts = VALUE #( FOR ls_file IN it_files ( ls_file-file_id ) ).
      RETURN.
    ENDIF.
    mt_saved = it_files.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~insert_event.
    INSERT is_event INTO TABLE mt_events.
    rv_inserted = abap_true.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_prism_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_prism_dao PARTIALLY IMPLEMENTED.
    DATA ms_row TYPE zif_cd_fmon_prism_types=>ty_row.
    DATA mt_marked TYPE zif_cd_fmon_prism_types=>tt_event_id.
    "! Stored FAILED milestones (ZCD_FMON_PRISM) for the duplicate-name read
    DATA mt_failures TYPE zif_cd_fmon_prism_types=>tt_row.
ENDCLASS.


CLASS ltd_prism_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_prism_dao~read_failures.
    LOOP AT mt_failures ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF line_exists( it_codes[ table_line = <ls_row>-error_code ] ) AND <ls_row>-business_date >= iv_since.
        INSERT <ls_row> INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_fmon_prism_dao~read_event.
    rs_row = COND #( WHEN iv_event_id = ms_row-event_id THEN ms_row ).
  ENDMETHOD.
  METHOD zif_cd_fmon_prism_dao~mark_processed.
    INSERT LINES OF it_event_ids INTO TABLE mt_marked.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store PARTIALLY IMPLEMENTED.
    DATA mt_saved_findings TYPE zif_cd_ops_types=>tt_finding.
    DATA mv_variant TYPE zif_cd_ops_types=>ty_variant.
    DATA mv_commits TYPE i.
    DATA mv_reconciles TYPE i.
ENDCLASS.


CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~start_run.
    mv_variant      = iv_variant.
    rs_run-pe_area  = iv_pe_area.
    rs_run-variant  = iv_variant.
    rs_run-status   = zif_cd_ops_types=>gc_run_status-running.
  ENDMETHOD.
  METHOD zif_cd_ops_store~save_findings.
    INSERT LINES OF it_findings INTO TABLE mt_saved_findings.
    cs_run-finding_count += lines( it_findings ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~finish_run.
  ENDMETHOD.
  METHOD zif_cd_ops_store~commit.
    mv_commits += 1.
  ENDMETHOD.
  METHOD zif_cd_ops_store~reconcile.
    mv_reconciles += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_alert DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert.
    DATA mt_dispatched TYPE zif_cd_ops_types=>tt_finding.
    DATA mv_dispatches TYPE i.
ENDCLASS.


CLASS ltd_alert IMPLEMENTATION.
  METHOD zif_cd_ops_alert~send.
  ENDMETHOD.
  METHOD zif_cd_ops_alert~dispatch.
    mv_dispatches += 1.
    mt_dispatched = it_findings.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
ENDCLASS.


CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = '20261106145000'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261106'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = '145000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_proc DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flags,
        milestone     TYPE zif_cd_fmon_prism_types=>ty_milestone,
        occurred_at   TYPE timestampl,
        unknown_file  TYPE abap_bool,
        processed     TYPE abap_bool,
        conflict      TYPE abap_bool,
        registry_only TYPE abap_bool,
        "! ACH interface (throttled) with 4 ACH files and 1 positive pay file queued ahead
        throttled     TYPE abap_bool,
        "! FMON_PRISM_THROTTLE_MIN = 0
        throttle_off  TYPE abap_bool,
        "! FMON_PRISM_QUEUE_MAX maintained (0 = default)
        queue_max     TYPE i,
        "! Regenerated files: another generation of the file's group - E earlier (delivered),
        "! L later (regenerated after the file)
        peer          TYPE c LENGTH 1,
        "! PRISM's failure carries a duplicate-name code that FMON_PRISM_DUP_NAME_CODES lists
        dup_name      TYPE abap_bool,
      END OF ty_flags.

    "! Regenerated files: the payment run of the file and its other generation
    CONSTANTS:
      BEGIN OF gc_regen,
        group     TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261106/RUN07/PNC1',
        peer_name TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_PNC_20261106_02',
        peer_id   TYPE zif_cd_fmon_types=>ty_file_id VALUE '0000000000000000000000000000000B',
        earlier   TYPE timestampl VALUE '20261106140000',
        later     TYPE timestampl VALUE '20261106144000',
        dup_code  TYPE zif_cd_fmon_prism_types=>ty_error_code VALUE 'FILE_EXISTS',
        peer_e    TYPE c LENGTH 1 VALUE 'E',
        peer_l    TYPE c LENGTH 1 VALUE 'L',
      END OF gc_regen.

    CONSTANTS:
      BEGIN OF gc_test,
        event_id  TYPE zif_cd_fmon_prism_types=>ty_event_id VALUE 'PRISM-0001',
        iface     TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_PNC_OUT',
        file_name TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_PNC_20261106_01',
        unknown   TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_PNC_20261106_99',
        src_id    TYPE zif_cd_fmon_types=>ty_src_id VALUE 'PRISM',
        date      TYPE d VALUE '20261106',
        sent_at   TYPE timestampl VALUE '20261106142000',
        on_time   TYPE timestampl VALUE '20261106143000',
        too_late  TYPE timestampl VALUE '20261106144500',
        version   TYPE timestampl VALUE '20261106142100',
        sla_min   TYPE i VALUE 15,
      END OF gc_test.
    "! Evening ACH cycle: 4 ACH files and a positive pay file reached PRISM before the file
    "! (received 14:21); PRISM delivers one file every 2 minutes
    CONSTANTS:
      BEGIN OF gc_queue,
        pospay_iface TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'CHECK_POSPAY_OUT',
        ach          TYPE zif_cd_fmon_types=>ty_pay_method VALUE 'ACH',
        check        TYPE zif_cd_fmon_types=>ty_pay_method VALUE 'CHECK',
        bank         TYPE zif_cd_fmon_types=>ty_bank_key VALUE 'PNC',
        "! The ACH peers' receipts 14:20:10 .. 14:20:40, the positive pay file 14:20:50
        first_peer   TYPE timestampl VALUE '20261106142010',
        peer_step    TYPE i VALUE 10,
        peers        TYPE i VALUE 4,
        received_at  TYPE timestampl VALUE '20261106142100',
        "! 9 / 14 minutes after the receipt
        after_9_min  TYPE timestampl VALUE '20261106143000',
        after_14_min TYPE timestampl VALUE '20261106143500',
        base_min     TYPE i VALUE 5,
        short_queue  TYPE i VALUE 3,
      END OF gc_queue.

    DATA mo_dao TYPE REF TO ltd_fmon_dao.
    DATA mo_prism TYPE REF TO ltd_prism_dao.
    DATA mo_store TYPE REF TO ltd_store.
    DATA mo_alert TYPE REF TO ltd_alert.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS act
      RETURNING
        VALUE(rs_outcome) TYPE zcl_cd_fmon_prism_proc=>ty_outcome.

    METHODS add_check
      IMPORTING
        iv_check_id TYPE zif_cd_fmon_types=>ty_check_id
        iv_class    TYPE zif_cd_ops_types=>ty_class_name
        iv_params   TYPE zif_cd_fmon_types=>ty_params OPTIONAL.

    METHODS add_map
      IMPORTING
        iv_value TYPE zif_cd_fmon_types=>ty_status_value
        iv_stage TYPE zif_cd_fmon_types=>ty_stage.

    METHODS codes
      IMPORTING
        it_findings     TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rt_codes) TYPE string_table.

    METHODS unit_applies_prism_stage FOR TESTING.
    METHODS late_event_opens_sla_finding FOR TESTING.
    METHODS failed_event_opens_finding FOR TESTING.
    METHODS unknown_file_is_deferred FOR TESTING.
    METHODS conflict_left_to_batch_run FOR TESTING.
    METHODS processed_event_not_reapplied FOR TESTING.
    METHODS registry_only_without_instant FOR TESTING.
    METHODS unit_allows_prism_queue FOR TESTING.
    METHODS pospay_not_in_ach_queue FOR TESTING.
    METHODS unit_throttle_off_is_late FOR TESTING.
    METHODS unit_reports_long_queue FOR TESTING.
    METHODS unit_flags_regen_not_failed FOR TESTING.
    METHODS unit_failure_replaced_is_info FOR TESTING.
    METHODS unit_dup_name_not_failed FOR TESTING.

    "! The file belongs to a generation group; the other generation is served by index GRP
    METHODS configure_regen
      IMPORTING
        is_flags TYPE ty_flags.

    "! Throttled scenario: interfaces, SLA, check, the file's receipt and the queued peers
    METHODS configure_queue
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS add_peer
      IMPORTING
        iv_no       TYPE i
        iv_iface_id TYPE zif_cd_fmon_types=>ty_iface_id
        iv_received TYPE timestampl.

ENDCLASS.


CLASS ltc_proc IMPLEMENTATION.

  METHOD setup.
    mo_dao   = NEW #( ).
    mo_prism = NEW #( ).
    mo_store = NEW #( ).
    mo_alert = NEW #( ).
    zcl_cd_fmon_injector=>inject_dao( mo_dao ).
    zcl_cd_fmon_injector=>inject_prism_dao( mo_prism ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    mo_params = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    zcl_cd_ops_injector=>inject_alert( mo_alert ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR: mo_dao, mo_prism, mo_store, mo_alert.
    zcl_cd_fmon_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD add_check.
    DATA ls_check TYPE zif_cd_fmon_types=>ty_chk.
    ls_check-check_id   = iv_check_id.
    ls_check-class_name = iv_class.
    ls_check-severity   = zif_cd_ops_types=>gc_severity-error.
    ls_check-active     = abap_true.
    ls_check-params     = iv_params.
    INSERT ls_check INTO TABLE mo_dao->mt_checks.
  ENDMETHOD.


  METHOD add_map.
    DATA ls_map TYPE zif_cd_fmon_types=>ty_srcmap.
    ls_map-src_id       = gc_test-src_id.
    ls_map-status_value = iv_value.
    ls_map-stage        = iv_stage.
    INSERT ls_map INTO TABLE mo_dao->mt_maps.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    DATA ls_sla TYPE zif_cd_fmon_types=>ty_sla.
    DATA ls_src TYPE zif_cd_fmon_types=>ty_src.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    DATA ls_event TYPE zif_cd_fmon_types=>ty_event.

    ls_iface-iface_id     = gc_test-iface.
    ls_iface-direction    = zif_cd_fmon_types=>gc_direction-outbound.
    ls_iface-file_type    = zif_cd_fmon_types=>gc_file_type-payment.
    ls_iface-source_sys   = zif_cd_fmon_types=>gc_wildcard.
    ls_iface-lob          = zif_cd_fmon_types=>gc_wildcard.
    ls_iface-name_pattern = 'ACH_PNC_.*'.
    ls_iface-ack_expected = abap_true.
    ls_iface-active       = abap_true.
    INSERT ls_iface INTO TABLE mo_dao->mt_ifaces.

    ls_sla-iface_id    = gc_test-iface.
    ls_sla-kind        = zif_cd_fmon_types=>gc_sla_kind-duration.
    ls_sla-day_type    = zif_cd_fmon_types=>gc_wildcard.
    ls_sla-stage       = zif_cd_fmon_types=>gc_stage-prism_received.
    ls_sla-max_minutes = gc_test-sla_min.
    ls_sla-basis       = zif_cd_fmon_types=>gc_sla_basis-previous.
    ls_sla-severity    = zif_cd_ops_types=>gc_severity-error.
    INSERT ls_sla INTO TABLE mo_dao->mt_slas.

    " The configured PRISM source (fmon_seed.md) with its stage map
    ls_src-src_id          = gc_test-src_id.
    ls_src-table_name      = 'ZCD_FMON_PRISM'.
    ls_src-file_name_field = 'FILE_REF'.
    ls_src-ts_field        = 'OCCURRED_AT'.
    ls_src-status_field    = 'MILESTONE'.
    ls_src-adapter_class   = zif_cd_fmon_prism_types=>gc_adapter_class.
    ls_src-active          = abap_true.
    INSERT ls_src INTO TABLE mo_dao->mt_srcs.
    add_map( iv_value = CONV #( zif_cd_fmon_prism_types=>gc_milestone-received )
             iv_stage = zif_cd_fmon_types=>gc_stage-prism_received ).
    add_map( iv_value = CONV #( zif_cd_fmon_prism_types=>gc_milestone-delivered )
             iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered ).
    add_map( iv_value = CONV #( zif_cd_fmon_prism_types=>gc_milestone-failed )
             iv_stage = zif_cd_fmon_types=>gc_stage-prism_failed ).

    add_check( iv_check_id = 'F_PRISMRCV' iv_class = 'ZCL_CD_FMON_CHK_SLA' iv_params = 'STAGE=PRISM_RECEIVED' ).
    add_check( iv_check_id = 'F_PRFAIL' iv_class = 'ZCL_CD_FMON_CHK_REJECT' iv_params = 'OUTCOME=PRISM_FAILED' ).
    add_check( iv_check_id = 'F_PRFILE' iv_class = 'ZCL_CD_FMON_CHK_PRISM_FILE' ).
    " A batch-only check: must not run in the unit (it would see a file without its lot)
    add_check( iv_check_id = 'F_SIZE' iv_class = 'ZCL_CD_FMON_CHK_SIZE' ).

    " The file SAP generated and handed to PRISM (known to FMON from an earlier 5-minute run)
    ls_file-file_id        = '0000000000000000000000000000000A'.
    ls_file-iface_id       = gc_test-iface.
    ls_file-file_name      = gc_test-file_name.
    ls_file-file_ref       = zcl_cd_fmon_util=>normalize_ref( gc_test-file_name ).
    ls_file-direction      = zif_cd_fmon_types=>gc_direction-outbound.
    ls_file-file_type      = zif_cd_fmon_types=>gc_file_type-payment.
    ls_file-business_date  = gc_test-date.
    ls_file-stage          = zif_cd_fmon_types=>gc_stage-sent.
    ls_file-first_event_at = gc_test-sent_at.
    ls_file-last_event_at  = gc_test-sent_at.
    ls_file-db_exists      = abap_true.
    ls_file-db_version     = gc_test-version.
    ls_file-changed_at     = gc_test-version.
    INSERT ls_file INTO TABLE mo_dao->mt_existing.
    ls_event-file_id  = ls_file-file_id.
    ls_event-event_no = 1.
    ls_event-stage    = zif_cd_fmon_types=>gc_stage-sent.
    ls_event-event_at = gc_test-sent_at.
    ls_event-src_id   = 'REGUT'.
    ls_event-src_key  = ls_file-file_ref.
    INSERT ls_event INTO TABLE mo_dao->mt_old_events.

    IF is_flags-throttled = abap_true.
      configure_queue( is_flags ).
    ENDIF.
    IF is_flags-peer IS NOT INITIAL OR is_flags-dup_name = abap_true.
      configure_regen( is_flags ).
    ENDIF.

    mo_dao->mv_conflict_all     = is_flags-conflict.
    IF is_flags-registry_only = abap_true.
      " BOOL off: a value row with blank value (no row = the default X)
      mo_params->set( iv_name = zif_cd_fmon_prism_types=>gc_param_instant iv_value = space ).
    ENDIF.

    mo_prism->ms_row-event_id     = gc_test-event_id.
    mo_prism->ms_row-file_ref     = COND #( WHEN is_flags-unknown_file = abap_true THEN gc_test-unknown
                                            ELSE gc_test-file_name ).
    mo_prism->ms_row-direction    = zif_cd_fmon_types=>gc_direction-outbound.
    mo_prism->ms_row-milestone    = COND #( WHEN is_flags-milestone IS NOT INITIAL THEN is_flags-milestone
                                            ELSE zif_cd_fmon_prism_types=>gc_milestone-received ).
    mo_prism->ms_row-occurred_at  = COND #( WHEN is_flags-occurred_at IS NOT INITIAL THEN is_flags-occurred_at
                                            ELSE gc_test-on_time ).
    mo_prism->ms_row-counterparty = 'PNC'.
    mo_prism->ms_row-processed_at = COND #( WHEN is_flags-processed = abap_true THEN gc_test-version ).
  ENDMETHOD.


  METHOD act.
    rs_outcome = NEW zcl_cd_fmon_prism_proc( )->process( gc_test-event_id ).
  ENDMETHOD.


  METHOD configure_regen.
    DATA ls_failure TYPE zif_cd_fmon_prism_types=>ty_row.
    add_check( iv_check_id = 'F_REGEN' iv_class = 'ZCL_CD_FMON_CHK_REGEN' ).
    ASSIGN mo_dao->mt_existing[ 1 ] TO FIELD-SYMBOL(<ls_file>).
    <ls_file>-gen_group = gc_regen-group.
    IF is_flags-peer IS NOT INITIAL.
      DATA(ls_peer) = <ls_file>.
      ls_peer-file_id        = gc_regen-peer_id.
      ls_peer-file_name      = gc_regen-peer_name.
      ls_peer-file_ref       = zcl_cd_fmon_util=>normalize_ref( gc_regen-peer_name ).
      ls_peer-stage          = COND #( WHEN is_flags-peer = gc_regen-peer_e THEN zif_cd_fmon_types=>gc_stage-prism_delivered
                                       ELSE zif_cd_fmon_types=>gc_stage-generated ).
      ls_peer-first_event_at = COND #( WHEN is_flags-peer = gc_regen-peer_e THEN gc_regen-earlier ELSE gc_regen-later ).
      ls_peer-last_event_at  = ls_peer-first_event_at.
      INSERT ls_peer INTO TABLE mo_dao->mt_group_files.
    ENDIF.
    IF is_flags-dup_name = abap_true.
      mo_params->set( iv_name = zif_cd_fmon_types=>gc_param-dup_name_codes iv_value = CONV #( gc_regen-dup_code ) ).
      ls_failure-event_id      = gc_test-event_id.
      ls_failure-file_ref      = gc_test-file_name.
      ls_failure-milestone     = zif_cd_fmon_prism_types=>gc_milestone-failed.
      ls_failure-error_code    = gc_regen-dup_code.
      ls_failure-occurred_at   = gc_test-on_time.
      ls_failure-business_date = gc_test-date.
      INSERT ls_failure INTO TABLE mo_prism->mt_failures.
    ENDIF.
  ENDMETHOD.


  METHOD configure_queue.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    DATA ls_sla TYPE zif_cd_fmon_types=>ty_sla.
    DATA ls_event TYPE zif_cd_fmon_types=>ty_event.

    " The file's interface is an ACH interface to PNC: throttled (FMON_PRISM_THROTTLE_METHODS)
    ASSIGN mo_dao->mt_ifaces[ iface_id = gc_test-iface ] TO FIELD-SYMBOL(<ls_iface>).
    <ls_iface>-pay_method = gc_queue-ach.
    <ls_iface>-bank_key   = gc_queue-bank.
    ls_iface = <ls_iface>.
    ls_iface-iface_id     = gc_queue-pospay_iface.
    ls_iface-file_type    = zif_cd_fmon_types=>gc_file_type-pospay.
    ls_iface-pay_method   = gc_queue-check.
    ls_iface-name_pattern = 'POSPAY_.*'.
    INSERT ls_iface INTO TABLE mo_dao->mt_ifaces.

    ls_sla-iface_id    = gc_test-iface.
    ls_sla-kind        = zif_cd_fmon_types=>gc_sla_kind-duration.
    ls_sla-day_type    = zif_cd_fmon_types=>gc_wildcard.
    ls_sla-stage       = zif_cd_fmon_types=>gc_stage-prism_delivered.
    ls_sla-max_minutes = gc_queue-base_min.
    ls_sla-basis       = zif_cd_fmon_types=>gc_sla_basis-previous.
    ls_sla-severity    = zif_cd_ops_types=>gc_severity-error.
    INSERT ls_sla INTO TABLE mo_dao->mt_slas.
    add_check( iv_check_id = 'F_PRISMDLV' iv_class = 'ZCL_CD_FMON_CHK_SLA' iv_params = 'STAGE=PRISM_DELIVERED' ).

    " The file itself: PRISM received it at 14:21 (stored by an earlier unit)
    ASSIGN mo_dao->mt_existing[ 1 ] TO FIELD-SYMBOL(<ls_file>).
    <ls_file>-stage         = zif_cd_fmon_types=>gc_stage-prism_received.
    <ls_file>-last_event_at = gc_queue-received_at.
    ls_event-file_id  = <ls_file>-file_id.
    ls_event-event_no = 2.
    ls_event-stage    = zif_cd_fmon_types=>gc_stage-prism_received.
    ls_event-event_at = gc_queue-received_at.
    ls_event-src_id   = gc_test-src_id.
    ls_event-src_key  = <ls_file>-file_ref.
    INSERT ls_event INTO TABLE mo_dao->mt_old_events.

    DO gc_queue-peers TIMES.
      add_peer( iv_no       = sy-index
                iv_iface_id = gc_test-iface
                iv_received = cl_abap_tstmp=>add( tstmp = gc_queue-first_peer
                                                  secs  = ( sy-index - 1 ) * gc_queue-peer_step ) ).
    ENDDO.
    add_peer( iv_no       = gc_queue-peers + 1
              iv_iface_id = gc_queue-pospay_iface
              iv_received = cl_abap_tstmp=>add( tstmp = gc_queue-first_peer
                                                secs  = gc_queue-peers * gc_queue-peer_step ) ).

    IF is_flags-throttle_off = abap_true.
      mo_params->set( iv_name = zif_cd_fmon_types=>gc_param-throttle_min iv_value = `0` ).
    ENDIF.
    IF is_flags-queue_max > 0.
      mo_params->set( iv_name = zif_cd_fmon_types=>gc_param-queue_max iv_value = |{ is_flags-queue_max }| ).
    ENDIF.
  ENDMETHOD.


  METHOD add_peer.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    DATA ls_event TYPE zif_cd_fmon_types=>ty_event.
    ls_file-file_id        = CONV zif_cd_fmon_types=>ty_file_id( iv_no ).
    ls_file-iface_id       = iv_iface_id.
    ls_file-file_name      = |PEER_{ iv_no }|.
    ls_file-file_ref       = zcl_cd_fmon_util=>normalize_ref( ls_file-file_name ).
    ls_file-direction      = zif_cd_fmon_types=>gc_direction-outbound.
    ls_file-business_date  = gc_test-date.
    ls_file-stage          = zif_cd_fmon_types=>gc_stage-prism_received.
    ls_file-first_event_at = gc_test-sent_at.
    ls_file-last_event_at  = iv_received.
    ls_file-db_exists      = abap_true.
    INSERT ls_file INTO TABLE mo_dao->mt_existing.
    ls_event-file_id  = ls_file-file_id.
    ls_event-event_no = 1.
    ls_event-stage    = zif_cd_fmon_types=>gc_stage-prism_received.
    ls_event-event_at = iv_received.
    ls_event-src_id   = gc_test-src_id.
    ls_event-src_key  = ls_file-file_ref.
    INSERT ls_event INTO TABLE mo_dao->mt_old_events.
  ENDMETHOD.


  METHOD codes.
    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      INSERT CONV string( <ls_finding>-check_code ) INTO TABLE rt_codes.
    ENDLOOP.
    SORT rt_codes.
  ENDMETHOD.


  " Rule: the unit applies PRISM_RECEIVED to the known file at once, records PRISM's event,
  " finds the SLA met (no NO_/LATE finding), runs no batch-only check, marks the event processed.
  METHOD unit_applies_prism_stage.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_outcome-processed }/{ ls_outcome-deferred }|
                                            exp = |{ abap_true }/|
                                            msg = 'The event must be applied and not deferred' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-stage
                                            exp = zif_cd_fmon_types=>gc_stage-prism_received
                                            msg = 'The file must be PRISM_RECEIVED' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_events[ 1 ]-event_at exp = gc_test-on_time
                                            msg = 'The event carries PRISM''s own time' ).
        cl_abap_unit_assert=>assert_initial( act = codes( ls_outcome-result-findings )
                                             msg = 'SLA met, no batch-only check: no finding' ).
        cl_abap_unit_assert=>assert_equals( act = mo_prism->mt_marked
                                            exp = VALUE zif_cd_fmon_prism_types=>tt_event_id( ( gc_test-event_id ) )
                                            msg = 'The event must be marked processed' ).
        cl_abap_unit_assert=>assert_equals( act = |{ mo_store->mv_variant }/{ mo_dao->mv_eval_calls }/|
                                               && |{ mo_store->mv_reconciles }|
                                            exp = |PRISM/0/0|
                                            msg = 'Own run variant; no batch file read, no reconcile' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PRISM_RECEIVED 25 minutes after SENT_TO_PRISM (SLA 15) opens PRISM_RECEIVED_LATE at
  " once - saved and handed to the alert router like a batch finding.
  METHOD late_event_opens_sla_finding.
    TRY.
        configure_scenario( VALUE #( occurred_at = gc_test-too_late ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = codes( mo_store->mt_saved_findings )
                                            exp = VALUE string_table( ( `PRISM_RECEIVED_LATE` ) )
                                            msg = 'The late receipt must be saved as a finding' ).
        cl_abap_unit_assert=>assert_equals( act = codes( mo_alert->mt_dispatched )
                                            exp = VALUE string_table( ( `PRISM_RECEIVED_LATE` ) )
                                            msg = 'and dispatched to the alert router' ).
        cl_abap_unit_assert=>assert_true( act = ls_outcome-processed msg = 'The event is processed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a FAILED event makes the file PRISM_FAILED and opens the PRISM_FAILED finding at once;
  " the receipt PRISM never confirmed is reported as inferred (A40, severity I).
  " Rule (regenerated files, instant path): PRISM's receipt of a regenerated file whose earlier
  " generation of the same payment run was delivered raises FILE_REGENERATED_NOT_FAILED in the unit
  " (the earlier generation is read by index GRP) and alerts at once.
  METHOD unit_flags_regen_not_failed.
    TRY.
        configure_scenario( VALUE #( peer = gc_regen-peer_e ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_outcome-result-findings[
                                        check_code = zif_cd_fmon_types=>gc_check_code-regen_not_failed
                                        object_key = gc_test-file_name ] ) )
          msg = 'Possible duplicate raised by the instant unit' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_alert->mt_dispatched[ check_code = zif_cd_fmon_types=>gc_check_code-regen_not_failed ] ) )
          msg = 'Handed to the alert router at once' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (a, instant path): PRISM's failure of a file SAP has already regenerated is answered -
  " FILE_REPLACED (information), no PRISM_FAILED.
  METHOD unit_failure_replaced_is_info.
    TRY.
        configure_scenario( VALUE #( milestone = zif_cd_fmon_prism_types=>gc_milestone-failed
                                     peer      = gc_regen-peer_l ) ).
        DATA(lt_codes) = codes( act( )-result-findings ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_codes[ table_line = `FILE_REPLACED` ] ) )
                                          msg = 'The replaced failure is information' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_codes[ table_line = `PRISM_FAILED` ] ) )
                                           msg = 'No PRISM_FAILED for a replaced file' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (d, instant path): PRISM rejected the name as already received (listed error code) -
  " PRISM_DUPLICATE_NAME instead of PRISM_FAILED.
  METHOD unit_dup_name_not_failed.
    TRY.
        configure_scenario( VALUE #( milestone = zif_cd_fmon_prism_types=>gc_milestone-failed
                                     dup_name  = abap_true ) ).
        DATA(lt_codes) = codes( act( )-result-findings ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_codes[ table_line = `PRISM_DUPLICATE_NAME` ] ) )
                                          msg = 'The precise cause is reported' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_codes[ table_line = `PRISM_FAILED` ] ) )
                                           msg = 'Not a second, generic PRISM_FAILED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD failed_event_opens_finding.
    TRY.
        configure_scenario( VALUE #( milestone = zif_cd_fmon_prism_types=>gc_milestone-failed ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-outcome
                                            exp = zif_cd_fmon_types=>gc_stage-prism_failed
                                            msg = 'Outcome must be PRISM_FAILED' ).
        cl_abap_unit_assert=>assert_equals( act = codes( ls_outcome-result-findings )
                                            exp = VALUE string_table( ( `PRISM_FAILED` ) ( `PRISM_RECEIVED_INFERRED` ) )
                                            msg = 'PRISM_FAILED, and PRISM_RECEIVED only inferred (information)' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatches exp = 1
                                            msg = 'The finding goes to the alert router' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an outbound event for a file FMON does not know yet is not applied by the unit (no
  " file opened by PRISM alone) - left unprocessed for the 5-minute run.
  METHOD unknown_file_is_deferred.
    TRY.
        configure_scenario( VALUE #( unknown_file = abap_true ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_outcome-processed }/{ ls_outcome-deferred }|
                                            exp = |/{ abap_true }|
                                            msg = 'The event must be deferred' ).
        cl_abap_unit_assert=>assert_initial( act = mo_prism->mt_marked msg = 'It must stay unprocessed' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_saved msg = 'No file may be opened' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (concurrency, A04): when the 5-minute run changed the file meanwhile, the stale version
  " is never overwritten; the unit retries once with a fresh read and then leaves the event
  " unprocessed, so the 5-minute run applies it.
  METHOD conflict_left_to_batch_run.
    TRY.
        configure_scenario( VALUE #( conflict = abap_true ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_outcome-attempts }/{ mo_dao->mv_save_calls }|
                                            exp = |{ zif_cd_fmon_prism_types=>gc_unit_attempts }/|
                                               && |{ zif_cd_fmon_prism_types=>gc_unit_attempts }|
                                            msg = 'One retry with a fresh engine' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_saved msg = 'The stale version is not written' ).
        cl_abap_unit_assert=>assert_initial( act = mo_prism->mt_marked msg = 'The event stays unprocessed' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_outcome-result-findings[
                           check_code = zif_cd_fmon_types=>gc_check_code-persist_conflict ] ) )
          msg = 'The conflict is visible' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an event already processed (e.g. bgPF re-delivered the unit) is not applied again.
  METHOD processed_event_not_reapplied.
    TRY.
        configure_scenario( VALUE #( processed = abap_true ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = |{ ls_outcome-attempts }/{ mo_dao->mv_save_calls }| exp = |0/0|
                                            msg = 'No engine run for a processed event' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (PRISM throttle, user 2026-11-06): PRISM delivers ACH files one every 2 minutes. The
  " file had 4 ACH files ahead in PRISM's queue, so its delivery 9 minutes after PRISM's receipt
  " is on time (SLA 5 + 4 x 2 = 13 min) - the unit applies the same rule as the batch run.
  METHOD unit_allows_prism_queue.
    TRY.
        configure_scenario( VALUE #( throttled   = abap_true
                                     milestone   = zif_cd_fmon_prism_types=>gc_milestone-delivered
                                     occurred_at = gc_queue-after_9_min ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-stage
                                            exp = zif_cd_fmon_types=>gc_stage-prism_delivered
                                            msg = 'The delivery must be applied' ).
        cl_abap_unit_assert=>assert_initial( act = codes( ls_outcome-result-findings )
                                             msg = 'Delivered within the queue allowance: no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: positive pay is not throttled, so the positive pay file queued with the ACH files does
  " not extend the ACH allowance: delivery after 14 min (allowed 13) is late.
  METHOD pospay_not_in_ach_queue.
    TRY.
        configure_scenario( VALUE #( throttled   = abap_true
                                     milestone   = zif_cd_fmon_prism_types=>gc_milestone-delivered
                                     occurred_at = gc_queue-after_14_min ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = codes( ls_outcome-result-findings )
                                            exp = VALUE string_table( ( `PRISM_DELIVERED_LATE` ) )
                                            msg = 'Only the 4 ACH files count: 14 min is late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: FMON_PRISM_THROTTLE_MIN = 0 keeps today's behaviour - 9 minutes against SLA 5 is late.
  METHOD unit_throttle_off_is_late.
    TRY.
        configure_scenario( VALUE #( throttled    = abap_true
                                     throttle_off = abap_true
                                     milestone    = zif_cd_fmon_prism_types=>gc_milestone-delivered
                                     occurred_at  = gc_queue-after_9_min ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = codes( ls_outcome-result-findings )
                                            exp = VALUE string_table( ( `PRISM_DELIVERED_LATE` ) )
                                            msg = 'Throttle off: no queue allowance' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a queue longer than FMON_PRISM_QUEUE_MAX (here 3; the file is 5th) is reported as
  " PRISM_QUEUE_LONG (W); the allowance stops at 2 files ahead (4 min), so 9 min is still on time.
  METHOD unit_reports_long_queue.
    TRY.
        configure_scenario( VALUE #( throttled   = abap_true
                                     queue_max   = gc_queue-short_queue
                                     milestone   = zif_cd_fmon_prism_types=>gc_milestone-delivered
                                     occurred_at = gc_queue-after_9_min ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = codes( ls_outcome-result-findings )
                                            exp = VALUE string_table( ( `PRISM_QUEUE_LONG` ) )
                                            msg = 'The long queue must be visible' ).
        cl_abap_unit_assert=>assert_equals( act = ls_outcome-result-findings[ 1 ]-severity
                                            exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'PRISM_QUEUE_LONG is a warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: with FMON_PRISM_INSTANT blank the unit updates the registry only; findings and alerts
  " are left to the 5-minute run.
  METHOD registry_only_without_instant.
    TRY.
        configure_scenario( VALUE #( occurred_at = gc_test-too_late registry_only = abap_true ) ).
        DATA(ls_outcome) = act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-stage
                                            exp = zif_cd_fmon_types=>gc_stage-prism_received
                                            msg = 'The stage is applied at once' ).
        cl_abap_unit_assert=>assert_equals( act = |{ lines( mo_store->mt_saved_findings ) }/{ mo_alert->mv_dispatches }|
                                            exp = |0/0|
                                            msg = 'No finding saved, nothing dispatched' ).
        cl_abap_unit_assert=>assert_true( act = ls_outcome-processed msg = 'The event is processed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
