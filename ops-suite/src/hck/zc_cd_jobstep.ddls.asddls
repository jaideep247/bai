@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Job cycle steps'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['CycleId', 'StepNo']
define view entity ZC_CD_JobStep
  as projection on ZR_CD_JobStep
{
  key CycleId,
  key StepNo,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Jobname,
      Program,
      Variant,
      PredStep,
      DayOffset,
      WindowFrom,
      WindowTo,
      MaxRuntimeMin,
      Skippable,
      Critical,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}
