// Artifact: zr_{{p}}_paymledger.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - the "Ledger" facet of a payment (entity PaymentLedger): per batch key,
//          company code, G/L account and currency the payment's subledger amount, the batch's subledger total
//          (summary records), its G/L total (G/L documents not reversed), the payment's SHARE of the summary (payment
//          amount / batch total, percent) and the pro-rata G/L amount (share x G/L total) - the G/L receives consolidated
//          amounts per account and batch key, so the page never shows a G/L line as if it were the payment's own; the
//          journal lines of the batch on that account and the payment's items are the next level. Read by payment
//          document (navigation from the payment). Read-only.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
// VERIFY-ADT: division( ) of DEC operands and the DEC 15,2 product in a view entity (7.58); a batch total of 0 gives
//             share 0 (no division by zero).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - payment ledger'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_PaymLedger
  as select from    ZI_{{P}}_LedgPaySum as Pay
    left outer join ZI_{{P}}_LedgBatch  as Bat on  Bat.BatchKey    = Pay.BatchKey
                                               and Bat.CompanyCode = Pay.CompanyCode
                                               and Bat.GlAccount   = Pay.GlAccount
                                               and Bat.Currency    = Pay.Currency
    left outer join ZI_{{P}}_LedgGlTot  as Gl  on  Gl.BatchKey    = Pay.BatchKey
                                               and Gl.CompanyCode = Pay.CompanyCode
                                               and Gl.GlAccount   = Pay.GlAccount
                                               and Gl.Currency    = Pay.Currency
    left outer join ZI_{{P}}_LedgGlKey  as Key on  Key.BatchKey    = Pay.BatchKey
                                               and Key.CompanyCode = Pay.CompanyCode
  association [0..*] to ZR_{{P}}_LedgJrnl as _Journal on  $projection.CompanyCode    = _Journal.CompanyCode
                                                     and $projection.GlReferenceKey = _Journal.ReferenceKey
                                                     and $projection.GlAccount      = _Journal.GlAccount
                                                     and _Journal.ReferenceType     = '{{GL_REFTYPE}}'
  association [0..*] to ZR_{{P}}_LedgItem as _Items   on  $projection.PaymentDocument = _Items.PaymentDocument
                                                     and $projection.BatchKey        = _Items.BatchKey
                                                     and $projection.GlAccount       = _Items.GlAccount
                                                     and $projection.Currency        = _Items.Currency
{
  key Pay.PaymentDocument,
  key Pay.BatchKey,
  key Pay.CompanyCode,
  key Pay.GlAccount,
  key Pay.Currency,
      _Journal,
      _Items,
      cast( '{{AREA}}' as abap.char( 16 ) )                 as OpsArea,
      @Semantics.amount.currencyCode: 'Currency'
      Pay.PaymentAmount,
      Pay.ItemCount,
      Bat.GlReferenceKey,
      Bat.PostingDate                                       as BatchPostingDate,
      Bat.BatchStatus,
      @Semantics.amount.currencyCode: 'Currency'
      Bat.Amount                                            as BatchAmount,
      @Semantics.amount.currencyCode: 'Currency'
      Gl.GlAmount,
      coalesce( Key.ActiveDocumentCount, 0 )                as GlDocumentCount,
      Key.FirstFiscalYear                                   as GlFiscalYear,
      Key.FirstGlDocument                                   as GlDocument,
      cast( case when Bat.Amount is null or Bat.Amount = 0 then 0
                 else division( cast( Pay.PaymentAmount as abap.dec( 15, 2 ) ) * 100,
                                cast( Bat.Amount as abap.dec( 15, 2 ) ), 4 ) end as abap.dec( 9, 4 ) ) as SharePercent,
      cast( case when Bat.Amount is null or Bat.Amount = 0 or Gl.GlAmount is null then 0
                 else division( cast( Pay.PaymentAmount as abap.dec( 15, 2 ) ) * cast( Gl.GlAmount as abap.dec( 15, 2 ) ),
                                cast( Bat.Amount as abap.dec( 15, 2 ) ), 2 ) end as abap.dec( 23, 2 ) ) as ProRataGlAmount,
      cast( cast( coalesce( Bat.Amount, cast( 0 as abap.curr( 23, 2 ) ) ) as abap.dec( 23, 2 ) )
          - cast( coalesce( Gl.GlAmount, cast( 0 as abap.curr( 23, 2 ) ) ) as abap.dec( 23, 2 ) )
            as abap.dec( 23, 2 ) )                          as BatchDifference,
      cast( case when coalesce( Key.ActiveDocumentCount, 0 ) = 0 then 'NOT_TRANSFERRED'
                 when cast( coalesce( Bat.Amount, cast( 0 as abap.curr( 23, 2 ) ) ) as abap.dec( 23, 2 ) )
                   <> cast( coalesce( Gl.GlAmount, cast( 0 as abap.curr( 23, 2 ) ) ) as abap.dec( 23, 2 ) )
                 then 'DIFFERENCE'
                 else 'TRANSFERRED' end as abap.char( 16 ) )  as TransferStatus,
      cast( case when coalesce( Key.ActiveDocumentCount, 0 ) = 0 then 2
                 when cast( coalesce( Bat.Amount, cast( 0 as abap.curr( 23, 2 ) ) ) as abap.dec( 23, 2 ) )
                   <> cast( coalesce( Gl.GlAmount, cast( 0 as abap.curr( 23, 2 ) ) ) as abap.dec( 23, 2 ) )
                 then 1
                 else 3 end as abap.int1 )                  as StatusCriticality
}
