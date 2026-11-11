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
      _PaymFeeder : redirected to composition child ZC_CA_PaymFeeder
}
