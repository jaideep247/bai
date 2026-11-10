*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_regen.clas.testclasses.abap
*& Purpose:
*& Pure unit tests of the regeneration check (context built field by field,
*& no doubles): a regenerated file whose earlier generation did not fail is
*& FILE_REGENERATED_NOT_FAILED with the row severity; a regeneration after a
*& PRISM failure and a file without generation group raise nothing. Static
*& ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (regenerated files, user facts 2026-11-07).
*&---------------------------------------------------------------------*
CLASS ltc_regen_check DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_iface TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'CHECK_IRIS_OUT'.
    CONSTANTS gc_group TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261102/CHQ01/JPMC1'.
    CONSTANTS:
      BEGIN OF gc_name,
        first  TYPE zif_cd_fmon_types=>ty_file_name VALUE 'CHQ_PRINT_20261102_01.TXT',
        second TYPE zif_cd_fmon_types=>ty_file_name VALUE 'CHQ_PRINT_20261102_02.TXT',
      END OF gc_name.
    CONSTANTS:
      BEGIN OF gc_id,
        first  TYPE zif_cd_fmon_types=>ty_file_id VALUE '00000000000000000000000000000021',
        second TYPE zif_cd_fmon_types=>ty_file_id VALUE '00000000000000000000000000000022',
      END OF gc_id.
    CONSTANTS:
      BEGIN OF gc_at,
        first  TYPE timestampl VALUE '20261102150000',
        second TYPE timestampl VALUE '20261102160000',
      END OF gc_at.

    DATA ms_ctx TYPE zif_cd_fmon_types=>ty_check_ctx.

    METHODS setup.

    "! A generation in the context (in the run's files when iv_in_run)
    METHODS add_generation
      IMPORTING
        iv_id      TYPE zif_cd_fmon_types=>ty_file_id
        iv_name    TYPE zif_cd_fmon_types=>ty_file_name
        iv_at      TYPE timestampl
        iv_outcome TYPE zif_cd_fmon_types=>ty_stage OPTIONAL
        iv_group   TYPE zif_cd_fmon_types=>ty_file_ref DEFAULT gc_group
        iv_in_run  TYPE abap_bool DEFAULT abap_true.

    METHODS act
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding
      RAISING
        zcx_ca_ops_error.

    METHODS delivered_twice_is_critical FOR TESTING.
    METHODS peer_outside_run_is_used FOR TESTING.
    METHODS regen_after_failure_silent FOR TESTING.
    METHODS file_without_group_silent FOR TESTING.

ENDCLASS.


CLASS ltc_regen_check IMPLEMENTATION.

  METHOD setup.
    CLEAR ms_ctx.
  ENDMETHOD.


  METHOD add_generation.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    ls_file-file_id        = iv_id.
    ls_file-iface_id       = gc_iface.
    ls_file-direction      = zif_cd_fmon_types=>gc_direction-outbound.
    ls_file-file_name      = iv_name.
    ls_file-file_ref       = zcl_cd_fmon_util=>normalize_ref( iv_name ).
    ls_file-gen_group      = iv_group.
    ls_file-stage          = COND #( WHEN iv_outcome IS NOT INITIAL THEN iv_outcome
                                     ELSE zif_cd_fmon_types=>gc_stage-prism_delivered ).
    ls_file-outcome        = iv_outcome.
    ls_file-first_event_at = iv_at.
    ls_file-last_event_at  = iv_at.
    IF iv_in_run = abap_true.
      INSERT ls_file INTO TABLE ms_ctx-files.
    ENDIF.
    IF iv_group IS NOT INITIAL.
      INSERT ls_file INTO TABLE ms_ctx-generations.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    DATA ls_check TYPE zif_cd_fmon_types=>ty_chk.
    ls_check-check_id = 'F_REGEN'.
    ls_check-severity = zif_ca_ops_types=>gc_severity-block.
    rt_findings = NEW zcl_cd_fmon_chk_regen( )->zif_cd_fmon_check~execute( is_ctx   = ms_ctx
                                                                          is_check = ls_check ).
  ENDMETHOD.


  " Rule (c): both generations of the payment run delivered - the regenerated file is reported with
  " the row severity (critical), naming the earlier file and its state.
  METHOD delivered_twice_is_critical.
    TRY.
        add_generation( iv_id = gc_id-first iv_name = gc_name-first iv_at = gc_at-first ).
        add_generation( iv_id = gc_id-second iv_name = gc_name-second iv_at = gc_at-second ).
        DATA(lt_findings) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_findings )
                                            exp = 1
                                            msg = 'Only the regenerated file is reported' ).
        DATA(ls_finding) = lt_findings[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code
                                            exp = zif_cd_fmon_types=>gc_check_code-regen_not_failed
                                            msg = 'Possible duplicate payment file' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key
                                            exp = gc_name-second
                                            msg = 'On the regenerated file' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity
                                            exp = zif_ca_ops_types=>gc_severity-block
                                            msg = 'Severity of the check row (seed B)' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_finding-message
                                             exp = |*{ gc_name-first }*|
                                             msg = 'The earlier generation is named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (instant unit): the earlier generation is only in the context's generations (read by
  " index GRP), not among the run's files - it still decides.
  METHOD peer_outside_run_is_used.
    TRY.
        add_generation( iv_id = gc_id-first iv_name = gc_name-first iv_at = gc_at-first iv_in_run = abap_false ).
        add_generation( iv_id = gc_id-second iv_name = gc_name-second iv_at = gc_at-second ).
        cl_abap_unit_assert=>assert_equals( act = lines( act( ) )
                                            exp = 1
                                            msg = 'The peer read from the registry is compared' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (negative): regeneration after a PRISM failure is the expected recovery.
  METHOD regen_after_failure_silent.
    TRY.
        add_generation( iv_id      = gc_id-first
                        iv_name    = gc_name-first
                        iv_at      = gc_at-first
                        iv_outcome = zif_cd_fmon_types=>gc_stage-prism_failed ).
        add_generation( iv_id = gc_id-second iv_name = gc_name-second iv_at = gc_at-second ).
        cl_abap_unit_assert=>assert_initial( act = act( )
                                             msg = 'No duplicate after a failure' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (no generation group configured): never reported - behaviour as before.
  METHOD file_without_group_silent.
    TRY.
        add_generation( iv_id = gc_id-first iv_name = gc_name-first iv_at = gc_at-first iv_group = space ).
        add_generation( iv_id = gc_id-second iv_name = gc_name-second iv_at = gc_at-second iv_group = space ).
        cl_abap_unit_assert=>assert_initial( act = act( )
                                             msg = 'Files without generation group are not linked' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
