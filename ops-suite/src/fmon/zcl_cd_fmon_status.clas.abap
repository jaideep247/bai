*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_status.clas.abap
*& Purpose:
*& File status state machine (pure domain logic, no database, no clock).
*& Stages are ordered per direction; a later stage never regresses;
*& terminal outcomes are final except the inbound re-run improvement.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - file status state machine</p>
"! Rules (also in FMON_FILE_MONITORING.md):
"! <ol><li>A status outside the model, or of the other direction, is rejected.</li>
"! <li>Without an outcome the file only moves to a stage of higher rank;
"! skipping intermediate stages is allowed, going back is ignored.</li>
"! <li>ACK_RECEIVED and NACK_REJECTED are final.</li>
"! <li>Inbound outcomes may only improve on a re-run:
"! FAILED -> PARTIALLY_PROCESSED -> FULLY_PROCESSED. FULLY_PROCESSED is final.</li>
"! <li>PARTIALLY_PROCESSED re-applied with another count updates the count only.</li></ol>
CLASS zcl_cd_fmon_status DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! Rank of a status within its direction (1..4 outbound, 1..3 inbound, 0 unknown)
    CLASS-METHODS rank
      IMPORTING
        iv_stage       TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_rank) TYPE i.

    "! Direction a status belongs to (blank when unknown)
    CLASS-METHODS direction_of
      IMPORTING
        iv_stage            TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_direction) TYPE zif_cd_fmon_types=>ty_direction.

    CLASS-METHODS is_terminal
      IMPORTING
        iv_stage           TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_terminal) TYPE abap_bool.

    "! Apply a status to a file; returns advanced / updated / ignored / rejected
    CLASS-METHODS apply
      IMPORTING
        iv_stage         TYPE zif_cd_fmon_types=>ty_stage
        iv_unprocessed   TYPE i DEFAULT 0
      CHANGING
        cs_file          TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_result) TYPE zif_cd_fmon_types=>ty_transition.

  PRIVATE SECTION.

    "! Inbound outcome quality: FAILED 1, PARTIALLY 2, FULLY 3; others 0
    CLASS-METHODS quality
      IMPORTING
        iv_stage          TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_quality) TYPE i.

    CLASS-METHODS set_stage
      IMPORTING
        iv_stage       TYPE zif_cd_fmon_types=>ty_stage
        iv_unprocessed TYPE i
      CHANGING
        cs_file        TYPE zif_cd_fmon_types=>ty_file.

ENDCLASS.



CLASS zcl_cd_fmon_status IMPLEMENTATION.

  METHOD rank.
    rv_rank = SWITCH #( iv_stage
                        WHEN zif_cd_fmon_types=>gc_stage-generated THEN 1
                        WHEN zif_cd_fmon_types=>gc_stage-sent      THEN 2
                        WHEN zif_cd_fmon_types=>gc_stage-forwarded THEN 3
                        WHEN zif_cd_fmon_types=>gc_stage-ack       THEN 4
                        WHEN zif_cd_fmon_types=>gc_stage-nack      THEN 4
                        WHEN zif_cd_fmon_types=>gc_stage-received  THEN 1
                        WHEN zif_cd_fmon_types=>gc_stage-loaded    THEN 2
                        WHEN zif_cd_fmon_types=>gc_stage-fully     THEN 3
                        WHEN zif_cd_fmon_types=>gc_stage-partially THEN 3
                        WHEN zif_cd_fmon_types=>gc_stage-failed    THEN 3
                        ELSE 0 ).
  ENDMETHOD.


  METHOD direction_of.
    CASE iv_stage.
      WHEN zif_cd_fmon_types=>gc_stage-generated OR zif_cd_fmon_types=>gc_stage-sent
        OR zif_cd_fmon_types=>gc_stage-forwarded OR zif_cd_fmon_types=>gc_stage-ack
        OR zif_cd_fmon_types=>gc_stage-nack.
        rv_direction = zif_cd_fmon_types=>gc_direction-outbound.
      WHEN zif_cd_fmon_types=>gc_stage-received OR zif_cd_fmon_types=>gc_stage-loaded
        OR zif_cd_fmon_types=>gc_stage-fully OR zif_cd_fmon_types=>gc_stage-partially
        OR zif_cd_fmon_types=>gc_stage-failed.
        rv_direction = zif_cd_fmon_types=>gc_direction-inbound.
      WHEN OTHERS.
        CLEAR rv_direction.
    ENDCASE.
  ENDMETHOD.


  METHOD is_terminal.
    rv_terminal = xsdbool( iv_stage = zif_cd_fmon_types=>gc_stage-ack
                        OR iv_stage = zif_cd_fmon_types=>gc_stage-nack
                        OR iv_stage = zif_cd_fmon_types=>gc_stage-fully
                        OR iv_stage = zif_cd_fmon_types=>gc_stage-partially
                        OR iv_stage = zif_cd_fmon_types=>gc_stage-failed ).
  ENDMETHOD.


  METHOD apply.
    IF rank( iv_stage ) = 0 OR direction_of( iv_stage ) <> cs_file-direction.
      rv_result = zif_cd_fmon_types=>gc_transition-rejected.
      RETURN.
    ENDIF.

    IF cs_file-outcome IS NOT INITIAL.
      IF iv_stage = cs_file-outcome.
        IF iv_stage = zif_cd_fmon_types=>gc_stage-partially
           AND iv_unprocessed <> cs_file-unprocessed_count.
          cs_file-unprocessed_count = iv_unprocessed.
          rv_result = zif_cd_fmon_types=>gc_transition-updated.
        ELSE.
          rv_result = zif_cd_fmon_types=>gc_transition-ignored.
        ENDIF.
        RETURN.
      ENDIF.
      IF quality( cs_file-outcome ) > 0 AND quality( iv_stage ) > quality( cs_file-outcome ).
        set_stage( EXPORTING iv_stage       = iv_stage
                             iv_unprocessed = iv_unprocessed
                   CHANGING  cs_file        = cs_file ).
        rv_result = zif_cd_fmon_types=>gc_transition-advanced.
      ELSE.
        rv_result = zif_cd_fmon_types=>gc_transition-ignored.
      ENDIF.
      RETURN.
    ENDIF.

    IF rank( iv_stage ) <= rank( cs_file-stage ).
      rv_result = zif_cd_fmon_types=>gc_transition-ignored.
      RETURN.
    ENDIF.

    set_stage( EXPORTING iv_stage       = iv_stage
                         iv_unprocessed = iv_unprocessed
               CHANGING  cs_file        = cs_file ).
    rv_result = zif_cd_fmon_types=>gc_transition-advanced.
  ENDMETHOD.


  METHOD quality.
    rv_quality = SWITCH #( iv_stage
                           WHEN zif_cd_fmon_types=>gc_stage-failed    THEN 1
                           WHEN zif_cd_fmon_types=>gc_stage-partially THEN 2
                           WHEN zif_cd_fmon_types=>gc_stage-fully     THEN 3
                           ELSE 0 ).
  ENDMETHOD.


  METHOD set_stage.
    cs_file-stage = iv_stage.
    IF is_terminal( iv_stage ) = abap_true.
      cs_file-outcome = iv_stage.
    ENDIF.
    cs_file-unprocessed_count = COND #( WHEN iv_stage = zif_cd_fmon_types=>gc_stage-partially
                                        THEN iv_unprocessed
                                        ELSE 0 ).
  ENDMETHOD.

ENDCLASS.
