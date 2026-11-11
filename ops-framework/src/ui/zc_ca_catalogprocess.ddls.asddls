@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue processes'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['ProcessId']
define view entity ZC_CA_CatalogProcess
  as projection on ZR_CA_CatalogProcess
{
  key ProcessId,
      @Consumption.hidden: true
      SingletonID,
      PkgId,
      Description,
      Component,
      DashCard,
      OwnerRole,
      Schedule,
      DfltActive,
      Evidence,
      VerifyRef,
      Seq,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
