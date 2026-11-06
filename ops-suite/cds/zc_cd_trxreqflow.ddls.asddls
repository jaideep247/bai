// Artifact: zc_cd_trxreqflow.ddls.asddls
// Purpose: Consumption view of the request funnel (ADT only, cds/, service ZUI_CD_TRX_REQ):
//          payment requests by stage and source, funnel measures, navigation to the payment trace
//          (FIN + source). Read access: DCL ZC_CD_TRXREQ (ZCD_OPS, CORE and BUKRS, ACTVT 03).
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard - request funnel'
@Metadata.allowExtensions: true
define root view entity ZC_CD_TrxReqFlow
  provider contract transactional_query
  as projection on ZR_CD_TrxReqFlow
{
  key FinId,
  key SourceSystem,
      PaymentEngineArea,
      RequestDate,
      RequestOutcome,
      CompanyCode,
      PaymentMethod,
      Direction,
      PostingDate,
      ClearingDoc,
      ChequeNo,
      RetrievalStatus,
      RequestStage,
      StageCriticality,
      @Aggregation.default: #SUM
      RequestedCount,
      @Aggregation.default: #SUM
      ProcessedCount,
      @Aggregation.default: #SUM
      PostedCount,
      @Aggregation.default: #SUM
      PaidCount,
      @Aggregation.default: #SUM
      AcknowledgedCount,
      @Aggregation.default: #SUM
      SettledCount,
      @Aggregation.default: #SUM
      ErroredCount,
      @Aggregation.default: #SUM
      RejectedCount,
      @Aggregation.default: #SUM
      ReturnedCount,
      @Aggregation.default: #SUM
      AttemptCount,
      @Aggregation.default: #SUM
      SuccessAttempts,
      @Aggregation.default: #SUM
      ErrorAttempts
}
