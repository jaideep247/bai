// Artifact: zi_cd_payoutcome.ddls.asddls
// Purpose: Basic view of the payment worklist ZCD_PAY_OUTCOME (written only by the snapshot
//          ZCL_CD_OPS_PAY_SNAPSHOT - FAST / NIGHTLY / SWEEP - from the evaluator ZIF_CD_OPS_PAY_OUTCOME and
//          the request rule ZIF_CD_OPS_PAY_REQUEST): open payments, open payment requests and
//          exceptions only (user decision 2026-11-08 - a clean payment has no row). One row per
//          version of FIN + source + company code + payment document + payment run (request rows: payment
//          document blank), valid from / to (UTC; open end 99991231235959 = current), outcome, deciding
//          evidence kind (for a request the stage reached) and reference, finding, severity, flow + method
//          class, due date of a request. Keys only: amounts, dates, partner and method are joined from
//          DPAYH / DFKKOP / FEBEP / ZCD_PAYM_REQ_LOG by the consumers. Read-only.
// Modification log: 2026-11-07 | Initial version (one canonical payment outcome model).
//                   2026-11-08 | Exceptions-only worklist: severity, flow + method class, due date.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment worklist row (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_PayOutcome
  as select from zcd_pay_outcome
{
  key fin_id                                                as FinId,
  key source                                                as SourceSystem,
  key bukrs                                                 as CompanyCode,
  key augbl                                                 as ClearingDoc,
  key laufd                                                 as RunDate,
  key laufi                                                 as RunId,
  key valid_from                                            as ValidFrom,
      valid_to                                              as ValidTo,
      outcome                                               as Outcome,
      evidence_kind                                         as EvidenceKind,
      evidence_ref                                          as EvidenceRef,
      finding                                               as Finding,
      severity                                              as Severity,
      evaluated_at                                          as EvaluatedAt,
      flow_class                                            as FlowClass,
      due_date                                              as DueDate
}
