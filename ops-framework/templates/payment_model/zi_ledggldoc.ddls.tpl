// Artifact: zi_{{p}}_ledggldoc.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - the G/L documents of a subledger batch key: journal entry headers
//          (released view I_JournalEntry) of the same company code whose reference type is {{GL_REFTYPE}} and whose
//          reference key is the batch's G/L reference key (adapter ZI_{{P}}_LedgBatch) - the header index on reference
//          type + key under the released view, never a search of the journal. A reversed G/L document (or a reversal
//          document of the same reference) is listed with IsReversed; the totals leave it out.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
//                   2026-11-11 | Released view I_JournalEntry instead of the document header table; element names
//                              | unchanged.
// VERIFY-ADT (VERIFY.md V110): I_JournalEntry C1; elements CompanyCode, FiscalYear, AccountingDocument,
//          ReferenceDocumentType, OriginalReferenceDocument (the full reference key), AccountingDocumentType,
//          PostingDate, AccountingDocumentCreationDate, CreationTime, ReverseDocument, ReverseDocumentFiscalYear.
//          PlanViz V113: the reference type + key predicate reaches the header's reference index through the view.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - G/L documents of a batch key'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_{{P}}_LedgGlDoc
  as select distinct from ZI_{{P}}_LedgBatch as Bat
    inner join            I_JournalEntry     as Doc on  Doc.ReferenceDocumentType     = '{{GL_REFTYPE}}'
                                                    and Doc.OriginalReferenceDocument = Bat.GlReferenceKey
                                                    and Doc.CompanyCode               = Bat.CompanyCode
{
  key Bat.BatchKey,
  key Bat.CompanyCode,
  key Doc.FiscalYear                                        as FiscalYear,
  key Doc.AccountingDocument                                as GlDocument,
      Bat.GlReferenceKey,
      Doc.AccountingDocumentType                            as DocumentType,
      Doc.PostingDate                                       as PostingDate,
      Doc.AccountingDocumentCreationDate                    as EntryDate,
      Doc.CreationTime                                      as EntryTime,
      Doc.ReverseDocument                                   as ReversalDocument,
      Doc.ReverseDocumentFiscalYear                         as ReversalYear,
      cast( case when Doc.ReverseDocument = '' then ' ' else 'X' end as abap_boolean ) as IsReversed
}
