@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry link conditions'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['LinkId', 'CondNo']
define view entity ZC_CA_LinkCondition
  as projection on ZR_CA_LinkCondition
{
  key LinkId,
  key CondNo,
      @Consumption.hidden: true
      SingletonID,
      CondKind,
      FromRef,
      ToRef,
      CondValue,
      Transform,
      TransformArg,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
