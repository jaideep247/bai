*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_ma_dao.intf.abap
*& Purpose:
*& Data access of the FI-CA mass activity check (package ZCA_OPS_CASH):
*& the mass activities an area watches (ZCA_OPS_MAACT, active rows) and
*& the dunning notices of the runs (FKKMAKO: count and dunning balance per
*& run and currency, summed on the database). The payment documents of a
*& payment run are read through the cash checks' data access (ZIF_CA_OPS_
*& CASH_DAO=>PAYMENT_RUNS), never a second time here. Read only; a failed
*& read raises ZCX_CA_OPS_ERROR (the rule is then "not evaluated").
*& Modification log:
*& 2026-11-16 | Initial version (build P: FI-CA mass-activity intervals and their output).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA mass activities - data access</p>
"! FKKMAKO is the dunning history (header per business partner and contract account) of the reference system;
"! its run fields LAUFD / LAUFI and the dunning balance MSALM / WAERS are read (VERIFY V301: their meaning).
INTERFACE zif_ca_ops_ma_dao
  PUBLIC.

  "! Active mass activities of the area (ZCA_OPS_MAACT)
  "! @raising zcx_ca_ops_error | the configuration cannot be read
  METHODS activities
    IMPORTING
      iv_area              TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rt_activities) TYPE zif_ca_ops_ma_types=>tt_activity
    RAISING
      zcx_ca_ops_error.

  "! Dunning notices per run date, run ID and currency of the run dates from iv_from to iv_to, at most iv_max rows
  "! @raising zcx_ca_ops_error | the read failed
  METHODS dunning_notices
    IMPORTING
      iv_from        TYPE d
      iv_to          TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_ma_types=>tt_notice_sum
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
