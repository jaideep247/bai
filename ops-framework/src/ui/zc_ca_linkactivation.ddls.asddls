@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry activation overrides'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['TargetKind', 'TargetId']
define view entity ZC_CA_LinkActivation
  as projection on ZR_CA_LinkActivation
{
  key TargetKind,
  key TargetId,
      @Consumption.hidden: true
      SingletonID,
      LayerId,
      Active,
      Reason,
      Owner,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
