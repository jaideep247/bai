// Artifact: zr_cd_trxkpi.ddls.asddls
// Purpose: KPI entity of the transactions dashboard (tiles, production-support overview page): per
//          worklist date (run date of a payment, due date of a request; last 31 days), company code and
//          direction - the payment worklist now (ZI_CD_PayWorkItem): entries, distinct FIN numbers, open,
//          exceptions, payments in flight, late payments, inconsistent / undetermined / ambiguous,
//          requests open and not paid on their due date, and a day criticality. A clean payment has no
//          row any more (user decision 2026-11-08): there is no cleared / returned count here - those
//          payments are in the standard tables and the payment trace. Live: computed at request time.
//          Authorisation before aggregation: CompanyCode is a GROUP BY key passed through from the
//          base rows, so the DCL condition on it (ZC_CD_TRXDASH) is the same predicate as on the base
//          rows - no row of another company code is ever summed into a visible one. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Canonical outcome measures (settled from bank lines removed); 31-day window
//                   here (the item driver spans the 400-day retention).
//                   2026-11-08 | Exceptions-only worklist: measures of the worklist, no "as of" instant.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - KPI per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_TrxKpi
  as select from ZI_CD_PayWorkItem as Work
{
  key Work.WorklistDate,
  key Work.CompanyCode,
  key Work.Direction,
      Work.PaymentEngineArea,
      Work.IsToday,
      cast( count( * ) as abap.int4 )                       as EntryCount,
      // VERIFY-ADT: COUNT( DISTINCT ) in a view entity (as ZI_CD_EbsRunFind)
      cast( count( distinct Work.FinId ) as abap.int4 )     as FinCount,
      cast( sum( case when Work.Finding = ' ' then 1 else 0 end ) as abap.int4 )  as OpenCount,
      cast( sum( case when Work.Finding <> ' ' then 1 else 0 end ) as abap.int4 ) as ExceptionCount,
      cast( sum( case Work.Outcome when 'IN_FLIGHT' then 1 when 'PENDING' then 1 else 0 end )
            as abap.int4 )                                  as InFlightCount,
      cast( sum( case Work.Finding when 'PAYMENT_NOT_CLEARED' then 1 else 0 end ) as abap.int4 ) as LateCount,
      cast( sum( case Work.Outcome when 'UNDETERMINED' then 1 when 'INCONSISTENT' then 1
                                   when 'AMBIGUOUS' then 1 else 0 end ) as abap.int4 ) as ProblemCount,
      cast( sum( case Work.Outcome when 'REQ_OPEN' then 1 else 0 end ) as abap.int4 )     as RequestOpenCount,
      cast( sum( case Work.Outcome when 'REQ_NOT_PAID' then 1 else 0 end ) as abap.int4 ) as RequestNotPaidCount,
      // Day criticality: 1 red (an exception of severity E), 2 yellow (any other exception), 3 green
      cast( case
              when sum( case when Work.Severity = 'E' then 1 else 0 end ) > 0 then 1
              when sum( case when Work.Finding <> ' ' then 1 else 0 end ) > 0 then 2
              else 3 end as abap.int1 )                     as DayCriticality
}
where Work.WorklistDate >= dats_add_days( $session.system_date, -30, 'INITIAL' )
group by
  Work.WorklistDate,
  Work.CompanyCode,
  Work.Direction,
  Work.PaymentEngineArea,
  Work.IsToday
