// Artifact: zr_{{p}}_paymtrend.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - business-date trend: the daily totals per category and currency
//          (ZI_{{P}}_PaymTrendB) next to the same weekday of the previous week (same category, same currency;
//          a category without payments last week shows 0), days ago (the trend cards select the last {{TREND}}
//          days) and the peak-day flag (day volume of the company code at least {{PEAK}}). Aggregated on the
//          database; one row per day and category reaches the UI, never a payment.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - business-date trend'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_PaymTrend
  as select from    ZI_{{P}}_PaymTrendB as Cur
    left outer join ZI_{{P}}_PaymTrendB as Prev on  Prev.CompareDate     = Cur.BusinessDate
                                                and Prev.CompanyCode     = Cur.CompanyCode
                                                and Prev.Flow            = Cur.Flow
                                                and Prev.Source          = Cur.Source
                                                and Prev.TransactionType = Cur.TransactionType
                                                and Prev.MethodClass     = Cur.MethodClass
                                                and Prev.PaymentStatus   = Cur.PaymentStatus
                                                and Prev.HouseBank       = Cur.HouseBank
                                                and Prev.Currency        = Cur.Currency
    left outer join ZI_{{P}}_PaymDay    as Day  on  Day.BusinessDate     = Cur.BusinessDate
                                                and Day.CompanyCode      = Cur.CompanyCode
{
  key Cur.BusinessDate,
  key Cur.CompanyCode,
  key Cur.Flow,
  key Cur.Source,
  key Cur.TransactionType,
  key Cur.MethodClass,
  key Cur.PaymentStatus,
  key Cur.HouseBank,
  key Cur.Currency,
      cast( '{{AREA}}' as abap.char( 16 ) )                 as OpsArea,
      dats_days_between( Cur.BusinessDate, $session.system_date ) as DaysAgo,
      cast( case when Day.DayCount >= {{PEAK}} then 'X' else ' ' end as abap_boolean ) as IsPeakDay,
      Cur.ItemCount,
      Cur.LateCount,
      cast( coalesce( Prev.ItemCount, 0 ) as abap.int4 )    as PrevWeekCount,
      @Semantics.amount.currencyCode: 'Currency'
      Cur.Amount,
      @Semantics.amount.currencyCode: 'Currency'
      Prev.Amount                                           as PrevWeekAmount
}
