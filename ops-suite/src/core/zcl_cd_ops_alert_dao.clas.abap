*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_alert_dao.clas.abap
*& Purpose:
*& SQL for the alert router: rules (module or '*'), channels and the delivery
*& log. The log write is part of the caller's LUW (the engine commits).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - alert repository</p>
CLASS zcl_cd_ops_alert_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_dao.

    CONSTANTS gc_any_module TYPE zif_cd_ops_types=>ty_module VALUE '*'.

ENDCLASS.



CLASS zcl_cd_ops_alert_dao IMPLEMENTATION.

  METHOD zif_cd_ops_alert_dao~get_rules.
    SELECT rule_id, module, min_severity, rule_pattern, check_pattern, group1_pattern,
           group2_pattern, min_rag, on_abort, channel, destination, digest, max_items,
           throttle_min, quiet_from, quiet_to, escalate_after, escalation_dest, active
      FROM zcd_ops_alert_rule
      WHERE ( module = @iv_module OR module = @gc_any_module )
        AND active = @abap_true
      ORDER BY rule_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_rules.
  ENDMETHOD.


  METHOD zif_cd_ops_alert_dao~get_channels.
    SELECT channel, class_name, destination, active
      FROM zcd_ops_alert_chn
      ORDER BY channel
      INTO CORRESPONDING FIELDS OF TABLE @rt_channels.
  ENDMETHOD.


  METHOD zif_cd_ops_alert_dao~get_log.
    SELECT alert_id, rule_id, channel, run_id, module, sent_at, status, destination, subject, error
      FROM zcd_ops_alert_log
      WHERE rule_id  = @iv_rule_id
        AND sent_at >= @iv_since
      ORDER BY sent_at DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt_log.
  ENDMETHOD.


  METHOD zif_cd_ops_alert_dao~insert_log.
    DATA lt_db TYPE STANDARD TABLE OF zcd_ops_alert_log WITH EMPTY KEY.
    DATA ls_db TYPE zcd_ops_alert_log.
    IF it_log IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT it_log INTO DATA(ls_log).
      CLEAR ls_db.
      ls_db-alert_id    = ls_log-alert_id.
      ls_db-rule_id     = ls_log-rule_id.
      ls_db-channel     = ls_log-channel.
      ls_db-run_id      = ls_log-run_id.
      ls_db-module      = ls_log-module.
      ls_db-sent_at     = ls_log-sent_at.
      ls_db-status      = ls_log-status.
      ls_db-destination = ls_log-destination.
      ls_db-subject     = ls_log-subject.
      ls_db-error       = ls_log-error.
      ls_db-created_by  = sy-uname.
      INSERT ls_db INTO TABLE lt_db.
    ENDLOOP.
    " Audit rows; a duplicate key (UUID collision) must not lose the others, so
    " sy-subrc 4 (some rows skipped) is accepted deliberately
    INSERT zcd_ops_alert_log FROM TABLE @lt_db ACCEPTING DUPLICATE KEYS. "#EC CI_SUBRC
  ENDMETHOD.

ENDCLASS.
