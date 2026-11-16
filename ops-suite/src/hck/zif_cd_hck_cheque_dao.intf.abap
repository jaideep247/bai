*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_cheque_dao.intf.abap
*& Purpose:
*& Reads of the cheque pilot checks (build R): cheque register rows (DFKKCR)
*& of a set of cheque numbers (ECT pending items, C_ECT_PENDING) and the
*& cheque payments of a run-date window that have no cheque register row
*& with a cheque number (missing check IDs, C_CHQ_NO_ID) - each one set-based
*& statement, capped. The cheque history (ZCD_CHECK_HIST) is read through
*& the configured-source reader of the payment trace. Read-only: the
*& interface has no write method.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - cheque pilot reads</p>
"! Implementation ZCL_CD_HCK_CHEQUE_DAO, factory ZCL_CD_HCK_FACTORY=>GET_CHEQUE_DAO.
INTERFACE zif_cd_hck_cheque_dao
  PUBLIC.

  "! Cheque register rows of the cheque numbers (DFKKCR-ZTNUM), latest run first, at most iv_max_rows;
  "! an empty list reads nothing
  METHODS get_register
    IMPORTING
      it_cheques         TYPE zif_cd_hck_cheque_types=>tt_cheque_no
      iv_max_rows        TYPE i
    RETURNING
      VALUE(rt_register) TYPE zif_cd_hck_cheque_types=>tt_register.

  "! Cheque payments (DPAYH: no proposal run, DOC1R filled, RZAWE in it_methods, run date LAUFD in
  "! iv_from .. iv_to) without a DFKKCR row of the same payment document and run date that carries a
  "! cheque number; at most iv_max_rows rows (reaching it = capped). No method = nothing read
  METHODS get_payments_without_cheque
    IMPORTING
      iv_from            TYPE d
      iv_to              TYPE d
      it_methods         TYPE zif_cd_hck_cheque_types=>tt_pymet
      iv_max_rows        TYPE i
    RETURNING
      VALUE(rt_payments) TYPE zif_cd_hck_cheque_types=>tt_payment.

ENDINTERFACE.
