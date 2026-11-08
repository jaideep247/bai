@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment method classes (and house-bank calendars)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Flow', 'MethodClass', 'Hbkid']
define view entity ZC_CD_HckPmClass
  as projection on ZR_CD_HckPmClass
{
  key Flow,
  key MethodClass,
  key Hbkid,
      @Consumption.hidden: true
      SingletonID,
      PayMethods,
      AgeBasis,
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
