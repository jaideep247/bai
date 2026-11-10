*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_run_guard.clas.abap
*& Purpose:
*& What a run does when it cannot run or cannot finish:
*&  - refuse: the run lock is held by another run - nothing is validated or
*&    persisted; the result is an aborted, red run with one RUN_LOCKED finding
*&    (message 040), dispatched once through the alert router (rule pattern
*&    RUN_LOCKED) and committed (this method owns that small LUW). Reports
*&    recognise it with was_refused( ).
*&  - abort: a technical error stopped a started run - the open LUW is rolled
*&    back, the run is closed as aborted (red) with one RUN_ABORTED finding that
*&    carries the exception trace and error class, committed, then dispatched
*&    (ON_ABORT rules). The caller re-raises, so the batch job ends cancelled.
*& An alert dispatch that fails adds an ALERT_FAILED finding (never swallowed).
*& Modification log:
*& 2026-11-06 | Initial version (run lock).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCA_OPS messages (phase 5).
*& 2026-11-10 | abort( ) for the run boundary of the engines; refuse commits after its dispatch;
*&            | ALERT_FAILED finding when the dispatch fails (was swallowed).
*& 2026-11-10 | Moved from ZCL_CD_OPS_RUN_GUARD to the reusable framework ZCA_OPS.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - refused run (run lock held)</p>
CLASS zcl_ca_ops_run_guard DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS gc_check_code TYPE zif_ca_ops_types=>ty_check_code VALUE 'RUN_LOCKED'.
    CONSTANTS gc_object_type TYPE zif_ca_ops_types=>ty_object_type VALUE 'RUN'.
    CONSTANTS gc_rule_id TYPE zif_ca_ops_types=>ty_rule_id VALUE 'LOCK'.
    "! A started run stopped by a technical error (abort)
    CONSTANTS gc_check_aborted TYPE zif_ca_ops_types=>ty_check_code VALUE 'RUN_ABORTED'.
    CONSTANTS gc_rule_aborted TYPE zif_ca_ops_types=>ty_rule_id VALUE 'RUN'.
    "! The alert router could not be run for the refused / aborted run
    CONSTANTS gc_check_alert_failed TYPE zif_ca_ops_types=>ty_check_code VALUE 'ALERT_FAILED'.

    TYPES:
      BEGIN OF ty_refusal,
        run      TYPE zif_ca_ops_types=>ty_run,
        findings TYPE zif_ca_ops_types=>tt_finding,
      END OF ty_refusal.

    "! Build the refused run and alert it (alert failures are swallowed: the
    "! refusal is still returned to the caller and shown by the report)
    CLASS-METHODS refuse
      IMPORTING
        iv_area         TYPE zif_ca_ops_types=>ty_area
        iv_variant        TYPE zif_ca_ops_types=>ty_variant
        iv_holder         TYPE syuname
      RETURNING
        VALUE(rs_refusal) TYPE ty_refusal.

    "! Close a started run that a technical error stopped: rollback, run aborted (red) with
    "! one RUN_ABORTED finding (trace in DETAILS, error class), finish_run + commit, then the
    "! alert router (ON_ABORT). Returns the findings written; the caller re-raises ix_error.
    "! A store that fails again leaves the run in status R (stale-run check, audit A06).
    CLASS-METHODS abort
      IMPORTING
        ix_error           TYPE REF TO cx_root
      CHANGING
        cs_run             TYPE zif_ca_ops_types=>ty_run
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

    "! ALERT_FAILED finding of a run whose alert dispatch raised (trace in DETAILS)
    CLASS-METHODS alert_failed
      IMPORTING
        is_run            TYPE zif_ca_ops_types=>ty_run
        ix_error          TYPE REF TO cx_root
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    CLASS-METHODS was_refused
      IMPORTING
        it_findings       TYPE zif_ca_ops_types=>tt_finding
      RETURNING
        VALUE(rv_refused) TYPE abap_bool.

ENDCLASS.



