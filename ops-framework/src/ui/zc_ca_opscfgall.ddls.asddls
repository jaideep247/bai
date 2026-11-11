@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Processes, checks, alerting, purge targets and controls'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SingletonID']
define root view entity ZC_CA_OpsCfgAll
  provider contract transactional_query
  as projection on ZR_CA_OpsCfgAll
{
  key SingletonID,
      @Consumption.hidden: true
      LastChangedAtMax,
      TransportRequestID,
      _AlertRule : redirected to composition child ZC_CA_AlertRule,
      _AlertChannel : redirected to composition child ZC_CA_AlertChannel,
      _PurgeTarget : redirected to composition child ZC_CA_PurgeTarget,
      _Control : redirected to composition child ZC_CA_Control,
      _ControlText : redirected to composition child ZC_CA_ControlText,
      _ControlCheck : redirected to composition child ZC_CA_ControlCheck,
      _Process : redirected to composition child ZC_CA_Process,
      _RegisteredCheck : redirected to composition child ZC_CA_RegisteredCheck,
      _AggregateCheck : redirected to composition child ZC_CA_AggregateCheck,
      _ApprovedTable : redirected to composition child ZC_CA_ApprovedTable,
      _PaymDimText : redirected to composition child ZC_CA_PaymDimText,
      _PaymFeeder : redirected to composition child ZC_CA_PaymFeeder,
      _SchedulerJob : redirected to composition child ZC_CA_SchedulerJob,
      _RunbookLink : redirected to composition child ZC_CA_RunbookLink,
      _CorrelationRule : redirected to composition child ZC_CA_CorrelationRule,
      _LinkLayer : redirected to composition child ZC_CA_LinkLayer,
      _LinkObject : redirected to composition child ZC_CA_LinkObject,
      _LinkField : redirected to composition child ZC_CA_LinkField,
      _Link : redirected to composition child ZC_CA_Link,
      _LinkCondition : redirected to composition child ZC_CA_LinkCondition,
      _LinkActivation : redirected to composition child ZC_CA_LinkActivation,
      _CatalogPackage : redirected to composition child ZC_CA_CatalogPackage,
      _CatalogProcess : redirected to composition child ZC_CA_CatalogProcess,
      _CatalogStep : redirected to composition child ZC_CA_CatalogStep,
      _CatalogTable : redirected to composition child ZC_CA_CatalogTable,
      _CatalogDependency : redirected to composition child ZC_CA_CatalogDependency,
      _CatalogActivation : redirected to composition child ZC_CA_CatalogActivation,
      _BreakAccount : redirected to composition child ZC_CA_BreakAccount,
      _BreakBucket : redirected to composition child ZC_CA_BreakBucket,
      _BreakRule : redirected to composition child ZC_CA_BreakRule,
      _BreakCondition : redirected to composition child ZC_CA_BreakCondition,
      _PilotBaseline : redirected to composition child ZC_CA_PilotBaseline
}
