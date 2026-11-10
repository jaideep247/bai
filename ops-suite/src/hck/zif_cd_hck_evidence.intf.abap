*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_evidence.intf.abap
*& Purpose:
*& One kind of clearing / return evidence of the in-flight check
*& (A_INFLIGHT): given the payments of payment runs that are candidates
*& for "in flight", returns per payment whether the evidence was found,
*& with hits, a short detail and an anomaly of the evidence itself. The
*& kind is named in ZCD_HCK_CLRRULE-EVIDENCE_CLASS with its PARAM1-3; the
*& check combines the rows of one purpose (CLEARED / RETURNED / VOIDED /
*& PENDING). One batch read per kind and run, never one per payment.
*& Read-only: an implementation never posts, clears or changes a status.
*& Modification log:
*& 2026-11-07 | Initial version (clearing / return evidence as plug-ins, user rule 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - payment clearing / return evidence kind</p>
"! A new evidence kind = a new class implementing this interface + rows in ZCD_HCK_CLRRULE;
"! the check is not changed. Implementations read only through ZIF_CD_OPS_TRACE_DAO or
"! ZIF_CD_HCK_RUNTIME_DAO (factories), so they are tested with doubles.
INTERFACE zif_cd_hck_evidence
  PUBLIC.

  "! Evidence of the payments. A payment without a row in the result has no evidence.
  "! @parameter it_payments | payments of one or more flow / method classes (flow and class set)
  "! @parameter is_rule | the rule row (PARAM1-3) the kind is evaluated for
  "! @parameter iv_max_rows | row cap of every read of the kind (result capped = flagged)
  "! @raising zcx_ca_ops_error | parameter missing or invalid, configuration unusable
  METHODS collect
    IMPORTING
      it_payments      TYPE zif_cd_hck_runtime_types=>tt_issued_payment
      is_rule          TYPE zif_cd_hck_runtime_types=>ty_clr_rule
      iv_max_rows      TYPE i
    RETURNING
      VALUE(rs_result) TYPE zif_cd_hck_runtime_types=>ty_evidence_result
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
