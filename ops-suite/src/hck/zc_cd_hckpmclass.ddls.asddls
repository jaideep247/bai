@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment method classes'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Flow', 'MethodClass']
define view entity ZC_CD_HckPmClass
  as projection on ZR_CD_HckPmClass
{
  key Flow,
  key MethodClass,
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
