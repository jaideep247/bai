@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Scheduler jobs and SAP job names'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SchedFolder', 'SchedJob']
define view entity ZC_CA_SchedulerJob
  as projection on ZR_CA_SchedulerJob
{
  key SchedFolder,
  key SchedJob,
      @Consumption.hidden: true
      SingletonID,
      SapPattern,
      Criticality,
      Description,
      Active,
      Seq,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
