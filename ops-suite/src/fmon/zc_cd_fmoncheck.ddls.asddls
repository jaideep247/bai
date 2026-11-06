@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Checks'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['CheckId']
define view entity ZC_CD_FmonCheck
  as projection on ZR_CD_FmonCheck
{
  key CheckId,
      @Consumption.hidden: true
      SingletonID,
      ClassName,
      Severity,
      Active,
      Params,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _FmonCfgAll : redirected to parent ZC_CD_FmonCfgAll
}
