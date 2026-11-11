*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_job_claim.intf.abap
*& Purpose:
*& Plug-in contract of a claim of another monitor (parameter JOB_CLAIMS):
*& the jobs whose own failure (aborted, long-running, not started) another
*& monitor already reports - e.g. the steps of named job cycles of a
*& consumer's daily health report. The SAP job monitor keeps their evidence and
*& writes an information finding instead of an exception, so the same
*& failure is never alerted twice. A child that failed under a claimed
*& parent is still reported (the other monitor does not see children).
*& Read only.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor: de-duplication).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - job claim of another monitor</p>
INTERFACE zif_ca_ops_job_claim
  PUBLIC.

  "! The jobs of the list another monitor reports, with who reports them
  METHODS claimed
    IMPORTING
      it_jobs          TYPE zif_ca_ops_job_types=>tt_job
    RETURNING
      VALUE(rt_claims) TYPE zif_ca_ops_job_types=>tt_claim
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
