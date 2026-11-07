// Artifact: zc_cd_trxkpi.ddls.asddls
// Purpose: Consumption view of the KPI entity (TransactionKpi): per posting date, company code and
//          direction - transactions, FIN numbers, paid and the canonical outcome now (cleared,
//          returned, retrieved, voided, in flight, problems, reversed, open, NOC, not evaluated);
//          tiles and overview-page cards. Read access: DCL ZC_CD_TRXDASH (company code = GROUP BY
//          key of ZR_CD_TrxKpi, so the condition equals the one on the base rows). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Canonical outcome measures.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard - KPI'
@Metadata.allowExtensions: true
define root view entity ZC_CD_TrxKpi
  provider contract transactional_query
  as projection on ZR_CD_TrxKpi
{
  key PostingDate,
  key CompanyCode,
  key Direction,
      PaymentEngineArea,
      IsToday,
      @Aggregation.default: #SUM
      ItemCount,
      @Aggregation.default: #SUM
      FinCount,
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
      InFlightCount,
      @Aggregation.default: #SUM
      ProblemCount,
      @Aggregation.default: #SUM
      ReversedCount,
      @Aggregation.default: #SUM
      OpenCount,
      @Aggregation.default: #SUM
      NocItemCount,
      @Aggregation.default: #SUM
      NotEvaluatedCount,
      DayCriticality
}
