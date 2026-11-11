// Artifact: zr_ca_opsbrkitem.ddls.asddls
// Purpose: Lines of a clearing-account break group (drill-down of ZR_CA_OpsBrkGroup): the journal entry line (key of
//          I_JournalEntryItem: ledger, company code, year, document, line), posting / document date, document type,
//          debit / credit, amount and currency, reference type and reconciliation key, LATER (posted after the key
//          date: context that clears the group), the bucket and rule that explain the line and the evidence the rule
//          read through the link registry (linked object, its masked key, the value compared - e.g. the bank line
//          and its transaction code). Navigation to the released journal entry line. Read-only.
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
// VERIFY-ADT: association to the released view I_JournalEntryItem by its key (V136); its DCL is not evaluated here.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Clearing account break lines'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsBrkItem
  as select from    zca_ops_brkitm   as Itm
    inner join      zca_ops_brkrun   as Run on Run.snap_id = Itm.snap_id
    left outer join zca_ops_brkbkt   as Bkt on Bkt.bucket = Itm.bucket
  association [0..*] to I_JournalEntryItem as _JournalItem on  $projection.Ledger             = _JournalItem.Ledger
                                                           and $projection.CompanyCode        = _JournalItem.CompanyCode
                                                           and $projection.FiscalYear         = _JournalItem.FiscalYear
                                                           and $projection.AccountingDocument = _JournalItem.AccountingDocument
                                                           and $projection.LedgerGLLineItem   = _JournalItem.LedgerGLLineItem
{
  key Itm.snap_id                                           as SnapshotId,
  key Itm.group_no                                          as GroupNo,
  key Itm.item_no                                           as ItemNo,
      Run.area                                              as Area,
      Run.acct_id                                           as AccountId,
      Itm.ledger                                            as Ledger,
      Itm.bukrs                                             as CompanyCode,
      Itm.gjahr                                             as FiscalYear,
      Itm.belnr                                             as AccountingDocument,
      Itm.docln                                             as LedgerGLLineItem,
      Itm.posting_date                                      as PostingDate,
      Itm.document_date                                     as DocumentDate,
      Itm.doc_type                                          as DocumentType,
      Itm.debit_credit                                      as DebitCredit,
      Itm.amount                                            as Amount,
      Itm.currency                                          as Currency,
      Itm.ref_type                                          as ReferenceType,
      Itm.recon_key                                         as ReconKey,
      Itm.later                                             as IsLater,
      Itm.bucket                                            as Bucket,
      Bkt.description                                       as BucketText,
      Itm.rule_id                                           as RuleId,
      Itm.link_object                                       as LinkedObject,
      Itm.link_key                                          as LinkedKey,
      Itm.link_value                                        as LinkedValue,
      _JournalItem
}
