*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_onboard.clas.abap
*& Purpose:
*& Onboarding (completeness) check, run every morning: every active
*& business process of ZCA_OPS_PROC is integrated end to end - at least one
*& active check (PROC_NO_CHECK, error), each of its checks covered by an
*& active control of the daily review (PROC_NO_CONTROL), an active alert
*& rule for its area (PROC_NO_ALERT_RULE), an owner who is a user of this
*& client (PROC_NO_OWNER), a purge target for own tables (PROC_NO_PURGE)
*& and authorisation coverage - a role named and the area an active
*& parameter area (PROC_NO_AUTH). One finding per gap (owned exception);
*& a closed gap is auto-resolved by the next run. Reads only through
*& ZIF_CA_OPS_CHECK_DAO, the purge registry and the authorisation service.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - process onboarding check</p>
"! Registered in the check registry (area CA_OPS, schedule group MORNING) or run by a
"! consumer's own daily report through its adapter. Findings are area-level (no company code).
CLASS zcl_ca_ops_chk_onboard DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

  PRIVATE SECTION.
    TYPES tt_target TYPE SORTED TABLE OF zif_ca_ops_chk_types=>ty_purge_target WITH UNIQUE KEY table_line.

    "! Facts of every process, read once per run
    DATA mt_checks TYPE zif_ca_ops_chk_types=>tt_check.
    DATA mt_covered TYPE zif_ca_ops_chk_types=>tt_covered.
    DATA mt_alert_areas TYPE zif_ca_ops_chk_types=>tt_area.
    DATA mt_targets TYPE tt_target.

    "! The gaps of one process
    METHODS gaps
      IMPORTING
        is_process         TYPE zif_ca_ops_chk_types=>ty_process
        io_dao             TYPE REF TO zif_ca_ops_check_dao
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

    METHODS gap
      IMPORTING
        is_process        TYPE zif_ca_ops_chk_types=>ty_process
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
        iv_msgno          TYPE zif_ca_ops_types=>ty_msgno
        iv_severity       TYPE zif_ca_ops_types=>ty_severity DEFAULT zif_ca_ops_types=>gc_severity-warning
        iv_detail         TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

ENDCLASS.



CLASS zcl_ca_ops_chk_onboard IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    DATA(lo_dao) = zcl_ca_ops_factory=>get_check_dao( ).
    DATA(lt_processes) = lo_dao->get_processes( ).
    mt_checks = lo_dao->get_all_checks( ).
    mt_covered = lo_dao->get_covered_checks( ).
    mt_alert_areas = lo_dao->get_alert_areas( ).
    CLEAR mt_targets.
    LOOP AT zcl_ca_ops_factory=>get_purge_dao( )->get_targets( ) ASSIGNING FIELD-SYMBOL(<ls_target>).
      INSERT CONV zif_ca_ops_chk_types=>ty_purge_target( <ls_target>-target ) INTO TABLE mt_targets.
    ENDLOOP.

    LOOP AT lt_processes ASSIGNING FIELD-SYMBOL(<ls_process>).
      INSERT LINES OF gaps( is_process = <ls_process>
                            io_dao     = lo_dao ) INTO TABLE rs_result-findings.
      rs_result-item_count += 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD gaps.
    DATA lv_has_check TYPE abap_bool.

    " Checks: at least one active check; each covered by an active control (GROUP2 = check ID)
    LOOP AT mt_checks ASSIGNING FIELD-SYMBOL(<ls_check>)
         WHERE area = is_process-area AND process_id = is_process-process_id.
      lv_has_check = abap_true.
      IF NOT line_exists( mt_covered[ area = <ls_check>-area check_id = <ls_check>-check_id ] ).
        DATA(ls_finding) = gap( is_process = is_process
                                iv_code    = zif_ca_ops_chk_types=>gc_code-proc_no_control
                                iv_msgno   = zif_ca_ops_chk_types=>gc_msg-proc_no_control
                                iv_detail  = <ls_check>-check_id ).
        ls_finding-object_key = |{ ls_finding-object_key }/{ <ls_check>-check_id }|.
        INSERT ls_finding INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
    IF lv_has_check = abap_false.
      INSERT gap( is_process = is_process
                  iv_code     = zif_ca_ops_chk_types=>gc_code-proc_no_check
                  iv_msgno    = zif_ca_ops_chk_types=>gc_msg-proc_no_check
                  iv_severity = zif_ca_ops_types=>gc_severity-error ) INTO TABLE rt_findings.
    ENDIF.

    " Alerting: an active rule of the process's own area (a rule of every area '*' is not a route)
    IF NOT line_exists( mt_alert_areas[ table_line = is_process-area ] ).
      INSERT gap( is_process = is_process
                  iv_code    = zif_ca_ops_chk_types=>gc_code-proc_no_alert
                  iv_msgno   = zif_ca_ops_chk_types=>gc_msg-proc_no_alert ) INTO TABLE rt_findings.
    ENDIF.

    " Ownership: an owner who is a user of this client
    IF is_process-owner IS INITIAL OR zcl_ca_ops_factory=>get_auth( )->user_exists( is_process-owner ) = abap_false.
      INSERT gap( is_process = is_process
                  iv_code    = zif_ca_ops_chk_types=>gc_code-proc_no_owner
                  iv_msgno   = zif_ca_ops_chk_types=>gc_msg-proc_no_owner
                  iv_detail  = is_process-owner ) INTO TABLE rt_findings.
    ENDIF.

    " Purge: own tables need an active purge target; a named target must be active
    IF ( is_process-own_data = abap_true AND is_process-purge_target IS INITIAL )
       OR ( is_process-purge_target IS NOT INITIAL
            AND NOT line_exists( mt_targets[ table_line = is_process-purge_target ] ) ).
      INSERT gap( is_process = is_process
                  iv_code    = zif_ca_ops_chk_types=>gc_code-proc_no_purge
                  iv_msgno   = zif_ca_ops_chk_types=>gc_msg-proc_no_purge
                  iv_detail  = is_process-purge_target ) INTO TABLE rt_findings.
    ENDIF.

    " Authorisation: a role is named and the area is one the field ZCA_PARAR takes
    IF is_process-auth_role IS INITIAL OR io_dao->is_area_active( is_process-area ) = abap_false.
      INSERT gap( is_process = is_process
                  iv_code    = zif_ca_ops_chk_types=>gc_code-proc_no_auth
                  iv_msgno   = zif_ca_ops_chk_types=>gc_msg-proc_no_auth
                  iv_detail  = is_process-auth_role ) INTO TABLE rt_findings.
    ENDIF.
  ENDMETHOD.


  METHOD gap.
    rs_finding-object_type = zif_ca_ops_chk_types=>gc_object_type-process.
    rs_finding-object_key  = |{ is_process-area }/{ is_process-process_id }|.
    rs_finding-rule_id     = zif_ca_ops_chk_types=>gc_rule_id-onboard.
    rs_finding-check_code  = iv_code.
    rs_finding-severity    = iv_severity.
    rs_finding-action      = zif_ca_ops_types=>gc_action-exception.
    rs_finding-reference   = iv_detail.
    rs_finding-message     = zcl_ca_ops_util=>text( iv_msgno = iv_msgno
                                                    iv_v1    = is_process-process_id
                                                    iv_v2    = is_process-area
                                                    iv_v3    = iv_detail ).
  ENDMETHOD.

ENDCLASS.
