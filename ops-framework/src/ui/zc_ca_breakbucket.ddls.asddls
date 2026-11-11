@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis buckets'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Bucket']
define view entity ZC_CA_BreakBucket
  as projection on ZR_CA_BreakBucket
{
  key Bucket,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Explained,
      LayerId,
      Seq,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
