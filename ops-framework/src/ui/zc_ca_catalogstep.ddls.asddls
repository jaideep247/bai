@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue steps'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['ProcessId', 'StepNo']
define view entity ZC_CA_CatalogStep
  as projection on ZR_CA_CatalogStep
{
  key ProcessId,
  key StepNo,
      @Consumption.hidden: true
      SingletonID,
      StepKind,
      ObjName,
      Description,
      Evidence,
      VerifyRef,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
