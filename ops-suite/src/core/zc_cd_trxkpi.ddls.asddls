// Artifact: zc_cd_trxkpi.ddls.asddls
// Purpose: Consumption view of the KPI entity (TransactionKpi): per worklist date, company code and
//          direction - the payment worklist now (entries, FIN numbers, open, exceptions, in flight,
//          late, problems, requests open and not paid on their due date); tiles and overview-page
//          cards. Read access: DCL ZC_CD_TRXDASH (company code = GROUP BY key of ZR_CD_TrxKpi, so the
//          condition equals the one on the base rows). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Canonical outcome measures.
//                   2026-11-08 | Exceptions-only worklist measures.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard - KPI'
@Metadata.allowExtensions: true
define root view entity ZC_CD_TrxKpi
  provider contract transactional_query
  as projection on ZR_CD_TrxKpi
{
  key WorklistDate,
  key CompanyCode,
  key Direction,
      PaymentEngineArea,
      IsToday,
      @Aggregation.default: #SUM
      EntryCount,
      @Aggregation.default: #SUM
      FinCount,
      @Aggregation.default: #SUM
      OpenCount,
      @Aggregation.default: #SUM
      ExceptionCount,
      @Aggregation.default: #SUM
      InFlightCount,
      @Aggregation.default: #SUM
      LateCount,
      @Aggregation.default: #SUM
      ProblemCount,
      @Aggregation.default: #SUM
      RequestOpenCount,
      @Aggregation.default: #SUM
      RequestNotPaidCount,
      DayCriticality
}
