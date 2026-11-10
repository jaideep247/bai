*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_purge_target.intf.abap
*& Purpose:
*& A purge target of the retention purge ZCL_CA_OPS_PURGE: counts and
*& deletes, one package at a time, the rows of a target older than a cutoff,
*& with the keep rules of the target (rows still needed are never deleted).
*& The framework implements its own targets RUN and ALERT_LOG
*& (ZCL_CA_OPS_PURGE_DAO); a consumer registers more targets in table
*& ZCA_OPS_PURGE (target, implementing class, retention parameter). One
*& class may serve several targets (IV_TARGET). No commit: the purge engine
*& commits after every package.
*& Modification log:
*& 2026-11-10 | Initial version (framework ZCA_OPS: purge target registry; the methods are those of the
*&            | former purge DAO of the suite, which served every target in one class).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - retention purge target</p>
"! Count and delete, package by package, the purgeable rows of a target (no commit).
INTERFACE zif_ca_ops_purge_target
  PUBLIC.

  TYPES ty_target TYPE c LENGTH 12.

  "! Rows of the target older than iv_cutoff that may be purged
  METHODS count_purgeable
    IMPORTING
      iv_target       TYPE ty_target
      iv_cutoff       TYPE timestampl
      iv_today        TYPE d
    RETURNING
      VALUE(rv_count) TYPE i.

  "! Delete at most iv_max purgeable rows of the target (no commit)
  "! @parameter ev_dependent | rows of dependent tables deleted with them (RUN: findings)
  "! @parameter ev_history | history rows deleted with the dependent rows (RUN: exception history)
  METHODS delete_package
    IMPORTING
      iv_target       TYPE ty_target
      iv_cutoff       TYPE timestampl
      iv_today        TYPE d
      iv_max          TYPE i
    EXPORTING
      ev_dependent    TYPE i
      ev_history      TYPE i
    RETURNING
      VALUE(rv_count) TYPE i.

ENDINTERFACE.
