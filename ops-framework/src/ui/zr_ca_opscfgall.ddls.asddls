@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Processes, checks, alerting, purge targets and controls (all)'
define root view entity ZR_CA_OpsCfgAll
  as select from I_Language
    left outer join ZI_CA_OpsCfgChg as Chg on 0 = 0
  composition [0..*] of ZR_CA_AlertRule as _AlertRule
  composition [0..*] of ZR_CA_AlertChannel as _AlertChannel
  composition [0..*] of ZR_CA_PurgeTarget as _PurgeTarget
  composition [0..*] of ZR_CA_Control as _Control
  composition [0..*] of ZR_CA_ControlText as _ControlText
  composition [0..*] of ZR_CA_ControlCheck as _ControlCheck
  composition [0..*] of ZR_CA_Process as _Process
  composition [0..*] of ZR_CA_RegisteredCheck as _RegisteredCheck
  composition [0..*] of ZR_CA_AggregateCheck as _AggregateCheck
  composition [0..*] of ZR_CA_ApprovedTable as _ApprovedTable
  composition [0..*] of ZR_CA_PaymDimText as _PaymDimText
  composition [0..*] of ZR_CA_PaymFeeder as _PaymFeeder
  composition [0..*] of ZR_CA_SchedulerJob as _SchedulerJob
  composition [0..*] of ZR_CA_RunbookLink as _RunbookLink
  composition [0..*] of ZR_CA_CorrelationRule as _CorrelationRule
  composition [0..*] of ZR_CA_LinkLayer as _LinkLayer
  composition [0..*] of ZR_CA_LinkObject as _LinkObject
  composition [0..*] of ZR_CA_LinkField as _LinkField
  composition [0..*] of ZR_CA_Link as _Link
  composition [0..*] of ZR_CA_LinkCondition as _LinkCondition
  composition [0..*] of ZR_CA_LinkActivation as _LinkActivation
  composition [0..*] of ZR_CA_CatalogPackage as _CatalogPackage
  composition [0..*] of ZR_CA_CatalogProcess as _CatalogProcess
  composition [0..*] of ZR_CA_CatalogStep as _CatalogStep
  composition [0..*] of ZR_CA_CatalogTable as _CatalogTable
  composition [0..*] of ZR_CA_CatalogDependency as _CatalogDependency
  composition [0..*] of ZR_CA_CatalogActivation as _CatalogActivation
{
  key 1 as SingletonID,
      max( Chg.LastChangedAt ) as LastChangedAtMax,
      @EndUserText.label: 'Customizing request'
      cast( '' as trkorr ) as TransportRequestID,
      _AlertRule,
      _AlertChannel,
      _PurgeTarget,
      _Control,
      _ControlText,
      _ControlCheck,
      _Process,
      _RegisteredCheck,
      _AggregateCheck,
      _ApprovedTable,
      _PaymDimText,
      _PaymFeeder,
      _SchedulerJob,
      _RunbookLink,
      _CorrelationRule,
      _LinkLayer,
      _LinkObject,
      _LinkField,
      _Link,
      _LinkCondition,
      _LinkActivation,
      _CatalogPackage,
      _CatalogProcess,
      _CatalogStep,
      _CatalogTable,
      _CatalogDependency,
      _CatalogActivation
}
where
  I_Language.Language = $session.system_language
