@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert rules'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['RuleId']
define view entity ZC_CA_AlertRule
  as projection on ZR_CA_AlertRule
{
  key RuleId,
      @Consumption.hidden: true
      SingletonID,
      Area,
      MinSeverity,
      RulePattern,
      CheckPattern,
      Group1Pattern,
      Group2Pattern,
      BukrsPattern,
      MinRag,
      OnAbort,
      Channel,
      Destination,
      Digest,
      MaxItems,
      ThrottleMin,
      QuietFrom,
      QuietTo,
      EscalateAfter,
      EscalationDest,
      EscOverride,
      EscAfterMin,
      EscRepeatMin,
      EscMaxCount,
      EscSeverity,
      Active,
      TemplateId,
      ShowAmounts,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
