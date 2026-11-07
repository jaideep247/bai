// Artifact: zc_cd_trxflow.ddls.asddls
// Purpose: Consumption view of the transactions dashboard (analytical list page, OData V4,
//          service ZUI_CD_TRX_DASH): payment-engine open items with FIN of the chosen day(s) by
//          posting, payment run or value date (any day within the 400-day retention) and their
//          canonical payment outcome as of the chosen instant (default now; history from go-live),
//          default aggregation of every measure (HANA aggregates the base rows that the DCL left -
//          the company-code restriction applies before the GROUP BY), drill-down to payment runs and
//          returns / NOC lot items; navigation to the payment trace (FIN / clearing document).
//          UI annotations in the metadata extension ZC_CD_TRXFLOW.
//          Read access: DCL ZC_CD_TRXDASH (ZCD_OPS, ZCD_PE_AREA = CORE and BUKRS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Canonical outcome, date kind and as-of parameters (ZR_CD_TrxFlow).
// VERIFY-ADT: parameters of a transactional_query projection in an analytical list page (OData V4).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard'
@Metadata.allowExtensions: true
define root view entity ZC_CD_TrxFlow
  provider contract transactional_query
  with parameters
    @EndUserText.label: 'Date kind (POSTING, RUN, VALUE)'
    @Consumption.defaultValue: 'POSTING'
    P_DateKind : abap.char( 10 ),
    @EndUserText.label: 'Date from'
    @Environment.systemField: #SYSTEM_DATE
    P_DateFrom : abap.dats,
    @EndUserText.label: 'Date to'
    @Environment.systemField: #SYSTEM_DATE
    P_DateTo   : abap.dats,
    @EndUserText.label: 'Outcome as of (date, from go-live)'
    @Environment.systemField: #SYSTEM_DATE
    P_AsOfDate : abap.dats,
    @EndUserText.label: 'Outcome as of (time, system time zone)'
    @Environment.systemField: #SYSTEM_TIME
    P_AsOfTime : abap.tims
  as projection on ZR_CD_TrxFlow( P_DateKind : $parameters.P_DateKind,
                                  P_DateFrom : $parameters.P_DateFrom,
                                  P_DateTo   : $parameters.P_DateTo,
                                  P_AsOfDate : $parameters.P_AsOfDate,
                                  P_AsOfTime : $parameters.P_AsOfTime )
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
      ValueDate,
      PaymentStatus,
      ChequeNo,
      ChequeHouseBank,
      SettlementDate,
      EncashDate,
      ReturnReason,
      NocReason,
      Outcome,
      OutcomeFinding,
      OutcomeEvidenceKind,
      OutcomeEvidenceRef,
      OutcomeValidFrom,
      OutcomeSourceCount,
      FlowBucket,
      FlowCriticality,
      @Aggregation.default: #SUM
      ItemCount,
      @Aggregation.default: #SUM
      PaidReachedCount,
      @Aggregation.default: #SUM
      ClearedCount,
      @Aggregation.default: #SUM
      ReturnedCount,
      @Aggregation.default: #SUM
      RetrievedCount,
      @Aggregation.default: #SUM
      VoidedCount,
      @Aggregation.default: #SUM
      PendingCount,
      @Aggregation.default: #SUM
      InFlightCount,
      @Aggregation.default: #SUM
      UndeterminedCount,
      @Aggregation.default: #SUM
      InconsistentCount,
      @Aggregation.default: #SUM
      AmbiguousCount,
      @Aggregation.default: #SUM
      ReversedCount,
      @Aggregation.default: #SUM
      NotEvaluatedCount,
      @Aggregation.default: #SUM
      OpenCount,
      @Aggregation.default: #SUM
      NocItemCount,
      @Aggregation.default: #SUM
      ChequeItemCount,
      _PaymentRuns : redirected to ZC_CD_TrxPayRun,
      _ReturnsNoc : redirected to ZC_CD_TrxRetNoc
}
