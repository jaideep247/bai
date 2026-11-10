*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_pay_outcome.intf.abap
*& Purpose:
*& The one evaluator of a payment's outcome (canonical payment outcome
*& model): the method classes, rules and evidence plug-ins of the morning
*& report check A_INFLIGHT (posting areas ZPMC / ZBTR, ZCD_HCK_CLRRULE /
*& SEQOUT, ZCA_PARAM HCK_STRIPE_*, ZIF_CD_HCK_EVIDENCE) decide per payment CLEARED,
*& RETURNED, RETRIEVED, VOIDED, PENDING, IN_FLIGHT, UNDETERMINED or
*& INCONSISTENT; the source attribution of a FIN number decides AMBIGUOUS.
*& Used by A_INFLIGHT, the payment trace and the 5-minute snapshot behind
*& the transactions dashboard - no consumer holds a second copy of a rule.
*& Read-only: never posts, clears or changes a status.
*& Modification log:
*& 2026-11-07 | Initial version (evaluation extracted from ZCL_CD_HCK_C_INFLIGHT).
*& 2026-11-08 | Table consolidation: configuration tables named as after the merge (PMCLASS with house-bank
*&            | rows, Stripe settings in ZCA_PARAM).
*& 2026-11-08 | Comments: method classes / house-bank calendars are posting area ZPMC, bank code roles ZBTR
*&            | (were ZCD_HCK_PMCLASS / ZCD_HCK_BTCROLE, customer posting areas); no code change.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - canonical evaluator</p>
"! Get the instance from ZCL_CD_OPS_FACTORY=>GET_PAY_OUTCOME (test double by
"! ZCL_CD_OPS_INJECTOR=>INJECT_PAY_OUTCOME). Call LOAD once per run, then CLASSIFY /
"! EVALUATE (payments already read) or EVALUATE_DOCUMENTS (payment documents).
INTERFACE zif_cd_ops_pay_outcome
  PUBLIC.

  "! Load the configuration and start a run of the evidence kinds (shared reads per run).
  "! A class is watched when it has payment methods and at least one CLEARED rule.
  "! @parameter iv_context | object-key prefix of the findings (check id of the caller)
  "! @parameter iv_max_rows | row cap of every evidence read (reaching it = TECH_READ_CAPPED)
  "! @raising zcx_ca_ops_error | no watched method (E384), a method in two classes (E385)
  METHODS load
    IMPORTING
      iv_context       TYPE zif_cd_hck_types=>ty_check_id
      iv_max_rows      TYPE i
    RETURNING
      VALUE(rs_config) TYPE zif_cd_ops_payout_types=>ty_config
    RAISING
      zcx_ca_ops_error.

  "! Flow (TFK042Z-XEINZ) and method class (configuration) of each payment; a payment whose
  "! method is in no watched class is left out
  METHODS classify
    IMPORTING
      it_payments        TYPE zif_cd_hck_runtime_types=>tt_issued_payment
    RETURNING
      VALUE(rt_payments) TYPE zif_cd_hck_runtime_types=>tt_issued_payment.

  "! Verdict of every payment (flow and class set): reversed documents are REVERSED, the
  "! others are judged by their rules (one batch read per evidence kind, never per payment)
  METHODS evaluate
    IMPORTING
      it_payments          TYPE zif_cd_hck_runtime_types=>tt_issued_payment
    RETURNING
      VALUE(rs_evaluation) TYPE zif_cd_ops_payout_types=>ty_evaluation.

  "! Verdict of payment documents: the latest payment run of each document (DPAYH, run date
  "! then run ID descending), classified and evaluated. A document without a payment run or
  "! with a method of no watched class has no verdict
  METHODS evaluate_documents
    IMPORTING
      it_docno             TYPE zif_cd_ops_trace_types=>tt_docno
    RETURNING
      VALUE(rs_evaluation) TYPE zif_cd_ops_payout_types=>ty_evaluation.

  "! Sources of FIN numbers from the payment request log (configured source TRACE_SRC_REQUEST):
  "! the sources with a SUCCESS row, else every source found. A FIN without request row has
  "! one row with a blank source
  "! @raising zcx_ca_ops_error | request source not configured or not readable
  METHODS sources_of
    IMPORTING
      it_fin            TYPE zif_cd_ops_payout_types=>tt_fin
    RETURNING
      VALUE(rt_sources) TYPE zif_cd_ops_payout_types=>tt_fin_source
    RAISING
      zcx_ca_ops_error.

  "! The verdict for one source of the FIN: AMBIGUOUS (finding PAY_SOURCE_AMBIGUOUS, the
  "! evaluated outcome in the reference) when the FIN is in two or more sources
  METHODS for_source
    IMPORTING
      is_verdict        TYPE zif_cd_ops_payout_types=>ty_verdict
      is_source         TYPE zif_cd_ops_payout_types=>ty_fin_source
    RETURNING
      VALUE(rs_verdict) TYPE zif_cd_ops_payout_types=>ty_verdict.

ENDINTERFACE.
