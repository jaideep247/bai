*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_job_claim.clas.abap
*& Purpose:
*& Claim of the morning health check towards the framework's SAP job
*& monitor (ZIF_CA_OPS_JOB_CLAIM, parameter JOB_CLAIMS): the steps of the
*& named job cycles stay with the health check - a job whose name matches a
*& step of an active cycle that an active job-cycle check reports
*& (ZCL_CD_HCK_C_JOB_CYCLE: B_CYCLE_*, B_CLEAR_*; cycles of their PARAM2
*& patterns) is claimed, so the job monitor (area CD_JOBS) keeps its
*& evidence as information and never alerts it a second time. Every other
*& failure, and every failed child of a claimed job, is CD_JOBS's (split
*& documented in docs/HCK_MORNING_REPORT.md section 9b). Read only, through
*& the health check's data access.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption: de-duplication with the job cycles).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - claim of named job cycles (job monitor)</p>
CLASS zcl_cd_hck_job_claim DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_claim.

ENDCLASS.



CLASS zcl_cd_hck_job_claim IMPLEMENTATION.

  METHOD zif_ca_ops_job_claim~claimed.
    DATA lt_cycles TYPE zif_ca_ops_types=>tt_pcre.
    DATA lv_all TYPE abap_bool.

    IF it_jobs IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    " the cycles the active job-cycle checks report (PARAM2 patterns; blank = every cycle)
    DATA(lv_cycle_checks) = 0.
    LOOP AT lo_dao->get_check_defs( ) ASSIGNING FIELD-SYMBOL(<ls_def>)
         WHERE class_name = zif_cd_job_types=>gc_cycle_check_class.
      lv_cycle_checks += 1.
      DATA(lt_patterns) = zcl_cd_hck_param=>patterns( <ls_def>-param2 ).
      IF lt_patterns IS INITIAL.
        lv_all = abap_true.
      ENDIF.
      INSERT LINES OF lt_patterns INTO TABLE lt_cycles.
    ENDLOOP.
    IF lv_cycle_checks = 0.
      RETURN.
    ENDIF.
    IF lv_all = abap_true.
      CLEAR lt_cycles.
    ENDIF.
    DATA(lt_steps) = lo_dao->get_cycle_steps( lt_cycles ).
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      LOOP AT lt_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
        IF zcl_ca_ops_util=>pcre_valid( <ls_step>-jobname ) = abap_true
           AND zcl_ca_ops_util=>pcre_match( iv_value = <ls_job>-jobname iv_pattern = <ls_step>-jobname ) = abap_true.
          INSERT VALUE #( jobname  = <ls_job>-jobname
                          jobcount = <ls_job>-jobcount
                          claimer  = |{ zif_cd_job_types=>gc_claimer_prefix } { <ls_step>-cycle_id }/{ <ls_step>-step_no }| )
            INTO TABLE rt_claims.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
