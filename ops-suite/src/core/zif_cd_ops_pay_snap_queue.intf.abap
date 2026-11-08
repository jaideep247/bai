*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_pay_snap_queue.intf.abap
*& Purpose:
*& Seam for the parallel packages of the payment outcome snapshot (real
*& implementation: bgPF, ZCL_CD_OPS_PAY_SNAP_QUEUE): register the unit of
*& one package in the caller's LUW (it starts with the caller's COMMIT WORK)
*& and pause between two looks at the package rows (ZCD_PAY_OUTPKG).
*& Modification log:
*& 2026-11-08 | Initial version (parallel snapshot packages, 2 million payments a peak day).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - queue of parallel snapshot packages</p>
INTERFACE zif_cd_ops_pay_snap_queue
  PUBLIC.

  "! Register the background unit of the package in the current LUW (starts at COMMIT WORK)
  "! @raising zcx_cd_ops_error | the unit could not be registered (the run judges the package itself)
  METHODS dispatch
    IMPORTING
      is_package TYPE zif_cd_ops_payout_types=>ty_package
    RAISING
      zcx_cd_ops_error.

  "! Wait before the next look at the package rows
  METHODS pause
    IMPORTING
      iv_seconds TYPE i.

ENDINTERFACE.
