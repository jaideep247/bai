@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank transaction code roles'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Flow', 'MethodClass', 'Scheme', 'BtcCode']
define view entity ZC_CD_HckBtcRole
  as projection on ZR_CD_HckBtcRole
{
  key Flow,
  key MethodClass,
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
