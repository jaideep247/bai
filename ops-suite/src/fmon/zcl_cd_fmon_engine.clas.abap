*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_engine.clas.abap
*& Purpose:
*& FMON application service for one business date: sync the registry from
*& legacy adapters, apply stage transitions, derive lot outcomes, run the
*& plug-in checks, persist, write findings and dispatch alerts.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | Run header committed at start; results committed before alerts;
*&              failed registry save rolled back; READ TABLE replaces OPTIONAL + sy-subrc.
*& 2026-11-06 | Run lock for the whole payment engine area (shared registry); body moved to execute( ).
*& 2026-11-06 | Exception carry-forward: evaluated files reconciled before the commit.
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A04 save conflicts reported, A05 SQL errors handled at the LUW owner,
*&              A38 truncated lot scans, A39 payment-level ACK dedupe and cumulative counts,
*&              A40 events stored as applied, A41 unknown age, A49 file instance by
*&              business date, A52 malformed rows quarantined.
*& 2026-11-06 | Digest file references verified against the full file name in the registry (audit A100).
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | PRISM status API: direction fit and file-instance origin from ZCL_CD_FMON_STATUS
*&              (PRISM_* stages in both directions; inbound PRISM evidence opens the instance).
*& 2026-11-06 | run_event( ): single-event entry point of the instant PRISM unit (bgPF); the
*&              batch path run( ) is unchanged.
*& 2026-11-06 | Modern-syntax sweep: INSERT INTO TABLE, alert tables ZCD_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-06 | PRISM throttle (user 2026-11-06): throttle settings and PRISM queue in the check
*&              context for the batch run and run_event alike (same rule, no copy).
*& 2026-11-06 | Configuration load: an interface name pattern that is not valid PCRE is a PATTERN_INVALID
*&              finding (never a silent no-match).
*& 2026-11-07 | Integer parameters with ZCL_CD_OPS_UTIL=>PARAM_INT and defaults from ZIF_CD_FMON_TYPES
*&            | (private int_param and inline defaults removed).
*& 2026-11-07 | Parameters through ZCL_CD_OPS_FACTORY=>GET_PARAMS (ZCA_PARAM) instead of the store;
*&            | FMON_PRISM_INSTANT is BOOL (blank value row = registry only).
*& 2026-11-07 | Design review: file generation identity - resolve_file( ) asks
*&            | ZCL_CD_FMON_RULES=>FILE_INSTANCE with the events of the instances found by
*&            | reference (prefetch), so one file keeps one instance across midnight and DST.
*& 2026-11-07 | BAI processing deadline: statement evidence of the FEB adapter kept for the checks
*&            | (evidence-only records are not applied), unprocessed count of a source record,
*&            | stage deadlines (ZCD_FMON_DEADL) and time zone in the check context, interface-day
*&            | keys of the expectations reconciled (a met deadline closes its exception).
*& 2026-11-07 | Regenerated files (user 2026-11-07): generation group of a file taken from its source
*&            | records (GEN_GROUP), the other generations of the groups loaded by index GRP (batch:
*&            | evaluated and reconciled; instant unit: context only), regeneration settings and PRISM
*&            | duplicate-name failures in the check context, ZCL_CD_FMON_CHK_REGEN in the instant unit.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - engine (one run per business date)</p>
"! Run order: start run -> load customizing -> sync sources -> load registry
"! -> lot outcomes -> calendar expectations -> checks -> persist registry
"! -> board -> save findings -> dispatch alerts (core router) -> finish -> commit.
"! A failing adapter, lot reader, calendar or check never aborts the run:
"! it becomes a PLUGIN_ERROR finding (severity E). Test mode writes nothing,
"! dispatches nothing and does not commit.
"! run_event( ) applies the records of one PRISM event (instant unit, no run lock: overlap with
"! the 5-minute run is safe through version-checked saves (A04) and the idempotent event insert):
"! only files FMON already knows or inbound PRISM origins, no lots / calendar, only the checks
"! the event can open or close (SLA, reject, PRISM file, regeneration), no reconcile of earlier exceptions.
CLASS zcl_cd_fmon_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS run
      IMPORTING
        iv_business_date TYPE d
        iv_iface_id      TYPE zif_cd_fmon_types=>ty_iface_id OPTIONAL
        iv_test_mode     TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_result) TYPE zif_cd_fmon_types=>ty_result
      RAISING
        zcx_cd_ops_error.

    "! Instant processing of one PRISM event (bgPF unit). Business date = the records' date.
    "! @parameter ev_deferred | an observation needs a file FMON does not know yet: nothing was
    "!                         applied for it - the 5-minute run (all sources together) decides
    METHODS run_event
      IMPORTING
        is_src           TYPE zif_cd_fmon_types=>ty_src
        it_records       TYPE zif_cd_fmon_types=>tt_src_record
      EXPORTING
        ev_deferred      TYPE abap_bool
      RETURNING
        VALUE(rs_result) TYPE zif_cd_fmon_types=>ty_result
      RAISING
        zcx_cd_ops_error.

  PRIVATE SECTION.
    "! Run variant of the instant PRISM unit (run history; no lock is taken)
    CONSTANTS gc_event_variant TYPE zif_cd_ops_types=>ty_variant VALUE 'PRISM'.
    "! Checks an event can open or close for its file (the others need the batch context)
    CONSTANTS:
      BEGIN OF gc_event_check,
        sla        TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_FMON_CHK_SLA',
        reject     TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_FMON_CHK_REJECT',
        prism_file TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_FMON_CHK_PRISM_FILE',
        "! Regenerated file while the earlier generation did not fail (duplicate risk: alert at once)
        regen      TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_FMON_CHK_REGEN',
      END OF gc_event_check.
    "! Single-event mode (run_event): source and records given, no adapter read
    DATA mv_single TYPE abap_bool.
    DATA ms_single_src TYPE zif_cd_fmon_types=>ty_src.
    DATA mt_single_records TYPE zif_cd_fmon_types=>tt_src_record.
    DATA mv_deferred TYPE abap_bool.

    "! Lock variant: one monitor run at a time for all interfaces - the registry,
    "! event numbering and lots are shared (design: payment engine area + variant; FMON uses '*')
    CONSTANTS gc_lock_variant TYPE zif_cd_ops_types=>ty_variant VALUE '*'.

    "! The run itself, under the run lock taken by run( )
    METHODS execute
      IMPORTING
        iv_business_date TYPE d
        iv_iface_id      TYPE zif_cd_fmon_types=>ty_iface_id
        iv_test_mode     TYPE abap_bool
      RETURNING
        VALUE(rs_result) TYPE zif_cd_fmon_types=>ty_result
      RAISING
        zcx_cd_ops_error.

    METHODS release_lock
      IMPORTING
        iv_test_mode TYPE abap_bool.

    "! Resolve open exceptions of earlier runs for files evaluated without a finding
    "! now. Skipped when a check, source or the registry save failed.
    METHODS reconcile_files
      IMPORTING
        is_run TYPE zif_cd_ops_types=>ty_run
      RAISING
        zcx_cd_ops_error.

    TYPES tt_file_map TYPE HASHED TABLE OF zif_cd_fmon_types=>ty_file
      WITH UNIQUE KEY file_id
      WITH NON-UNIQUE SORTED KEY ref COMPONENTS iface_id file_ref.
    TYPES tt_id_set TYPE HASHED TABLE OF zif_cd_fmon_types=>ty_file_id WITH UNIQUE KEY table_line.

    "! All rows of one source for one file and stage
    TYPES:
      BEGIN OF ty_group,
        src_id        TYPE zif_cd_fmon_types=>ty_src_id,
        iface_id      TYPE zif_cd_fmon_types=>ty_iface_id,
        file_ref      TYPE zif_cd_fmon_types=>ty_file_ref,
        stage         TYPE zif_cd_fmon_types=>ty_stage,
        raw_status    TYPE zif_cd_fmon_types=>ty_status_value,
        rows          TYPE i,
        rec_count     TYPE i,
        count_known   TYPE abap_bool,
        amount        TYPE zif_cd_ops_types=>ty_amount,
        event_at      TYPE timestampl,
        last_at       TYPE timestampl,
        business_date TYPE d,
        file_name     TYPE zif_cd_fmon_types=>ty_file_name,
        size_bytes    TYPE zif_cd_fmon_types=>ty_size,
        size_known    TYPE abap_bool,
        checksum      TYPE zif_cd_fmon_types=>ty_checksum,
        source_sys    TYPE zif_cd_fmon_types=>ty_system,
        lob           TYPE zif_cd_fmon_types=>ty_lob,
        "! Unprocessed items reported with the stage (PARTIALLY_PROCESSED, FEB adapter)
        unprocessed   TYPE i,
        "! Distinct payment identities of per-payment rows (audit A39)
        items         TYPE string_table,
        "! Generation group key of the file (source with GROUP_FIELDS)
        gen_group     TYPE zif_cd_fmon_types=>ty_file_ref,
      END OF ty_group.
    TYPES tt_group TYPE STANDARD TABLE OF ty_group WITH EMPTY KEY.
    "! Audit A49: the business date is part of the observation identity, so generations of
    "! the same reference on different days are never collapsed into one group
    TYPES tt_group_hash TYPE HASHED TABLE OF ty_group
      WITH UNIQUE KEY src_id iface_id file_ref stage business_date.

    "! Malformed rows per source and field (audit A52): one finding each, never counted
    TYPES:
      BEGIN OF ty_malformed,
        src_id TYPE zif_cd_fmon_types=>ty_src_id,
        role   TYPE zif_cd_fmon_types=>ty_role,
        rows   TYPE i,
      END OF ty_malformed.
    TYPES tt_malformed TYPE HASHED TABLE OF ty_malformed WITH UNIQUE KEY src_id role.

    DATA mo_dao TYPE REF TO zif_cd_fmon_dao.
    DATA mo_store TYPE REF TO zif_cd_ops_store.
    DATA mo_params TYPE REF TO zif_cd_ops_params.
    DATA mo_clock TYPE REF TO zif_cd_ops_clock.
    DATA mo_calendar TYPE REF TO zif_cd_fmon_calendar.

    DATA mv_date TYPE d.
    DATA mv_iface TYPE zif_cd_fmon_types=>ty_iface_id.
    DATA mv_test_mode TYPE abap_bool.
    DATA mv_now TYPE timestampl.
    DATA mv_tz TYPE zif_cd_fmon_types=>ty_time_zone.

    DATA mt_ifaces TYPE zif_cd_fmon_types=>tt_iface.
    DATA mt_slas TYPE zif_cd_fmon_types=>tt_sla.
    DATA mt_cals TYPE zif_cd_fmon_types=>tt_cal.
    DATA mt_srcs TYPE zif_cd_fmon_types=>tt_src.
    DATA mt_maps TYPE zif_cd_fmon_types=>tt_srcmap.
    DATA mt_lotcfgs TYPE zif_cd_fmon_types=>tt_lotcfg.
    DATA mt_checks TYPE zif_cd_fmon_types=>tt_chk.
    DATA mt_deadlines TYPE zif_cd_fmon_types=>tt_deadline.
    "! Statement evidence read by this run (FEB adapter), for the deadline check
    DATA mt_statements TYPE zif_cd_fmon_types=>tt_stmt_evidence.

    DATA mt_files TYPE tt_file_map.
    DATA mt_changed TYPE tt_id_set.
    DATA mt_events TYPE zif_cd_fmon_types=>tt_event.
    DATA mt_new_events TYPE zif_cd_fmon_types=>tt_event.
    "! Recorded events of the instances found by reference (prefetch) - the instance decision
    "! tells a re-read of an event from a new generation of the reference
    DATA mt_ref_events TYPE zif_cd_fmon_types=>tt_event.
    "! Instant unit: other generations of the groups of the event's files (context only, not evaluated)
    DATA mt_generations TYPE zif_cd_fmon_types=>tt_file.
    DATA mt_lots TYPE zif_cd_fmon_types=>tt_lot_status.
    DATA mt_expects TYPE zif_cd_fmon_types=>tt_expect.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.

    "! Sweep: findings of one file reference - number, worst severity rank and the message of
    "! the first finding of that rank (one pass instead of a scan per file)
    TYPES:
      BEGIN OF ty_ref_summary,
        reference   TYPE zif_cd_ops_types=>ty_finding-reference,
        count       TYPE i,
        worst       TYPE i,
        top_message TYPE zif_cd_ops_types=>ty_finding-message,
      END OF ty_ref_summary.
    TYPES tt_ref_summary TYPE HASHED TABLE OF ty_ref_summary WITH UNIQUE KEY reference.

    METHODS findings_by_reference
      RETURNING
        VALUE(rt_summary) TYPE tt_ref_summary.

    METHODS init
      IMPORTING
        iv_business_date TYPE d
        iv_iface_id      TYPE zif_cd_fmon_types=>ty_iface_id
        iv_test_mode     TYPE abap_bool.

    METHODS load_config.

    METHODS sync_sources
      RAISING
        zcx_cd_ops_error.

    METHODS aggregate
      IMPORTING
        is_src           TYPE zif_cd_fmon_types=>ty_src
        it_records       TYPE zif_cd_fmon_types=>tt_src_record
      RETURNING
        VALUE(rt_groups) TYPE tt_group.

    METHODS prefetch
      IMPORTING
        it_groups TYPE tt_group.

    "! File instance of an observation - file generation identity (design review 2026-11-07,
    "! ZCL_CD_FMON_RULES=>FILE_INSTANCE): the instance is fixed by the file's first evidence and
    "! later evidence of the same interface + reference attaches whatever its own date or time;
    "! a new generation, or a reference without instance, opens one (get_or_create) - except a
    "! later stage in single-event mode (blank id: deferred); ambiguous = applied to none
    METHODS resolve_file
      IMPORTING
        is_group      TYPE ty_group
        is_iface      TYPE zif_cd_fmon_types=>ty_iface
      EXPORTING
        ev_file_id    TYPE zif_cd_fmon_types=>ty_file_id
        ev_ambiguous  TYPE abap_bool
      RAISING
        zcx_cd_ops_error.

    METHODS get_or_create
      IMPORTING
        is_group          TYPE ty_group
        is_iface          TYPE zif_cd_fmon_types=>ty_iface
      RETURNING
        VALUE(rv_file_id) TYPE zif_cd_fmon_types=>ty_file_id
      RAISING
        zcx_cd_ops_error.

    "! ACK / NACK counts (audit A39): per-payment rows count distinct payment identities,
    "! file-level rows the reported count; counts are cumulative (never lowered by a later
    "! partial window) and ACK_KNOWN separates an unreported count from a reported zero
    METHODS apply_responses
      IMPORTING
        is_group TYPE ty_group
        is_iface TYPE zif_cd_fmon_types=>ty_iface
      CHANGING
        cs_file  TYPE zif_cd_fmon_types=>ty_file.

    METHODS apply_group
      IMPORTING
        is_group TYPE ty_group
        is_iface TYPE zif_cd_fmon_types=>ty_iface
      CHANGING
        cs_file  TYPE zif_cd_fmon_types=>ty_file.

    METHODS load_registry.

    "! Other generations of the generation groups of the files in memory (regenerated files): the
    "! batch run evaluates them with the files (their exceptions are reconciled), the instant unit
    "! only shows them to the checks
    METHODS load_generations.

    "! Earliest business date of the files under watch (lookback / open-file window)
    METHODS watch_since
      RETURNING
        VALUE(rv_since) TYPE d.

    "! PRISM failures whose error code is in FMON_PRISM_DUP_NAME_CODES (no read for an empty list)
    METHODS prism_failures
      IMPORTING
        iv_codes           TYPE zif_cd_fmon_types=>ty_value_list
      RETURNING
        VALUE(rt_failures) TYPE zif_cd_fmon_types=>tt_prism_failure.

    METHODS derive_lot_outcomes.

    METHODS apply_lot_status
      IMPORTING
        is_status TYPE zif_cd_fmon_types=>ty_lot_status
      CHANGING
        cs_file   TYPE zif_cd_fmon_types=>ty_file.

    METHODS banking_age
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_days) TYPE i.

    METHODS build_expectations.

    METHODS resolve_day_type
      IMPORTING
        iv_calendar_id     TYPE zif_cd_fmon_types=>ty_fcal_id
      RETURNING
        VALUE(rv_day_type) TYPE zif_cd_fmon_types=>ty_day_type.

    METHODS calendar_id_for
      IMPORTING
        iv_iface_id    TYPE zif_cd_fmon_types=>ty_iface_id
      RETURNING
        VALUE(rv_cal) TYPE zif_cd_fmon_types=>ty_fcal_id.

    METHODS build_context
      RETURNING
        VALUE(rs_ctx) TYPE zif_cd_fmon_types=>ty_check_ctx.

    "! PRISM throttle settings from ZCA_PARAM (FMON_PRISM_THROTTLE_* / FMON_PRISM_QUEUE_MAX)
    METHODS throttle_settings
      RETURNING
        VALUE(rs_throttle) TYPE zif_cd_fmon_types=>ty_throttle.

    "! PRISM queues of the business dates of the throttled files in the run. Files and events
    "! in memory are used as they are; a business date the run did not load completely (single
    "! event, one interface, open file of an older date) is read from the registry - other
    "! interfaces' throttled files of the same queue share it (scope C: the same bank; scope A: all)
    METHODS build_queue
      IMPORTING
        is_throttle     TYPE zif_cd_fmon_types=>ty_throttle
      RETURNING
        VALUE(rt_queue) TYPE zif_cd_fmon_types=>tt_queue.

    METHODS run_checks.

    METHODS persist_registry.

    METHODS build_board
      RETURNING
        VALUE(rt_board) TYPE zif_cd_fmon_types=>tt_board.

    METHODS finish
      CHANGING
        cs_run TYPE zif_cd_ops_types=>ty_run
      RAISING
        zcx_cd_ops_error.

    METHODS is_lot_controlled
      IMPORTING
        is_iface             TYPE zif_cd_fmon_types=>ty_iface
      RETURNING
        VALUE(rv_controlled) TYPE abap_bool.

    METHODS engine_finding
      IMPORTING
        iv_code     TYPE zif_cd_ops_types=>ty_check_code
        iv_key      TYPE clike
        iv_message  TYPE clike
        iv_iface_id TYPE zif_cd_fmon_types=>ty_iface_id OPTIONAL
        iv_severity TYPE zif_cd_ops_types=>ty_severity DEFAULT zif_cd_ops_types=>gc_severity-error.


    METHODS mark_changed
      IMPORTING
        iv_file_id TYPE zif_cd_fmon_types=>ty_file_id.

