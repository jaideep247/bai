*&---------------------------------------------------------------------*
*& Artifact: zif_cd_job_dao.intf.abap
*& Purpose:
*& Data access of the suite's SAP job monitor plug-ins: payments of payment
*& runs per company code (DPAYH, by run date and run ID - a confirmed key)
*& and the open exceptions of payment runs in the payment worklist
*& (ZCD_PAY_OUTCOME). Read only.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption, area CD_JOBS).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - SAP job monitor plug-in data access</p>
INTERFACE zif_cd_job_dao
  PUBLIC.

  "! Payments (not proposals) of the runs per run and company code
  METHODS run_payments
    IMPORTING
      it_runs            TYPE zif_cd_job_types=>tt_run_key
    RETURNING
      VALUE(rt_payments) TYPE zif_cd_job_types=>tt_run_payments.

  "! Current rows of the payment worklist with a finding (exceptions) per run
  METHODS run_exceptions
    IMPORTING
      it_runs              TYPE zif_cd_job_types=>tt_run_key
    RETURNING
      VALUE(rt_exceptions) TYPE zif_cd_job_types=>tt_run_exceptions.

ENDINTERFACE.
