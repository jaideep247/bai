*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_lifecycle.clas.abap
*& Purpose:
*& The lifecycle model of a payment file (docs/PAYMENT_FILE_LIFECYCLE.md
*& sections 3 and 7) - pure rules, no database: the business date of a
*& file (local generation date in the file type's time zone, the next
*& day from the overnight cut-off on, then the next business day of the
*& calendar), the deadline of a milestone (clock time DAY_OFFSET business
*& days after the business date, or minutes after another milestone),
*& the status of every configured milestone from the file's evidence
*& (REACHED, LATE, IMPLIED by a later milestone, PENDING, MISSING past its
*& deadline, REJECTED, PARTIAL, FAILED, UNKNOWN when the source that
*& would evidence it failed or is stale), payment- and batch-level
*& acknowledgements and conflicting answers of the bank, where the file
*& stopped, its next required milestone and deadline, its state, and the
*& result of a business day (expected versus observed: holiday, not
*& evaluated, stale source, valid zero-volume day, pending, missing,
*& partial). Order-independent: events may arrive out of order and twice.
*& The business calendar is a plug-in (ZIF_CA_OPS_PF_CALENDAR).
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file lifecycle model</p>
"! The rules are mirrored by the offline reference model tools/abaptools/payfile.py, which runs the fixtures of
"! config/payfile/fixtures.json for both integration setups (docs/PAYMENT_FILE_LIFECYCLE.md section 10).
CLASS zcl_ca_ops_pf_lifecycle DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Health of the source of a milestone: N its source failed (not evaluated), S its source is stale
    TYPES:
      BEGIN OF ty_health,
        milestone TYPE zif_ca_ops_pf_types=>ty_milestone,
        eval      TYPE zif_ca_ops_pf_types=>ty_flag,
        reason    TYPE zif_ca_ops_pf_types=>ty_reason,
      END OF ty_health.
    TYPES tt_health TYPE SORTED TABLE OF ty_health WITH UNIQUE KEY milestone.

    "! What decides a business day
    TYPES:
      BEGIN OF ty_day_input,
        bus_date      TYPE d,
        observed      TYPE i,
        "! Read status and freshness of the file source
        source_status TYPE zif_ca_ops_pf_types=>ty_flag,
        source_reason TYPE zif_ca_ops_pf_types=>ty_reason,
        as_of         TYPE timestampl,
        watermark     TYPE timestampl,
        "! The day's expectation is due (UTC): clock deadline of the first milestone, else the end of the day
        due_at        TYPE timestampl,
      END OF ty_day_input.

    "! @parameter io_calendar | Business calendar (blank = the factory calendar class)
    METHODS constructor
      IMPORTING
        io_calendar TYPE REF TO zif_ca_ops_pf_calendar OPTIONAL.

    "! Rank of a milestone in the product order (1 = payment run; 0 = not a milestone)
    CLASS-METHODS rank
      IMPORTING
        iv_milestone   TYPE zif_ca_ops_pf_types=>ty_milestone
      RETURNING
        VALUE(rv_rank) TYPE i.

    "! Minutes from iv_from to iv_to (negative when iv_to is earlier; 0 when either is initial)
    CLASS-METHODS minutes
      IMPORTING
        iv_from           TYPE timestampl
        iv_to             TYPE timestampl
      RETURNING
        VALUE(rv_minutes) TYPE i.

    "! A time stamp plus minutes
    CLASS-METHODS add_minutes
      IMPORTING
        iv_ts        TYPE timestampl
        iv_minutes   TYPE i
      RETURNING
        VALUE(rv_ts) TYPE timestampl.

    "! Business date of a file generated at iv_gen_at (UTC)
    "! @raising zcx_ca_ops_error | 397 time zone, 393 calendar
    METHODS business_date
      IMPORTING
        is_type        TYPE zif_ca_ops_pf_types=>ty_type_cfg
        iv_gen_at      TYPE timestampl
      RETURNING
        VALUE(rv_date) TYPE d
      RAISING
        zcx_ca_ops_error.

    "! Clock deadline: iv_time (local) iv_days business days after iv_date, in UTC
    "! @raising zcx_ca_ops_error | 397 time zone, 393 calendar
    METHODS clock_due
      IMPORTING
        is_type      TYPE zif_ca_ops_pf_types=>ty_type_cfg
        iv_date      TYPE d
        iv_days      TYPE i
        iv_time      TYPE t
      RETURNING
        VALUE(rv_ts) TYPE timestampl
      RAISING
        zcx_ca_ops_error.

    "! Evaluate one file
    "! @parameter is_type     | File type (ACK level, calendar, time zone)
    "! @parameter it_stages   | Active milestones of the file type
    "! @parameter is_file     | The file (business date, payment counts, partial flag)
    "! @parameter it_events   | Its evidence (outcome INFO ignored)
    "! @parameter it_payments | Its payments (payment- and batch-level acknowledgement)
    "! @parameter it_health   | Milestones whose source failed or is stale
    "! @parameter iv_now      | Evaluation time (UTC)
    "! @raising zcx_ca_ops_error | 397 time zone, 393 calendar
    METHODS evaluate
      IMPORTING
        is_type        TYPE zif_ca_ops_pf_types=>ty_type_cfg
        it_stages      TYPE zif_ca_ops_pf_types=>tt_stage
        is_file        TYPE zif_ca_ops_pf_types=>ty_file
        it_events      TYPE zif_ca_ops_pf_types=>tt_event
        it_payments    TYPE zif_ca_ops_pf_types=>tt_payment OPTIONAL
        it_health      TYPE tt_health OPTIONAL
        iv_now         TYPE timestampl
      RETURNING
        VALUE(rs_eval) TYPE zif_ca_ops_pf_types=>ty_eval
      RAISING
        zcx_ca_ops_error.

    "! Result of a business day of a file type
    "! @raising zcx_ca_ops_error | 393 calendar
    METHODS evaluate_day
      IMPORTING
        is_type       TYPE zif_ca_ops_pf_types=>ty_type_cfg
        is_input      TYPE ty_day_input
        iv_stale_min  TYPE i
        iv_now        TYPE timestampl
      RETURNING
        VALUE(rs_day) TYPE zif_ca_ops_pf_types=>ty_day
      RAISING
        zcx_ca_ops_error.

  PRIVATE SECTION.
    "! What the evidence says about one milestone
    TYPES:
      BEGIN OF ty_observed,
        milestone   TYPE zif_ca_ops_pf_types=>ty_milestone,
        outcome     TYPE zif_ca_ops_pf_types=>ty_outcome,
        observed_at TYPE timestampl,
        event_key   TYPE zif_ca_ops_pf_types=>ty_event_key,
        conflict    TYPE abap_bool,
        "! Scoped acknowledgement (batch / payment) still incomplete
        incomplete  TYPE abap_bool,
      END OF ty_observed.
    TYPES tt_observed TYPE SORTED TABLE OF ty_observed WITH UNIQUE KEY milestone.

    DATA mo_calendar TYPE REF TO zif_ca_ops_pf_calendar.

    METHODS calendar
      RETURNING
        VALUE(ro_calendar) TYPE REF TO zif_ca_ops_pf_calendar
      RAISING
        zcx_ca_ops_error.

    "! The decisive answer of the events of one milestone (latest; on a tie the non-OK outcome)
    METHODS observe
      IMPORTING
        iv_milestone       TYPE zif_ca_ops_pf_types=>ty_milestone
        it_events          TYPE zif_ca_ops_pf_types=>tt_event
      RETURNING
        VALUE(rs_observed) TYPE ty_observed.

    "! Payment- or batch-level acceptance from the payments' acknowledgements
    METHODS observe_scoped
      IMPORTING
        is_type            TYPE zif_ca_ops_pf_types=>ty_type_cfg
        it_events          TYPE zif_ca_ops_pf_types=>tt_event
        it_payments        TYPE zif_ca_ops_pf_types=>tt_payment
      CHANGING
        cs_eval            TYPE zif_ca_ops_pf_types=>ty_eval
      RETURNING
        VALUE(rs_observed) TYPE ty_observed.

    METHODS due_of
      IMPORTING
        is_type      TYPE zif_ca_ops_pf_types=>ty_type_cfg
        is_stage     TYPE zif_ca_ops_pf_types=>ty_stage
        is_file      TYPE zif_ca_ops_pf_types=>ty_file
        it_ms        TYPE zif_ca_ops_pf_types=>tt_ms
      RETURNING
        VALUE(rv_ts) TYPE timestampl
      RAISING
        zcx_ca_ops_error.

    "! Where the file stopped, its next required milestone, deadline, state and evaluation
    METHODS conclude
      IMPORTING
        it_health TYPE tt_health
        is_file   TYPE zif_ca_ops_pf_types=>ty_file
        iv_now    TYPE timestampl
      CHANGING
        cs_eval   TYPE zif_ca_ops_pf_types=>ty_eval.

    CLASS-METHODS severity_of_outcome
      IMPORTING
        iv_outcome     TYPE zif_ca_ops_pf_types=>ty_outcome
      RETURNING
        VALUE(rv_rank) TYPE i.

