*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_queues.clas.abap
*& Purpose:
*& Technical health: qRFC / bgRFC queues in error or stuck. Reads the
*& outbound (TRFCQOUT, SMQ1) and inbound (TRFCQIN, SMQ2) qRFC entries and,
*& when configured, a bgRFC unit table (SBGRFCMON) grouped per queue,
*& destination, state and day; classifies the states as ERROR, HOLD or -
*& for a waiting state older than the age limit - STUCK. Report only: no
*& queue is restarted, unlocked or deleted; the finding names the
*& transaction support works in.
*& Modification log:
*& 2026-11-07 | Initial version (queue errors, morning report).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - qRFC / bgRFC queues in error or stuck</p>
"! PARAM1 = queue name PCRE list (blank = all), PARAM2 = destination PCRE list (blank =
"! all; sources without destination are not filtered), PARAM3 = minutes after which a
"! waiting state is stuck (default 30), PARAM4 = bgRFC source TABLE=..;NAME=..;DEST=..;
"! STATE=..;DATE=..;TIME=.. (blank = bgRFC not monitored; no STATE = every row is an error).
"! States: HCK_QUEUE_ERR_STATES / _HOLD_STATES / _WAIT_STATES (ZCA_PARAM). Metrics per
"! source (DIM1 QOUT / QIN / BGRF): Q_ERROR, Q_HOLD, Q_STUCK (entries), Q_OLDEST_MIN.
CLASS zcl_cd_hck_c_queues DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS:
      BEGIN OF gc_metric,
        error  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'Q_ERROR',
        hold   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'Q_HOLD',
        stuck  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'Q_STUCK',
        oldest TYPE zif_cd_hck_types=>ty_metric_name VALUE 'Q_OLDEST_MIN',
      END OF gc_metric.

  PRIVATE SECTION.
    TYPES tt_state TYPE SORTED TABLE OF zif_cd_hck_runtime_types=>ty_queue_state WITH UNIQUE KEY table_line.
    TYPES tt_source TYPE STANDARD TABLE OF zif_cd_hck_runtime_types=>ty_queue_source WITH EMPTY KEY.

    "! One problem queue (all its days): entries and oldest age
    TYPES:
      BEGIN OF ty_problem,
        name       TYPE zif_cd_hck_runtime_types=>ty_queue_name,
        dest       TYPE zif_cd_hck_runtime_types=>ty_queue_name,
        state      TYPE zif_cd_hck_runtime_types=>ty_queue_state,
        class      TYPE zif_cd_hck_runtime_types=>ty_queue_class,
        entries    TYPE int8,
        oldest_min TYPE i,
      END OF ty_problem.
    TYPES tt_problem TYPE SORTED TABLE OF ty_problem WITH UNIQUE KEY name dest state.

    DATA mt_err_states TYPE tt_state.
    DATA mt_hold_states TYPE tt_state.
    DATA mt_wait_states TYPE tt_state.
    DATA mt_name_patterns TYPE zif_cd_ops_types=>tt_pcre.
    DATA mt_dest_patterns TYPE zif_cd_ops_types=>tt_pcre.
    DATA mv_stuck_min TYPE i.

    METHODS load_config
      IMPORTING
        is_def TYPE zif_cd_hck_types=>ty_check_def
      RAISING
        zcx_cd_ops_error.

    CLASS-METHODS sources
      IMPORTING
        is_def           TYPE zif_cd_hck_types=>ty_check_def
      RETURNING
        VALUE(rt_source) TYPE tt_source.

    METHODS evaluate
      IMPORTING
        is_source  TYPE zif_cd_hck_runtime_types=>ty_queue_source
        it_groups  TYPE zif_cd_hck_runtime_types=>tt_queue_group
        is_def     TYPE zif_cd_hck_types=>ty_check_def
        is_context TYPE zif_cd_hck_types=>ty_context
      CHANGING
        cs_result  TYPE zif_cd_hck_types=>ty_check_result.

    METHODS classify
      IMPORTING
        is_source       TYPE zif_cd_hck_runtime_types=>ty_queue_source
        iv_state        TYPE zif_cd_hck_runtime_types=>ty_queue_state
        iv_age_min      TYPE i
      RETURNING
        VALUE(rv_class) TYPE zif_cd_hck_runtime_types=>ty_queue_class.

    CLASS-METHODS states
      IMPORTING
        iv_name          TYPE zif_cd_ops_types=>ty_param_name
        iv_default       TYPE string
      RETURNING
        VALUE(rt_states) TYPE tt_state.

    CLASS-METHODS tcode
      IMPORTING
        iv_kind         TYPE zif_cd_hck_runtime_types=>ty_queue_kind
      RETURNING
        VALUE(rv_tcode) TYPE zif_cd_hck_runtime_types=>ty_tcode.

