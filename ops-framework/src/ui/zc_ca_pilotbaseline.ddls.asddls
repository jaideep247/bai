@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pilot detection baselines'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'CheckId']
define view entity ZC_CA_PilotBaseline
  as projection on ZR_CA_PilotBaseline
{
  key Area,
  key CheckId,
      @Consumption.hidden: true
      SingletonID,
      BaselineMin,
      Source,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
