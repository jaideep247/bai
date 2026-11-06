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

    TYPES:
      BEGIN OF ty_result,
        run      TYPE zif_cd_ops_types=>ty_run,
        findings TYPE zif_cd_ops_types=>tt_finding,
        lines    TYPE zif_cd_ebs_types=>tt_line,
      END OF ty_result.

    TYPES:
      BEGIN OF ty_decision,
        block    TYPE abap_bool,
        findings TYPE zif_cd_ops_types=>tt_finding,
        package  TYPE zif_cd_ebs_types=>ty_package,
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
    "! depends only on this class and one TVARVC row. Failed read = MONITOR.
    CLASS-METHODS read_mode
      RETURNING
        VALUE(rv_mode) TYPE ty_mode.

  PRIVATE SECTION.
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

    METHODS execute_rule
      IMPORTING
        is_rule            TYPE zif_cd_ebs_types=>ty_rule_cfg
        it_statements      TYPE zif_cd_ebs_types=>tt_statement
        it_lines           TYPE zif_cd_ebs_types=>tt_line
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

    METHODS count_lines
      IMPORTING
        it_lines    TYPE zif_cd_ebs_types=>tt_line
        it_findings TYPE zif_cd_ops_types=>tt_finding
      CHANGING
        cs_run      TYPE zif_cd_ops_types=>ty_run.

    METHODS close_run
      IMPORTING
        iv_rag      TYPE zif_cd_ops_types=>ty_rag
        iv_started  TYPE timestampl
      CHANGING
        cs_run      TYPE zif_cd_ops_types=>ty_run.

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
    DATA lv_run_rag      TYPE zif_cd_ops_types=>ty_rag.
    DATA lv_bad_packages TYPE i.

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

      DATA(lt_findings) = validate_package( CHANGING cs_package = ls_package ).
      DATA(ls_before) = rs_result-run.
      count_lines( EXPORTING it_lines = ls_package-lines it_findings = lt_findings
                   CHANGING  cs_run   = rs_result-run ).

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
      IF lines( rs_result-lines ) < lv_keep_max.
        INSERT LINES OF ls_package-lines INTO TABLE rs_result-lines.
      ENDIF.

      " Circuit breaker: consecutive packages with a failure rate above the limit
      DATA(lv_package_lines) = rs_result-run-total_items - ls_before-total_items.
      DATA(lv_package_bad) = ( rs_result-run-failed_items - ls_before-failed_items )
                           + ( rs_result-run-blocked_items - ls_before-blocked_items ).
      IF lv_package_lines >= lv_cb_min AND lv_package_lines > 0
         AND lv_package_bad * 100 > lv_cb_percent * lv_package_lines.
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
        lv_run_rag = zif_cd_ops_types=>gc_rag-red.
        rs_result-run-status = zif_cd_ops_types=>gc_run_status-aborted.
        EXIT.
      ENDIF.
    ENDDO.

    close_run( EXPORTING iv_rag     = lv_run_rag
                         iv_started = lv_started
               CHANGING  cs_run     = rs_result-run ).
    lo_store->finish_run( rs_result-run ).
    IF iv_test_mode = abap_false.
      lo_store->commit( ).
      TRY.
          zcl_cd_ops_factory=>get_alert( )->dispatch( is_run = rs_result-run it_findings = lt_all_findings ).
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

    mo_resolver->enrich_statements( CHANGING ct_statements = cs_package-statements ).
    INSERT LINES OF mo_resolver->resolve( EXPORTING it_statements = cs_package-statements
                                          CHANGING  ct_lines      = cs_package-lines ) INTO TABLE rt_findings.

    " 1. Statement checks
    LOOP AT mt_rules INTO DATA(ls_stmt_rule) WHERE level = zif_cd_ebs_types=>gc_level-statement.
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
    SELECT SINGLE low
      FROM tvarvc BYPASSING BUFFER
      WHERE name = @gc_switch_name
        AND type = @zif_cd_ebs_types=>gc_tvarvc-type_parameter
        AND numb = @zif_cd_ebs_types=>gc_tvarvc-numb_single
      INTO @DATA(lv_low).
    rv_mode = COND #( WHEN sy-subrc <> 0 THEN gc_mode-monitor
                      WHEN lv_low = gc_mode-enforce OR lv_low = gc_mode-off THEN lv_low
                      ELSE gc_mode-monitor ).
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


  METHOD execute_rule.
    DATA lo_rule TYPE REF TO zif_cd_ebs_rule.
    TRY.
        READ TABLE mt_plugins INTO DATA(ls_plugin) WITH TABLE KEY class_name = is_rule-class_name.
        IF sy-subrc = 0.
          lo_rule = ls_plugin-rule.
        ELSE.
          lo_rule = CAST zif_cd_ebs_rule( zcl_cd_ops_factory=>get_plugin( is_rule-class_name ) ).
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
  ENDMETHOD.


  METHOD int_param.
    rv_value = zcl_cd_ops_util=>to_decimal(
      iv_value   = zcl_cd_ops_factory=>get_store( )->get_param( iv_name = iv_name iv_default = |{ iv_default }| )
      iv_default = iv_default ).
  ENDMETHOD.

ENDCLASS.
