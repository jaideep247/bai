// Artifact: zr_{{p}}_ledgbatch.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - the subledger batch key as a first-class level (entity
//          SubledgerBatch): per batch key, company code, G/L account and currency the posting date, the batch status
//          the consumer delivers (blank until its field is confirmed), the subledger total of the summary records vs the
//          G/L total of the batch's G/L documents that are not reversed, the difference and the transfer status:
//          NOT_TRANSFERRED (no unreversed G/L document), DIFFERENCE (subledger total <> G/L total on the account),
//          TRANSFERRED. The amounts carry the signs the adapters deliver (consumer's mapping notes). Drill-down: the
//          batch's journal lines (_Journal), its subledger items with their payments (_Items). This view shows the
//          status; the consumer's own check reports keys that are not transferred (no second check here). Read-only.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
// VERIFY-ADT: DEC arithmetic of CURR operands (subledger minus G/L) and coalesce of a CURR with a cast literal (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - batch key level'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_LedgBatch
  as select from    ZI_{{P}}_LedgBatch  as Bat
    left outer join ZI_{{P}}_LedgGlTot  as Gl  on  Gl.BatchKey    = Bat.BatchKey
                                               and Gl.CompanyCode = Bat.CompanyCode
                                               and Gl.GlAccount   = Bat.GlAccount
                                               and Gl.Currency    = Bat.Currency
    left outer join ZI_{{P}}_LedgGlKey  as Key on  Key.BatchKey    = Bat.BatchKey
                                               and Key.CompanyCode = Bat.CompanyCode
  association [0..*] to ZR_{{P}}_LedgJrnl as _Journal on  $projection.CompanyCode    = _Journal.CompanyCode
                                                     and $projection.GlReferenceKey = _Journal.ReferenceKey
                                                     and _Journal.ReferenceType     = '{{GL_REFTYPE}}'
  association [0..*] to ZR_{{P}}_LedgItem as _Items   on  $projection.BatchKey    = _Items.BatchKey
                                                     and $projection.CompanyCode = _Items.CompanyCode
                                                     and $projection.GlAccount   = _Items.GlAccount
                                                     and $projection.Currency    = _Items.Currency
{
  key Bat.BatchKey,
  key Bat.CompanyCode,
  key Bat.GlAccount,
  key Bat.Currency,
      _Journal,
      _Items,
      cast( '{{AREA}}' as abap.char( 16 ) )                 as OpsArea,
      Bat.GlReferenceKey,
      Bat.PostingDate,
      Bat.BatchStatus,
      @Semantics.amount.currencyCode: 'Currency'
      Bat.Amount                                            as SubledgerAmount,
      Bat.LineCount                                         as SubledgerLineCount,
      @Semantics.amount.currencyCode: 'Currency'
      coalesce( Gl.GlAmount, cast( 0 as abap.curr( 23, 2 ) ) ) as GlAmount,
      coalesce( Gl.GlLineCount, 0 )                         as GlLineCount,
      coalesce( Key.ActiveDocumentCount, 0 )                as GlDocumentCount,
      coalesce( Key.ReversedDocumentCount, 0 )              as ReversedDocumentCount,
      Key.FirstFiscalYear                                   as GlFiscalYear,
      Key.FirstGlDocument                                   as GlDocument,
      cast( cast( Bat.Amount as abap.dec( 23, 2 ) )
          - cast( coalesce( Gl.GlAmount, cast( 0 as abap.curr( 23, 2 ) ) ) as abap.dec( 23, 2 ) )
            as abap.dec( 23, 2 ) )                          as Difference,
      cast( case when coalesce( Key.ActiveDocumentCount, 0 ) = 0 then 'NOT_TRANSFERRED'
                 when cast( Bat.Amount as abap.dec( 23, 2 ) )
                   <> cast( coalesce( Gl.GlAmount, cast( 0 as abap.curr( 23, 2 ) ) ) as abap.dec( 23, 2 ) )
                 then 'DIFFERENCE'
                 else 'TRANSFERRED' end as abap.char( 16 ) )  as TransferStatus,
      cast( case when coalesce( Key.ActiveDocumentCount, 0 ) = 0 then ' ' else 'X' end as abap_boolean ) as IsTransferred,
      cast( case when coalesce( Key.ActiveDocumentCount, 0 ) = 0 then 2
                 when cast( Bat.Amount as abap.dec( 23, 2 ) )
                   <> cast( coalesce( Gl.GlAmount, cast( 0 as abap.curr( 23, 2 ) ) ) as abap.dec( 23, 2 ) )
                 then 1
                 else 3 end as abap.int1 )                  as StatusCriticality,
      cast( 1 as abap.int4 )                                as KeyCount
}
