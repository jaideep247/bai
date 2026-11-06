*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_engine.clas.abap
*& Purpose:
*& EBS validation engine (chain of responsibility): BTC resolution (R14, zero
*& suspense) -> statement checks -> line rules per rule group, all resolved
*& from customizing. Works on any source (bank file or FEBKO/FEBEP), persists
*& findings through the core store per package, has a circuit breaker and
*& hands the run to the alert router. validate_for_posting( ) is the
*& pre-posting entry for BAdI FIEB_CHANGE_BS_DATA, governed by the TVARVC kill
*& switch ZCD_EBS_VALIDATION_MODE (E enforce / M monitor / O off).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Findings kept in memory capped at EBS_RESULT_MAX; RAG accumulated per package (review 3.5).
*& 2026-11-06 | Fail closed: PLUGIN_ERROR and VALIDATION_ERROR have action BLOCK; validate_for_posting never raises.
*& 2026-11-06 | Run lock per variant (refused run when held); body moved to execute( ).
*& 2026-11-06 | Exception carry-forward: each package's lines and statements reconciled.
*& 2026-11-06 | Posting gate honours approved blocked-line releases (design 6.2).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A03: configuration gaps (unusable assignment, group without usable rule) block; NONE rows skipped.
*& 2026-11-06 | Audit A27/A86: package (parser) findings honour the blocks-posting flag of their rule.
*& 2026-11-06 | Audit A66/A67/A68: unevaluated lines, technical breaker; alerts over complete summaries;
*&            | exact line cap; NO_DATA run.
*& 2026-11-06 | Audit A85: typed posting disposition per line (BLOCK > NOT_POSTED > EXCEPTION > ON_ACCOUNT > AUTO_POST).
*& 2026-11-06 | In-flight grace: AWAITING_LOT_TRANSFER lines are EXCEPTION in the posting disposition.
*& 2026-11-06 | Audit A62/A64: rule plug-ins created with interface check; parameter snapshot refreshed per posting check.
*& 2026-11-06 | Audit A91: kill switch read failure / missing / invalid value -> MONITOR with KILL_SWITCH_FALLBACK diagnostic.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - engine</p>
CLASS zcl_cd_ebs_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_mode TYPE c LENGTH 1.

    CONSTANTS:
      BEGIN OF gc_mode,
        enforce TYPE ty_mode VALUE 'E',
        monitor TYPE ty_mode VALUE 'M',
        off     TYPE ty_mode VALUE 'O',
      END OF gc_mode.

    CONSTANTS:
      BEGIN OF gc_check_code,
        plugin_error     TYPE zif_cd_ops_types=>ty_check_code VALUE 'PLUGIN_ERROR',
        validation_error TYPE zif_cd_ops_types=>ty_check_code VALUE 'VALIDATION_ERROR',
      END OF gc_check_code.

    "! TVARVC kill switch (type P, NUMB 0000)
    CONSTANTS gc_switch_name TYPE c LENGTH 30 VALUE 'ZCD_EBS_VALIDATION_MODE'.

    "! A68: run status of a run that selected no statement (RAG grey). The core run status
    "! list has no such value yet - merge note in docs/Audit_Response_EBS.md
    CONSTANTS gc_status_no_data TYPE zif_cd_ops_types=>ty_run_status VALUE 'N'.

    TYPES:
      BEGIN OF ty_result,
        run         TYPE zif_cd_ops_types=>ty_run,
        "! Retained findings (EBS_RESULT_MAX); every finding is saved and alerted on
        findings    TYPE zif_cd_ops_types=>tt_finding,
        "! Retained lines, exactly EBS_RESULT_MAX at most
        lines       TYPE zif_cd_ebs_types=>tt_line,
        "! A66: lines not evaluated because a rule of their group could not run
        unevaluated TYPE i,
      END OF ty_result.

    "! A85: posting disposition of one line - AUTO_POST, EXCEPTION, ON_ACCOUNT, BLOCK or
    "! NOT_POSTED. Precedence BLOCK > NOT_POSTED > EXCEPTION > ON_ACCOUNT > AUTO_POST
    "! (docs/EBS_VALIDATION.md, section 'Posting disposition')
    TYPES:
      BEGIN OF ty_disposition,
        line_key    TYPE zif_cd_ops_types=>ty_object_key,
        stmt_key    TYPE zif_cd_ebs_types=>ty_stmt_key,
        line_no     TYPE i,
        disposition TYPE zif_cd_ops_types=>ty_action,
      END OF ty_disposition.
    TYPES tt_disposition TYPE SORTED TABLE OF ty_disposition WITH UNIQUE KEY line_key.

    TYPES:
      BEGIN OF ty_decision,
        block        TYPE abap_bool,
        findings     TYPE zif_cd_ops_types=>tt_finding,
        package      TYPE zif_cd_ebs_types=>ty_package,
        "! A85: one disposition per line (empty in mode OFF)
        dispositions TYPE tt_disposition,
      END OF ty_decision.

    "! Validate every package of a source and persist the run (unless test mode)
    METHODS run
      IMPORTING
        io_source        TYPE REF TO zif_cd_ebs_source
        iv_variant       TYPE zif_cd_ops_types=>ty_variant OPTIONAL
        iv_test_mode     TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_cd_ops_error.

    "! Validate one package in memory (no persistence). Lines come back enriched.
    METHODS validate_package
      CHANGING
        cs_package         TYPE zif_cd_ebs_types=>ty_package
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding
      RAISING
        zcx_cd_ops_error.

    "! Pre-posting decision for the BAdI. iv_mode comes from read_mode( ).
    "! Never raises: validation that cannot run is a VALIDATION_ERROR finding
    "! with action BLOCK (fail closed in enforce mode).
    METHODS validate_for_posting
      IMPORTING
        iv_mode            TYPE ty_mode
        is_package         TYPE zif_cd_ebs_types=>ty_package
      RETURNING
        VALUE(rs_decision) TYPE ty_decision.

    "! Block posting? Only in enforce mode, on a B finding or an action BLOCK.
    CLASS-METHODS must_block
      IMPORTING
        iv_mode         TYPE ty_mode
        it_findings     TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rv_block) TYPE abap_bool.

    "! Kill switch. Read directly (no factory, no cache) so the emergency path
    "! depends only on this class and one TVARVC row. A91: a missing row, a value that is
    "! not E / M / O, or a failed read (database error) gives MONITOR and an operational
    "! diagnostic in es_diagnostic (KILL_SWITCH_FALLBACK, W) for the caller to log.
    CLASS-METHODS read_mode
      EXPORTING
        es_diagnostic  TYPE zif_cd_ops_types=>ty_finding
      RETURNING
        VALUE(rv_mode) TYPE ty_mode.

  PRIVATE SECTION.
    "! A85: disposition per line from the released findings (line, statement and package
    "! scope), the map row (NOT_POSTED, action) and the mode. A finding contributes BLOCK
    "! (severity B or action BLOCK - the A27 flag sets the latter), EXCEPTION (action
    "! EXCEPTION, or blank action with severity E) or ON_ACCOUNT (its action); NOTIFY and
    "! released findings contribute nothing; AWAITING_LOT_TRANSFER (in-flight grace) is
    "! EXCEPTION, never AUTO_POST. Outside ENFORCE a BLOCK becomes EXCEPTION.
    METHODS dispositions
      IMPORTING
        iv_mode                TYPE ty_mode
        is_package             TYPE zif_cd_ebs_types=>ty_package
        it_findings            TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rt_dispositions) TYPE tt_disposition.

    "! A85: what one finding contributes to the disposition of the lines in its scope
    CLASS-METHODS finding_disposition
      IMPORTING
        is_finding            TYPE zif_cd_ops_types=>ty_finding
      RETURNING
        VALUE(rv_disposition) TYPE zif_cd_ops_types=>ty_action.

    "! A85: the stronger of two dispositions by precedence
    CLASS-METHODS stronger
      IMPORTING
        iv_current            TYPE zif_cd_ops_types=>ty_action
        iv_candidate          TYPE zif_cd_ops_types=>ty_action
      RETURNING
        VALUE(rv_disposition) TYPE zif_cd_ops_types=>ty_action.

    CLASS-METHODS disposition_rank
      IMPORTING
        iv_disposition TYPE zif_cd_ops_types=>ty_action
      RETURNING
        VALUE(rv_rank) TYPE i.

    "! A91: diagnostic of a kill-switch fallback to MONITOR
    CLASS-METHODS mode_fallback
      IMPORTING
        iv_reason            TYPE clike
      RETURNING
        VALUE(rs_diagnostic) TYPE zif_cd_ops_types=>ty_finding.

    "! Approved blocked-line releases applied to the findings of a posting check
    METHODS apply_releases
      IMPORTING
        it_findings        TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

    "! The run itself, under the run lock taken by run( )
    METHODS execute
      IMPORTING
        io_source        TYPE REF TO zif_cd_ebs_source
        iv_variant       TYPE zif_cd_ops_types=>ty_variant
        iv_test_mode     TYPE abap_bool
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_cd_ops_error.

    METHODS release_lock
      IMPORTING
        iv_variant   TYPE zif_cd_ops_types=>ty_variant
        iv_test_mode TYPE abap_bool.

    "! Resolve open exceptions of earlier runs for the package's lines and
    "! statements that passed now. Skipped when a rule could not run.
    METHODS reconcile_package
      IMPORTING
        is_run      TYPE zif_cd_ops_types=>ty_run
        is_package  TYPE zif_cd_ebs_types=>ty_package
        it_findings TYPE zif_cd_ops_types=>tt_finding
      RAISING
        zcx_cd_ops_error.

    TYPES:
      BEGIN OF ty_plugin,
        class_name TYPE zif_cd_ops_types=>ty_class_name,
        rule       TYPE REF TO zif_cd_ebs_rule,
      END OF ty_plugin.
    TYPES tt_plugin TYPE HASHED TABLE OF ty_plugin WITH UNIQUE KEY class_name.

    DATA mo_resolver     TYPE REF TO zcl_cd_ebs_btc_resolver.
    DATA mt_rules        TYPE zif_cd_ebs_types=>tt_rule_cfg.
    DATA mt_plugins      TYPE tt_plugin.
    DATA mv_config_ready TYPE abap_bool.

    METHODS load_configuration
      RAISING
        zcx_cd_ops_error.

    "! A03: assignments that cannot run and mapped rule groups without any usable rule
    "! are configuration gaps - one finding with action BLOCK per affected line (or run)
    "! A27/A86: findings that arrive with the package (parser S00/S06/S12) honour the
    "! 'blocks posting' flag of their rule like rule plug-in findings do
    METHODS apply_blocking_flags
      CHANGING
        ct_findings TYPE zif_cd_ops_types=>tt_finding.

    METHODS configuration_gaps
      IMPORTING
        it_lines           TYPE zif_cd_ebs_types=>tt_line
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

    METHODS execute_rule
      IMPORTING
        is_rule            TYPE zif_cd_ebs_types=>ty_rule_cfg
        it_statements      TYPE zif_cd_ebs_types=>tt_statement
        it_lines           TYPE zif_cd_ebs_types=>tt_line
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

    "! Worst severity per line; A66: a line whose rule group (or a '*' rule) had a
    "! PLUGIN_ERROR is not evaluated - counted as failed and in cv_unevaluated, never passed
    METHODS count_lines
      IMPORTING
        it_lines       TYPE zif_cd_ebs_types=>tt_line
        it_findings    TYPE zif_cd_ops_types=>tt_finding
      CHANGING
        cs_run         TYPE zif_cd_ops_types=>ty_run
        cv_unevaluated TYPE i.

    METHODS close_run
      IMPORTING
        iv_rag         TYPE zif_cd_ops_types=>ty_rag
        iv_started     TYPE timestampl
        iv_no_data     TYPE abap_bool DEFAULT abap_false
        iv_unevaluated TYPE i DEFAULT 0
      CHANGING
        cs_run         TYPE zif_cd_ops_types=>ty_run.

    "! A67: one entry per alert-relevant class of finding (rule, check code, groups,
    "! severity, action) with its count and first finding - complete, independent of the
    "! EBS_RESULT_MAX display cap
    TYPES:
      BEGIN OF ty_summary,
        rule_id    TYPE zif_cd_ops_types=>ty_rule_id,
        check_code TYPE zif_cd_ops_types=>ty_check_code,
        group1     TYPE zif_cd_ops_types=>ty_group,
        group2     TYPE zif_cd_ops_types=>ty_group,
        severity   TYPE zif_cd_ops_types=>ty_severity,
        action     TYPE zif_cd_ops_types=>ty_action,
        count      TYPE i,
        sample     TYPE zif_cd_ops_types=>ty_finding,
      END OF ty_summary.
    TYPES tt_summary TYPE HASHED TABLE OF ty_summary
                     WITH UNIQUE KEY rule_id check_code group1 group2 severity action.

    METHODS summarize
      IMPORTING
        it_findings TYPE zif_cd_ops_types=>tt_finding
      CHANGING
        ct_summary  TYPE tt_summary.

    "! A67: the findings handed to the alert router - the retained ones plus one sample of
    "! every summarised class that the cap cut off, so every alert rule sees its match
    METHODS alert_findings
      IMPORTING
        it_kept            TYPE zif_cd_ops_types=>tt_finding
        it_summary         TYPE tt_summary
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

    METHODS int_param
      IMPORTING
        iv_name         TYPE zif_cd_ops_types=>ty_param_name
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

