// Artifact: zc_cd_trxreqflow.ddls.asddls
// Purpose: Consumption view of the request funnel (ADT only, cds/, service ZUI_CD_TRX_REQ):
//          payment requests and their payments by stage (canonical outcome as of the chosen
//          instant) and source, funnel measures, navigation to the payment trace (FIN + source).
//          Read access: DCL ZC_CD_TRXREQ (ZCD_OPS, CORE and BUKRS, ACTVT 03) on the row's company
//          code - a row-level key, so HANA's aggregation ($apply) only sums rows the user may see.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
//                   2026-11-07 | Canonical outcome, request date window and as-of parameters; identity
//                   FIN + source + company code + payment.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard - request funnel'
@Metadata.allowExtensions: true
define root view entity ZC_CD_TrxReqFlow
  provider contract transactional_query
  with parameters
    @EndUserText.label: 'Request date from'
    @Environment.systemField: #SYSTEM_DATE
    P_DateFrom : abap.dats,
    @EndUserText.label: 'Request date to'
    @Environment.systemField: #SYSTEM_DATE
    P_DateTo   : abap.dats
  as projection on ZR_CD_TrxReqFlow( P_DateFrom : $parameters.P_DateFrom,
                                     P_DateTo   : $parameters.P_DateTo )
{
  key FinId,
  key SourceSystem,
  key CompanyCode,
  key ClearingDoc,
  key PaymentMethod,
      PaymentEngineArea,
      RequestDate,
      LastAttemptDate,
      RequestOutcome,
      Direction,
      PostingDate,
      SourceCount,
      RetrievalStatus,
      Outcome,
      OutcomeFinding,
      OutcomeEvidenceKind,
      OutcomeEvidenceRef,
      OutcomeValidFrom,
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
      ErroredCount,
      @Aggregation.default: #SUM
      RejectedCount,
      @Aggregation.default: #SUM
      ExceptionCount,
      @Aggregation.default: #SUM
      AmbiguousCount,
      @Aggregation.default: #SUM
      AttemptCount,
      @Aggregation.default: #SUM
      SuccessAttempts,
      @Aggregation.default: #SUM
      ErrorAttempts
}
