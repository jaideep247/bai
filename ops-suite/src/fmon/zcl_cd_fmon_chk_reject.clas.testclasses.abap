*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_reject.clas.testclasses.abap
*& Purpose:
*& Pure unit tests of the reject check: parameter OUTCOME=PRISM_FAILED reports
*& only PRISM failures; without it NACK / FAILED as before. Static ABAP Unit
*& only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API: check row F_PRFAIL).
*& 2026-11-07 | Regenerated files (user 2026-11-07): a replaced failed file is FILE_REPLACED (information,
*&            | names the replacing file), a duplicate-name rejection PRISM_DUPLICATE_NAME instead of
*&            | PRISM_FAILED, an overdue regeneration REGENERATION_MISSING next to PRISM_FAILED.
*&---------------------------------------------------------------------*
CLASS ltc_reject DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA ms_ctx TYPE zif_cd_fmon_types=>ty_check_ctx.

    METHODS setup.

    METHODS act
      IMPORTING
        iv_params       TYPE zif_cd_fmon_types=>ty_params OPTIONAL
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        zcx_cd_ops_error.

    METHODS add_file
      IMPORTING
        iv_name    TYPE zif_cd_fmon_types=>ty_file_name
        iv_outcome TYPE zif_cd_fmon_types=>ty_stage.

    "! Regenerated files: the PRISM_FAILED file ACH_PNC_1 belongs to generation group GC_GROUP
    METHODS add_generation
      IMPORTING
        iv_name TYPE zif_cd_fmon_types=>ty_file_name
        iv_at   TYPE timestampl.

    METHODS findings
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding
      RAISING
        zcx_cd_ops_error.

    CONSTANTS gc_group TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261102/RUN01'.
    CONSTANTS gc_failed TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_PNC_1'.
    CONSTANTS gc_regen TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_PNC_1_REGEN'.
    CONSTANTS gc_dup_code TYPE zif_cd_fmon_types=>ty_prism_error VALUE 'NAME_EXISTS'.
    CONSTANTS gc_prism_params TYPE zif_cd_fmon_types=>ty_params VALUE 'OUTCOME=PRISM_FAILED'.
    CONSTANTS:
      BEGIN OF gc_at,
        generated TYPE timestampl VALUE '20261102170000',
        failed    TYPE timestampl VALUE '20261102171000',
        regen     TYPE timestampl VALUE '20261102174000',
        late      TYPE timestampl VALUE '20261102190000',
      END OF gc_at.

    METHODS prism_param_only_prism FOR TESTING.
    METHODS default_ignores_prism_failed FOR TESTING.
    METHODS replaced_file_is_information FOR TESTING.
    METHODS dup_name_replaces_failed FOR TESTING.
    METHODS overdue_regen_adds_missing FOR TESTING.

ENDCLASS.


