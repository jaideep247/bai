// Artifact: zc_cd_trxproblem.ddls.asddls
// Purpose: Consumption view of the exceptions of the payment worklist (service ZUI_CD_TRX_DASH):
//          inconsistent, undetermined, ambiguous, late payments, payments waiting for the status job and
//          requests not paid on their due date; overview-page list card, oldest first, navigation to the
//          payment trace.
//          Read access: DCL ZC_CD_TRXDASH (ZCD_OPS, ZCA_PARAR = CORE and BUKRS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Canonical outcome: outcome finding.
//                   2026-11-08 | Exceptions-only worklist: the worklist's exceptions.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard - errored / stuck'
@Metadata.allowExtensions: true
define root view entity ZC_CD_TrxProblem
  provider contract transactional_query
  as projection on ZR_CD_TrxProblem
{
  key FinId,
  key SourceSystem,
  key CompanyCode,
  key ClearingDoc,
  key RunDate,
  key RunId,
      PaymentEngineArea,
      WorkKind,
      WorklistDate,
      ExceptionSince,
      Outcome,
      EvidenceKind,
      EvidenceRef,
      FlowClass,
      PaymentMethod,
      Direction,
      PaymentStatus,
      ProblemType,
      ProblemCriticality,
      Currency,
      Amount
}
