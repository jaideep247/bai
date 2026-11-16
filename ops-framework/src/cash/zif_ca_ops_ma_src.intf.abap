*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_ma_src.intf.abap
*& Purpose:
*& Plug-in contract of the run source of the FI-CA mass activity check
*& (docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md section 3.2): the runs of a
*& mass activity since a date - run date, run ID where known, the parent
*& job and the run's intervals with their state. Parameter MA_SOURCE names
*& the class (interface checked by RTTI). Delivered: ZCL_CA_OPS_MA_SRC_JOBS
*& - the parent job by program and name, its intervals as the parallel
*& jobs the job monitor's resolvers link to it (SAP's job tables only).
*& A source that reads the mass activity's own run and interval records
*& replaces it once their tables and status values are confirmed on the
*& target release (VERIFY V300). Read only.
*& Modification log:
*& 2026-11-16 | Initial version (build P: FI-CA mass-activity intervals and their output).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA mass activities - run source</p>
INTERFACE zif_ca_ops_ma_src
  PUBLIC.

  "! The runs of a mass activity whose parent job started on or after iv_from (oldest first, at most iv_max)
  "! @raising zcx_ca_ops_error | the runs cannot be read (the rule is then "not evaluated")
  METHODS runs
    IMPORTING
      is_activity    TYPE zif_ca_ops_ma_types=>ty_activity
      iv_from        TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rs_runs) TYPE zif_ca_ops_ma_types=>ty_runs
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
