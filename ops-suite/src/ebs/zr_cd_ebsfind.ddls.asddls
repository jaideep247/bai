// Artifact: zr_cd_ebsfind.ddls.asddls
// Purpose: EBS findings (open, plus all of the last 31 days) for the EBS validation dashboard:
//          findings by rule (with the rule text of ZCD_EBS_RULE_DEF) and severity, BAI code,
//          category, bank key, statement and line key, masked account (statement findings), open
//          flag, owner and due date. The leaf of the drill-down run / statement / line -> finding,
//          and the second analytical list page "EBS findings". Work the exception in the
//          owned-exceptions app (ZUI_CD_OPS_EXC_O4). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS validation dashboard - finding'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
define root view entity ZR_CD_EbsFind
  as select from ZI_CD_EbsFinding
  association [0..1] to zcd_ebs_rule_def as _RuleDef on $projection.RuleId = _RuleDef.rule_id
{
  key RunId,
  key FindingNo,
      PaymentEngineArea,
      ObjectType,
      ObjectKey,
      StatementSource,
      StmtObjectKey,
      LineObjectKey,
      LineNo,
      BaiCode,
      Category,
      BankKey,
      AccountMasked,
      RuleId,
      _RuleDef.description                                  as RuleText,
      CheckCode,
      Severity,
      SeverityCriticality,
      FindingAction,
      // DEC amount of the finding (signed: debit negative) in Currency - slice by currency
      Amount,
      Currency,
      Reference,
      FindingMessage,
      Disposition,
      IsOpen,
      IsPostingIncomplete,
      IsDuplicate,
      Owner,
      DueDate,
      FirstSeenAt,
      Occurrences,
      CreatedAt,
      CreatedDate,
      cast( 1 as abap.int4 )                                as FindingCount,
      cast( case IsOpen when 'X' then 1 else 0 end as abap.int4 ) as OpenFindingCount
}
