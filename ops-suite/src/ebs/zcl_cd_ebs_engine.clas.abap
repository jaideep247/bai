*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_engine.clas.abap
*& Purpose:
*& EBS validation engine (chain of responsibility): BTC resolution (R14, zero
*& suspense) -> statement checks -> line rules per rule group, all resolved
*& from customizing. Works on any source (bank file or FEBKO/FEBEP), persists
*& findings through the core store per package, has a circuit breaker and
*& hands the run to the alert router. Read-only towards production data: it
*& reads statements and payment engine evidence and writes only suite records.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Findings kept in memory capped at EBS_RESULT_MAX; RAG accumulated per package (review 3.5).
*& 2026-11-06 | Fail closed: PLUGIN_ERROR has action BLOCK.
*& 2026-11-06 | Run lock per variant (refused run when held); body moved to execute( ).
*& 2026-11-06 | Exception carry-forward: each package's lines and statements reconciled.
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A03: configuration gaps (unusable assignment, group without usable rule) block; NONE rows skipped.
*& 2026-11-06 | Audit A66/A67/A68: unevaluated lines, technical breaker; alerts over complete summaries;
*&            | exact line cap; NO_DATA run.
*& 2026-11-06 | Audit A62: rule plug-ins created with interface check.
*& 2026-11-06 | NO_DATA status taken from the core run-status constants.
*& 2026-11-06 | Operating model (post-posting detective control): an imported entry expected to
*&            | post but not posted is POSTING_OPEN - rules flagged NEEDS_POSTING are not evaluated
*&            | for it (or its statement), it is counted as unevaluated, kept out of the exception
*&            | reconciliation, and the run is never green (rule S13 reports POSTING_INCOMPLETE).
*& 2026-11-06 | Performance: rule lookups per line / finding by sorted secondary keys, alert classes
*&            | of the kept findings hashed, read-only loops with field symbols; the check-register
*&            | memo is cleared at the start of validate_package (same statements validated twice).
*& 2026-11-06 | Package buffers released (FREE) once persisted, before the next package is read.
*& 2026-11-06 | Payment engine account scope (user decision): before validation each package's imported
*&            | statements whose lines are not all active payment engine accounts (account from
*&            | FEBEP-XBLNR, ZCL_CD_EBS_PE_SCOPE) are removed with their lines - no rule, no finding, no
*&            | reconciliation - and counted (result OUT_OF_SCOPE, run message 546).
*& 2026-11-06 | Run with every statement out of scope is NO_DATA (grey), not green; count in the message.
*& 2026-11-07 | Parameter names / defaults from ZIF_CD_OPS_TYPES / ZIF_CD_EBS_TYPES; integer parameters with
*&            | ZCL_CD_OPS_UTIL=>PARAM_INT (private int_param removed); parameters through GET_PARAMS.
*& 2026-11-07 | Read-only scope (user decision): pre-posting path (validate_for_posting, must_block,
*&            | dispositions, release lookup), TVARVC kill switch read_mode and the blocks-posting
*&            | flag (apply_blocking_flags) removed - the batch run ZCD_EBS_VALIDATE is the only entry.
*& 2026-11-07 | EBS_EMPTY_FEED_OK read through ZCL_CD_OPS_FACTORY=>GET_PARAMS (the store serves no parameters).
*& 2026-11-07 | Posting-open definition in ZCL_CD_EBS_STMT_EVIDENCE=>IS_POSTING_OPEN (shared with file monitoring).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - engine</p>
CLASS zcl_cd_ebs_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF gc_check_code,
        plugin_error TYPE zif_cd_ops_types=>ty_check_code VALUE 'PLUGIN_ERROR',
      END OF gc_check_code.

    "! A68: run status of a run that selected no statement (RAG grey)
    CONSTANTS gc_status_no_data TYPE zif_cd_ops_types=>ty_run_status VALUE zif_cd_ops_types=>gc_run_status-no_data.

    TYPES:
      BEGIN OF ty_result,
        run         TYPE zif_cd_ops_types=>ty_run,
        "! Retained findings (EBS_RESULT_MAX); every finding is saved and alerted on
        findings    TYPE zif_cd_ops_types=>tt_finding,
        "! Retained lines, exactly EBS_RESULT_MAX at most
        lines       TYPE zif_cd_ebs_types=>tt_line,
        "! A66: lines not evaluated because a rule of their group could not run, plus the
        "! POSTING_OPEN lines below
        unevaluated  TYPE i,
        "! Operating model 2026-11-06: imported entries expected to post but not posted whose
        "! posting-dependent rules (NEEDS_POSTING) were not evaluated - never passed, never failed
        posting_open TYPE i,
        "! User decision 2026-11-06: imported statements not validated because not every line
        "! carries an active payment engine account (XBLNR) - no finding; ZCD_OPS_RUN has no
        "! field for it, the run message carries it (message 546)
        out_of_scope TYPE i,
      END OF ty_result.

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

  PRIVATE SECTION.
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

    "! Active rules in execution order (level, rule group, sequence, rule ID - primary index).
    "! Sorted secondary keys for the lookups per line (BY_GROUP, BY_POSTING); rows of one key
    "! keep the primary order
    TYPES tt_rule TYPE STANDARD TABLE OF zif_cd_ebs_types=>ty_rule_cfg WITH EMPTY KEY
                  WITH NON-UNIQUE SORTED KEY by_group COMPONENTS rule_group unusable
                  WITH NON-UNIQUE SORTED KEY by_posting COMPONENTS needs_posting level unusable rule_group.

    DATA mo_resolver     TYPE REF TO zcl_cd_ebs_btc_resolver.
    "! Payment engine account scope (active ZCD_EBS_ACCT accounts)
    DATA mo_scope        TYPE REF TO zcl_cd_ebs_pe_scope.
    DATA mt_rules        TYPE tt_rule.
    DATA mt_plugins      TYPE tt_plugin.
    DATA mv_config_ready TYPE abap_bool.

    METHODS load_configuration
      RAISING
        zcx_cd_ops_error.


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
    "! PLUGIN_ERROR is not evaluated - counted as failed and in cv_unevaluated, never passed.
    "! Operating model: a POSTING_OPEN line with a posting-dependent rule that was not
    "! evaluated counts in cv_unevaluated and cv_posting_open - neither passed nor failed
    "! (a B / E finding of a rule that did run still counts it as blocked / failed)
    METHODS count_lines
      IMPORTING
        it_lines        TYPE zif_cd_ebs_types=>tt_line
        it_findings     TYPE zif_cd_ops_types=>tt_finding
      CHANGING
        cs_run          TYPE zif_cd_ops_types=>ty_run
        cv_unevaluated  TYPE i
        cv_posting_open TYPE i.

    "! Operating model 2026-11-06: an imported entry with posting state O that is not mapped
    "! NOT_POSTED and not blocked is expected to post but is not posted (POSTING_OPEN)
    CLASS-METHODS mark_posting_open
      CHANGING
        ct_lines TYPE zif_cd_ebs_types=>tt_line.

    TYPES tt_stmt_key TYPE HASHED TABLE OF zif_cd_ebs_types=>ty_stmt_key WITH UNIQUE KEY table_line.

    "! Operating model 2026-11-06: statements holding a POSTING_OPEN entry
    CLASS-METHODS posting_open_statements
      IMPORTING
        it_lines             TYPE zif_cd_ebs_types=>tt_line
      RETURNING
        VALUE(rt_statements) TYPE tt_stmt_key.

    "! Operating model 2026-11-06: does a rule flagged NEEDS_POSTING apply to the line - a
    "! statement rule, or a line rule of its group or '*'
    METHODS posting_rule_applies
      IMPORTING
        is_line       TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    METHODS close_run
      IMPORTING
        iv_rag          TYPE zif_cd_ops_types=>ty_rag
        iv_started      TYPE timestampl
        iv_no_data      TYPE abap_bool DEFAULT abap_false
        iv_unevaluated  TYPE i DEFAULT 0
        iv_posting_open TYPE i DEFAULT 0
        iv_out_of_scope TYPE i DEFAULT 0
      CHANGING
        cs_run          TYPE zif_cd_ops_types=>ty_run.

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
    " Operating model: an entry not posted yet, and its statement, were not fully evaluated -
    " their open exceptions stay open until a run after the posting jobs evaluates them
    DATA(lt_open_statements) = posting_open_statements( is_package-lines ).
    LOOP AT is_package-statements ASSIGNING FIELD-SYMBOL(<ls_statement>).
      IF line_exists( lt_open_statements[ table_line = <ls_statement>-stmt_key ] ).
        CONTINUE.
      ENDIF.
      INSERT CONV zif_cd_ops_types=>ty_object_key( <ls_statement>-stmt_key ) INTO TABLE lt_scope.
    ENDLOOP.
    LOOP AT is_package-lines ASSIGNING FIELD-SYMBOL(<ls_line>) WHERE posting_open = abap_false.
      INSERT zcl_cd_ebs_finding=>line_key( <ls_line> ) INTO TABLE lt_scope.
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

    DATA(lo_params)      = zcl_cd_ops_factory=>get_params( ).
    DATA(lv_cb_percent)  = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                       iv_name    = zif_cd_ebs_types=>gc_param-cb_fail_pct
                                                       iv_default = zif_cd_ebs_types=>gc_param_default-cb_fail_pct ).
    DATA(lv_cb_packages) = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                       iv_name    = zif_cd_ebs_types=>gc_param-cb_packages
                                                       iv_default = zif_cd_ebs_types=>gc_param_default-cb_packages ).
    DATA(lv_cb_min)      = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                       iv_name    = zif_cd_ebs_types=>gc_param-cb_min_lines
                                                       iv_default = zif_cd_ebs_types=>gc_param_default-cb_min_lines ).
    DATA(lv_keep_max)    = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                       iv_name    = zif_cd_ebs_types=>gc_param-result_max
                                                       iv_default = zif_cd_ebs_types=>gc_param_default-result_max ).

    DO.
      DATA(ls_package) = io_source->next_package( ).
      IF ls_package-statements IS INITIAL AND ls_package-lines IS INITIAL AND ls_package-findings IS INITIAL.
        EXIT.
      ENDIF.

      " User decision 2026-11-06: only statements whose every line is a payment engine account
      " are validated; the others leave the package before any rule, finding or reconciliation
      load_configuration( ).
      rs_result-out_of_scope += mo_scope->remove_out_of_scope( CHANGING cs_package = ls_package ).
      " Only statements in scope count as evaluated: a run whose statements were all out of
      " scope evaluated nothing and is NO_DATA (grey), never green - an empty or wrong account
      " configuration must not look like a clean day
      lv_statements += lines( ls_package-statements ).
      IF ls_package-statements IS INITIAL AND ls_package-lines IS INITIAL AND ls_package-findings IS INITIAL.
        FREE ls_package.
        CONTINUE.
      ENDIF.
      DATA(lt_findings) = validate_package( CHANGING cs_package = ls_package ).
      DATA(ls_before) = rs_result-run.
      count_lines( EXPORTING it_lines        = ls_package-lines
                             it_findings     = lt_findings
                   CHANGING  cs_run          = rs_result-run
                             cv_unevaluated  = rs_result-unevaluated
                             cv_posting_open = rs_result-posting_open ).
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
      LOOP AT lt_findings ASSIGNING FIELD-SYMBOL(<ls_keep>) FROM 1 TO lv_keep_max - lines( lt_all_findings ).
        INSERT <ls_keep> INTO TABLE lt_all_findings.
      ENDLOOP.
      " A67: the retention bound is exact - never a whole package over the cap
      LOOP AT ls_package-lines ASSIGNING FIELD-SYMBOL(<ls_keep_line>) FROM 1 TO lv_keep_max - lines( rs_result-lines ).
        INSERT <ls_keep_line> INTO TABLE rs_result-lines.
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
      " The package is persisted, counted and kept within EBS_RESULT_MAX: release its buffers
      " before the next package is read (lower peak memory in long batch runs)
      FREE: ls_package, lt_findings.
    ENDDO.

    " A68: a run that selected no statement evaluated nothing - NO_DATA (grey), not green,
    " unless the feed is declared intentionally empty (EBS_EMPTY_FEED_OK = X)
    DATA(lv_no_data) = xsdbool( lv_statements = 0
                                AND rs_result-run-status <> zif_cd_ops_types=>gc_run_status-aborted
                                AND zcl_cd_ops_factory=>get_params( )->get_param( zif_cd_ebs_types=>gc_param-empty_feed_ok ) <> abap_true ).
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

    " Operating model: a run that could not evaluate entries because posting is not complete
    " is never green, whatever severity S13 is configured with
    IF rs_result-posting_open > 0.
      lv_run_rag = zcl_cd_ops_util=>worse_rag( iv_rag1 = lv_run_rag iv_rag2 = zif_cd_ops_types=>gc_rag-amber ).
    ENDIF.
    close_run( EXPORTING iv_rag          = lv_run_rag
                         iv_started      = lv_started
                         iv_no_data      = lv_no_data
                         iv_unevaluated  = rs_result-unevaluated
                         iv_posting_open = rs_result-posting_open
                         iv_out_of_scope = rs_result-out_of_scope
               CHANGING  cs_run          = rs_result-run ).
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
    " Performance fix 1 note: the DFKKCR memo of the cheque rules is bound to the statement
    " keys - validating the same statement set twice in one session must read it again
    zcl_cd_ebs_rule_base=>clear_memo( ).
    load_configuration( ).
    INSERT LINES OF cs_package-findings INTO TABLE rt_findings.

    mo_resolver->enrich_statements( CHANGING ct_statements = cs_package-statements ).
    INSERT LINES OF mo_resolver->resolve( EXPORTING it_statements = cs_package-statements
                                          CHANGING  ct_lines      = cs_package-lines ) INTO TABLE rt_findings.
    mark_posting_open( CHANGING ct_lines = cs_package-lines ).

    " Operating model: statements without an entry that is expected to post but not posted,
    " and their lines - the scope of statement rules flagged NEEDS_POSTING
    DATA lt_posted_statements TYPE zif_cd_ebs_types=>tt_statement.
    DATA lt_posted_stmt_lines TYPE zif_cd_ebs_types=>tt_line.
    DATA(lt_open_statements) = posting_open_statements( cs_package-lines ).
    LOOP AT cs_package-statements ASSIGNING FIELD-SYMBOL(<ls_statement>).
      IF NOT line_exists( lt_open_statements[ table_line = <ls_statement>-stmt_key ] ).
        INSERT <ls_statement> INTO TABLE lt_posted_statements.
        LOOP AT cs_package-lines ASSIGNING FIELD-SYMBOL(<ls_stmt_line>) USING KEY stmt
             WHERE stmt_key = <ls_statement>-stmt_key.
          INSERT <ls_stmt_line> INTO TABLE lt_posted_stmt_lines.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    " 0. Configuration gaps (A03) - never a silent pass
    INSERT LINES OF configuration_gaps( cs_package-lines ) INTO TABLE rt_findings.

    " 1. Statement checks
    LOOP AT mt_rules ASSIGNING FIELD-SYMBOL(<ls_stmt_rule>) WHERE level = zif_cd_ebs_types=>gc_level-statement
                                                              AND unusable = abap_false.
      IF <ls_stmt_rule>-needs_posting = abap_false.
        INSERT LINES OF execute_rule( is_rule       = <ls_stmt_rule>
                                      it_statements = cs_package-statements
                                      it_lines      = cs_package-lines ) INTO TABLE rt_findings.
      ELSEIF lt_posted_statements IS NOT INITIAL.
        INSERT LINES OF execute_rule( is_rule       = <ls_stmt_rule>
                                      it_statements = lt_posted_statements
                                      it_lines      = lt_posted_stmt_lines ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.

    " 2. Line rules per rule group; blocked lines are never validated as postable
    DATA(lt_open) = cs_package-lines.
    DELETE lt_open WHERE blocked = abap_true.
    LOOP AT lt_open INTO DATA(ls_group_line) GROUP BY ls_group_line-rule_group INTO DATA(lv_group).
      DATA lt_group_lines TYPE zif_cd_ebs_types=>tt_line.
      DATA lt_posted_lines TYPE zif_cd_ebs_types=>tt_line.
      CLEAR: lt_group_lines, lt_posted_lines.
      LOOP AT GROUP lv_group ASSIGNING FIELD-SYMBOL(<ls_member_line>).
        INSERT <ls_member_line> INTO TABLE lt_group_lines.
        IF <ls_member_line>-posting_open = abap_false.
          INSERT <ls_member_line> INTO TABLE lt_posted_lines.
        ENDIF.
      ENDLOOP.
      " Execution order is the primary order of the rules (once per rule group, not per line)
      LOOP AT mt_rules ASSIGNING FIELD-SYMBOL(<ls_line_rule>)
           WHERE level = zif_cd_ebs_types=>gc_level-line
             AND unusable = abap_false
             AND rule_id <> zif_cd_ebs_types=>gc_rule_none
             AND ( rule_group = lv_group OR rule_group = zif_cd_ebs_types=>gc_rule_group_all ).
        " Operating model: a posting-dependent rule sees only entries that are posted (or
        " not expected to post, or of unknown posting state - bank file)
        IF <ls_line_rule>-needs_posting = abap_false.
          INSERT LINES OF execute_rule( is_rule       = <ls_line_rule>
                                        it_statements = cs_package-statements
                                        it_lines      = lt_group_lines ) INTO TABLE rt_findings.
        ELSEIF lt_posted_lines IS NOT INITIAL.
          INSERT LINES OF execute_rule( is_rule       = <ls_line_rule>
                                        it_statements = cs_package-statements
                                        it_lines      = lt_posted_lines ) INTO TABLE rt_findings.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_configuration.
    IF mv_config_ready = abap_true.
      RETURN.
    ENDIF.
    DATA(lo_cfg) = zcl_cd_ebs_factory=>get_cfg_dao( ).
    DATA(lv_fallback) = zcl_cd_ops_factory=>get_params( )->get_param(
                          iv_name    = zif_cd_ebs_types=>gc_param-camt_bai_fallback
                          iv_default = zif_cd_ebs_types=>gc_param_default-camt_bai_fallback ).
    DATA(lt_accounts) = lo_cfg->get_accounts( ).
    mo_resolver = NEW #( it_map          = lo_cfg->get_btc_map( )
                         it_patterns     = lo_cfg->get_flow_patterns( )
                         it_accounts     = lt_accounts
                         iv_bai_fallback = xsdbool( lv_fallback = abap_true ) ).
    mo_scope = NEW #( lt_accounts ).
    mt_rules = lo_cfg->get_rules( ).
    DELETE mt_rules WHERE active = abap_false.
    SORT mt_rules BY level rule_group seq rule_id.
    mv_config_ready = abap_true.
  ENDMETHOD.


  METHOD configuration_gaps.
    LOOP AT mt_rules ASSIGNING FIELD-SYMBOL(<ls_run_rule>) USING KEY by_group
         WHERE rule_group = zif_cd_ebs_types=>gc_rule_group_all AND unusable = abap_true.
      INSERT VALUE #( object_type = zcl_cd_ebs_finding=>gc_object_type-run
                      object_key  = <ls_run_rule>-rule_id
                      group2      = <ls_run_rule>-rule_group
                      rule_id     = <ls_run_rule>-rule_id
                      check_code  = zif_cd_ebs_types=>gc_check_code-rule_unusable
                      severity    = zif_cd_ops_types=>gc_severity-error
                      action      = zif_cd_ops_types=>gc_action-block
                      message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-rule_unusable
                                                           iv_v1    = <ls_run_rule>-rule_id
                                                           iv_v2    = <ls_run_rule>-rule_group ) )
        INTO TABLE rt_findings.
    ENDLOOP.

    " Per line: the rules of its group by key BY_GROUP (was a scan of every rule per line)
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>) WHERE blocked = abap_false.
      IF <ls_line>-rule_group IS INITIAL OR <ls_line>-rule_group = zif_cd_ebs_types=>gc_rule_group_all.
        CONTINUE.
      ENDIF.
      LOOP AT mt_rules ASSIGNING FIELD-SYMBOL(<ls_rule>) USING KEY by_group
           WHERE rule_group = <ls_line>-rule_group AND unusable = abap_true.
        INSERT zcl_cd_ebs_finding=>for_line(
                 is_line       = <ls_line>
                 iv_rule_id    = <ls_rule>-rule_id
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-rule_unusable
                 iv_severity   = zif_cd_ops_types=>gc_severity-error
                 iv_action     = zif_cd_ops_types=>gc_action-block
                 iv_message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-rule_unusable
                                                        iv_v1    = <ls_rule>-rule_id
                                                        iv_v2    = <ls_rule>-rule_group ) )
          INTO TABLE rt_findings.
      ENDLOOP.
      " a usable rule or an explicit NONE row (group intentionally without own rules)
      IF NOT line_exists( mt_rules[ KEY by_group rule_group = <ls_line>-rule_group unusable = abap_false ] ).
        INSERT zcl_cd_ebs_finding=>for_line(
                 is_line       = <ls_line>
                 iv_rule_id    = zif_cd_ebs_types=>gc_engine-rule_id
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-rule_group_empty
                 iv_severity   = zif_cd_ops_types=>gc_severity-error
                 iv_action     = zif_cd_ops_types=>gc_action-block
                 iv_message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-rule_group_empty
                                                        iv_v1    = <ls_line>-rule_group ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD execute_rule.
    DATA lo_rule TYPE REF TO zif_cd_ebs_rule.
    TRY.
        READ TABLE mt_plugins ASSIGNING FIELD-SYMBOL(<ls_plugin>) WITH TABLE KEY class_name = is_rule-class_name.
        IF sy-subrc = 0.
          lo_rule = <ls_plugin>-rule.
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
        " Fail closed: action BLOCK - a check that could not run is never a pass.
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

    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_error>) WHERE check_code = gc_check_code-plugin_error.
      INSERT <ls_error>-group2 INTO TABLE lt_unevaluated.
    ENDLOOP.
    DATA(lv_all_unevaluated) = xsdbool( line_exists( lt_unevaluated[ table_line = zif_cd_ebs_types=>gc_rule_group_all ] ) ).

    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>) WHERE object_type = zcl_cd_ebs_finding=>gc_object_type-line.
      READ TABLE lt_worst ASSIGNING FIELD-SYMBOL(<ls_worst>) WITH TABLE KEY object_key = <ls_finding>-object_key.
      IF sy-subrc <> 0.
        INSERT <ls_finding> INTO TABLE lt_worst.
      ELSEIF zcl_cd_ops_util=>severity_rank( <ls_finding>-severity ) > zcl_cd_ops_util=>severity_rank( <ls_worst>-severity ).
        <ls_worst>-severity = <ls_finding>-severity.
      ENDIF.
    ENDLOOP.

    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      cs_run-total_items += 1.
      DATA(lv_key) = zcl_cd_ebs_finding=>line_key( <ls_line> ).
      DATA(lv_severity) = VALUE #( lt_worst[ object_key = lv_key ]-severity OPTIONAL ).
      IF <ls_line>-blocked = abap_true OR lv_severity = zif_cd_ops_types=>gc_severity-block.
        cs_run-blocked_items += 1.
      ELSEIF lv_all_unevaluated = abap_true OR line_exists( lt_unevaluated[ table_line = <ls_line>-rule_group ] ).
        cs_run-failed_items += 1.
        cv_unevaluated += 1.
      ELSEIF lv_severity = zif_cd_ops_types=>gc_severity-error.
        cs_run-failed_items += 1.
      ELSEIF <ls_line>-posting_open = abap_true AND posting_rule_applies( <ls_line> ) = abap_true.
        cv_unevaluated += 1.
        cv_posting_open += 1.
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
      IF iv_out_of_scope > 0.
        cs_run-message = |{ cs_run-message } {
                            zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-out_of_scope
                                                   iv_v1    = iv_out_of_scope ) }|.
      ENDIF.
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
    cs_run-message = |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-run_counts_1
                                               iv_v1    = cs_run-total_items
                                               iv_v2    = cs_run-passed_items
                                               iv_v3    = cs_run-failed_items ) } {
                        zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-run_counts_2
                                               iv_v1    = cs_run-blocked_items
                                               iv_v2    = cs_run-warning_items ) }|.
    IF iv_unevaluated > iv_posting_open.
      cs_run-message = |{ cs_run-message } {
                          zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-unevaluated
                                                 iv_v1    = iv_unevaluated - iv_posting_open ) }|.
    ENDIF.
    IF iv_posting_open > 0.
      cs_run-message = |{ cs_run-message } {
                          zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-posting_unevaluated
                                                 iv_v1    = iv_posting_open ) }|.
    ENDIF.
    IF iv_out_of_scope > 0.
      cs_run-message = |{ cs_run-message } {
                          zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-out_of_scope
                                                 iv_v1    = iv_out_of_scope ) }|.
    ENDIF.
  ENDMETHOD.


  METHOD mark_posting_open.
    LOOP AT ct_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      " One definition of 'expected to post but not posted' (shared with file monitoring)
      <ls_line>-posting_open = zcl_cd_ebs_stmt_evidence=>is_posting_open( <ls_line> ).
    ENDLOOP.
  ENDMETHOD.


  METHOD posting_open_statements.
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>) WHERE posting_open = abap_true.
      INSERT <ls_line>-stmt_key INTO TABLE rt_statements.
    ENDLOOP.
  ENDMETHOD.


  METHOD posting_rule_applies.
    rv_yes = xsdbool(
      line_exists( mt_rules[ KEY by_posting needs_posting = abap_true
                                            level         = zif_cd_ebs_types=>gc_level-statement
                                            unusable      = abap_false ] )
      OR line_exists( mt_rules[ KEY by_posting needs_posting = abap_true
                                               level         = zif_cd_ebs_types=>gc_level-line
                                               unusable      = abap_false
                                               rule_group    = is_line-rule_group ] )
      OR line_exists( mt_rules[ KEY by_posting needs_posting = abap_true
                                               level         = zif_cd_ebs_types=>gc_level-line
                                               unusable      = abap_false
                                               rule_group    = zif_cd_ebs_types=>gc_rule_group_all ] ) ).
  ENDMETHOD.


  METHOD summarize.
    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      READ TABLE ct_summary ASSIGNING FIELD-SYMBOL(<ls_summary>)
           WITH TABLE KEY rule_id    = <ls_finding>-rule_id
                          check_code = <ls_finding>-check_code
                          group1     = <ls_finding>-group1
                          group2     = <ls_finding>-group2
                          severity   = <ls_finding>-severity
                          action     = <ls_finding>-action.
      IF sy-subrc = 0.
        <ls_summary>-count += 1.
      ELSE.
        INSERT VALUE #( rule_id    = <ls_finding>-rule_id
                        check_code = <ls_finding>-check_code
                        group1     = <ls_finding>-group1
                        group2     = <ls_finding>-group2
                        severity   = <ls_finding>-severity
                        action     = <ls_finding>-action
                        count      = 1
                        sample     = <ls_finding> ) INTO TABLE ct_summary.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD alert_findings.
    DATA lt_kept_classes TYPE tt_summary.
    rt_findings = it_kept.
    " Classes of the kept findings in one pass (was a scan of up to EBS_RESULT_MAX findings
    " per summarised class)
    LOOP AT it_kept ASSIGNING FIELD-SYMBOL(<ls_kept>).
      INSERT VALUE #( rule_id    = <ls_kept>-rule_id
                      check_code = <ls_kept>-check_code
                      group1     = <ls_kept>-group1
                      group2     = <ls_kept>-group2
                      severity   = <ls_kept>-severity
                      action     = <ls_kept>-action ) INTO TABLE lt_kept_classes.
    ENDLOOP.
    LOOP AT it_summary ASSIGNING FIELD-SYMBOL(<ls_summary>).
      IF line_exists( lt_kept_classes[ rule_id    = <ls_summary>-rule_id
                                       check_code = <ls_summary>-check_code
                                       group1     = <ls_summary>-group1
                                       group2     = <ls_summary>-group2
                                       severity   = <ls_summary>-severity
                                       action     = <ls_summary>-action ] ).
        CONTINUE.
      ENDIF.
      INSERT <ls_summary>-sample INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