ENDCLASS.



CLASS zcl_cd_fmon_engine IMPLEMENTATION.

  METHOD run.
    DATA lv_holder TYPE syuname.

    IF iv_test_mode = abap_false.
      IF zcl_cd_ops_factory=>get_lock( )->acquire( EXPORTING iv_pe_area  = zif_cd_ops_types=>gc_pe_area-file_monitor
                                                             iv_variant = gc_lock_variant
                                                   IMPORTING ev_holder  = lv_holder ) = abap_false.
        DATA(ls_refusal) = zcl_cd_ops_run_guard=>refuse( iv_pe_area  = zif_cd_ops_types=>gc_pe_area-file_monitor
                                                         iv_variant = gc_lock_variant
                                                         iv_holder  = lv_holder ).
        rs_result-run      = ls_refusal-run.
        rs_result-findings = ls_refusal-findings.
        RETURN.
      ENDIF.
    ENDIF.

    TRY.
        rs_result = execute( iv_business_date = iv_business_date
                             iv_iface_id      = iv_iface_id
                             iv_test_mode     = iv_test_mode ).
      CLEANUP.
        release_lock( iv_test_mode ).
    ENDTRY.
    release_lock( iv_test_mode ).
  ENDMETHOD.


  METHOD run_event.
    DATA lv_date TYPE d.
    LOOP AT it_records ASSIGNING FIELD-SYMBOL(<ls_record>) WHERE business_date IS NOT INITIAL.
      lv_date = nmax( val1 = lv_date val2 = <ls_record>-business_date ).
    ENDLOOP.
    IF lv_date IS INITIAL.
      lv_date = zcl_cd_ops_factory=>get_clock( )->today( ).
    ENDIF.
    mv_single         = abap_true.
    ms_single_src     = is_src.
    mt_single_records = it_records.
    CLEAR mv_deferred.
    rs_result = execute( iv_business_date = lv_date
                         iv_iface_id      = space
                         iv_test_mode     = abap_false ).
    ev_deferred = mv_deferred.
  ENDMETHOD.


  METHOD reconcile_files.
    DATA lt_scope TYPE zif_cd_ops_types=>tt_object_key.

    IF line_exists( mt_findings[ check_code = zif_cd_fmon_types=>gc_check_code-plugin_error ] )
       OR line_exists( mt_findings[ check_code = zif_cd_fmon_types=>gc_check_code-persist_error ] ).
      RETURN.
    ENDIF.
    " Same object key as ZCL_CD_FMON_UTIL=>NEW_FINDING: file name, else file reference
    LOOP AT mt_files INTO DATA(ls_file).
      INSERT CONV zif_cd_ops_types=>ty_object_key( COND string( WHEN ls_file-file_name IS NOT INITIAL
                                                                THEN ls_file-file_name
                                                                ELSE ls_file-file_ref ) ) INTO TABLE lt_scope.
    ENDLOOP.
    " Interface-day findings (expected files, stage deadlines) of the evaluated expectations:
    " same key as ZCL_CD_FMON_CHK_MISSING / _DEADLINE - closed when not raised again
    LOOP AT mt_expects ASSIGNING FIELD-SYMBOL(<ls_expect>).
      INSERT zcl_cd_fmon_util=>iface_day_key( iv_iface_id = <ls_expect>-iface_id
                                              iv_date     = mv_date ) INTO TABLE lt_scope.
    ENDLOOP.
    mo_store->reconcile( is_run         = is_run
                         it_object_keys = lt_scope ).
  ENDMETHOD.


  METHOD release_lock.
    IF iv_test_mode = abap_false.
      zcl_cd_ops_factory=>get_lock( )->release( iv_pe_area  = zif_cd_ops_types=>gc_pe_area-file_monitor
                                                iv_variant = gc_lock_variant ).
    ENDIF.
  ENDMETHOD.


  METHOD execute.
    init( iv_business_date = iv_business_date
          iv_iface_id      = iv_iface_id
          iv_test_mode     = iv_test_mode ).

    DATA(ls_run) = mo_store->start_run(
      iv_pe_area    = zif_cd_ops_types=>gc_pe_area-file_monitor
      iv_variant   = COND #( WHEN mv_single = abap_true THEN gc_event_variant
                             WHEN iv_iface_id IS INITIAL THEN 'ALL' ELSE iv_iface_id )
      iv_test_mode = iv_test_mode ).
    IF mv_test_mode = abap_false.
      " Run header durable first: a later rollback of a failed registry save keeps the run
      mo_store->commit( ).
    ENDIF.

    " Audit A05: a technical SQL error anywhere in the run is handled here, at the owner of
    " the LUW - rolled back, recorded, and the run closed as failed (never left running)
    TRY.
        load_config( ).
        sync_sources( ).
        load_registry( ).
        " Lots and calendar expectations need the whole day: batch run only
        IF mv_single = abap_false.
          derive_lot_outcomes( ).
          build_expectations( ).
        ENDIF.
        run_checks( ).
        IF mv_test_mode = abap_false.
          persist_registry( ).
        ENDIF.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        IF mv_test_mode = abap_false.
          mo_store->rollback( ).
        ENDIF.
        engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-persist_error
                        iv_key     = zif_cd_fmon_types=>gc_engine_key-registry
                        iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-database_error
                                                            iv_tail  = lx_sql->get_text( ) ) ).
    ENDTRY.

    rs_result-board = build_board( ).
    finish( CHANGING cs_run = ls_run ).
    rs_result-run      = ls_run.
    rs_result-findings = mt_findings.
  ENDMETHOD.


  METHOD init.
    mo_dao      = zcl_cd_fmon_factory=>get_dao( ).
    mo_calendar = zcl_cd_fmon_factory=>get_calendar( ).
    mo_store    = zcl_cd_ops_factory=>get_store( ).
    mo_params   = zcl_cd_ops_factory=>get_params( ).
    mo_clock    = zcl_cd_ops_factory=>get_clock( ).

    CLEAR: mt_files, mt_changed, mt_events, mt_new_events, mt_ref_events, mt_lots, mt_expects, mt_findings,
           mt_statements, mt_generations.
    mv_date      = iv_business_date.
    mv_iface     = iv_iface_id.
    mv_test_mode = iv_test_mode.
    mv_now       = mo_clock->now( ).
    mv_tz        = mo_params->get_param( iv_name    = zif_cd_fmon_types=>gc_param-time_zone
                                         iv_default = CONV #( zif_cd_ops_types=>gc_time_zone_utc ) ).
  ENDMETHOD.


  METHOD load_config.
    mt_ifaces  = mo_dao->get_ifaces( ).
    " PCRE name patterns: an invalid one would silently resolve no file - reported instead
    LOOP AT mt_ifaces ASSIGNING FIELD-SYMBOL(<ls_iface>) WHERE active = abap_true AND name_pattern IS NOT INITIAL.
      IF zcl_cd_ops_util=>pcre_valid( <ls_iface>-name_pattern ) = abap_false.
        engine_finding( iv_code     = zif_cd_fmon_types=>gc_check_code-pattern_invalid
                        iv_key      = zif_cd_fmon_types=>gc_engine_key-iface && <ls_iface>-iface_id
                        iv_iface_id = <ls_iface>-iface_id
                        iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-pattern_invalid
                                                             iv_v1    = <ls_iface>-iface_id
                                                             iv_v2    = <ls_iface>-name_pattern ) ).
      ENDIF.
    ENDLOOP.
    mt_slas    = mo_dao->get_slas( ).
    mt_cals    = mo_dao->get_calendars( ).
    mt_srcs    = mo_dao->get_sources( ).
    mt_maps    = mo_dao->get_source_maps( ).
    mt_lotcfgs = mo_dao->get_lot_configs( ).
    mt_checks  = mo_dao->get_checks( ).
    mt_deadlines = mo_dao->get_deadlines( ).
  ENDMETHOD.


  METHOD sync_sources.
    DATA ls_request TYPE zif_cd_fmon_types=>ty_read_request.
    DATA lt_records TYPE zif_cd_fmon_types=>tt_src_record.
    DATA lt_groups TYPE tt_group.

    ls_request-date_from = mv_date - zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                                 iv_name    = zif_cd_fmon_types=>gc_param-lookback_days
                                                                 iv_default = zif_cd_fmon_types=>gc_param_default-lookback_days ).
    ls_request-date_to   = mv_date.
    ls_request-time_zone = mv_tz.
    ls_request-max_rows  = zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                       iv_name    = zif_cd_fmon_types=>gc_param-max_rows
                                                       iv_default = zif_cd_fmon_types=>gc_param_default-max_rows ).

    IF mv_single = abap_true.
      lt_groups = aggregate( is_src     = ms_single_src
                             it_records = mt_single_records ).
    ENDIF.
    LOOP AT mt_srcs INTO DATA(ls_src).
      " Single-event mode: the event's records are the only input
      IF mv_single = abap_true.
        EXIT.
      ENDIF.
      IF mv_iface IS NOT INITIAL AND ls_src-iface_id IS NOT INITIAL AND ls_src-iface_id <> mv_iface.
        CONTINUE.
      ENDIF.
      ls_request-src  = ls_src.
      ls_request-maps = VALUE #( FOR ls_map IN mt_maps WHERE ( src_id = ls_src-src_id ) ( ls_map ) ).
      TRY.
          lt_records = zcl_cd_fmon_factory=>get_adapter( ls_src-adapter_class )->read( ls_request ).
        CATCH zcx_cd_ops_error INTO DATA(lx_ops).
          engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                          iv_key     = zif_cd_fmon_types=>gc_engine_key-source && ls_src-src_id
                          iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-source
                                                              iv_v1    = ls_src-src_id
                                                              iv_v2    = ls_src-table_name
                                                              iv_tail  = lx_ops->get_text( ) ) ).
          CONTINUE.
        CATCH cx_root INTO DATA(lx_root).
          engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                          iv_key     = zif_cd_fmon_types=>gc_engine_key-source && ls_src-src_id
                          iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-source
                                                              iv_v1    = ls_src-src_id
                                                              iv_v2    = ls_src-table_name
                                                              iv_tail  = lx_root->get_text( ) ) ).
          CONTINUE.
      ENDTRY.

      " Statement evidence (FEB adapter) is kept for the checks; an evidence-only record has no stage
      LOOP AT lt_records ASSIGNING FIELD-SYMBOL(<ls_evidence>) WHERE evidence-iface_id IS NOT INITIAL.
        DELETE mt_statements WHERE iface_id      = <ls_evidence>-evidence-iface_id
                               AND business_date = <ls_evidence>-evidence-business_date.
        INSERT <ls_evidence>-evidence INTO TABLE mt_statements.
      ENDLOOP.
      DELETE lt_records WHERE evidence_only = abap_true.
      DATA(lt_src_groups) = aggregate( is_src     = ls_src
                                       it_records = lt_records ).
      INSERT LINES OF lt_src_groups INTO TABLE lt_groups.
    ENDLOOP.

    " Apply all sources in event-time order: terminal outcomes are final, so a
    " later status must never be applied before an earlier one of another source
    prefetch( lt_groups ).
    SORT lt_groups BY event_at src_id.
    LOOP AT lt_groups INTO DATA(ls_group).
      DATA(ls_iface) = VALUE #( mt_ifaces[ iface_id = ls_group-iface_id ] OPTIONAL ).
      resolve_file( EXPORTING is_group     = ls_group
                              is_iface     = ls_iface
                    IMPORTING ev_file_id   = DATA(lv_file_id)
                              ev_ambiguous = DATA(lv_ambiguous) ).
      IF lv_ambiguous = abap_true.
        engine_finding( iv_code     = zif_cd_fmon_types=>gc_check_code-ref_ambiguous
                        iv_key      = |{ ls_group-src_id }:{ ls_group-file_ref }|
                        iv_iface_id = ls_group-iface_id
                        iv_severity = zif_cd_ops_types=>gc_severity-warning
                        iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-reference_ambiguous
                                                             iv_v1    = ls_group-file_ref
                                                             iv_v2    = ls_group-iface_id ) ).
        CONTINUE.
      ENDIF.
      IF lv_file_id IS INITIAL.
        " Single-event mode: no known file for a later stage - left to the 5-minute run
        mv_deferred = abap_true.
        CONTINUE.
      ENDIF.
      DATA(ls_file) = VALUE #( mt_files[ file_id = lv_file_id ] OPTIONAL ).
      apply_group( EXPORTING is_group = ls_group
                             is_iface = ls_iface
                   CHANGING  cs_file  = ls_file ).
      MODIFY TABLE mt_files FROM ls_file.
      mark_changed( lv_file_id ).
    ENDLOOP.
  ENDMETHOD.


  METHOD aggregate.
    DATA lt_hash TYPE tt_group_hash.
    DATA lt_malformed TYPE tt_malformed.
    FIELD-SYMBOLS <ls_group> TYPE ty_group.
    FIELD-SYMBOLS <ls_bad> TYPE ty_malformed.

    LOOP AT it_records INTO DATA(ls_record).
      IF ls_record-malformed = abap_true.
        " Audit A52: quarantined - counted for one finding per field, never applied
        READ TABLE lt_malformed ASSIGNING <ls_bad>
          WITH TABLE KEY src_id = is_src-src_id role = ls_record-malformed_role.
        IF sy-subrc <> 0.
          INSERT VALUE #( src_id = is_src-src_id role = ls_record-malformed_role )
            INTO TABLE lt_malformed ASSIGNING <ls_bad>.
        ENDIF.
        <ls_bad>-rows += 1.
        CONTINUE.
      ENDIF.
      DATA(ls_iface) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = mt_ifaces
                                                        iv_iface_id  = ls_record-iface_id
                                                        iv_file_name = ls_record-file_name
                                                        iv_source    = ls_record-source_sys
                                                        iv_lob       = ls_record-lob ).
      IF ls_iface IS INITIAL.
        engine_finding( iv_code     = zif_cd_fmon_types=>gc_check_code-unmapped_file
                        iv_key      = |{ is_src-src_id }:{ ls_record-file_ref }|
                        iv_severity = zif_cd_ops_types=>gc_severity-warning
                        iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-source_no_interface_matches
                                                             iv_v1    = is_src-src_id
                                                             iv_v2    = ls_record-file_name ) ).
        CONTINUE.
      ENDIF.
      IF mv_iface IS NOT INITIAL AND ls_iface-iface_id <> mv_iface.
        CONTINUE.
      ENDIF.
      " PRISM_* stages fit both directions (PRISM status API)
      IF ls_record-stage IS INITIAL
         OR zcl_cd_fmon_status=>fits_direction( iv_stage     = ls_record-stage
                                                iv_direction = ls_iface-direction ) = abap_false.
        engine_finding( iv_code     = zif_cd_fmon_types=>gc_check_code-unmapped_status
                        iv_key      = |{ is_src-src_id }:{ ls_record-raw_status }|
                        iv_iface_id = ls_iface-iface_id
                        iv_severity = zif_cd_ops_types=>gc_severity-warning
                        iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-source_status_has_no_stage
                                                             iv_v1    = is_src-src_id
                                                             iv_v2    = ls_record-raw_status
                                                             iv_v3    = ls_iface-direction ) ).
        CONTINUE.
      ENDIF.

      READ TABLE lt_hash ASSIGNING <ls_group>
        WITH TABLE KEY src_id        = is_src-src_id
                       iface_id      = ls_iface-iface_id
                       file_ref      = ls_record-file_ref
                       stage         = ls_record-stage
                       business_date = ls_record-business_date.
      IF sy-subrc <> 0.
        INSERT VALUE #( src_id        = is_src-src_id
                        iface_id      = ls_iface-iface_id
                        file_ref      = ls_record-file_ref
                        stage         = ls_record-stage
                        raw_status    = ls_record-raw_status
                        event_at      = ls_record-event_at
                        last_at       = ls_record-event_at
                        business_date = ls_record-business_date ) INTO TABLE lt_hash ASSIGNING <ls_group>.
      ENDIF.
      <ls_group>-rows += 1.
      <ls_group>-amount += ls_record-amount.
      <ls_group>-unprocessed += ls_record-unprocessed.
      IF ls_record-item_key IS NOT INITIAL
         AND NOT line_exists( <ls_group>-items[ table_line = ls_record-item_key ] ).
        INSERT CONV string( ls_record-item_key ) INTO TABLE <ls_group>-items.
      ENDIF.
      IF ls_record-count_known = abap_true.
        <ls_group>-rec_count += ls_record-rec_count.
        <ls_group>-count_known = abap_true.
      ENDIF.
      IF ls_record-event_at IS NOT INITIAL AND ls_record-event_at < <ls_group>-event_at.
        <ls_group>-event_at = ls_record-event_at.
      ENDIF.
      IF ls_record-event_at > <ls_group>-last_at.
        <ls_group>-last_at = ls_record-event_at.
      ENDIF.
      IF ls_record-business_date IS NOT INITIAL
         AND ( <ls_group>-business_date IS INITIAL OR ls_record-business_date < <ls_group>-business_date ).
        <ls_group>-business_date = ls_record-business_date.
      ENDIF.
      IF <ls_group>-file_name IS INITIAL.
        <ls_group>-file_name = ls_record-file_name.
      ENDIF.
      IF ls_record-size_known = abap_true.
        <ls_group>-size_bytes = ls_record-size_bytes.
        <ls_group>-size_known = abap_true.
      ENDIF.
      IF ls_record-checksum IS NOT INITIAL.
        <ls_group>-checksum = ls_record-checksum.
      ENDIF.
      IF <ls_group>-source_sys IS INITIAL.
        <ls_group>-source_sys = ls_record-source_sys.
      ENDIF.
      IF <ls_group>-lob IS INITIAL.
        <ls_group>-lob = ls_record-lob.
      ENDIF.
      IF <ls_group>-gen_group IS INITIAL.
        <ls_group>-gen_group = ls_record-gen_group.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_malformed ASSIGNING FIELD-SYMBOL(<ls_malformed>).
      engine_finding( iv_code     = zif_cd_fmon_types=>gc_check_code-malformed_row
                      iv_key      = |{ <ls_malformed>-src_id }:{ <ls_malformed>-role }|
                      iv_severity = zif_cd_ops_types=>gc_severity-warning
                      iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-malformed_rows
                                                           iv_v1    = <ls_malformed>-src_id
                                                           iv_v2    = <ls_malformed>-rows
                                                           iv_v3    = <ls_malformed>-role ) ).
    ENDLOOP.

    rt_groups = VALUE #( FOR ls_hash IN lt_hash ( ls_hash ) ).
  ENDMETHOD.


  METHOD prefetch.
    DATA lt_keys TYPE zif_cd_fmon_types=>tt_file_key.
    LOOP AT it_groups ASSIGNING FIELD-SYMBOL(<ls_group>).
      IF line_exists( mt_files[ KEY ref COMPONENTS iface_id = <ls_group>-iface_id file_ref = <ls_group>-file_ref ] )
         OR line_exists( lt_keys[ iface_id = <ls_group>-iface_id file_ref = <ls_group>-file_ref ] ).
        CONTINUE.
      ENDIF.
      INSERT VALUE #( iface_id = <ls_group>-iface_id file_ref = <ls_group>-file_ref ) INTO TABLE lt_keys.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.
    " Instances of earlier days are needed only inside the evaluation / open-file window
    DATA(lt_found) = mo_dao->find_files_by_ref( it_keys  = lt_keys
                                                iv_since = watch_since( ) ).
    LOOP AT lt_found ASSIGNING FIELD-SYMBOL(<ls_file>).
      INSERT <ls_file> INTO TABLE mt_files.
    ENDLOOP.
    IF lt_found IS NOT INITIAL.
      mt_ref_events = mo_dao->get_events( VALUE #( FOR ls_found IN lt_found ( ls_found-file_id ) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD get_or_create.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.

    TRY.
        ls_file-file_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e211(zcd_ops)
          EXPORTING
            previous = lx_uuid.
    ENDTRY.
    ls_file-iface_id      = is_group-iface_id.
    ls_file-file_ref      = is_group-file_ref.
    ls_file-direction     = is_iface-direction.
    ls_file-file_type     = is_iface-file_type.
    ls_file-pay_method    = is_iface-pay_method.
    ls_file-source_sys    = COND #( WHEN is_group-source_sys IS NOT INITIAL THEN is_group-source_sys
                                    WHEN is_iface-source_sys <> zif_cd_fmon_types=>gc_wildcard THEN is_iface-source_sys ).
    ls_file-lob           = COND #( WHEN is_group-lob IS NOT INITIAL THEN is_group-lob
                                    WHEN is_iface-lob <> zif_cd_fmon_types=>gc_wildcard THEN is_iface-lob ).
    ls_file-business_date = COND #( WHEN is_group-business_date IS NOT INITIAL THEN is_group-business_date
                                    ELSE mv_date ).
    ls_file-file_name     = is_group-file_name.
    ls_file-src_id        = is_group-src_id.
    ls_file-src_key       = is_group-file_ref.
    ls_file-created_at    = mv_now.
    INSERT ls_file INTO TABLE mt_files.
    rv_file_id = ls_file-file_id.
  ENDMETHOD.


  METHOD resolve_file.
    DATA lt_candidates TYPE zif_cd_fmon_types=>tt_file.
    DATA lt_events TYPE zif_cd_fmon_types=>tt_event.

    CLEAR: ev_file_id, ev_ambiguous.
    LOOP AT mt_files ASSIGNING FIELD-SYMBOL(<ls_file>) USING KEY ref
         WHERE iface_id = is_group-iface_id AND file_ref = is_group-file_ref.
      " Audit A100: a digest reference matches only the file with the same full name
      IF zcl_cd_fmon_util=>is_digest_ref( is_group-file_ref ) = abap_true
         AND is_group-file_name IS NOT INITIAL AND <ls_file>-file_name IS NOT INITIAL
         AND zcl_cd_fmon_util=>canonical_name( is_group-file_name )
             <> zcl_cd_fmon_util=>canonical_name( <ls_file>-file_name ).
        ev_ambiguous = abap_true.
        RETURN.
      ENDIF.
      INSERT <ls_file> INTO TABLE lt_candidates.
      " Recorded (prefetched) and applied in this run: a re-read is told from a new generation
      LOOP AT mt_ref_events ASSIGNING FIELD-SYMBOL(<ls_recorded>) USING KEY by_file WHERE file_id = <ls_file>-file_id.
        INSERT <ls_recorded> INTO TABLE lt_events.
      ENDLOOP.
      LOOP AT mt_new_events ASSIGNING FIELD-SYMBOL(<ls_applied>) USING KEY by_file WHERE file_id = <ls_file>-file_id.
        INSERT <ls_applied> INTO TABLE lt_events.
      ENDLOOP.
    ENDLOOP.

    DATA(ls_pick) = zcl_cd_fmon_rules=>file_instance(
                      is_obs        = VALUE #( src_id        = is_group-src_id
                                               file_ref      = is_group-file_ref
                                               stage         = is_group-stage
                                               direction     = is_iface-direction
                                               business_date = is_group-business_date
                                               run_date      = mv_date
                                               event_at      = is_group-event_at )
                      it_candidates = lt_candidates
                      it_events     = lt_events ).
    IF ls_pick-ambiguous = abap_true.
      ev_ambiguous = abap_true.
      RETURN.
    ENDIF.
    IF ls_pick-file_id IS NOT INITIAL.
      ev_file_id = ls_pick-file_id.
      RETURN.
    ENDIF.
    IF mv_single = abap_true
       AND zcl_cd_fmon_status=>is_origin( iv_stage = is_group-stage iv_direction = is_iface-direction ) = abap_false.
      " A later stage of a file FMON does not know yet (e.g. PRISM faster than the generation
      " read): never opened by one event alone - blank ID, the 5-minute run correlates it
      RETURN.
    ENDIF.
    ev_file_id = get_or_create( is_group = is_group
                                is_iface = is_iface ).
  ENDMETHOD.


  METHOD apply_responses.
    DATA(lv_payment) = xsdbool( is_iface-ack_level = zif_cd_fmon_types=>gc_ack_level-payment ).
    " Per-payment rows: distinct payment identities, else rows; file level: reported count
    DATA(lv_count) = COND i( WHEN lv_payment = abap_true AND is_group-items IS NOT INITIAL THEN lines( is_group-items )
                             WHEN lv_payment = abap_true THEN is_group-rows
                             ELSE is_group-rec_count ).
    DATA(lv_known) = xsdbool( lv_payment = abap_true OR is_group-count_known = abap_true ).
    CASE is_group-stage.
      WHEN zif_cd_fmon_types=>gc_stage-ack.
        IF lv_known = abap_true.
          cs_file-ack_count = nmax( val1 = cs_file-ack_count val2 = lv_count ).
          cs_file-ack_known = abap_true.
        ENDIF.
        IF is_group-amount > cs_file-ack_amount.
          cs_file-ack_amount = is_group-amount.
        ENDIF.
      WHEN zif_cd_fmon_types=>gc_stage-nack.
        IF lv_known = abap_true.
          cs_file-nack_count = nmax( val1 = cs_file-nack_count val2 = lv_count ).
          cs_file-ack_known  = abap_true.
        ELSE.
          " A rejection without a count is at least one rejected record
          cs_file-nack_count = nmax( val1 = cs_file-nack_count val2 = 1 ).
        ENDIF.
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD apply_group.
    DATA(lv_origin) = zcl_cd_fmon_status=>is_origin( iv_stage     = is_group-stage
                                                     iv_direction = is_iface-direction ).
    IF lv_origin = abap_true.
      " First stage (generated / received) carries the file's own attributes
      IF is_group-file_name IS NOT INITIAL.
        cs_file-file_name = is_group-file_name.
      ENDIF.
      IF is_group-count_known = abap_true.
        cs_file-record_count = is_group-rec_count.
      ENDIF.
      IF is_group-amount <> 0.
        cs_file-control_total = is_group-amount.
      ENDIF.
      IF is_group-checksum IS NOT INITIAL.
        cs_file-checksum = is_group-checksum.
      ENDIF.
      cs_file-origin_rows = nmax( val1 = cs_file-origin_rows val2 = is_group-rows ).
    ELSEIF cs_file-file_name IS INITIAL.
      cs_file-file_name = is_group-file_name.
    ENDIF.

    IF is_group-size_known = abap_true
       AND ( cs_file-size_known = abap_false OR lv_origin = abap_true ).
      cs_file-size_bytes = is_group-size_bytes.
      cs_file-size_known = abap_true.
    ENDIF.

    " Disbursements are acknowledged per payment (one row each), collections per file
    apply_responses( EXPORTING is_group = is_group
                               is_iface = is_iface
                     CHANGING  cs_file  = cs_file ).

    IF cs_file-first_event_at IS INITIAL OR is_group-event_at < cs_file-first_event_at.
      cs_file-first_event_at = is_group-event_at.
    ENDIF.
    IF is_group-last_at > cs_file-last_event_at.
      cs_file-last_event_at = is_group-last_at.
    ENDIF.
    IF cs_file-source_sys IS INITIAL.
      cs_file-source_sys = is_group-source_sys.
    ENDIF.
    IF cs_file-lob IS INITIAL.
      cs_file-lob = is_group-lob.
    ENDIF.
    " Regenerated files: the generation group is the only link to the other generations (set once)
    IF cs_file-gen_group IS INITIAL.
      cs_file-gen_group = is_group-gen_group.
    ENDIF.

    " Audit A40: the event records the stage as applied - for lot-controlled interfaces a
    " source FULLY / PARTIALLY is FILE_LOADED, the lot decides the outcome (raw status in INFO)
    DATA(lv_stage) = zcl_cd_fmon_rules=>cap_stage( iv_stage          = is_group-stage
                                                   iv_lot_controlled = is_lot_controlled( is_iface ) ).
    INSERT VALUE #( file_id      = cs_file-file_id
                    stage        = lv_stage
                    event_at     = is_group-event_at
                    src_id       = is_group-src_id
                    src_key      = is_group-file_ref
                    record_count = COND #( WHEN is_group-count_known = abap_true THEN is_group-rec_count
                                           ELSE is_group-rows )
                    amount       = is_group-amount
                    info         = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-event_info
                                                         iv_v1    = is_group-rows
                                                         iv_v2    = is_group-raw_status )
                    created_by   = sy-uname
                    created_at   = mv_now ) INTO TABLE mt_new_events.

    " For lot-controlled interfaces the lot, not the source, decides the outcome
    zcl_cd_fmon_status=>apply(
      EXPORTING
        iv_stage       = lv_stage
        iv_unprocessed = is_group-unprocessed
      CHANGING
        cs_file        = cs_file ).
  ENDMETHOD.


  METHOD load_registry.
    DATA lv_from TYPE d.
    DATA lv_open_since TYPE d.
    lv_from       = mv_date - zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                          iv_name    = zif_cd_fmon_types=>gc_param-lookback_days
                                                          iv_default = zif_cd_fmon_types=>gc_param_default-lookback_days ).
    lv_open_since = mv_date - zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                          iv_name    = zif_cd_fmon_types=>gc_param-open_days
                                                          iv_default = zif_cd_fmon_types=>gc_param_default-open_days ).
    DATA lt_db TYPE zif_cd_fmon_types=>tt_file.
    " Single-event mode: only the files of the event (prefetched by reference)
    IF mv_single = abap_false.
      lt_db = mo_dao->get_eval_files( iv_date_from  = lv_from
                                      iv_date_to    = mv_date
                                      iv_open_since = lv_open_since
                                      iv_iface_id   = mv_iface ).
    ENDIF.
    LOOP AT lt_db ASSIGNING FIELD-SYMBOL(<ls_db>).
      IF NOT line_exists( mt_files[ file_id = <ls_db>-file_id ] ).
        INSERT <ls_db> INTO TABLE mt_files.
      ENDIF.
    ENDLOOP.
    load_generations( ).

    IF mt_files IS NOT INITIAL.
      mt_events = mo_dao->get_events( VALUE #( FOR ls_file IN mt_files ( ls_file-file_id ) ) ).
    ENDIF.
    LOOP AT mt_new_events INTO DATA(ls_event).
      IF NOT line_exists( mt_events[ KEY by_file
                                     file_id = ls_event-file_id
                                     src_id  = ls_event-src_id
                                     src_key = ls_event-src_key
                                     stage   = ls_event-stage ] ).
        INSERT ls_event INTO TABLE mt_events.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_generations.
    DATA lt_keys TYPE zif_cd_fmon_types=>tt_group_key.
    LOOP AT mt_files ASSIGNING FIELD-SYMBOL(<ls_file>) WHERE gen_group IS NOT INITIAL.
      IF NOT line_exists( lt_keys[ iface_id = <ls_file>-iface_id gen_group = <ls_file>-gen_group ] ).
        INSERT VALUE #( iface_id = <ls_file>-iface_id gen_group = <ls_file>-gen_group ) INTO TABLE lt_keys.
      ENDIF.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      " No source has GROUP_FIELDS (or no grouped file in the run): no read, behaviour as before
      RETURN.
    ENDIF.
    LOOP AT mo_dao->get_group_files( it_keys  = lt_keys
                                     iv_since = watch_since( ) ) ASSIGNING FIELD-SYMBOL(<ls_peer>).
      IF line_exists( mt_files[ file_id = <ls_peer>-file_id ] ).
        CONTINUE.
      ENDIF.
      IF mv_single = abap_true.
        INSERT <ls_peer> INTO TABLE mt_generations.
      ELSE.
        INSERT <ls_peer> INTO TABLE mt_files.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD watch_since.
    rv_since = mv_date - nmax( val1 = zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                                  iv_name    = zif_cd_fmon_types=>gc_param-lookback_days
                                                                  iv_default = zif_cd_fmon_types=>gc_param_default-lookback_days )
                               val2 = zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                                  iv_name    = zif_cd_fmon_types=>gc_param-open_days
                                                                  iv_default = zif_cd_fmon_types=>gc_param_default-open_days ) ).
  ENDMETHOD.


  METHOD prism_failures.
    DATA lt_codes TYPE zif_cd_fmon_prism_types=>tt_error_code.
    LOOP AT zcl_cd_ops_util=>split_list( iv_codes ) ASSIGNING FIELD-SYMBOL(<lv_code>).
      INSERT CONV #( to_upper( <lv_code> ) ) INTO TABLE lt_codes.
    ENDLOOP.
    IF lt_codes IS INITIAL.
      " FMON_PRISM_DUP_NAME_CODES blank (delivered default, codes to be confirmed with PRISM): no read
      RETURN.
    ENDIF.
    LOOP AT zcl_cd_fmon_factory=>get_prism_dao( )->read_failures( it_codes = lt_codes
                                                                  iv_since = watch_since( ) )
         ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( file_ref    = zcl_cd_fmon_util=>normalize_ref( <ls_row>-file_ref )
                      error_code  = <ls_row>-error_code
                      occurred_at = <ls_row>-occurred_at ) INTO TABLE rt_failures.
    ENDLOOP.
  ENDMETHOD.


  METHOD derive_lot_outcomes.
    DATA lt_batch TYPE zif_cd_fmon_types=>tt_file.
    DATA lt_status TYPE zif_cd_fmon_types=>tt_lot_status.

    DATA(lv_default_sla) = zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                       iv_name    = zif_cd_fmon_types=>gc_param-noc_sla_days
                                                       iv_default = zif_cd_fmon_types=>gc_param_default-noc_sla_days ).
    DATA(lv_max_rows) = zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                    iv_name    = zif_cd_fmon_types=>gc_param-max_rows
                                                    iv_default = zif_cd_fmon_types=>gc_param_default-max_rows ).

    LOOP AT mt_lotcfgs INTO DATA(ls_cfg) WHERE active = abap_true.
      CLEAR lt_batch.
      LOOP AT mt_files INTO DATA(ls_file)
           WHERE direction = zif_cd_fmon_types=>gc_direction-inbound
             AND file_type = ls_cfg-lot_type
             AND outcome  <> zif_cd_fmon_types=>gc_stage-fully.
        IF zcl_cd_fmon_rules=>lot_cfg_for( it_cfgs     = mt_lotcfgs
                                           iv_iface_id = ls_file-iface_id
                                           iv_lot_type = ls_cfg-lot_type ) = ls_cfg.
          INSERT ls_file INTO TABLE lt_batch.
        ENDIF.
      ENDLOOP.
      IF lt_batch IS INITIAL.
        CONTINUE.
      ENDIF.

      TRY.
          lt_status = zcl_cd_fmon_factory=>get_lot_reader( )->read( is_cfg      = ls_cfg
                                                                    it_files    = lt_batch
                                                                    iv_max_rows = lv_max_rows ).
        CATCH cx_root INTO DATA(lx_root).
          engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                          iv_key     = zif_cd_fmon_types=>gc_engine_key-lot && |{ ls_cfg-iface_id }:{ ls_cfg-lot_type }|
                          iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-lot_reader
                                                              iv_v1    = ls_cfg-lot_type
                                                              iv_v2    = ls_cfg-item_table
                                                              iv_tail  = lx_root->get_text( ) ) ).
          CONTINUE.
      ENDTRY.

      IF line_exists( lt_status[ truncated = abap_true ] ).
        engine_finding( iv_code     = zif_cd_fmon_types=>gc_check_code-lot_truncated
                        iv_key      = zif_cd_fmon_types=>gc_engine_key-lot && |{ ls_cfg-iface_id }:{ ls_cfg-lot_type }|
                        iv_severity = zif_cd_ops_types=>gc_severity-warning
                        iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-lot_scan_truncated
                                                             iv_v1    = ls_cfg-lot_type
                                                             iv_v2    = lv_max_rows ) ).
      ENDIF.
      LOOP AT lt_status INTO DATA(ls_status).
        READ TABLE mt_files INTO ls_file WITH TABLE KEY file_id = ls_status-file_id.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        IF ls_status-sla_days <= 0.
          ls_status-sla_days = lv_default_sla.
        ENDIF.
        ls_status-age_days = banking_age( ls_file ).
        apply_lot_status( EXPORTING is_status = ls_status
                          CHANGING  cs_file   = ls_file ).
        INSERT ls_status INTO TABLE mt_lots.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD apply_lot_status.
    DATA(lv_target) = zcl_cd_fmon_rules=>lot_outcome( is_status ).
    IF lv_target IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_result) = zcl_cd_fmon_status=>apply( EXPORTING iv_stage       = lv_target
                                                           iv_unprocessed = is_status-open_items
                                                 CHANGING  cs_file        = cs_file ).
    IF lv_result <> zif_cd_fmon_types=>gc_transition-advanced
       AND lv_result <> zif_cd_fmon_types=>gc_transition-updated.
      RETURN.
    ENDIF.

    IF lv_result = zif_cd_fmon_types=>gc_transition-advanced.
      cs_file-last_event_at = mv_now.
      DATA(ls_event) = VALUE zif_cd_fmon_types=>ty_event(
        file_id      = cs_file-file_id
        stage        = lv_target
        event_at     = mv_now
        src_id       = zif_cd_fmon_types=>gc_lot_src_id
        src_key      = zcl_cd_fmon_util=>file_hex( cs_file-file_id )
        record_count = is_status-total_items
        info         = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-lot_items_open
                                             iv_v1    = is_status-open_items
                                             iv_v2    = is_status-total_items
                                             iv_v3    = is_status-lot_type )
        created_by   = sy-uname
        created_at   = mv_now ).
      INSERT ls_event INTO TABLE mt_new_events.
      INSERT ls_event INTO TABLE mt_events.
    ENDIF.
    MODIFY TABLE mt_files FROM cs_file.
    mark_changed( cs_file-file_id ).
  ENDMETHOD.


  METHOD banking_age.
    DATA(lv_cal) = calendar_id_for( is_file-iface_id ).
    TRY.
        rv_days = mo_calendar->working_days_between(
                    iv_from        = is_file-business_date
                    iv_to          = mv_date
                    iv_calendar_id = lv_cal
                    iv_basis       = CONV #( mo_params->get_param(
                                               iv_name    = zif_cd_fmon_types=>gc_param-age_basis
                                               iv_default = CONV #( zif_cd_fmon_types=>gc_age_basis-after_receipt ) ) ) ).
      CATCH zcx_cd_ops_error INTO DATA(lx_cal).
        engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                        iv_key     = zif_cd_fmon_types=>gc_engine_key-calendar && lv_cal
                        iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-factory_calendar_age_unknwn
                                                            iv_v1    = lv_cal
                                                            iv_tail  = lx_cal->get_text( ) ) ).
        " Audit A41: no silent fallback to calendar days - the age is unknown, no verdict
        rv_days = zif_cd_fmon_types=>gc_age_unknown.
    ENDTRY.
  ENDMETHOD.


  METHOD build_expectations.
    DATA ls_expect TYPE zif_cd_fmon_types=>ty_expect.

    LOOP AT mt_ifaces INTO DATA(ls_iface).
      IF ( mv_iface IS NOT INITIAL AND ls_iface-iface_id <> mv_iface )
         OR NOT line_exists( mt_cals[ iface_id = ls_iface-iface_id ] ).
        CONTINUE.
      ENDIF.
      CLEAR ls_expect.
      ls_expect-iface_id = ls_iface-iface_id.
      ls_expect-fcal_id  = calendar_id_for( ls_iface-iface_id ).
      ls_expect-day_type = resolve_day_type( ls_expect-fcal_id ).
      DATA(ls_cal) = zcl_cd_fmon_rules=>pick_calendar_row( it_cals     = mt_cals
                                                          iv_iface_id = ls_iface-iface_id
                                                          iv_day_type = ls_expect-day_type ).
      " A holiday without its own row expects nothing (files that day are unexpected)
      IF ls_cal IS INITIAL AND ls_expect-day_type <> zif_cd_fmon_types=>gc_day_type-holiday.
        CONTINUE.
      ENDIF.
      ls_expect-expected_count = ls_cal-expected_count.
      IF ls_cal IS NOT INITIAL.
        CONVERT DATE mv_date TIME ls_cal-window_from
          INTO TIME STAMP ls_expect-ts_from TIME ZONE mv_tz.
        DATA(lv_to_time) = COND t( WHEN ls_cal-window_to IS INITIAL THEN '235959' ELSE ls_cal-window_to ).
        DATA(lv_to_date) = COND d( WHEN ls_cal-window_to IS NOT INITIAL AND ls_cal-window_to < ls_cal-window_from
                                   THEN mv_date + 1 ELSE mv_date ).
        CONVERT DATE lv_to_date TIME lv_to_time
          INTO TIME STAMP ls_expect-ts_to TIME ZONE mv_tz.
      ENDIF.
      INSERT ls_expect INTO TABLE mt_expects.
    ENDLOOP.
  ENDMETHOD.


  METHOD resolve_day_type.
    TRY.
        DATA(lv_working) = mo_calendar->is_working_day( iv_date        = mv_date
                                                        iv_calendar_id = iv_calendar_id ).
        DATA(lv_month_end) = abap_false.
        IF lv_working = abap_true.
          lv_month_end = mo_calendar->is_month_end( iv_date        = mv_date
                                                    iv_calendar_id = iv_calendar_id ).
        ENDIF.
        rv_day_type = zcl_cd_fmon_rules=>day_type(
                        iv_working_day  = lv_working
                        iv_month_end    = lv_month_end
                        iv_date         = mv_date
                        iv_returns_days = mo_params->get_param( zif_cd_fmon_types=>gc_param-returns_days ) ).
      CATCH zcx_cd_ops_error INTO DATA(lx_cal).
        engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                        iv_key     = zif_cd_fmon_types=>gc_engine_key-calendar && iv_calendar_id
                        iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-factory_calendar_normal_day
                                                            iv_v1    = iv_calendar_id
                                                            iv_tail  = lx_cal->get_text( ) ) ).
        rv_day_type = zif_cd_fmon_types=>gc_day_type-normal.
    ENDTRY.
  ENDMETHOD.


  METHOD calendar_id_for.
    LOOP AT mt_cals ASSIGNING FIELD-SYMBOL(<ls_cal>) WHERE iface_id = iv_iface_id AND fcal_id IS NOT INITIAL.
      rv_cal = <ls_cal>-fcal_id.
      RETURN.
    ENDLOOP.
    rv_cal = mo_params->get_param( iv_name    = zif_cd_fmon_types=>gc_param-factory_cal
                                   iv_default = zif_cd_fmon_types=>gc_param_default-factory_cal ).
  ENDMETHOD.


  METHOD build_context.
    DATA lt_names TYPE zif_cd_fmon_types=>tt_file_name.
    DATA lt_checksums TYPE zif_cd_fmon_types=>tt_checksum.

    rs_ctx-business_date = mv_date.
    rs_ctx-now           = mv_now.
    rs_ctx-files         = VALUE #( FOR ls_file IN mt_files ( ls_file ) ).
    rs_ctx-events        = mt_events.
    rs_ctx-ifaces        = mt_ifaces.
    rs_ctx-slas          = mt_slas.
    rs_ctx-expects       = mt_expects.
    rs_ctx-lots          = mt_lots.
    rs_ctx-throttle      = throttle_settings( ).
    rs_ctx-queue         = build_queue( rs_ctx-throttle ).
    rs_ctx-deadlines     = mt_deadlines.
    rs_ctx-time_zone     = mv_tz.
    rs_ctx-statements    = mt_statements.
    " Regenerated files: every known generation of the groups, settings and PRISM duplicate names
    LOOP AT mt_files ASSIGNING FIELD-SYMBOL(<ls_grouped>) WHERE gen_group IS NOT INITIAL.
      INSERT <ls_grouped> INTO TABLE rs_ctx-generations.
    ENDLOOP.
    INSERT LINES OF mt_generations INTO TABLE rs_ctx-generations.
    rs_ctx-regen-wait_min  = zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                         iv_name    = zif_cd_fmon_types=>gc_param-regen_wait_min
                                                         iv_default = zif_cd_fmon_types=>gc_param_default-regen_wait_min ).
    rs_ctx-regen-dup_codes = mo_params->get_param( zif_cd_fmon_types=>gc_param-dup_name_codes ).
    rs_ctx-prism_failures  = prism_failures( rs_ctx-regen-dup_codes ).

    LOOP AT mt_files ASSIGNING FIELD-SYMBOL(<ls_named>).
      IF <ls_named>-file_name IS NOT INITIAL.
        INSERT <ls_named>-file_name INTO TABLE lt_names.
      ENDIF.
      IF <ls_named>-checksum IS NOT INITIAL.
        INSERT <ls_named>-checksum INTO TABLE lt_checksums.
      ENDIF.
    ENDLOOP.
    SORT lt_names BY table_line.
    DELETE ADJACENT DUPLICATES FROM lt_names COMPARING table_line.
    SORT lt_checksums BY table_line.
    DELETE ADJACENT DUPLICATES FROM lt_checksums COMPARING table_line.
    DATA lv_since TYPE d.
    lv_since = mv_date - zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                     iv_name    = zif_cd_fmon_types=>gc_param-dup_days
                                                     iv_default = zif_cd_fmon_types=>gc_param_default-dup_days ).
    rs_ctx-history = mo_dao->get_history( it_names     = lt_names
                                          it_checksums = lt_checksums
                                          iv_since     = lv_since ).
  ENDMETHOD.


  METHOD throttle_settings.
    rs_throttle-minutes   = zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                        iv_name    = zif_cd_fmon_types=>gc_param-throttle_min
                                                        iv_default = zif_cd_fmon_types=>gc_param_default-throttle_min ).
    rs_throttle-scope     = to_upper( mo_params->get_param(
                              iv_name    = zif_cd_fmon_types=>gc_param-throttle_scope
                              iv_default = CONV #( zif_cd_fmon_types=>gc_param_default-throttle_scope ) ) ).
    rs_throttle-methods   = mo_params->get_param( iv_name    = zif_cd_fmon_types=>gc_param-throttle_methods
                                                  iv_default = zif_cd_fmon_types=>gc_param_default-throttle_methods ).
    rs_throttle-queue_max = zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                        iv_name    = zif_cd_fmon_types=>gc_param-queue_max
                                                        iv_default = zif_cd_fmon_types=>gc_param_default-queue_max ).
  ENDMETHOD.


  METHOD build_queue.
    TYPES tt_date_set TYPE SORTED TABLE OF d WITH UNIQUE KEY table_line.
    DATA lt_dates TYPE tt_date_set.
    DATA lt_files TYPE zif_cd_fmon_types=>tt_file.
    DATA lt_extra_ids TYPE tt_id_set.
    DATA lv_covered_from TYPE d.

    IF is_throttle-minutes <= 0.
      RETURN.
    ENDIF.
    lt_files = VALUE #( FOR ls_file IN mt_files ( ls_file ) ).
    DATA(lt_events) = mt_events.
    " Business dates of the throttled files with PRISM receipt evidence in this run
    LOOP AT zcl_cd_fmon_rules=>build_queue( it_files    = lt_files
                                            it_events   = lt_events
                                            it_ifaces   = mt_ifaces
                                            is_throttle = is_throttle ) ASSIGNING FIELD-SYMBOL(<ls_own>).
      INSERT <ls_own>-business_date INTO TABLE lt_dates.
    ENDLOOP.
    IF lt_dates IS INITIAL.
      RETURN.
    ENDIF.

    " The full batch run holds every file of its lookback window in memory
    IF mv_single = abap_false AND mv_iface IS INITIAL.
      lv_covered_from = mv_date - zcl_cd_ops_util=>param_int( io_params  = mo_params
                                                              iv_name    = zif_cd_fmon_types=>gc_param-lookback_days
                                                              iv_default = zif_cd_fmon_types=>gc_param_default-lookback_days ).
    ENDIF.
    LOOP AT lt_dates ASSIGNING FIELD-SYMBOL(<lv_date>).
      IF lv_covered_from IS NOT INITIAL AND <lv_date> BETWEEN lv_covered_from AND mv_date.
        CONTINUE.
      ENDIF.
      LOOP AT mo_dao->get_eval_files( iv_date_from  = <lv_date>
                                      iv_date_to    = <lv_date>
                                      iv_open_since = <lv_date> ) ASSIGNING FIELD-SYMBOL(<ls_peer>).
        IF <ls_peer>-business_date = <lv_date>
           AND NOT line_exists( mt_files[ file_id = <ls_peer>-file_id ] )
           AND NOT line_exists( lt_extra_ids[ table_line = <ls_peer>-file_id ] ).
          INSERT <ls_peer>-file_id INTO TABLE lt_extra_ids.
          INSERT <ls_peer> INTO TABLE lt_files.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    IF lt_extra_ids IS NOT INITIAL.
      LOOP AT mo_dao->get_events( VALUE #( FOR lv_id IN lt_extra_ids ( lv_id ) ) ) ASSIGNING FIELD-SYMBOL(<ls_event>).
        IF line_exists( lt_extra_ids[ table_line = <ls_event>-file_id ] ).
          INSERT <ls_event> INTO TABLE lt_events.
        ENDIF.
      ENDLOOP.
    ENDIF.
    rt_queue = zcl_cd_fmon_rules=>build_queue( it_files    = lt_files
                                               it_events   = lt_events
                                               it_ifaces   = mt_ifaces
                                               is_throttle = is_throttle ).
  ENDMETHOD.


  METHOD run_checks.
    DATA lt_found TYPE zif_cd_ops_types=>tt_finding.
    DATA(ls_ctx) = build_context( ).

    LOOP AT mt_checks INTO DATA(ls_check) WHERE active = abap_true.
      IF mv_single = abap_true
         AND ls_check-class_name <> gc_event_check-sla
         AND ls_check-class_name <> gc_event_check-reject
         AND ls_check-class_name <> gc_event_check-prism_file
         AND ls_check-class_name <> gc_event_check-regen.
        CONTINUE.
      ENDIF.
      TRY.
          lt_found = zcl_cd_fmon_factory=>get_check( ls_check-class_name )->execute( is_ctx   = ls_ctx
                                                                                      is_check = ls_check ).
          INSERT LINES OF lt_found INTO TABLE mt_findings.
        CATCH cx_root INTO DATA(lx_root).
          engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                          iv_key     = zif_cd_fmon_types=>gc_engine_key-check && ls_check-check_id
                          iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-check
                                                              iv_v1    = ls_check-check_id
                                                              iv_v2    = ls_check-class_name
                                                              iv_tail  = lx_root->get_text( ) ) ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD persist_registry.
    DATA lt_save TYPE zif_cd_fmon_types=>tt_file.

    LOOP AT mt_changed ASSIGNING FIELD-SYMBOL(<lv_file_id>).
      " READ TABLE sets sy-subrc; a table expression with OPTIONAL does not
      READ TABLE mt_files INTO DATA(ls_file) WITH TABLE KEY file_id = <lv_file_id>.
      IF sy-subrc = 0.
        ls_file-changed_at = mv_now.
        ls_file-changed_by = sy-uname.
        INSERT ls_file INTO TABLE lt_save.
      ENDIF.
    ENDLOOP.

    TRY.
        DATA(lt_conflicts) = mo_dao->save_files( lt_save ).
        LOOP AT mt_new_events ASSIGNING FIELD-SYMBOL(<ls_event>).
          mo_dao->insert_event( <ls_event> ).
        ENDLOOP.
      CATCH zcx_cd_ops_error INTO DATA(lx_ops).
        " Never commit a half-written registry (files without their events or vice versa)
        mo_store->rollback( ).
        engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-persist_error
                        iv_key     = zif_cd_fmon_types=>gc_engine_key-registry
                        iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-registry_not_saved
                                                            iv_tail  = lx_ops->get_text( ) ) ).
        RETURN.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        " Audit A05: technical SQL errors are rolled back the same way
        mo_store->rollback( ).
        engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-persist_error
                        iv_key     = zif_cd_fmon_types=>gc_engine_key-registry
                        iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-database_error
                                                            iv_tail  = lx_sql->get_text( ) ) ).
        RETURN.
    ENDTRY.

    " Audit A04: rows changed meanwhile by another process keep their newer state; the
    " next run re-derives from it. Visible, not an error.
    LOOP AT lt_conflicts ASSIGNING FIELD-SYMBOL(<lv_conflict>).
      READ TABLE mt_files INTO DATA(ls_conflict) WITH TABLE KEY file_id = <lv_conflict>.
      IF sy-subrc = 0.
        engine_finding( iv_code     = zif_cd_fmon_types=>gc_check_code-persist_conflict
                        iv_key      = COND string( WHEN ls_conflict-file_name IS NOT INITIAL THEN ls_conflict-file_name
                                                   ELSE ls_conflict-file_ref )
                        iv_iface_id = ls_conflict-iface_id
                        iv_severity = zif_cd_ops_types=>gc_severity-warning
                        iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-newer_registry_state
                                                             iv_v1    = ls_conflict-file_name ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD build_board.
    DATA ls_row TYPE zif_cd_fmon_types=>ty_board.

    DATA(lt_by_ref) = findings_by_reference( ).
    LOOP AT mt_files ASSIGNING FIELD-SYMBOL(<ls_file>).
      ls_row = CORRESPONDING #( <ls_file> ).
      READ TABLE mt_ifaces ASSIGNING FIELD-SYMBOL(<ls_iface>) WITH TABLE KEY iface_id = <ls_file>-iface_id.
      IF sy-subrc = 0.
        ls_row-owner = <ls_iface>-owner.
      ENDIF.
      DATA(lv_worst) = 0.
      READ TABLE lt_by_ref ASSIGNING FIELD-SYMBOL(<ls_ref>)
           WITH TABLE KEY reference = zcl_cd_fmon_util=>file_hex( <ls_file>-file_id ).
      IF sy-subrc = 0.
        ls_row-finding_count = <ls_ref>-count.
        ls_row-top_message   = <ls_ref>-top_message.
        lv_worst             = <ls_ref>-worst.
      ENDIF.
      ls_row-sla_status = COND #( WHEN lv_worst >= 3 THEN zif_cd_ops_types=>gc_rag-red
                                  WHEN lv_worst = 2 THEN zif_cd_ops_types=>gc_rag-amber
                                  ELSE zif_cd_ops_types=>gc_rag-green ).
      INSERT ls_row INTO TABLE rt_board.
      CLEAR ls_row.
    ENDLOOP.

    " Expected-but-missing files and other interface-level findings get their own row
    LOOP AT mt_findings ASSIGNING FIELD-SYMBOL(<ls_finding>) WHERE reference IS INITIAL AND group1 IS NOT INITIAL.
      CLEAR ls_row.
      ls_row-iface_id      = <ls_finding>-group1.
      ls_row-business_date = mv_date.
      ls_row-file_name     = <ls_finding>-object_key.
      ls_row-finding_count = 1.
      ls_row-top_message   = <ls_finding>-message.
      ls_row-sla_status    = zcl_cd_ops_util=>rag_from_findings( VALUE #( ( <ls_finding> ) ) ).
      INSERT ls_row INTO TABLE rt_board.
    ENDLOOP.

    LOOP AT rt_board ASSIGNING FIELD-SYMBOL(<ls_board>).
      <ls_board>-sla_light = SWITCH #( <ls_board>-sla_status
                                       WHEN zif_cd_ops_types=>gc_rag-red   THEN zif_cd_ops_types=>gc_light-red
                                       WHEN zif_cd_ops_types=>gc_rag-amber THEN zif_cd_ops_types=>gc_light-yellow
                                       ELSE zif_cd_ops_types=>gc_light-green ).
    ENDLOOP.
    SORT rt_board BY iface_id business_date file_name.
  ENDMETHOD.


  METHOD finish.
    DATA(lv_worst_run) = 0.
    cs_run-total_items = lines( mt_files ).
    DATA(lt_by_ref) = findings_by_reference( ).
    LOOP AT mt_files ASSIGNING FIELD-SYMBOL(<ls_file>).
      DATA(lv_worst) = VALUE #( lt_by_ref[ reference = zcl_cd_fmon_util=>file_hex( <ls_file>-file_id ) ]-worst
                                OPTIONAL ).
      CASE lv_worst.
        WHEN 4.
          cs_run-blocked_items += 1.
        WHEN 3.
          cs_run-failed_items += 1.
        WHEN 2.
          cs_run-warning_items += 1.
        WHEN OTHERS.
          cs_run-passed_items += 1.
      ENDCASE.
    ENDLOOP.

    lv_worst_run = zcl_cd_ops_util=>severity_rank( zcl_cd_ops_util=>worst_severity( mt_findings ) ).
    cs_run-rag      = zcl_cd_ops_util=>rag_from_findings( mt_findings ).
    cs_run-status   = COND #( WHEN lv_worst_run >= 3 THEN zif_cd_ops_types=>gc_run_status-error
                              WHEN lv_worst_run = 2 THEN zif_cd_ops_types=>gc_run_status-warning
                              ELSE zif_cd_ops_types=>gc_run_status-success ).
    cs_run-ended_at   = mo_clock->now( ).
    cs_run-runtime_ms = zcl_cd_ops_util=>elapsed_ms( iv_from = cs_run-started_at
                                                     iv_to   = cs_run-ended_at ).
    cs_run-message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-file_s_finding_s
                                               iv_v1    = |{ mv_date DATE = ISO }|
                                               iv_v2    = cs_run-total_items
                                               iv_v3    = lines( mt_findings ) ).

    " Single-event mode with FMON_PRISM_INSTANT blank: registry only - findings and alerts
    " come from the 5-minute run (which would otherwise see them as carried forward, not new)
    DATA(lv_instant) = xsdbool( mv_single = abap_false
                                OR mo_params->get_param( iv_name    = zif_cd_fmon_prism_types=>gc_param_instant
                                                         iv_default = zif_cd_fmon_prism_types=>gc_default_instant )
                                   IS NOT INITIAL ).
    IF lv_instant = abap_true.
      mo_store->save_findings( EXPORTING it_findings = mt_findings
                               CHANGING  cs_run      = cs_run ).
    ENDIF.
    mo_store->finish_run( cs_run ).

    IF mv_test_mode = abap_false AND lv_instant = abap_false.
      mo_store->commit( ).
      RETURN.
    ENDIF.
    IF mv_test_mode = abap_false.
      " Reconcile closes exceptions by object key: a run with only some checks must not close
      " the others' exceptions - single-event runs leave that to the 5-minute run
      IF mv_single = abap_false.
        reconcile_files( cs_run ).
      ENDIF.
      " Results are durable before anyone is told (a channel may COMMIT WORK itself)
      mo_store->commit( ).
      " Alert thresholds, recipients, channels and throttling live in ZCD_OPS_ALRULE
      TRY.
          zcl_cd_ops_factory=>get_alert( )->dispatch( is_run      = cs_run
                                                      it_findings = mt_findings ).
        CATCH zcx_cd_ops_error INTO DATA(lx_alert).
          DATA(lt_alert_error) = VALUE zif_cd_ops_types=>tt_finding(
            ( zcl_cd_fmon_util=>new_key_finding(
                iv_object_key = 'ALERT'
                is_check      = VALUE #( check_id = zif_cd_fmon_types=>gc_engine_rule )
                iv_code       = zif_cd_fmon_types=>gc_check_code-alert_failed
                iv_message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-alert_dispatch_failed
                                                       iv_tail  = lx_alert->get_text( ) ) ) ) ).
          mo_store->save_findings( EXPORTING it_findings = lt_alert_error
                                   CHANGING  cs_run      = cs_run ).
          INSERT LINES OF lt_alert_error INTO TABLE mt_findings.
          mo_store->finish_run( cs_run ).
          mo_store->commit( ).
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD is_lot_controlled.
    rv_controlled = xsdbool( is_iface-direction = zif_cd_fmon_types=>gc_direction-inbound
                             AND zcl_cd_fmon_rules=>lot_cfg_for( it_cfgs     = mt_lotcfgs
                                                                 iv_iface_id = is_iface-iface_id
                                                                 iv_lot_type = CONV #( is_iface-file_type ) )
                                 IS NOT INITIAL ).
  ENDMETHOD.


  METHOD findings_by_reference.
    " In finding order: the first finding of the worst rank gives the message, as before
    LOOP AT mt_findings ASSIGNING FIELD-SYMBOL(<ls_finding>) WHERE reference IS NOT INITIAL.
      READ TABLE rt_summary ASSIGNING FIELD-SYMBOL(<ls_summary>) WITH TABLE KEY reference = <ls_finding>-reference.
      IF sy-subrc <> 0.
        INSERT VALUE #( reference = <ls_finding>-reference ) INTO TABLE rt_summary ASSIGNING <ls_summary>.
      ENDIF.
      <ls_summary>-count += 1.
      DATA(lv_rank) = zcl_cd_ops_util=>severity_rank( <ls_finding>-severity ).
      IF lv_rank > <ls_summary>-worst.
        <ls_summary>-worst       = lv_rank.
        <ls_summary>-top_message = <ls_finding>-message.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD engine_finding.
    DATA ls_check TYPE zif_cd_fmon_types=>ty_chk.
    ls_check-check_id = zif_cd_fmon_types=>gc_engine_rule.
    DATA(ls_finding) = zcl_cd_fmon_util=>new_key_finding( iv_iface_id   = iv_iface_id
                                                         iv_object_key = iv_key
                                                         is_check      = ls_check
                                                         iv_code       = iv_code
                                                         iv_message    = iv_message
                                                         iv_severity   = iv_severity ).
    IF line_exists( mt_findings[ check_code = ls_finding-check_code object_key = ls_finding-object_key ] ).
      RETURN.
    ENDIF.
    INSERT ls_finding INTO TABLE mt_findings.
  ENDMETHOD.



  METHOD mark_changed.
    INSERT iv_file_id INTO TABLE mt_changed.
  ENDMETHOD.

ENDCLASS.
