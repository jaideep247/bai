// Artifact: zc_{{p}}_paymexctrend.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - exceptions raised vs resolved per day (entity ExceptionTrend of
//          {{SERVICE}}): managers' trend, IT support's daily failures per area. Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - exceptions per day'
@Metadata.allowExtensions: true
@UI.chart: [ { qualifier: 'MgrRaisedResolved', title: 'Exceptions raised vs resolved per day',
               chartType: #COLUMN, dimensions: [ 'BusinessDate' ], measures: [ 'RaisedCount', 'ResolvedCount' ],
               dimensionAttributes: [ { dimension: 'BusinessDate', role: #CATEGORY } ],
               measureAttributes: [ { measure: 'RaisedCount', role: #AXIS_1 }, { measure: 'ResolvedCount', role: #AXIS_1 } ] },
             { qualifier: 'ItRaisedByArea', title: 'Failures per day and area',
               chartType: #COLUMN_STACKED, dimensions: [ 'BusinessDate', 'OpsArea' ], measures: [ 'RaisedCount' ],
               dimensionAttributes: [ { dimension: 'BusinessDate', role: #CATEGORY }, { dimension: 'OpsArea', role: #SERIES } ],
               measureAttributes: [ { measure: 'RaisedCount', role: #AXIS_1 } ] } ]
@UI.selectionVariant: [ { qualifier: 'Last{{TREND}}', text: 'Last {{TREND}} days', filter: 'DaysAgo LE {{TREND}}' } ]
define root view entity ZC_{{P}}_PaymExcTrend
  provider contract transactional_query
  as projection on ZR_{{P}}_PaymExcTrend
{
      @EndUserText.label: 'Business date'
  key BusinessDate,
      @EndUserText.label: 'Area'
  key OpsArea,
      @EndUserText.label: 'Company code'
  key CompanyCode,
      @EndUserText.label: 'Severity'
  key Severity,
      @EndUserText.label: 'Days ago'
      DaysAgo,
      @EndUserText.label: 'Raised'
      @Aggregation.default: #SUM
      RaisedCount,
      @EndUserText.label: 'Resolved'
      @Aggregation.default: #SUM
      ResolvedCount
}
