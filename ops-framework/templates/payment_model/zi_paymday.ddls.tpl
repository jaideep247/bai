// Artifact: zi_{{p}}_paymday.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - payments per business date and company code (all categories):
//          the day volume that marks a peak day on the trend (at least {{PEAK}} payments in the company code).
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - payments per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_{{P}}_PaymDay
  as select from ZI_{{P}}_PaymFact as Fact
{
  key Fact.BusinessDate,
  key Fact.CompanyCode,
      cast( count( * ) as abap.int4 )                       as DayCount
}
group by
  Fact.BusinessDate,
  Fact.CompanyCode