ENDCLASS.



CLASS zcl_cd_hck_c_queues IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    load_config( is_def ).
    DATA(lv_cap) = zcl_cd_hck_param=>row_cap( iv_name    = zif_cd_hck_runtime_types=>gc_param-max_tech_rows
                                              iv_default = zif_cd_hck_runtime_types=>gc_param_default-max_tech_rows
                                              iv_ceiling = zif_cd_hck_runtime_types=>gc_max_tech_rows ).
    IF is_def-param4 IS INITIAL.
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ zif_cd_hck_runtime_types=>gc_queue_kind-bgrfc }|
                      check_code = zif_cd_hck_runtime_types=>gc_code-queue_not_watched
                      severity   = zif_cd_ops_types=>gc_severity-info
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-bgrfc_not_watched
                                                          iv_v1    = is_def-check_id ) ) INTO TABLE rs_result-findings.
    ENDIF.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_runtime_dao( ).
    LOOP AT sources( is_def ) ASSIGNING FIELD-SYMBOL(<ls_source>).
      TRY.
          DATA(lt_groups) = lo_dao->get_queue_groups( is_source   = <ls_source>
                                                      iv_max_rows = lv_cap ).
        CATCH zcx_cd_ops_error INTO DATA(lx_error).
          " A source that cannot be read is reported and measures nothing (never zero entries)
          INSERT VALUE #( object_key = |{ is_def-check_id }/{ <ls_source>-kind }|
                          check_code = zif_cd_hck_runtime_types=>gc_code-queue_config
                          severity   = zif_cd_ops_types=>gc_severity-warning
                          action     = zif_cd_ops_types=>gc_action-notify
                          reference  = <ls_source>-tabname
                          message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-queue_source_failed
                                                              iv_v1    = <ls_source>-kind
                                                              iv_v2    = <ls_source>-tabname
                                                              iv_tail  = lx_error->get_text( ) ) )
                 INTO TABLE rs_result-findings.
          CONTINUE.
      ENDTRY.
      IF lines( lt_groups ) >= lv_cap.
        INSERT VALUE #( object_key = |{ is_def-check_id }/{ <ls_source>-kind }|
                        check_code = zif_cd_hck_runtime_types=>gc_code-read_capped
                        severity   = zif_cd_ops_types=>gc_severity-warning
                        action     = zif_cd_ops_types=>gc_action-notify
                        reference  = <ls_source>-tabname
                        message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-read_capped
                                                            iv_v1    = zif_cd_hck_runtime_types=>gc_param-max_tech_rows
                                                            iv_v2    = lv_cap
                                                            iv_v3    = <ls_source>-tabname ) ) INTO TABLE rs_result-findings.
      ENDIF.
      evaluate( EXPORTING is_source  = <ls_source>
                          it_groups  = lt_groups
                          is_def     = is_def
                          is_context = is_context
                CHANGING  cs_result  = rs_result ).
    ENDLOOP.
  ENDMETHOD.


  METHOD load_config.
    mt_name_patterns = zcl_cd_hck_param=>patterns( is_def-param1 ).
    zcl_cd_hck_param=>check_patterns( it_patterns = mt_name_patterns iv_check_id = is_def-check_id ).
    mt_dest_patterns = zcl_cd_hck_param=>patterns( is_def-param2 ).
    zcl_cd_hck_param=>check_patterns( it_patterns = mt_dest_patterns iv_check_id = is_def-check_id ).
    mv_stuck_min = nmax( val1 = 1
                         val2 = zcl_cd_hck_param=>int( iv_value   = is_def-param3
                                                       iv_default = zif_cd_hck_runtime_types=>gc_check_default-queue_stuck_min ) ).
    mt_err_states  = states( iv_name    = zif_cd_hck_runtime_types=>gc_param-queue_err_states
                             iv_default = zif_cd_hck_runtime_types=>gc_param_default-queue_err_states ).
    mt_hold_states = states( iv_name    = zif_cd_hck_runtime_types=>gc_param-queue_hold_states
                             iv_default = zif_cd_hck_runtime_types=>gc_param_default-queue_hold_states ).
    mt_wait_states = states( iv_name    = zif_cd_hck_runtime_types=>gc_param-queue_wait_states
                             iv_default = zif_cd_hck_runtime_types=>gc_param_default-queue_wait_states ).
  ENDMETHOD.


  METHOD sources.
    INSERT VALUE #( kind        = zif_cd_hck_runtime_types=>gc_queue_kind-outbound
                    tabname     = zif_cd_hck_runtime_types=>gc_trfcqout-tabname
                    name_field  = zif_cd_hck_runtime_types=>gc_trfcqout-name_field
                    dest_field  = zif_cd_hck_runtime_types=>gc_trfcqout-dest_field
                    state_field = zif_cd_hck_runtime_types=>gc_trfcqout-state_field
                    date_field  = zif_cd_hck_runtime_types=>gc_trfcqout-date_field
                    time_field  = zif_cd_hck_runtime_types=>gc_trfcqout-time_field ) INTO TABLE rt_source.
    INSERT VALUE #( kind        = zif_cd_hck_runtime_types=>gc_queue_kind-inbound
                    tabname     = zif_cd_hck_runtime_types=>gc_trfcqin-tabname
                    name_field  = zif_cd_hck_runtime_types=>gc_trfcqin-name_field
                    state_field = zif_cd_hck_runtime_types=>gc_trfcqin-state_field
                    date_field  = zif_cd_hck_runtime_types=>gc_trfcqin-date_field
                    time_field  = zif_cd_hck_runtime_types=>gc_trfcqin-time_field ) INTO TABLE rt_source.
    " bgRFC only when its source is configured (PARAM4); the info finding is written by execute
    IF is_def-param4 IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_spec) = zcl_cd_hck_value_query=>parse( is_def-param4 ).
    INSERT VALUE #( kind        = zif_cd_hck_runtime_types=>gc_queue_kind-bgrfc
                    tabname     = zcl_cd_hck_value_query=>value( it_spec = lt_spec iv_name = zif_cd_hck_runtime_types=>gc_spec-table )
                    name_field  = zcl_cd_hck_value_query=>value( it_spec = lt_spec iv_name = zif_cd_hck_runtime_types=>gc_spec-name )
                    dest_field  = zcl_cd_hck_value_query=>value( it_spec = lt_spec iv_name = zif_cd_hck_runtime_types=>gc_spec-dest )
                    state_field = zcl_cd_hck_value_query=>value( it_spec = lt_spec iv_name = zif_cd_hck_runtime_types=>gc_spec-state )
                    date_field  = zcl_cd_hck_value_query=>value( it_spec = lt_spec iv_name = zif_cd_hck_runtime_types=>gc_spec-date )
                    time_field  = zcl_cd_hck_value_query=>value( it_spec = lt_spec iv_name = zif_cd_hck_runtime_types=>gc_spec-time )
                    configured  = abap_true ) INTO TABLE rt_source.
  ENDMETHOD.


  METHOD evaluate.
    DATA lt_problem TYPE tt_problem.
    DATA lv_error TYPE zif_cd_hck_types=>ty_value.
    DATA lv_hold TYPE zif_cd_hck_types=>ty_value.
    DATA lv_stuck TYPE zif_cd_hck_types=>ty_value.
    DATA lv_oldest TYPE i.

    LOOP AT it_groups ASSIGNING FIELD-SYMBOL(<ls_group>).
      IF mt_name_patterns IS NOT INITIAL
         AND zcl_cd_ops_util=>pcre_match_any( iv_value    = condense( <ls_group>-name )
                                              it_patterns = mt_name_patterns ) = abap_false.
        CONTINUE.
      ENDIF.
      IF mt_dest_patterns IS NOT INITIAL AND is_source-dest_field IS NOT INITIAL
         AND zcl_cd_ops_util=>pcre_match_any( iv_value    = condense( <ls_group>-dest )
                                              it_patterns = mt_dest_patterns ) = abap_false.
        CONTINUE.
      ENDIF.
      DATA(lv_state) = CONV zif_cd_hck_runtime_types=>ty_queue_state( to_upper( condense( <ls_group>-state ) ) ).
      DATA(lv_age) = nmax( val1 = 0
                           val2 = zcl_cd_hck_cycle_eval=>minutes_between( iv_from_date = <ls_group>-qdate
                                                                          iv_from_time = <ls_group>-qtime
                                                                          iv_to_date   = is_context-now_date
                                                                          iv_to_time   = is_context-now_time ) ).
      DATA(lv_class) = classify( is_source  = is_source
                                 iv_state   = lv_state
                                 iv_age_min = lv_age ).
      CASE lv_class.
        WHEN zif_cd_hck_runtime_types=>gc_queue_class-error.
          lv_error = lv_error + <ls_group>-entries.
        WHEN zif_cd_hck_runtime_types=>gc_queue_class-hold.
          lv_hold = lv_hold + <ls_group>-entries.
        WHEN zif_cd_hck_runtime_types=>gc_queue_class-stuck.
          lv_stuck = lv_stuck + <ls_group>-entries.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.
      lv_oldest = nmax( val1 = lv_oldest val2 = lv_age ).
      READ TABLE lt_problem ASSIGNING FIELD-SYMBOL(<ls_problem>)
        WITH TABLE KEY name = <ls_group>-name dest = <ls_group>-dest state = lv_state.
      IF sy-subrc <> 0.
        INSERT VALUE #( name = <ls_group>-name dest = <ls_group>-dest state = lv_state class = lv_class )
          INTO TABLE lt_problem ASSIGNING <ls_problem>.
      ENDIF.
      <ls_problem>-entries    = <ls_problem>-entries + <ls_group>-entries.
      <ls_problem>-oldest_min = nmax( val1 = <ls_problem>-oldest_min val2 = lv_age ).
    ENDLOOP.

    " Every source that was read measures all four metrics (zero is evidence, not absence)
    INSERT VALUE #( metric = gc_metric-error dim1 = is_source-kind value = lv_error ) INTO TABLE cs_result-metrics.
    INSERT VALUE #( metric = gc_metric-hold dim1 = is_source-kind value = lv_hold ) INTO TABLE cs_result-metrics.
    INSERT VALUE #( metric = gc_metric-stuck dim1 = is_source-kind value = lv_stuck ) INTO TABLE cs_result-metrics.
    INSERT VALUE #( metric = gc_metric-oldest dim1 = is_source-kind value = lv_oldest
                    kind   = zif_cd_hck_types=>gc_metric_kind-level ) INTO TABLE cs_result-metrics.

    LOOP AT lt_problem ASSIGNING <ls_problem>.
      INSERT VALUE #( object_key = |{ is_def-check_id }/{ is_source-kind }/{ <ls_problem>-name }/{ <ls_problem>-dest }|
                      check_code = SWITCH #( <ls_problem>-class
                                             WHEN zif_cd_hck_runtime_types=>gc_queue_class-error
                                             THEN zif_cd_hck_runtime_types=>gc_code-queue_error
                                             WHEN zif_cd_hck_runtime_types=>gc_queue_class-hold
                                             THEN zif_cd_hck_runtime_types=>gc_code-queue_hold
                                             ELSE zif_cd_hck_runtime_types=>gc_code-queue_stuck )
                      severity   = COND #( WHEN <ls_problem>-class = zif_cd_hck_runtime_types=>gc_queue_class-error
                                           THEN zif_cd_ops_types=>gc_severity-error
                                           ELSE zif_cd_ops_types=>gc_severity-warning )
                      action     = zif_cd_ops_types=>gc_action-notify
                      reference  = <ls_problem>-name
                      message    = zcl_cd_ops_util=>text(
                                     iv_msgno = zif_cd_hck_runtime_types=>gc_msg-queue_group
                                     iv_v1    = is_source-kind
                                     iv_v2    = condense( <ls_problem>-name )
                                     iv_v3    = condense( <ls_problem>-dest )
                                     iv_v4    = <ls_problem>-state
                                     iv_tail  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-queue_detail
                                                                      iv_v1    = <ls_problem>-entries
                                                                      iv_v2    = <ls_problem>-oldest_min
                                                                      iv_v3    = tcode( is_source-kind ) ) ) )
             INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD classify.
    " A configured source without a state field lists errors only (e.g. a bgRFC error table)
    IF is_source-state_field IS INITIAL OR line_exists( mt_err_states[ table_line = iv_state ] ).
      rv_class = zif_cd_hck_runtime_types=>gc_queue_class-error.
    ELSEIF line_exists( mt_hold_states[ table_line = iv_state ] ).
      rv_class = zif_cd_hck_runtime_types=>gc_queue_class-hold.
    ELSEIF line_exists( mt_wait_states[ table_line = iv_state ] ) AND iv_age_min > mv_stuck_min.
      rv_class = zif_cd_hck_runtime_types=>gc_queue_class-stuck.
    ENDIF.
  ENDMETHOD.


  METHOD states.
    DATA(lv_list) = zcl_cd_ops_factory=>get_params( )->get_param( iv_name    = iv_name
                                                                  iv_default = iv_default ).
    LOOP AT zcl_cd_ops_util=>split_list( lv_list ) ASSIGNING FIELD-SYMBOL(<lv_state>).
      INSERT CONV zif_cd_hck_runtime_types=>ty_queue_state( to_upper( <lv_state> ) ) INTO TABLE rt_states.
    ENDLOOP.
  ENDMETHOD.


  METHOD tcode.
    rv_tcode = SWITCH #( iv_kind
                         WHEN zif_cd_hck_runtime_types=>gc_queue_kind-outbound THEN zif_cd_hck_runtime_types=>gc_queue_tcode-outbound
                         WHEN zif_cd_hck_runtime_types=>gc_queue_kind-inbound  THEN zif_cd_hck_runtime_types=>gc_queue_tcode-inbound
                         ELSE zif_cd_hck_runtime_types=>gc_queue_tcode-bgrfc ).
  ENDMETHOD.

ENDCLASS.
