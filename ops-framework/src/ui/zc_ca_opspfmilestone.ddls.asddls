// Artifact: zc_ca_opspfmilestone.ddls.asddls
// Purpose: Payment file lifecycle - consumption view of the stage timeline of a file (object page facet of ZC_CA_OpsPayFile). Read access: DCL ZC_CA_OPSPFMILESTONE.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment file stage timeline'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsPfMilestone
  provider contract transactional_query
  as projection on ZR_CA_OpsPfMilestone
{
  key Area,
  key FileId,
  key Milestone,
      CompanyCode,
      Sequence,
      IsRequired,
      Status,
      StatusCriticality,
      Outcome,
      DueAt,
      ObservedAt,
      LateMinutes,
      EventKey,
      EvaluatedAt
}
