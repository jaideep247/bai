*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_sla.clas.abap
*& Purpose:
*& Plug-in check for every ZCD_FMON_SLA row: NO_PRISM_HANDOFF, NO_BANK_ACK,
*& PRISM_HANDOFF_LATE, BANK_ACK_LATE, ... Optional parameter STAGE limits
*& one configured check to one stage; LATE_SEVERITY (default W).
*& PRISM throttle: a throttled file's delivery stage (and a later stage measured
*& before the delivery) is allowed the queue wait of its PRISM queue position;
*& a queue longer than FMON_PRISM_QUEUE_MAX is reported as PRISM_QUEUE_LONG (W).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Audit A40: INFERRED verdicts reported as information.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | PRISM throttle (user 2026-11-06): queue allowance from the check context
*&              (ZCL_CD_FMON_RULES=>QUEUE_POSITION), PRISM_QUEUE_LONG on the delivery stage.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - stage SLA (PRISM handoff, bank ack)</p>
"! Rules: ZCL_CD_FMON_RULES=>SLA_VERDICT / SLA_CODE / QUEUE_POSITION. Params: STAGE=, LATE_SEVERITY=W
"! Ack stages are skipped for interfaces without ack (ACK_EXPECTED blank).
"! The batch run and the instant PRISM unit (run_event) both reach this check through the
"! engine's check context, so the queue allowance is the same on both paths.
CLASS zcl_cd_fmon_chk_sla DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

ENDCLASS.



CLASS zcl_cd_fmon_chk_sla IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    DATA lv_queue_reported TYPE abap_bool.

    DATA(lv_stage) = CONV zif_cd_fmon_types=>ty_stage( to_upper( zcl_cd_fmon_util=>param(
                       iv_params = is_check-params iv_name = 'STAGE' ) ) ).
    DATA(lv_late_severity) = CONV zif_cd_ops_types=>ty_severity( zcl_cd_fmon_util=>param(
                               iv_params = is_check-params iv_name = 'LATE_SEVERITY' iv_default = `W` ) ).

    LOOP AT is_ctx-files ASSIGNING FIELD-SYMBOL(<ls_file>).
      READ TABLE is_ctx-ifaces INTO DATA(ls_iface) WITH TABLE KEY iface_id = <ls_file>-iface_id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      " PRISM throttle: position of the file in its PRISM queue (not QUEUED = no allowance)
      DATA(ls_queue) = zcl_cd_fmon_rules=>queue_position( iv_file_id  = <ls_file>-file_id
                                                         it_queue    = is_ctx-queue
                                                         is_throttle = is_ctx-throttle ).
      DATA(lv_queue_length) = ls_queue-ahead + 1.
      lv_queue_reported = abap_false.
      LOOP AT is_ctx-slas ASSIGNING FIELD-SYMBOL(<ls_sla>) WHERE iface_id = <ls_file>-iface_id.
        IF ( lv_stage IS NOT INITIAL AND <ls_sla>-stage <> lv_stage )
           OR ( <ls_sla>-stage = zif_cd_fmon_types=>gc_stage-ack AND ls_iface-ack_expected = abap_false ).
          CONTINUE.
        ENDIF.
        " A jammed PRISM queue stays visible: the allowance is capped, the length is reported once
        IF ls_queue-long = abap_true AND lv_queue_reported = abap_false
           AND zcl_cd_fmon_rules=>is_queue_stage( <ls_sla>-stage ) = abap_true.
          lv_queue_reported = abap_true.
          INSERT zcl_cd_fmon_util=>new_finding(
                   is_file     = <ls_file>
                   is_check    = is_check
                   iv_code     = zif_cd_fmon_types=>gc_check_code-prism_queue_long
                   iv_severity = zif_cd_ops_types=>gc_severity-warning
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-prism_queue_long
                                                        iv_v1    = <ls_file>-file_name
                                                        iv_v2    = lv_queue_length
                                                        iv_v3    = is_ctx-throttle-queue_max ) ) INTO TABLE rt_findings.
        ENDIF.
        DATA(ls_verdict) = zcl_cd_fmon_rules=>sla_verdict( is_file      = <ls_file>
                                                          is_sla       = <ls_sla>
                                                          it_events    = is_ctx-events
                                                          iv_now       = is_ctx-now
                                                          iv_queue_min = ls_queue-delay_min ).
        IF ls_verdict-state = zif_cd_fmon_types=>gc_sla_state-ok.
          CONTINUE.
        ENDIF.
        INSERT zcl_cd_fmon_util=>new_finding(
                 is_file     = <ls_file>
                 is_check    = is_check
                 iv_code     = zcl_cd_fmon_rules=>sla_code( iv_stage = <ls_sla>-stage iv_state = ls_verdict-state )
                 iv_severity = COND #( WHEN ls_verdict-state = zif_cd_fmon_types=>gc_sla_state-late
                                       THEN lv_late_severity
                                       " Audit A40: a stage passed without its own evidence - visible, not an error
                                       WHEN ls_verdict-state = zif_cd_fmon_types=>gc_sla_state-inferred
                                       THEN zif_cd_ops_types=>gc_severity-info
                                       ELSE <ls_sla>-severity )
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = COND #( WHEN ls_verdict-queue_min > 0
                                                                        THEN zif_cd_fmon_types=>gc_msg-after_min_sla_queue_min
                                                                        ELSE zif_cd_fmon_types=>gc_msg-after_min_sla_min )
                                                      iv_v1    = <ls_file>-file_name
                                                      iv_v2    = <ls_sla>-stage
                                                      iv_v3    = ls_verdict-elapsed_min
                                                      iv_v4    = ls_verdict-allowed_min ) ) INTO TABLE rt_findings.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
