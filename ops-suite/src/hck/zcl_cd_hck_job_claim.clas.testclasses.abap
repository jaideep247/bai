*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_job_claim.clas.testclasses.abap
*& Purpose:
*& Unit tests of the health check's claim towards the SAP job monitor: a
*& job matching a step of a cycle that an active job-cycle check reports is
*& claimed with its cycle and step; a job of no step is not; without an
*& active job-cycle check nothing is claimed (the job monitor reports every
*& failure). HCK data access double through the HCK injector. Does not
*& prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption: de-duplication with the job cycles).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_defs TYPE zif_cd_hck_types=>tt_check_def.
    DATA mt_steps TYPE zif_cd_hck_types=>tt_cycle_step.
    DATA mt_asked TYPE zif_ca_ops_types=>tt_pcre.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_check_defs.
    rt_defs = mt_defs.
  ENDMETHOD.
  METHOD zif_cd_hck_dao~get_cycle_steps.
    mt_asked = it_cycle_ids.
    rt_steps = mt_steps.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_job_claim DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_cycle  TYPE zif_cd_hck_types=>ty_cycle_id VALUE 'DISB_DAY',
      gc_step   TYPE zif_cd_hck_types=>ty_step_no VALUE '040',
      gc_count  TYPE btcjobcnt VALUE '10000001'.

    TYPES:
      BEGIN OF ty_flags,
        cycle_check TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.

    METHODS setup.
    METHODS teardown.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      IMPORTING
        iv_jobname       TYPE btcjob
      RETURNING
        VALUE(rt_claims) TYPE zif_ca_ops_job_types=>tt_claim
      RAISING
        zcx_ca_ops_error.

    METHODS cycle_step_is_claimed   FOR TESTING.
    METHODS other_job_not_claimed   FOR TESTING.
    METHODS no_cycle_check_no_claim FOR TESTING.
ENDCLASS.


CLASS ltc_job_claim IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-cycle_check = abap_true.
      INSERT VALUE #( check_id = 'B_CYCLE_TODAY' class_name = zif_cd_job_types=>gc_cycle_check_class active = abap_true
                      param2 = '(?!CLEARING).*' ) INTO TABLE mo_dao->mt_defs.
    ENDIF.
    INSERT VALUE #( check_id = 'E_JOBS' class_name = 'ZCL_CD_HCK_C_TECH_JOBS' active = abap_true param1 = 'ZCD_.*' )
      INTO TABLE mo_dao->mt_defs.
    INSERT VALUE #( cycle_id = gc_cycle step_no = gc_step jobname = 'ZPAYM_WIRE_CORP.*' critical = abap_true )
      INTO TABLE mo_dao->mt_steps.
  ENDMETHOD.


  METHOD act.
    rt_claims = NEW zcl_cd_hck_job_claim( )->zif_ca_ops_job_claim~claimed(
                  VALUE #( ( jobname = iv_jobname jobcount = gc_count ) ) ).
  ENDMETHOD.


  " Rule: a step of a cycle an active job-cycle check reports stays with the health check
  METHOD cycle_step_is_claimed.
    TRY.
        configure_scenario( VALUE #( cycle_check = abap_true ) ).
        DATA(lt_claims) = act( 'ZPAYM_WIRE_CORP_0130' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_claims ) exp = 1 msg = 'Claimed' ).
        cl_abap_unit_assert=>assert_equals( act = lt_claims[ 1 ]-claimer exp = |HCK { gc_cycle }/{ gc_step }|
                                            msg = 'By the cycle step' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_asked ) exp = 1
                                            msg = 'Cycles of the check''s PARAM2' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every other job is the job monitor's (E_JOBS covers every ZCD_ job and is no claim)
  METHOD other_job_not_claimed.
    TRY.
        configure_scenario( VALUE #( cycle_check = abap_true ) ).
        cl_abap_unit_assert=>assert_initial( act = act( 'ZCD_POST_DOCS' ) msg = 'Not a cycle step' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no active job-cycle check - nothing is claimed
  METHOD no_cycle_check_no_claim.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_initial( act = act( 'ZPAYM_WIRE_CORP_0130' ) msg = 'No claim' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
