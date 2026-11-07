@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alerting and parameters (all)'
define root view entity ZR_CD_OpsCfgAll
  as select from I_Language
    left outer join ZI_CD_OpsCfgChg as Chg on 0 = 0
  composition [0..*] of ZR_CD_AlertRule as _AlertRule
  composition [0..*] of ZR_CD_AlertChannel as _AlertChannel
  composition [0..*] of ZR_CD_OpsParam as _OpsParam
  composition [0..*] of ZR_CD_MonitorCfg as _MonitorCfg
{
  key 1 as SingletonID,
      max( Chg.LastChangedAt ) as LastChangedAtMax,
      @EndUserText.label: 'Customizing request'
      cast( '' as trkorr ) as TransportRequestID,
      _AlertRule,
      _AlertChannel,
      _OpsParam,
      _MonitorCfg
}
where
  I_Language.Language = $session.system_language
