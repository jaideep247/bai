*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_snap_queue.clas.abap
*& Purpose:
*& bgPF implementation of ZIF_CD_OPS_PAY_SNAP_QUEUE (as the FMON PRISM queue):
*& one background process per parallel package of the payment outcome
*& snapshot with the transactional-uncontrolled operation
*& ZCL_CD_OPS_PAY_SNAP_OP, saved for execution in the caller's LUW; PAUSE
*& waits between two looks at the package rows. Thin wrapper over
*& CL_BGMC_PROCESS_FACTORY and WAIT UP TO: the calls sit in the test seams
*& BGPF and PAUSE (own test include); the framework is QA case POC-14.
*& Modification log:
*& 2026-11-08 | Initial version (parallel snapshot packages; test seams BGPF, PAUSE).
*& 2026-11-10 | The operation carries the package key only (concurrency review: keys, never the documents).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - bgPF queue of snapshot packages</p>
"! VERIFY-ADT: CL_BGMC_PROCESS_FACTORY=>GET_DEFAULT( )->CREATE( ), SET_NAME,
"! SET_OPERATION_TX_UNCONTROLLED, SAVE_FOR_EXECUTION and CX_BGMC on SAP_BASIS 7.58 SP01;
"! bgPF needs its bgRFC inbound destination (SBGRFCCONF, Implementation_Order.md). Without bgPF
"! the snapshot judges the packages one by one (finding PAY_OUTCOME_SERIAL).
CLASS zcl_cd_ops_pay_snap_queue DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_snap_queue.

ENDCLASS.



CLASS zcl_cd_ops_pay_snap_queue IMPLEMENTATION.

  METHOD zif_cd_ops_pay_snap_queue~dispatch.
    DATA lo_process TYPE REF TO if_bgmc_process_single_op.
    DATA lx_error TYPE REF TO cx_bgmc.
    TEST-SEAM bgpf.
      TRY.
          lo_process = cl_bgmc_process_factory=>get_default( )->create( ).
          lo_process->set_name( CONV #( zif_cd_ops_payout_types=>gc_process_name ) ).
          lo_process->set_operation_tx_uncontrolled( NEW zcl_cd_ops_pay_snap_op( CORRESPONDING #( is_package ) ) ).
          lo_process->save_for_execution( ).
        CATCH cx_bgmc INTO lx_error.
          " raised below: the run judges the package itself
      ENDTRY.
    END-TEST-SEAM.
    IF lx_error IS BOUND.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e751(zcd_ops) WITH is_package-source
        EXPORTING
          previous = lx_error.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_snap_queue~pause.
    TEST-SEAM pause.
      WAIT UP TO iv_seconds SECONDS.
    END-TEST-SEAM.
  ENDMETHOD.

ENDCLASS.
