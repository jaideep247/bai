*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_check_config.intf.abap
*& Purpose:
*& Optional second contract of a registered check (explainable, versioned
*& results): the effective configuration rows the check runs with besides
*& its registry row - aggregate rows, bucket rules and their conditions,
*& accounts, the values of the parameters it reads - one text line per row.
*& The runner hashes them with the registry row (ZCL_CA_OPS_CFG_VERSION)
*& into the configuration version stamped on every finding of the run
*& (ZCA_OPS_FINDING-CFG_VERSION). A check without this interface is
*& versioned by its registry row only. Read only: nothing is written.
*& Modification log:
*& 2026-11-11 | Initial version (explainable, versioned results).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - configuration rows of a check</p>
"! Lines are built with ZCL_CA_OPS_CFG_VERSION=>LINE (kind and the row's values); their order does not
"! matter (the version sorts them). Leave out what does not change a result (descriptions, sequence).
INTERFACE zif_ca_ops_check_config
  PUBLIC.

  "! Effective configuration rows of the check besides its registry row
  "! @parameter is_check  | The registry row the runner runs
  "! @parameter rt_lines  | One line per configuration row (ZCL_CA_OPS_CFG_VERSION=>LINE)
  "! @raising zcx_ca_ops_error | A configuration row cannot be read: the runner records CHECK_FAILED
  METHODS config_lines
    IMPORTING
      is_check        TYPE zif_ca_ops_chk_types=>ty_check
    RETURNING
      VALUE(rt_lines) TYPE string_table
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
