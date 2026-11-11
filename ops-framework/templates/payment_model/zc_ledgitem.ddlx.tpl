// UI annotations: ledger model - subledger item (entity SubledgerItem; generated - never edit, regenerate)
// Items table (payment ledger, batch key) and object page of one item: document / item, transactions with texts,
// contract account, masked partner, account, signed amount with currency, batch key, clearing; links up to the payment.
@Metadata.layer: #CORE
@UI.headerInfo: { typeName: 'Subledger item', typeNamePlural: 'Subledger items',
                  title: { type: #STANDARD, value: 'SubledgerDocument' },
                  description: { type: #STANDARD, value: 'MainTransactionText' } }
@UI.presentationVariant: [ { sortOrder: [ { by: 'SubledgerDocument', direction: #ASC }, { by: 'SubledgerItem', direction: #ASC } ] } ]
annotate entity ZC_{{P}}_LedgItem with
{
  @UI.facet: [ { id: 'Item', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Subledger item', position: 10 },
               { id: 'Clearing', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Clearing', label: 'Clearing and G/L', position: 20 } ]
  @EndUserText.label: 'Payment'
  @UI.lineItem: [ { position: 10 } ]
  @UI.identification: [ { position: 10 } ]
  PaymentDocument;
  @EndUserText.label: 'Subledger document'
  @UI.lineItem: [ { position: 20, importance: #HIGH } ]
  @UI.identification: [ { position: 20 } ]
  SubledgerDocument;
  @EndUserText.label: 'Item'
  @UI.lineItem: [ { position: 30 } ]
  @UI.identification: [ { position: 30 } ]
  SubledgerItem;
  @UI.hidden: true
  OpsArea;
  @EndUserText.label: 'Company code'
  @UI.identification: [ { position: 40 } ]
  CompanyCode;
  @EndUserText.label: 'Batch key'
  @UI.lineItem: [ { position: 40 } ]
  @UI.fieldGroup: [ { qualifier: 'Clearing', position: 10 } ]
  BatchKey;
  @EndUserText.label: 'G/L account'
  @UI.lineItem: [ { position: 50 } ]
  @UI.fieldGroup: [ { qualifier: 'Clearing', position: 20 } ]
  GlAccount;
  @EndUserText.label: 'Currency'
  Currency;
  @EndUserText.label: 'Amount (signed)'
  @UI.lineItem: [ { position: 60, importance: #HIGH } ]
  @UI.identification: [ { position: 50 } ]
  Amount;
  @EndUserText.label: 'Posting date'
  @UI.lineItem: [ { position: 70 } ]
  @UI.identification: [ { position: 60 } ]
  PostingDate;
  @EndUserText.label: 'Main transaction'
  @UI.lineItem: [ { position: 80 } ]
  @UI.identification: [ { position: 70 } ]
  MainTransaction;
  @EndUserText.label: 'Main transaction'
  MainTransactionText;
  @EndUserText.label: 'Sub-transaction'
  @UI.lineItem: [ { position: 90 } ]
  @UI.identification: [ { position: 80 } ]
  SubTransaction;
  @EndUserText.label: 'Sub-transaction'
  SubTransactionText;
  @EndUserText.label: 'Contract account'
  @UI.identification: [ { position: 90 } ]
  ContractAccount;
  @EndUserText.label: 'Business partner (masked)'
  @UI.identification: [ { position: 100 } ]
  BusinessPartnerMasked;
  @EndUserText.label: 'Clearing document'
  @UI.fieldGroup: [ { qualifier: 'Clearing', position: 30 } ]
  ClearingDocument;
  @EndUserText.label: 'Clearing date'
  @UI.fieldGroup: [ { qualifier: 'Clearing', position: 40 } ]
  ClearingDate;
  @EndUserText.label: 'Clearing reason'
  @UI.fieldGroup: [ { qualifier: 'Clearing', position: 50 } ]
  ClearingReason;
  @EndUserText.label: 'Request'
  @UI.lineItem: [ { position: 100 } ]
  @UI.identification: [ { position: 110 } ]
  RequestReference;
  @EndUserText.label: 'Items'
  ItemCount;
}
