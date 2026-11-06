*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_status.clas.testclasses.abap
*& Purpose:
*& Pure unit tests (no doubles) for the file status state machine:
*& stage ordering, terminal outcomes and the re-run improvement rule.
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | PRISM SUCCESS rule and manual status tests (design 6.4, 6.5).
*&---------------------------------------------------------------------*
CLASS ltc_status DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flags,
        inbound     TYPE abap_bool,
        stage       TYPE zif_cd_fmon_types=>ty_stage,
        outcome     TYPE zif_cd_fmon_types=>ty_stage,
        unprocessed TYPE i,
      END OF ty_flags.

    DATA ms_file TYPE zif_cd_fmon_types=>ty_file.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS act
      IMPORTING
        iv_stage         TYPE zif_cd_fmon_types=>ty_stage
        iv_unprocessed   TYPE i DEFAULT 0
      RETURNING
        VALUE(rv_result) TYPE zif_cd_fmon_types=>ty_transition.

    METHODS stage_advances_in_order FOR TESTING.
    METHODS stage_may_skip_forward FOR TESTING.
    METHODS stage_never_regresses FOR TESTING.
    METHODS same_stage_is_idempotent FOR TESTING.
    METHODS ack_is_never_overwritten FOR TESTING.
    METHODS full_is_never_downgraded FOR TESTING.
    METHODS partial_improves_to_full FOR TESTING.
    METHODS failed_improves_to_partial FOR TESTING.
    METHODS partial_count_is_updated FOR TESTING.
    METHODS wrong_direction_is_rejected FOR TESTING.
    METHODS unknown_stage_is_rejected FOR TESTING.
    METHODS success_wins_over_later_fail FOR TESTING.
    METHODS success_after_fail_wins FOR TESTING.
    METHODS manual_forward_is_allowed FOR TESTING.
    METHODS manual_backward_is_refused FOR TESTING.

ENDCLASS.


