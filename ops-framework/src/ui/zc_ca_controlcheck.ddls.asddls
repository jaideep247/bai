@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Checks covered by a control'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'ControlId', 'CheckArea', 'MatchField', 'MatchValue']
define view entity ZC_CA_ControlCheck
  as projection on ZR_CA_ControlCheck
{
  key Area,
  key ControlId,
  key CheckArea,
  key MatchField,
  key MatchValue,
      @Consumption.hidden: true
      SingletonID,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
