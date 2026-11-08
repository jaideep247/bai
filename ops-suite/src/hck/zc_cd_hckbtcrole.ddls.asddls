@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank code roles (lifecycle and reconciliation)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Usage', 'Scope', 'Scheme', 'BtcCode']
define view entity ZC_CD_HckBtcRole
  as projection on ZR_CD_HckBtcRole
{
  key Usage,
  key Scope,
  key Scheme,
  key BtcCode,
      @Consumption.hidden: true
      SingletonID,
      Role,
      CompareAmount,
      Description,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}
