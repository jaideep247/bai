*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_check_runner.clas.abap
*& Purpose:
*& Generic runner of the check registry: one run of an area and schedule
*& group (run variant) - authorisation ZCA_OPS execute (16) for the area,
*& run lock (a second run is refused, RUN_LOCKED), run header durable before
*& anything else, every active registered check of the area and group in
*& sequence (class by name, ZIF_CA_OPS_CHECK checked by RTTI first), GROUP1
*& = process ID and GROUP2 = check ID stamped on every finding, a check that
*& raises = one CHECK_FAILED finding and the run continues, findings stored
*& (B / E / W = owned exceptions with SLA), earlier exceptions of every
*& complete check that it no longer raises auto-resolved (reconcile by
*& GROUP2), run closed and committed, then the alert rules of the area. A
*& store error closes the run as aborted (ZCL_CA_OPS_RUN_GUARD) and is
*& re-raised. Test mode: nothing is written, no alert is sent.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - generic check runner</p>
"! Report ZCA_OPS_CHECK_RUN (one job per area and schedule group). No check, no business table
"! and no configuration is written here: results only through the store.
CLASS zcl_ca_ops_check_runner DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! One run of the registered checks of an area and schedule group
    "! @raising zcx_ca_ops_error | 041 not authorised, 042 lock service, 043 / 044 area or release,
    "! store errors (the run is closed as aborted first)
    METHODS run
      IMPORTING
        iv_area          TYPE zif_ca_ops_types=>ty_area
        iv_sched_group   TYPE zif_ca_ops_chk_types=>ty_sched_group OPTIONAL
        iv_test_mode     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_run_result
      RAISING
        zcx_ca_ops_error.

  PRIVATE SECTION.
    "! The run under the lock taken by RUN
    METHODS execute
      IMPORTING
        iv_area          TYPE zif_ca_ops_types=>ty_area
        iv_sched_group   TYPE zif_ca_ops_chk_types=>ty_sched_group
        iv_test_mode     TYPE abap_bool
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_run_result
      RAISING
        zcx_ca_ops_error.

    "! One check, guarded: a check that raises is a CHECK_FAILED finding and partial
    METHODS run_check
      IMPORTING
        is_check         TYPE zif_ca_ops_chk_types=>ty_check
        is_context       TYPE zif_ca_ops_chk_types=>ty_context
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result.

    METHODS failed
      IMPORTING
        is_check          TYPE zif_ca_ops_chk_types=>ty_check
        ix_error          TYPE REF TO cx_root
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! The identity of the check on its findings: GROUP1 process, GROUP2 check; defaults for the rest
    METHODS stamp
      IMPORTING
        is_check    TYPE zif_ca_ops_chk_types=>ty_check
      CHANGING
        ct_findings TYPE zif_ca_ops_types=>tt_finding.

    "! Counts, status, RAG and runtime of the finished run
    METHODS close
      IMPORTING
        it_findings TYPE zif_ca_ops_types=>tt_finding
        iv_items    TYPE i
      CHANGING
        cs_run      TYPE zif_ca_ops_types=>ty_run.

    "! Route the alerts of the stored run; a failed dispatch is an ALERT_FAILED finding of the run
    METHODS dispatch
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_run_result
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_check_runner IMPLEMENTATION.

  METHOD run.
    zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                            iv_area     = iv_area ).
    DATA(lo_lock) = zcl_ca_ops_factory=>get_lock( ).
    DATA(lv_variant) = CONV zif_ca_ops_types=>ty_variant( iv_sched_group ).
    IF lo_lock->acquire( EXPORTING iv_area    = iv_area
                                   iv_variant = lv_variant
                         IMPORTING ev_holder  = DATA(lv_holder) ) = abap_false.
      DATA(ls_refusal) = zcl_ca_ops_run_guard=>refuse( iv_area    = iv_area
                                                       iv_variant = lv_variant
                                                       iv_holder  = lv_holder ).
      rs_result-run      = ls_refusal-run.
      rs_result-findings = ls_refusal-findings.
      rs_result-refused  = abap_true.
      RETURN.
    ENDIF.
    TRY.
        rs_result = execute( iv_area        = iv_area
                             iv_sched_group = iv_sched_group
                             iv_test_mode   = iv_test_mode ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        lo_lock->release( iv_area    = iv_area
                          iv_variant = lv_variant ).
        RAISE EXCEPTION lx_error.
    ENDTRY.
    lo_lock->release( iv_area    = iv_area
                      iv_variant = lv_variant ).
  ENDMETHOD.


  METHOD execute.
    DATA lt_groups TYPE zif_ca_ops_types=>tt_group.
    DATA lv_items TYPE i.

    DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
    rs_result-run = lo_store->start_run( iv_area      = iv_area
                                         iv_variant   = CONV #( iv_sched_group )
                                         iv_test_mode = iv_test_mode ).
    " the run header is durable before anything can fail or notify
    lo_store->commit( ).
    TRY.
        DATA(lo_clock) = zcl_ca_ops_factory=>get_clock( ).
        DATA(ls_context) = VALUE zif_ca_ops_chk_types=>ty_context( area        = iv_area
                                                                   sched_group = iv_sched_group
                                                                   run_id      = rs_result-run-run_id
                                                                   test_mode   = iv_test_mode
                                                                   today       = lo_clock->today( )
                                                                   now         = lo_clock->now( ) ).
        DATA(lt_checks) = zcl_ca_ops_factory=>get_check_dao( )->get_checks( iv_area        = iv_area
                                                                           iv_sched_group = iv_sched_group ).
        IF lt_checks IS INITIAL.
          INSERT VALUE #( object_type = zif_ca_ops_chk_types=>gc_object_type-check
                          object_key  = |{ iv_area }/{ iv_sched_group }|
                          rule_id     = zif_ca_ops_chk_types=>gc_rule_id-runner
                          check_code  = zif_ca_ops_chk_types=>gc_code-no_checks
                          severity    = zif_ca_ops_types=>gc_severity-error
                          action      = zif_ca_ops_types=>gc_action-notify
                          message     = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_chk_types=>gc_msg-no_checks
                                                               iv_v1    = iv_area
                                                               iv_v2    = iv_sched_group ) )
                 INTO TABLE rs_result-findings.
        ENDIF.

        LOOP AT lt_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
          DATA(ls_one) = run_check( is_check   = <ls_check>
                                    is_context = ls_context ).
          INSERT LINES OF ls_one-findings INTO TABLE rs_result-findings.
          lv_items += ls_one-item_count.
          rs_result-check_count += 1.
          " only a complete check may resolve what it no longer raises
          IF ls_one-partial = abap_false.
            INSERT CONV zif_ca_ops_types=>ty_group( <ls_check>-check_id ) INTO TABLE lt_groups.
          ENDIF.
        ENDLOOP.

        lo_store->save_findings( EXPORTING it_findings = rs_result-findings
                                 CHANGING  cs_run      = rs_result-run ).
        IF lt_groups IS NOT INITIAL.
          lo_store->reconcile( is_run    = rs_result-run
                               it_groups = lt_groups ).
        ENDIF.
        close( EXPORTING it_findings = rs_result-findings
                         iv_items    = lv_items
               CHANGING  cs_run      = rs_result-run ).
        lo_store->finish_run( rs_result-run ).
        lo_store->commit( ).
        dispatch( CHANGING cs_result = rs_result ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        INSERT LINES OF zcl_ca_ops_run_guard=>abort( EXPORTING ix_error = lx_error
                                                     CHANGING  cs_run   = rs_result-run ) INTO TABLE rs_result-findings.
        RAISE EXCEPTION lx_error.
    ENDTRY.
  ENDMETHOD.


  METHOD run_check.
    TRY.
        " the factory checks the interface by RTTI before the class is created (message 032)
        rs_result = CAST zif_ca_ops_check( zcl_ca_ops_factory=>get_plugin(
                      iv_class_name = is_check-class_name
                      iv_interface  = zif_ca_ops_chk_types=>gc_check_intf ) )->run( is_check   = is_check
                                                                                   is_context = is_context ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        CLEAR rs_result.
        rs_result-partial = abap_true.
        INSERT failed( is_check = is_check
                       ix_error = lx_error ) INTO TABLE rs_result-findings.
      CATCH cx_root INTO DATA(lx_root).
        CLEAR rs_result.
        rs_result-partial = abap_true.
        INSERT failed( is_check = is_check
                       ix_error = lx_root ) INTO TABLE rs_result-findings.
    ENDTRY.
    stamp( EXPORTING is_check    = is_check
           CHANGING  ct_findings = rs_result-findings ).
  ENDMETHOD.


  METHOD failed.
    rs_finding = VALUE #( object_type = zif_ca_ops_chk_types=>gc_object_type-check
                          object_key  = is_check-check_id
                          rule_id     = zif_ca_ops_chk_types=>gc_rule_id-runner
                          check_code  = zif_ca_ops_chk_types=>gc_code-check_failed
                          severity    = zif_ca_ops_types=>gc_severity-error
                          action      = zif_ca_ops_types=>gc_action-notify
                          reference   = is_check-class_name
                          message     = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_chk_types=>gc_msg-check_failed
                                                               iv_v1    = is_check-check_id
                                                               iv_v2    = is_check-area
                                                               iv_tail  = ix_error->get_text( ) )
                          details     = zcl_ca_ops_util=>exception_trace( ix_error )
                          error_class = zcl_ca_ops_util=>error_class( ix_error ) ).
  ENDMETHOD.


  METHOD stamp.
    LOOP AT ct_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      <ls_finding>-group1 = is_check-process_id.
      <ls_finding>-group2 = is_check-check_id.
      IF <ls_finding>-object_type IS INITIAL.
        <ls_finding>-object_type = zif_ca_ops_chk_types=>gc_object_type-check.
      ENDIF.
      IF <ls_finding>-object_key IS INITIAL.
        <ls_finding>-object_key = is_check-check_id.
      ENDIF.
      IF <ls_finding>-action IS INITIAL.
        <ls_finding>-action = COND #( WHEN <ls_finding>-severity = zif_ca_ops_types=>gc_severity-info
                                      THEN zif_ca_ops_types=>gc_action-notify
                                      ELSE zif_ca_ops_types=>gc_action-exception ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD close.
    DATA(lv_rank) = zcl_ca_ops_util=>severity_rank( zcl_ca_ops_util=>worst_severity( it_findings ) ).
    cs_run-total_items = iv_items.
    CLEAR: cs_run-failed_items, cs_run-warning_items.
    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      CASE <ls_finding>-severity.
        WHEN zif_ca_ops_types=>gc_severity-error OR zif_ca_ops_types=>gc_severity-block.
          cs_run-failed_items += 1.
        WHEN zif_ca_ops_types=>gc_severity-warning.
          cs_run-warning_items += 1.
      ENDCASE.
    ENDLOOP.
    cs_run-rag          = zcl_ca_ops_util=>rag_from_findings( it_findings ).
    cs_run-status        = COND #( WHEN lv_rank >= 3 THEN zif_ca_ops_types=>gc_run_status-error
                                   WHEN lv_rank = 2  THEN zif_ca_ops_types=>gc_run_status-warning
                                   ELSE zif_ca_ops_types=>gc_run_status-success ).
    cs_run-ended_at      = zcl_ca_ops_factory=>get_clock( )->now( ).
    cs_run-runtime_ms    = zcl_ca_ops_util=>elapsed_ms( iv_from = cs_run-started_at
                                                        iv_to   = cs_run-ended_at ).
  ENDMETHOD.


  METHOD dispatch.
    TRY.
        " the alert rules of the area (and of *) decide who hears about it; none in test mode
        zcl_ca_ops_factory=>get_alert( )->dispatch( is_run      = cs_result-run
                                                    it_findings = cs_result-findings ).
      CATCH zcx_ca_ops_error INTO DATA(lx_alert).
        DATA(lt_failed) = VALUE zif_ca_ops_types=>tt_finding(
                            ( zcl_ca_ops_run_guard=>alert_failed( is_run   = cs_result-run
                                                                  ix_error = lx_alert ) ) ).
        INSERT LINES OF lt_failed INTO TABLE cs_result-findings.
        DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
        lo_store->save_findings( EXPORTING it_findings = lt_failed
                                 CHANGING  cs_run      = cs_result-run ).
        lo_store->finish_run( cs_result-run ).
        lo_store->commit( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
