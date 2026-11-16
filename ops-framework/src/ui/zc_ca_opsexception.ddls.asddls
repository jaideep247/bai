// Extension point EXC (2026-11-15, build H; config/extension_points.json, docs/EXTENDING_WITH_CUSTOMER_DATA.md):
//          base view; a customer adds its own elements with extend view entity from its package,
//          never by changing this view. Anchors COMPANY, OBJECT, CHECK: their elements stay stable.
// VERIFY-ADT (V153): the extensibility annotations below on 7.58.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Owned exceptions'
@Metadata.allowExtensions: true
@AbapCatalog.extensibility.extensible: true
@AbapCatalog.extensibility.elementSuffix: 'ZOP'
@AbapCatalog.extensibility.allowNewDatasources: true
@AbapCatalog.extensibility.quota.maximumFields: 50
@AbapCatalog.extensibility.quota.maximumBytes: 2000
define root view entity ZC_CA_OpsException
  provider contract transactional_query
  as projection on ZR_CA_OpsException
{
  key RunId,
  key FindingNo,
      Area,
      CompanyCode,
      ObjectType,
      ObjectKey,
      Group1,
      Group2,
      RuleId,
      CheckCode,
      Severity,
      ActionCode,
      Amount,
      Currency,
      Reference,
      Message,
      Disposition,
      Owner,
      DueDate,
      ResolvedBy,
      ResolvedAt,
      Resolution,
      ReasonCode,
      FirstSeenAt,
      Occurrences,
      WaiverUntil,
      WaiverReqBy,
      WaiverReqAt,
      WaiverReason,
      CreatedAt,
      LastChangedAt,
      // Operations response features (2026-11-11): planned downtime, correlation, runbook of the check
      DowntimeId,
      IsPlannedDowntime,
      CorrelationId,
      CorrelationRole,
      // Explainable, versioned results and pilot metrics (2026-11-11)
      ConfigRule,
      ConfigVersion,
      ConfigVersionShort,
      BusinessDate,
      EventAt,
      // Exception contract (2026-11-15, docs/EXCEPTION_CONTRACT.md)
      ItemCount,
      UnknownCount,
      DuplicateAmount,
      DeadlineAt,
      CalendarId,
      Stage,
      ResponsibleUser,
      ResponsibleTeam,
      ResponsibleSource,
      EvidenceKey,
      @EndUserText.label: 'Open correlated exceptions'
      _CorrCount.OpenChildren as CorrelatedOpen,
      @EndUserText.label: 'Runbook'
      _Runbook.RunbookUrl     as RunbookUrl,
      @EndUserText.label: 'First action'
      _Runbook.FirstAction    as FirstAction,
      _History      : redirected to composition child ZC_CA_OpsExcHist,
      _CorrChildren : redirected to ZC_CA_OpsException,
      _CorrParent   : redirected to ZC_CA_OpsException,
      _Evidence
}
