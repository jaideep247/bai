@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitor freshness'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['PaymentEngineArea']
define view entity ZC_CD_MonitorCfg
  as projection on ZR_CD_MonitorCfg
{
  key PaymentEngineArea,
      @Consumption.hidden: true
      SingletonID,
      StaleAfterMin,
      Description,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}
