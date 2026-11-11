@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Runbook links per check'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'MatchField', 'MatchValue']
define view entity ZC_CA_RunbookLink
  as projection on ZR_CA_RunbookLink
{
  key Area,
  key MatchField,
  key MatchValue,
      @Consumption.hidden: true
      SingletonID,
      RunbookUrl,
      FirstAction,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
