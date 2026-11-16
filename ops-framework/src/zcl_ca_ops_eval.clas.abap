*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_eval.clas.abap
*& Purpose:
*& Rules of the evaluation state of a check run (docs/EVALUATION_AND_
*& COVERAGE.md), without database: the earlier vocabularies mapped onto
*& the one of the framework (build K's day results OK / ZERO_OK / HOLIDAY
*& / STALE / NOT_EVAL / MISSING / PARTIAL / PENDING, build N's OBSERVED /
*& ZERO_VOLUME / NOT_EXPECTED / STALE / NOT_EVALUATED), the fold of a
*& check's terms and sources into its optional result part, and the record
*& the runner stores for every check and run: expected scope (business
*& date, period, company codes), source freshness against its limit,
*& watermark, completeness (raised = not evaluated, PARTIAL = partial),
*& result class (no exception = OK, else FINDINGS; a stale source turns a
*& zero into STALE, a closed period into PER_CLOSED), the display state
*& (completeness first - unknown is never shown as OK) and the reason text.
*& The CDS views of the dashboard and the daily review read the stored
*& display state; ABAP Unit proves the rules here.
*& Modification log:
*& 2026-11-16 | Initial version (build O: evaluation state of every control).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - evaluation state rules</p>
CLASS zcl_ca_ops_eval DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! What a term of an earlier vocabulary means: its result class (blank = no contribution), and whether the term
    "! stands for something evaluated or for something that could not be evaluated
    TYPES:
      BEGIN OF ty_term_result,
        state       TYPE zif_ca_ops_eval_types=>ty_state,
        evaluated   TYPE abap_bool,
        unevaluated TYPE abap_bool,
      END OF ty_term_result.

    "! Map a term: build K's day results, build N's evaluations and this vocabulary's own states.
    "! iv_exception = the term comes with an owned exception (B / E / W): an observed source then gives FINDINGS
    CLASS-METHODS of_term
      IMPORTING
        iv_term          TYPE clike
        iv_exception     TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_result) TYPE ty_term_result.

    "! Fold one term into the result part of a check: the worse class wins, evaluated / not evaluated counted
    CLASS-METHODS merge_term
      IMPORTING
        iv_term      TYPE clike
        iv_exception TYPE abap_bool DEFAULT abap_false
      CHANGING
        cs_eval      TYPE zif_ca_ops_eval_types=>ty_check_eval.

    "! A source the check names with its newest observation (the newest is kept per source; 0 = default limit)
    CLASS-METHODS add_source
      IMPORTING
        iv_source_id TYPE clike
        iv_newest_at TYPE timestampl
        iv_stale_min TYPE i DEFAULT 0
      CHANGING
        cs_eval      TYPE zif_ca_ops_eval_types=>ty_check_eval.

    "! Rank of a state, higher = worse: OK 0, ZERO_OK 1, HOLIDAY 2, PER_CLOSED 3, FINDINGS 4, PARTIAL 5, STALE 6,
    "! NOT_EVAL (and blank) 7
    CLASS-METHODS rank
      IMPORTING
        iv_state       TYPE clike
      RETURNING
        VALUE(rv_rank) TYPE i.

    CLASS-METHODS worse_of
      IMPORTING
        iv_one          TYPE clike
        iv_other        TYPE clike
      RETURNING
        VALUE(rv_state) TYPE zif_ca_ops_eval_types=>ty_state.

    "! The one state support sees: not evaluated, then stale, then partial, else the result class
    CLASS-METHODS display_state
      IMPORTING
        iv_class        TYPE clike
        iv_cmpl         TYPE clike
      RETURNING
        VALUE(rv_state) TYPE zif_ca_ops_eval_types=>ty_state.

    "! NOT_EVAL, STALE, PARTIAL or blank: never shown as healthy, never signed off as healthy without a reason
    CLASS-METHODS is_unknown
      IMPORTING
        iv_state          TYPE clike
      RETURNING
        VALUE(rv_unknown) TYPE abap_bool.

    "! Severity B / E / W: an owned exception
    CLASS-METHODS is_exception
      IMPORTING
        iv_severity         TYPE zif_ca_ops_types=>ty_severity
      RETURNING
        VALUE(rv_exception) TYPE abap_bool.

    "! Calendar period YYYYMM of a date (the default of a check that names no period)
    CLASS-METHODS period_of
      IMPORTING
        iv_date          TYPE d
      RETURNING
        VALUE(rv_period) TYPE zif_ca_ops_eval_types=>ty_period.

    "! Expected scope of a run: the check's business date, else the run's date; its period, else that date's month
    CLASS-METHODS scope
      IMPORTING
        is_eval     TYPE zif_ca_ops_eval_types=>ty_check_eval
        iv_today    TYPE d
      EXPORTING
        ev_bus_date TYPE d
        ev_period   TYPE zif_ca_ops_eval_types=>ty_period.

    "! The evaluation record of one check run (defaults from TY_RESULT for a check that reports nothing new)
    CLASS-METHODS derive
      IMPORTING
        is_input       TYPE zif_ca_ops_eval_types=>ty_derive_input
        is_result      TYPE zif_ca_ops_chk_types=>ty_result
      RETURNING
        VALUE(rs_eval) TYPE zif_ca_ops_eval_types=>ty_eval.

    "! The record of a check that was not run (licence refused, business process not in effect): not evaluated
    CLASS-METHODS not_run
      IMPORTING
        is_input       TYPE zif_ca_ops_eval_types=>ty_derive_input
        iv_reason_code TYPE zif_ca_ops_eval_types=>ty_reason_code
        iv_reason      TYPE clike
      RETURNING
        VALUE(rs_eval) TYPE zif_ca_ops_eval_types=>ty_eval.

    "! X = the source's newest observation is older than its limit in minutes, or nothing was observed
    CLASS-METHODS is_stale
      IMPORTING
        iv_newest_at    TYPE timestampl
        iv_now          TYPE timestampl
        iv_stale_min    TYPE i
      RETURNING
        VALUE(rv_stale) TYPE abap_bool.

  PRIVATE SECTION.
    "! Record fields every record carries (identity, run, licence)
    CLASS-METHODS header
      IMPORTING
        is_input       TYPE zif_ca_ops_eval_types=>ty_derive_input
      RETURNING
        VALUE(rs_eval) TYPE zif_ca_ops_eval_types=>ty_eval.

    CLASS-METHODS completeness
      IMPORTING
        is_input       TYPE zif_ca_ops_eval_types=>ty_derive_input
        is_result      TYPE zif_ca_ops_chk_types=>ty_result
      RETURNING
        VALUE(rv_cmpl) TYPE zif_ca_ops_eval_types=>ty_cmpl.

    "! Sources with their limit and verdict; the oldest newest observation and its source
    CLASS-METHODS freshness
      IMPORTING
        is_input TYPE zif_ca_ops_eval_types=>ty_derive_input
      CHANGING
        cs_eval  TYPE zif_ca_ops_eval_types=>ty_eval.

    "! Reason code and text of a record that is not complete, stale or in a closed period (blank otherwise)
    CLASS-METHODS reason
      IMPORTING
        is_input TYPE zif_ca_ops_eval_types=>ty_derive_input
      CHANGING
        cs_eval  TYPE zif_ca_ops_eval_types=>ty_eval.

