@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expected groups'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['CheckId', 'AggId', 'GroupValue']
define view entity ZC_CD_HckAggGroup
  as projection on ZR_CD_HckAggGroup
{
  key CheckId,
  key AggId,
  key GroupValue,
      @Consumption.hidden: true
      SingletonID,
      Description,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}
