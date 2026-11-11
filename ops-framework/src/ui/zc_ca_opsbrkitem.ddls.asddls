// Artifact: zc_ca_opsbrkitem.ddls.asddls
// Purpose: Consumption view of the lines of a clearing-account break (object page table of "Clearing account breaks",
//          service ZUI_CA_OPS_BRK): journal entry line, dates, amount and currency, reconciliation key, bucket and rule,
//          the linked object the rule read (masked key, value). Read access: DCL ZC_CA_OPSBRKITEM. Read-only.
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Clearing account break lines'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsBrkItem
  provider contract transactional_query
  as projection on ZR_CA_OpsBrkItem
{
  key SnapshotId,
  key GroupNo,
  key ItemNo,
      Area,
      AccountId,
      Ledger,
      CompanyCode,
      FiscalYear,
      AccountingDocument,
      LedgerGLLineItem,
      PostingDate,
      DocumentDate,
      DocumentType,
      DebitCredit,
      Amount,
      Currency,
      ReferenceType,
      ReconKey,
      IsLater,
      @ObjectModel.text.element: [ 'BucketText' ]
      Bucket,
      BucketText,
      RuleId,
      LinkedObject,
      LinkedKey,
      LinkedValue
}
