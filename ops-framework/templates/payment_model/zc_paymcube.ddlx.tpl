// UI annotations: payment model - categorisation (entity PaymentCategory; generated - never edit, regenerate)
// Persona cards (docs of the consumer: overview pages Business / Managers / IT support). Qualifier prefix:
// Biz = business users (plain-language texts, no technical codes, amounts per currency), Mgr = managers (volume,
// on-time share by method class, company code, house bank), It = IT support (counts only - amounts on the
// drill-down, rule SHOW_AMOUNTS of the alert e-mails). Every amount chart groups by Currency.
// VERIFY-ADT: OVP V4 analytical cards with two dimensions and a currency dimension; selection variants with
// boolean filters (as the control center cards).
@Metadata.layer: #CORE
@UI.headerInfo: { typeName: 'Payment category', typeNamePlural: 'Payments by category',
                  title: { type: #STANDARD, value: 'SourceText' } }
@UI.chart: [ { qualifier: 'BizBySourceStatus', title: 'Payments by source and payment status',
               chartType: #COLUMN_STACKED, dimensions: [ 'Source', 'PaymentStatus' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'Source', role: #CATEGORY }, { dimension: 'PaymentStatus', role: #SERIES } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] },
             { qualifier: 'BizByClassStatus', title: 'Payments by payment type and payment status',
               chartType: #COLUMN_STACKED, dimensions: [ 'MethodClass', 'PaymentStatus' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'MethodClass', role: #CATEGORY }, { dimension: 'PaymentStatus', role: #SERIES } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] },
             { qualifier: 'BizBySourceClass', title: 'Payments by source and payment type',
               chartType: #COLUMN_STACKED, dimensions: [ 'Source', 'MethodClass' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'Source', role: #CATEGORY }, { dimension: 'MethodClass', role: #SERIES } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] },
             { qualifier: 'BizAmountBySource', title: 'Amount by source (per currency)',
               chartType: #BAR, dimensions: [ 'Source', 'Currency' ], measures: [ 'Amount' ],
               dimensionAttributes: [ { dimension: 'Source', role: #CATEGORY }, { dimension: 'Currency', role: #SERIES } ],
               measureAttributes: [ { measure: 'Amount', role: #AXIS_1 } ] },
             { qualifier: 'BizByBank', title: 'Payments by house bank and payment status',
               chartType: #COLUMN_STACKED, dimensions: [ 'HouseBank', 'PaymentStatus' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'HouseBank', role: #CATEGORY }, { dimension: 'PaymentStatus', role: #SERIES } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] },
             { qualifier: 'BizByCompany', title: 'Payments by company code and source',
               chartType: #COLUMN_STACKED, dimensions: [ 'CompanyCode', 'Source' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'CompanyCode', role: #CATEGORY }, { dimension: 'Source', role: #SERIES } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] },
             { qualifier: 'MgrOnTimeByClass', title: 'On time and late by payment type',
               chartType: #BAR_STACKED, dimensions: [ 'MethodClass' ], measures: [ 'OnTimeCount', 'LateCount' ],
               dimensionAttributes: [ { dimension: 'MethodClass', role: #CATEGORY } ],
               measureAttributes: [ { measure: 'OnTimeCount', role: #AXIS_1 }, { measure: 'LateCount', role: #AXIS_1 } ] },
             { qualifier: 'MgrOnTimeByBank', title: 'On time and late by house bank',
               chartType: #BAR_STACKED, dimensions: [ 'HouseBank' ], measures: [ 'OnTimeCount', 'LateCount' ],
               dimensionAttributes: [ { dimension: 'HouseBank', role: #CATEGORY } ],
               measureAttributes: [ { measure: 'OnTimeCount', role: #AXIS_1 }, { measure: 'LateCount', role: #AXIS_1 } ] },
             { qualifier: 'MgrOnTimeByCompany', title: 'On time and late by company code',
               chartType: #BAR_STACKED, dimensions: [ 'CompanyCode' ], measures: [ 'OnTimeCount', 'LateCount' ],
               dimensionAttributes: [ { dimension: 'CompanyCode', role: #CATEGORY } ],
               measureAttributes: [ { measure: 'OnTimeCount', role: #AXIS_1 }, { measure: 'LateCount', role: #AXIS_1 } ] },
             { qualifier: 'ItOpenByClass', title: 'Open payments by method class and outcome',
               chartType: #COLUMN_STACKED, dimensions: [ 'MethodClass', 'Outcome' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'MethodClass', role: #CATEGORY }, { dimension: 'Outcome', role: #SERIES } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] },
             { qualifier: 'ItGapsByClass', title: 'Evidence gaps by method class and finding',
               chartType: #COLUMN_STACKED, dimensions: [ 'MethodClass', 'Finding' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'MethodClass', role: #CATEGORY }, { dimension: 'Finding', role: #SERIES } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] },
             { qualifier: 'ItByBankStatus', title: 'Payments per house bank and status',
               chartType: #HEATMAP, dimensions: [ 'HouseBank', 'PaymentStatus' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'HouseBank', role: #CATEGORY }, { dimension: 'PaymentStatus', role: #CATEGORY2 } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] } ]
@UI.selectionVariant: [ { qualifier: 'Today', text: 'Current business date', filter: 'IsCurrentDay EQ X' },
                        { qualifier: 'LocalCurrency', text: 'Company code currency', filter: 'IsLocalCurrency EQ X' },
                        { qualifier: 'OtherCurrencies', text: 'Other currencies', filter: 'IsLocalCurrency NE X' },
                        { qualifier: 'Collections', text: 'Collections', filter: 'Flow EQ C' },
                        { qualifier: 'Disbursements', text: 'Disbursements', filter: 'Flow EQ D' } ]
annotate entity ZC_{{P}}_PaymCube with
{
  @EndUserText.label: 'Business date'
  @UI.selectionField: [ { position: 20 } ]
  @UI.lineItem: [ { position: 10 } ]
  BusinessDate;
  @EndUserText.label: 'Company code'
  @UI.selectionField: [ { position: 30 } ]
  @UI.lineItem: [ { position: 20 } ]
  CompanyCode;
  @EndUserText.label: 'Collection / disbursement'
  @UI.selectionField: [ { position: 40 } ]
  Flow;
  @EndUserText.label: 'Source'
  @UI.selectionField: [ { position: 50 } ]
  @UI.lineItem: [ { position: 30 } ]
  Source;
  @EndUserText.label: 'Transaction'
  @UI.selectionField: [ { position: 60 } ]
  TransactionType;
  @EndUserText.label: 'Request status'
  RequestStatus;
  @EndUserText.label: 'Payment status'
  @UI.selectionField: [ { position: 70 } ]
  @UI.lineItem: [ { position: 40 } ]
  PaymentStatus;
  @EndUserText.label: 'Payment method'
  PaymentMethod;
  @EndUserText.label: 'Payment type'
  @UI.selectionField: [ { position: 80 } ]
  @UI.lineItem: [ { position: 50 } ]
  MethodClass;
  @EndUserText.label: 'House bank'
  @UI.selectionField: [ { position: 90 } ]
  @UI.lineItem: [ { position: 60 } ]
  HouseBank;
  @EndUserText.label: 'Open outcome'
  Outcome;
  @EndUserText.label: 'Open finding'
  Finding;
  @EndUserText.label: 'Currency'
  @UI.lineItem: [ { position: 70 } ]
  Currency;
  @UI.hidden: true
  OpsArea;
  @EndUserText.label: 'Collection / disbursement'
  FlowText;
  @EndUserText.label: 'Source'
  SourceText;
  @EndUserText.label: 'Transaction'
  TransactionText;
  @EndUserText.label: 'Payment status'
  PaymentStatusText;
  @EndUserText.label: 'Payment type'
  MethodClassText;
  @EndUserText.label: 'Company code currency'
  IsLocalCurrency;
  @EndUserText.label: 'Current business date'
  @UI.selectionField: [ { position: 10 } ]
  @Consumption.filter.defaultValue: 'X'
  IsCurrentDay;
  @EndUserText.label: 'Payments'
  @UI.lineItem: [ { position: 80 } ]
  @UI.dataPoint: { qualifier: 'Payments', title: 'Payments' }
  ItemCount;
  @EndUserText.label: 'Late'
  @UI.dataPoint: { qualifier: 'Late', title: 'Late payments' }
  LateCount;
  @EndUserText.label: 'On time'
  @UI.dataPoint: { qualifier: 'OnTime', title: 'On time' }
  OnTimeCount;
  @EndUserText.label: 'Amount'
  @UI.lineItem: [ { position: 90 } ]
  @UI.dataPoint: { qualifier: 'Amount', title: 'Amount (company code currency)' }
  Amount;
}
