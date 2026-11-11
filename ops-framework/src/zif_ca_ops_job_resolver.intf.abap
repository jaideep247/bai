*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_job_resolver.intf.abap
*& Purpose:
*& Plug-in contract of a parent / child resolver of the SAP job monitor
*& (parameter JOB_RESOLVERS: classes in order, checked by RTTI before
*& creation). A resolver links jobs set-based - one call for all jobs of a
*& run, its reads through the job monitor's data access and job log reader
*& handed in - and states the evidence quality of every link: C confirmed
*& by a key (a field, an event parameter, a job log line naming the job),
*& P probable (heuristic, name pattern, time window). Delivered: FIELD,
*& EVENT, JOBLOG, HEURISTIC (framework); a consumer adds its own (e.g. the
*& worker jobs of a mass activity run). Read only; a resolver that cannot
*& work (parameter blank, field not in the DDIC) returns nothing.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - job parent / child resolver</p>
"! The monitor keeps for each child the first link in resolver order (a confirmed link first when two
"! resolvers of the same position disagree); a resolver that raises is a JOB_PLUGIN_FAILED finding.
INTERFACE zif_ca_ops_job_resolver
  PUBLIC.

  "! ID of the resolver, stored with every link it found
  METHODS id
    RETURNING
      VALUE(rv_id) TYPE zif_ca_ops_job_types=>ty_resolver_id.

  "! Parents of the jobs (one link per child at most)
  "! @parameter it_jobs   | Children (TBTCO rows)
  "! @parameter is_config | Settings of the run (caps, programs)
  "! @parameter io_dao    | Reads of TBTCO / TBTCP of the monitor
  "! @parameter io_log    | Job log reader (cached by the monitor for the run)
  METHODS parents
    IMPORTING
      it_jobs         TYPE zif_ca_ops_job_types=>tt_job
      is_config       TYPE zif_ca_ops_job_types=>ty_config
      io_dao          TYPE REF TO zif_ca_ops_job_dao
      io_log          TYPE REF TO zif_ca_ops_job_log
    RETURNING
      VALUE(rt_links) TYPE zif_ca_ops_job_types=>tt_link
    RAISING
      zcx_ca_ops_error.

  "! Children of the jobs (at most JOB_MAX_CHILDREN per parent)
  METHODS children
    IMPORTING
      it_jobs         TYPE zif_ca_ops_job_types=>tt_job
      is_config       TYPE zif_ca_ops_job_types=>ty_config
      io_dao          TYPE REF TO zif_ca_ops_job_dao
      io_log          TYPE REF TO zif_ca_ops_job_log
    RETURNING
      VALUE(rt_links) TYPE zif_ca_ops_job_types=>tt_link
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
