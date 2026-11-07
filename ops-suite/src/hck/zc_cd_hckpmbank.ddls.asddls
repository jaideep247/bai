@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Factory calendar per house bank'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Flow', 'MethodClass', 'Hbkid']
define view entity ZC_CD_HckPmBank
  as projection on ZR_CD_HckPmBank
{
  key Flow,
  key MethodClass,
  key Hbkid,
      @Consumption.hidden: true
      SingletonID,
      Calendar,
      Description,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}