CLASS zcl_ca_ops_run_guard IMPLEMENTATION.

  METHOD refuse.
    DATA lv_text TYPE zif_ca_ops_types=>ty_message.

    MESSAGE e040(zca_ops) WITH iv_area iv_variant iv_holder INTO lv_text.

    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    TRY.
        rs_refusal-run-run_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        " The refusal is still reported; only the alert log loses its run reference
        CLEAR rs_refusal-run-run_id.
    ENDTRY.
    rs_refusal-run-area        = iv_area.
    rs_refusal-run-variant       = iv_variant.
    rs_refusal-run-started_at    = lv_now.
    rs_refusal-run-ended_at      = lv_now.
    rs_refusal-run-status        = zif_ca_ops_types=>gc_run_status-aborted.
    rs_refusal-run-rag           = zif_ca_ops_types=>gc_rag-red.
    rs_refusal-run-finding_count = 1.
    rs_refusal-run-message       = lv_text.
    rs_refusal-run-created_by    = sy-uname.

    INSERT VALUE #( object_type = gc_object_type
                    object_key  = |{ iv_area }/{ iv_variant }|
                    group1      = iv_area
                    rule_id     = gc_rule_id
                    check_code  = gc_check_code
                    severity    = zif_ca_ops_types=>gc_severity-error
                    action      = zif_ca_ops_types=>gc_action-notify
                    reference   = iv_holder
                    message     = lv_text ) INTO TABLE rs_refusal-findings.

    TRY.
        zcl_ca_ops_factory=>get_alert( )->dispatch( is_run      = rs_refusal-run
                                                    it_findings = rs_refusal-findings ).
      CATCH zcx_ca_ops_error INTO DATA(lx_alert).
        " the report shows it next to message 040 (the refused run is not persisted)
        INSERT alert_failed( is_run = rs_refusal-run ix_error = lx_alert ) INTO TABLE rs_refusal-findings.
    ENDTRY.
    " This method owns the small LUW of the refusal: the alert decision log is durable
    " before the batch job ends with an error message
    zcl_ca_ops_factory=>get_store( )->commit( ).
  ENDMETHOD.


  METHOD abort.
    DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
    IF cs_run-test_mode = abap_false.
      lo_store->rollback( ).
    ENDIF.
    DATA(ls_finding) = VALUE zif_ca_ops_types=>ty_finding(
      object_type = gc_object_type
      object_key  = |{ cs_run-area }/{ cs_run-variant }|
      group1      = cs_run-area
      rule_id     = gc_rule_aborted
      check_code  = gc_check_aborted
      severity    = zif_ca_ops_types=>gc_severity-error
      action      = zif_ca_ops_types=>gc_action-notify
      message     = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-run_aborted
                                           iv_v1    = cs_run-area
                                           iv_v2    = cs_run-variant
                                           iv_tail  = ix_error->get_text( ) )
      details     = zcl_ca_ops_util=>exception_trace( ix_error )
      error_class = zcl_ca_ops_util=>error_class( ix_error ) ).
    INSERT ls_finding INTO TABLE rt_findings.

    cs_run-status     = zif_ca_ops_types=>gc_run_status-aborted.
    cs_run-rag        = zif_ca_ops_types=>gc_rag-red.
    cs_run-ended_at   = zcl_ca_ops_factory=>get_clock( )->now( ).
    cs_run-runtime_ms = zcl_ca_ops_util=>elapsed_ms( iv_from = cs_run-started_at iv_to = cs_run-ended_at ).
    cs_run-message    = ls_finding-message.
    TRY.
        lo_store->save_findings( EXPORTING it_findings = rt_findings CHANGING cs_run = cs_run ).
        lo_store->finish_run( cs_run ).
        IF cs_run-test_mode = abap_false.
          lo_store->commit( ).
        ENDIF.
      CATCH zcx_ca_ops_error cx_sy_open_sql_db INTO DATA(lx_store).
        " The store failed again: nothing more can be recorded here - the run stays in status R
        " and the stale-run check reports it (A06); the caller re-raises the original error
        lo_store->rollback( ).
        ls_finding-details = |{ ls_finding-details }{ cl_abap_char_utilities=>newline }|
                          && zcl_ca_ops_util=>exception_trace( lx_store ).
        MODIFY rt_findings FROM ls_finding INDEX 1 TRANSPORTING details.
        RETURN.
    ENDTRY.
    IF cs_run-test_mode = abap_true.
      RETURN.
    ENDIF.
    TRY.
        zcl_ca_ops_factory=>get_alert( )->dispatch( is_run      = cs_run
                                                    it_findings = rt_findings ).
      CATCH zcx_ca_ops_error INTO DATA(lx_alert).
        DATA(lt_alert) = VALUE zif_ca_ops_types=>tt_finding( ( alert_failed( is_run = cs_run ix_error = lx_alert ) ) ).
        INSERT LINES OF lt_alert INTO TABLE rt_findings.
        TRY.
            lo_store->save_findings( EXPORTING it_findings = lt_alert CHANGING cs_run = cs_run ).
            lo_store->finish_run( cs_run ).
            lo_store->commit( ).
          CATCH zcx_ca_ops_error cx_sy_open_sql_db.
            " the ALERT_FAILED finding still reaches the caller (job log / report)
            lo_store->rollback( ).
        ENDTRY.
    ENDTRY.
  ENDMETHOD.


  METHOD alert_failed.
    rs_finding = VALUE #( object_type = gc_object_type
                          object_key  = |{ is_run-area }/{ is_run-variant }|
                          group1      = is_run-area
                          rule_id     = gc_rule_aborted
                          check_code  = gc_check_alert_failed
                          severity    = zif_ca_ops_types=>gc_severity-warning
                          action      = zif_ca_ops_types=>gc_action-notify
                          message     = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-alert_dispatch_failed
                                                               iv_v1    = is_run-area
                                                               iv_tail  = ix_error->get_text( ) )
                          details     = zcl_ca_ops_util=>exception_trace( ix_error )
                          error_class = zcl_ca_ops_util=>error_class( ix_error ) ).
  ENDMETHOD.


  METHOD was_refused.
    rv_refused = xsdbool( line_exists( it_findings[ check_code = gc_check_code ] ) ).
  ENDMETHOD.

ENDCLASS.
