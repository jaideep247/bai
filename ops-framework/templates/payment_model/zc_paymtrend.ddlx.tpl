// UI annotations: payment model - business-date trend (entity PaymentTrend; generated - never edit, regenerate)
// Cards: Biz (daily volume by source / transaction), Mgr (volume vs same weekday last week, late payments, amount
// per currency), It (daily counts by status). Selection variant Last{{TREND}}: the last {{TREND}} days.
@Metadata.layer: #CORE
@UI.headerInfo: { typeName: 'Business day', typeNamePlural: 'Business-date trend',
                  title: { type: #STANDARD, value: 'BusinessDate' } }
@UI.chart: [ { qualifier: 'BizDailyBySource', title: 'Daily payments by source',
               chartType: #COLUMN_STACKED, dimensions: [ 'BusinessDate', 'Source' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'BusinessDate', role: #CATEGORY }, { dimension: 'Source', role: #SERIES } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] },
             { qualifier: 'BizDailyByTransaction', title: 'Daily payments by transaction',
               chartType: #COLUMN_STACKED, dimensions: [ 'BusinessDate', 'TransactionType' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'BusinessDate', role: #CATEGORY }, { dimension: 'TransactionType', role: #SERIES } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] },
             { qualifier: 'MgrVolumeVsLastWeek', title: 'Payments per day vs same weekday last week',
               chartType: #LINE, dimensions: [ 'BusinessDate' ], measures: [ 'ItemCount', 'PrevWeekCount' ],
               dimensionAttributes: [ { dimension: 'BusinessDate', role: #CATEGORY } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 }, { measure: 'PrevWeekCount', role: #AXIS_1 } ] },
             { qualifier: 'MgrLatePerDay', title: 'Late payments per day by payment type',
               chartType: #COLUMN_STACKED, dimensions: [ 'BusinessDate', 'MethodClass' ], measures: [ 'LateCount' ],
               dimensionAttributes: [ { dimension: 'BusinessDate', role: #CATEGORY }, { dimension: 'MethodClass', role: #SERIES } ],
               measureAttributes: [ { measure: 'LateCount', role: #AXIS_1 } ] },
             { qualifier: 'MgrAmountPerDay', title: 'Amount per day (per currency)',
               chartType: #LINE, dimensions: [ 'BusinessDate', 'Currency' ], measures: [ 'Amount' ],
               dimensionAttributes: [ { dimension: 'BusinessDate', role: #CATEGORY }, { dimension: 'Currency', role: #SERIES } ],
               measureAttributes: [ { measure: 'Amount', role: #AXIS_1 } ] },
             { qualifier: 'ItDailyByStatus', title: 'Payments per day by payment status',
               chartType: #COLUMN_STACKED, dimensions: [ 'BusinessDate', 'PaymentStatus' ], measures: [ 'ItemCount' ],
               dimensionAttributes: [ { dimension: 'BusinessDate', role: #CATEGORY }, { dimension: 'PaymentStatus', role: #SERIES } ],
               measureAttributes: [ { measure: 'ItemCount', role: #AXIS_1 } ] } ]
@UI.presentationVariant: [ { qualifier: 'Trend', sortOrder: [ { by: 'BusinessDate', direction: #ASC } ],
                             visualizations: [ { type: #AS_CHART, qualifier: 'MgrVolumeVsLastWeek' } ] } ]
@UI.selectionVariant: [ { qualifier: 'Last{{TREND}}', text: 'Last {{TREND}} days', filter: 'DaysAgo LE {{TREND}}' },
                        { qualifier: 'PeakDays', text: 'Peak days', filter: 'IsPeakDay EQ X' } ]
annotate entity ZC_{{P}}_PaymTrend with
{
  @EndUserText.label: 'Business date'
  @UI.selectionField: [ { position: 10 } ]
  @UI.lineItem: [ { position: 10 } ]
  BusinessDate;
  @EndUserText.label: 'Company code'
  @UI.selectionField: [ { position: 20 } ]
  CompanyCode;
  @EndUserText.label: 'Collection / disbursement'
  Flow;
  @EndUserText.label: 'Source'
  @UI.selectionField: [ { position: 30 } ]
  Source;
  @EndUserText.label: 'Transaction'
  TransactionType;
  @EndUserText.label: 'Payment type'
  @UI.selectionField: [ { position: 40 } ]
  MethodClass;
  @EndUserText.label: 'Payment status'
  PaymentStatus;
  @EndUserText.label: 'House bank'
  @UI.selectionField: [ { position: 50 } ]
  HouseBank;
  @EndUserText.label: 'Currency'
  Currency;
  @UI.hidden: true
  OpsArea;
  @EndUserText.label: 'Days ago'
  DaysAgo;
  @EndUserText.label: 'Peak day'
  @UI.lineItem: [ { position: 20 } ]
  IsPeakDay;
  @EndUserText.label: 'Payments'
  @UI.lineItem: [ { position: 30 } ]
  ItemCount;
  @EndUserText.label: 'Late'
  LateCount;
  @EndUserText.label: 'Same weekday last week'
  @UI.lineItem: [ { position: 40 } ]
  PrevWeekCount;
  @EndUserText.label: 'Amount'
  Amount;
  @EndUserText.label: 'Amount same weekday last week'
  PrevWeekAmount;
}
