// Artifact: zc_ca_opsflowqry.ddls.asddls
// Purpose: Account flow reconciliation - analytical query (transient view entity over ZI_CA_OpsFlowCube): for one flow,
//          company code and currency (mandatory, single) and the posting date window "from" - "to" (parameters): rows
//          the stage (in its order: the configured stages, OTHER, then Movement, Opening position, Closing position,
//          Unexplained), columns the accounts by role, debit and credit per cell, expected debit / credit (the
//          brackets of the sample: the query cannot write a value in brackets, so they are their own columns), reached
//          G/L of a subledger-posted account; free: control tag, evaluation status, line source, document type, rule.
//          Totals hidden: the Movement row is the total of the stages, the positions are no sum of rows. Totals per
//          currency by the query, never in ABAP and never across currencies. Preview: ADT data preview, Fiori
//          "Multidimensional Reports" with this query, Analysis for Office.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): transient view entity with parameters and provider contract analytical_query (7.58), mandatory
//          single-value filters, axis / totals annotations (as ZC_CA_OpsBrkQry, V136).
@EndUserText.label: 'Account flow - query'
@AccessControl.authorizationCheck: #NOT_ALLOWED
define transient view entity ZC_CA_OpsFlowQry
  provider contract analytical_query
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as projection on ZI_CA_OpsFlowCube( P_DateFrom : $parameters.P_DateFrom,
                                      P_DateTo   : $parameters.P_DateTo )
{
  @AnalyticsDetails.query.axis: #FREE
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: false, mandatory: true }
  FlowId,
  @AnalyticsDetails.query.axis: #FREE
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: false, mandatory: true }
  CompanyCode,
  @AnalyticsDetails.query.axis: #FREE
  @Consumption.filter: { selectionType: #SINGLE, multipleSelections: false, mandatory: true }
  Currency,
  @AnalyticsDetails.query.axis: #ROWS
  @AnalyticsDetails.query.totals: #HIDE
  StageOrder,
  @AnalyticsDetails.query.axis: #ROWS
  @AnalyticsDetails.query.totals: #HIDE
  StageId,
  @AnalyticsDetails.query.axis: #ROWS
  @AnalyticsDetails.query.totals: #HIDE
  ControlStatus,
  @AnalyticsDetails.query.axis: #COLUMNS
  @AnalyticsDetails.query.totals: #HIDE
  AccountOrder,
  @AnalyticsDetails.query.axis: #COLUMNS
  @AnalyticsDetails.query.totals: #HIDE
  AccountRole,
  @AnalyticsDetails.query.axis: #COLUMNS
  @AnalyticsDetails.query.totals: #HIDE
  FlowAccount,
  @AnalyticsDetails.query.axis: #FREE
  Area,
  @AnalyticsDetails.query.axis: #FREE
  GLAccount,
  @AnalyticsDetails.query.axis: #FREE
  EvalStatus,
  @AnalyticsDetails.query.axis: #FREE
  RowKind,
  @AnalyticsDetails.query.axis: #FREE
  LineSource,
  @AnalyticsDetails.query.axis: #FREE
  ReferenceType,
  @AnalyticsDetails.query.axis: #FREE
  DocumentType,
  @AnalyticsDetails.query.axis: #FREE
  Origin,
  @AnalyticsDetails.query.axis: #FREE
  MainTransaction,
  @AnalyticsDetails.query.axis: #FREE
  SubTransaction,
  @AnalyticsDetails.query.axis: #FREE
  RuleId,
  @AnalyticsDetails.query.axis: #COLUMNS
  DebitAmount,
  @AnalyticsDetails.query.axis: #COLUMNS
  CreditAmount,
  @AnalyticsDetails.query.axis: #COLUMNS
  ExpectedDebit,
  @AnalyticsDetails.query.axis: #COLUMNS
  ExpectedCredit,
  @AnalyticsDetails.query.axis: #FREE
  ReachedGlDebit,
  @AnalyticsDetails.query.axis: #FREE
  ReachedGlCredit,
  @AnalyticsDetails.query.axis: #FREE
  LineCount,
  @AnalyticsDetails.query.axis: #FREE
  NotEvaluatedCount,
  @AnalyticsDetails.query.axis: #FREE
  ControlOpenCount
}
