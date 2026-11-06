*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_prism_file.clas.testclasses.abap
*& Purpose:
*& Pure unit tests of the check of PRISM evidence SAP does not confirm
*& (PRISM_UNKNOWN_FILE outbound, PRISM_NOT_LOADED inbound, grace period). Static
*& ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API: unknown files never vanish).
*&---------------------------------------------------------------------*
CLASS ltc_prism_file DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flags,
        inbound    TYPE abap_bool,
        sap_stage  TYPE zif_cd_fmon_types=>ty_stage,
        prism_at   TYPE timestampl,
        file_stage TYPE zif_cd_fmon_types=>ty_stage,
      END OF ty_flags.

    CONSTANTS:
      BEGIN OF gc_test,
        file_id TYPE zif_cd_fmon_types=>ty_file_id VALUE '0000000000000000000000000000000B',
        name    TYPE zif_cd_fmon_types=>ty_file_name VALUE 'BAI_JPMC_20261106',
        now     TYPE timestampl VALUE '20261106150000',
        old     TYPE timestampl VALUE '20261106130000',
        recent  TYPE timestampl VALUE '20261106144500',
      END OF gc_test.

    DATA ms_ctx TYPE zif_cd_fmon_types=>ty_check_ctx.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS act
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        zcx_cd_ops_error.

    METHODS add_event
      IMPORTING
        iv_stage TYPE zif_cd_fmon_types=>ty_stage
        iv_at    TYPE timestampl.

    METHODS outbound_unknown_after_grace FOR TESTING.
    METHODS outbound_unknown_within_grace FOR TESTING.
    METHODS outbound_known_no_finding FOR TESTING.
    METHODS inbound_not_loaded_after_grace FOR TESTING.
    METHODS inbound_received_no_finding FOR TESTING.

ENDCLASS.


CLASS ltc_prism_file IMPLEMENTATION.

  METHOD add_event.
    DATA ls_event TYPE zif_cd_fmon_types=>ty_event.
    ls_event-file_id  = gc_test-file_id.
    ls_event-stage    = iv_stage.
    ls_event-event_at = iv_at.
    INSERT ls_event INTO TABLE ms_ctx-events.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    CLEAR ms_ctx.
    ms_ctx-now = gc_test-now.
    ls_file-file_id   = gc_test-file_id.
    ls_file-file_name = gc_test-name.
    ls_file-direction = COND #( WHEN is_flags-inbound = abap_true THEN zif_cd_fmon_types=>gc_direction-inbound
                                ELSE zif_cd_fmon_types=>gc_direction-outbound ).
    ls_file-stage     = is_flags-file_stage.
    INSERT ls_file INTO TABLE ms_ctx-files.
    add_event( iv_stage = COND #( WHEN is_flags-inbound = abap_true THEN zif_cd_fmon_types=>gc_stage-prism_delivered
                                  ELSE zif_cd_fmon_types=>gc_stage-prism_received )
               iv_at    = is_flags-prism_at ).
    IF is_flags-sap_stage IS NOT INITIAL.
      add_event( iv_stage = is_flags-sap_stage iv_at = gc_test-recent ).
    ENDIF.
  ENDMETHOD.


  METHOD act.
    DATA ls_check TYPE zif_cd_fmon_types=>ty_chk.
    ls_check-check_id   = 'F_PRFILE'.
    ls_check-class_name = 'ZCL_CD_FMON_CHK_PRISM_FILE'.
    ls_check-severity   = zif_cd_ops_types=>gc_severity-warning.
    DATA(lt_findings) = NEW zcl_cd_fmon_chk_prism_file( )->zif_cd_fmon_check~execute( is_ctx   = ms_ctx
                                                                                     is_check = ls_check ).
    LOOP AT lt_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      INSERT CONV string( <ls_finding>-check_code ) INTO TABLE rt_codes.
    ENDLOOP.
  ENDMETHOD.


  " Rule: outbound PRISM evidence without SAP generation / send, older than GRACE_MIN, surfaces.
  METHOD outbound_unknown_after_grace.
    TRY.
        configure_scenario( VALUE #( prism_at = gc_test-old file_stage = zif_cd_fmon_types=>gc_stage-prism_received ) ).
        cl_abap_unit_assert=>assert_equals( act = act( ) exp = VALUE string_table( ( `PRISM_UNKNOWN_FILE` ) )
                                            msg = 'An unknown file must surface' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: within the grace period PRISM may simply be faster than the next read of SAP's evidence.
  METHOD outbound_unknown_within_grace.
    TRY.
        configure_scenario( VALUE #( prism_at = gc_test-recent file_stage = zif_cd_fmon_types=>gc_stage-prism_received ) ).
        cl_abap_unit_assert=>assert_initial( act = act( ) msg = 'No finding within the grace period' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: SAP's own SENT_TO_PRISM confirms the outbound file.
  METHOD outbound_known_no_finding.
    TRY.
        configure_scenario( VALUE #( prism_at   = gc_test-old
                                     sap_stage  = zif_cd_fmon_types=>gc_stage-sent
                                     file_stage = zif_cd_fmon_types=>gc_stage-prism_received ) ).
        cl_abap_unit_assert=>assert_initial( act = act( ) msg = 'A known file is no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: inbound file PRISM delivered, not received in SAP after GRACE_MIN, surfaces.
  METHOD inbound_not_loaded_after_grace.
    TRY.
        configure_scenario( VALUE #( inbound = abap_true prism_at = gc_test-old
                                     file_stage = zif_cd_fmon_types=>gc_stage-prism_delivered ) ).
        cl_abap_unit_assert=>assert_equals( act = act( ) exp = VALUE string_table( ( `PRISM_NOT_LOADED` ) )
                                            msg = 'A delivered, not received file must surface' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: SAP's receipt (FILE_RECEIVED or later) confirms the inbound delivery.
  METHOD inbound_received_no_finding.
    TRY.
        configure_scenario( VALUE #( inbound = abap_true prism_at = gc_test-old
                                     sap_stage  = zif_cd_fmon_types=>gc_stage-received
                                     file_stage = zif_cd_fmon_types=>gc_stage-loaded ) ).
        cl_abap_unit_assert=>assert_initial( act = act( ) msg = 'A received file is no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
