// UI annotations: ledger model - batch key level (entity SubledgerBatch; generated - never edit, regenerate)
// List (posting date mandatory) and object page: subledger total vs G/L total vs difference per account and currency,
// transfer status with criticality, the batch's journal lines and its subledger items (next levels, paged).
@Metadata.layer: #CORE
@UI.headerInfo: { typeName: 'Subledger batch key', typeNamePlural: 'Subledger batch keys',
                  title: { type: #STANDARD, value: 'BatchKey' },
                  description: { type: #STANDARD, value: 'TransferStatus' } }
@UI.presentationVariant: [ { sortOrder: [ { by: 'StatusCriticality', direction: #ASC }, { by: 'BatchKey', direction: #ASC } ] } ]
@UI.selectionVariant: [ { qualifier: 'NotTransferred', text: 'Not transferred', filter: 'IsTransferred EQ ' },
                        { qualifier: 'Difference', text: 'Subledger and G/L differ', filter: 'TransferStatus EQ DIFFERENCE' } ]
annotate entity ZC_{{P}}_LedgBatch with
{
  @UI.facet: [ { id: 'Key', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Batch key', position: 10 },
               { id: 'Totals', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Totals', label: 'Subledger vs G/L', position: 20 },
               { id: 'Journal', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Journal', label: 'G/L journal lines', position: 30 },
               { id: 'Items', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Items', label: 'Subledger items and payments', position: 40 } ]
  @EndUserText.label: 'Batch key'
  @UI.selectionField: [ { position: 20 } ]
  @UI.lineItem: [ { position: 10, importance: #HIGH } ]
  @UI.identification: [ { position: 10 } ]
  BatchKey;
  @EndUserText.label: 'Company code'
  @UI.selectionField: [ { position: 30 } ]
  @UI.lineItem: [ { position: 20 } ]
  @UI.identification: [ { position: 20 } ]
  CompanyCode;
  @EndUserText.label: 'G/L account'
  @UI.selectionField: [ { position: 40 } ]
  @UI.lineItem: [ { position: 30, importance: #HIGH } ]
  @UI.identification: [ { position: 30 } ]
  GlAccount;
  @EndUserText.label: 'Currency'
  @UI.lineItem: [ { position: 40 } ]
  Currency;
  @UI.hidden: true
  OpsArea;
  @EndUserText.label: 'G/L reference key'
  @UI.identification: [ { position: 40 } ]
  GlReferenceKey;
  @EndUserText.label: 'Posting date'
  @UI.selectionField: [ { position: 10 } ]
  @Consumption.filter: { mandatory: true }
  @UI.lineItem: [ { position: 50 } ]
  @UI.identification: [ { position: 50 } ]
  PostingDate;
  @EndUserText.label: 'Key status (open / closed)'
  @UI.identification: [ { position: 60 } ]
  BatchStatus;
  @EndUserText.label: 'Subledger total'
  @UI.lineItem: [ { position: 60, importance: #HIGH } ]
  @UI.fieldGroup: [ { qualifier: 'Totals', position: 10 } ]
  SubledgerAmount;
  @EndUserText.label: 'Summary records'
  @UI.fieldGroup: [ { qualifier: 'Totals', position: 20 } ]
  SubledgerLineCount;
  @EndUserText.label: 'G/L total'
  @UI.lineItem: [ { position: 70, importance: #HIGH } ]
  @UI.fieldGroup: [ { qualifier: 'Totals', position: 30 } ]
  GlAmount;
  @EndUserText.label: 'G/L lines'
  @UI.fieldGroup: [ { qualifier: 'Totals', position: 40 } ]
  GlLineCount;
  @EndUserText.label: 'G/L documents'
  @UI.lineItem: [ { position: 90 } ]
  @UI.fieldGroup: [ { qualifier: 'Totals', position: 50 } ]
  GlDocumentCount;
  @EndUserText.label: 'Reversed G/L documents'
  @UI.fieldGroup: [ { qualifier: 'Totals', position: 60 } ]
  ReversedDocumentCount;
  @EndUserText.label: 'G/L fiscal year'
  @UI.fieldGroup: [ { qualifier: 'Totals', position: 70 } ]
  GlFiscalYear;
  @EndUserText.label: 'G/L document'
  @UI.fieldGroup: [ { qualifier: 'Totals', position: 80 } ]
  GlDocument;
  @EndUserText.label: 'Difference (subledger - G/L)'
  @UI.lineItem: [ { position: 80, importance: #HIGH, criticality: 'StatusCriticality' } ]
  @UI.fieldGroup: [ { qualifier: 'Totals', position: 90, criticality: 'StatusCriticality' } ]
  Difference;
  @EndUserText.label: 'Transfer status'
  @UI.selectionField: [ { position: 50 } ]
  @UI.lineItem: [ { position: 100, criticality: 'StatusCriticality' } ]
  @UI.identification: [ { position: 70, criticality: 'StatusCriticality' } ]
  TransferStatus;
  @EndUserText.label: 'Transferred to G/L'
  IsTransferred;
  @UI.hidden: true
  StatusCriticality;
  @EndUserText.label: 'Keys'
  KeyCount;
}
