// Artifact: zr_cd_trxproblem.ddls.asddls
// Purpose: "Errored / stuck" list of the transactions dashboard (launchpad list tile and the
//          production-support overview page list card): the exceptions of the payment worklist
//          (ZI_CD_PayWorkItem, a finding) - payments INCONSISTENT, UNDETERMINED, AMBIGUOUS, late beyond
//          AMBER / RED (PAYMENT_NOT_CLEARED), waiting for the payment status job (PAY_STATUS_PENDING)
//          and payment requests not paid on their due date (PRQ_NOT_PAID, the stage as evidence kind).
//          A return or retrieval with the right status is finished and not listed (user decision
//          2026-11-08). No window: the worklist bounds the rows. Oldest first. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Canonical outcome (problem outcomes); 31-day window here.
//                   2026-11-08 | Exceptions-only worklist: the exceptions of the worklist (OPEN_OVERDUE replaced
//                   by the requests not paid on their due date).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - errored / stuck'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_TrxProblem
  as select from ZI_CD_PayWorkItem as Work
{
  key Work.FinId,
  key Work.SourceSystem,
  key Work.CompanyCode,
  key Work.ClearingDoc,
  key Work.RunDate,
  key Work.RunId,
      Work.PaymentEngineArea,
      Work.WorkKind,
      Work.WorklistDate,
      Work.ValidFrom                                        as ExceptionSince,
      Work.Outcome,
      Work.EvidenceKind,
      Work.EvidenceRef,
      Work.FlowClass,
      Work.PaymentMethod,
      Work.Direction,
      Work.PaymentStatus,
      Work.Finding                                          as ProblemType,
      cast( case when Work.Severity = 'E' then 1 else 2 end as abap.int1 ) as ProblemCriticality,
      Work.Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Work.Amount
}
where Work.Finding <> ' '
