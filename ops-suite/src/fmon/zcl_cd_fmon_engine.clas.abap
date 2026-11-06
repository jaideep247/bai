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
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - engine (one run per business date)</p>
"! Run order: start run -> load customizing -> sync sources -> load registry
"! -> lot outcomes -> calendar expectations -> checks -> persist registry
"! -> board -> save findings -> dispatch alerts (core router) -> finish -> commit.
"! A failing adapter, lot reader, calendar or check never aborts the run:
"! it becomes a PLUGIN_ERROR finding (severity E). Test mode writes nothing,
"! dispatches nothing and does not commit.
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

  PRIVATE SECTION.
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
      END OF ty_group.
    TYPES tt_group TYPE STANDARD TABLE OF ty_group WITH EMPTY KEY.
    TYPES tt_group_hash TYPE HASHED TABLE OF ty_group WITH UNIQUE KEY src_id iface_id file_ref stage.

    DATA mo_dao TYPE REF TO zif_cd_fmon_dao.
    DATA mo_store TYPE REF TO zif_cd_ops_store.
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

    DATA mt_files TYPE tt_file_map.
    DATA mt_changed TYPE tt_id_set.
    DATA mt_events TYPE zif_cd_fmon_types=>tt_event.
    DATA mt_new_events TYPE zif_cd_fmon_types=>tt_event.
    DATA mt_lots TYPE zif_cd_fmon_types=>tt_lot_status.
    DATA mt_expects TYPE zif_cd_fmon_types=>tt_expect.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.

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

    METHODS get_or_create
      IMPORTING
        is_group          TYPE ty_group
        is_iface          TYPE zif_cd_fmon_types=>ty_iface
      RETURNING
        VALUE(rv_file_id) TYPE zif_cd_fmon_types=>ty_file_id
      RAISING
        zcx_cd_ops_error.

    METHODS apply_group
      IMPORTING
        is_group TYPE ty_group
        is_iface TYPE zif_cd_fmon_types=>ty_iface
      CHANGING
        cs_file  TYPE zif_cd_fmon_types=>ty_file.

    METHODS load_registry.

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

    METHODS int_param
      IMPORTING
        iv_name         TYPE zif_cd_ops_types=>ty_param_name
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

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
      iv_variant   = COND #( WHEN iv_iface_id IS INITIAL THEN 'ALL' ELSE iv_iface_id )
      iv_test_mode = iv_test_mode ).
    IF mv_test_mode = abap_false.
      " Run header durable first: a later rollback of a failed registry save keeps the run
      mo_store->commit( ).
    ENDIF.

    load_config( ).
    sync_sources( ).
    load_registry( ).
    derive_lot_outcomes( ).
    build_expectations( ).
    run_checks( ).
    IF mv_test_mode = abap_false.
      persist_registry( ).
    ENDIF.

    rs_result-board = build_board( ).
    finish( CHANGING cs_run = ls_run ).
    rs_result-run      = ls_run.
    rs_result-findings = mt_findings.
  ENDMETHOD.


  METHOD init.
    mo_dao      = zcl_cd_fmon_factory=>get_dao( ).
    mo_calendar = zcl_cd_fmon_factory=>get_calendar( ).
    mo_store    = zcl_cd_ops_factory=>get_store( ).
    mo_clock    = zcl_cd_ops_factory=>get_clock( ).

    CLEAR: mt_files, mt_changed, mt_events, mt_new_events, mt_lots, mt_expects, mt_findings.
    mv_date      = iv_business_date.
    mv_iface     = iv_iface_id.
    mv_test_mode = iv_test_mode.
    mv_now       = mo_clock->now( ).
    mv_tz        = mo_store->get_param( iv_name    = zif_cd_fmon_types=>gc_param-time_zone
                                        iv_default = `UTC` ).
  ENDMETHOD.


  METHOD load_config.
    mt_ifaces  = mo_dao->get_ifaces( ).
    mt_slas    = mo_dao->get_slas( ).
    mt_cals    = mo_dao->get_calendars( ).
    mt_srcs    = mo_dao->get_sources( ).
    mt_maps    = mo_dao->get_source_maps( ).
    mt_lotcfgs = mo_dao->get_lot_configs( ).
    mt_checks  = mo_dao->get_checks( ).
  ENDMETHOD.


  METHOD sync_sources.
    DATA ls_request TYPE zif_cd_fmon_types=>ty_read_request.
    DATA lt_records TYPE zif_cd_fmon_types=>tt_src_record.
    DATA lt_groups TYPE tt_group.

    ls_request-date_from = mv_date - int_param( iv_name    = zif_cd_fmon_types=>gc_param-lookback_days
                                                iv_default = 1 ).
    ls_request-date_to   = mv_date.
    ls_request-time_zone = mv_tz.
    ls_request-max_rows  = int_param( iv_name    = zif_cd_fmon_types=>gc_param-max_rows
                                      iv_default = 50000 ).

    LOOP AT mt_srcs INTO DATA(ls_src).
      IF mv_iface IS NOT INITIAL AND ls_src-iface_id IS NOT INITIAL AND ls_src-iface_id <> mv_iface.
        CONTINUE.
      ENDIF.
      ls_request-src  = ls_src.
      ls_request-maps = VALUE #( FOR ls_map IN mt_maps WHERE ( src_id = ls_src-src_id ) ( ls_map ) ).
      TRY.
          lt_records = zcl_cd_fmon_factory=>get_adapter( ls_src-adapter_class )->read( ls_request ).
        CATCH zcx_cd_ops_error INTO DATA(lx_ops).
          engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                          iv_key     = |SRC:{ ls_src-src_id }|
                          iv_message = |Source { ls_src-src_id } ({ ls_src-table_name }): { lx_ops->get_text( ) }| ).
          CONTINUE.
        CATCH cx_root INTO DATA(lx_root).
          engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                          iv_key     = |SRC:{ ls_src-src_id }|
                          iv_message = |Source { ls_src-src_id } ({ ls_src-table_name }): { lx_root->get_text( ) }| ).
          CONTINUE.
      ENDTRY.

      DATA(lt_src_groups) = aggregate( is_src     = ls_src
                                       it_records = lt_records ).
      APPEND LINES OF lt_src_groups TO lt_groups.
    ENDLOOP.

    " Apply all sources in event-time order: terminal outcomes are final, so a
    " later status must never be applied before an earlier one of another source
    prefetch( lt_groups ).
    SORT lt_groups BY event_at src_id.
    LOOP AT lt_groups INTO DATA(ls_group).
      DATA(ls_iface) = VALUE #( mt_ifaces[ iface_id = ls_group-iface_id ] OPTIONAL ).
      DATA(lv_file_id) = get_or_create( is_group = ls_group
                                        is_iface = ls_iface ).
      DATA(ls_file) = VALUE #( mt_files[ file_id = lv_file_id ] OPTIONAL ).
      IF zcl_cd_fmon_status=>rank( ls_group-stage ) = 1
         AND ls_group-business_date > ls_file-business_date.
        " A new generation/receipt under a reference already used on an earlier day:
        " the file key is not unique - make it visible instead of merging silently
        engine_finding( iv_code     = zif_cd_fmon_types=>gc_check_code-ref_reused
                        iv_key      = |{ ls_group-src_id }:{ ls_group-file_ref }|
                        iv_iface_id = ls_group-iface_id
                        iv_severity = zif_cd_ops_types=>gc_severity-warning
                        iv_message  = |Reference { ls_group-file_ref } of { ls_file-business_date DATE = ISO } | &&
                                      |reused on { ls_group-business_date DATE = ISO }: configure a unique FILE_KEY_FIELD| ).
        CONTINUE.
      ENDIF.
      apply_group( EXPORTING is_group = ls_group
                             is_iface = ls_iface
                   CHANGING  cs_file  = ls_file ).
      MODIFY TABLE mt_files FROM ls_file.
      mark_changed( lv_file_id ).
    ENDLOOP.
  ENDMETHOD.


  METHOD aggregate.
    DATA lt_hash TYPE tt_group_hash.
    FIELD-SYMBOLS <ls_group> TYPE ty_group.

    LOOP AT it_records INTO DATA(ls_record).
      DATA(ls_iface) = zcl_cd_fmon_rules=>resolve_iface( it_ifaces    = mt_ifaces
                                                        iv_iface_id  = ls_record-iface_id
                                                        iv_file_name = ls_record-file_name
                                                        iv_source    = ls_record-source_sys
                                                        iv_lob       = ls_record-lob ).
      IF ls_iface IS INITIAL.
        engine_finding( iv_code     = zif_cd_fmon_types=>gc_check_code-unmapped_file
                        iv_key      = |{ is_src-src_id }:{ ls_record-file_ref }|
                        iv_severity = zif_cd_ops_types=>gc_severity-warning
                        iv_message  = |Source { is_src-src_id }: no interface matches file { ls_record-file_name }| ).
        CONTINUE.
      ENDIF.
      IF mv_iface IS NOT INITIAL AND ls_iface-iface_id <> mv_iface.
        CONTINUE.
      ENDIF.
      IF ls_record-stage IS INITIAL
         OR zcl_cd_fmon_status=>direction_of( ls_record-stage ) <> ls_iface-direction.
        engine_finding( iv_code     = zif_cd_fmon_types=>gc_check_code-unmapped_status
                        iv_key      = |{ is_src-src_id }:{ ls_record-raw_status }|
                        iv_iface_id = ls_iface-iface_id
                        iv_severity = zif_cd_ops_types=>gc_severity-warning
                        iv_message  = |Source { is_src-src_id }: status '{ ls_record-raw_status }' has no | &&
                                      |{ ls_iface-direction } stage in ZCD_FMON_SRCMAP| ).
        CONTINUE.
      ENDIF.

      READ TABLE lt_hash ASSIGNING <ls_group>
        WITH TABLE KEY src_id   = is_src-src_id
                       iface_id = ls_iface-iface_id
                       file_ref = ls_record-file_ref
                       stage    = ls_record-stage.
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
    ENDLOOP.

    rt_groups = VALUE #( FOR ls_hash IN lt_hash ( ls_hash ) ).
  ENDMETHOD.


  METHOD prefetch.
    DATA lt_keys TYPE zif_cd_fmon_types=>tt_file_key.
    LOOP AT it_groups INTO DATA(ls_group).
      IF line_exists( mt_files[ KEY ref COMPONENTS iface_id = ls_group-iface_id file_ref = ls_group-file_ref ] )
         OR line_exists( lt_keys[ iface_id = ls_group-iface_id file_ref = ls_group-file_ref ] ).
        CONTINUE.
      ENDIF.
      INSERT VALUE #( iface_id = ls_group-iface_id file_ref = ls_group-file_ref ) INTO TABLE lt_keys.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_found) = mo_dao->find_files_by_ref( lt_keys ).
    LOOP AT lt_found INTO DATA(ls_file).
      INSERT ls_file INTO TABLE mt_files.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_or_create.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.

    READ TABLE mt_files INTO ls_file WITH KEY ref COMPONENTS iface_id = is_group-iface_id
                                                            file_ref = is_group-file_ref.
    IF sy-subrc = 0.
      rv_file_id = ls_file-file_id.
      RETURN.
    ENDIF.

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


  METHOD apply_group.
    IF zcl_cd_fmon_status=>rank( is_group-stage ) = 1.
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
       AND ( cs_file-size_known = abap_false OR zcl_cd_fmon_status=>rank( is_group-stage ) = 1 ).
      cs_file-size_bytes = is_group-size_bytes.
      cs_file-size_known = abap_true.
    ENDIF.

    " Disbursements are acknowledged per payment (one row each), collections per file
    CASE is_group-stage.
      WHEN zif_cd_fmon_types=>gc_stage-ack.
        cs_file-ack_count  = COND #( WHEN is_iface-ack_level = zif_cd_fmon_types=>gc_ack_level-payment
                                     THEN is_group-rows ELSE is_group-rec_count ).
        cs_file-ack_amount = is_group-amount.
      WHEN zif_cd_fmon_types=>gc_stage-nack.
        cs_file-nack_count = COND #( WHEN is_iface-ack_level = zif_cd_fmon_types=>gc_ack_level-payment
                                     THEN is_group-rows
                                     ELSE nmax( val1 = is_group-rec_count val2 = 1 ) ).
      WHEN OTHERS.
    ENDCASE.

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

    INSERT VALUE #( file_id      = cs_file-file_id
                    stage        = is_group-stage
                    event_at     = is_group-event_at
                    src_id       = is_group-src_id
                    src_key      = is_group-file_ref
                    record_count = COND #( WHEN is_group-count_known = abap_true THEN is_group-rec_count
                                           ELSE is_group-rows )
                    amount       = is_group-amount
                    info         = |{ is_group-rows } source row(s), status { is_group-raw_status }|
                    created_by   = sy-uname
                    created_at   = mv_now ) INTO TABLE mt_new_events.

    " For lot-controlled interfaces the lot, not the source, decides the outcome
    zcl_cd_fmon_status=>apply(
      EXPORTING
        iv_stage = zcl_cd_fmon_rules=>cap_stage( iv_stage          = is_group-stage
                                                 iv_lot_controlled = is_lot_controlled( is_iface ) )
      CHANGING
        cs_file  = cs_file ).
  ENDMETHOD.


  METHOD load_registry.
    DATA lv_from TYPE d.
    DATA lv_open_since TYPE d.
    lv_from       = mv_date - int_param( iv_name = zif_cd_fmon_types=>gc_param-lookback_days iv_default = 1 ).
    lv_open_since = mv_date - int_param( iv_name = zif_cd_fmon_types=>gc_param-open_days iv_default = 30 ).
    DATA(lt_db) = mo_dao->get_eval_files( iv_date_from  = lv_from
                                          iv_date_to    = mv_date
                                          iv_open_since = lv_open_since
                                          iv_iface_id   = mv_iface ).
    LOOP AT lt_db INTO DATA(ls_db).
      IF NOT line_exists( mt_files[ file_id = ls_db-file_id ] ).
        INSERT ls_db INTO TABLE mt_files.
      ENDIF.
    ENDLOOP.

    IF mt_files IS NOT INITIAL.
      mt_events = mo_dao->get_events( VALUE #( FOR ls_file IN mt_files ( ls_file-file_id ) ) ).
    ENDIF.
    LOOP AT mt_new_events INTO DATA(ls_event).
      IF NOT line_exists( mt_events[ file_id = ls_event-file_id
                                     src_id  = ls_event-src_id
                                     src_key = ls_event-src_key
                                     stage   = ls_event-stage ] ).
        INSERT ls_event INTO TABLE mt_events.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD derive_lot_outcomes.
    DATA lt_batch TYPE zif_cd_fmon_types=>tt_file.
    DATA lt_status TYPE zif_cd_fmon_types=>tt_lot_status.

    DATA(lv_default_sla) = int_param( iv_name = zif_cd_fmon_types=>gc_param-noc_sla_days iv_default = 6 ).
    DATA(lv_max_rows) = int_param( iv_name = zif_cd_fmon_types=>gc_param-max_rows iv_default = 50000 ).

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
                          iv_key     = |LOT:{ ls_cfg-iface_id }:{ ls_cfg-lot_type }|
                          iv_message = |Lot reader { ls_cfg-lot_type } ({ ls_cfg-item_table }): { lx_root->get_text( ) }| ).
          CONTINUE.
      ENDTRY.

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
        info         = |{ is_status-open_items } of { is_status-total_items } { is_status-lot_type } item(s) open|
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
        rv_days = mo_calendar->working_days_between( iv_from        = is_file-business_date
                                                     iv_to          = mv_date
                                                     iv_calendar_id = lv_cal ).
      CATCH zcx_cd_ops_error INTO DATA(lx_cal).
        engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                        iv_key     = |CAL:{ lv_cal }|
                        iv_message = |Factory calendar { lv_cal }: { lx_cal->get_text( ) }; calendar days used| ).
        rv_days = nmax( val1 = 0 val2 = mv_date - is_file-business_date ).
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
                        iv_returns_days = mo_store->get_param( zif_cd_fmon_types=>gc_param-returns_days ) ).
      CATCH zcx_cd_ops_error INTO DATA(lx_cal).
        engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                        iv_key     = |CAL:{ iv_calendar_id }|
                        iv_message = |Factory calendar { iv_calendar_id }: { lx_cal->get_text( ) }; NORMAL day used| ).
        rv_day_type = zif_cd_fmon_types=>gc_day_type-normal.
    ENDTRY.
  ENDMETHOD.


  METHOD calendar_id_for.
    LOOP AT mt_cals INTO DATA(ls_cal) WHERE iface_id = iv_iface_id AND fcal_id IS NOT INITIAL.
      rv_cal = ls_cal-fcal_id.
      RETURN.
    ENDLOOP.
    rv_cal = mo_store->get_param( iv_name    = zif_cd_fmon_types=>gc_param-factory_cal
                                  iv_default = `US` ).
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

    LOOP AT mt_files INTO DATA(ls_named).
      IF ls_named-file_name IS NOT INITIAL.
        INSERT ls_named-file_name INTO TABLE lt_names.
      ENDIF.
      IF ls_named-checksum IS NOT INITIAL.
        INSERT ls_named-checksum INTO TABLE lt_checksums.
      ENDIF.
    ENDLOOP.
    SORT lt_names BY table_line.
    DELETE ADJACENT DUPLICATES FROM lt_names COMPARING table_line.
    SORT lt_checksums BY table_line.
    DELETE ADJACENT DUPLICATES FROM lt_checksums COMPARING table_line.
    DATA lv_since TYPE d.
    lv_since = mv_date - int_param( iv_name = zif_cd_fmon_types=>gc_param-dup_days iv_default = 7 ).
    rs_ctx-history = mo_dao->get_history( it_names     = lt_names
                                          it_checksums = lt_checksums
                                          iv_since     = lv_since ).
  ENDMETHOD.


  METHOD run_checks.
    DATA lt_found TYPE zif_cd_ops_types=>tt_finding.
    DATA(ls_ctx) = build_context( ).

    LOOP AT mt_checks INTO DATA(ls_check) WHERE active = abap_true.
      TRY.
          lt_found = zcl_cd_fmon_factory=>get_check( ls_check-class_name )->execute( is_ctx   = ls_ctx
                                                                                      is_check = ls_check ).
          APPEND LINES OF lt_found TO mt_findings.
        CATCH cx_root INTO DATA(lx_root).
          engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-plugin_error
                          iv_key     = |CHK:{ ls_check-check_id }|
                          iv_message = |Check { ls_check-check_id } ({ ls_check-class_name }): { lx_root->get_text( ) }| ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD persist_registry.
    DATA lt_save TYPE zif_cd_fmon_types=>tt_file.

    LOOP AT mt_changed INTO DATA(lv_file_id).
      " READ TABLE sets sy-subrc; a table expression with OPTIONAL does not
      READ TABLE mt_files INTO DATA(ls_file) WITH TABLE KEY file_id = lv_file_id.
      IF sy-subrc = 0.
        ls_file-changed_at = mv_now.
        ls_file-changed_by = sy-uname.
        INSERT ls_file INTO TABLE lt_save.
      ENDIF.
    ENDLOOP.

    TRY.
        mo_dao->save_files( lt_save ).
        LOOP AT mt_new_events INTO DATA(ls_event).
          mo_dao->insert_event( ls_event ).
        ENDLOOP.
      CATCH zcx_cd_ops_error INTO DATA(lx_ops).
        " Never commit a half-written registry (files without their events or vice versa)
        mo_store->rollback( ).
        engine_finding( iv_code    = zif_cd_fmon_types=>gc_check_code-persist_error
                        iv_key     = 'ZCD_FMON_FILE'
                        iv_message = |Registry not saved: { lx_ops->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD build_board.
    DATA ls_row TYPE zif_cd_fmon_types=>ty_board.

    LOOP AT mt_files INTO DATA(ls_file).
      ls_row = CORRESPONDING #( ls_file ).
      READ TABLE mt_ifaces INTO DATA(ls_iface) WITH TABLE KEY iface_id = ls_file-iface_id.
      IF sy-subrc = 0.
        ls_row-owner = ls_iface-owner.
      ENDIF.
      DATA(lv_ref) = zcl_cd_fmon_util=>file_hex( ls_file-file_id ).
      DATA(lv_worst) = 0.
      LOOP AT mt_findings INTO DATA(ls_finding) WHERE reference = lv_ref.
        ls_row-finding_count += 1.
        IF zcl_cd_ops_util=>severity_rank( ls_finding-severity ) > lv_worst.
          lv_worst = zcl_cd_ops_util=>severity_rank( ls_finding-severity ).
          ls_row-top_message = ls_finding-message.
        ENDIF.
      ENDLOOP.
      ls_row-sla_status = COND #( WHEN lv_worst >= 3 THEN zif_cd_ops_types=>gc_rag-red
                                  WHEN lv_worst = 2 THEN zif_cd_ops_types=>gc_rag-amber
                                  ELSE zif_cd_ops_types=>gc_rag-green ).
      INSERT ls_row INTO TABLE rt_board.
      CLEAR ls_row.
    ENDLOOP.

    " Expected-but-missing files and other interface-level findings get their own row
    LOOP AT mt_findings INTO ls_finding WHERE reference IS INITIAL AND group1 IS NOT INITIAL.
      CLEAR ls_row.
      ls_row-iface_id      = ls_finding-group1.
      ls_row-business_date = mv_date.
      ls_row-file_name     = ls_finding-object_key.
      ls_row-finding_count = 1.
      ls_row-top_message   = ls_finding-message.
      ls_row-sla_status    = zcl_cd_ops_util=>rag_from_findings( VALUE #( ( ls_finding ) ) ).
      INSERT ls_row INTO TABLE rt_board.
    ENDLOOP.

    LOOP AT rt_board ASSIGNING FIELD-SYMBOL(<ls_board>).
      <ls_board>-sla_light = SWITCH #( <ls_board>-sla_status
                                       WHEN zif_cd_ops_types=>gc_rag-red   THEN '1'
                                       WHEN zif_cd_ops_types=>gc_rag-amber THEN '2'
                                       ELSE '3' ).
    ENDLOOP.
    SORT rt_board BY iface_id business_date file_name.
  ENDMETHOD.


  METHOD finish.
    DATA(lv_worst_run) = 0.
    cs_run-total_items = lines( mt_files ).
    LOOP AT mt_files INTO DATA(ls_file).
      DATA(lv_ref) = zcl_cd_fmon_util=>file_hex( ls_file-file_id ).
      DATA(lv_worst) = 0.
      LOOP AT mt_findings INTO DATA(ls_finding) WHERE reference = lv_ref.
        lv_worst = nmax( val1 = lv_worst val2 = zcl_cd_ops_util=>severity_rank( ls_finding-severity ) ).
      ENDLOOP.
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
    cs_run-message    = |{ mv_date DATE = ISO }: { cs_run-total_items } file(s), | &&
                        |{ lines( mt_findings ) } finding(s)|.

    mo_store->save_findings( EXPORTING it_findings = mt_findings
                             CHANGING  cs_run      = cs_run ).
    mo_store->finish_run( cs_run ).

    IF mv_test_mode = abap_false.
      reconcile_files( cs_run ).
      " Results are durable before anyone is told (a channel may COMMIT WORK itself)
      mo_store->commit( ).
      " Alert thresholds, recipients, channels and throttling live in ZCD_OPS_ALERT_RULE
      TRY.
          zcl_cd_ops_factory=>get_alert( )->dispatch( is_run      = cs_run
                                                      it_findings = mt_findings ).
        CATCH zcx_cd_ops_error INTO DATA(lx_alert).
          DATA(lt_alert_error) = VALUE zif_cd_ops_types=>tt_finding(
            ( zcl_cd_fmon_util=>new_key_finding(
                iv_object_key = 'ALERT'
                is_check      = VALUE #( check_id = zif_cd_fmon_types=>gc_engine_rule )
                iv_code       = zif_cd_fmon_types=>gc_check_code-alert_failed
                iv_message    = |Alert dispatch failed: { lx_alert->get_text( ) }| ) ) ).
          mo_store->save_findings( EXPORTING it_findings = lt_alert_error
                                   CHANGING  cs_run      = cs_run ).
          APPEND LINES OF lt_alert_error TO mt_findings.
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


  METHOD int_param.
    rv_value = zcl_cd_ops_util=>to_decimal( iv_value   = mo_store->get_param( iv_name    = iv_name
                                                                              iv_default = |{ iv_default }| )
                                            iv_default = iv_default ).
  ENDMETHOD.


  METHOD mark_changed.
    INSERT iv_file_id INTO TABLE mt_changed.
  ENDMETHOD.

ENDCLASS.
