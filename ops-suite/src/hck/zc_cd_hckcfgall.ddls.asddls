@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Health check setup'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SingletonID']
define root view entity ZC_CD_HckCfgAll
  provider contract transactional_query
  as projection on ZR_CD_HckCfgAll
{
  key SingletonID,
      @Consumption.hidden: true
      LastChangedAtMax,
      TransportRequestID,
      _HckCheckDef : redirected to composition child ZC_CD_HckCheckDef,
      _HckThreshold : redirected to composition child ZC_CD_HckThreshold,
      _HckAggregate : redirected to composition child ZC_CD_HckAggregate,
      _HckDriftTable : redirected to composition child ZC_CD_HckDriftTable,
      _HckWhitelist : redirected to composition child ZC_CD_HckWhitelist,
      _JobCycle : redirected to composition child ZC_CD_JobCycle,
      _JobStep : redirected to composition child ZC_CD_JobStep
}
