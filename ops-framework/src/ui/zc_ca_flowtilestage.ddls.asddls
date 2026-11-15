@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow tiles from stages'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'FlowId', 'Tile', 'StageId', 'Role']
define view entity ZC_CA_FlowTileStage
  as projection on ZR_CA_FlowTileStage
{
  key Area,
  key FlowId,
  key Tile,
  key StageId,
  key Role,
      @Consumption.hidden: true
      SingletonID,
      Side,
      Description,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
