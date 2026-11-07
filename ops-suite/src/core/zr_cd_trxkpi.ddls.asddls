// Artifact: zr_cd_trxkpi.ddls.asddls
// Purpose: KPI entity of the transactions dashboard (tiles, production-support overview page):
//          per posting date (last 31 days), company code and direction - transactions (open items
//          with FIN) and distinct FIN numbers, paid, and the canonical outcome now (ZI_CD_TrxItemFlow
//          with the current version: as of today 23:59:59 - no version starts in the future, so the
//          version valid then is the current one): cleared, returned, retrieved, voided, in flight,
//          problems (undetermined, inconsistent, ambiguous), reversed, still open, with NOC, not
//          evaluated, and a day criticality. Live: computed at request time (as of = now).
//          Authorisation before aggregation: CompanyCode is a GROUP BY key passed through from the
//          base rows, so the DCL condition on it (ZC_CD_TRXDASH) is the same predicate as on the base
//          rows - no row of another company code is ever summed into a visible one. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Canonical outcome measures (settled from bank lines removed); 31-day window
//                   here (the item driver spans the 400-day retention).
// VERIFY-ADT: a character literal as actual parameter of type TIMS (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - KPI per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_TrxKpi
  as select from ZI_CD_TrxItemFlow( P_AsOfDate : $session.system_date,
                                    P_AsOfTime : '235959' ) as Flow
{
  key Flow.PostingDate,
  key Flow.CompanyCode,
  key Flow.Direction,
      Flow.PaymentEngineArea,
      Flow.IsToday,
      cast( sum( Flow.ItemCount ) as abap.int4 )            as ItemCount,
      // VERIFY-ADT: COUNT( DISTINCT ) in a view entity (as ZI_CD_EbsRunFind)
      cast( count( distinct Flow.FinId ) as abap.int4 )     as FinCount,
      cast( sum( Flow.PaidReachedCount ) as abap.int4 )     as PaidReachedCount,
      cast( sum( Flow.ClearedCount ) as abap.int4 )         as ClearedCount,
      cast( sum( Flow.ReturnedCount ) as abap.int4 )        as ReturnedCount,
      cast( sum( Flow.RetrievedCount ) as abap.int4 )       as RetrievedCount,
      cast( sum( Flow.VoidedCount ) as abap.int4 )          as VoidedCount,
      cast( sum( Flow.InFlightCount ) + sum( Flow.PendingCount ) as abap.int4 ) as InFlightCount,
      cast( sum( Flow.UndeterminedCount ) + sum( Flow.InconsistentCount )
          + sum( Flow.AmbiguousCount ) as abap.int4 )       as ProblemCount,
      cast( sum( Flow.ReversedCount ) as abap.int4 )        as ReversedCount,
      cast( sum( Flow.OpenCount ) as abap.int4 )            as OpenCount,
      cast( sum( Flow.NocItemCount ) as abap.int4 )         as NocItemCount,
      cast( sum( Flow.NotEvaluatedCount ) as abap.int4 )    as NotEvaluatedCount,
      // Day criticality: 1 red (returned, reversed or a problem), 2 yellow (still open / in flight), 3 green
      cast( case
              when sum( Flow.ReturnedCount ) > 0 or sum( Flow.ReversedCount ) > 0
                or sum( Flow.UndeterminedCount ) + sum( Flow.InconsistentCount ) + sum( Flow.AmbiguousCount ) > 0
                                                                     then 1
              when sum( Flow.OpenCount ) > 0 or sum( Flow.InFlightCount ) > 0 then 2
              else 3 end as abap.int1 )                     as DayCriticality
}
where Flow.PostingDate >= dats_add_days( $session.system_date, -30, 'INITIAL' )
group by
  Flow.PostingDate,
  Flow.CompanyCode,
  Flow.Direction,
  Flow.PaymentEngineArea,
  Flow.IsToday
