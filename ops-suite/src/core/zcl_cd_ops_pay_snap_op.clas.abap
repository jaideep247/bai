*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_snap_op.clas.abap
*& Purpose:
*& bgPF operation (transactional, uncontrolled - the unit commits itself) of
*& one parallel package of the payment outcome snapshot: runs
*& ZCL_CD_OPS_PAY_SNAPSHOT->RUN_PACKAGE for the package key it carries (run,
*& source, package number, run time); the unit re-reads the documents and
*& requests of the package (ZCD_PAY_OUTPKGM). Never raises: a package the
*& unit could not judge is status F (C on a configuration error) and the run
*& keeps the watermark before it. Covered by the snapshot tests (the queue
*& double runs this operation); bgPF execution itself is QA case POC-14.
*& Modification log:
*& 2026-11-08 | Initial version (parallel snapshot packages).
*& 2026-11-10 | Keys only (concurrency review): the operation carries the package key and run time, never the
*&            | up to 50,000 documents of the package - the unit re-reads them.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - bgPF operation of one snapshot package</p>
"! VERIFY-ADT: interface IF_BGMC_OP_SINGLE_TX_UNCONTR (method EXECUTE, serializable object)
"! on SAP_BASIS 7.58 SP01. Only the package key is serialized.
CLASS zcl_cd_ops_pay_snap_op DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_bgmc_op_single_tx_uncontr.

    METHODS constructor
      IMPORTING
        is_key TYPE zif_cd_ops_payout_types=>ty_pkg_key.

  PRIVATE SECTION.
    DATA ms_key TYPE zif_cd_ops_payout_types=>ty_pkg_key.

ENDCLASS.



CLASS zcl_cd_ops_pay_snap_op IMPLEMENTATION.

  METHOD constructor.
    ms_key = is_key.
  ENDMETHOD.


  METHOD if_bgmc_op_single_tx_uncontr~execute.
    " The outcome is in ZCD_PAY_OUTPKG (status, counts) and in the versions written
    NEW zcl_cd_ops_pay_snapshot( )->run_package( ms_key ).
  ENDMETHOD.

ENDCLASS.
