// UI annotations: ledger model - journal line (entity JournalLine; generated - never edit, regenerate)
// Line table of every ledger page and the object page of one line: document and line, dates, account with text,
// posting key, debit / credit, the three amounts each with its currency, assignment, text, clearing, profit center,
// segment, business area, cost center, reference, reversal. VERIFY-ADT: rendering of the three amount columns.
@Metadata.layer: #CORE
@UI.headerInfo: { typeName: 'Journal line', typeNamePlural: 'Journal lines',
                  title: { type: #STANDARD, value: 'GlDocument' },
                  description: { type: #STANDARD, value: 'GlAccountText' } }
@UI.presentationVariant: [ { sortOrder: [ { by: 'PostingDate', direction: #DESC }, { by: 'GlDocument', direction: #ASC },
                                          { by: 'JournalLine', direction: #ASC } ] } ]
annotate entity ZC_{{P}}_LedgJrnl with
{
  @UI.facet: [ { id: 'Document', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Document', position: 10 },
               { id: 'Account', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Account', label: 'Account and amounts', position: 20 },
               { id: 'Assignment', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Assignment', label: 'Assignment and clearing', position: 30 } ]
  @EndUserText.label: 'Ledger'
  @UI.identification: [ { position: 10 } ]
  Ledger;
  @EndUserText.label: 'Company code'
  @UI.lineItem: [ { position: 10 } ]
  @UI.identification: [ { position: 20 } ]
  CompanyCode;
  @EndUserText.label: 'Fiscal year'
  @UI.identification: [ { position: 30 } ]
  FiscalYear;
  @EndUserText.label: 'G/L document'
  @UI.lineItem: [ { position: 20, importance: #HIGH } ]
  @UI.identification: [ { position: 40 } ]
  GlDocument;
  @EndUserText.label: 'Journal line'
  @UI.lineItem: [ { position: 30 } ]
  @UI.identification: [ { position: 50 } ]
  JournalLine;
  @UI.hidden: true
  OpsArea;
  @EndUserText.label: 'Line item (entry view)'
  @UI.identification: [ { position: 60 } ]
  GlLineItem;
  @EndUserText.label: 'Fiscal period'
  @UI.identification: [ { position: 70 } ]
  FiscalPeriod;
  @EndUserText.label: 'Document type'
  @UI.lineItem: [ { position: 40 } ]
  @UI.identification: [ { position: 80 } ]
  DocumentType;
  @EndUserText.label: 'Posting date'
  @UI.lineItem: [ { position: 50, importance: #HIGH } ]
  @UI.identification: [ { position: 90 } ]
  PostingDate;
  @EndUserText.label: 'Document date'
  @UI.identification: [ { position: 100 } ]
  DocumentDate;
  @EndUserText.label: 'Entry date'
  @UI.identification: [ { position: 110 } ]
  EntryDate;
  @EndUserText.label: 'Entry time'
  @UI.identification: [ { position: 120 } ]
  EntryTime;
  @EndUserText.label: 'G/L account'
  @UI.lineItem: [ { position: 60, importance: #HIGH } ]
  @UI.fieldGroup: [ { qualifier: 'Account', position: 10 } ]
  GlAccount;
  @EndUserText.label: 'G/L account text'
  GlAccountText;
  @EndUserText.label: 'Posting key'
  @UI.lineItem: [ { position: 70 } ]
  @UI.fieldGroup: [ { qualifier: 'Account', position: 20 } ]
  PostingKey;
  @EndUserText.label: 'Debit / credit'
  @UI.lineItem: [ { position: 80 } ]
  @UI.fieldGroup: [ { qualifier: 'Account', position: 30 } ]
  DebitCredit;
  @EndUserText.label: 'Amount (transaction currency)'
  @UI.lineItem: [ { position: 90, importance: #HIGH } ]
  @UI.fieldGroup: [ { qualifier: 'Account', position: 40 } ]
  AmountInTransCurrency;
  @EndUserText.label: 'Transaction currency'
  TransactionCurrency;
  @EndUserText.label: 'Amount (company code currency)'
  @UI.lineItem: [ { position: 100 } ]
  @UI.fieldGroup: [ { qualifier: 'Account', position: 50 } ]
  AmountInCompanyCurrency;
  @EndUserText.label: 'Company code currency'
  CompanyCodeCurrency;
  @EndUserText.label: 'Amount (group currency)'
  @UI.fieldGroup: [ { qualifier: 'Account', position: 60 } ]
  AmountInGroupCurrency;
  @EndUserText.label: 'Group currency'
  GroupCurrency;
  @EndUserText.label: 'Assignment'
  @UI.lineItem: [ { position: 110 } ]
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 10 } ]
  Assignment;
  @EndUserText.label: 'Item text'
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 20 } ]
  ItemText;
  @EndUserText.label: 'Clearing document'
  @UI.lineItem: [ { position: 120 } ]
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 30 } ]
  ClearingDocument;
  @EndUserText.label: 'Clearing date'
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 40 } ]
  ClearingDate;
  @EndUserText.label: 'Profit center'
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 50 } ]
  ProfitCenter;
  @EndUserText.label: 'Segment'
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 60 } ]
  Segment;
  @EndUserText.label: 'Business area'
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 70 } ]
  BusinessArea;
  @EndUserText.label: 'Cost center'
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 80 } ]
  CostCenter;
  @EndUserText.label: 'Reference type'
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 90 } ]
  ReferenceType;
  @EndUserText.label: 'Reference key'
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 100 } ]
  ReferenceKey;
  @EndUserText.label: 'Reversed by / reverses'
  @UI.fieldGroup: [ { qualifier: 'Assignment', position: 110 } ]
  ReversalDocument;
  @EndUserText.label: 'Reversal'
  @UI.lineItem: [ { position: 130 } ]
  IsReversal;
  @EndUserText.label: 'Transfer of a batch key'
  @UI.lineItem: [ { position: 140 } ]
  IsTransferLine;
}
