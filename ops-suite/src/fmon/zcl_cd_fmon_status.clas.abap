*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_status.clas.abap
*& Purpose:
*& File status state machine (pure domain logic, no database, no clock).
*& Stages are ordered per direction; a later stage never regresses;
*& terminal outcomes are final except the inbound re-run improvement.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | manual_allowed( ) for the manual-status app (design 6.4).
*& 2026-11-06 | PRISM status API: rank per direction (PRISM_* stages in both directions),
*&              fits_direction( ), is_origin( ), PRISM_FAILED superseded by later progress.
*& 2026-11-07 | reaches( ): has the file reached a stage (stage deadline check).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - file status state machine</p>
"! Rules (also in FMON_FILE_MONITORING.md):
"! <ol><li>A status outside the model, or of the other direction, is rejected.
"! PRISM_RECEIVED / PRISM_DELIVERED / PRISM_FAILED belong to both directions.</li>
"! <li>Without an outcome the file only moves to a stage of higher rank;
"! skipping intermediate stages is allowed, going back is ignored.</li>
"! <li>ACK_RECEIVED and NACK_REJECTED are final.</li>
"! <li>PRISM_FAILED is an outcome that a later stage of the same or higher rank
"! supersedes (PRISM retried and delivered, or SAP received the file).</li>
"! <li>Inbound outcomes may only improve on a re-run:
"! FAILED -> PARTIALLY_PROCESSED -> FULLY_PROCESSED. FULLY_PROCESSED is final.</li>
"! <li>PARTIALLY_PROCESSED re-applied with another count updates the count only.</li></ol>
CLASS zcl_cd_fmon_status DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! Rank of a status within a direction (outbound 10..40, inbound 3..30; 0 = not in
    "! that direction or unknown). Without a direction, the stage's own direction is used;
    "! a PRISM_* stage (both directions) then has rank 0.
    CLASS-METHODS rank
      IMPORTING
        iv_stage       TYPE zif_cd_fmon_types=>ty_stage
        iv_direction   TYPE zif_cd_fmon_types=>ty_direction OPTIONAL
      RETURNING
        VALUE(rv_rank) TYPE i.

    "! Direction a status belongs to (blank when unknown or when it belongs to both)
    CLASS-METHODS direction_of
      IMPORTING
        iv_stage            TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_direction) TYPE zif_cd_fmon_types=>ty_direction.

    "! The status exists in the given direction (PRISM_* stages fit both)
    CLASS-METHODS fits_direction
      IMPORTING
        iv_stage       TYPE zif_cd_fmon_types=>ty_stage
        iv_direction   TYPE zif_cd_fmon_types=>ty_direction
      RETURNING
        VALUE(rv_fits) TYPE abap_bool.

    "! First evidence of a file instance (audit A49): may open the instance of its own
    "! business date. Outbound GENERATED_IN_SAP; inbound every stage up to FILE_RECEIVED
    "! (PRISM receives and delivers an inbound file before SAP sees it).
    CLASS-METHODS is_origin
      IMPORTING
        iv_stage         TYPE zif_cd_fmon_types=>ty_stage
        iv_direction     TYPE zif_cd_fmon_types=>ty_direction
      RETURNING
        VALUE(rv_origin) TYPE abap_bool.

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

    "! The file has reached the stage (stage deadline): an inbound outcome (FULLY / PARTIALLY /
    "! FAILED) needs an outcome of at least that quality - PARTIALLY_PROCESSED does not reach
    "! FULLY_PROCESSED; any other stage a current stage of at least its rank (a later stage
    "! includes the earlier ones); PRISM_FAILED does not reach the delivery it failed
    CLASS-METHODS reaches
      IMPORTING
        is_file           TYPE zif_cd_fmon_types=>ty_file
        iv_stage          TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_reached) TYPE abap_bool.

    "! Manual status (design 6.4): allowed only where APPLY would advance or update
    "! the file. Works on a copy - the file passed in is not changed.
    CLASS-METHODS manual_allowed
      IMPORTING
        iv_stage          TYPE zif_cd_fmon_types=>ty_stage
        is_file           TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

  PRIVATE SECTION.
    "! Stage ranks per direction; gaps leave room between SAP's own stages for PRISM's
    CONSTANTS:
      BEGIN OF gc_rank,
        out_generated      TYPE i VALUE 10,
        out_sent           TYPE i VALUE 20,
        out_prism_received TYPE i VALUE 25,
        out_forwarded      TYPE i VALUE 30,
        out_response       TYPE i VALUE 40,
        in_prism_received  TYPE i VALUE 3,
        in_prism_delivered TYPE i VALUE 6,
        in_received        TYPE i VALUE 10,
        in_loaded          TYPE i VALUE 20,
        in_outcome         TYPE i VALUE 30,
      END OF gc_rank.

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
    DATA(lv_direction) = COND #( WHEN iv_direction IS NOT INITIAL THEN iv_direction
                                 ELSE direction_of( iv_stage ) ).
    CASE lv_direction.
      WHEN zif_cd_fmon_types=>gc_direction-outbound.
        " PRISM_DELIVERED = forwarded to the bank / IRIS / source (same rank)
        rv_rank = SWITCH #( iv_stage
                            WHEN zif_cd_fmon_types=>gc_stage-generated       THEN gc_rank-out_generated
                            WHEN zif_cd_fmon_types=>gc_stage-sent            THEN gc_rank-out_sent
                            WHEN zif_cd_fmon_types=>gc_stage-prism_received  THEN gc_rank-out_prism_received
                            WHEN zif_cd_fmon_types=>gc_stage-prism_delivered THEN gc_rank-out_forwarded
                            WHEN zif_cd_fmon_types=>gc_stage-prism_failed    THEN gc_rank-out_forwarded
                            WHEN zif_cd_fmon_types=>gc_stage-forwarded       THEN gc_rank-out_forwarded
                            WHEN zif_cd_fmon_types=>gc_stage-ack             THEN gc_rank-out_response
                            WHEN zif_cd_fmon_types=>gc_stage-nack            THEN gc_rank-out_response
                            ELSE 0 ).
      WHEN zif_cd_fmon_types=>gc_direction-inbound.
        rv_rank = SWITCH #( iv_stage
                            WHEN zif_cd_fmon_types=>gc_stage-prism_received  THEN gc_rank-in_prism_received
                            WHEN zif_cd_fmon_types=>gc_stage-prism_delivered THEN gc_rank-in_prism_delivered
                            WHEN zif_cd_fmon_types=>gc_stage-prism_failed    THEN gc_rank-in_prism_delivered
                            WHEN zif_cd_fmon_types=>gc_stage-received        THEN gc_rank-in_received
                            WHEN zif_cd_fmon_types=>gc_stage-loaded          THEN gc_rank-in_loaded
                            WHEN zif_cd_fmon_types=>gc_stage-fully           THEN gc_rank-in_outcome
                            WHEN zif_cd_fmon_types=>gc_stage-partially       THEN gc_rank-in_outcome
                            WHEN zif_cd_fmon_types=>gc_stage-failed          THEN gc_rank-in_outcome
                            ELSE 0 ).
      WHEN OTHERS.
        rv_rank = 0.
    ENDCASE.
  ENDMETHOD.


  METHOD fits_direction.
    rv_fits = xsdbool( iv_direction IS NOT INITIAL
                       AND rank( iv_stage = iv_stage iv_direction = iv_direction ) > 0 ).
  ENDMETHOD.


  METHOD is_origin.
    DATA(lv_rank) = rank( iv_stage = iv_stage iv_direction = iv_direction ).
    CASE iv_direction.
      WHEN zif_cd_fmon_types=>gc_direction-outbound.
        rv_origin = xsdbool( lv_rank = gc_rank-out_generated ).
      WHEN zif_cd_fmon_types=>gc_direction-inbound.
        rv_origin = xsdbool( lv_rank > 0 AND lv_rank <= gc_rank-in_received ).
      WHEN OTHERS.
        rv_origin = abap_false.
    ENDCASE.
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
                        OR iv_stage = zif_cd_fmon_types=>gc_stage-prism_failed
                        OR iv_stage = zif_cd_fmon_types=>gc_stage-fully
                        OR iv_stage = zif_cd_fmon_types=>gc_stage-partially
                        OR iv_stage = zif_cd_fmon_types=>gc_stage-failed ).
  ENDMETHOD.


  METHOD apply.
    DATA(lv_rank) = rank( iv_stage = iv_stage iv_direction = cs_file-direction ).
    IF lv_rank = 0.
      rv_result = zif_cd_fmon_types=>gc_transition-rejected.
      RETURN.
    ENDIF.

    " PRISM_FAILED is superseded by later evidence of progress (PRISM retried, SAP received)
    IF cs_file-outcome = zif_cd_fmon_types=>gc_stage-prism_failed
       AND iv_stage <> zif_cd_fmon_types=>gc_stage-prism_failed
       AND lv_rank >= rank( iv_stage     = zif_cd_fmon_types=>gc_stage-prism_failed
                            iv_direction = cs_file-direction ).
      set_stage( EXPORTING iv_stage       = iv_stage
                           iv_unprocessed = iv_unprocessed
                 CHANGING  cs_file        = cs_file ).
      rv_result = zif_cd_fmon_types=>gc_transition-advanced.
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

    IF lv_rank <= rank( iv_stage = cs_file-stage iv_direction = cs_file-direction ).
      rv_result = zif_cd_fmon_types=>gc_transition-ignored.
      RETURN.
    ENDIF.

    set_stage( EXPORTING iv_stage       = iv_stage
                         iv_unprocessed = iv_unprocessed
               CHANGING  cs_file        = cs_file ).
    rv_result = zif_cd_fmon_types=>gc_transition-advanced.
  ENDMETHOD.


  METHOD reaches.
    DATA(lv_target) = rank( iv_stage = iv_stage iv_direction = is_file-direction ).
    IF lv_target = 0.
      RETURN.
    ENDIF.
    IF quality( iv_stage ) > 0.
      rv_reached = xsdbool( quality( is_file-outcome ) >= quality( iv_stage ) ).
      RETURN.
    ENDIF.
    DATA(lv_rank) = rank( iv_stage = is_file-stage iv_direction = is_file-direction ).
    IF is_file-outcome = zif_cd_fmon_types=>gc_stage-prism_failed AND iv_stage <> zif_cd_fmon_types=>gc_stage-prism_failed.
      rv_reached = xsdbool( lv_rank > lv_target ).
      RETURN.
    ENDIF.
    rv_reached = xsdbool( lv_rank >= lv_target ).
  ENDMETHOD.


  METHOD manual_allowed.
    DATA(ls_copy) = is_file.
    DATA(lv_result) = apply( EXPORTING iv_stage       = iv_stage
                                       iv_unprocessed = is_file-unprocessed_count
                             CHANGING  cs_file        = ls_copy ).
    rv_allowed = xsdbool( lv_result = zif_cd_fmon_types=>gc_transition-advanced
                       OR lv_result = zif_cd_fmon_types=>gc_transition-updated ).
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
    " A non-terminal stage reached after PRISM_FAILED clears that outcome (the only
    " outcome a non-terminal stage can supersede)
    cs_file-outcome = COND #( WHEN is_terminal( iv_stage ) = abap_true THEN iv_stage ).
    cs_file-unprocessed_count = COND #( WHEN iv_stage = zif_cd_fmon_types=>gc_stage-partially
                                        THEN iv_unprocessed
                                        ELSE 0 ).
  ENDMETHOD.

ENDCLASS.
