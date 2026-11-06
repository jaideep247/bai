@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Job cycles'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['CycleId']
define view entity ZC_CD_JobCycle
  as projection on ZR_CD_JobCycle
{
  key CycleId,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Calendar,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}
