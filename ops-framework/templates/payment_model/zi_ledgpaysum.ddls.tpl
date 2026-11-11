// Artifact: zi_{{p}}_ledgpaysum.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - a payment's subledger amount per batch key, company code, G/L account
//          and currency (sum of the items it cleared, signed as the adapter delivers them; never across currencies).
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - payment amount per batch key'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_{{P}}_LedgPaySum
  as select from ZI_{{P}}_LedgItem as Itm
{
  key Itm.PaymentDocument,
  key Itm.BatchKey,
  key Itm.CompanyCode,
  key Itm.GlAccount,
  key Itm.Currency,
      @Semantics.amount.currencyCode: 'Currency'
      sum( Itm.Amount )                                     as PaymentAmount,
      cast( count( * ) as abap.int4 )                       as ItemCount
}
group by
  Itm.PaymentDocument,
  Itm.BatchKey,
  Itm.CompanyCode,
  Itm.GlAccount,
  Itm.Currency
