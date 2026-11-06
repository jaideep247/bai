// Artifact: zc_cd_trxflow.ddls.asddls
// Purpose: Consumption view of the transactions dashboard (analytical list page, OData V4,
//          service ZUI_CD_TRX_DASH): payment-engine open items with FIN of the last 31 days and their flow
//          bucket, default aggregation of every measure, drill-down to payment runs and
//          returns / NOC lot items; navigation to the payment trace (FIN / clearing document).
//          UI annotations in the metadata extension ZC_CD_TRXFLOW.
//          Read access: DCL ZC_CD_TRXDASH (ZCD_OPS, ZCD_PE_AREA = CORE and BUKRS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard'
@Metadata.allowExtensions: true
// VERIFY-ADT: OData V4 data aggregation of a transactional_query projection without
// behaviour definition (as ZC_CD_FmonFlow)
define root view entity ZC_CD_TrxFlow
  provider contract transactional_query
  as projection on ZR_CD_TrxFlow
{
  key DocumentNo,
  key RepetitionItem,
  key ItemNo,
  key SubItem,
      PaymentEngineArea,
      FinId,
      BillPlanId,
      CompanyCode,
      PostingDate,
      IsToday,
      PaymentMethod,
      Direction,
      LocalCurrency,
      @Aggregation.default: #SUM
      AmountInLocalCurrency,
      Currency,
      @Aggregation.default: #SUM
      Amount,
      ClearingStatus,
      ClearingDoc,
      ClearingDate,
      ClearingReason,
      LastRunDate,
      LastRunId,
      PaymentStatus,
      ChequeNo,
      ChequeHouseBank,
      SettlementDate,
      EncashDate,
      ReturnReason,
      NocReason,
      FlowBucket,
      FlowCriticality,
      @Aggregation.default: #SUM
      ItemCount,
      @Aggregation.default: #SUM
      PaidReachedCount,
      @Aggregation.default: #SUM
      SettledReachedCount,
      @Aggregation.default: #SUM
      ReturnedCount,
      @Aggregation.default: #SUM
      ReversedCount,
      @Aggregation.default: #SUM
      OpenCount,
      @Aggregation.default: #SUM
      NocItemCount,
      @Aggregation.default: #SUM
      ChequeItemCount,
      @Aggregation.default: #SUM
      PaymentRunCount,
      _PaymentRuns : redirected to ZC_CD_TrxPayRun,
      _ReturnsNoc : redirected to ZC_CD_TrxRetNoc
}
