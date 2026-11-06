// Artifact: zc_cd_trxkpi.ddls.asddls
// Purpose: Consumption view of the transactions KPI entity (tiles, overview-page cards, service ZUI_CD_TRX_DASH):
//          funnel counts per posting date, company code and direction, live.
//          Read access: DCL ZC_CD_TRXDASH (ZCD_OPS, ZCD_PE_AREA = CORE and BUKRS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
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
      PostedBucketCount,
      @Aggregation.default: #SUM
      ClearedBucketCount,
      @Aggregation.default: #SUM
      PaidBucketCount,
      @Aggregation.default: #SUM
      SettledBucketCount,
      DayCriticality
}
