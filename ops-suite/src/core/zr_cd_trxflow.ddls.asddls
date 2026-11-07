// Artifact: zr_cd_trxflow.ddls.asddls
// Purpose: Root of the transactions dashboard (analytical list page, OData V4,
//          docs/Dashboard_Transactions.md): one row per payment-engine open item with a payment
//          request FIN number and its canonical payment outcome (ZI_CD_TrxItemFlow: the verdict of
//          the evaluator ZIF_CD_OPS_PAY_OUTCOME, the same as the morning report check A_INFLIGHT and
//          the payment trace). Parameters:
//            P_DateKind  POSTING (DFKKOP-BUDAT), RUN (latest DPAYH-LAUFD) or VALUE (DPAYH-VALUT)
//            P_DateFrom / P_DateTo  the day (or days) chosen - any date within the 400-day
//                        retention (ZI_CD_TrxItem); the outcome snapshot runs every 5 minutes, so a
//                        day can be chosen at any time during the day
//            P_AsOfDate / P_AsOfTime  the outcome version valid at that instant (system time zone;
//                        default now). History exists from go-live only: before it every paid item
//                        is NOT_EVALUATED.
//          The request date is a filter of the request side (cds/ZR_CD_TrxReqFlow). Aggregation is
//          done by HANA on the base rows ($apply on ZC_CD_TrxFlow, whose DCL restricts the base rows
//          by company code before the GROUP BY). Drill-down: payment runs, returns / NOC lot items;
//          payment trace by FIN or clearing document. No member number, partner or bank account.
//          Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Review defect: SETTLED from any bank / encashment line - the bucket is now
//                   the canonical outcome (ZI_CD_TrxItemFlow); date kind and as-of parameters.
// VERIFY-ADT: OR of parameter comparisons in WHERE is pruned by HANA per date kind (PlanViz, TXD-12).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - transaction'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MIXED }
define root view entity ZR_CD_TrxFlow
  with parameters
    @EndUserText.label: 'Date kind (POSTING, RUN, VALUE)'
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
  as select from ZI_CD_TrxItemFlow( P_AsOfDate : $parameters.P_AsOfDate,
                                    P_AsOfTime : $parameters.P_AsOfTime ) as Flow
  association [0..*] to ZR_CD_TrxPayRun as _PaymentRuns on $projection.ClearingDoc = _PaymentRuns.PaymentDocument
  association [0..*] to ZR_CD_TrxRetNoc as _ReturnsNoc  on  $projection.DocumentNo     = _ReturnsNoc.DocumentNo
                                                        and $projection.RepetitionItem = _ReturnsNoc.RepetitionItem
                                                        and $projection.ItemNo         = _ReturnsNoc.ItemNo
                                                        and $projection.SubItem        = _ReturnsNoc.SubItem
{
  key Flow.DocumentNo,
  key Flow.RepetitionItem,
  key Flow.ItemNo,
  key Flow.SubItem,
      Flow.PaymentEngineArea,
      Flow.FinId,
      Flow.BillPlanId,
      Flow.CompanyCode,
      Flow.PostingDate,
      Flow.IsToday,
      Flow.PaymentMethod,
      Flow.Direction,
      Flow.LocalCurrency,
      @Semantics.amount.currencyCode: 'LocalCurrency'
      Flow.AmountInLocalCurrency,
      Flow.Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Flow.Amount,
      Flow.ClearingStatus,
      Flow.ClearingDoc,
      Flow.ClearingDate,
      Flow.ClearingReason,
      Flow.LastRunDate,
      Flow.LastRunId,
      Flow.ValueDate,
      Flow.PaymentStatus,
      Flow.ChequeNo,
      Flow.ChequeHouseBank,
      Flow.SettlementDate,
      Flow.EncashDate,
      Flow.ReturnReason,
      Flow.NocReason,
      Flow.Outcome,
      Flow.OutcomeFinding,
      Flow.OutcomeEvidenceKind,
      Flow.OutcomeEvidenceRef,
      Flow.OutcomeValidFrom,
      Flow.OutcomeSourceCount,
      Flow.FlowBucket,
      Flow.FlowCriticality,
      // ---------------------------------------------------------------- measures
      Flow.ItemCount,
      Flow.PaidReachedCount,
      Flow.ClearedCount,
      Flow.ReturnedCount,
      Flow.RetrievedCount,
      Flow.VoidedCount,
      Flow.PendingCount,
      Flow.InFlightCount,
      Flow.UndeterminedCount,
      Flow.InconsistentCount,
      Flow.AmbiguousCount,
      Flow.ReversedCount,
      Flow.NotEvaluatedCount,
      Flow.OpenCount,
      Flow.NocItemCount,
      Flow.ChequeItemCount,
      _PaymentRuns,
      _ReturnsNoc
}
where ( $parameters.P_DateKind = 'POSTING'
        and Flow.PostingDate between $parameters.P_DateFrom and $parameters.P_DateTo )
   or ( $parameters.P_DateKind = 'RUN'
        and Flow.LastRunDate between $parameters.P_DateFrom and $parameters.P_DateTo )
   or ( $parameters.P_DateKind = 'VALUE'
        and Flow.ValueDate between $parameters.P_DateFrom and $parameters.P_DateTo )
