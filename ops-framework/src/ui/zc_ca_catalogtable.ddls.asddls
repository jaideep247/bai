@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue tables'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['ProcessId', 'Tabname']
define view entity ZC_CA_CatalogTable
  as projection on ZR_CA_CatalogTable
{
  key ProcessId,
  key Tabname,
      @Consumption.hidden: true
      SingletonID,
      TabRole,
      LinkObject,
      Description,
      Evidence,
      VerifyRef,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