ENDCLASS.



CLASS zcl_ca_ops_eval IMPLEMENTATION.

  METHOD of_term.
    DATA(lv_term) = to_upper( condense( CONV string( iv_term ) ) ).
    CASE lv_term.
      WHEN zif_ca_ops_eval_types=>gc_state-ok OR zif_ca_ops_eval_types=>gc_term-observed.
        rs_result = VALUE #( state     = COND #( WHEN iv_exception = abap_true
                                                 THEN zif_ca_ops_eval_types=>gc_state-findings
                                                 ELSE zif_ca_ops_eval_types=>gc_state-ok )
                             evaluated = abap_true ).
      WHEN zif_ca_ops_eval_types=>gc_state-zero_ok OR zif_ca_ops_eval_types=>gc_term-zero_volume.
        rs_result = VALUE #( state = zif_ca_ops_eval_types=>gc_state-zero_ok evaluated = abap_true ).
      WHEN zif_ca_ops_eval_types=>gc_state-holiday OR zif_ca_ops_eval_types=>gc_term-not_expected.
        rs_result = VALUE #( state = zif_ca_ops_eval_types=>gc_state-holiday evaluated = abap_true ).
      WHEN zif_ca_ops_eval_types=>gc_state-period_closed.
        rs_result = VALUE #( state = zif_ca_ops_eval_types=>gc_state-period_closed evaluated = abap_true ).
      WHEN zif_ca_ops_eval_types=>gc_state-stale.
        rs_result = VALUE #( state = zif_ca_ops_eval_types=>gc_state-stale evaluated = abap_true ).
      WHEN zif_ca_ops_eval_types=>gc_state-findings OR zif_ca_ops_eval_types=>gc_term-day_missing
        OR zif_ca_ops_eval_types=>gc_term-day_partial.
        " build K: MISSING / PARTIAL days are business findings (fewer files than expected), not a partial evaluation
        rs_result = VALUE #( state = zif_ca_ops_eval_types=>gc_state-findings evaluated = abap_true ).
      WHEN zif_ca_ops_eval_types=>gc_state-not_evaluated OR zif_ca_ops_eval_types=>gc_term-not_evaluated_n.
        rs_result-unevaluated = abap_true.
      WHEN OTHERS.
        " PENDING (deadline not passed) and unknown terms: no verdict, no contribution
        CLEAR rs_result.
    ENDCASE.
  ENDMETHOD.


  METHOD merge_term.
    DATA(ls_term) = of_term( iv_term = iv_term iv_exception = iv_exception ).
    IF ls_term-evaluated = abap_true.
      cs_eval-evaluated += 1.
      cs_eval-result_class = COND #( WHEN cs_eval-result_class IS INITIAL THEN ls_term-state
                                     ELSE worse_of( iv_one = cs_eval-result_class iv_other = ls_term-state ) ).
    ELSEIF ls_term-unevaluated = abap_true.
      cs_eval-unevaluated += 1.
    ENDIF.
  ENDMETHOD.


  METHOD add_source.
    DATA(lv_id) = CONV zif_ca_ops_eval_types=>ty_source_id( to_upper( condense( CONV string( iv_source_id ) ) ) ).
    ASSIGN cs_eval-sources[ source_id = lv_id ] TO FIELD-SYMBOL(<ls_source>).
    IF sy-subrc <> 0.
      INSERT VALUE #( source_id = lv_id newest_at = iv_newest_at stale_min = iv_stale_min ) INTO TABLE cs_eval-sources.
      RETURN.
    ENDIF.
    IF iv_newest_at > <ls_source>-newest_at.
      <ls_source>-newest_at = iv_newest_at.
    ENDIF.
    IF iv_stale_min > 0.
      <ls_source>-stale_min = iv_stale_min.
    ENDIF.
  ENDMETHOD.


  METHOD rank.
    rv_rank = SWITCH #( to_upper( condense( CONV string( iv_state ) ) )
                        WHEN zif_ca_ops_eval_types=>gc_state-ok            THEN 0
                        WHEN zif_ca_ops_eval_types=>gc_state-zero_ok       THEN 1
                        WHEN zif_ca_ops_eval_types=>gc_state-holiday       THEN 2
                        WHEN zif_ca_ops_eval_types=>gc_state-period_closed THEN 3
                        WHEN zif_ca_ops_eval_types=>gc_state-findings      THEN 4
                        WHEN zif_ca_ops_eval_types=>gc_state-partial       THEN 5
                        WHEN zif_ca_ops_eval_types=>gc_state-stale         THEN 6
                        ELSE 7 ).
  ENDMETHOD.


  METHOD worse_of.
    rv_state = COND #( WHEN rank( iv_other ) > rank( iv_one ) THEN iv_other ELSE iv_one ).
  ENDMETHOD.


  METHOD display_state.
    IF iv_cmpl = zif_ca_ops_eval_types=>gc_cmpl-not_evaluated OR iv_class IS INITIAL
       OR iv_class = zif_ca_ops_eval_types=>gc_state-not_evaluated.
      rv_state = zif_ca_ops_eval_types=>gc_state-not_evaluated.
    ELSEIF iv_class = zif_ca_ops_eval_types=>gc_state-stale.
      rv_state = zif_ca_ops_eval_types=>gc_state-stale.
    ELSEIF iv_cmpl = zif_ca_ops_eval_types=>gc_cmpl-partial.
      rv_state = zif_ca_ops_eval_types=>gc_state-partial.
    ELSE.
      rv_state = iv_class.
    ENDIF.
  ENDMETHOD.


  METHOD is_unknown.
    rv_unknown = xsdbool( iv_state IS INITIAL
                          OR iv_state = zif_ca_ops_eval_types=>gc_state-not_evaluated
                          OR iv_state = zif_ca_ops_eval_types=>gc_state-stale
                          OR iv_state = zif_ca_ops_eval_types=>gc_state-partial ).
  ENDMETHOD.


  METHOD is_exception.
    rv_exception = xsdbool( iv_severity = zif_ca_ops_types=>gc_severity-block
                            OR iv_severity = zif_ca_ops_types=>gc_severity-error
                            OR iv_severity = zif_ca_ops_types=>gc_severity-warning ).
  ENDMETHOD.


  METHOD period_of.
    rv_period = iv_date(6).
  ENDMETHOD.


  METHOD scope.
    ev_bus_date = COND #( WHEN is_eval-bus_date IS INITIAL THEN iv_today ELSE is_eval-bus_date ).
    ev_period   = COND #( WHEN is_eval-period IS INITIAL THEN period_of( ev_bus_date ) ELSE is_eval-period ).
  ENDMETHOD.


  METHOD is_stale.
    IF iv_newest_at IS INITIAL.
      rv_stale = abap_true.
      RETURN.
    ENDIF.
    IF iv_stale_min <= 0 OR iv_now IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        DATA(lv_seconds) = cl_abap_tstmp=>subtract( tstmp1 = iv_now tstmp2 = iv_newest_at ).
        rv_stale = xsdbool( lv_seconds > iv_stale_min * 60 ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        " a time stamp that cannot be compared proves no freshness
        rv_stale = abap_true.
    ENDTRY.
  ENDMETHOD.


  METHOD header.
    rs_eval = VALUE #( run_id       = is_input-run_id
                       check_id     = is_input-check_id
                       area         = is_input-area
                       process_id   = is_input-process_id
                       sched_group  = is_input-sched_group
                       evaluated_at = is_input-now
                       lic_state    = is_input-lic_state
                       lic_module   = is_input-lic_module ).
  ENDMETHOD.


  METHOD derive.
    DATA(ls_part) = is_result-eval.
    rs_eval = header( is_input ).
    scope( EXPORTING is_eval     = ls_part
                     iv_today    = is_input-today
           IMPORTING ev_bus_date = rs_eval-bus_date
                     ev_period   = rs_eval-period ).
    rs_eval-bukrs_list   = ls_part-bukrs_list.
    rs_eval-expected_cnt = ls_part-expected.
    rs_eval-observed_cnt = ls_part-observed.
    rs_eval-watermark    = ls_part-watermark.
    rs_eval-item_count   = is_result-item_count.
    rs_eval-sources      = ls_part-sources.
    DATA(lv_blocking) = abap_false.
    LOOP AT is_result-findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      IF is_exception( <ls_finding>-severity ) = abap_true.
        rs_eval-finding_cnt += 1.
      ENDIF.
      IF <ls_finding>-severity = zif_ca_ops_types=>gc_severity-block
         OR <ls_finding>-severity = zif_ca_ops_types=>gc_severity-error.
        lv_blocking = abap_true.
      ENDIF.
    ENDLOOP.
    freshness( EXPORTING is_input = is_input
               CHANGING  cs_eval  = rs_eval ).
    rs_eval-completeness = completeness( is_input = is_input is_result = is_result ).

    IF rs_eval-completeness = zif_ca_ops_eval_types=>gc_cmpl-not_evaluated.
      rs_eval-result_class = zif_ca_ops_eval_types=>gc_state-not_evaluated.
    ELSE.
      rs_eval-result_class = ls_part-result_class.
      IF rs_eval-result_class IS INITIAL OR rs_eval-result_class = zif_ca_ops_eval_types=>gc_state-not_evaluated.
        " a check that reports nothing new: no owned exception = OK, else FINDINGS
        rs_eval-result_class = COND #( WHEN rs_eval-finding_cnt > 0 THEN zif_ca_ops_eval_types=>gc_state-findings
                                       ELSE zif_ca_ops_eval_types=>gc_state-ok ).
      ELSEIF lv_blocking = abap_true AND rank( rs_eval-result_class ) < rank( zif_ca_ops_eval_types=>gc_state-findings ).
        " an error never hides behind a zero, a holiday or a closed period
        rs_eval-result_class = zif_ca_ops_eval_types=>gc_state-findings.
      ENDIF.
      IF rs_eval-result_class = zif_ca_ops_eval_types=>gc_state-ok
         OR rs_eval-result_class = zif_ca_ops_eval_types=>gc_state-zero_ok.
        IF line_exists( rs_eval-sources[ is_stale = abap_true ] ).
          " the silence of a stale source proves nothing
          rs_eval-result_class = zif_ca_ops_eval_types=>gc_state-stale.
        ELSEIF is_input-period_closed = abap_true.
          " no activity is expected in a closed period: a zero there is not health
          rs_eval-result_class = zif_ca_ops_eval_types=>gc_state-period_closed.
        ENDIF.
      ENDIF.
    ENDIF.
    rs_eval-eval_state = display_state( iv_class = rs_eval-result_class iv_cmpl = rs_eval-completeness ).
    rs_eval-reason_code = ls_part-reason_code.
    rs_eval-reason      = ls_part-reason.
    reason( EXPORTING is_input = is_input
            CHANGING  cs_eval  = rs_eval ).
  ENDMETHOD.


  METHOD not_run.
    rs_eval = header( is_input ).
    rs_eval-bus_date     = is_input-today.
    rs_eval-period       = period_of( is_input-today ).
    rs_eval-completeness = zif_ca_ops_eval_types=>gc_cmpl-not_evaluated.
    rs_eval-result_class = zif_ca_ops_eval_types=>gc_state-not_evaluated.
    rs_eval-eval_state   = zif_ca_ops_eval_types=>gc_state-not_evaluated.
    rs_eval-reason_code  = iv_reason_code.
    rs_eval-reason       = iv_reason.
  ENDMETHOD.


  METHOD completeness.
    DATA(ls_part) = is_result-eval.
    IF is_input-raised = abap_true.
      rv_cmpl = zif_ca_ops_eval_types=>gc_cmpl-not_evaluated.
    ELSEIF ls_part-completeness IS NOT INITIAL.
      rv_cmpl = ls_part-completeness.
      IF rv_cmpl = zif_ca_ops_eval_types=>gc_cmpl-complete AND is_result-partial = abap_true.
        rv_cmpl = zif_ca_ops_eval_types=>gc_cmpl-partial.
      ENDIF.
    ELSEIF ls_part-unevaluated > 0 AND ls_part-evaluated = 0.
      rv_cmpl = zif_ca_ops_eval_types=>gc_cmpl-not_evaluated.
    ELSEIF ls_part-unevaluated > 0 OR is_result-partial = abap_true.
      rv_cmpl = zif_ca_ops_eval_types=>gc_cmpl-partial.
    ELSE.
      rv_cmpl = zif_ca_ops_eval_types=>gc_cmpl-complete.
    ENDIF.
  ENDMETHOD.


  METHOD freshness.
    DATA lv_first TYPE abap_bool VALUE abap_true.
    LOOP AT cs_eval-sources ASSIGNING FIELD-SYMBOL(<ls_source>).
      IF <ls_source>-stale_min <= 0.
        <ls_source>-stale_min = is_input-source_stale_min.
      ENDIF.
      <ls_source>-is_stale = is_stale( iv_newest_at = <ls_source>-newest_at
                                       iv_now       = is_input-now
                                       iv_stale_min = <ls_source>-stale_min ).
      " the freshness of the evaluation is that of its oldest source
      IF lv_first = abap_true OR <ls_source>-newest_at < cs_eval-fresh_at.
        cs_eval-fresh_at     = <ls_source>-newest_at.
        cs_eval-fresh_source = <ls_source>-source_id.
        lv_first = abap_false.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD reason.
    IF cs_eval-reason IS NOT INITIAL.
      RETURN.
    ENDIF.
    IF is_input-raised = abap_true.
      cs_eval-reason_code = zif_ca_ops_eval_types=>gc_reason-check_raised.
      cs_eval-reason      = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-check_raised
                                                   iv_v1    = is_input-check_id
                                                   iv_v2    = is_input-area
                                                   iv_tail  = CONV #( is_input-error_text ) ).
    ELSEIF cs_eval-completeness = zif_ca_ops_eval_types=>gc_cmpl-not_evaluated.
      cs_eval-reason_code = zif_ca_ops_eval_types=>gc_reason-not_evaluated.
      cs_eval-reason      = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-not_evaluated
                                                   iv_v1    = is_input-check_id
                                                   iv_v2    = is_input-area ).
    ELSEIF cs_eval-result_class = zif_ca_ops_eval_types=>gc_state-stale AND cs_eval-fresh_source IS NOT INITIAL.
      cs_eval-reason_code = zif_ca_ops_eval_types=>gc_reason-source_stale.
      cs_eval-reason      = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-source_stale
                                                   iv_v1    = cs_eval-fresh_source
                                                   iv_v2    = is_input-check_id
                                                   iv_v3    = |{ cs_eval-fresh_at TIMESTAMP = ISO }|
                                                   iv_v4    = is_input-source_stale_min ).
    ELSEIF cs_eval-completeness = zif_ca_ops_eval_types=>gc_cmpl-partial.
      cs_eval-reason_code = zif_ca_ops_eval_types=>gc_reason-partial.
      cs_eval-reason      = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-partial
                                                   iv_v1    = is_input-check_id
                                                   iv_v2    = is_input-area ).
    ELSEIF cs_eval-result_class = zif_ca_ops_eval_types=>gc_state-period_closed.
      cs_eval-reason_code = zif_ca_ops_eval_types=>gc_reason-period_closed.
      cs_eval-reason      = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-period_closed
                                                   iv_v1    = cs_eval-period
                                                   iv_v2    = is_input-area
                                                   iv_v3    = cs_eval-bukrs_list ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
