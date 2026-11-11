@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue activation'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['ProcessId', 'ValidFrom']
define view entity ZC_CA_CatalogActivation
  as projection on ZR_CA_CatalogActivation
{
  key ProcessId,
  key ValidFrom,
      @Consumption.hidden: true
      SingletonID,
      Active,
      PkgId,
      Reason,
      ApprovedBy,
      ApprovedOn,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
