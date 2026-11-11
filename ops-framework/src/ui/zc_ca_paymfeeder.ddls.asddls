@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Feeder systems of the payment model'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Feeder']
define view entity ZC_CA_PaymFeeder
  as projection on ZR_CA_PaymFeeder
{
  key Feeder,
      @Consumption.hidden: true
      SingletonID,
      Description,
      UrlTemplate,
      RefVisible,
      Seq,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
