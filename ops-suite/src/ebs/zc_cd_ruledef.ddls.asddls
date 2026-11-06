@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rule registry'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['RuleId']
define view entity ZC_CD_RuleDef
  as projection on ZR_CD_RuleDef
{
  key RuleId,
      @Consumption.hidden: true
      SingletonID,
      RuleLevel,
      ClassName,
      DefaultSeverity,
      DefaultAction,
      Description,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _EbsCfgAll : redirected to parent ZC_CD_EbsCfgAll
}
