// Artifact: zr_cd_ledgitem.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - subledger item cleared by a payment (entity SubledgerItem): subledger
//          document / item, posting date, main / sub transaction with texts, contract account, business partner masked
//          to its last four characters (a reconciler needs the item, not the person), G/L account, signed amount with
//          its currency, the batch key under which the clearing reached the G/L, clearing document / date / reason and
//          the request reference. Navigation up to the payment (_Payment) and the batch key (_Batch). Read by key
//          (payment document or batch key) through the navigations - never a scan of the subledger. Read-only.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
// VERIFY-ADT: right( ) / concat( ) on a CHAR 20 partner (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - subledger item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_LedgItem
  as select from ZI_CD_LedgItem as Itm
  association [0..*] to ZR_CD_Payment   as _Payment on  $projection.PaymentDocument = _Payment.PaymentDocument
  association [0..1] to ZR_CD_LedgBatch as _Batch   on  $projection.BatchKey    = _Batch.BatchKey
                                                       and $projection.CompanyCode = _Batch.CompanyCode
                                                       and $projection.GlAccount   = _Batch.GlAccount
                                                       and $projection.Currency    = _Batch.Currency
{
  key Itm.PaymentDocument,
  key Itm.SubledgerDocument,
  key Itm.SubledgerItem,
      _Payment,
      _Batch,
      cast( 'CD_OPS' as abap.char( 16 ) )                 as OpsArea,
      Itm.CompanyCode,
      Itm.BatchKey,
      Itm.GlAccount,
      Itm.Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Itm.Amount,
      Itm.PostingDate,
      Itm.MainTransaction,
      Itm.MainTransactionText,
      Itm.SubTransaction,
      Itm.SubTransactionText,
      Itm.ContractAccount,
      cast( case when Itm.BusinessPartner = '' then ''
                 else concat( '****', right( Itm.BusinessPartner, 4 ) ) end as abap.char( 20 ) ) as BusinessPartnerMasked,
      Itm.ClearingDocument,
      Itm.ClearingDate,
      Itm.ClearingReason,
      Itm.RequestReference,
      cast( 1 as abap.int4 )                                as ItemCount
}
