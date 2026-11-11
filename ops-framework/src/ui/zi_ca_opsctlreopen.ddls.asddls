// Artifact: zi_ca_opsctlreopen.ddls.asddls
// Purpose: Findings of a signed-off slice that change the picture after the sign-off (explainable, versioned
//          results): every live finding of the control and business date (ZI_CA_OpsCtlFind) recorded after the
//          sign-off (ZCA_OPS_REVIEW-REVIEWED_AT), compared with the row it replaced - the earlier row of the same
//          exception (area, object type, key, check code, company code) superseded by the finding's run
//          (SUPERSEDED_BY = RUN_ID). Flags per finding (rules of ZCL_CA_OPS_REVIEW_POLICY=>REOPEN_REASON):
//          NewFlag - first seen after the sign-off (a new exception); StatusFlag - severity differs from the
//          replaced row; AmountFlag - amount or currency differs; ConfigFlag - produced by another configuration
//          version (both versions known). A finding raised again unchanged sets no flag: it does not reopen the
//          sign-off. Read-only.
// Modification log: 2026-11-11 | Initial version (explainable, versioned results).
// VERIFY-ADT: left outer join on a column of the same table compared with a key of the joined view (7.58);
//             PlanViz CTL-09: the replaced row is read by index OBJ (MANDT, AREA, OBJECT_KEY) with the sign-offs
//             of the date as driver - only findings created after a sign-off are compared.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: changes after sign-off'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsCtlReopen
  as select from    ZI_CA_OpsCtlFind as F
    inner join      zca_ops_review   as Rev  on  Rev.area          = F.Area
                                             and Rev.control_id    = F.ControlId
                                             and Rev.business_date = F.BusinessDate
                                             and Rev.bukrs         = F.CompanyCode
    left outer join zca_ops_finding  as Prev on  Prev.area          = F.FindingArea
                                             and Prev.object_key    = F.ObjectKey
                                             and Prev.superseded_by = F.RunId
                                             and Prev.object_type   = F.ObjectType
                                             and Prev.check_code    = F.CheckCode
                                             and Prev.bukrs         = F.CompanyCode
{
  key F.Area,
  key F.ControlId,
  key F.BusinessDate,
  key F.CompanyCode,
  key F.MatchField,
  key F.MatchValue,
  key F.RunId,
  key F.FindingNo,
      F.CreatedAt,
      Rev.reviewed_at                                       as ReviewedAt,
      cast( case when F.FirstSeenAt > Rev.reviewed_at then 1 else 0 end as abap.int4 ) as NewFlag,
      cast( case when F.FirstSeenAt > Rev.reviewed_at then 0
                 when Prev.severity is null then 0
                 when Prev.severity <> F.Severity then 1
                 else 0 end as abap.int4 )                  as StatusFlag,
      cast( case when F.FirstSeenAt > Rev.reviewed_at then 0
                 when Prev.amount is null then 0
                 when Prev.amount <> F.Amount or Prev.currency <> F.Currency then 1
                 else 0 end as abap.int4 )                  as AmountFlag,
      cast( case when F.FirstSeenAt > Rev.reviewed_at then 0
                 when Prev.cfg_version is null then 0
                 when Prev.cfg_version = ' ' or F.ConfigVersion = ' ' then 0
                 when Prev.cfg_version <> F.ConfigVersion then 1
                 else 0 end as abap.int4 )                  as ConfigFlag
}
where
      F.CreatedAt          > Rev.reviewed_at
  and Rev.status_at_review <> ' '
