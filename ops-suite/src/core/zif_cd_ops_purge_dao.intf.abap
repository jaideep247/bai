*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_purge_dao.intf.abap
*& Purpose:
*& SQL for the retention purge: count and delete, one package at a time, the
*& rows of a purge target older than a cutoff. Runs (with their findings) are
*& never purgeable while they hold an open, assigned or validly waived exception.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-06 | Purge target FMON_PRISM: PRISM status events by receipt time (RETENTION_DAYS_FMON_PRISM).
*& 2026-11-07 | Purge target HCK_RESULT: verdicts of the morning report checks (RETENTION_DAYS_HCK_RESULT).
*& 2026-11-07 | Purge target PAY_OUTCOME: payment outcome versions (RETENTION_DAYS_PAY_OUTCOME).
*& 2026-11-08 | PAY_OUTCOME: current versions only when final and the payment run is before the cutoff.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - retention purge repository</p>
INTERFACE zif_cd_ops_purge_dao
  PUBLIC.

  TYPES ty_target TYPE c LENGTH 12.

  CONSTANTS:
    BEGIN OF gc_target,
      "! ZCD_OPS_RUN with its ZCD_OPS_FINDING rows
      run        TYPE ty_target VALUE 'RUN',
      alert_log  TYPE ty_target VALUE 'ALERT_LOG',
      fmon_event TYPE ty_target VALUE 'FMON_EVENT',
      hck_metric TYPE ty_target VALUE 'HCK_METRIC',
      "! ZCD_FMON_PRISM: PRISM status API events, by receipt time
      fmon_prism TYPE ty_target VALUE 'FMON_PRISM',
      "! ZCD_HCK_RESULT: verdict of each check per run, by execution time
      hck_result TYPE ty_target VALUE 'HCK_RESULT',
      "! ZCD_PAY_OUTCOME: versions closed before the cutoff; the current version only when its outcome
      "! is final and its payment run is before the cutoff (never the current version of a payment
      "! that is not final)
      pay_outcome TYPE ty_target VALUE 'PAY_OUTCOME',
    END OF gc_target.

  "! Rows of the target older than iv_cutoff that may be purged
  METHODS count_purgeable
    IMPORTING
      iv_target       TYPE ty_target
      iv_cutoff       TYPE timestampl
      iv_today        TYPE d
    RETURNING
      VALUE(rv_count) TYPE i.

  "! Delete at most iv_max purgeable rows of the target (no commit).
  "! For RUN, rv_count counts runs and ev_findings their deleted findings.
  METHODS delete_package
    IMPORTING
      iv_target       TYPE ty_target
      iv_cutoff       TYPE timestampl
      iv_today        TYPE d
      iv_max          TYPE i
    EXPORTING
      ev_findings     TYPE i
    RETURNING
      VALUE(rv_count) TYPE i.

ENDINTERFACE.
