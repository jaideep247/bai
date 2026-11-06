@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'File monitoring setup'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SingletonID']
define root view entity ZC_CD_FmonCfgAll
  provider contract transactional_query
  as projection on ZR_CD_FmonCfgAll
{
  key SingletonID,
      @Consumption.hidden: true
      LastChangedAtMax,
      TransportRequestID,
      _FmonIface : redirected to composition child ZC_CD_FmonIface,
      _FmonSla : redirected to composition child ZC_CD_FmonSla,
      _FmonSource : redirected to composition child ZC_CD_FmonSource,
      _FmonSourceMap : redirected to composition child ZC_CD_FmonSourceMap,
      _FmonCheck : redirected to composition child ZC_CD_FmonCheck,
      _FmonLotCfg : redirected to composition child ZC_CD_FmonLotCfg,
      _FmonCalendar : redirected to composition child ZC_CD_FmonCalendar
}