ENDCLASS.



CLASS zcl_ca_ops_pf_lifecycle IMPLEMENTATION.

  METHOD constructor.
    mo_calendar = io_calendar.
  ENDMETHOD.


  METHOD calendar.
    IF mo_calendar IS NOT BOUND.
      mo_calendar ?= zcl_ca_ops_factory=>get_plugin( iv_class_name = zif_ca_ops_pf_types=>gc_default_class-calendar
                                                     iv_interface  = zif_ca_ops_pf_types=>gc_intf-calendar ).
    ENDIF.
    ro_calendar = mo_calendar.
  ENDMETHOD.


  METHOD rank.
    SPLIT zif_ca_ops_pf_types=>gc_milestone_order AT ',' INTO TABLE DATA(lt_order).
    rv_rank = line_index( lt_order[ table_line = condense( CONV string( iv_milestone ) ) ] ).
  ENDMETHOD.


  METHOD minutes.
    IF iv_from IS INITIAL OR iv_to IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        DATA(lv_seconds) = cl_abap_tstmp=>subtract( tstmp1 = iv_to tstmp2 = iv_from ).
        rv_minutes = trunc( lv_seconds / 60 ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        rv_minutes = 0.
    ENDTRY.
  ENDMETHOD.


  METHOD add_minutes.
    rv_ts = iv_ts.
    IF iv_ts IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        rv_ts = cl_abap_tstmp=>add( tstmp = iv_ts secs = iv_minutes * 60 ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        rv_ts = iv_ts.
    ENDTRY.
  ENDMETHOD.


  METHOD business_date.
    DATA lv_date TYPE d.
    DATA lv_time TYPE t.
    DATA(lv_zone) = COND tznzone( WHEN is_type-time_zone IS INITIAL THEN zif_ca_ops_types=>gc_time_zone_utc
                                  ELSE is_type-time_zone ).
    CONVERT TIME STAMP iv_gen_at TIME ZONE lv_zone INTO DATE lv_date TIME lv_time.
    IF sy-subrc > 4 OR lv_date IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e397(zca_ops) WITH lv_zone iv_gen_at.
    ENDIF.
    " overnight cut-off: a file generated at or after it belongs to the next day
    IF is_type-day_cutoff IS NOT INITIAL AND lv_time >= is_type-day_cutoff.
      lv_date += 1.
    ENDIF.
    rv_date = calendar( )->add_business_days( iv_calendar_id = is_type-calendar_id
                                              iv_date        = lv_date
                                              iv_days        = 0 ).
  ENDMETHOD.


  METHOD clock_due.
    DATA lv_ts TYPE timestamp.
    DATA(lv_zone) = COND tznzone( WHEN is_type-time_zone IS INITIAL THEN zif_ca_ops_types=>gc_time_zone_utc
                                  ELSE is_type-time_zone ).
    DATA(lv_date) = calendar( )->add_business_days( iv_calendar_id = is_type-calendar_id
                                                    iv_date        = iv_date
                                                    iv_days        = iv_days ).
    CONVERT DATE lv_date TIME iv_time INTO TIME STAMP lv_ts TIME ZONE lv_zone.
    IF sy-subrc > 4.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e397(zca_ops) WITH lv_zone iv_time.
    ENDIF.
    rv_ts = lv_ts.
  ENDMETHOD.


  METHOD evaluate.
    DATA lt_observed TYPE tt_observed.
    DATA lt_stages TYPE zif_ca_ops_pf_types=>tt_stage.

    " the milestones that apply, in the product order (no acknowledgement milestones without an ACK)
    LOOP AT it_stages ASSIGNING FIELD-SYMBOL(<ls_stage>) WHERE active = abap_true.
      IF is_type-ack_level = zif_ca_ops_pf_types=>gc_ack_level-none
         AND ( <ls_stage>-milestone = zif_ca_ops_pf_types=>gc_milestone-receipt
            OR <ls_stage>-milestone = zif_ca_ops_pf_types=>gc_milestone-accepted ).
        CONTINUE.
      ENDIF.
      IF rank( <ls_stage>-milestone ) > 0.
        INSERT <ls_stage> INTO TABLE lt_stages.
      ENDIF.
    ENDLOOP.
    DATA(lt_ranked) = VALUE zif_ca_ops_pf_types=>tt_stage( ).
    DO 7 TIMES.
      DATA(lv_index) = sy-index.
      LOOP AT lt_stages ASSIGNING <ls_stage> WHERE milestone IS NOT INITIAL.
        IF rank( <ls_stage>-milestone ) = lv_index.
          INSERT <ls_stage> INTO TABLE lt_ranked.
        ENDIF.
      ENDLOOP.
    ENDDO.

    " what the evidence says per milestone
    LOOP AT lt_ranked ASSIGNING <ls_stage>.
      IF <ls_stage>-milestone = zif_ca_ops_pf_types=>gc_milestone-accepted
         AND ( is_type-ack_level = zif_ca_ops_pf_types=>gc_ack_level-payment
            OR is_type-ack_level = zif_ca_ops_pf_types=>gc_ack_level-batch ).
        DATA(ls_observed) = observe_scoped( EXPORTING is_type     = is_type
                                                      it_events   = it_events
                                                      it_payments = it_payments
                                            CHANGING  cs_eval     = rs_eval ).
      ELSE.
        ls_observed = observe( iv_milestone = <ls_stage>-milestone it_events = it_events ).
      ENDIF.
      ls_observed-milestone = <ls_stage>-milestone.
      IF ls_observed-conflict = abap_true.
        rs_eval-conflict = abap_true.
      ENDIF.
      INSERT ls_observed INTO TABLE lt_observed.
    ENDLOOP.

    " status per milestone, in order (the deadline of an offset milestone needs its basis first)
    LOOP AT lt_ranked ASSIGNING <ls_stage>.
      DATA(lv_rank) = rank( <ls_stage>-milestone ).
      DATA(ls_obs) = lt_observed[ milestone = <ls_stage>-milestone ].
      DATA(ls_ms) = VALUE zif_ca_ops_pf_types=>ty_ms( area         = is_file-area
                                                      file_id      = is_file-file_id
                                                      milestone    = <ls_stage>-milestone
                                                      seq          = lv_rank
                                                      required     = <ls_stage>-required
                                                      outcome      = ls_obs-outcome
                                                      observed_at  = ls_obs-observed_at
                                                      event_key    = ls_obs-event_key
                                                      evaluated_at = iv_now ).
      ls_ms-due_at = due_of( is_type  = is_type
                             is_stage = <ls_stage>
                             is_file  = is_file
                             it_ms    = rs_eval-milestones ).
      DATA(lv_due_passed) = xsdbool( ls_ms-due_at IS NOT INITIAL AND iv_now > ls_ms-due_at ).
      IF ls_obs-outcome IS NOT INITIAL AND NOT ( ls_obs-incomplete = abap_true AND lv_due_passed = abap_false ).
        ls_ms-status = SWITCH #( ls_obs-outcome
                                 WHEN zif_ca_ops_pf_types=>gc_outcome-rejected THEN zif_ca_ops_pf_types=>gc_ms_status-rejected
                                 WHEN zif_ca_ops_pf_types=>gc_outcome-partial  THEN zif_ca_ops_pf_types=>gc_ms_status-partial
                                 WHEN zif_ca_ops_pf_types=>gc_outcome-failed   THEN zif_ca_ops_pf_types=>gc_ms_status-failed
                                 ELSE zif_ca_ops_pf_types=>gc_ms_status-reached ).
        IF ls_ms-status = zif_ca_ops_pf_types=>gc_ms_status-reached AND ls_ms-due_at IS NOT INITIAL
           AND ls_ms-observed_at > ls_ms-due_at.
          ls_ms-status   = zif_ca_ops_pf_types=>gc_ms_status-late.
          ls_ms-late_min = minutes( iv_from = ls_ms-due_at iv_to = ls_ms-observed_at ).
          IF rs_eval-late_ms IS INITIAL.
            rs_eval-late_ms  = ls_ms-milestone.
            rs_eval-late_min = ls_ms-late_min.
          ENDIF.
        ENDIF.
      ELSE.
        " a later milestone with any answer implies this one (the bank cannot accept a file it never received)
        DATA(lv_implied) = abap_false.
        LOOP AT lt_observed ASSIGNING FIELD-SYMBOL(<ls_later>) WHERE outcome IS NOT INITIAL.
          IF rank( <ls_later>-milestone ) > lv_rank.
            lv_implied = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        READ TABLE it_health WITH TABLE KEY milestone = <ls_stage>-milestone ASSIGNING FIELD-SYMBOL(<ls_health>).
        ls_ms-status = COND #( WHEN lv_implied = abap_true THEN zif_ca_ops_pf_types=>gc_ms_status-implied
                               WHEN lv_due_passed = abap_true AND sy-subrc = 0
                                 THEN zif_ca_ops_pf_types=>gc_ms_status-unknown
                               WHEN lv_due_passed = abap_true THEN zif_ca_ops_pf_types=>gc_ms_status-missing
                               ELSE zif_ca_ops_pf_types=>gc_ms_status-pending ).
        IF ls_ms-status = zif_ca_ops_pf_types=>gc_ms_status-unknown.
          rs_eval-eval_state  = <ls_health>-eval.
          rs_eval-eval_reason = <ls_health>-reason.
        ENDIF.
      ENDIF.
      INSERT ls_ms INTO TABLE rs_eval-milestones.
    ENDLOOP.

    conclude( EXPORTING it_health = it_health
                        is_file   = is_file
                        iv_now    = iv_now
              CHANGING  cs_eval   = rs_eval ).
  ENDMETHOD.


  METHOD observe.
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>)
         WHERE milestone = iv_milestone AND outcome <> zif_ca_ops_pf_types=>gc_outcome-info AND outcome IS NOT INITIAL.
      IF rs_observed-outcome IS INITIAL.
        rs_observed = VALUE #( outcome     = <ls_event>-outcome
                               observed_at = <ls_event>-occurred_at
                               event_key   = <ls_event>-event_key ).
        CONTINUE.
      ENDIF.
      " acceptance and rejection of the same scope by the bank: a conflict, never hidden
      IF iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted AND <ls_event>-outcome <> rs_observed-outcome
         AND ( <ls_event>-outcome = zif_ca_ops_pf_types=>gc_outcome-ok
            OR rs_observed-outcome = zif_ca_ops_pf_types=>gc_outcome-ok ).
        rs_observed-conflict = abap_true.
      ENDIF.
      " the latest answer decides (a retried transfer succeeds after its failure); on a tie the worse one
      IF <ls_event>-occurred_at > rs_observed-observed_at
         OR ( <ls_event>-occurred_at = rs_observed-observed_at
              AND severity_of_outcome( <ls_event>-outcome ) > severity_of_outcome( rs_observed-outcome ) ).
        rs_observed-outcome     = <ls_event>-outcome.
        rs_observed-observed_at = <ls_event>-occurred_at.
        rs_observed-event_key   = <ls_event>-event_key.
      ENDIF.
    ENDLOOP.
    " reached at the first time the decisive answer was given (a repeated acknowledgement is not later)
    LOOP AT it_events ASSIGNING <ls_event>
         WHERE milestone = iv_milestone AND outcome = rs_observed-outcome AND outcome IS NOT INITIAL.
      IF <ls_event>-occurred_at < rs_observed-observed_at.
        rs_observed-observed_at = <ls_event>-occurred_at.
        rs_observed-event_key   = <ls_event>-event_key.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD observe_scoped.
    TYPES:
      BEGIN OF ty_scope,
        scope    TYPE zif_ca_ops_pf_types=>ty_pay_key,
        outcome  TYPE zif_ca_ops_pf_types=>ty_outcome,
        at       TYPE timestampl,
        key      TYPE zif_ca_ops_pf_types=>ty_event_key,
        conflict TYPE abap_bool,
      END OF ty_scope.
    DATA lt_scopes TYPE SORTED TABLE OF ty_scope WITH UNIQUE KEY scope.
    DATA(lv_by_payment) = xsdbool( is_type-ack_level = zif_ca_ops_pf_types=>gc_ack_level-payment ).

    " the scopes the bank must answer: every payment, or every batch of the file's payments
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      DATA(lv_scope) = COND zif_ca_ops_pf_types=>ty_pay_key( WHEN lv_by_payment = abap_true THEN <ls_payment>-pay_key
                                                             ELSE <ls_payment>-batch_id ).
      INSERT VALUE #( scope = lv_scope ) INTO TABLE lt_scopes.
    ENDLOOP.

    " a file-level answer of a scoped file type answers every scope
    DATA(ls_file_level) = VALUE ty_observed( ).
    DATA(lt_file_events) = VALUE zif_ca_ops_pf_types=>tt_event( ).
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>)
         WHERE milestone = zif_ca_ops_pf_types=>gc_milestone-accepted
           AND outcome <> zif_ca_ops_pf_types=>gc_outcome-info AND outcome IS NOT INITIAL.
      DATA(lv_key) = COND zif_ca_ops_pf_types=>ty_pay_key( WHEN lv_by_payment = abap_true THEN <ls_event>-pay_key
                                                           ELSE <ls_event>-batch_id ).
      IF lv_key IS INITIAL.
        INSERT <ls_event> INTO TABLE lt_file_events.
        CONTINUE.
      ENDIF.
      READ TABLE lt_scopes WITH TABLE KEY scope = lv_key ASSIGNING FIELD-SYMBOL(<ls_scope>).
      IF sy-subrc <> 0.
        " an answer for a payment the file does not hold: evidence only
        CONTINUE.
      ENDIF.
      IF <ls_scope>-outcome IS NOT INITIAL AND <ls_scope>-outcome <> <ls_event>-outcome.
        <ls_scope>-conflict = abap_true.
      ENDIF.
      IF <ls_scope>-outcome IS INITIAL OR <ls_event>-occurred_at > <ls_scope>-at
         OR ( <ls_event>-occurred_at = <ls_scope>-at
              AND severity_of_outcome( <ls_event>-outcome ) > severity_of_outcome( <ls_scope>-outcome ) ).
        <ls_scope>-outcome = <ls_event>-outcome.
        <ls_scope>-at      = <ls_event>-occurred_at.
        <ls_scope>-key     = <ls_event>-event_key.
      ENDIF.
    ENDLOOP.
    IF lt_file_events IS NOT INITIAL.
      ls_file_level = observe( iv_milestone = zif_ca_ops_pf_types=>gc_milestone-accepted it_events = lt_file_events ).
    ENDIF.

    LOOP AT lt_scopes ASSIGNING <ls_scope>.
      IF <ls_scope>-outcome IS INITIAL AND ls_file_level-outcome IS NOT INITIAL.
        <ls_scope>-outcome = ls_file_level-outcome.
        <ls_scope>-at      = ls_file_level-observed_at.
        <ls_scope>-key     = ls_file_level-event_key.
      ENDIF.
      IF <ls_scope>-conflict = abap_true.
        rs_observed-conflict = abap_true.
      ENDIF.
      CASE <ls_scope>-outcome.
        WHEN zif_ca_ops_pf_types=>gc_outcome-ok.
          cs_eval-pay_accepted += 1.
        WHEN zif_ca_ops_pf_types=>gc_outcome-rejected OR zif_ca_ops_pf_types=>gc_outcome-failed.
          cs_eval-pay_rejected += 1.
        WHEN OTHERS.
          cs_eval-pay_open += 1.
      ENDCASE.
      IF <ls_scope>-at > rs_observed-observed_at.
        rs_observed-observed_at = <ls_scope>-at.
        rs_observed-event_key   = <ls_scope>-key.
      ENDIF.
    ENDLOOP.
    IF ls_file_level-conflict = abap_true.
      rs_observed-conflict = abap_true.
    ENDIF.

    DATA(lv_answered) = cs_eval-pay_accepted + cs_eval-pay_rejected.
    IF lv_answered = 0.
      CLEAR: rs_observed-outcome, rs_observed-observed_at, rs_observed-event_key.
      RETURN.
    ENDIF.
    rs_observed-outcome = COND #( WHEN cs_eval-pay_open = 0 AND cs_eval-pay_rejected = 0
                                    THEN zif_ca_ops_pf_types=>gc_outcome-ok
                                  WHEN cs_eval-pay_open = 0 AND cs_eval-pay_accepted = 0
                                    THEN zif_ca_ops_pf_types=>gc_outcome-rejected
                                  ELSE zif_ca_ops_pf_types=>gc_outcome-partial ).
    " answers outstanding: the milestone is partial only once its deadline passed (else still pending)
    rs_observed-incomplete = xsdbool( cs_eval-pay_open > 0 ).
  ENDMETHOD.


  METHOD due_of.
    CASE is_stage-due_kind.
      WHEN zif_ca_ops_pf_types=>gc_due_kind-clock.
        IF is_file-bus_date IS NOT INITIAL.
          rv_ts = clock_due( is_type = is_type
                             iv_date = is_file-bus_date
                             iv_days = is_stage-day_offset
                             iv_time = is_stage-due_time ).
        ENDIF.
      WHEN zif_ca_ops_pf_types=>gc_due_kind-offset.
        IF is_stage-basis = zif_ca_ops_pf_types=>gc_milestone-payrun AND is_file-gen_at IS NOT INITIAL
           AND NOT line_exists( it_ms[ milestone = is_stage-basis ] ).
          rv_ts = add_minutes( iv_ts = is_file-gen_at iv_minutes = is_stage-offset_min ).
          RETURN.
        ENDIF.
        READ TABLE it_ms WITH KEY milestone = is_stage-basis ASSIGNING FIELD-SYMBOL(<ls_basis>).
        " a basis without a time (pending, implied, unknown) gives no deadline yet
        IF sy-subrc = 0 AND <ls_basis>-observed_at IS NOT INITIAL.
          rv_ts = add_minutes( iv_ts = <ls_basis>-observed_at iv_minutes = is_stage-offset_min ).
        ENDIF.
      WHEN OTHERS.
        CLEAR rv_ts.
    ENDCASE.
  ENDMETHOD.


  METHOD conclude.
    DATA lv_failed TYPE abap_bool.
    DATA lv_open_required TYPE abap_bool.

    LOOP AT cs_eval-milestones ASSIGNING FIELD-SYMBOL(<ls_ms>).
      CASE <ls_ms>-status.
        WHEN zif_ca_ops_pf_types=>gc_ms_status-reached OR zif_ca_ops_pf_types=>gc_ms_status-late
          OR zif_ca_ops_pf_types=>gc_ms_status-implied.
          cs_eval-stage = <ls_ms>-milestone.
          CLEAR lv_failed.
        WHEN zif_ca_ops_pf_types=>gc_ms_status-failed.
          lv_failed = abap_true.
      ENDCASE.
    ENDLOOP.

    " the next required milestone not reached, its deadline and how long it is overdue
    LOOP AT cs_eval-milestones ASSIGNING <ls_ms> WHERE required = abap_true.
      IF <ls_ms>-status = zif_ca_ops_pf_types=>gc_ms_status-reached OR <ls_ms>-status = zif_ca_ops_pf_types=>gc_ms_status-late
         OR <ls_ms>-status = zif_ca_ops_pf_types=>gc_ms_status-implied.
        CONTINUE.
      ENDIF.
      lv_open_required = abap_true.
      cs_eval-next_ms     = <ls_ms>-milestone.
      cs_eval-deadline_at = <ls_ms>-due_at.
      IF <ls_ms>-due_at IS NOT INITIAL AND iv_now > <ls_ms>-due_at
         AND <ls_ms>-status <> zif_ca_ops_pf_types=>gc_ms_status-unknown.
        cs_eval-overdue_min = minutes( iv_from = <ls_ms>-due_at iv_to = iv_now ).
      ENDIF.
      EXIT.
    ENDLOOP.

    IF line_exists( cs_eval-milestones[ milestone = zif_ca_ops_pf_types=>gc_milestone-accepted
                                        status    = zif_ca_ops_pf_types=>gc_ms_status-rejected ] ).
      cs_eval-state = zif_ca_ops_pf_types=>gc_state-rejected.
    ELSEIF line_exists( cs_eval-milestones[ status = zif_ca_ops_pf_types=>gc_ms_status-partial ] ).
      cs_eval-state = zif_ca_ops_pf_types=>gc_state-partial.
    ELSEIF lv_failed = abap_true.
      cs_eval-state = zif_ca_ops_pf_types=>gc_state-failed.
    ELSEIF lv_open_required = abap_false.
      cs_eval-state = zif_ca_ops_pf_types=>gc_state-done.
    ELSE.
      cs_eval-state = zif_ca_ops_pf_types=>gc_state-open.
    ENDIF.

    IF cs_eval-eval_state IS INITIAL.
      cs_eval-eval_state = COND #( WHEN is_file-pay_partial = abap_true THEN zif_ca_ops_pf_types=>gc_eval-partial
                                   ELSE zif_ca_ops_pf_types=>gc_eval-complete ).
    ENDIF.
    " a source that failed or is stale is said even when no milestone is unknown yet
    IF cs_eval-eval_reason IS INITIAL.
      LOOP AT it_health ASSIGNING FIELD-SYMBOL(<ls_health>).
        cs_eval-eval_reason = <ls_health>-reason.
        EXIT.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD evaluate_day.
    rs_day = VALUE #( file_type = is_type-file_type
                      area      = is_type-area
                      bus_date  = is_input-bus_date
                      expected  = is_type-expected_files
                      observed  = is_input-observed
                      as_of     = is_input-as_of
                      watermark = is_input-watermark
                      eval_at   = iv_now ).
    IF calendar( )->is_business_day( iv_calendar_id = is_type-calendar_id iv_date = is_input-bus_date ) = abap_false.
      rs_day-day_kind     = zif_ca_ops_pf_types=>gc_day_kind-holiday.
      rs_day-result       = zif_ca_ops_pf_types=>gc_day-holiday.
      rs_day-completeness = zif_ca_ops_pf_types=>gc_eval-complete.
      rs_day-reason       = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_pf_types=>gc_msg-holiday
                                                   iv_v1    = is_input-bus_date
                                                   iv_v2    = is_type-calendar_id ).
      RETURN.
    ENDIF.
    rs_day-day_kind = zif_ca_ops_pf_types=>gc_day_kind-business.

    IF is_input-source_status = zif_ca_ops_pf_types=>gc_src_status-failed.
      " a failed query is "not evaluated", never "no files"
      rs_day-result       = zif_ca_ops_pf_types=>gc_day-not_eval.
      rs_day-completeness = zif_ca_ops_pf_types=>gc_eval-not_evaluated.
      rs_day-reason       = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_pf_types=>gc_msg-day_not_eval
                                                   iv_v1    = is_input-bus_date
                                                   iv_v2    = is_type-file_type
                                                   iv_v3    = is_input-source_reason ).
      RETURN.
    ENDIF.

    IF is_input-observed > 0 AND is_input-observed >= is_type-expected_files.
      rs_day-result       = zif_ca_ops_pf_types=>gc_day-ok.
      rs_day-completeness = zif_ca_ops_pf_types=>gc_eval-complete.
      RETURN.
    ENDIF.

    " before the day's deadline nothing is missing yet
    DATA(lv_due) = COND timestampl( WHEN is_input-due_at IS NOT INITIAL THEN is_input-due_at ELSE iv_now ).
    IF iv_now <= lv_due.
      rs_day-result       = zif_ca_ops_pf_types=>gc_day-pending.
      rs_day-completeness = zif_ca_ops_pf_types=>gc_eval-complete.
      RETURN.
    ENDIF.
    " the source must be complete up to the deadline before an empty or short day means anything: one that lags
    " longer than the stale limit is stale (never a missing file, never a valid empty day)
    IF is_input-as_of IS INITIAL OR is_input-as_of < lv_due.
      IF add_minutes( iv_ts = COND #( WHEN is_input-as_of IS INITIAL THEN lv_due ELSE is_input-as_of )
                      iv_minutes = iv_stale_min ) < iv_now.
        rs_day-result       = zif_ca_ops_pf_types=>gc_day-stale.
        rs_day-completeness = zif_ca_ops_pf_types=>gc_eval-stale.
        rs_day-reason       = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_pf_types=>gc_msg-day_stale
                                                     iv_v1    = is_input-bus_date
                                                     iv_v2    = is_type-file_type
                                                     iv_v3    = is_input-as_of
                                                     iv_v4    = iv_stale_min ).
      ELSE.
        rs_day-result       = zif_ca_ops_pf_types=>gc_day-pending.
        rs_day-completeness = zif_ca_ops_pf_types=>gc_eval-partial.
      ENDIF.
      RETURN.
    ENDIF.
    rs_day-completeness = zif_ca_ops_pf_types=>gc_eval-complete.
    IF is_input-observed = 0 AND ( is_type-zero_ok = abap_true OR is_type-expected_files = 0 ).
      rs_day-result = zif_ca_ops_pf_types=>gc_day-zero_ok.
      rs_day-reason = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_pf_types=>gc_msg-zero_ok
                                             iv_v1    = is_input-bus_date
                                             iv_v2    = is_type-file_type ).
    ELSEIF is_input-observed = 0.
      rs_day-result = zif_ca_ops_pf_types=>gc_day-missing.
    ELSE.
      rs_day-result = zif_ca_ops_pf_types=>gc_day-partial.
    ENDIF.
  ENDMETHOD.


  METHOD severity_of_outcome.
    rv_rank = SWITCH #( iv_outcome
                        WHEN zif_ca_ops_pf_types=>gc_outcome-rejected THEN 4
                        WHEN zif_ca_ops_pf_types=>gc_outcome-failed   THEN 3
                        WHEN zif_ca_ops_pf_types=>gc_outcome-partial  THEN 2
                        WHEN zif_ca_ops_pf_types=>gc_outcome-ok       THEN 1
                        ELSE 0 ).
  ENDMETHOD.

ENDCLASS.
