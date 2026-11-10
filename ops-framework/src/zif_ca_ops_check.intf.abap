*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_check.intf.abap
*& Purpose:
*& Contract of a registered check (ZCA_OPS_CHECK-CLASS_NAME): measure one
*& thing of a business process and return findings. The generic runner
*& ZCL_CA_OPS_CHECK_RUNNER creates the class by name (interface checked by
*& RTTI first), calls RUN once per run, stamps GROUP1 = process ID and
*& GROUP2 = check ID on every finding, stores them through the store
*& (B / E / W = owned exceptions), auto-resolves what a complete check no
*& longer raises and routes the alerts. A check never persists, commits,
*& alerts or writes a business table; it reads only through its own data
*& access class. The no-code check ZCL_CA_OPS_CHK_AGG and the onboarding
*& check ZCL_CA_OPS_CHK_ONBOARD implement it; a consumer's check class too.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - registered check contract</p>
"! Findings: OBJECT_KEY identifies the object (with CHECK_CODE and COMPANY_CODE the identity
"! of an exception); fill COMPANY_CODE where the finding is about one company code; texts are
"! messages of the consumer's message class. A raised exception is a CHECK_FAILED finding.
INTERFACE zif_ca_ops_check
  PUBLIC.

  "! Run the check once
  "! @parameter is_check   | The registry row (area, check ID, process, schedule group, company-code aware)
  "! @parameter is_context | Run ID, test mode, today and now of the run
  "! @parameter rs_result  | Findings, items evaluated, partial flag
  "! @raising zcx_ca_ops_error | Configuration or read error: the runner records CHECK_FAILED
  METHODS run
    IMPORTING
      is_check         TYPE zif_ca_ops_chk_types=>ty_check
      is_context       TYPE zif_ca_ops_chk_types=>ty_context
    RETURNING
      VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
