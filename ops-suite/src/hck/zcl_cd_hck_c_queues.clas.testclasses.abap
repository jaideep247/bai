*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_queues.clas.testclasses.abap
*& Purpose:
*& Unit tests of the queue check: error / hold / stuck classification per
*& source, stuck age boundary, zero metrics for empty queues, queue name
*& filter, configured states, unreadable source, bgRFC source without state
*& field, bgRFC not configured, row cap, invalid pattern. The runtime DAO is
*& a test double from the HCK injector, parameters the delivered in-memory
*& definitions; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (queue errors, morning report).
*&---------------------------------------------------------------------*
CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    TYPES:
      BEGIN OF ty_kind_group,
        kind  TYPE zif_cd_hck_runtime_types=>ty_queue_kind,
        group TYPE zif_cd_hck_runtime_types=>ty_queue_group,
      END OF ty_kind_group.
    DATA mt_groups TYPE STANDARD TABLE OF ty_kind_group WITH EMPTY KEY.
    DATA mt_sources TYPE STANDARD TABLE OF zif_cd_hck_runtime_types=>ty_queue_source WITH EMPTY KEY.
    DATA mv_fail_kind TYPE zif_cd_hck_runtime_types=>ty_queue_kind.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
  METHOD zif_cd_hck_runtime_dao~get_queue_groups.
    INSERT is_source INTO TABLE mt_sources.
    IF is_source-kind = mv_fail_kind.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e304(zcd_ops) WITH is_source-state_field is_source-tabname.
    ENDIF.
    LOOP AT mt_groups ASSIGNING FIELD-SYMBOL(<ls_group>) WHERE kind = is_source-kind.
      INSERT <ls_group>-group INTO TABLE rt_groups.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_queues DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check   TYPE zif_cd_hck_types=>ty_check_id VALUE 'E_QUEUES',
      gc_queue   TYPE zif_cd_hck_runtime_types=>ty_queue_name VALUE 'ZCD_PAYM_0001',
      gc_other   TYPE zif_cd_hck_runtime_types=>ty_queue_name VALUE 'CRM_SITE_01',
      gc_dest    TYPE zif_cd_hck_runtime_types=>ty_queue_name VALUE 'PRISM_OUT',
      gc_today   TYPE d VALUE '20261107',
      gc_now     TYPE t VALUE '100000',
      gc_age_30  TYPE t VALUE '093000',
      gc_age_31  TYPE t VALUE '092900',
      gc_bgrfc   TYPE zif_cd_hck_types=>ty_param VALUE 'TABLE=ZBGRFC_ERR;NAME=QUEUE;DEST=DEST;DATE=ERDAT;TIME=ERZEIT',
      gc_entries TYPE i VALUE 3.

    DATA mo_dao TYPE REF TO ltd_runtime_dao.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS error_counted_per_source   FOR TESTING.
    METHODS hold_state_warns           FOR TESTING.
    METHODS stuck_after_age_limit      FOR TESTING.
    METHODS empty_queues_measure_zero  FOR TESTING.
    METHODS name_filter_applies        FOR TESTING.
    METHODS states_are_configurable    FOR TESTING.
    METHODS unreadable_source_reported FOR TESTING.
    METHODS bgrfc_rows_are_errors      FOR TESTING.
    METHODS read_cap_reported          FOR TESTING.
    METHODS invalid_pattern_raises     FOR TESTING.

    METHODS add_group
      IMPORTING
        iv_kind  TYPE zif_cd_hck_runtime_types=>ty_queue_kind DEFAULT zif_cd_hck_runtime_types=>gc_queue_kind-outbound
        iv_name  TYPE zif_cd_hck_runtime_types=>ty_queue_name DEFAULT gc_queue
        iv_state TYPE zif_cd_hck_runtime_types=>ty_queue_state
        iv_time  TYPE t DEFAULT gc_age_31.
    METHODS act
      IMPORTING
        iv_names         TYPE zif_cd_hck_types=>ty_param OPTIONAL
        iv_bgrfc         TYPE zif_cd_hck_types=>ty_param OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_ca_ops_error.
    METHODS metric
      IMPORTING
        is_result       TYPE zif_cd_hck_types=>ty_check_result
        iv_metric       TYPE zif_cd_hck_types=>ty_metric_name
        iv_kind         TYPE zif_cd_hck_runtime_types=>ty_queue_kind DEFAULT zif_cd_hck_runtime_types=>gc_queue_kind-outbound
      RETURNING
        VALUE(rv_value) TYPE zif_cd_hck_types=>ty_value.
    METHODS finding
      IMPORTING
        is_result         TYPE zif_cd_hck_types=>ty_check_result
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.
ENDCLASS.


