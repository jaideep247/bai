// Artifact: zr_cd_hckfind.ddls.asddls
// Purpose: Morning report findings (open, plus all of the last 31 days) for the health check
//          dashboard: check, category, check text, metric object key, DIM2 reference, check code,
//          severity, warm-up flag, disposition, owner, due date. Leaf of the drill-down; work the
//          exception in the owned-exceptions app (ZUI_CD_OPS_EXC_O4). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
//                   2026-11-10 | Company code of the finding (company-code isolation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check dashboard - finding'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
define root view entity ZR_CD_HckFind
  as select from    ZI_CD_HckFinding as Find
    left outer join zcd_hck_def      as Def on Def.check_id = Find.CheckId
{
  key Find.RunId,
  key Find.FindingNo,
      Find.PaymentEngineArea,
      Find.CompanyCode,
      Find.CheckId,
      Def.description                                       as CheckText,
      Find.Category,
      Find.ObjectKey,
      Find.Reference,
      Find.CheckCode,
      Find.Severity,
      Find.SeverityCriticality,
      Find.IsWarmup,
      Find.FindingMessage,
      Find.Disposition,
      Find.IsOpen,
      Find.Owner,
      Find.DueDate,
      Find.FirstSeenAt,
      Find.Occurrences,
      Find.CreatedAt,
      Find.CreatedDate,
      cast( 1 as abap.int4 )                                as FindingCount,
      cast( case Find.IsOpen when 'X' then 1 else 0 end as abap.int4 ) as OpenFindingCount
}
