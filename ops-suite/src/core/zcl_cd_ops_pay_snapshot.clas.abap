*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_snapshot.clas.abap
*& Purpose:
*& Incremental 5-minute snapshot of the canonical payment outcome (job step
*& ZCD_OPS_PAY_SNAPSHOT of the SM36 job ZCD_FMON_MONITOR_ALL): per evidence
*& source (payment / clearing documents, reversals, statement lines, returns
*& lots, G/L clearing of XREF2, recheck of outcomes that are not final) only
*& the payment documents with new evidence after the source's watermark are
*& read, in packages, and judged by the shared evaluator ZIF_CD_OPS_PAY_OUTCOME
*& (the verdict of A_INFLIGHT and the payment trace). Per FIN + source +
*& company code + payment + run a new version of ZCD_PAY_OUTCOME is written
*& only when the outcome or its finding changed (the current one is closed);
*& otherwise nothing. A payment without an item with a FIN gets one version
*& with FIN and source blank. A FIN in two sources is AMBIGUOUS for both
*& (finding PAY_SOURCE_AMBIGUOUS, one finding per flow + method class + run
*& date). PAYOUT_PARALLEL = 1: each package commits its versions and its
*& watermark together, one after the other (as before). PAYOUT_PARALLEL > 1:
*& the packages of every source are planned first (key reads), then judged
*& in waves of parallel bgPF units (ZCL_CD_OPS_PAY_SNAP_OP, package rows
*& ZCD_PAY_OUTPKG); each unit commits its versions with its package status,
*& and the run advances a source's watermark only to the end of the last
*& contiguous completed package - never past a failed or abandoned one. A
*& package that cannot be judged completely (configuration, capped read)
*& writes nothing (PAY_OUTCOME_FAILED). The watermark keeps the instant up to
*& which its source is processed (CURRENT_TO): the snapshot lag. Run lock
*& per variant; test mode writes nothing (always one by one). Read-only
*& towards business tables.
*& Modification log:
*& 2026-11-07 | Initial version (incremental 5-minute payment outcome snapshot).
*& 2026-11-08 | Scale (2 million payments a peak day, user 2026-11-08): parallel packages as bgPF units
*&            | (PAYOUT_PARALLEL, PAYOUT_PARALLEL_WAIT_SEC; queue seam ZIF_CD_OPS_PAY_SNAP_QUEUE) with
*&            | ordered watermark advancement (CONTIGUOUS_DONE); PAYOUT_PARALLEL 1 unchanged. CURRENT_TO
*&            | per watermark and the snapshot lag (LAG). Versions also for payments without FIN; current
*&            | versions read by payment document; a new version when the finding changes too; marker
*&            | PAY_STATUS_PENDING for a verdict whose payment status waits for the status job (basis of
*&            | A_INFLIGHT PAY_STATUS_LAG); SEVERITY of the version. PAY_SOURCE_AMBIGUOUS aggregated per
*&            | flow + method class + run date with count and the first PAYOUT_EXAMPLES examples.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - incremental 5-minute snapshot</p>
"! Parameters (ZCA_PARAM, CD_OPS): PAYOUT_PACKAGE_SIZE, PAYOUT_MAX_PACKAGES, PAYOUT_INITIAL_DAYS,
"! PAYOUT_PARALLEL, PAYOUT_PARALLEL_WAIT_SEC, PAYOUT_EXAMPLES; evidence row cap HCK_INFLIGHT_MAX_ROWS
"! (as A_INFLIGHT).
CLASS zcl_cd_ops_pay_snapshot DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_result,
        run      TYPE zif_cd_ops_types=>ty_run,
        sources  TYPE zif_cd_ops_payout_types=>tt_source_result,
        findings TYPE zif_cd_ops_types=>tt_finding,
        "! Snapshot lag after the run (from the saved watermarks)
        lag      TYPE zif_cd_ops_payout_types=>ty_lag,
      END OF ty_result.

    "! Package status in package order (ordered watermark advancement)
    TYPES tt_pkg_status TYPE STANDARD TABLE OF zif_cd_ops_payout_types=>ty_pkg_status WITH EMPTY KEY.

    "! One snapshot run over every evidence source
    "! @raising zcx_cd_ops_error | run header or run end could not be written
    METHODS run
      IMPORTING
        iv_test_mode     TYPE abap_bool
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_cd_ops_error.

    "! One parallel package as its bgPF unit runs it: judge the documents, claim the package row
    "! (still planned), write the versions and status D in one commit; on any error nothing of the
    "! package is written and its status is F. Never raises
    METHODS run_package
      IMPORTING
        is_package TYPE zif_cd_ops_payout_types=>ty_package.

    "! Versions to close and to insert so that the current versions of the evaluated payment
    "! documents equal the desired ones: same key, outcome and finding = nothing; otherwise close +
    "! insert; new key = insert; a current version of an evaluated payment whose key is no longer
    "! desired (newer payment run, other source attribution) = close
    CLASS-METHODS plan_versions
      IMPORTING
        it_desired TYPE zif_cd_ops_payout_types=>tt_version
        it_open    TYPE zif_cd_ops_payout_types=>tt_version
        iv_now     TYPE zif_cd_ops_payout_types=>ty_timestamp
      EXPORTING
        et_close   TYPE zif_cd_ops_payout_types=>tt_version
        et_insert  TYPE zif_cd_ops_payout_types=>tt_version.

    "! Ordered watermark rule: the number of leading packages (package order) that are done - the
    "! watermark of the source may advance to the end of the last of them and never further
    CLASS-METHODS contiguous_done
      IMPORTING
        it_status       TYPE tt_pkg_status
      RETURNING
        VALUE(rv_count) TYPE i.

    "! Snapshot lag at iv_now: whole minutes since the oldest CURRENT_TO of the evidence sources
    "! (RECHECK has no time and is left out); KNOWN blank when no source has a CURRENT_TO yet
    CLASS-METHODS lag
      IMPORTING
        it_watermarks TYPE zif_cd_ops_payout_types=>tt_watermark
        iv_now        TYPE timestampl
      RETURNING
        VALUE(rs_lag) TYPE zif_cd_ops_payout_types=>ty_lag.

  PRIVATE SECTION.
    "! A planned package of the parallel mode with the watermark after it
    TYPES:
      BEGIN OF ty_plan,
        package   TYPE zif_cd_ops_payout_types=>ty_package,
        watermark TYPE zif_cd_ops_payout_types=>ty_watermark,
        more      TYPE abap_bool,
        "! The watermark of its source already stands at the end of this package
        applied   TYPE abap_bool,
      END OF ty_plan.
    TYPES tt_plan TYPE STANDARD TABLE OF ty_plan WITH EMPTY KEY.

    "! A version with a finding written by this run and the flow + method class of its payment
    TYPES:
      BEGIN OF ty_flagged,
        version TYPE zif_cd_ops_payout_types=>ty_version,
        key     TYPE zif_cd_hck_runtime_types=>ty_flow_class,
      END OF ty_flagged.
    TYPES tt_flagged TYPE STANDARD TABLE OF ty_flagged WITH EMPTY KEY.

    "! What one package of documents comes to
    TYPES:
      BEGIN OF ty_judgement,
        documents TYPE i,
        evaluated TYPE i,
        close     TYPE zif_cd_ops_payout_types=>tt_version,
        insert    TYPE zif_cd_ops_payout_types=>tt_version,
        flagged   TYPE tt_flagged,
      END OF ty_judgement.

    DATA mo_dao TYPE REF TO zif_cd_ops_pay_outcome_dao.
    DATA mo_outcome TYPE REF TO zif_cd_ops_pay_outcome.
    DATA mo_store TYPE REF TO zif_cd_ops_store.
    DATA ms_config TYPE zif_cd_ops_payout_types=>ty_config.
    DATA mv_test_mode TYPE abap_bool.
    DATA mv_run_id TYPE zif_cd_ops_types=>ty_run_id.
    DATA mv_now TYPE zif_cd_ops_payout_types=>ty_timestamp.
    DATA mv_package TYPE i.
    DATA mv_max_packages TYPE i.
    DATA mv_initial_days TYPE i.
    DATA mv_parallel TYPE i.
    DATA mv_wait_sec TYPE i.
    DATA mv_examples TYPE i.
    "! Row cap of every evidence read (HCK_INFLIGHT_MAX_ROWS)
    DATA mv_cap TYPE i.
    "! Payment documents already judged (or planned) in this run (a document in several sources: once)
    DATA mt_done TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.
    "! Versions with a finding written by the packages judged in this process (one by one, test mode)
    DATA mt_flagged TYPE tt_flagged.

    METHODS execute
      IMPORTING
        iv_test_mode     TYPE abap_bool
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_cd_ops_error.

    METHODS read_parameters.

    "! PAYOUT_PARALLEL = 1 (and test mode): one package after the other, versions and watermark of a
    "! package in one commit
    METHODS process_source
      IMPORTING
        iv_source        TYPE zif_cd_ops_payout_types=>ty_source_id
        is_watermark     TYPE zif_cd_ops_payout_types=>ty_watermark
      RETURNING
        VALUE(rs_result) TYPE zif_cd_ops_payout_types=>ty_source_result.

    "! Judge one package and write its versions and watermark (one commit)
    METHODS process_package
      IMPORTING
        is_changes TYPE zif_cd_ops_payout_types=>ty_changes
      CHANGING
        cs_result  TYPE zif_cd_ops_payout_types=>ty_source_result
      RAISING
        zcx_cd_ops_error.

    "! PAYOUT_PARALLEL > 1: plan every source, judge the packages in waves of bgPF units, advance each
    "! watermark to the end of its last contiguous completed package after every wave
    METHODS process_parallel
      IMPORTING
        it_watermarks     TYPE zif_cd_ops_payout_types=>tt_watermark
      RETURNING
        VALUE(rt_results) TYPE zif_cd_ops_payout_types=>tt_source_result
      RAISING
        zcx_cd_ops_error.

    "! The packages of one source after its watermark (key reads only), documents of the run judged once
    METHODS plan_source
      IMPORTING
        iv_source       TYPE zif_cd_ops_payout_types=>ty_source_id
        is_watermark    TYPE zif_cd_ops_payout_types=>ty_watermark
      RETURNING
        VALUE(rt_plans) TYPE tt_plan.

    "! Dispatch one wave, wait for it (at most PAYOUT_PARALLEL_WAIT_SEC), take over the package status
    METHODS run_wave
      CHANGING
        ct_plans TYPE tt_plan
      RAISING
        zcx_cd_ops_error.

    "! Advance every source's watermark to the end of its last contiguous done package
    METHODS advance_watermarks
      CHANGING
        ct_plans TYPE tt_plan
      RAISING
        zcx_cd_ops_error.

    "! Payment documents of a change set: the documents, the statement references that are payment
    "! documents and the payment documents of the cheques referenced - without those already judged
    METHODS documents_of
      IMPORTING
        is_changes      TYPE zif_cd_ops_payout_types=>ty_changes
      RETURNING
        VALUE(rt_docno) TYPE zif_cd_ops_trace_types=>tt_docno.

    "! Verdicts, desired and current versions of the documents: what to close and insert
    METHODS judge
      IMPORTING
        it_docno            TYPE zif_cd_ops_trace_types=>tt_docno
      RETURNING
        VALUE(rs_judgement) TYPE ty_judgement
      RAISING
        zcx_cd_ops_error.

    "! Current versions wanted for the verdicts: one per item FIN, source, company code; one with FIN
    "! and source blank for a payment without an item with a FIN
    METHODS desired_versions
      IMPORTING
        is_evaluation      TYPE zif_cd_ops_payout_types=>ty_evaluation
        it_items           TYPE zif_cd_ops_payout_types=>tt_fin_item
        it_sources         TYPE zif_cd_ops_payout_types=>tt_fin_source
      RETURNING
        VALUE(rt_versions) TYPE zif_cd_ops_payout_types=>tt_version.

    "! First run of a source: PAYOUT_INITIAL_DAYS before today (statement: first line from then)
    METHODS initial_watermark
      IMPORTING
        iv_source           TYPE zif_cd_ops_payout_types=>ty_source_id
      RETURNING
        VALUE(rs_watermark) TYPE zif_cd_ops_payout_types=>ty_watermark.

    "! The watermark after a package with the instant up to which its source is processed: the run
    "! time when the source caught up, else the entry time of the watermark (system time zone), else
    "! (statement, recheck: no time) the instant kept from before
    METHODS processed_to
      IMPORTING
        is_watermark        TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_more             TYPE abap_bool
        iv_before           TYPE timestampl
      RETURNING
        VALUE(rs_watermark) TYPE zif_cd_ops_payout_types=>ty_watermark.

    "! One finding per flow + method class + finding code + run date of the versions with a finding
    "! written by this run (PAY_SOURCE_AMBIGUOUS): count of payments, first PAYOUT_EXAMPLES lines
    METHODS report_flagged
      IMPORTING
        it_flagged TYPE tt_flagged.

    "! Flow + method class of a method (DPAYH-PYMET) and flow indicator (TFK042Z-XEINZ)
    METHODS class_key
      IMPORTING
        iv_pymet      TYPE zif_cd_hck_runtime_types=>ty_pymet
        iv_xeinz      TYPE abap_bool
      RETURNING
        VALUE(rv_key) TYPE zif_cd_hck_runtime_types=>ty_flow_class.

    METHODS failure
      IMPORTING
        iv_source TYPE zif_cd_ops_payout_types=>ty_source_id
        iv_text   TYPE string.

    METHODS finish
      CHANGING
        cs_result TYPE ty_result
      RAISING
        zcx_cd_ops_error.

    METHODS release_lock.

    "! Evidence sources in processing order (the recheck last: it sees this run's versions)
    CLASS-METHODS sources
      RETURNING
        VALUE(rt_sources) TYPE string_table.

