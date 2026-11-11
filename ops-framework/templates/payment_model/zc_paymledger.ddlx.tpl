// UI annotations: ledger model - payment ledger (entity PaymentLedger; generated - never edit, regenerate)
// Table of the "Ledger" facet of the payment object page and the object page of one row: the payment's amount, its
// share of the batch summary, the batch's G/L total and documents, transfer status; next levels journal lines and
// items. The G/L amount is the batch's (consolidated) - labelled so, with the pro-rata share next to it.
@Metadata.layer: #CORE
@UI.headerInfo: { typeName: 'Ledger entry of the payment', typeNamePlural: 'Ledger',
                  title: { type: #STANDARD, value: 'BatchKey' },
                  description: { type: #STANDARD, value: 'GlAccount' } }
@UI.presentationVariant: [ { sortOrder: [ { by: 'BatchKey', direction: #ASC }, { by: 'GlAccount', direction: #ASC } ] } ]
annotate entity ZC_{{P}}_PaymLedger with
{
  @UI.facet: [ { id: 'Share', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Share of the batch summary', position: 10 },
               { id: 'Journal', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Journal', label: 'G/L journal lines of the batch (account)', position: 20 },
               { id: 'Items', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Items', label: 'Subledger items of the payment', position: 30 } ]
  @EndUserText.label: 'Payment'
  @UI.identification: [ { position: 10 } ]
  PaymentDocument;
  @EndUserText.label: 'Batch key'
  @UI.lineItem: [ { position: 10, importance: #HIGH } ]
  @UI.identification: [ { position: 20 } ]
  BatchKey;
  @EndUserText.label: 'Company code'
  @UI.identification: [ { position: 30 } ]
  CompanyCode;
  @EndUserText.label: 'G/L account'
  @UI.lineItem: [ { position: 20, importance: #HIGH } ]
  @UI.identification: [ { position: 40 } ]
  GlAccount;
  @EndUserText.label: 'Currency'
  @UI.lineItem: [ { position: 30 } ]
  Currency;
  @UI.hidden: true
  OpsArea;
  @EndUserText.label: 'Payment amount (subledger)'
  @UI.lineItem: [ { position: 40, importance: #HIGH } ]
  @UI.identification: [ { position: 50 } ]
  PaymentAmount;
  @EndUserText.label: 'Items'
  @UI.identification: [ { position: 60 } ]
  ItemCount;
  @EndUserText.label: 'G/L reference key'
  @UI.identification: [ { position: 70 } ]
  GlReferenceKey;
  @EndUserText.label: 'Batch posting date'
  @UI.lineItem: [ { position: 50 } ]
  @UI.identification: [ { position: 80 } ]
  BatchPostingDate;
  @EndUserText.label: 'Batch status'
  @UI.identification: [ { position: 90 } ]
  BatchStatus;
  @EndUserText.label: 'Batch total (subledger summary)'
  @UI.lineItem: [ { position: 60 } ]
  @UI.identification: [ { position: 100 } ]
  BatchAmount;
  @EndUserText.label: 'Batch total in G/L (consolidated)'
  @UI.lineItem: [ { position: 70 } ]
  @UI.identification: [ { position: 110 } ]
  GlAmount;
  @EndUserText.label: 'G/L documents'
  @UI.identification: [ { position: 120 } ]
  GlDocumentCount;
  @EndUserText.label: 'G/L fiscal year'
  @UI.identification: [ { position: 130 } ]
  GlFiscalYear;
  @EndUserText.label: 'G/L document'
  @UI.lineItem: [ { position: 80 } ]
  @UI.identification: [ { position: 140 } ]
  GlDocument;
  @EndUserText.label: 'Share of the batch (%)'
  @UI.lineItem: [ { position: 90, importance: #HIGH } ]
  @UI.identification: [ { position: 150 } ]
  SharePercent;
  @EndUserText.label: 'Pro-rata G/L amount (share, not a G/L line)'
  @UI.lineItem: [ { position: 100 } ]
  @UI.identification: [ { position: 160 } ]
  ProRataGlAmount;
  @EndUserText.label: 'Batch difference (subledger - G/L)'
  @UI.identification: [ { position: 170, criticality: 'StatusCriticality' } ]
  BatchDifference;
  @EndUserText.label: 'Transfer status'
  @UI.lineItem: [ { position: 110, criticality: 'StatusCriticality' } ]
  @UI.identification: [ { position: 180, criticality: 'StatusCriticality' } ]
  TransferStatus;
  @UI.hidden: true
  StatusCriticality;
}
