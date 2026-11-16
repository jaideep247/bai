*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_eval_dao.intf.abap
*& Purpose:
*& Repository of the evaluation records (ZCA_OPS_EVAL, sources
*& ZCA_OPS_EVALSRC; docs/EVALUATION_AND_COVERAGE.md): the runner saves one
*& record per registered check and run in its unit of work (never in test
*& mode), each with its last valid result; the coverage check reads the
*& latest record per check. Obtained from ZCL_CA_OPS_FACTORY=>GET_EVAL_DAO
*& (double: ZCL_CA_OPS_INJECTOR=>INJECT_EVAL_DAO). No commit.
*& Modification log:
*& 2026-11-16 | Initial version (build O: evaluation state of every control).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - evaluation records</p>
INTERFACE zif_ca_ops_eval_dao
  PUBLIC.

  "! Insert the records and their sources. LAST_VALID_* of a record: the record itself when complete, else the
  "! latest complete record of the same area and check
  "! @raising zcx_ca_ops_error | 010 a row was refused by the database
  METHODS save
    IMPORTING
      it_eval TYPE zif_ca_ops_eval_types=>tt_eval
    RAISING
      zcx_ca_ops_error.

  "! The latest record of every check of an area (blank = every area), without sources
  METHODS latest
    IMPORTING
      iv_area        TYPE zif_ca_ops_types=>ty_area OPTIONAL
    RETURNING
      VALUE(rt_eval) TYPE zif_ca_ops_eval_types=>tt_eval.

ENDINTERFACE.
