@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment method classes (typed ZPMC)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Version', 'Flow', 'PayMethod', 'HouseBank']
define view entity ZC_CD_MapMethodClass
  as projection on ZR_CD_MapMethodClass
{
  key Version,
  key Flow,
  key PayMethod,
  key HouseBank,
      @Consumption.hidden: true
      SingletonID,
      MethodClass,
      AgeBasis,
      Calendar,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}
