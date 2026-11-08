// Artifact: zr_cd_trxflow.ddls.asddls
// Purpose: Root of the transactions dashboard (analytical list page, OData V4,
//          docs/Dashboard_Transactions.md): the payment worklist - every open payment, open payment
//          request and exception (user decision 2026-11-08: a clean payment has no row; its detail
//          stays in the standard tables and the payment trace looks it up). One row per current
//          worklist row (ZI_CD_PayWorkItem) with the verdict of the evaluator ZIF_CD_OPS_PAY_OUTCOME /
//          the request rule ZIF_CD_OPS_PAY_REQUEST - the same as the morning report checks A_INFLIGHT /
//          A_PRQ_NOT_PAID and the payment trace. Parameters:
//            P_DateKind  WORKLIST (run date of a payment, due date of a request), RUN (payment run
//                        date), VALUE (its value date) or DUE (due date of a request)
//            P_DateFrom / P_DateTo  the day (or days) chosen - the worklist bounds the rows, no driver
//                        window
//          Filters: kind (PAYMENT / REQUEST), flow + method class, outcome, finding (code), source,
//          exception or open. Aggregation is done by HANA on the base rows ($apply on ZC_CD_TrxFlow,
//          whose DCL restricts the base rows by company code before the GROUP BY). Drill-down: payment
//          runs, returns / NOC lot items; every row links to the payment trace (FIN, payment document).
//          No member number, partner or bank account. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Review defect: SETTLED from any bank / encashment line - the bucket is now
//                   the canonical outcome (ZI_CD_TrxItemFlow); date kind and as-of parameters.
//                   2026-11-08 | Header: the payment outcome snapshot lag (ZI_CD_PayOutLag - minutes,
//                   stale flag, criticality), so a stale outcome is never read as current.
//                   2026-11-08 | Exceptions-only worklist: rows from the worklist (ZI_CD_PayWorkItem) - the
//                   400-day open-item driver, the POSTING date kind and the "outcome as of" history are
//                   gone; date kind DUE and the requests not paid on their due date added.
// VERIFY-ADT: OR of parameter comparisons in WHERE is pruned by HANA per date kind (PlanViz, TXD-12).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - worklist row'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #L, dataClass: #MIXED }
define root view entity ZR_CD_TrxFlow
  with parameters
    @EndUserText.label: 'Date kind (WORKLIST, RUN, VALUE, DUE)'
    P_DateKind : abap.char( 10 ),
    @EndUserText.label: 'Date from'
    @Environment.systemField: #SYSTEM_DATE
    P_DateFrom : abap.dats,
    @EndUserText.label: 'Date to'
    @Environment.systemField: #SYSTEM_DATE
    P_DateTo   : abap.dats
  as select from ZI_CD_PayWorkItem as Work
    // One row (area CORE = the dashboard's area): the snapshot lag shown in the header
    left outer join ZI_CD_PayOutLag as Lag on Lag.PaymentEngineArea = Work.PaymentEngineArea
  association [0..*] to ZR_CD_TrxPayRun as _PaymentRuns on $projection.ClearingDoc = _PaymentRuns.PaymentDocument
  association [0..*] to ZR_CD_TrxRetNoc as _ReturnsNoc  on $projection.ClearingDoc = _ReturnsNoc.ClearingDoc
{
  key Work.FinId,
  key Work.SourceSystem,
  key Work.CompanyCode,
  key Work.ClearingDoc,
  key Work.RunDate,
  key Work.RunId,
      Work.PaymentEngineArea,
      Work.WorkKind,
      Work.IsException,
      Work.ValidFrom                                        as OpenSince,
      Work.Outcome,
      Work.Finding,
      Work.Severity,
      Work.EvidenceKind,
      Work.EvidenceRef,
      Work.FlowClass,
      Work.DueDate,
      Work.WorklistDate,
      Work.IsToday,
      Work.PaymentMethod,
      Work.HouseBank,
      Work.ValueDate,
      Work.PaymentStatus,
      Work.Direction,
      Work.Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Work.Amount,
      // UI criticality: 1 red (exception E), 2 yellow (exception W / I), 0 open
      cast( case
              when Work.Severity = 'E' then 1
              when Work.Finding <> ' ' then 2
              else 0 end as abap.int1 )                     as FlowCriticality,
      // ---------------------------------------------------------------- header: snapshot lag
      Lag.AgeMinutes                                        as SnapshotLagMinutes,
      Lag.StaleAfterMinutes                                 as SnapshotStaleAfterMinutes,
      Lag.IsStale                                           as SnapshotIsStale,
      Lag.StaleCriticality                                  as SnapshotCriticality,
      // ---------------------------------------------------------------- measures
      cast( 1 as abap.int4 )                                as EntryCount,
      cast( case when Work.Finding = ' ' then 1 else 0 end as abap.int4 ) as OpenCount,
      cast( case when Work.Finding <> ' ' then 1 else 0 end as abap.int4 ) as ExceptionCount,
      cast( case Work.Outcome when 'IN_FLIGHT' then 1 else 0 end as abap.int4 )    as InFlightCount,
      cast( case Work.Outcome when 'PENDING' then 1 else 0 end as abap.int4 )      as PendingCount,
      cast( case Work.Outcome when 'UNDETERMINED' then 1 else 0 end as abap.int4 ) as UndeterminedCount,
      cast( case Work.Outcome when 'INCONSISTENT' then 1 else 0 end as abap.int4 ) as InconsistentCount,
      cast( case Work.Outcome when 'AMBIGUOUS' then 1 else 0 end as abap.int4 )    as AmbiguousCount,
      cast( case Work.Outcome when 'REQ_OPEN' then 1 else 0 end as abap.int4 )     as RequestOpenCount,
      cast( case Work.Outcome when 'REQ_NOT_PAID' then 1 else 0 end as abap.int4 ) as RequestNotPaidCount,
      cast( case Work.Finding when 'PAYMENT_NOT_CLEARED' then 1 else 0 end as abap.int4 ) as LateCount,
      cast( case Work.Finding when 'PAY_STATUS_PENDING' then 1 else 0 end as abap.int4 )  as StatusPendingCount,
      _PaymentRuns,
      _ReturnsNoc
}
where ( $parameters.P_DateKind = 'RUN'
        and Work.WorkKind = 'PAYMENT'
        and Work.RunDate between $parameters.P_DateFrom and $parameters.P_DateTo )
   or ( $parameters.P_DateKind = 'VALUE'
        and Work.ValueDate between $parameters.P_DateFrom and $parameters.P_DateTo )
   or ( $parameters.P_DateKind = 'DUE'
        and Work.DueDate between $parameters.P_DateFrom and $parameters.P_DateTo )
   or ( $parameters.P_DateKind = 'WORKLIST'
        and Work.WorklistDate between $parameters.P_DateFrom and $parameters.P_DateTo )
