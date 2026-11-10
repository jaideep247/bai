*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_review_dao.intf.abap
*& Purpose:
*& Repository of the daily control review: the lock of one control and
*& business date while it is signed off (ENQUEUE_E_TABLE on ZCA_OPS_REVIEW)
*& and the save of sign-offs (insert or update of the review row; no
*& commit - the RAP save sequence of the review app commits). Nothing else
*& writes ZCA_OPS_REVIEW (the retention purge deletes old rows).
*& Modification log:
*& 2026-11-10 | Initial version (control register and daily control review).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - daily control review repository</p>
INTERFACE zif_ca_ops_review_dao
  PUBLIC.

  "! Exclusive lock of the review of one control and business date (released at the end of the LUW)
  "! @raising zcx_ca_ops_error | locked by another user (079) or the lock server failed (042)
  METHODS lock
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
      iv_control_id    TYPE zif_ca_ops_ctl_types=>ty_control_id
      iv_business_date TYPE d
    RAISING
      zcx_ca_ops_error.

  "! Insert or update the review rows (no commit)
  METHODS save
    IMPORTING
      it_reviews TYPE zif_ca_ops_ctl_types=>tt_review.

ENDINTERFACE.
