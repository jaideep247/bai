@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow stages'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'FlowId', 'StageId']
define view entity ZC_CA_FlowStage
  as projection on ZR_CA_FlowStage
{
  key Area,
  key FlowId,
  key StageId,
      @Consumption.hidden: true
      SingletonID,
      Seq,
      Description,
      ExpectFrom,
      ExpectTo,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
