@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'House bank accounts'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Bukrs', 'Hbkid', 'Hktid']
define view entity ZC_CD_HouseBankAcct
  as projection on ZR_CD_HouseBankAcct
{
  key Bukrs,
  key Hbkid,
  key Hktid,
      @Consumption.hidden: true
      SingletonID,
      AccountNo,
      BankKey,
      Format,
      FlowDefault,
      Currency,
      GlAccount,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _EbsCfgAll : redirected to parent ZC_CD_EbsCfgAll
}
