@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue packages'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['PkgId']
define view entity ZC_CA_CatalogPackage
  as projection on ZR_CA_CatalogPackage
{
  key PkgId,
      @Consumption.hidden: true
      SingletonID,
      PkgKind,
      PkgRank,
      IdPrefix,
      MonArea,
      Description,
      Owner,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
