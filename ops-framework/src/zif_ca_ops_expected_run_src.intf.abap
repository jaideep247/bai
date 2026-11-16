*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_expected_run_src.intf.abap
*& Purpose:
*& Plug-in contract of an expected-run source (docs/EXPECTED_RUNS_AND_
*& MASS_ACTIVITIES.md section 2): the plan of the external scheduler for
*& a range of days - each expected job with its run ID, planned start,
*& late limit, predecessor and the state the scheduler reports (planned,
*& started, ended OK, ended not OK, held, not started) - with the days
*& the business calendar does not expect a run, the days that cannot be
*& told, the newest record of the source (its freshness) and whether it
*& returned less than its plan. Parameter XRUN_SOURCES names the classes
*& in order (interface checked by RTTI before creation). Delivered:
*& ZCL_CA_OPS_XRUN_SRC_JOBSCH (the plan of the framework's own scheduler
*& job configuration ZCA_OPS_JOBSCH plus a business calendar, "expected
*& by configuration"); a site plugs a reader of its scheduler's export
*& (worked example examples/expected_runs, never seeded). Read only: a
*& source never starts, holds or releases anything.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - expected-run source</p>
"! A source that cannot read its plan raises: the check reports it "not evaluated", never "no run expected".
INTERFACE zif_ca_ops_expected_run_src
  PUBLIC.

  "! ID of the source (evidence rows, freshness of the evaluation record)
  METHODS id
    RETURNING
      VALUE(rv_id) TYPE zif_ca_ops_xrun_types=>ty_source_id.

  "! The plan of the requested days
  "! @raising zcx_ca_ops_error | the plan cannot be read (file missing, table not readable)
  METHODS read
    IMPORTING
      is_request     TYPE zif_ca_ops_xrun_types=>ty_request
    RETURNING
      VALUE(rs_plan) TYPE zif_ca_ops_xrun_types=>ty_plan
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
