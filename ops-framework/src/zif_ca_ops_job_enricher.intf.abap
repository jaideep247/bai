*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_job_enricher.intf.abap
*& Purpose:
*& Plug-in contract of an enricher of the SAP job monitor (parameter
*& JOB_ENRICHERS: classes in order, checked by RTTI before creation): the
*& consumer's business context of failed jobs and their ancestors -
*& business objects such as a payment run or a mass activity run, with a
*& label (a message of the consumer's class), a company code, a count and
*& the evidence quality (C confirmed by key, P probable). Set-based: one
*& call per run. An enricher sees the objects of the enrichers before it
*& (e.g. a payment run found from a mass activity run). Read only.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - job enricher (business context)</p>
"! The company code of an object becomes the company code of the job's finding when the objects of a
"! job name exactly one; an enricher that raises is a JOB_PLUGIN_FAILED finding.
INTERFACE zif_ca_ops_job_enricher
  PUBLIC.

  "! Add business objects of the jobs
  "! @parameter it_jobs    | Failed jobs and their ancestors (TBTCO rows)
  "! @parameter it_steps   | Their steps (program, variant, user)
  "! @parameter ct_objects | Objects of the enrichers so far; this enricher adds its own
  METHODS enrich
    IMPORTING
      it_jobs    TYPE zif_ca_ops_job_types=>tt_job
      it_steps   TYPE zif_ca_ops_job_types=>tt_step
    CHANGING
      ct_objects TYPE zif_ca_ops_job_types=>tt_bus_object
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
