*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_docchg_dao.intf.abap
*& Purpose:
*& Reads of the document-change risk check A_DOC_CHANGE (build C): the
*& payment documents reversed in a window with their payment runs - one
*& set-based read, no SELECT per payment. Bank lines, cheques and G/L
*& transfer gaps are read through the existing repositories (payment trace
*& repository, HCK DAO). Read-only: the interface has no write method.
*& Modification log:
*& 2026-11-11 | Initial version (reversal and reset-clearing tracking, build C).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - document-change reads</p>
"! Implementation ZCL_CD_HCK_DOCCHG_DAO, factory ZCL_CD_HCK_FACTORY=>GET_DOCCHG_DAO.
INTERFACE zif_cd_hck_docchg_dao
  PUBLIC.

  "! Payment documents (DPAYH-DOC1R, no proposal run) whose document header carries a reversal
  "! document (DFKKKO-STBEL) entered in iv_from .. iv_to, one row per payment run, at most
  "! iv_max_rows rows (reaching it = capped)
  METHODS get_reversed_payments
    IMPORTING
      iv_from             TYPE d
      iv_to               TYPE d
      iv_max_rows         TYPE i
    RETURNING
      VALUE(rt_reversals) TYPE zif_cd_hck_docchg_types=>tt_reversal.

ENDINTERFACE.
