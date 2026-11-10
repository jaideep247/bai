@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alerting, purge targets and controls (all)'
define root view entity ZR_CA_OpsCfgAll
  as select from I_Language
    left outer join ZI_CA_OpsCfgChg as Chg on 0 = 0
  composition [0..*] of ZR_CA_AlertRule as _AlertRule
  composition [0..*] of ZR_CA_AlertChannel as _AlertChannel
  composition [0..*] of ZR_CA_PurgeTarget as _PurgeTarget
  composition [0..*] of ZR_CA_Control as _Control
  composition [0..*] of ZR_CA_ControlText as _ControlText
  composition [0..*] of ZR_CA_ControlCheck as _ControlCheck
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
      _ControlCheck
}
where
  I_Language.Language = $session.system_language
