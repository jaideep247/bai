*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_demo_types.intf.abap
*& Purpose:
*& Constants and types of the demo consumer ZCA_OPS_DEMO (optional
*& sub-package, not needed in production): its area CA_DEMO, the check
*& codes of its three findings, the background job statuses it counts in
*& TBTCO, the time window and the numbers of its messages in class ZCA_OPS.
*& Modification log:
*& 2026-11-10 | Initial version (demo consumer of the operations framework).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework demo - constants and types</p>
INTERFACE zif_ca_ops_demo_types
  PUBLIC.

  "! Area of the demo: a parameter area of ZCA_PARAM (config/demo/param_areas_demo.csv)
  CONSTANTS gc_area TYPE zif_ca_ops_types=>ty_area VALUE 'CA_DEMO'.
  "! Variant of the run (one per report call)
  CONSTANTS gc_variant TYPE zif_ca_ops_types=>ty_variant VALUE 'JOBS_24H'.
  CONSTANTS gc_rule_id TYPE zif_ca_ops_types=>ty_rule_id VALUE 'DEMO'.
  "! Object of the findings: the background jobs of this client (TBTCO)
  CONSTANTS gc_object_type TYPE zif_ca_ops_types=>ty_object_type VALUE 'JOBS'.
  CONSTANTS gc_object_key TYPE zif_ca_ops_types=>ty_object_key VALUE 'TBTCO'.

  "! Check codes of the three findings
  CONSTANTS:
    BEGIN OF gc_check,
      "! Information: jobs that ended in the window
      ended   TYPE zif_ca_ops_types=>ty_check_code VALUE 'DEMO_JOBS_ENDED',
      "! Error (open exception): jobs that were cancelled in the window
      aborted TYPE zif_ca_ops_types=>ty_check_code VALUE 'DEMO_JOBS_ABORTED',
      "! Warning: released jobs still not started a while after their planned start
      late    TYPE zif_ca_ops_types=>ty_check_code VALUE 'DEMO_JOBS_LATE',
    END OF gc_check.

  "! Background job status (TBTCO-STATUS, SAP standard values)
  TYPES ty_job_status TYPE c LENGTH 1.
  CONSTANTS:
    BEGIN OF gc_job_status,
      finished TYPE ty_job_status VALUE 'F',
      aborted  TYPE ty_job_status VALUE 'A',
      released TYPE ty_job_status VALUE 'S',
    END OF gc_job_status.

  "! Window of the check (hours back from now) and the delay after which a released job is late
  CONSTANTS gc_window_hours TYPE i VALUE 24.
  CONSTANTS gc_late_minutes TYPE i VALUE 60.
  CONSTANTS gc_seconds_per_minute TYPE i VALUE 60.
  CONSTANTS gc_hours_per_day TYPE i VALUE 24.

  "! Messages of the demo in class ZCA_OPS (texts of the findings and the result line)
  CONSTANTS:
    BEGIN OF gc_msg,
      ended   TYPE zif_ca_ops_types=>ty_msgno VALUE '900',
      aborted TYPE zif_ca_ops_types=>ty_msgno VALUE '901',
      late    TYPE zif_ca_ops_types=>ty_msgno VALUE '902',
    END OF gc_msg.

  "! A point in time as TBTCO stores it (server date and time)
  TYPES:
    BEGIN OF ty_moment,
      date TYPE d,
      time TYPE t,
    END OF ty_moment.

  "! Job counts of the window
  TYPES:
    BEGIN OF ty_counts,
      ended   TYPE i,
      aborted TYPE i,
      late    TYPE i,
    END OF ty_counts.

  "! Result of one demo run: the run header and the findings written
  TYPES:
    BEGIN OF ty_result,
      run      TYPE zif_ca_ops_types=>ty_run,
      counts   TYPE ty_counts,
      findings TYPE zif_ca_ops_types=>tt_finding,
    END OF ty_result.

ENDINTERFACE.
