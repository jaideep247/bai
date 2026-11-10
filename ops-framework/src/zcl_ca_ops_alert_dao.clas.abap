*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_alert_dao.clas.abap
*& Purpose:
*& SQL for the alert router: rules (area or '*'), channels and the delivery
*& log. The log write is part of the caller's LUW (the engine commits).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | claim / complete (durable claim before send), get_repeat_keys (audit A17); escalation override read (A46).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-10 | Moved from ZCL_CD_OPS_ALERT_DAO to the reusable framework ZCA_OPS.
*& 2026-11-10 | Template fields of rules, channels and log rows; COMPLETE writes the rendered subject and
*&            | the render outcome; GET_EXCEPTION_FACTS (e-mail context: new / repeated / overdue, due date).
*& 2026-11-10 | Pilot review: routing decisions were logged with a blank intent key and attempt 0, so with
*&            | the unique index INT a second decision collided and ACCEPTING DUPLICATE KEYS dropped it
*&            | silently. A row without an intent now carries its alert ID (hex, 32 characters - a dispatch
*&            | intent is a 40-character SHA-1, so the two never meet); rows the database refuses raise 081;
*&            | COMPLETE's fallback insert is checked as well.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert repository</p>
CLASS zcl_ca_ops_alert_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_dao.



ENDCLASS.



