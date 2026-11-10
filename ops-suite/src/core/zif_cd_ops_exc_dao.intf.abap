*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_exc_dao.intf.abap
*& Purpose:
*& Repository for closing exceptions outside the exceptions business object
*& (PRISM payment request handled manually): find the
*& open exception of an object and close it with a history row.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-07 | Purpose: the EBS release approval is no longer a caller (read-only scope).
*& 2026-11-10 | Concurrency review: FIND_OPEN returns the disposition and change stamp read; RESOLVE writes
*&            | all or nothing - each exception only while it is as read, else nothing (787).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - exception repository</p>
INTERFACE zif_cd_ops_exc_dao
  PUBLIC.

  "! Open (O) or assigned (A) exceptions of an object with the disposition, owner and change stamp read;
  "! check code blank = any
  METHODS find_open
    IMPORTING
      iv_pe_area     TYPE zif_cd_ops_types=>ty_pe_area
      iv_object_key  TYPE zif_cd_ops_types=>ty_object_key
      iv_check_code  TYPE zif_cd_ops_types=>ty_check_code OPTIONAL
    RETURNING
      VALUE(rt_open) TYPE zif_cd_ops_exc_types=>tt_exc_open.

  "! Close exceptions as resolved (R) and write one history row per exception. All or nothing: an
  "! exception is written only while its disposition and change stamp are the ones of it_open (a user or
  "! a run changed it meanwhile = raised before any history row; the caller ends the LUW without commit).
  "! Part of the caller's LUW (no commit).
  "! @raising zcx_cd_ops_error | 787 an exception changed meanwhile, or a row could not be written
  METHODS resolve
    IMPORTING
      it_open      TYPE zif_cd_ops_exc_types=>tt_exc_open
      iv_action    TYPE zif_cd_ops_exc_types=>ty_action
      iv_reason    TYPE zif_cd_ops_exc_types=>ty_reason
      iv_reference TYPE zif_cd_ops_exc_types=>ty_reference OPTIONAL
      iv_user      TYPE syuname
      iv_at        TYPE timestampl
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
