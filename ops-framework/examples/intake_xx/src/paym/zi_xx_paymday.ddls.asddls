// Artifact: zi_xx_paymday.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the example customer XX (intake) - payments per business date and company code (all categories):
//          the day volume that marks a peak day on the trend (at least 100000 payments in the company code).
// Modification log: 2026-11-16 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - payments per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_XX_PaymDay
  as select from ZI_XX_PaymFact as Fact
{
  key Fact.BusinessDate,
  key Fact.CompanyCode,
      cast( count( * ) as abap.int4 )                       as DayCount
}
group by
  Fact.BusinessDate,
  Fact.CompanyCode
