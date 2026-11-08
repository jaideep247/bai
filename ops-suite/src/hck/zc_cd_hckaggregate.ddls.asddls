@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Generic aggregates'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['CheckId', 'AggId']
define view entity ZC_CD_HckAggregate
  as projection on ZR_CD_HckAggregate
{
  key CheckId,
  key AggId,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Tabname,
      AggFunc,
      SumField,
      DateField,
      DateMode,
      AgeDaysMin,
      GroupField,
      ExpectedGroups,
      Cond1Field,
      Cond1Op,
      Cond1Value,
      Cond2Field,
      Cond2Op,
      Cond2Value,
      Cond3Field,
      Cond3Op,
      Cond3Value,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}
