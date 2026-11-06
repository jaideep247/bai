*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_op.clas.abap
*& Purpose:
*& bgPF operation (transactional, uncontrolled - the FMON store commits itself)
*& of one PRISM event: runs ZCL_CD_FMON_PRISM_PROC=>PROCESS for the event ID it
*& carries. Never raises: an event the unit could not apply stays unprocessed
*& and the 5-minute run applies it. Thin: own test include (event ID handed
*& to the unit); bgPF execution itself is QA case PRISM-12.
*& Modification log:
*& 2026-11-06 | Initial version (instant PRISM processing, user decision 2026-11-06).
*& 2026-11-06 | Header: own test include (coverage gap closure); no code change.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FMON PRISM status API - bgPF operation for one event</p>
"! VERIFY-ADT: interface IF_BGMC_OP_SINGLE_TX_UNCONTR (method EXECUTE, serializable object)
"! on SAP_BASIS 7.58 SP01. Only the event ID is serialized.
CLASS zcl_cd_fmon_prism_op DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_bgmc_op_single_tx_uncontr.

    METHODS constructor
      IMPORTING
        iv_event_id TYPE zif_cd_fmon_prism_types=>ty_event_id.

  PRIVATE SECTION.
    DATA mv_event_id TYPE zif_cd_fmon_prism_types=>ty_event_id.

ENDCLASS.



CLASS zcl_cd_fmon_prism_op IMPLEMENTATION.

  METHOD constructor.
    mv_event_id = iv_event_id.
  ENDMETHOD.


  METHOD if_bgmc_op_single_tx_uncontr~execute.
    " The outcome is in the registry, ZCD_FMON_PRISM-PROCESSED_AT and the run of variant PRISM
    NEW zcl_cd_fmon_prism_proc( )->process( mv_event_id ).
  ENDMETHOD.

ENDCLASS.
