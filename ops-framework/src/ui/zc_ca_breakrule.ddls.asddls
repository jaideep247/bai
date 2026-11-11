@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis bucket rules'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'RuleId']
define view entity ZC_CA_BreakRule
  as projection on ZR_CA_BreakRule
{
  key Area,
  key RuleId,
      @Consumption.hidden: true
      SingletonID,
      LayerId,
      Seq,
      Bucket,
      AcctPattern,
      Reason,
      Description,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
