@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approved tables and payment stages'
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
      _ApprovedTable : redirected to composition child ZC_CD_ApprovedTable,
      _PayStage : redirected to composition child ZC_CD_PayStage,
      _Service : redirected to composition child ZC_CD_Service,
      _ServiceMap : redirected to composition child ZC_CD_ServiceMap
}
