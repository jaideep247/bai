@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Registered checks'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'CheckId']
define view entity ZC_CA_RegisteredCheck
  as projection on ZR_CA_RegisteredCheck
{
  key Area,
  key CheckId,
      @Consumption.hidden: true
      SingletonID,
      ProcessId,
      Description,
      ClassName,
      SchedGroup,
      BukrsAware,
      Active,
      Seq,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
