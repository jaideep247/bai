// Artifact: zc_cd_trxproblem.ddls.asddls
// Purpose: Consumption view of returned, reversed and overdue open disbursements (service ZUI_CD_TRX_DASH):
//          overview-page list card, newest first, navigation to the payment trace.
//          Read access: DCL ZC_CD_TRXDASH (ZCD_OPS, ZCD_PE_AREA = CORE and BUKRS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard - errored / stuck'
@Metadata.allowExtensions: true
define root view entity ZC_CD_TrxProblem
  provider contract transactional_query
  as projection on ZR_CD_TrxProblem
{
  key DocumentNo,
  key RepetitionItem,
  key ItemNo,
  key SubItem,
      PaymentEngineArea,
      FinId,
      CompanyCode,
      PostingDate,
      PaymentMethod,
      Direction,
      ClearingDoc,
      ClearingDate,
      PaymentStatus,
      ReturnReason,
      FlowBucket,
      ProblemType,
      ProblemCriticality,
      Currency,
      Amount
}
