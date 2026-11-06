@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status mappings'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SrcId', 'StatusValue']
define view entity ZC_CD_FmonSourceMap
  as projection on ZR_CD_FmonSourceMap
{
  key SrcId,
  key StatusValue,
      @Consumption.hidden: true
      SingletonID,
      Stage,
      Info,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _FmonCfgAll : redirected to parent ZC_CD_FmonCfgAll
}