CLASS ltc_queues IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_dao ).
    mo_params = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_params.
  ENDMETHOD.


  METHOD add_group.
    DATA ls_group TYPE ltd_runtime_dao=>ty_kind_group.
    ls_group-kind          = iv_kind.
    ls_group-group-name    = iv_name.
    ls_group-group-dest    = gc_dest.
    ls_group-group-state   = iv_state.
    ls_group-group-qdate   = gc_today.
    ls_group-group-qtime   = iv_time.
    ls_group-group-entries = gc_entries.
    INSERT ls_group INTO TABLE mo_dao->mt_groups.
  ENDMETHOD.


  METHOD act.
    DATA ls_def TYPE zif_cd_hck_types=>ty_check_def.
    DATA ls_context TYPE zif_cd_hck_types=>ty_context.
    ls_def-check_id        = gc_check.
    ls_def-param1          = iv_names.
    ls_def-param4          = iv_bgrfc.
    ls_context-report_date = gc_today.
    ls_context-now_date    = gc_today.
    ls_context-now_time    = gc_now.
    rs_result = NEW zcl_cd_hck_c_queues( )->zif_cd_hck_check~execute( is_def        = ls_def
                                                                      it_thresholds = VALUE #( )
                                                                      is_context    = ls_context ).
  ENDMETHOD.


  METHOD metric.
    rv_value = VALUE #( is_result-metrics[ metric = iv_metric dim1 = iv_kind ]-value OPTIONAL ).
  ENDMETHOD.


  METHOD finding.
    rs_finding = VALUE #( is_result-findings[ check_code = iv_code ] OPTIONAL ).
  ENDMETHOD.


  " Rule: SYSFAIL is an error of the source; the finding names queue, destination, state, entries,
  " age and the transaction to look in (SMQ1) - nothing is restarted
  METHOD error_counted_per_source.
    TRY.
        add_group( iv_state = 'SYSFAIL' ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_queues=>gc_metric-error )
                                            exp = gc_entries msg = 'Q_ERROR QOUT = entries' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_queues=>gc_metric-oldest )
                                            exp = 31 msg = 'Oldest age in minutes' ).
        DATA(ls_finding) = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-queue_error ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'Error state: error' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_finding-message
          exp = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-queue_group
                                       iv_v1    = zif_cd_hck_runtime_types=>gc_queue_kind-outbound
                                       iv_v2    = condense( gc_queue )
                                       iv_v3    = condense( gc_dest )
                                       iv_v4    = 'SYSFAIL'
                                       iv_tail  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-queue_detail
                                                                        iv_v1    = gc_entries
                                                                        iv_v2    = 31
                                                                        iv_v3    = zif_cd_hck_runtime_types=>gc_queue_tcode-outbound ) )
          msg = 'Queue, destination, state, entries, age, transaction' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a stopped queue (STOP) is HOLD - a warning, counted in Q_HOLD of its source
  METHOD hold_state_warns.
    TRY.
        add_group( iv_kind = zif_cd_hck_runtime_types=>gc_queue_kind-inbound iv_state = 'STOP' ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_queues=>gc_metric-hold
                                                          iv_kind   = zif_cd_hck_runtime_types=>gc_queue_kind-inbound )
                                            exp = gc_entries msg = 'Q_HOLD QIN = entries' ).
        cl_abap_unit_assert=>assert_equals(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-queue_hold )-severity
          exp = zif_ca_ops_types=>gc_severity-warning
          msg = 'Hold: warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: READY older than the age limit (30 min) is stuck; exactly 30 minutes is not
  METHOD stuck_after_age_limit.
    TRY.
        add_group( iv_state = 'READY' iv_time = gc_age_30 ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_queues=>gc_metric-stuck )
                                            exp = 0 msg = '30 min: not stuck' ).
        CLEAR mo_dao->mt_groups.
        add_group( iv_state = 'READY' iv_time = gc_age_31 ).
        ls_result = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_queues=>gc_metric-stuck )
                                            exp = gc_entries msg = '31 min: stuck' ).
        cl_abap_unit_assert=>assert_not_initial(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-queue_stuck )
          msg = 'Stuck finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a source that was read measures all four metrics, zero included (evidence of health);
  " bgRFC without a configured source is listed as not monitored, never silently skipped
  METHOD empty_queues_measure_zero.
    TRY.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-metrics ) exp = 8 msg = 'Four metrics x QOUT and QIN' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_sources ) exp = 2 msg = 'Two qRFC sources read' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_sources[ 1 ]-tabname
                                            exp = zif_cd_hck_runtime_types=>gc_trfcqout-tabname
                                            msg = 'Outbound qRFC table' ).
        cl_abap_unit_assert=>assert_equals(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-queue_not_watched )-severity
          exp = zif_ca_ops_types=>gc_severity-info
          msg = 'bgRFC not monitored: information' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'Nothing else reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PARAM1 queue names are PCRE matched to the complete name - other queues are not counted
  METHOD name_filter_applies.
    TRY.
        add_group( iv_state = 'SYSFAIL' ).
        add_group( iv_state = 'SYSFAIL' iv_name = gc_other ).
        DATA(ls_result) = act( iv_names = 'zcd_.*' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_queues=>gc_metric-error )
                                            exp = gc_entries msg = 'Only the payment engine queue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the error states come from HCK_QUEUE_ERR_STATES - a state not listed is not an error
  METHOD states_are_configurable.
    TRY.
        mo_params->set( iv_name = zif_cd_hck_runtime_types=>gc_param-queue_err_states iv_value = 'CPICERR' ).
        add_group( iv_state = 'SYSFAIL' ).
        add_group( iv_state = 'CPICERR' iv_name = gc_other ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_queues=>gc_metric-error )
                                            exp = gc_entries msg = 'Only CPICERR is an error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an unreadable source is a warning and measures nothing; the other sources still run
  METHOD unreadable_source_reported.
    TRY.
        mo_dao->mv_fail_kind = zif_cd_hck_runtime_types=>gc_queue_kind-inbound.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-queue_config )-severity
          exp = zif_ca_ops_types=>gc_severity-warning
          msg = 'Source not read: warning' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ls_result-metrics[ dim1 = zif_cd_hck_runtime_types=>gc_queue_kind-inbound ] ) )
          msg = 'No QIN metric (never zero)' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-metrics[ dim1 = zif_cd_hck_runtime_types=>gc_queue_kind-outbound ] ) )
          msg = 'QOUT still measured' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a configured bgRFC source without STATE field counts every row as an error; its
  " table must be whitelisted (configured flag) and the finding points to SBGRFCMON
  METHOD bgrfc_rows_are_errors.
    TRY.
        add_group( iv_kind = zif_cd_hck_runtime_types=>gc_queue_kind-bgrfc iv_state = space ).
        DATA(ls_result) = act( iv_bgrfc = gc_bgrfc ).
        DATA(ls_source) = mo_dao->mt_sources[ kind = zif_cd_hck_runtime_types=>gc_queue_kind-bgrfc ].
        cl_abap_unit_assert=>assert_equals( act = ls_source-tabname exp = 'ZBGRFC_ERR' msg = 'Configured table' ).
        cl_abap_unit_assert=>assert_equals( act = ls_source-time_field exp = 'ERZEIT' msg = 'Configured time field' ).
        cl_abap_unit_assert=>assert_true( act = ls_source-configured msg = 'Whitelist required' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_queues=>gc_metric-error
                                                          iv_kind   = zif_cd_hck_runtime_types=>gc_queue_kind-bgrfc )
                                            exp = gc_entries msg = 'Every row is an error' ).
        DATA(lv_message) = CONV string( finding( is_result = ls_result
                                                 iv_code   = zif_cd_hck_runtime_types=>gc_code-queue_error )-message ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( find( val = lv_message sub = condense( zif_cd_hck_runtime_types=>gc_queue_tcode-bgrfc ) ) >= 0 )
          msg = 'Look in SBGRFCMON' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a read that reaches HCK_MAX_TECH_ROWS is reported as possibly incomplete
  METHOD read_cap_reported.
    TRY.
        mo_params->set( iv_name = zif_cd_hck_runtime_types=>gc_param-max_tech_rows iv_value = '1' ).
        add_group( iv_state = 'SYSFAIL' ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-read_capped )-reference
          exp = CONV zif_ca_ops_types=>ty_reference( zif_cd_hck_runtime_types=>gc_trfcqout-tabname )
          msg = 'Capped source named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an invalid PCRE in PARAM1 is a configuration error of the check, never 'no match'
  METHOD invalid_pattern_raises.
    TRY.
        act( iv_names = 'ZCD_(' ).
        cl_abap_unit_assert=>fail( msg = 'Invalid pattern must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Configuration error raised' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
