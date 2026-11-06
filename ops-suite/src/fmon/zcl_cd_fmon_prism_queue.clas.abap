*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_queue.clas.abap
*& Purpose:
*& bgPF implementation of ZIF_CD_FMON_PRISM_QUEUE: one background process per
*& stored PRISM event with the transactional-uncontrolled operation
*& ZCL_CD_FMON_PRISM_OP, saved for execution in the caller's LUW. Thin
*& wrapper over CL_BGMC_PROCESS_FACTORY: the bgPF calls sit in test seam BGPF
*& (own test include: error mapping); the framework is QA case PRISM-12.
*& Modification log:
*& 2026-11-06 | Initial version (instant PRISM processing, user decision 2026-11-06).
*& 2026-11-06 | Test seam BGPF; bgPF error kept in a local, raised after the seam (coverage gap closure).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FMON PRISM status API - bgPF queue of the instant unit</p>
"! VERIFY-ADT: CL_BGMC_PROCESS_FACTORY=>GET_DEFAULT( )->CREATE( ) returning
"! IF_BGMC_PROCESS_SINGLE_OP, SET_NAME,
"! SET_OPERATION_TX_UNCONTROLLED, SAVE_FOR_EXECUTION and CX_BGMC on SAP_BASIS 7.58 SP01;
"! bgPF needs its bgRFC inbound destination (SBGRFCCONF, Implementation_Order.md).
"! Fallback without bgPF: the 5-minute FMON job applies every unprocessed event.
CLASS zcl_cd_fmon_prism_queue DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_prism_queue.

ENDCLASS.



CLASS zcl_cd_fmon_prism_queue IMPLEMENTATION.

  METHOD zif_cd_fmon_prism_queue~enqueue.
    DATA lo_process TYPE REF TO if_bgmc_process_single_op.
    DATA lx_error TYPE REF TO cx_bgmc.
    TEST-SEAM bgpf.
      TRY.
          lo_process = cl_bgmc_process_factory=>get_default( )->create( ).
          lo_process->set_name( CONV #( zif_cd_fmon_prism_types=>gc_process_name ) ).
          lo_process->set_operation_tx_uncontrolled( NEW zcl_cd_fmon_prism_op( iv_event_id ) ).
          lo_process->save_for_execution( ).
        CATCH cx_bgmc INTO lx_error.
          " raised below: the caller leaves the event to the 5-minute run
      ENDTRY.
    END-TEST-SEAM.
    IF lx_error IS BOUND.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e268(zcd_ops) WITH iv_event_id
        EXPORTING
          previous = lx_error.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