CLASS zcl_ca_ops_alert_dao IMPLEMENTATION.

  METHOD zif_ca_ops_alert_dao~get_rules.
    SELECT rule_id, area, min_severity, rule_pattern, check_pattern, group1_pattern,
           group2_pattern, min_rag, on_abort, channel, destination, digest, max_items,
           throttle_min, quiet_from, quiet_to, escalate_after, escalation_dest, esc_override, active,
           template_id, show_amounts
      FROM zca_ops_alrule
      WHERE ( area = @iv_area OR area = @zif_ca_ops_types=>gc_area_any )
        AND active = @abap_true
      ORDER BY rule_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_rules.
  ENDMETHOD.


  METHOD zif_ca_ops_alert_dao~get_channels.
    SELECT channel, class_name, destination, active, template_id
      FROM zca_ops_alchn
      ORDER BY channel
      INTO CORRESPONDING FIELDS OF TABLE @rt_channels.
  ENDMETHOD.


  METHOD zif_ca_ops_alert_dao~get_log.
    SELECT alert_id, rule_id, channel, run_id, area, sent_at, status, destination, subject, error,
           intent_key, attempt, template_id, renderer, render_info
      FROM zca_ops_allog
      WHERE rule_id  = @iv_rule_id
        AND sent_at >= @iv_since
      ORDER BY sent_at DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt_log.
  ENDMETHOD.


  METHOD zif_ca_ops_alert_dao~insert_log.
    DATA lt_db TYPE STANDARD TABLE OF zca_ops_allog WITH EMPTY KEY.
    DATA ls_db TYPE zca_ops_allog.
    IF it_log IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT it_log ASSIGNING FIELD-SYMBOL(<ls_log>).
      CLEAR ls_db.
      ls_db-alert_id    = <ls_log>-alert_id.
      ls_db-rule_id     = <ls_log>-rule_id.
      ls_db-channel     = <ls_log>-channel.
      ls_db-run_id      = <ls_log>-run_id.
      ls_db-area      = <ls_log>-area.
      ls_db-sent_at     = <ls_log>-sent_at.
      ls_db-status      = <ls_log>-status.
      ls_db-destination = <ls_log>-destination.
      ls_db-subject     = <ls_log>-subject.
      ls_db-error       = <ls_log>-error.
      ls_db-intent_key  = <ls_log>-intent_key.
      ls_db-attempt     = <ls_log>-attempt.
      IF ls_db-intent_key IS INITIAL.
        " a routing decision, not a dispatch attempt: its own alert ID keeps it unique in index INT
        ls_db-intent_key = |{ <ls_log>-alert_id }|.
        ls_db-attempt    = 0.
      ENDIF.
      ls_db-template_id = <ls_log>-template_id.
      ls_db-renderer    = <ls_log>-renderer.
      ls_db-render_info = <ls_log>-render_info.
      ls_db-created_by  = sy-uname.
      INSERT ls_db INTO TABLE lt_db.
    ENDLOOP.
    " The other rows are kept even if one is refused, but a refused row is reported, never skipped
    INSERT zca_ops_allog FROM TABLE @lt_db ACCEPTING DUPLICATE KEYS.
    IF sy-dbcnt <> lines( lt_db ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e081(zca_ops) WITH |{ lines( lt_db ) - sy-dbcnt }| |{ lines( lt_db ) }|.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_alert_dao~claim.
    DATA ls_db TYPE zca_ops_allog.
    " A17: an intent that is claimed (in delivery) or sent is never sent again; a failed
    " intent may be retried with the next attempt number
    SELECT intent_key, attempt, status
      FROM zca_ops_allog
      WHERE intent_key = @is_log-intent_key
      ORDER BY attempt DESCENDING
      INTO TABLE @DATA(lt_attempts).
    LOOP AT lt_attempts TRANSPORTING NO FIELDS
         WHERE status = zif_ca_ops_types=>gc_alert_status-claimed
            OR status = zif_ca_ops_types=>gc_alert_status-sent
            OR status = zif_ca_ops_types=>gc_alert_status-partial.
      rv_claimed_elsewhere = abap_true.
      RETURN.
    ENDLOOP.
    ls_db-alert_id    = is_log-alert_id.
    ls_db-rule_id     = is_log-rule_id.
    ls_db-channel     = is_log-channel.
    ls_db-run_id      = is_log-run_id.
    ls_db-area     = is_log-area.
    ls_db-sent_at     = is_log-sent_at.
    ls_db-status      = zif_ca_ops_types=>gc_alert_status-claimed.
    ls_db-destination = is_log-destination.
    ls_db-subject     = is_log-subject.
    ls_db-intent_key  = is_log-intent_key.
    ls_db-attempt     = lines( lt_attempts ) + 1.
    ls_db-template_id = is_log-template_id.
    ls_db-created_by  = sy-uname.
    " the unique index INT (MANDT, INTENT_KEY, ATTEMPT) rejects a parallel dispatcher
    INSERT zca_ops_allog FROM @ls_db.
    rv_claimed_elsewhere = xsdbool( sy-subrc <> 0 ).
  ENDMETHOD.


  METHOD zif_ca_ops_alert_dao~complete.
    UPDATE zca_ops_allog
      SET status      = @is_log-status,
          error       = @is_log-error,
          sent_at     = @is_log-sent_at,
          subject     = @is_log-subject,
          template_id = @is_log-template_id,
          renderer    = @is_log-renderer,
          render_info = @is_log-render_info
      WHERE alert_id = @is_log-alert_id.
    IF sy-subrc <> 0.
      " the claim row is gone (purged): keep the evidence as a new row
      INSERT zca_ops_allog FROM @( CORRESPONDING #( is_log ) ).
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e081(zca_ops) WITH '1' '1'.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_alert_dao~get_repeat_keys.
    SELECT object_type, object_key, check_code
      FROM zca_ops_finding
      WHERE run_id      = @iv_run_id
        AND occurrences > 1
      ORDER BY object_type, object_key, check_code
      INTO TABLE @DATA(lt_rows).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT CORRESPONDING #( <ls_row> ) INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_alert_dao~get_exception_facts.
    " one read per dispatch, by the key of the run (primary key prefix RUN_ID)
    SELECT object_type, object_key, check_code, occurrences, due_date, owner
      FROM zca_ops_finding
      WHERE run_id = @iv_run_id
        AND ( disposition = @zif_ca_ops_types=>gc_disposition-open
           OR disposition = @zif_ca_ops_types=>gc_disposition-assigned )
      ORDER BY object_type, object_key, check_code
      INTO TABLE @DATA(lt_rows).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      " a duplicate key (same object and check twice in one run) keeps the first row
      INSERT CORRESPONDING #( <ls_row> ) INTO TABLE rt_facts.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
