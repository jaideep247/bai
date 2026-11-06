@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Checks'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['CheckId']
define view entity ZC_CD_HckCheckDef
  as projection on ZR_CD_HckCheckDef
{
  key CheckId,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Category,
      ClassName,
      Active,
      Seq,
      Priority,
      Param1,
      Param2,
      Param3,
      Param4,
      PackageSize,
      TimeoutSec,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}
