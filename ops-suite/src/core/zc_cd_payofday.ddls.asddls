// Artifact: zc_cd_payofday.ddls.asddls
// Purpose: Consumption view of the payments of a business date ("View payments" of the payment lifecycle
//          card, entity PaymentOfDay): payment reference, source, company code, method, status, stage,
//          amount - the payment document opens the payment trace. Read access: DCL ZC_CD_OPSOVERVIEW (area
//          CD_OPS and the company code of the payment). Read-only.
// Modification log: 2026-11-10 | Initial version (control center: payment lifecycle list).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Production support - payments of a date'
@Metadata.allowExtensions: true
define root view entity ZC_CD_PayOfDay
  provider contract transactional_query
  as projection on ZR_CD_PayOfDay
{
  key BusinessDate,
  key RunId,
      @Consumption.semanticObject: 'ZCDPaymentTrace'
  key PaymentDocument,
      CompanyCode,
      PaymentEngineArea,
      SourceSystem,
      PaymentMethod,
      HouseBank,
      PaymentStatus,
      Stage,
      StageLabel,
      Currency,
      @Aggregation.default: #SUM
      Amount,
      IsCurrentDay,
      @Aggregation.default: #SUM
      PaymentCount
}
