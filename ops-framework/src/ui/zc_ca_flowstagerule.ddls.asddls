@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow stage rules'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'FlowId', 'RuleSeq']
define view entity ZC_CA_FlowStageRule
  as projection on ZR_CA_FlowStageRule
{
  key Area,
  key FlowId,
  key RuleSeq,
      @Consumption.hidden: true
      SingletonID,
      RuleId,
      StageId,
      LineSource,
      RefType,
      DocType,
      Origin,
      MainTrans,
      SubTrans,
      DebitCredit,
      Description,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
