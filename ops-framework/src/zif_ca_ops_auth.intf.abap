*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_auth.intf.abap
*& Purpose:
*& Authorisation seam for the operations suite (object ZCD_OPS: ACTVT,
*& ZCA_PARAR, BUKRS). Engines, reports and RAP handlers ask this interface;
*& nobody writes AUTHORITY-CHECK for ZCD_OPS directly.
*& Modification log:
*& 2026-11-06 | Initial version (authorisation object ZCD_OPS, gap G3).
*& 2026-11-07 | Activity 43 (release a blocked line) removed (read-only scope).
*& 2026-11-10 | Authorisation field ZCA_PARAR, as defined in SU20 and used by the DCLs.
*& 2026-11-10 | may_read_table: S_TABU_NAM display (03) before every dynamic read of a configured table
*&            | (file monitoring, health check, EBS lookup R21); moved here from ZCL_CD_FMON_DDIC.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - authorisation (object ZCD_OPS)</p>
"! Activities follow SU21 object ZCD_OPS (config/auth_zcd_ops.md).
INTERFACE zif_ca_ops_auth
  PUBLIC.

  TYPES ty_activity TYPE c LENGTH 2.

  CONSTANTS gc_object TYPE xuobject VALUE 'ZCA_OPS'.

  "! Table display authorisation of every dynamic read (S_TABU_NAM, ACTVT 03, TABLE)
  CONSTANTS:
    BEGIN OF gc_table_auth,
      object   TYPE xuobject VALUE 'S_TABU_NAM',
      id_actvt TYPE xufield VALUE 'ACTVT',
      id_table TYPE xufield VALUE 'TABLE',
      display  TYPE activ_auth VALUE '03',
    END OF gc_table_auth.

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
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_bukrs          TYPE bukrs OPTIONAL
    RETURNING
      VALUE(rv_allowed) TYPE abap_bool.

  "! S_TABU_NAM display (03) for a table the suite reads by a configured name (FMON dynamic
  "! reader, HCK aggregates / values / queues / drift, EBS lookup R21). DEFAULT IGNORE: a double
  "! that does not implement it allows nothing.
  METHODS may_read_table DEFAULT IGNORE
    IMPORTING
      iv_table          TYPE clike
    RETURNING
      VALUE(rv_allowed) TYPE abap_bool.

  "! Same as is_allowed, raising message 041 when not allowed
  METHODS check
    IMPORTING
      iv_activity TYPE ty_activity
      iv_area   TYPE zif_ca_ops_types=>ty_area
      iv_bukrs    TYPE bukrs OPTIONAL
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
