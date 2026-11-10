@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control guidance per language'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Langu', 'Area', 'ControlId']
define view entity ZC_CA_ControlText
  as projection on ZR_CA_ControlText
{
  key Langu,
  key Area,
  key ControlId,
      @Consumption.hidden: true
      SingletonID,
      Guidance,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
