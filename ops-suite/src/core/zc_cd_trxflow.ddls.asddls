// Artifact: zc_cd_trxflow.ddls.asddls
// Purpose: Consumption view of the transactions dashboard (analytical list page, OData V4,
//          service ZUI_CD_TRX_DASH): the payment worklist - open payments, open payment requests and
//          exceptions (no clean payment, user decision 2026-11-08) of the chosen day(s) by worklist,
//          payment run, value or due date, default aggregation of every measure (HANA aggregates the
//          base rows that the DCL left - the company-code restriction applies before the GROUP BY),
//          drill-down to payment runs and returns / NOC lot items; navigation to the payment trace
//          (FIN / payment document). UI annotations in the metadata extension ZC_CD_TRXFLOW.
//          Read access: DCL ZC_CD_TRXDASH (ZCD_OPS, ZCA_PARAR = CORE and BUKRS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Canonical outcome, date kind and as-of parameters (ZR_CD_TrxFlow).
//                   2026-11-08 | Header: payment outcome snapshot lag (maximum over the rows: one value).
//                   2026-11-08 | Exceptions-only worklist: worklist rows, date kinds WORKLIST / RUN / VALUE / DUE,
//                   no "as of" parameters, requests not paid on their due date.
// VERIFY-ADT: parameters of a transactional_query projection in an analytical list page (OData V4).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard'
@Metadata.allowExtensions: true
define root view entity ZC_CD_TrxFlow
  provider contract transactional_query
  with parameters
    @EndUserText.label: 'Date kind (WORKLIST, RUN, VALUE, DUE)'
    @Consumption.defaultValue: 'WORKLIST'
    P_DateKind : abap.char( 10 ),
    @EndUserText.label: 'Date from'
    @Environment.systemField: #SYSTEM_DATE
    P_DateFrom : abap.dats,
    @EndUserText.label: 'Date to'
    @Environment.systemField: #SYSTEM_DATE
    P_DateTo   : abap.dats
  as projection on ZR_CD_TrxFlow( P_DateKind : $parameters.P_DateKind,
                                  P_DateFrom : $parameters.P_DateFrom,
                                  P_DateTo   : $parameters.P_DateTo )
{
  key FinId,
  key SourceSystem,
  key CompanyCode,
  key ClearingDoc,
  key RunDate,
  key RunId,
      PaymentEngineArea,
      WorkKind,
      IsException,
      OpenSince,
      Outcome,
      Finding,
      Severity,
      EvidenceKind,
      EvidenceRef,
      FlowClass,
      DueDate,
      WorklistDate,
      IsToday,
      PaymentMethod,
      HouseBank,
      ValueDate,
      PaymentStatus,
      Direction,
      Currency,
      @Aggregation.default: #SUM
      Amount,
      FlowCriticality,
      @Aggregation.default: #MAX
      SnapshotLagMinutes,
      SnapshotStaleAfterMinutes,
      SnapshotIsStale,
      SnapshotCriticality,
      @Aggregation.default: #SUM
      EntryCount,
      @Aggregation.default: #SUM
      OpenCount,
      @Aggregation.default: #SUM
      ExceptionCount,
      @Aggregation.default: #SUM
      InFlightCount,
      @Aggregation.default: #SUM
      PendingCount,
      @Aggregation.default: #SUM
      UndeterminedCount,
      @Aggregation.default: #SUM
      InconsistentCount,
      @Aggregation.default: #SUM
      AmbiguousCount,
      @Aggregation.default: #SUM
      RequestOpenCount,
      @Aggregation.default: #SUM
      RequestNotPaidCount,
      @Aggregation.default: #SUM
      LateCount,
      @Aggregation.default: #SUM
      StatusPendingCount,
      _PaymentRuns : redirected to ZC_CD_TrxPayRun,
      _ReturnsNoc : redirected to ZC_CD_TrxRetNoc
}
