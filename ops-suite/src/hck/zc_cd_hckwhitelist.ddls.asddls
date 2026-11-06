@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Aggregate table whitelist'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Tabname']
define view entity ZC_CD_HckWhitelist
  as projection on ZR_CD_HckWhitelist
{
  key Tabname,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Active,
      ApprovedBy,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}
