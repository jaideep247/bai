@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model dimension texts'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Langu', 'Dimension', 'DimValue']
define view entity ZC_CA_PaymDimText
  as projection on ZR_CA_PaymDimText
{
  key Langu,
  key Dimension,
  key DimValue,
      @Consumption.hidden: true
      SingletonID,
      Text,
      Seq,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
