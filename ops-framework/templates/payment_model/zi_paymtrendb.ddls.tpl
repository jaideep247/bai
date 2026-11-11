// Artifact: zi_{{p}}_paymtrendb.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - daily totals behind the business-date trend: per business date,
//          company code, flow, source, transaction, method class, payment status, house bank and currency -
//          count, late count and amount; CompareDate = the business date one week later (the row is the "same
//          weekday last week" of that date). Aggregated on the database from the adapter ZI_{{P}}_PaymFact.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - daily totals (trend)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_{{P}}_PaymTrendB
  as select from ZI_{{P}}_PaymFact as Fact
{
  key Fact.BusinessDate,
  key Fact.CompanyCode,
  key Fact.Flow,
  key Fact.Source,
  key Fact.TransactionType,
  key Fact.MethodClass,
  key Fact.PaymentStatus,
  key Fact.HouseBank,
  key Fact.Currency,
      dats_add_days( Fact.BusinessDate, 7, 'INITIAL' )      as CompareDate,
      cast( count( * ) as abap.int4 )                       as ItemCount,
      cast( sum( case when Fact.IsLate = 'X' then 1 else 0 end ) as abap.int4 ) as LateCount,
      @Semantics.amount.currencyCode: 'Currency'
      sum( Fact.Amount )                                    as Amount
}
group by
  Fact.BusinessDate,
  Fact.CompanyCode,
  Fact.Flow,
  Fact.Source,
  Fact.TransactionType,
  Fact.MethodClass,
  Fact.PaymentStatus,
  Fact.HouseBank,
  Fact.Currency
