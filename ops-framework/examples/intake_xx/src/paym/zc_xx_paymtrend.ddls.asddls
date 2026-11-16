// Artifact: zc_xx_paymtrend.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the example customer XX (intake) - business-date trend (entity PaymentTrend of ZUI_XX_PAYM): daily
//          volume, late payments and amount per currency by category, same weekday last week, peak days.
//          Read access: DCL ZC_XX_PAYM. Read-only.
// Modification log: 2026-11-16 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - business-date trend'
@Metadata.allowExtensions: true
define root view entity ZC_XX_PaymTrend
  provider contract transactional_query
  as projection on ZR_XX_PaymTrend
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
