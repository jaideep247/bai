// Artifact: zr_cd_trxkpi.ddls.asddls
// Purpose: KPI entity of the transactions dashboard (tiles, production-support overview page):
//          per posting date (last 31 days), company code and direction - transactions (open items
//          with FIN) and distinct FIN numbers, the funnel posted -> paid -> settled, returned,
//          reversed, still open, with NOC, per flow bucket, and a day criticality. Live: computed at
//          request time from ZR_CD_TrxFlow (no batch, as of = now). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - KPI per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_TrxKpi
  as select from ZR_CD_TrxFlow
{
  key PostingDate,
  key CompanyCode,
  key Direction,
      PaymentEngineArea,
      IsToday,
      cast( sum( ItemCount ) as abap.int4 )                 as ItemCount,
      // VERIFY-ADT: COUNT( DISTINCT ) in a view entity (as ZI_CD_EbsRunFind)
      cast( count( distinct FinId ) as abap.int4 )          as FinCount,
      cast( sum( PaidReachedCount ) as abap.int4 )          as PaidReachedCount,
      cast( sum( SettledReachedCount ) as abap.int4 )       as SettledReachedCount,
      cast( sum( ReturnedCount ) as abap.int4 )             as ReturnedCount,
      cast( sum( ReversedCount ) as abap.int4 )             as ReversedCount,
      cast( sum( OpenCount ) as abap.int4 )                 as OpenCount,
      cast( sum( NocItemCount ) as abap.int4 )              as NocItemCount,
      cast( sum( case FlowBucket when 'POSTED' then 1 else 0 end ) as abap.int4 )  as PostedBucketCount,
      cast( sum( case FlowBucket when 'CLEARED' then 1 else 0 end ) as abap.int4 ) as ClearedBucketCount,
      cast( sum( case FlowBucket when 'PAID' then 1 else 0 end ) as abap.int4 )    as PaidBucketCount,
      cast( sum( case FlowBucket when 'SETTLED' then 1 else 0 end ) as abap.int4 ) as SettledBucketCount,
      // Day criticality: 1 red (returned or reversed), 2 yellow (still open), 3 green
      cast( case
              when sum( ReturnedCount ) > 0 or sum( ReversedCount ) > 0 then 1
              when sum( OpenCount ) > 0                                 then 2
              else 3 end as abap.int1 )                     as DayCriticality
}
group by
  PostingDate,
  CompanyCode,
  Direction,
  PaymentEngineArea,
  IsToday
