@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Aggregate checks (no code)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'CheckId', 'AggId']
define view entity ZC_CA_AggregateCheck
  as projection on ZR_CA_AggregateCheck
{
  key Area,
  key CheckId,
  key AggId,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Tabname,
      AggFunc,
      DateField,
      MinAgeDays,
      BukrsField,
      StatusField,
      StatusOp,
      StatusValue,
      CondField,
      CondOp,
      CondValue,
      Amber,
      Red,
      CheckCode,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
