// Artifact: zi_cd_ledggltot.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - G/L total of a subledger batch key per company code, G/L account and
//          transaction currency: the journal lines (ZI_CD_LedgJrnl, read by the journal's primary key of each G/L
//          document of the key) of the G/L documents that are not reversed; reversal lines are left out. Never summed
//          across currencies (the currency is a key). The amount carries the journal's sign (WSL).
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - G/L total per batch key'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgGlTot
  as select from ZI_CD_LedgGlDoc as Doc
    inner join   ZI_CD_LedgJrnl  as Jrn on  Jrn.CompanyCode = Doc.CompanyCode
                                           and Jrn.FiscalYear  = Doc.FiscalYear
                                           and Jrn.GlDocument  = Doc.GlDocument
{
  key Doc.BatchKey,
  key Doc.CompanyCode,
  key Jrn.GlAccount,
  key Jrn.TransactionCurrency                               as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      sum( Jrn.AmountInTransCurrency )                      as GlAmount,
      cast( count( * ) as abap.int4 )                       as GlLineCount
}
where
      Doc.IsReversed = ' '
  and Jrn.IsReversal = ' '
group by
  Doc.BatchKey,
  Doc.CompanyCode,
  Jrn.GlAccount,
  Jrn.TransactionCurrency
