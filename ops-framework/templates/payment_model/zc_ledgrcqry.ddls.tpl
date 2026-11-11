// Artifact: zc_{{p}}_ledgrcqry.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - analytical query of the group reconciliation (transient view entity over
//          ZI_{{P}}_LedgRcCube): rows company code / G/L account / currency, columns the legs; totals per currency by the
//          query, never in ABAP. Preview: ADT data preview of the cube, Fiori "Multidimensional Reports" with this query.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
// VERIFY-ADT: transient view entity with provider contract analytical_query (7.58), axis / totals annotations.
@EndUserText.label: 'Ledger model - reconciliation query'
@AccessControl.authorizationCheck: #NOT_ALLOWED
define transient view entity ZC_{{P}}_LedgRcQry
  provider contract analytical_query
  as projection on ZI_{{P}}_LedgRcCube
{
  @AnalyticsDetails.query.axis: #ROWS
  @AnalyticsDetails.query.totals: #SHOW
  CompanyCode,
  @AnalyticsDetails.query.axis: #ROWS
  GlAccount,
  @AnalyticsDetails.query.axis: #ROWS
  Currency,
  @AnalyticsDetails.query.axis: #FREE
  BusinessDate,
  @AnalyticsDetails.query.axis: #COLUMNS
  SubledgerAmount,
  @AnalyticsDetails.query.axis: #COLUMNS
  JournalTransferAmount,
  @AnalyticsDetails.query.axis: #COLUMNS
  JournalOtherAmount,
  @AnalyticsDetails.query.axis: #COLUMNS
  LiveDifference,
  @AnalyticsDetails.query.axis: #COLUMNS
  BatchCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  JournalLineCount
}