ENDCLASS.



CLASS zcl_cd_ops_pay_snapshot IMPLEMENTATION.

  METHOD run.
    DATA lv_holder TYPE syuname.
    IF iv_test_mode = abap_false.
      " An overlapping start of the 5-minute job is refused (RUN_LOCKED), never run twice
      IF zcl_cd_ops_factory=>get_lock( )->acquire( EXPORTING iv_pe_area = zif_cd_ops_types=>gc_pe_area-core
                                                             iv_variant = zif_cd_ops_payout_types=>gc_variant
                                                   IMPORTING ev_holder  = lv_holder ) = abap_false.
        DATA(ls_refusal) = zcl_cd_ops_run_guard=>refuse( iv_pe_area = zif_cd_ops_types=>gc_pe_area-core
                                                         iv_variant = zif_cd_ops_payout_types=>gc_variant
                                                         iv_holder  = lv_holder ).
        rs_result-run      = ls_refusal-run.
        rs_result-findings = ls_refusal-findings.
        RETURN.
      ENDIF.
    ENDIF.
    TRY.
        rs_result = execute( iv_test_mode ).
      CLEANUP.
        IF iv_test_mode = abap_false.
          release_lock( ).
        ENDIF.
    ENDTRY.
    IF iv_test_mode = abap_false.
      release_lock( ).
    ENDIF.
  ENDMETHOD.


  METHOD execute.
    CLEAR: mt_done, mt_findings, mt_flagged, ms_config.
    mv_test_mode = iv_test_mode.
    mo_store   = zcl_cd_ops_factory=>get_store( ).
    mo_dao     = zcl_cd_ops_factory=>get_pay_outcome_dao( ).
    mo_outcome = zcl_cd_ops_factory=>get_pay_outcome( ).
    rs_result-run = mo_store->start_run( iv_pe_area   = zif_cd_ops_types=>gc_pe_area-core
                                         iv_variant   = zif_cd_ops_payout_types=>gc_variant
                                         iv_test_mode = iv_test_mode ).
    IF iv_test_mode = abap_false.
      mo_store->commit( ).
    ENDIF.
    mv_run_id = rs_result-run-run_id.
    mv_now = trunc( zcl_cd_ops_factory=>get_clock( )->now( ) ).
    read_parameters( ).
    TRY.
        mv_cap = zcl_cd_ops_pay_outcome=>evidence_cap( ).
        ms_config = mo_outcome->load( iv_context  = zif_cd_ops_payout_types=>gc_context
                                      iv_max_rows = mv_cap ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        " No configuration: nothing can be judged, nothing is written
        failure( iv_source = space iv_text = lx_error->get_text( ) ).
        finish( CHANGING cs_result = rs_result ).
        RETURN.
    ENDTRY.

    DATA(lt_watermarks) = mo_dao->get_watermarks( ).
    IF mv_parallel > 1 AND iv_test_mode = abap_false.
      rs_result-sources = process_parallel( lt_watermarks ).
    ELSE.
      LOOP AT sources( ) ASSIGNING FIELD-SYMBOL(<lv_source>).
        DATA(lv_source) = CONV zif_cd_ops_payout_types=>ty_source_id( <lv_source> ).
        DATA(ls_watermark) = VALUE #( lt_watermarks[ source = lv_source ] OPTIONAL ).
        IF ls_watermark IS INITIAL.
          ls_watermark = initial_watermark( lv_source ).
        ENDIF.
        INSERT process_source( iv_source = lv_source is_watermark = ls_watermark ) INTO TABLE rs_result-sources.
      ENDLOOP.
      report_flagged( mt_flagged ).
    ENDIF.
    finish( CHANGING cs_result = rs_result ).
  ENDMETHOD.


  METHOD read_parameters.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    mv_package = nmax( val1 = 1
                       val2 = nmin( val1 = zcl_cd_ops_util=>param_int(
                                             io_params  = lo_params
                                             iv_name    = zif_cd_ops_payout_types=>gc_param-package_size
                                             iv_default = zif_cd_ops_payout_types=>gc_param_default-package_size )
                                    val2 = zif_cd_ops_payout_types=>gc_max_package ) ).
    mv_max_packages = nmax( val1 = 1
                            val2 = zcl_cd_ops_util=>param_int(
                                     io_params  = lo_params
                                     iv_name    = zif_cd_ops_payout_types=>gc_param-max_packages
                                     iv_default = zif_cd_ops_payout_types=>gc_param_default-max_packages ) ).
    mv_initial_days = nmax( val1 = 0
                            val2 = zcl_cd_ops_util=>param_int(
                                     io_params  = lo_params
                                     iv_name    = zif_cd_ops_payout_types=>gc_param-initial_days
                                     iv_default = zif_cd_ops_payout_types=>gc_param_default-initial_days ) ).
    mv_parallel = nmax( val1 = 1
                        val2 = nmin( val1 = zcl_cd_ops_util=>param_int(
                                              io_params  = lo_params
                                              iv_name    = zif_cd_ops_payout_types=>gc_param-parallel
                                              iv_default = zif_cd_ops_payout_types=>gc_param_default-parallel )
                                     val2 = zif_cd_ops_payout_types=>gc_max_parallel ) ).
    mv_wait_sec = nmax( val1 = zif_cd_ops_payout_types=>gc_poll_seconds
                        val2 = zcl_cd_ops_util=>param_int(
                                 io_params  = lo_params
                                 iv_name    = zif_cd_ops_payout_types=>gc_param-wait_sec
                                 iv_default = zif_cd_ops_payout_types=>gc_param_default-wait_sec ) ).
    mv_examples = nmax( val1 = 1
                        val2 = zcl_cd_ops_util=>param_int(
                                 io_params  = lo_params
                                 iv_name    = zif_cd_ops_payout_types=>gc_param-examples
                                 iv_default = zif_cd_ops_payout_types=>gc_param_default-examples ) ).
  ENDMETHOD.


  METHOD process_source.
    rs_result-source = iv_source.
    DATA(ls_watermark) = is_watermark.
    DO mv_max_packages TIMES.
      DATA(ls_changes) = mo_dao->get_changes( iv_source    = iv_source
                                              is_watermark = ls_watermark
                                              iv_max       = mv_package ).
      ls_changes-watermark-updated_at = mv_now.
      ls_changes-watermark-last_rows  = lines( ls_changes-docno ) + lines( ls_changes-refs ).
      ls_changes-watermark = processed_to( is_watermark = ls_changes-watermark
                                           iv_more      = ls_changes-more
                                           iv_before    = ls_watermark-current_to ).
      TRY.
          process_package( EXPORTING is_changes = ls_changes
                           CHANGING  cs_result  = rs_result ).
        CATCH zcx_cd_ops_error INTO DATA(lx_error).
          " Fail closed: nothing of the package is written, the watermark stays; the next run retries
          mo_store->rollback( ).
          failure( iv_source = iv_source iv_text = lx_error->get_text( ) ).
          RETURN.
      ENDTRY.
      rs_result-packages = rs_result-packages + 1.
      ls_watermark = ls_changes-watermark.
      rs_result-more = ls_changes-more.
      IF ls_changes-more = abap_false.
        RETURN.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD process_package.
    DATA(lt_judged) = documents_of( is_changes ).
    cs_result-documents = cs_result-documents + lines( lt_judged ).
    IF lt_judged IS NOT INITIAL.
      DATA(ls_judgement) = judge( lt_judged ).
      cs_result-evaluated = cs_result-evaluated + ls_judgement-evaluated.
      cs_result-closed    = cs_result-closed + lines( ls_judgement-close ).
      cs_result-inserted  = cs_result-inserted + lines( ls_judgement-insert ).
      INSERT LINES OF ls_judgement-flagged INTO TABLE mt_flagged.
      INSERT LINES OF lt_judged INTO TABLE mt_done.
    ENDIF.

    IF mv_test_mode = abap_true.
      RETURN.
    ENDIF.
    " Versions and watermark of the package are durable together
    IF lt_judged IS NOT INITIAL.
      mo_dao->save_versions( it_close = ls_judgement-close it_insert = ls_judgement-insert ).
    ENDIF.
    mo_dao->save_watermark( is_changes-watermark ).
    mo_store->commit( ).
  ENDMETHOD.


  METHOD documents_of.
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    " Statement references are payment documents (methods E G H I J K L) or cheque numbers
    lt_docno = is_changes-docno.
    LOOP AT is_changes-refs ASSIGNING FIELD-SYMBOL(<lv_ref>).
      IF strlen( condense( CONV string( <lv_ref> ) ) ) <= zif_cd_ops_payout_types=>gc_docno_length.
        INSERT CONV #( <lv_ref> ) INTO TABLE lt_docno.
      ENDIF.
    ENDLOOP.
    INSERT LINES OF mo_dao->get_cheque_documents( is_changes-refs ) INTO TABLE lt_docno.
    LOOP AT lt_docno ASSIGNING FIELD-SYMBOL(<lv_docno>).
      IF NOT line_exists( mt_done[ table_line = <lv_docno> ] ).
        INSERT <lv_docno> INTO TABLE rt_docno.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD judge.
    DATA lt_fin TYPE zif_cd_ops_payout_types=>tt_fin.
    DATA lt_desired_docs TYPE zif_cd_ops_trace_types=>tt_docno.
    rs_judgement-documents = lines( it_docno ).
    DATA(ls_evaluation) = mo_outcome->evaluate_documents( it_docno ).
    " A capped evidence read could hide evidence: the package is not judged (fail closed)
    READ TABLE ls_evaluation-findings ASSIGNING FIELD-SYMBOL(<ls_capped>)
         WITH KEY check_code = zif_cd_hck_runtime_types=>gc_code-read_capped.
    IF sy-subrc = 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e379(zcd_ops) WITH <ls_capped>-object_key mv_cap zif_cd_ops_payout_types=>gc_context.
    ENDIF.
    rs_judgement-evaluated = lines( ls_evaluation-verdicts ).
    LOOP AT ls_evaluation-verdicts ASSIGNING FIELD-SYMBOL(<ls_verdict>).
      INSERT <ls_verdict>-doc1r INTO TABLE lt_desired_docs.
    ENDLOOP.
    IF lt_desired_docs IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_items) = mo_dao->get_fin_items( lt_desired_docs ).
    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      INSERT <ls_item>-fin INTO TABLE lt_fin.
    ENDLOOP.
    DATA(lt_desired) = desired_versions( is_evaluation = ls_evaluation
                                         it_items      = lt_items
                                         it_sources    = mo_outcome->sources_of( lt_fin ) ).
    " The current versions of the judged payment documents, every FIN and source (index DOC)
    plan_versions( EXPORTING it_desired = lt_desired
                             it_open    = mo_dao->get_open_versions( lt_desired_docs )
                             iv_now     = mv_now
                   IMPORTING et_close   = rs_judgement-close
                             et_insert  = rs_judgement-insert ).
    LOOP AT rs_judgement-insert ASSIGNING FIELD-SYMBOL(<ls_new>)
         WHERE finding = zif_cd_ops_payout_types=>gc_code-source_ambiguous.
      READ TABLE ls_evaluation-verdicts ASSIGNING <ls_verdict> WITH KEY by_doc COMPONENTS doc1r = <ls_new>-augbl.
      IF sy-subrc = 0.
        INSERT VALUE #( version = <ls_new>
                        key     = |{ <ls_verdict>-flow }{ <ls_verdict>-class }| ) INTO TABLE rs_judgement-flagged.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD desired_versions.
    LOOP AT is_evaluation-verdicts ASSIGNING FIELD-SYMBOL(<ls_verdict>).
      DATA(ls_template) = VALUE zif_cd_ops_payout_types=>ty_version(
                            augbl         = <ls_verdict>-doc1r
                            laufd         = <ls_verdict>-laufd
                            laufi         = <ls_verdict>-laufi
                            valid_from    = mv_now
                            valid_to      = zif_cd_ops_payout_types=>gc_valid_to_open
                            evaluated_at  = mv_now ).
      DATA(lv_items) = 0.
      LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE augbl = <ls_verdict>-doc1r.
        lv_items = lv_items + 1.
        LOOP AT it_sources ASSIGNING FIELD-SYMBOL(<ls_source>) WHERE fin = <ls_item>-fin.
          DATA(ls_verdict) = mo_outcome->for_source( is_verdict = <ls_verdict> is_source = <ls_source> ).
          DATA(ls_version) = ls_template.
          ls_version-fin_id        = <ls_item>-fin.
          ls_version-source        = <ls_source>-source.
          ls_version-bukrs         = <ls_item>-bukrs.
          ls_version-laufd         = ls_verdict-laufd.
          ls_version-laufi         = ls_verdict-laufi.
          ls_version-outcome       = ls_verdict-outcome.
          ls_version-evidence_kind = ls_verdict-evidence_kind.
          ls_version-evidence_ref  = ls_verdict-evidence_ref.
          ls_version-finding       = ls_verdict-finding.
          ls_version-severity      = ls_verdict-severity.
          " The bank evidence decides, the status job has not followed: in flight with the marker (the
          " morning report's PAY_STATUS_LAG counts the grace from VALID_FROM of this version)
          IF ls_verdict-status_pending = abap_true AND ls_verdict-finding IS INITIAL.
            ls_version-finding = zif_cd_ops_payout_types=>gc_code-status_pending.
          ENDIF.
          INSERT ls_version INTO TABLE rt_versions.
        ENDLOOP.
      ENDLOOP.
      IF lv_items > 0.
        CONTINUE.
      ENDIF.
      " A payment without an item with a FIN (e.g. a collection): one version, FIN and source blank
      ls_version = ls_template.
      ls_version-bukrs         = <ls_verdict>-bukrs.
      ls_version-outcome       = <ls_verdict>-outcome.
      ls_version-evidence_kind = <ls_verdict>-evidence_kind.
      ls_version-evidence_ref  = <ls_verdict>-evidence_ref.
      ls_version-finding       = <ls_verdict>-finding.
      ls_version-severity      = <ls_verdict>-severity.
      IF <ls_verdict>-status_pending = abap_true AND <ls_verdict>-finding IS INITIAL.
        ls_version-finding = zif_cd_ops_payout_types=>gc_code-status_pending.
      ENDIF.
      INSERT ls_version INTO TABLE rt_versions.
    ENDLOOP.
  ENDMETHOD.


  METHOD plan_versions.
    CLEAR: et_close, et_insert.
    LOOP AT it_desired ASSIGNING FIELD-SYMBOL(<ls_desired>).
      READ TABLE it_open ASSIGNING FIELD-SYMBOL(<ls_open>)
           WITH KEY fin_id = <ls_desired>-fin_id source = <ls_desired>-source bukrs = <ls_desired>-bukrs
                    augbl  = <ls_desired>-augbl laufd = <ls_desired>-laufd laufi = <ls_desired>-laufi.
      IF sy-subrc = 0.
        " No change of the outcome and its finding: nothing is written (not even the evaluation time)
        IF <ls_open>-outcome = <ls_desired>-outcome AND <ls_open>-finding = <ls_desired>-finding.
          CONTINUE.
        ENDIF.
        DATA(ls_close) = <ls_open>.
        ls_close-valid_to = iv_now.
        INSERT ls_close INTO TABLE et_close.
      ENDIF.
      INSERT <ls_desired> INTO TABLE et_insert.
    ENDLOOP.
    " A current version of a judged payment that is no longer wanted (newer payment run, other
    " source attribution) is closed
    LOOP AT it_open ASSIGNING <ls_open>.
      IF line_exists( it_desired[ fin_id = <ls_open>-fin_id source = <ls_open>-source bukrs = <ls_open>-bukrs
                                  augbl  = <ls_open>-augbl laufd = <ls_open>-laufd laufi = <ls_open>-laufi ] ).
        CONTINUE.
      ENDIF.
      ls_close = <ls_open>.
      ls_close-valid_to = iv_now.
      INSERT ls_close INTO TABLE et_close.
    ENDLOOP.
  ENDMETHOD.


  METHOD process_parallel.
    DATA lt_plans TYPE tt_plan.
    " Packages of earlier runs are history (the run lock is held): only this run's rows stay
    DATA(lv_deleted) = mo_dao->delete_packages( mv_run_id ).
    IF lv_deleted > 0.
      mo_store->commit( ).
    ENDIF.
    mo_store->commit( ).
    LOOP AT sources( ) ASSIGNING FIELD-SYMBOL(<lv_source>).
      DATA(lv_source) = CONV zif_cd_ops_payout_types=>ty_source_id( <lv_source> ).
      DATA(ls_watermark) = VALUE #( it_watermarks[ source = lv_source ] OPTIONAL ).
      IF ls_watermark IS INITIAL.
        ls_watermark = initial_watermark( lv_source ).
      ENDIF.
      INSERT VALUE #( source = lv_source ) INTO TABLE rt_results.
      INSERT LINES OF plan_source( iv_source = lv_source is_watermark = ls_watermark ) INTO TABLE lt_plans.
    ENDLOOP.

    " Waves of PAYOUT_PARALLEL units until every package ran (or its source failed before it)
    WHILE line_exists( lt_plans[ package-status = zif_cd_ops_payout_types=>gc_pkg_status-planned ] ).
      run_wave( CHANGING ct_plans = lt_plans ).
      advance_watermarks( CHANGING ct_plans = lt_plans ).
    ENDWHILE.

    LOOP AT rt_results ASSIGNING FIELD-SYMBOL(<ls_result>).
      LOOP AT lt_plans ASSIGNING FIELD-SYMBOL(<ls_plan>) WHERE package-source = <ls_result>-source.
        <ls_result>-documents = <ls_result>-documents + lines( <ls_plan>-package-docno ).
        <ls_result>-evaluated = <ls_result>-evaluated + <ls_plan>-package-evaluated.
        <ls_result>-inserted  = <ls_result>-inserted + <ls_plan>-package-inserted.
        <ls_result>-closed    = <ls_result>-closed + <ls_plan>-package-closed.
        IF <ls_plan>-applied = abap_true.
          <ls_result>-packages = <ls_result>-packages + 1.
          <ls_result>-more     = <ls_plan>-more.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " Findings of the versions the units wrote: from the database (the units ran in other sessions)
    DATA(lt_flagged) = VALUE tt_flagged( ).
    LOOP AT mo_dao->get_new_versions( iv_valid_from = mv_now
                                      iv_finding    = zif_cd_ops_payout_types=>gc_code-source_ambiguous )
         ASSIGNING FIELD-SYMBOL(<ls_new>).
      INSERT VALUE #( version = <ls_new>-version
                      key     = class_key( iv_pymet = <ls_new>-pymet iv_xeinz = <ls_new>-xeinz ) ) INTO TABLE lt_flagged.
    ENDLOOP.
    report_flagged( lt_flagged ).
  ENDMETHOD.


  METHOD plan_source.
    DATA(ls_watermark) = is_watermark.
    DO mv_max_packages TIMES.
      DATA(ls_changes) = mo_dao->get_changes( iv_source    = iv_source
                                              is_watermark = ls_watermark
                                              iv_max       = mv_package ).
      ls_changes-watermark-updated_at = mv_now.
      ls_changes-watermark-last_rows  = lines( ls_changes-docno ) + lines( ls_changes-refs ).
      ls_changes-watermark = processed_to( is_watermark = ls_changes-watermark
                                           iv_more      = ls_changes-more
                                           iv_before    = ls_watermark-current_to ).
      DATA(ls_plan) = VALUE ty_plan( package-run_id = mv_run_id
                                     package-source = iv_source
                                     package-pkg_no = sy-index
                                     package-status = zif_cd_ops_payout_types=>gc_pkg_status-planned
                                     package-docno  = documents_of( ls_changes )
                                     watermark      = ls_changes-watermark
                                     more           = ls_changes-more ).
      INSERT LINES OF ls_plan-package-docno INTO TABLE mt_done.
      INSERT ls_plan INTO TABLE rt_plans.
      ls_watermark = ls_changes-watermark.
      IF ls_changes-more = abap_false.
        RETURN.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD run_wave.
    DATA lt_wave TYPE zif_cd_ops_payout_types=>tt_package.
    DATA lt_failed TYPE SORTED TABLE OF zif_cd_ops_payout_types=>ty_source_id WITH UNIQUE KEY table_line.
    " A source with a failed package is not continued in this run (its watermark cannot pass it)
    LOOP AT ct_plans ASSIGNING FIELD-SYMBOL(<ls_plan>)
         WHERE package-status = zif_cd_ops_payout_types=>gc_pkg_status-failed
            OR package-status = zif_cd_ops_payout_types=>gc_pkg_status-abandoned.
      INSERT <ls_plan>-package-source INTO TABLE lt_failed.
    ENDLOOP.
    LOOP AT ct_plans ASSIGNING <ls_plan> WHERE package-status = zif_cd_ops_payout_types=>gc_pkg_status-planned.
      IF line_exists( lt_failed[ table_line = <ls_plan>-package-source ] ).
        <ls_plan>-package-status = zif_cd_ops_payout_types=>gc_pkg_status-abandoned.
        CONTINUE.
      ENDIF.
      " A package without documents moves only its watermark: done without a unit
      IF <ls_plan>-package-docno IS INITIAL.
        <ls_plan>-package-status = zif_cd_ops_payout_types=>gc_pkg_status-done.
        CONTINUE.
      ENDIF.
      <ls_plan>-package-run_at = mv_now.
      INSERT <ls_plan>-package INTO TABLE lt_wave.
      IF lines( lt_wave ) >= mv_parallel.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF lt_wave IS INITIAL.
      RETURN.
    ENDIF.

    mo_dao->save_packages( lt_wave ).
    DATA(lo_queue) = zcl_cd_ops_factory=>get_pay_snap_queue( ).
    LOOP AT lt_wave ASSIGNING FIELD-SYMBOL(<ls_package>).
      TRY.
          lo_queue->dispatch( <ls_package> ).
        CATCH zcx_cd_ops_error INTO DATA(lx_error).
          " bgPF not available: the package is judged here, one by one (said once per run)
          IF NOT line_exists( mt_findings[ check_code = zif_cd_ops_payout_types=>gc_code-parallel_off ] ).
            INSERT VALUE #( object_type = zif_cd_ops_payout_types=>gc_object_type
                            object_key  = |{ zif_cd_ops_payout_types=>gc_context }/| &&
                                          |{ zif_cd_ops_payout_types=>gc_code-parallel_off }|
                            check_code  = zif_cd_ops_payout_types=>gc_code-parallel_off
                            severity    = zif_cd_ops_types=>gc_severity-warning
                            action      = zif_cd_ops_types=>gc_action-notify
                            message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-parallel_off
                                                                 iv_tail  = lx_error->get_text( ) ) ) INTO TABLE mt_findings.
          ENDIF.
          mo_store->commit( ).
          run_package( <ls_package> ).
      ENDTRY.
    ENDLOOP.
    " The units start with this commit
    mo_store->commit( ).

    " Wait for the wave; packages still planned after PAYOUT_PARALLEL_WAIT_SEC are abandoned (a unit
    " that has claimed its row finishes first: the claim locks the row)
    DATA(lv_waited) = 0.
    DO.
      DATA(lt_rows) = mo_dao->get_packages( mv_run_id ).
      DATA(lv_open) = abap_false.
      LOOP AT lt_wave ASSIGNING <ls_package>.
        IF VALUE #( lt_rows[ source = <ls_package>-source pkg_no = <ls_package>-pkg_no ]-status OPTIONAL )
           = zif_cd_ops_payout_types=>gc_pkg_status-planned.
          lv_open = abap_true.
        ENDIF.
      ENDLOOP.
      IF lv_open = abap_false.
        EXIT.
      ENDIF.
      IF lv_waited >= mv_wait_sec.
        IF mo_dao->abandon_packages( mv_run_id ) > 0.
          mo_store->commit( ).
        ENDIF.
        lt_rows = mo_dao->get_packages( mv_run_id ).
        EXIT.
      ENDIF.
      lo_queue->pause( zif_cd_ops_payout_types=>gc_poll_seconds ).
      lv_waited = lv_waited + zif_cd_ops_payout_types=>gc_poll_seconds.
    ENDDO.

    LOOP AT lt_wave ASSIGNING <ls_package>.
      DATA(ls_row) = VALUE #( lt_rows[ source = <ls_package>-source pkg_no = <ls_package>-pkg_no ] OPTIONAL ).
      READ TABLE ct_plans ASSIGNING <ls_plan>
           WITH KEY package-source = <ls_package>-source package-pkg_no = <ls_package>-pkg_no.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      <ls_plan>-package-status    = COND #( WHEN ls_row-status IS INITIAL
                                              OR ls_row-status = zif_cd_ops_payout_types=>gc_pkg_status-planned
                                            THEN zif_cd_ops_payout_types=>gc_pkg_status-abandoned
                                            ELSE ls_row-status ).
      <ls_plan>-package-evaluated = ls_row-evaluated.
      <ls_plan>-package-inserted  = ls_row-inserted.
      <ls_plan>-package-closed    = ls_row-closed.
      CASE <ls_plan>-package-status.
        WHEN zif_cd_ops_payout_types=>gc_pkg_status-failed.
          failure( iv_source = <ls_package>-source iv_text = CONV #( ls_row-message ) ).
        WHEN zif_cd_ops_payout_types=>gc_pkg_status-abandoned.
          failure( iv_source = <ls_package>-source
                   iv_text   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-pkg_abandoned
                                                      iv_v1    = <ls_package>-source
                                                      iv_v2    = <ls_package>-pkg_no
                                                      iv_v3    = mv_wait_sec ) ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD advance_watermarks.
    DATA lt_status TYPE tt_pkg_status.
    LOOP AT sources( ) ASSIGNING FIELD-SYMBOL(<lv_source>).
      DATA(lv_source) = CONV zif_cd_ops_payout_types=>ty_source_id( <lv_source> ).
      CLEAR lt_status.
      DATA(lv_applied) = 0.
      LOOP AT ct_plans ASSIGNING FIELD-SYMBOL(<ls_plan>) WHERE package-source = lv_source.
        INSERT <ls_plan>-package-status INTO TABLE lt_status.
        IF <ls_plan>-applied = abap_true.
          lv_applied = lv_applied + 1.
        ENDIF.
      ENDLOOP.
      " Ordered: only to the end of the last contiguous done package, never past a failed one
      DATA(lv_done) = contiguous_done( lt_status ).
      IF lv_done <= lv_applied.
        CONTINUE.
      ENDIF.
      DATA(lv_position) = 0.
      DATA(ls_watermark) = VALUE zif_cd_ops_payout_types=>ty_watermark( ).
      LOOP AT ct_plans ASSIGNING <ls_plan> WHERE package-source = lv_source.
        lv_position = lv_position + 1.
        IF lv_position > lv_done.
          EXIT.
        ENDIF.
        <ls_plan>-applied = abap_true.
        ls_watermark = <ls_plan>-watermark.
      ENDLOOP.
      mo_dao->save_watermark( ls_watermark ).
      mo_store->commit( ).
    ENDLOOP.
  ENDMETHOD.


  METHOD contiguous_done.
    LOOP AT it_status ASSIGNING FIELD-SYMBOL(<lv_status>).
      IF <lv_status> <> zif_cd_ops_payout_types=>gc_pkg_status-done.
        RETURN.
      ENDIF.
      rv_count = rv_count + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD run_package.
    DATA(ls_package) = is_package.
    mo_store   = zcl_cd_ops_factory=>get_store( ).
    mo_dao     = zcl_cd_ops_factory=>get_pay_outcome_dao( ).
    mo_outcome = zcl_cd_ops_factory=>get_pay_outcome( ).
    mv_now     = is_package-run_at.
    TRY.
        mv_cap = zcl_cd_ops_pay_outcome=>evidence_cap( ).
        mo_outcome->load( iv_context  = zif_cd_ops_payout_types=>gc_context
                          iv_max_rows = mv_cap ).
        DATA(ls_judgement) = judge( is_package-docno ).
        " An abandoned package (the run stopped waiting) writes nothing
        IF mo_dao->claim_package( ls_package ) = abap_false.
          mo_store->rollback( ).
          RETURN.
        ENDIF.
        mo_dao->save_versions( it_close = ls_judgement-close it_insert = ls_judgement-insert ).
        ls_package-status    = zif_cd_ops_payout_types=>gc_pkg_status-done.
        ls_package-evaluated = ls_judgement-evaluated.
        ls_package-inserted  = lines( ls_judgement-insert ).
        ls_package-closed    = lines( ls_judgement-close ).
        mo_dao->finish_package( ls_package ).
        mo_store->commit( ).
      CATCH cx_root INTO DATA(lx_error).
        " Fail closed: nothing of the package is written; the run keeps the watermark before it
        mo_store->rollback( ).
        ls_package-status  = zif_cd_ops_payout_types=>gc_pkg_status-failed.
        ls_package-message = lx_error->get_text( ).
        TRY.
            IF mo_dao->claim_package( ls_package ) = abap_true.
              mo_dao->finish_package( ls_package ).
            ENDIF.
            mo_store->commit( ).
          CATCH zcx_cd_ops_error.
            " The run sees the package still planned and abandons it after its wait
            mo_store->rollback( ).
        ENDTRY.
    ENDTRY.
  ENDMETHOD.


  METHOD processed_to.
    rs_watermark = is_watermark.
    IF iv_more = abap_false.
      " Caught up: every evidence of the source up to this run is processed
      rs_watermark-current_to = mv_now.
      RETURN.
    ENDIF.
    rs_watermark-current_to = iv_before.
    IF is_watermark-wm_date IS NOT INITIAL AND is_watermark-source <> zif_cd_ops_payout_types=>gc_source-statement
       AND is_watermark-source <> zif_cd_ops_payout_types=>gc_source-recheck.
      " Behind: processed up to the entry time of the last evidence read (system time zone)
      CONVERT DATE is_watermark-wm_date TIME is_watermark-wm_time
        INTO TIME STAMP rs_watermark-current_to TIME ZONE sy-zonlo.
      IF sy-subrc <> 0.
        rs_watermark-current_to = iv_before.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD lag.
    LOOP AT it_watermarks ASSIGNING FIELD-SYMBOL(<ls_watermark>)
         WHERE source <> zif_cd_ops_payout_types=>gc_source-recheck
           AND current_to IS NOT INITIAL.
      IF rs_lag-known = abap_false OR <ls_watermark>-current_to < rs_lag-current_to.
        rs_lag-known      = abap_true.
        rs_lag-source     = <ls_watermark>-source.
        rs_lag-current_to = <ls_watermark>-current_to.
      ENDIF.
    ENDLOOP.
    IF rs_lag-known = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_seconds) = cl_abap_tstmp=>subtract( tstmp1 = iv_now tstmp2 = rs_lag-current_to ).
    rs_lag-minutes = nmax( val1 = 0 val2 = floor( lv_seconds / 60 ) ).
  ENDMETHOD.


  METHOD report_flagged.
    DATA lt_details TYPE string_table.
    DATA lt_payments TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_docno WITH UNIQUE KEY table_line.
    DATA(lt_sorted) = it_flagged.
    SORT lt_sorted BY key version-finding version-laufd version-augbl version-fin_id version-source.
    LOOP AT lt_sorted ASSIGNING FIELD-SYMBOL(<ls_first>)
         GROUP BY ( key     = <ls_first>-key
                    finding = <ls_first>-version-finding
                    laufd   = <ls_first>-version-laufd ) ASSIGNING FIELD-SYMBOL(<ls_group>).
      CLEAR: lt_details, lt_payments.
      DATA(lv_rows) = 0.
      LOOP AT GROUP <ls_group> ASSIGNING FIELD-SYMBOL(<ls_member>).
        lv_rows = lv_rows + 1.
      ENDLOOP.
      INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-examples_head
                                    iv_v1    = nmin( val1 = mv_examples val2 = lv_rows )
                                    iv_v2    = lv_rows ) INTO TABLE lt_details.
      LOOP AT GROUP <ls_group> ASSIGNING <ls_member>.
        INSERT <ls_member>-version-augbl INTO TABLE lt_payments.
        IF lines( lt_details ) <= mv_examples.
          INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-ambiguous_line
                                        iv_v1    = <ls_member>-version-fin_id
                                        iv_v2    = <ls_member>-version-source
                                        iv_v3    = <ls_member>-version-augbl
                                        iv_tail  = CONV string( <ls_member>-version-evidence_ref ) ) INTO TABLE lt_details.
        ENDIF.
      ENDLOOP.
      INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-drill_down
                                    iv_v1    = <ls_group>-finding
                                    iv_v2    = |{ <ls_group>-laufd DATE = ISO }| ) INTO TABLE lt_details.
      INSERT VALUE #( object_type = zif_cd_ops_payout_types=>gc_object_type
                      object_key  = |{ zif_cd_ops_payout_types=>gc_context }/{ <ls_group>-key }/| &&
                                    |{ <ls_group>-finding }/{ <ls_group>-laufd }|
                      group1      = <ls_group>-key
                      group2      = |{ <ls_group>-laufd }|
                      check_code  = <ls_group>-finding
                      severity    = zif_cd_ops_types=>gc_severity-warning
                      action      = zif_cd_ops_types=>gc_action-notify
                      reference   = <ls_group>-key
                      message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-aggregated
                                                           iv_v1    = <ls_group>-key
                                                           iv_v2    = |{ <ls_group>-laufd DATE = ISO }|
                                                           iv_v3    = lines( lt_payments )
                                                           iv_v4    = <ls_group>-finding )
                      details     = concat_lines_of( table = lt_details sep = cl_abap_char_utilities=>newline ) )
             INTO TABLE mt_findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD class_key.
    DATA(lv_flow) = COND zif_cd_hck_runtime_types=>ty_flow( WHEN iv_xeinz = abap_true
                                                              THEN zif_cd_hck_runtime_types=>gc_flow-collection
                                                            ELSE zif_cd_hck_runtime_types=>gc_flow-disbursement ).
    rv_key = |{ lv_flow }{ VALUE #( ms_config-methods[ flow = lv_flow pymet = iv_pymet ]-class OPTIONAL ) }|.
  ENDMETHOD.


  METHOD initial_watermark.
    rs_watermark-source = iv_source.
    IF iv_source = zif_cd_ops_payout_types=>gc_source-recheck.
      RETURN.
    ENDIF.
    " History starts at go-live: the first run reads the last PAYOUT_INITIAL_DAYS days once
    rs_watermark-wm_date = zcl_cd_ops_factory=>get_clock( )->today( ) - mv_initial_days.
  ENDMETHOD.


  METHOD failure.
    INSERT VALUE #( object_type = zif_cd_ops_payout_types=>gc_object_type
                    object_key  = |{ zif_cd_ops_payout_types=>gc_context }/{ iv_source }|
                    check_code  = zif_cd_ops_payout_types=>gc_code-snapshot_failed
                    severity    = zif_cd_ops_types=>gc_severity-error
                    action      = zif_cd_ops_types=>gc_action-notify
                    message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-snapshot_failed
                                                         iv_v1    = iv_source
                                                         iv_tail  = iv_text ) ) INTO TABLE mt_findings.
  ENDMETHOD.


  METHOD finish.
    cs_result-findings = mt_findings.
    LOOP AT cs_result-sources ASSIGNING FIELD-SYMBOL(<ls_source>).
      cs_result-run-total_items  = cs_result-run-total_items + <ls_source>-documents.
      cs_result-run-passed_items = cs_result-run-passed_items + <ls_source>-evaluated.
    ENDLOOP.
    cs_result-run-status = COND #( WHEN line_exists( mt_findings[ severity = zif_cd_ops_types=>gc_severity-error ] )
                                     THEN zif_cd_ops_types=>gc_run_status-error
                                   WHEN mt_findings IS NOT INITIAL
                                     THEN zif_cd_ops_types=>gc_run_status-warning
                                   ELSE zif_cd_ops_types=>gc_run_status-success ).
    cs_result-run-rag = SWITCH #( cs_result-run-status
                                  WHEN zif_cd_ops_types=>gc_run_status-error   THEN zif_cd_ops_types=>gc_rag-red
                                  WHEN zif_cd_ops_types=>gc_run_status-warning THEN zif_cd_ops_types=>gc_rag-amber
                                  ELSE zif_cd_ops_types=>gc_rag-green ).
    cs_result-run-ended_at = zcl_cd_ops_factory=>get_clock( )->now( ).
    IF mo_dao IS BOUND.
      cs_result-lag = lag( it_watermarks = mo_dao->get_watermarks( )
                           iv_now        = cs_result-run-ended_at ).
    ENDIF.
    IF mt_findings IS NOT INITIAL.
      mo_store->save_findings( EXPORTING it_findings = mt_findings
                               CHANGING  cs_run      = cs_result-run ).
    ENDIF.
    mo_store->finish_run( cs_result-run ).
    IF mv_test_mode = abap_false.
      mo_store->commit( ).
    ENDIF.
  ENDMETHOD.


  METHOD sources.
    rt_sources = VALUE #( ( CONV #( zif_cd_ops_payout_types=>gc_source-documents ) )
                          ( CONV #( zif_cd_ops_payout_types=>gc_source-reversals ) )
                          ( CONV #( zif_cd_ops_payout_types=>gc_source-statement ) )
                          ( CONV #( zif_cd_ops_payout_types=>gc_source-returns ) )
                          ( CONV #( zif_cd_ops_payout_types=>gc_source-gl ) )
                          ( CONV #( zif_cd_ops_payout_types=>gc_source-recheck ) ) ).
  ENDMETHOD.


  METHOD release_lock.
    zcl_cd_ops_factory=>get_lock( )->release( iv_pe_area = zif_cd_ops_types=>gc_pe_area-core
                                              iv_variant = zif_cd_ops_payout_types=>gc_variant ).
  ENDMETHOD.

ENDCLASS.