CLASS ltc_status IMPLEMENTATION.

  METHOD configure_scenario.
    CLEAR ms_file.
    ms_file-direction = COND #( WHEN is_flags-inbound = abap_true
                                THEN zif_cd_fmon_types=>gc_direction-inbound
                                ELSE zif_cd_fmon_types=>gc_direction-outbound ).
    ms_file-stage             = is_flags-stage.
    ms_file-outcome           = is_flags-outcome.
    ms_file-unprocessed_count = is_flags-unprocessed.
  ENDMETHOD.


  METHOD act.
    rv_result = zcl_cd_fmon_status=>apply( EXPORTING iv_stage       = iv_stage
                                                     iv_unprocessed = iv_unprocessed
                                           CHANGING  cs_file        = ms_file ).
  ENDMETHOD.


  " Rule: an outbound file moves GENERATED -> SENT_TO_PRISM in order.
  METHOD stage_advances_in_order.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-generated ) ).
        DATA(lv_result) = act( zif_cd_fmon_types=>gc_stage-sent ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-advanced
                                            msg = 'Next stage must advance' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-stage exp = zif_cd_fmon_types=>gc_stage-sent
                                            msg = 'Stage must be SENT_TO_PRISM' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a later stage may arrive without the intermediate ones (ack without forward event).
  METHOD stage_may_skip_forward.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-sent ) ).
        DATA(lv_result) = act( zif_cd_fmon_types=>gc_stage-ack ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-advanced
                                            msg = 'Skipping forward must advance' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-outcome exp = zif_cd_fmon_types=>gc_stage-ack
                                            msg = 'ACK_RECEIVED is the outcome' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a later stage never regresses to an earlier one.
  METHOD stage_never_regresses.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-forwarded ) ).
        DATA(lv_result) = act( zif_cd_fmon_types=>gc_stage-sent ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-ignored
                                            msg = 'Earlier stage must be ignored' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-stage exp = zif_cd_fmon_types=>gc_stage-forwarded
                                            msg = 'Stage must stay FORWARDED_TO_BANK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: re-applying the current stage changes nothing (idempotent re-runs).
  METHOD same_stage_is_idempotent.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-sent ) ).
        DATA(lv_result) = act( zif_cd_fmon_types=>gc_stage-sent ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-ignored
                                            msg = 'Same stage must be ignored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: ACK_RECEIVED / NACK_REJECTED are final; a later NACK does not overwrite an ACK.
  METHOD ack_is_never_overwritten.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-ack outcome = zif_cd_fmon_types=>gc_stage-ack ) ).
        DATA(lv_result) = act( zif_cd_fmon_types=>gc_stage-nack ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-ignored
                                            msg = 'Terminal ACK must not be overwritten' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-outcome exp = zif_cd_fmon_types=>gc_stage-ack
                                            msg = 'Outcome must stay ACK_RECEIVED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: FULLY_PROCESSED is never downgraded to PARTIALLY_PROCESSED.
  METHOD full_is_never_downgraded.
    TRY.
        configure_scenario( VALUE #( inbound = abap_true
                                     stage   = zif_cd_fmon_types=>gc_stage-fully
                                     outcome = zif_cd_fmon_types=>gc_stage-fully ) ).
        DATA(lv_result) = act( iv_stage = zif_cd_fmon_types=>gc_stage-partially iv_unprocessed = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-ignored
                                            msg = 'FULLY must not be downgraded' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-unprocessed_count exp = 0
                                            msg = 'Unprocessed count must stay 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: on a re-run PARTIALLY_PROCESSED may become FULLY_PROCESSED (count reset to 0).
  METHOD partial_improves_to_full.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_file.
    TRY.
        configure_scenario( VALUE #( inbound = abap_true stage = zif_cd_fmon_types=>gc_stage-partially
                                     outcome = zif_cd_fmon_types=>gc_stage-partially unprocessed = 1 ) ).
        ls_exp = ms_file.
        ls_exp-stage             = zif_cd_fmon_types=>gc_stage-fully.
        ls_exp-outcome           = zif_cd_fmon_types=>gc_stage-fully.
        ls_exp-unprocessed_count = 0.
        DATA(lv_result) = act( zif_cd_fmon_types=>gc_stage-fully ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-advanced
                                            msg = 'PARTIALLY -> FULLY must advance' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file exp = ls_exp
                                            msg = 'File must be FULLY_PROCESSED with 0 open' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: on a re-run FAILED may improve to PARTIALLY_PROCESSED (outcome only improves).
  METHOD failed_improves_to_partial.
    TRY.
        configure_scenario( VALUE #( inbound = abap_true
                                     stage   = zif_cd_fmon_types=>gc_stage-failed
                                     outcome = zif_cd_fmon_types=>gc_stage-failed ) ).
        DATA(lv_result) = act( iv_stage = zif_cd_fmon_types=>gc_stage-partially iv_unprocessed = 2 ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-advanced
                                            msg = 'FAILED -> PARTIALLY must advance' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-unprocessed_count exp = 2
                                            msg = 'Unprocessed count must be taken over' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PARTIALLY_PROCESSED keeps its outcome but refreshes the unprocessed count.
  METHOD partial_count_is_updated.
    TRY.
        configure_scenario( VALUE #( inbound = abap_true stage = zif_cd_fmon_types=>gc_stage-partially
                                     outcome = zif_cd_fmon_types=>gc_stage-partially unprocessed = 3 ) ).
        DATA(lv_result) = act( iv_stage = zif_cd_fmon_types=>gc_stage-partially iv_unprocessed = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-updated
                                            msg = 'Count change must be reported as update' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-unprocessed_count exp = 1
                                            msg = 'Unprocessed count must be 1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an inbound status never applies to an outbound file.
  METHOD wrong_direction_is_rejected.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-generated ) ).
        DATA(lv_result) = act( zif_cd_fmon_types=>gc_stage-loaded ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-rejected
                                            msg = 'Inbound stage on outbound file must be rejected' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-stage exp = zif_cd_fmon_types=>gc_stage-generated
                                            msg = 'Stage must be unchanged' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a status outside the model is rejected, never stored.
  METHOD unknown_stage_is_rejected.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-generated ) ).
        DATA(lv_result) = act( 'SOMETHING_ELSE' ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-rejected
                                            msg = 'Unknown stage must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (PRISM payment requests, ZCD_PAYM_REQ_LOG): a request with a SUCCESS row is
  " FULLY_PROCESSED; a failed attempt written later must not downgrade it.
  METHOD success_wins_over_later_fail.
    TRY.
        configure_scenario( VALUE #( inbound = abap_true
                                     stage   = zif_cd_fmon_types=>gc_stage-fully
                                     outcome = zif_cd_fmon_types=>gc_stage-fully ) ).
        DATA(lv_result) = act( zif_cd_fmon_types=>gc_stage-failed ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-ignored
                                            msg = 'A later FAILED row must be ignored' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-outcome exp = zif_cd_fmon_types=>gc_stage-fully
                                            msg = 'The request must stay FULLY_PROCESSED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (PRISM): a SUCCESS row after failed attempts makes the request FULLY_PROCESSED.
  METHOD success_after_fail_wins.
    TRY.
        configure_scenario( VALUE #( inbound = abap_true
                                     stage   = zif_cd_fmon_types=>gc_stage-failed
                                     outcome = zif_cd_fmon_types=>gc_stage-failed ) ).
        DATA(lv_result) = act( zif_cd_fmon_types=>gc_stage-fully ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_types=>gc_transition-advanced
                                            msg = 'SUCCESS after FAILED must advance' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-outcome exp = zif_cd_fmon_types=>gc_stage-fully
                                            msg = 'The request must become FULLY_PROCESSED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (manual status, design 6.4): operations may set a stage by hand only where
  " the state machine itself would move the file; the file is not changed by the check.
  METHOD manual_forward_is_allowed.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-sent ) ).
        DATA(lv_allowed) = zcl_cd_fmon_status=>manual_allowed( iv_stage = zif_cd_fmon_types=>gc_stage-ack
                                                               is_file  = ms_file ).
        cl_abap_unit_assert=>assert_true( act = lv_allowed msg = 'SENT -> ACK_RECEIVED must be allowed by hand' ).
        cl_abap_unit_assert=>assert_equals( act = ms_file-stage exp = zif_cd_fmon_types=>gc_stage-sent
                                            msg = 'The check must not change the file' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (manual status): going back, or overwriting a final outcome, is refused.
  METHOD manual_backward_is_refused.
    TRY.
        configure_scenario( VALUE #( stage   = zif_cd_fmon_types=>gc_stage-ack
                                     outcome = zif_cd_fmon_types=>gc_stage-ack ) ).
        cl_abap_unit_assert=>assert_false(
          act = zcl_cd_fmon_status=>manual_allowed( iv_stage = zif_cd_fmon_types=>gc_stage-sent is_file = ms_file )
          msg = 'ACK_RECEIVED -> SENT must be refused' ).
        cl_abap_unit_assert=>assert_false(
          act = zcl_cd_fmon_status=>manual_allowed( iv_stage = zif_cd_fmon_types=>gc_stage-nack is_file = ms_file )
          msg = 'A final ACK must not be overwritten by hand' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
