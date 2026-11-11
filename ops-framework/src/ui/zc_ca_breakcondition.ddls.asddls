@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis rule conditions'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'RuleId', 'CondNo']
define view entity ZC_CA_BreakCondition
  as projection on ZR_CA_BreakCondition
{
  key Area,
  key RuleId,
  key CondNo,
      @Consumption.hidden: true
      SingletonID,
      CondKind,
      Field,
      Operator,
      CondValue,
      LinkId,
      MinCount,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
