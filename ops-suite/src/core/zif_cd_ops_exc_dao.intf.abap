*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_exc_dao.intf.abap
*& Purpose:
*& Repository for closing exceptions outside the exceptions business object
*& (EBS release approval, PRISM payment request handled manually): find the
*& open exception of an object and close it with a history row.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - exception repository</p>
INTERFACE zif_cd_ops_exc_dao
  PUBLIC.

  "! Open (O) or assigned (A) exceptions of an object; check code blank = any
  METHODS find_open
    IMPORTING
      iv_module      TYPE zif_cd_ops_types=>ty_module
      iv_object_key  TYPE zif_cd_ops_types=>ty_object_key
      iv_check_code  TYPE zif_cd_ops_types=>ty_check_code OPTIONAL
    RETURNING
      VALUE(rt_keys) TYPE zif_cd_ops_exc_types=>tt_exc_key.

  "! Close exceptions as resolved (R) and write one history row per exception.
  "! Part of the caller's LUW (no commit).
  METHODS resolve
    IMPORTING
      it_keys      TYPE zif_cd_ops_exc_types=>tt_exc_key
      iv_action    TYPE zif_cd_ops_exc_types=>ty_action
      iv_reason    TYPE zif_cd_ops_exc_types=>ty_reason
      iv_reference TYPE zif_cd_ops_exc_types=>ty_reference OPTIONAL
      iv_user      TYPE syuname
      iv_at        TYPE timestampl
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
