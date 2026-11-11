@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry layers'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['LayerId']
define view entity ZC_CA_LinkLayer
  as projection on ZR_CA_LinkLayer
{
  key LayerId,
      @Consumption.hidden: true
      SingletonID,
      LayerKind,
      LayerRank,
      IdPrefix,
      Description,
      Owner,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
