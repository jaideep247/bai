// Artifact: zi_{{p}}_ledgglkey.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - per subledger batch key and company code: how many G/L documents it has
//          (not reversed / reversed) and the first one that is not reversed (fiscal year, document) - the transfer
//          status of the batch key level (a key without an unreversed G/L document is not transferred).
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - G/L documents per batch key'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_{{P}}_LedgGlKey
  as select from ZI_{{P}}_LedgGlDoc as Doc
{
  key Doc.BatchKey,
  key Doc.CompanyCode,
      cast( sum( case when Doc.IsReversed = ' ' then 1 else 0 end ) as abap.int4 ) as ActiveDocumentCount,
      cast( sum( case when Doc.IsReversed = 'X' then 1 else 0 end ) as abap.int4 ) as ReversedDocumentCount,
      min( case when Doc.IsReversed = ' ' then Doc.FiscalYear end )          as FirstFiscalYear,
      min( case when Doc.IsReversed = ' ' then Doc.GlDocument end )          as FirstGlDocument
}
group by
  Doc.BatchKey,
  Doc.CompanyCode
