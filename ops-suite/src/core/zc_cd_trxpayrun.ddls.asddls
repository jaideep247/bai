// Artifact: zc_cd_trxpayrun.ddls.asddls
// Purpose: Consumption view of the payment runs and their live status (service ZUI_CD_TRX_DASH): DPAYH rows of
//          45 days, chart by run date and status, drill-down target of a transaction.
//          Read access: DCL ZC_CD_TRXDASH (ZCD_OPS, ZCD_PE_AREA = CORE, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard - payment run'
@Metadata.allowExtensions: true
define root view entity ZC_CD_TrxPayRun
  provider contract transactional_query
  as projection on ZR_CD_TrxPayRun
{
  key RunDate,
  key RunId,
  key PaymentDocument,
      PaymentEngineArea,
      PaymentStatus,
      IsToday,
      @Aggregation.default: #SUM
      PaymentCount
}
