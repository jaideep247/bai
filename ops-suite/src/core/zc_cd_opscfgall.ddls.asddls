@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alerting and parameters'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SingletonID']
define root view entity ZC_CD_OpsCfgAll
  provider contract transactional_query
  as projection on ZR_CD_OpsCfgAll
{
  key SingletonID,
      @Consumption.hidden: true
      LastChangedAtMax,
      TransportRequestID,
      _AlertRule : redirected to composition child ZC_CD_AlertRule,
      _AlertChannel : redirected to composition child ZC_CD_AlertChannel,
      _OpsParam : redirected to composition child ZC_CD_OpsParam,
      _MonitorCfg : redirected to composition child ZC_CD_MonitorCfg
}
