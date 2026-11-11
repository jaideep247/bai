// Artifact: zi_cd_paymday.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - payments per business date and company code (all categories):
//          the day volume that marks a peak day on the trend (at least 1000000 payments in the company code).
// Modification log: 2026-11-11 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - payments per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PaymDay
  as select from ZI_CD_PaymFact as Fact
{
  key Fact.BusinessDate,
  key Fact.CompanyCode,
      cast( count( * ) as abap.int4 )                       as DayCount
}
group by
  Fact.BusinessDate,
  Fact.CompanyCode
