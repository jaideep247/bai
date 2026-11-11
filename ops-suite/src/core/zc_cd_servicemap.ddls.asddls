@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'What a business service covers'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Service', 'Area', 'MatchField', 'MatchValue']
define view entity ZC_CD_ServiceMap
  as projection on ZR_CD_ServiceMap
{
  key Service,
  key Area,
  key MatchField,
  key MatchValue,
      @Consumption.hidden: true
      SingletonID,
      Weight,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}
