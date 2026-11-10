@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purge targets of consumers'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Target']
define view entity ZC_CA_PurgeTarget
  as projection on ZR_CA_PurgeTarget
{
  key Target,
      @Consumption.hidden: true
      SingletonID,
      ClassName,
      ParamArea,
      ParamName,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
