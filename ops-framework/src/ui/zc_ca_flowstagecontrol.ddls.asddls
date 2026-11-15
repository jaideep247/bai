@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow stage controls'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'FlowId', 'StageId', 'CheckArea', 'CheckId']
define view entity ZC_CA_FlowStageControl
  as projection on ZR_CA_FlowStageControl
{
  key Area,
  key FlowId,
  key StageId,
  key CheckArea,
  key CheckId,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
