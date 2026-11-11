// Artifact: zr_ca_opsbrkbucket.ddls.asddls
// Purpose: Clearing account breaks by bucket (overview card of a consumer's overview page, service ZUI_CA_OPS_BRK):
//          the groups of the latest snapshot of every account (IsLatest) per area, account, company code, bucket and
//          currency - groups, lines, amount (per currency, never across), oldest age and the explained flag of the
//          bucket. Aggregated on the database, nothing stored; read-only (no behaviour).
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Clearing account breaks by bucket'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsBrkBucket
  as select from ZR_CA_OpsBrkGroup
{
  key Area,
  key AccountId,
  key CompanyCode,
  key Bucket,
  key Currency,
      BucketText,
      IsExplained,
      KeyDate,
      cast( sum( GroupCount ) as abap.int4 )                as GroupCount,
      cast( sum( LineCount ) as abap.int4 )                 as LineCount,
      sum( Amount )                                         as Amount,
      max( AgeDays )                                        as OldestAgeDays,
      cast( case IsExplained when 'X' then 3 else 1 end as abap.int1 ) as BucketCriticality
}
where
  IsLatest = 'X'
group by
  Area,
  AccountId,
  CompanyCode,
  Bucket,
  Currency,
  BucketText,
  IsExplained,
  KeyDate
