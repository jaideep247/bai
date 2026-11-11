// Artifact: zc_{{p}}_paymtrend.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - business-date trend (entity PaymentTrend of {{SERVICE}}): daily
//          volume, late payments and amount per currency by category, same weekday last week, peak days.
//          Read access: DCL ZC_{{P}}_PAYM. Read-only.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - business-date trend'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_PaymTrend
  provider contract transactional_query
  as projection on ZR_{{P}}_PaymTrend
{
  key BusinessDate,
  key CompanyCode,
  key Flow,
  key Source,
  key TransactionType,
  key MethodClass,
  key PaymentStatus,
  key HouseBank,
  key Currency,
      OpsArea,
      DaysAgo,
      IsPeakDay,
      @Aggregation.default: #SUM
      ItemCount,
      @Aggregation.default: #SUM
      LateCount,
      @Aggregation.default: #SUM
      PrevWeekCount,
      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'Currency'
      Amount,
      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'Currency'
      PrevWeekAmount
}
