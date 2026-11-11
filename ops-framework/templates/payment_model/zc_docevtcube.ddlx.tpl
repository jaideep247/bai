// UI annotations: document-change model - volumes (entity DocumentChangeCategory; generated - never edit, regenerate)
// Persona cards: changes by type and source (business), trend per day (managers), by house bank / payment type (IT
// support); amounts per currency (currency in every amount chart), selection variant last 30 days.
// VERIFY-ADT: OVP V4 chart cards on a transactional_query projection with $apply (as the payment cube).
@Metadata.layer: #CORE
@UI.chart: [ { qualifier: 'ChgByTypeSource', title: 'Reversals, resets and re-clearings by source', chartType: #COLUMN_STACKED,
               dimensions: [ 'Source', 'EventType' ], measures: [ 'EventCount' ],
               dimensionAttributes: [ { dimension: 'Source', role: #CATEGORY }, { dimension: 'EventType', role: #SERIES } ],
               measureAttributes: [ { measure: 'EventCount', role: #AXIS_1 } ] },
             { qualifier: 'ChgPerDay', title: 'Document changes per day', chartType: #LINE,
               dimensions: [ 'EventDate', 'EventType' ], measures: [ 'EventCount' ],
               dimensionAttributes: [ { dimension: 'EventDate', role: #CATEGORY }, { dimension: 'EventType', role: #SERIES } ],
               measureAttributes: [ { measure: 'EventCount', role: #AXIS_1 } ] },
             { qualifier: 'ChgByBank', title: 'Document changes by house bank and payment type', chartType: #BAR_STACKED,
               dimensions: [ 'HouseBank', 'MethodClass' ], measures: [ 'EventCount' ],
               dimensionAttributes: [ { dimension: 'HouseBank', role: #CATEGORY }, { dimension: 'MethodClass', role: #SERIES } ],
               measureAttributes: [ { measure: 'EventCount', role: #AXIS_1 } ] },
             { qualifier: 'ChgAmount', title: 'Amount of changed payments (per currency)', chartType: #COLUMN,
               dimensions: [ 'EventType', 'Currency' ], measures: [ 'PaymentAmount' ],
               dimensionAttributes: [ { dimension: 'EventType', role: #CATEGORY }, { dimension: 'Currency', role: #SERIES } ],
               measureAttributes: [ { measure: 'PaymentAmount', role: #AXIS_1 } ] } ]
@UI.presentationVariant: [ { qualifier: 'ChgByTypeSource', visualizations: [ { type: #AS_CHART, qualifier: 'ChgByTypeSource' } ] },
                           { qualifier: 'ChgPerDay', visualizations: [ { type: #AS_CHART, qualifier: 'ChgPerDay' } ] },
                           { qualifier: 'ChgByBank', visualizations: [ { type: #AS_CHART, qualifier: 'ChgByBank' } ] },
                           { qualifier: 'ChgAmount', visualizations: [ { type: #AS_CHART, qualifier: 'ChgAmount' } ] } ]
annotate entity ZC_{{P}}_DocEvtCube with
{
  @EndUserText.label: 'Date of the change'
  @UI.selectionField: [ { position: 10 } ]
  EventDate;
  @EndUserText.label: 'Change'
  @UI.selectionField: [ { position: 20 } ]
  EventType;
  @EndUserText.label: 'Changed in'
  EventSource;
  @EndUserText.label: 'Company code'
  @UI.selectionField: [ { position: 30 } ]
  CompanyCode;
  @EndUserText.label: 'Source'
  Source;
  @EndUserText.label: 'Payment type'
  MethodClass;
  @EndUserText.label: 'House bank'
  HouseBank;
  @EndUserText.label: 'Currency'
  Currency;
  @UI.hidden: true
  OpsArea;
  @EndUserText.label: 'Changes'
  EventCount;
  @EndUserText.label: 'Payments'
  PaymentCount;
  @EndUserText.label: 'Payment amount'
  PaymentAmount;
}
