@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert correlation rules'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'CorrRule']
define view entity ZC_CA_CorrelationRule
  as projection on ZR_CA_CorrelationRule
{
  key Area,
  key CorrRule,
      @Consumption.hidden: true
      SingletonID,
      Description,
      CheckPattern,
      KeyFields,
      KeyPattern,
      WindowMin,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
