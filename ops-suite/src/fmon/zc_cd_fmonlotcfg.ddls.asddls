@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Returns / NOC lots'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['IfaceId', 'LotType']
define view entity ZC_CD_FmonLotCfg
  as projection on ZR_CD_FmonLotCfg
{
  key IfaceId,
  key LotType,
      @Consumption.hidden: true
      SingletonID,
      HdrTable,
      HdrLotField,
      HdrLinkField,
      ItemTable,
      ItemLotField,
      ItemKeyField,
      ItemStatusField,
      ItemLinkField,
      LinkBy,
      DoneValues,
      NocSlaDays,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _FmonCfgAll : redirected to parent ZC_CD_FmonCfgAll
}
