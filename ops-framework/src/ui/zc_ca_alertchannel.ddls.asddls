@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert channels'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Channel']
define view entity ZC_CA_AlertChannel
  as projection on ZR_CA_AlertChannel
{
  key Channel,
      @Consumption.hidden: true
      SingletonID,
      ClassName,
      Destination,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
