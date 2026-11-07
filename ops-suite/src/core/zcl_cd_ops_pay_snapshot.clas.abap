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
*& only when the outcome changed (the current one is closed); otherwise
*& nothing. A FIN in two sources is AMBIGUOUS for both (finding
*& PAY_SOURCE_AMBIGUOUS). Each package commits its versions and its watermark
*& together (through the store); a package that cannot be judged completely
*& (configuration, capped read) writes nothing and keeps the watermark
*& (PAY_OUTCOME_FAILED). Run lock per variant; test mode writes nothing.
*& Read-only towards business tables.
*& Modification log:
*& 2026-11-07 | Initial version (incremental 5-minute payment outcome snapshot).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - incremental 5-minute snapshot</p>
"! Parameters (ZCA_PARAM, CD_OPS): PAYOUT_PACKAGE_SIZE, PAYOUT_MAX_PACKAGES, PAYOUT_INITIAL_DAYS;
"! evidence row cap HCK_INFLIGHT_MAX_ROWS (as A_INFLIGHT).
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
      END OF ty_result.

    "! One snapshot run over every evidence source
    "! @raising zcx_cd_ops_error | run header or run end could not be written
    METHODS run
      IMPORTING
        iv_test_mode     TYPE abap_bool
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_cd_ops_error.

    "! Versions to close and to insert so that the current versions of the evaluated payment
    "! documents equal the desired ones: same key and outcome = nothing; other outcome = close +
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

  PRIVATE SECTION.
    DATA mo_dao TYPE REF TO zif_cd_ops_pay_outcome_dao.
    DATA mo_outcome TYPE REF TO zif_cd_ops_pay_outcome.
    DATA mo_store TYPE REF TO zif_cd_ops_store.
    DATA mv_test_mode TYPE abap_bool.
    DATA mv_now TYPE zif_cd_ops_payout_types=>ty_timestamp.
    DATA mv_package TYPE i.
    DATA mv_max_packages TYPE i.
    DATA mv_initial_days TYPE i.
    "! Row cap of every evidence read (HCK_INFLIGHT_MAX_ROWS)
    DATA mv_cap TYPE i.
    "! Payment documents already judged in this run (a document in several sources: once)
    DATA mt_done TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.

    METHODS execute
      IMPORTING
        iv_test_mode     TYPE abap_bool
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_cd_ops_error.

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

    "! Current versions wanted for the verdicts: one per item FIN, source, company code
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
    CLEAR: mt_done, mt_findings.
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
    mv_now = trunc( zcl_cd_ops_factory=>get_clock( )->now( ) ).
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
    TRY.
        mv_cap = zcl_cd_ops_pay_outcome=>evidence_cap( ).
        mo_outcome->load( iv_context  = zif_cd_ops_payout_types=>gc_context
                          iv_max_rows = mv_cap ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        " No configuration: nothing can be judged, nothing is written
        failure( iv_source = space iv_text = lx_error->get_text( ) ).
        finish( CHANGING cs_result = rs_result ).
        RETURN.
    ENDTRY.

    DATA(lt_watermarks) = mo_dao->get_watermarks( ).
    LOOP AT sources( ) ASSIGNING FIELD-SYMBOL(<lv_source>).
      DATA(lv_source) = CONV zif_cd_ops_payout_types=>ty_source_id( <lv_source> ).
      DATA(ls_watermark) = VALUE #( lt_watermarks[ source = lv_source ] OPTIONAL ).
      IF ls_watermark IS INITIAL.
        ls_watermark = initial_watermark( lv_source ).
      ENDIF.
      INSERT process_source( iv_source = lv_source is_watermark = ls_watermark ) INTO TABLE rs_result-sources.
    ENDLOOP.
    finish( CHANGING cs_result = rs_result ).
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
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA lt_judged TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA lt_fin TYPE zif_cd_ops_payout_types=>tt_fin.
    DATA lt_desired_docs TYPE zif_cd_ops_trace_types=>tt_docno.

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
        INSERT <lv_docno> INTO TABLE lt_judged.
      ENDIF.
    ENDLOOP.
    cs_result-documents = cs_result-documents + lines( lt_judged ).

    IF lt_judged IS NOT INITIAL.
      DATA(ls_evaluation) = mo_outcome->evaluate_documents( lt_judged ).
      " A capped evidence read could hide evidence: the package is not judged (fail closed)
      READ TABLE ls_evaluation-findings ASSIGNING FIELD-SYMBOL(<ls_capped>)
           WITH KEY check_code = zif_cd_hck_runtime_types=>gc_code-read_capped.
      IF sy-subrc = 0.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e379(zcd_ops) WITH <ls_capped>-object_key mv_cap zif_cd_ops_payout_types=>gc_context.
      ENDIF.
      cs_result-evaluated = cs_result-evaluated + lines( ls_evaluation-verdicts ).
      LOOP AT ls_evaluation-verdicts ASSIGNING FIELD-SYMBOL(<ls_verdict>).
        INSERT <ls_verdict>-doc1r INTO TABLE lt_desired_docs.
      ENDLOOP.
      DATA(lt_items) = mo_dao->get_fin_items( lt_desired_docs ).
      LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
        INSERT <ls_item>-fin INTO TABLE lt_fin.
      ENDLOOP.
      DATA(lt_desired) = desired_versions( is_evaluation = ls_evaluation
                                           it_items      = lt_items
                                           it_sources    = mo_outcome->sources_of( lt_fin ) ).
      " Only the current versions of the judged payments are compared (other payments of the FIN stay)
      DATA(lt_open) = VALUE zif_cd_ops_payout_types=>tt_version( ).
      LOOP AT mo_dao->get_open_versions( lt_fin ) ASSIGNING FIELD-SYMBOL(<ls_open>).
        IF line_exists( lt_desired_docs[ table_line = <ls_open>-augbl ] ).
          INSERT <ls_open> INTO TABLE lt_open.
        ENDIF.
      ENDLOOP.
      plan_versions( EXPORTING it_desired = lt_desired
                               it_open    = lt_open
                               iv_now     = mv_now
                     IMPORTING et_close   = DATA(lt_close)
                               et_insert  = DATA(lt_insert) ).
      cs_result-closed   = cs_result-closed + lines( lt_close ).
      cs_result-inserted = cs_result-inserted + lines( lt_insert ).
      DATA(lt_new_findings) = VALUE zif_cd_ops_types=>tt_finding( ).
      LOOP AT lt_insert ASSIGNING FIELD-SYMBOL(<ls_new>)
           WHERE finding = zif_cd_ops_payout_types=>gc_code-source_ambiguous.
        INSERT VALUE #( object_type = zif_cd_ops_payout_types=>gc_object_type
                        object_key  = |{ <ls_new>-fin_id }/{ <ls_new>-source }|
                        group1      = <ls_new>-bukrs
                        group2      = <ls_new>-augbl
                        check_code  = <ls_new>-finding
                        severity    = zif_cd_ops_types=>gc_severity-warning
                        action      = zif_cd_ops_types=>gc_action-notify
                        reference   = <ls_new>-augbl
                        message     = <ls_new>-evidence_ref ) INTO TABLE lt_new_findings.
      ENDLOOP.
      INSERT LINES OF lt_new_findings INTO TABLE mt_findings.
      INSERT LINES OF lt_judged INTO TABLE mt_done.
    ENDIF.

    IF mv_test_mode = abap_true.
      RETURN.
    ENDIF.
    " Versions and watermark of the package are durable together
    IF lt_judged IS NOT INITIAL.
      mo_dao->save_versions( it_close = lt_close it_insert = lt_insert ).
    ENDIF.
    mo_dao->save_watermark( is_changes-watermark ).
    mo_store->commit( ).
  ENDMETHOD.


  METHOD desired_versions.
    LOOP AT is_evaluation-verdicts ASSIGNING FIELD-SYMBOL(<ls_verdict>).
      LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE augbl = <ls_verdict>-doc1r.
        LOOP AT it_sources ASSIGNING FIELD-SYMBOL(<ls_source>) WHERE fin = <ls_item>-fin.
          DATA(ls_verdict) = mo_outcome->for_source( is_verdict = <ls_verdict> is_source = <ls_source> ).
          INSERT VALUE #( fin_id        = <ls_item>-fin
                          source        = <ls_source>-source
                          bukrs         = <ls_item>-bukrs
                          augbl         = <ls_item>-augbl
                          laufd         = ls_verdict-laufd
                          laufi         = ls_verdict-laufi
                          valid_from    = mv_now
                          valid_to      = zif_cd_ops_payout_types=>gc_valid_to_open
                          outcome       = ls_verdict-outcome
                          evidence_kind = ls_verdict-evidence_kind
                          evidence_ref  = ls_verdict-evidence_ref
                          finding       = ls_verdict-finding
                          evaluated_at  = mv_now ) INTO TABLE rt_versions.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD plan_versions.
    CLEAR: et_close, et_insert.
    LOOP AT it_desired ASSIGNING FIELD-SYMBOL(<ls_desired>).
      READ TABLE it_open ASSIGNING FIELD-SYMBOL(<ls_open>)
           WITH KEY fin_id = <ls_desired>-fin_id source = <ls_desired>-source bukrs = <ls_desired>-bukrs
                    augbl  = <ls_desired>-augbl laufd = <ls_desired>-laufd laufi = <ls_desired>-laufi.
      IF sy-subrc = 0.
        " No change of the outcome: nothing is written (not even the evaluation time)
        IF <ls_open>-outcome = <ls_desired>-outcome.
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
