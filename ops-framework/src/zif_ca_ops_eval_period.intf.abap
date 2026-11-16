*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_eval_period.intf.abap
*& Purpose:
*& Period-close calendar of the evaluation state (docs/EVALUATION_AND_
*& COVERAGE.md): is the accounting period of a check's expected scope
*& closed for an area (and company code)? A closed period turns a zero or
*& an OK into PER_CLOSED - no activity expected, a zero is not health.
*& Delivered: ZCL_CA_OPS_EVAL_PERIOD (parameter EVAL_PERIOD_CLOSED). A site
*& with its own period-close calendar plugs a class named in
*& EVAL_PERIOD_SOURCE (interface checked by RTTI); the SAP posting period
*& tables are not read by the product (VERIFY V275). Read-only.
*& Modification log:
*& 2026-11-16 | Initial version (build O: evaluation state of every control).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - period-close calendar</p>
INTERFACE zif_ca_ops_eval_period
  PUBLIC.

  "! X = the period is closed for the area and, when given, every company code of the list
  "! @parameter iv_bukrs_list | Company codes of the scope, comma list (blank = the area)
  METHODS is_closed
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
      iv_period        TYPE zif_ca_ops_eval_types=>ty_period
      iv_bukrs_list    TYPE zif_ca_ops_eval_types=>ty_bukrs_list OPTIONAL
    RETURNING
      VALUE(rv_closed) TYPE abap_bool.

ENDINTERFACE.
