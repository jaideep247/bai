@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS rules and mapping'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SingletonID']
define root view entity ZC_CD_EbsCfgAll
  provider contract transactional_query
  as projection on ZR_CD_EbsCfgAll
{
  key SingletonID,
      @Consumption.hidden: true
      LastChangedAtMax,
      TransportRequestID,
      _BtcMap : redirected to composition child ZC_CD_BtcMap,
      _BtcRule : redirected to composition child ZC_CD_BtcRule,
      _RuleDef : redirected to composition child ZC_CD_RuleDef,
      _HouseBankAcct : redirected to composition child ZC_CD_HouseBankAcct,
      _FlowPattern : redirected to composition child ZC_CD_FlowPattern,
      _ReasonMap : redirected to composition child ZC_CD_ReasonMap,
      _EbsLookup : redirected to composition child ZC_CD_EbsLookup
}