CLASS ltc_reject IMPLEMENTATION.

  METHOD setup.
    CLEAR ms_ctx.
    add_file( iv_name = 'ACH_PNC_1' iv_outcome = zif_cd_fmon_types=>gc_stage-prism_failed ).
    add_file( iv_name = 'ACH_PNC_2' iv_outcome = zif_cd_fmon_types=>gc_stage-nack ).
    add_file( iv_name = 'ACH_RET_3' iv_outcome = zif_cd_fmon_types=>gc_stage-failed ).
  ENDMETHOD.


  METHOD add_file.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    ls_file-file_name = iv_name.
    ls_file-file_ref  = zcl_cd_fmon_util=>normalize_ref( iv_name ).
    ls_file-outcome   = iv_outcome.
    ls_file-stage     = iv_outcome.
    INSERT ls_file INTO TABLE ms_ctx-files.
  ENDMETHOD.


  METHOD add_generation.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    " The failed file of the context joins the group; the regenerated file is another generation
    ASSIGN ms_ctx-files[ file_name = gc_failed ] TO FIELD-SYMBOL(<ls_failed>).
    <ls_failed>-iface_id       = 'ACH_PNC_OUT'.
    <ls_failed>-file_id        = '00000000000000000000000000000001'.
    <ls_failed>-gen_group      = gc_group.
    <ls_failed>-first_event_at = gc_at-generated.
    <ls_failed>-last_event_at  = gc_at-failed.
    INSERT <ls_failed> INTO TABLE ms_ctx-generations.
    IF iv_name IS INITIAL.
      RETURN.
    ENDIF.
    ls_file = <ls_failed>.
    ls_file-file_id        = '00000000000000000000000000000002'.
    ls_file-file_name      = iv_name.
    ls_file-file_ref       = zcl_cd_fmon_util=>normalize_ref( iv_name ).
    ls_file-stage          = zif_cd_fmon_types=>gc_stage-generated.
    CLEAR ls_file-outcome.
    ls_file-first_event_at = iv_at.
    ls_file-last_event_at  = iv_at.
    INSERT ls_file INTO TABLE ms_ctx-generations.
  ENDMETHOD.


  METHOD findings.
    DATA ls_check TYPE zif_cd_fmon_types=>ty_chk.
    ls_check-check_id = 'F_PRFAIL'.
    ls_check-severity = zif_cd_ops_types=>gc_severity-error.
    ls_check-params   = gc_prism_params.
    rt_findings = NEW zcl_cd_fmon_chk_reject( )->zif_cd_fmon_check~execute( is_ctx   = ms_ctx
                                                                           is_check = ls_check ).
  ENDMETHOD.


  METHOD act.
    DATA ls_check TYPE zif_cd_fmon_types=>ty_chk.
    ls_check-check_id = 'F_REJECT'.
    ls_check-params   = iv_params.
    DATA(lt_findings) = NEW zcl_cd_fmon_chk_reject( )->zif_cd_fmon_check~execute( is_ctx   = ms_ctx
                                                                                 is_check = ls_check ).
    LOOP AT lt_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      INSERT |{ <ls_finding>-check_code }:{ <ls_finding>-object_key }| INTO TABLE rt_codes.
    ENDLOOP.
    SORT rt_codes.
  ENDMETHOD.


  " Rule: OUTCOME=PRISM_FAILED reports exactly the files PRISM could not process or deliver.
  METHOD prism_param_only_prism.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = act( 'OUTCOME=PRISM_FAILED' )
                                            exp = VALUE string_table( ( `PRISM_FAILED:ACH_PNC_1` ) )
                                            msg = 'Only the PRISM failure must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (regenerated files, user 2026-11-07): a failed file replaced by a later generation of its
  " group is information naming the replacing file - no PRISM_FAILED, so the open exception is
  " resolved by the next reconcile.
  METHOD replaced_file_is_information.
    TRY.
        add_generation( iv_name = gc_regen iv_at = gc_at-regen ).
        ms_ctx-now = gc_at-late.
        DATA(lt_findings) = findings( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_findings )
                                            exp = 1
                                            msg = 'One finding for the failed file' ).
        DATA(ls_finding) = lt_findings[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code
                                            exp = zif_cd_fmon_types=>gc_check_code-file_replaced
                                            msg = 'Replaced, not failed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity
                                            exp = zif_cd_ops_types=>gc_severity-info
                                            msg = 'Information only (no exception)' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_finding-message
                                             exp = |*{ gc_regen }*|
                                             msg = 'The detail names the replacing file' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key
                                            exp = gc_failed
                                            msg = 'Same object key as the PRISM_FAILED exception' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (d): PRISM rejected a name it already had - PRISM_DUPLICATE_NAME instead of PRISM_FAILED.
  METHOD dup_name_replaces_failed.
    TRY.
        add_generation( iv_name = space iv_at = gc_at-generated ).
        ms_ctx-regen-dup_codes = gc_dup_code.
        INSERT VALUE #( file_ref    = zcl_cd_fmon_util=>normalize_ref( gc_failed )
                        error_code  = gc_dup_code
                        occurred_at = gc_at-failed ) INTO TABLE ms_ctx-prism_failures.
        ms_ctx-now = gc_at-regen.
        cl_abap_unit_assert=>assert_equals( act = act( gc_prism_params )
                                            exp = VALUE string_table( ( |PRISM_DUPLICATE_NAME:{ gc_failed }| ) )
                                            msg = 'One finding with the precise cause' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (b): no regenerated file after FMON_REGEN_WAIT_MIN - PRISM_FAILED stays and
  " REGENERATION_MISSING is added.
  METHOD overdue_regen_adds_missing.
    TRY.
        add_generation( iv_name = space iv_at = gc_at-generated ).
        ms_ctx-regen-wait_min = 60.
        ms_ctx-now = gc_at-late.
        cl_abap_unit_assert=>assert_equals( act = act( gc_prism_params )
                                            exp = VALUE string_table( ( |PRISM_FAILED:{ gc_failed }| )
                                                                      ( |REGENERATION_MISSING:{ gc_failed }| ) )
                                            msg = 'Failure and overdue regeneration' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without the parameter the check is unchanged (NACK, FAILED) - no duplicate PRISM finding.
  METHOD default_ignores_prism_failed.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = VALUE string_table( ( `FILE_FAILED:ACH_RET_3` ) ( `NACK:ACH_PNC_2` ) )
                                            msg = 'NACK and FAILED as before' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
