@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rule assignments'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['RuleGroup', 'RuleId']
define view entity ZC_CD_BtcRule
  as projection on ZR_CD_BtcRule
{
  key RuleGroup,
  key RuleId,
      @Consumption.hidden: true
      SingletonID,
      Seq,
      Severity,
      ActionCode,
      Param1,
      Param2,
      Param3,
      Tolerance,
      WindowDays,
      Active,
      BlocksPosting,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _EbsCfgAll : redirected to parent ZC_CD_EbsCfgAll
}
