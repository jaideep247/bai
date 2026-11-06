*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_prism_file.clas.abap
*& Purpose:
*& Plug-in check: PRISM evidence (PRISM status API) that SAP's own evidence
*& does not confirm. PRISM_UNKNOWN_FILE - outbound file PRISM reported but
*& SAP has no generation / send record of; PRISM_NOT_LOADED - inbound file
*& PRISM delivered that SAP has not received; both only after GRACE_MIN minutes
*& (SAP's own evidence is read every 5 minutes). Pure.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API: unknown files never vanish).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - PRISM evidence not confirmed by SAP</p>
"! Params: GRACE_MIN=60 - minutes after the first PRISM event (outbound) / PRISM_DELIVERED
"! (inbound) before a finding: PRISM is often faster than the next read of SAP's evidence.
"! A PRISM event whose file reference matches no interface is UNMAPPED_FILE (engine);
"! one that matches an interface but no SAP file is caught here.
CLASS zcl_cd_fmon_chk_prism_file DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

  PRIVATE SECTION.
    "! Name and default of the check parameter (ZCD_FMON_CHK-PARAMS)
    CONSTANTS gc_param_grace TYPE string VALUE `GRACE_MIN`.
    CONSTANTS gc_default_grace TYPE i VALUE 60.

    "! What the events of one file show
    TYPES:
      BEGIN OF ty_evidence,
        file_id      TYPE zif_cd_fmon_types=>ty_file_id,
        prism        TYPE abap_bool,
        first_prism  TYPE timestampl,
        sap_outbound TYPE abap_bool,
        delivered_at TYPE timestampl,
      END OF ty_evidence.
    TYPES tt_evidence TYPE HASHED TABLE OF ty_evidence WITH UNIQUE KEY file_id.

    CLASS-METHODS collect
      IMPORTING
        it_events          TYPE zif_cd_fmon_types=>tt_event
      RETURNING
        VALUE(rt_evidence) TYPE tt_evidence.

    CLASS-METHODS is_prism_stage
      IMPORTING
        iv_stage        TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_prism) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_fmon_chk_prism_file IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    DATA(lv_grace) = zcl_cd_fmon_util=>param_int( iv_params  = is_check-params
                                                  iv_name    = gc_param_grace
                                                  iv_default = gc_default_grace ).
    DATA(lt_evidence) = collect( is_ctx-events ).
    DATA(lv_received_rank) = zcl_cd_fmon_status=>rank( iv_stage     = zif_cd_fmon_types=>gc_stage-received
                                                       iv_direction = zif_cd_fmon_types=>gc_direction-inbound ).

    LOOP AT is_ctx-files ASSIGNING FIELD-SYMBOL(<ls_file>).
      READ TABLE lt_evidence ASSIGNING FIELD-SYMBOL(<ls_evidence>) WITH TABLE KEY file_id = <ls_file>-file_id.
      IF sy-subrc <> 0 OR <ls_evidence>-prism = abap_false.
        CONTINUE.
      ENDIF.
      DATA(lv_name) = COND string( WHEN <ls_file>-file_name IS NOT INITIAL THEN <ls_file>-file_name
                                   ELSE <ls_file>-file_ref ).
      CASE <ls_file>-direction.
        WHEN zif_cd_fmon_types=>gc_direction-outbound.
          IF <ls_evidence>-sap_outbound = abap_false
             AND zcl_cd_fmon_util=>minutes_between( iv_from = <ls_evidence>-first_prism
                                                    iv_to   = is_ctx-now ) > lv_grace.
            INSERT zcl_cd_fmon_util=>new_finding(
                     is_file    = <ls_file>
                     is_check   = is_check
                     iv_code    = zif_cd_fmon_types=>gc_check_code-prism_unknown
                     iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-prism_unknown_file
                                                         iv_v1    = lv_name ) ) INTO TABLE rt_findings.
          ENDIF.
        WHEN zif_cd_fmon_types=>gc_direction-inbound.
          " SAP's own receipt (FILE_RECEIVED or later) confirms the delivery
          IF <ls_evidence>-delivered_at IS INITIAL
             OR zcl_cd_fmon_status=>rank( iv_stage     = <ls_file>-stage
                                          iv_direction = <ls_file>-direction ) >= lv_received_rank.
            CONTINUE.
          ENDIF.
          DATA(lv_minutes) = zcl_cd_fmon_util=>minutes_between( iv_from = <ls_evidence>-delivered_at
                                                                iv_to   = is_ctx-now ).
          IF lv_minutes > lv_grace.
            INSERT zcl_cd_fmon_util=>new_finding(
                     is_file    = <ls_file>
                     is_check   = is_check
                     iv_code    = zif_cd_fmon_types=>gc_check_code-prism_not_loaded
                     iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-prism_not_loaded
                                                         iv_v1    = lv_name
                                                         iv_v2    = lv_minutes ) ) INTO TABLE rt_findings.
          ENDIF.
        WHEN OTHERS.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD collect.
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>).
      READ TABLE rt_evidence ASSIGNING FIELD-SYMBOL(<ls_evidence>) WITH TABLE KEY file_id = <ls_event>-file_id.
      IF sy-subrc <> 0.
        INSERT VALUE #( file_id = <ls_event>-file_id ) INTO TABLE rt_evidence ASSIGNING <ls_evidence>.
      ENDIF.
      IF is_prism_stage( <ls_event>-stage ) = abap_true.
        <ls_evidence>-prism = abap_true.
        IF <ls_evidence>-first_prism IS INITIAL OR <ls_event>-event_at < <ls_evidence>-first_prism.
          <ls_evidence>-first_prism = <ls_event>-event_at.
        ENDIF.
      ENDIF.
      " SAP's own outbound evidence: generation or hand-over to PRISM
      IF <ls_event>-stage = zif_cd_fmon_types=>gc_stage-generated
         OR <ls_event>-stage = zif_cd_fmon_types=>gc_stage-sent.
        <ls_evidence>-sap_outbound = abap_true.
      ENDIF.
      IF <ls_event>-stage = zif_cd_fmon_types=>gc_stage-prism_delivered
         AND ( <ls_evidence>-delivered_at IS INITIAL OR <ls_event>-event_at < <ls_evidence>-delivered_at ).
        <ls_evidence>-delivered_at = <ls_event>-event_at.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_prism_stage.
    rv_prism = xsdbool( iv_stage = zif_cd_fmon_types=>gc_stage-prism_received
                     OR iv_stage = zif_cd_fmon_types=>gc_stage-prism_delivered
                     OR iv_stage = zif_cd_fmon_types=>gc_stage-prism_failed ).
  ENDMETHOD.

ENDCLASS.