ENDCLASS.



CLASS zcl_cd_ebs_engine IMPLEMENTATION.

  METHOD run.
    DATA lv_holder TYPE syuname.

    IF iv_test_mode = abap_false.
      IF zcl_cd_ops_factory=>get_lock( )->acquire( EXPORTING iv_pe_area  = zif_cd_ops_types=>gc_pe_area-ebs
                                                             iv_variant = iv_variant
                                                   IMPORTING ev_holder  = lv_holder ) = abap_false.
        DATA(ls_refusal) = zcl_cd_ops_run_guard=>refuse( iv_pe_area  = zif_cd_ops_types=>gc_pe_area-ebs
                                                         iv_variant = iv_variant
                                                         iv_holder  = lv_holder ).
        rs_result-run      = ls_refusal-run.
        rs_result-findings = ls_refusal-findings.
        RETURN.
      ENDIF.
    ENDIF.

    TRY.
        rs_result = execute( io_source    = io_source
                             iv_variant   = iv_variant
                             iv_test_mode = iv_test_mode ).
      CLEANUP.
        release_lock( iv_variant = iv_variant iv_test_mode = iv_test_mode ).
    ENDTRY.
    release_lock( iv_variant = iv_variant iv_test_mode = iv_test_mode ).
  ENDMETHOD.


  METHOD reconcile_package.
    DATA lt_scope TYPE zif_cd_ops_types=>tt_object_key.

    IF line_exists( it_findings[ check_code = gc_check_code-plugin_error ] ).
      RETURN.
    ENDIF.
    LOOP AT is_package-statements INTO DATA(ls_statement).
      INSERT CONV zif_cd_ops_types=>ty_object_key( ls_statement-stmt_key ) INTO TABLE lt_scope.
    ENDLOOP.
    LOOP AT is_package-lines INTO DATA(ls_line).
      INSERT zcl_cd_ebs_finding=>line_key( ls_line ) INTO TABLE lt_scope.
    ENDLOOP.
    zcl_cd_ops_factory=>get_store( )->reconcile( is_run         = is_run
                                                 it_object_keys = lt_scope ).
  ENDMETHOD.


  METHOD release_lock.
    IF iv_test_mode = abap_false.
      zcl_cd_ops_factory=>get_lock( )->release( iv_pe_area  = zif_cd_ops_types=>gc_pe_area-ebs
                                                iv_variant = iv_variant ).
    ENDIF.
  ENDMETHOD.


  METHOD execute.
    " Findings kept in memory are capped (EBS_RESULT_MAX); every finding is still saved
    " per package, and the run RAG is accumulated over all of them (review 3.5)
    DATA lt_all_findings TYPE zif_cd_ops_types=>tt_finding.
    DATA lt_summary      TYPE tt_summary.
    DATA lv_run_rag      TYPE zif_cd_ops_types=>ty_rag.
    DATA lv_bad_packages TYPE i.
    DATA lv_statements   TYPE i.

    DATA(lo_store) = zcl_cd_ops_factory=>get_store( ).
    DATA(lv_started) = zcl_cd_ops_factory=>get_clock( )->now( ).
    rs_result-run = lo_store->start_run( iv_pe_area    = zif_cd_ops_types=>gc_pe_area-ebs
                                         iv_variant   = iv_variant
                                         iv_test_mode = iv_test_mode ).
    IF iv_test_mode = abap_false.
      lo_store->commit( ).
    ENDIF.

    DATA(lv_cb_percent)  = int_param( iv_name = 'EBS_CB_FAIL_PCT'  iv_default = 50 ).
    DATA(lv_cb_packages) = int_param( iv_name = 'EBS_CB_PACKAGES'  iv_default = 3 ).
    DATA(lv_cb_min)      = int_param( iv_name = 'EBS_CB_MIN_LINES' iv_default = 20 ).
    DATA(lv_keep_max)    = int_param( iv_name = 'EBS_RESULT_MAX'   iv_default = 100000 ).

    DO.
      DATA(ls_package) = io_source->next_package( ).
      IF ls_package-statements IS INITIAL AND ls_package-lines IS INITIAL AND ls_package-findings IS INITIAL.
        EXIT.
      ENDIF.

      lv_statements += lines( ls_package-statements ).
      DATA(lt_findings) = validate_package( CHANGING cs_package = ls_package ).
      DATA(ls_before) = rs_result-run.
      count_lines( EXPORTING it_lines       = ls_package-lines
                             it_findings    = lt_findings
                   CHANGING  cs_run         = rs_result-run
                             cv_unevaluated = rs_result-unevaluated ).
      summarize( EXPORTING it_findings = lt_findings CHANGING ct_summary = lt_summary ).

      lo_store->save_findings( EXPORTING it_findings = lt_findings CHANGING cs_run = rs_result-run ).
      IF iv_test_mode = abap_false.
        reconcile_package( is_run      = rs_result-run
                           is_package  = ls_package
                           it_findings = lt_findings ).
        lo_store->commit( ).
      ENDIF.
      lv_run_rag = zcl_cd_ops_util=>worse_rag( iv_rag1 = lv_run_rag
                                               iv_rag2 = zcl_cd_ops_util=>rag_from_findings( lt_findings ) ).
      LOOP AT lt_findings INTO DATA(ls_keep) FROM 1 TO lv_keep_max - lines( lt_all_findings ).
        INSERT ls_keep INTO TABLE lt_all_findings.
      ENDLOOP.
      " A67: the retention bound is exact - never a whole package over the cap
      LOOP AT ls_package-lines INTO DATA(ls_keep_line) FROM 1 TO lv_keep_max - lines( rs_result-lines ).
        INSERT ls_keep_line INTO TABLE rs_result-lines.
      ENDLOOP.

      " Circuit breaker: consecutive packages with a failure rate above the limit, or with
      " a technical failure (A66: a rule could not run - its lines are unevaluated)
      DATA(lv_package_lines) = rs_result-run-total_items - ls_before-total_items.
      DATA(lv_package_bad) = ( rs_result-run-failed_items - ls_before-failed_items )
                           + ( rs_result-run-blocked_items - ls_before-blocked_items ).
      DATA(lv_technical) = xsdbool( line_exists( lt_findings[ check_code = gc_check_code-plugin_error ] ) ).
      IF lv_technical = abap_true
         OR (     lv_package_lines >= lv_cb_min AND lv_package_lines > 0
              AND lv_package_bad * 100 > lv_cb_percent * lv_package_lines ).
        lv_bad_packages += 1.
      ELSE.
        CLEAR lv_bad_packages.
      ENDIF.
      IF lv_bad_packages >= lv_cb_packages.
        DATA(ls_breaker) = VALUE zif_cd_ops_types=>ty_finding(
          object_type = zcl_cd_ebs_finding=>gc_object_type-run
          rule_id     = 'CB'
          check_code  = zif_cd_ebs_types=>gc_check_code-circuit_breaker
          severity    = zif_cd_ops_types=>gc_severity-error
          action      = zif_cd_ops_types=>gc_action-notify
          message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-circuit_breaker
                                               iv_v1    = lv_bad_packages
                                               iv_v2    = lv_cb_percent ) ).
        lo_store->save_findings( EXPORTING it_findings = VALUE #( ( ls_breaker ) ) CHANGING cs_run = rs_result-run ).
        INSERT ls_breaker INTO TABLE lt_all_findings.
        summarize( EXPORTING it_findings = VALUE #( ( ls_breaker ) ) CHANGING ct_summary = lt_summary ).
        lv_run_rag = zif_cd_ops_types=>gc_rag-red.
        rs_result-run-status = zif_cd_ops_types=>gc_run_status-aborted.
        EXIT.
      ENDIF.
    ENDDO.

    " A68: a run that selected no statement evaluated nothing - NO_DATA (grey), not green,
    " unless the feed is declared intentionally empty (EBS_EMPTY_FEED_OK = X)
    DATA(lv_no_data) = xsdbool( lv_statements = 0
                                AND rs_result-run-status <> zif_cd_ops_types=>gc_run_status-aborted
                                AND lo_store->get_param( zif_cd_ebs_types=>gc_param-empty_feed_ok ) <> abap_true ).
    IF lv_no_data = abap_true.
      DATA(ls_no_data) = VALUE zif_cd_ops_types=>ty_finding(
        object_type = zcl_cd_ebs_finding=>gc_object_type-run
        object_key  = iv_variant
        rule_id     = zif_cd_ebs_types=>gc_engine-rule_id
        check_code  = zif_cd_ebs_types=>gc_check_code-no_data
        severity    = zif_cd_ops_types=>gc_severity-error
        action      = zif_cd_ops_types=>gc_action-notify
        message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-no_data
                                             iv_v1    = iv_variant ) ).
      lo_store->save_findings( EXPORTING it_findings = VALUE #( ( ls_no_data ) ) CHANGING cs_run = rs_result-run ).
      INSERT ls_no_data INTO TABLE lt_all_findings.
      summarize( EXPORTING it_findings = VALUE #( ( ls_no_data ) ) CHANGING ct_summary = lt_summary ).
    ENDIF.

    close_run( EXPORTING iv_rag         = lv_run_rag
                         iv_started     = lv_started
                         iv_no_data     = lv_no_data
                         iv_unevaluated = rs_result-unevaluated
               CHANGING  cs_run         = rs_result-run ).
    lo_store->finish_run( rs_result-run ).
    IF iv_test_mode = abap_false.
      lo_store->commit( ).
      TRY.
          zcl_cd_ops_factory=>get_alert( )->dispatch( is_run      = rs_result-run
                                                      it_findings = alert_findings( it_kept    = lt_all_findings
                                                                                    it_summary = lt_summary ) ).
        CATCH zcx_cd_ops_error ##NO_HANDLER.
          " Alert configuration unreadable: the run result is already persisted;
          " the morning report's alert-delivery check surfaces the gap.
      ENDTRY.
    ENDIF.
    rs_result-findings = lt_all_findings.
  ENDMETHOD.


  METHOD validate_package.
    load_configuration( ).
    INSERT LINES OF cs_package-findings INTO TABLE rt_findings.
    apply_blocking_flags( CHANGING ct_findings = rt_findings ).

    mo_resolver->enrich_statements( CHANGING ct_statements = cs_package-statements ).
    INSERT LINES OF mo_resolver->resolve( EXPORTING it_statements = cs_package-statements
                                          CHANGING  ct_lines      = cs_package-lines ) INTO TABLE rt_findings.

    " 0. Configuration gaps (A03) - never a silent pass
    INSERT LINES OF configuration_gaps( cs_package-lines ) INTO TABLE rt_findings.

    " 1. Statement checks
    LOOP AT mt_rules INTO DATA(ls_stmt_rule) WHERE level = zif_cd_ebs_types=>gc_level-statement
                                               AND unusable = abap_false.
      INSERT LINES OF execute_rule( is_rule       = ls_stmt_rule
                                    it_statements = cs_package-statements
                                    it_lines      = cs_package-lines ) INTO TABLE rt_findings.
    ENDLOOP.

    " 2. Line rules per rule group; blocked lines are never validated as postable
    DATA(lt_open) = cs_package-lines.
    DELETE lt_open WHERE blocked = abap_true.
    LOOP AT lt_open INTO DATA(ls_group_line) GROUP BY ls_group_line-rule_group INTO DATA(lv_group).
      DATA lt_group_lines TYPE zif_cd_ebs_types=>tt_line.
      CLEAR lt_group_lines.
      LOOP AT GROUP lv_group INTO DATA(ls_member_line).
        INSERT ls_member_line INTO TABLE lt_group_lines.
      ENDLOOP.
      LOOP AT mt_rules INTO DATA(ls_line_rule)
           WHERE level = zif_cd_ebs_types=>gc_level-line
             AND unusable = abap_false
             AND rule_id <> zif_cd_ebs_types=>gc_rule_none
             AND ( rule_group = lv_group OR rule_group = zif_cd_ebs_types=>gc_rule_group_all ).
        INSERT LINES OF execute_rule( is_rule       = ls_line_rule
                                      it_statements = cs_package-statements
                                      it_lines      = lt_group_lines ) INTO TABLE rt_findings.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_for_posting.
    rs_decision-package = is_package.
    IF iv_mode = gc_mode-off.
      RETURN.
    ENDIF.
    " A64: no run is started here, so the parameter snapshot is refreshed once per call
    zcl_cd_ops_factory=>get_store( )->refresh_params( ).
    TRY.
        rs_decision-findings = validate_package( CHANGING cs_package = rs_decision-package ).
      CATCH cx_root INTO DATA(lx_error).
        " Deliberately broad, fail closed: a validation that could not run is never
        " permission to post (enforce mode blocks on action BLOCK)
        INSERT VALUE #( object_type = zcl_cd_ebs_finding=>gc_object_type-run
                        object_key  = zif_cd_ebs_types=>gc_engine-posting_object
                        rule_id     = zif_cd_ebs_types=>gc_engine-rule_id
                        check_code  = gc_check_code-validation_error
                        severity    = zif_cd_ops_types=>gc_severity-error
                        action      = zif_cd_ops_types=>gc_action-block
                        message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-validation_could_not_run
                                                             iv_tail  = lx_error->get_text( ) ) )
          INTO TABLE rs_decision-findings.
    ENDTRY.
    rs_decision-findings = apply_releases( rs_decision-findings ).
    rs_decision-block = must_block( iv_mode = iv_mode it_findings = rs_decision-findings ).
    rs_decision-dispositions = dispositions( iv_mode     = iv_mode
                                             is_package  = rs_decision-package
                                             it_findings = rs_decision-findings ).
  ENDMETHOD.


  METHOD dispositions.
    TYPES:
      BEGIN OF ty_scope,
        object_key  TYPE zif_cd_ops_types=>ty_object_key,
        disposition TYPE zif_cd_ops_types=>ty_action,
      END OF ty_scope.
    TYPES tt_scope TYPE HASHED TABLE OF ty_scope WITH UNIQUE KEY object_key.
    DATA lt_lines TYPE tt_scope.
    DATA lt_statements TYPE tt_scope.
    DATA lv_package TYPE zif_cd_ops_types=>ty_action.

    IF iv_mode = gc_mode-off.
      RETURN.
    ENDIF.
    LOOP AT it_findings INTO DATA(ls_finding).
      DATA(lv_contribution) = finding_disposition( ls_finding ).
      IF lv_contribution IS INITIAL.
        CONTINUE.
      ENDIF.
      CASE ls_finding-object_type.
        WHEN zcl_cd_ebs_finding=>gc_object_type-line.
          READ TABLE lt_lines ASSIGNING FIELD-SYMBOL(<ls_line_scope>) WITH TABLE KEY object_key = ls_finding-object_key.
          IF sy-subrc = 0.
            <ls_line_scope>-disposition = stronger( iv_current = <ls_line_scope>-disposition iv_candidate = lv_contribution ).
          ELSE.
            INSERT VALUE #( object_key = ls_finding-object_key disposition = lv_contribution ) INTO TABLE lt_lines.
          ENDIF.
        WHEN zcl_cd_ebs_finding=>gc_object_type-statement.
          READ TABLE lt_statements ASSIGNING FIELD-SYMBOL(<ls_stmt_scope>) WITH TABLE KEY object_key = ls_finding-object_key.
          IF sy-subrc = 0.
            <ls_stmt_scope>-disposition = stronger( iv_current = <ls_stmt_scope>-disposition iv_candidate = lv_contribution ).
          ELSE.
            INSERT VALUE #( object_key = ls_finding-object_key disposition = lv_contribution ) INTO TABLE lt_statements.
          ENDIF.
        WHEN OTHERS.
          " Run / file: the whole package
          lv_package = stronger( iv_current = lv_package iv_candidate = lv_contribution ).
      ENDCASE.
    ENDLOOP.

    LOOP AT is_package-lines INTO DATA(ls_line).
      DATA(lv_key) = zcl_cd_ebs_finding=>line_key( ls_line ).
      " Map row: AUTO_POST unless it says otherwise
      DATA(lv_disposition) = COND zif_cd_ops_types=>ty_action(
        WHEN ls_line-not_posted = abap_true THEN zif_cd_ebs_types=>gc_disposition-not_posted
        WHEN ls_line-map_action = zif_cd_ops_types=>gc_action-exception
          OR ls_line-map_action = zif_cd_ops_types=>gc_action-on_account THEN ls_line-map_action
        ELSE zif_cd_ops_types=>gc_action-auto_post ).
      " A blocked line whose block was released is still not auto-postable (no usable mapping)
      IF ls_line-blocked = abap_true.
        lv_disposition = stronger( iv_current = lv_disposition iv_candidate = zif_cd_ops_types=>gc_action-exception ).
      ENDIF.
      lv_disposition = stronger( iv_current   = lv_disposition
                                 iv_candidate = VALUE #( lt_lines[ object_key = lv_key ]-disposition OPTIONAL ) ).
      lv_disposition = stronger( iv_current   = lv_disposition
                                 iv_candidate = VALUE #( lt_statements[ object_key = CONV zif_cd_ops_types=>ty_object_key(
                                                                                       ls_line-stmt_key ) ]-disposition OPTIONAL ) ).
      lv_disposition = stronger( iv_current = lv_disposition iv_candidate = lv_package ).
      IF iv_mode <> gc_mode-enforce AND lv_disposition = zif_cd_ops_types=>gc_action-block.
        " Monitor mode never blocks: the line is handed over as an exception
        lv_disposition = zif_cd_ops_types=>gc_action-exception.
      ENDIF.
      INSERT VALUE #( line_key    = lv_key
                      stmt_key    = ls_line-stmt_key
                      line_no     = ls_line-line_no
                      disposition = lv_disposition ) INTO TABLE rt_dispositions.
    ENDLOOP.
  ENDMETHOD.


  METHOD finding_disposition.
    rv_disposition = COND #(
      " In-flight grace: held for the transfer - never auto-posted on a missing lot / payment
      WHEN is_finding-check_code = zif_cd_ebs_types=>gc_check_code-awaiting_lot_transfer
        THEN zif_cd_ops_types=>gc_action-exception
      WHEN is_finding-severity = zif_cd_ops_types=>gc_severity-block
        OR is_finding-action   = zif_cd_ops_types=>gc_action-block      THEN zif_cd_ops_types=>gc_action-block
      WHEN is_finding-action   = zif_cd_ops_types=>gc_action-exception
        OR ( is_finding-action IS INITIAL
             AND is_finding-severity = zif_cd_ops_types=>gc_severity-error ) THEN zif_cd_ops_types=>gc_action-exception
      WHEN is_finding-action   = zif_cd_ops_types=>gc_action-on_account THEN zif_cd_ops_types=>gc_action-on_account ).
  ENDMETHOD.


  METHOD stronger.
    rv_disposition = COND #( WHEN disposition_rank( iv_candidate ) > disposition_rank( iv_current )
                             THEN iv_candidate
                             ELSE iv_current ).
  ENDMETHOD.


  METHOD disposition_rank.
    rv_rank = SWITCH #( iv_disposition
                        WHEN zif_cd_ops_types=>gc_action-block           THEN 5
                        WHEN zif_cd_ebs_types=>gc_disposition-not_posted THEN 4
                        WHEN zif_cd_ops_types=>gc_action-exception       THEN 3
                        WHEN zif_cd_ops_types=>gc_action-on_account      THEN 2
                        WHEN zif_cd_ops_types=>gc_action-auto_post       THEN 1
                        ELSE 0 ).
  ENDMETHOD.


  METHOD apply_releases.
    " Design 6.2: approved releases (second user) turn exactly their line's block into
    " information. A failing lookup changes nothing - the gate stays closed.
    rt_findings = it_findings.
    DATA(lt_keys) = zcl_cd_ebs_release_policy=>releasable_keys( it_findings ).
    CHECK lt_keys IS NOT INITIAL.
    TRY.
        rt_findings = zcl_cd_ebs_release_policy=>apply(
                        it_findings = it_findings
                        it_releases = zcl_cd_ebs_factory=>get_release_dao( )->get_approved( lt_keys ) ).
      CATCH cx_root ##CATCH_ALL ##NO_HANDLER.
        " deliberately broad and silent: without the release data the blocks stand
    ENDTRY.
  ENDMETHOD.


  METHOD must_block.
    IF iv_mode <> gc_mode-enforce.
      RETURN.
    ENDIF.
    rv_block = xsdbool( line_exists( it_findings[ severity = zif_cd_ops_types=>gc_severity-block ] )
                     OR line_exists( it_findings[ action = zif_cd_ops_types=>gc_action-block ] ) ).
  ENDMETHOD.


  METHOD read_mode.
    " Deliberate exception to the DAO rule (engine-redesign kill switch): read
    " straight from TVARVC, bypassing the buffer, in the entry method only.
    DATA lv_low TYPE tvarvc-low.
    DATA lv_subrc TYPE sysubrc.
    CLEAR es_diagnostic.
    rv_mode = gc_mode-monitor.
    TRY.
        TEST-SEAM tvarvc_read.
          SELECT SINGLE low
            FROM tvarvc BYPASSING BUFFER
            WHERE name = @gc_switch_name
              AND type = @zif_cd_ebs_types=>gc_tvarvc-type_parameter
              AND numb = @zif_cd_ebs_types=>gc_tvarvc-numb_single
            INTO @lv_low.
          lv_subrc = sy-subrc.
        END-TEST-SEAM.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        es_diagnostic = mode_fallback( lx_sql->get_text( ) ).
        RETURN.
      CATCH cx_root INTO DATA(lx_error).
        " Deliberately broad: the emergency path must always answer (documented MONITOR)
        es_diagnostic = mode_fallback( lx_error->get_text( ) ).
        RETURN.
    ENDTRY.
    IF lv_subrc <> 0.
      es_diagnostic = mode_fallback( zif_cd_ebs_types=>gc_tvarvc-type_parameter ).
      RETURN.
    ENDIF.
    DATA(lv_value) = condense( CONV string( lv_low ) ).
    IF lv_value = gc_mode-enforce OR lv_value = gc_mode-monitor OR lv_value = gc_mode-off.
      rv_mode = lv_value.
    ELSE.
      es_diagnostic = mode_fallback( lv_value ).
    ENDIF.
  ENDMETHOD.


  METHOD mode_fallback.
    rs_diagnostic = VALUE #( object_type = zcl_cd_ebs_finding=>gc_object_type-run
                             object_key  = gc_switch_name
                             rule_id     = zif_cd_ebs_types=>gc_engine-rule_id
                             check_code  = zif_cd_ebs_types=>gc_check_code-kill_switch_fallback
                             severity    = zif_cd_ops_types=>gc_severity-warning
                             action      = zif_cd_ops_types=>gc_action-notify
                             message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-kill_switch_fallback
                                                                  iv_v1    = gc_switch_name
                                                                  iv_v2    = iv_reason ) ).
  ENDMETHOD.


  METHOD load_configuration.
    IF mv_config_ready = abap_true.
      RETURN.
    ENDIF.
    DATA(lo_cfg) = zcl_cd_ebs_factory=>get_cfg_dao( ).
    DATA(lv_fallback) = zcl_cd_ops_factory=>get_store( )->get_param( iv_name    = 'EBS_CAMT_BAI_FALLBACK'
                                                                    iv_default = `X` ).
    mo_resolver = NEW #( it_map          = lo_cfg->get_btc_map( )
                         it_patterns     = lo_cfg->get_flow_patterns( )
                         it_accounts     = lo_cfg->get_accounts( )
                         iv_bai_fallback = xsdbool( lv_fallback = abap_true ) ).
    mt_rules = lo_cfg->get_rules( ).
    DELETE mt_rules WHERE active = abap_false.
    SORT mt_rules BY level rule_group seq rule_id.
    mv_config_ready = abap_true.
  ENDMETHOD.


  METHOD apply_blocking_flags.
    LOOP AT ct_findings ASSIGNING FIELD-SYMBOL(<ls_finding>) WHERE action IS INITIAL.
      IF line_exists( mt_rules[ rule_id = <ls_finding>-rule_id blocks_posting = abap_true unusable = abap_false ] ).
        <ls_finding>-action = zif_cd_ops_types=>gc_action-block.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD configuration_gaps.
    LOOP AT mt_rules INTO DATA(ls_run_rule) WHERE unusable = abap_true
                                              AND rule_group = zif_cd_ebs_types=>gc_rule_group_all.
      INSERT VALUE #( object_type = zcl_cd_ebs_finding=>gc_object_type-run
                      object_key  = ls_run_rule-rule_id
                      group2      = ls_run_rule-rule_group
                      rule_id     = ls_run_rule-rule_id
                      check_code  = zif_cd_ebs_types=>gc_check_code-rule_unusable
                      severity    = zif_cd_ops_types=>gc_severity-error
                      action      = zif_cd_ops_types=>gc_action-block
                      message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-rule_unusable
                                                           iv_v1    = ls_run_rule-rule_id
                                                           iv_v2    = ls_run_rule-rule_group ) )
        INTO TABLE rt_findings.
    ENDLOOP.

    LOOP AT it_lines INTO DATA(ls_line) WHERE blocked = abap_false.
      IF ls_line-rule_group IS INITIAL OR ls_line-rule_group = zif_cd_ebs_types=>gc_rule_group_all.
        CONTINUE.
      ENDIF.
      LOOP AT mt_rules INTO DATA(ls_rule) WHERE rule_group = ls_line-rule_group AND unusable = abap_true.
        INSERT zcl_cd_ebs_finding=>for_line(
                 is_line       = ls_line
                 iv_rule_id    = ls_rule-rule_id
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-rule_unusable
                 iv_severity   = zif_cd_ops_types=>gc_severity-error
                 iv_action     = zif_cd_ops_types=>gc_action-block
                 iv_message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-rule_unusable
                                                        iv_v1    = ls_rule-rule_id
                                                        iv_v2    = ls_rule-rule_group ) )
          INTO TABLE rt_findings.
      ENDLOOP.
      " a usable rule or an explicit NONE row (group intentionally without own rules)
      IF NOT line_exists( mt_rules[ rule_group = ls_line-rule_group unusable = abap_false ] ).
        INSERT zcl_cd_ebs_finding=>for_line(
                 is_line       = ls_line
                 iv_rule_id    = zif_cd_ebs_types=>gc_engine-rule_id
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-rule_group_empty
                 iv_severity   = zif_cd_ops_types=>gc_severity-error
                 iv_action     = zif_cd_ops_types=>gc_action-block
                 iv_message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-rule_group_empty
                                                        iv_v1    = ls_line-rule_group ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD execute_rule.
    DATA lo_rule TYPE REF TO zif_cd_ebs_rule.
    TRY.
        READ TABLE mt_plugins INTO DATA(ls_plugin) WITH TABLE KEY class_name = is_rule-class_name.
        IF sy-subrc = 0.
          lo_rule = ls_plugin-rule.
        ELSE.
          " A62: the factory checks the interface by RTTI before CREATE OBJECT
          lo_rule = CAST zif_cd_ebs_rule( zcl_cd_ops_factory=>get_plugin(
                                            iv_class_name = is_rule-class_name
                                            iv_interface  = zif_cd_ebs_types=>gc_plugin_interface-rule ) ).
          INSERT VALUE #( class_name = is_rule-class_name rule = lo_rule ) INTO TABLE mt_plugins.
        ENDIF.
        rt_findings = lo_rule->execute( is_rule       = is_rule
                                        it_statements = it_statements
                                        it_lines      = it_lines ).
      CATCH cx_root INTO DATA(lx_error).
        " Deliberately broad: one broken rule must never stop the validation of the others.
        " Fail closed: action BLOCK, so validate_for_posting( ) blocks in enforce mode -
        " a check that could not run is never permission to post.
        INSERT VALUE #( object_type = zcl_cd_ebs_finding=>gc_object_type-run
                        object_key  = is_rule-class_name
                        group2      = is_rule-rule_group
                        rule_id     = is_rule-rule_id
                        check_code  = gc_check_code-plugin_error
                        severity    = zif_cd_ops_types=>gc_severity-error
                        action      = zif_cd_ops_types=>gc_action-block
                        message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-rule_failed
                                                             iv_v1    = is_rule-rule_id
                                                             iv_v2    = is_rule-class_name
                                                             iv_tail  = lx_error->get_text( ) ) )
          INTO TABLE rt_findings.
    ENDTRY.
  ENDMETHOD.


  METHOD count_lines.
    TYPES tt_worst TYPE HASHED TABLE OF zif_cd_ops_types=>ty_finding WITH UNIQUE KEY object_key.
    DATA lt_worst TYPE tt_worst.
    DATA lt_unevaluated TYPE zif_cd_ops_types=>tt_group.

    LOOP AT it_findings INTO DATA(ls_error) WHERE check_code = gc_check_code-plugin_error.
      INSERT ls_error-group2 INTO TABLE lt_unevaluated.
    ENDLOOP.
    DATA(lv_all_unevaluated) = xsdbool( line_exists( lt_unevaluated[ table_line = zif_cd_ebs_types=>gc_rule_group_all ] ) ).

    LOOP AT it_findings INTO DATA(ls_finding) WHERE object_type = zcl_cd_ebs_finding=>gc_object_type-line.
      READ TABLE lt_worst ASSIGNING FIELD-SYMBOL(<ls_worst>) WITH TABLE KEY object_key = ls_finding-object_key.
      IF sy-subrc <> 0.
        INSERT ls_finding INTO TABLE lt_worst.
      ELSEIF zcl_cd_ops_util=>severity_rank( ls_finding-severity ) > zcl_cd_ops_util=>severity_rank( <ls_worst>-severity ).
        <ls_worst>-severity = ls_finding-severity.
      ENDIF.
    ENDLOOP.

    LOOP AT it_lines INTO DATA(ls_line).
      cs_run-total_items += 1.
      DATA(lv_key) = zcl_cd_ebs_finding=>line_key( ls_line ).
      DATA(lv_severity) = VALUE #( lt_worst[ object_key = lv_key ]-severity OPTIONAL ).
      IF ls_line-blocked = abap_true OR lv_severity = zif_cd_ops_types=>gc_severity-block.
        cs_run-blocked_items += 1.
      ELSEIF lv_all_unevaluated = abap_true OR line_exists( lt_unevaluated[ table_line = ls_line-rule_group ] ).
        cs_run-failed_items += 1.
        cv_unevaluated += 1.
      ELSEIF lv_severity = zif_cd_ops_types=>gc_severity-error.
        cs_run-failed_items += 1.
      ELSEIF lv_severity = zif_cd_ops_types=>gc_severity-warning.
        cs_run-warning_items += 1.
      ELSE.
        cs_run-passed_items += 1.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD close_run.
    cs_run-ended_at   = zcl_cd_ops_factory=>get_clock( )->now( ).
    cs_run-runtime_ms = zcl_cd_ops_util=>elapsed_ms( iv_from = iv_started iv_to = cs_run-ended_at ).
    cs_run-rag        = COND #( WHEN iv_rag IS INITIAL THEN zif_cd_ops_types=>gc_rag-green ELSE iv_rag ).
    IF iv_no_data = abap_true.
      " A68: nothing evaluated - grey unless findings of the source made it worse
      cs_run-rag     = COND #( WHEN iv_rag IS INITIAL THEN zif_cd_ops_types=>gc_rag-grey ELSE iv_rag ).
      cs_run-status  = gc_status_no_data.
      cs_run-message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-no_data
                                              iv_v1    = cs_run-variant ).
      RETURN.
    ENDIF.
    IF cs_run-status <> zif_cd_ops_types=>gc_run_status-aborted.
      cs_run-status = SWITCH #( cs_run-rag
                                WHEN zif_cd_ops_types=>gc_rag-red   THEN zif_cd_ops_types=>gc_run_status-error
                                WHEN zif_cd_ops_types=>gc_rag-amber THEN zif_cd_ops_types=>gc_run_status-warning
                                ELSE zif_cd_ops_types=>gc_run_status-success ).
    ELSE.
      cs_run-rag = zif_cd_ops_types=>gc_rag-red.
    ENDIF.
    cs_run-message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-run_counts_1
                                            iv_v1    = cs_run-total_items
                                            iv_v2    = cs_run-passed_items
                                            iv_v3    = cs_run-failed_items )
                  && ` `
                  && zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-run_counts_2
                                            iv_v1    = cs_run-blocked_items
                                            iv_v2    = cs_run-warning_items ).
    IF iv_unevaluated > 0.
      cs_run-message = cs_run-message && ` ` && zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-unevaluated
                                                                      iv_v1    = iv_unevaluated ).
    ENDIF.
  ENDMETHOD.


  METHOD summarize.
    LOOP AT it_findings INTO DATA(ls_finding).
      READ TABLE ct_summary ASSIGNING FIELD-SYMBOL(<ls_summary>)
           WITH TABLE KEY rule_id    = ls_finding-rule_id
                          check_code = ls_finding-check_code
                          group1     = ls_finding-group1
                          group2     = ls_finding-group2
                          severity   = ls_finding-severity
                          action     = ls_finding-action.
      IF sy-subrc = 0.
        <ls_summary>-count += 1.
      ELSE.
        INSERT VALUE #( rule_id    = ls_finding-rule_id
                        check_code = ls_finding-check_code
                        group1     = ls_finding-group1
                        group2     = ls_finding-group2
                        severity   = ls_finding-severity
                        action     = ls_finding-action
                        count      = 1
                        sample     = ls_finding ) INTO TABLE ct_summary.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD alert_findings.
    rt_findings = it_kept.
    LOOP AT it_summary INTO DATA(ls_summary).
      IF line_exists( it_kept[ rule_id    = ls_summary-rule_id
                               check_code = ls_summary-check_code
                               group1     = ls_summary-group1
                               group2     = ls_summary-group2
                               severity   = ls_summary-severity
                               action     = ls_summary-action ] ).
        CONTINUE.
      ENDIF.
      INSERT ls_summary-sample INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD int_param.
    rv_value = zcl_cd_ops_util=>to_decimal(
      iv_value   = zcl_cd_ops_factory=>get_store( )->get_param( iv_name = iv_name iv_default = |{ iv_default }| )
      iv_default = iv_default ).
  ENDMETHOD.

ENDCLASS.
