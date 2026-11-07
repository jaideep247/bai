*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_auth.intf.abap
*& Purpose:
*& Authorisation seam for the operations suite (object ZCD_OPS: ACTVT,
*& ZCD_MODULE, BUKRS). Engines, reports and RAP handlers ask this interface;
*& nobody writes AUTHORITY-CHECK for ZCD_OPS directly.
*& Modification log:
*& 2026-11-06 | Initial version (authorisation object ZCD_OPS, gap G3).
*& 2026-11-07 | Activity 43 (release a blocked line) removed (read-only scope).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - authorisation (object ZCD_OPS)</p>
"! Activities follow SU21 object ZCD_OPS (config/auth_zcd_ops.md).
INTERFACE zif_cd_ops_auth
  PUBLIC.

  TYPES ty_activity TYPE c LENGTH 2.

  CONSTANTS gc_object TYPE xuobject VALUE 'ZCD_OPS'.

  CONSTANTS:
    BEGIN OF gc_activity,
      create  TYPE ty_activity VALUE '01',
      change  TYPE ty_activity VALUE '02',
      display TYPE ty_activity VALUE '03',
      delete  TYPE ty_activity VALUE '06',
      "! Run a report or job (validation, monitor, morning report, purge)
      execute TYPE ty_activity VALUE '16',
      "! Second person: approve a waiver or a suppression
      approve TYPE ty_activity VALUE '85',
    END OF gc_activity.

  "! Is the user allowed? Company code initial = payment engine area-wide object (checked as DUMMY)
  METHODS is_allowed
    IMPORTING
      iv_activity       TYPE ty_activity
      iv_pe_area         TYPE zif_cd_ops_types=>ty_pe_area
      iv_bukrs          TYPE bukrs OPTIONAL
    RETURNING
      VALUE(rv_allowed) TYPE abap_bool.

  "! Same as is_allowed, raising message 041 when not allowed
  METHODS check
    IMPORTING
      iv_activity TYPE ty_activity
      iv_pe_area   TYPE zif_cd_ops_types=>ty_pe_area
      iv_bukrs    TYPE bukrs OPTIONAL
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
