@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tables under drift control'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Tabname']
define view entity ZC_CD_HckDriftTable
  as projection on ZR_CD_HckDriftTable
{
  key Tabname,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}
