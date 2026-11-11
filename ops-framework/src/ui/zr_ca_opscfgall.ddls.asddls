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
      _PaymFeeder
}
where
  I_Language.Language = $session.system_language
