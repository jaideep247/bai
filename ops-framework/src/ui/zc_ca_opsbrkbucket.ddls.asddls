// Artifact: zc_ca_opsbrkbucket.ddls.asddls
// Purpose: Consumption view of the overview card "Clearing account breaks by bucket" (service ZUI_CA_OPS_BRK; chart
//          and list annotations in the metadata extension): groups and amount per bucket and currency of the latest
//          snapshot of each account. Read access: DCL ZC_CA_OPSBRKBUCKET (ZCA_OPS 03 for the area and the company
//          code). Read-only.
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Clearing account breaks by bucket'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsBrkBucket
  provider contract transactional_query
  as projection on ZR_CA_OpsBrkBucket
{
  key Area,
  key AccountId,
  key CompanyCode,
  key Bucket,
  key Currency,
      BucketText,
      IsExplained,
      KeyDate,
      @Aggregation.default: #SUM
      GroupCount,
      @Aggregation.default: #SUM
      LineCount,
      Amount,
      OldestAgeDays,
      BucketCriticality
}
