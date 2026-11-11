// Artifact: zc_ca_opsbrkqry.ddls.asddls
// Purpose: Clearing-account break analysis - analytical query (transient view entity over ZI_CA_OpsBrkCube): rows
//          account / bucket / currency, columns amount, groups, lines, explained and unexplained groups and the oldest
//          age; the latest snapshot of each account by default (IsLatest = X). Totals per currency by the query, never
//          in ABAP and never across currencies (Currency on the rows). Preview: ADT data preview of the cube, Fiori
//          "Multidimensional Reports" with this query.
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
// VERIFY-ADT: transient view entity with provider contract analytical_query (7.58), axis / totals annotations,
//             default filter on a character dimension (V136).
@EndUserText.label: 'Clearing account breaks - query'
@AccessControl.authorizationCheck: #NOT_ALLOWED
define transient view entity ZC_CA_OpsBrkQry
  provider contract analytical_query
  as projection on ZI_CA_OpsBrkCube
{
  @AnalyticsDetails.query.axis: #ROWS
  @AnalyticsDetails.query.totals: #SHOW
  AccountId,
  @AnalyticsDetails.query.axis: #ROWS
  Bucket,
  @AnalyticsDetails.query.axis: #ROWS
  Currency,
  @AnalyticsDetails.query.axis: #FREE
  CompanyCode,
  @AnalyticsDetails.query.axis: #FREE
  KeyDate,
  @AnalyticsDetails.query.axis: #FREE
  IsExplained,
  @AnalyticsDetails.query.axis: #FREE
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: false, defaultValue: 'X' }
  IsLatest,
  @AnalyticsDetails.query.axis: #COLUMNS
  Amount,
  @AnalyticsDetails.query.axis: #COLUMNS
  GroupCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  LineCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  ExplainedCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  UnexplainedCount,
  @AnalyticsDetails.query.axis: #COLUMNS
  AgeDays
}
