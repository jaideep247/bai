@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue dependencies'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['ProcessId', 'PredId']
define view entity ZC_CA_CatalogDependency
  as projection on ZR_CA_CatalogDependency
{
  key ProcessId,
  key PredId,
      @Consumption.hidden: true
      SingletonID,
      DepKind,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
