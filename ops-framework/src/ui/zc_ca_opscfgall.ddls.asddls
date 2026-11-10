@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alerting and purge targets'
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
      _PurgeTarget : redirected to composition child ZC_CA_PurgeTarget
}
