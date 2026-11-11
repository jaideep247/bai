// Artifact: zc_ca_opspilotbrk.ddls.asddls
// Purpose: Consumption view of the share of clearing-account breaks explained (service ZUI_CA_OPS_PILOT): groups,
//          explained, unexplained and the share explained per account and key date. Read access: DCL
//          ZC_CA_OPSPILOTBRK (ZCA_OPS 03 for the area and the company code). Read-only.
// Modification log: 2026-11-11 | Initial version (build F: pilot pack).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Pilot pack: breaks explained'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsPilotBrk
  provider contract transactional_query
  as projection on ZR_CA_OpsPilotBrk
{
  key Area,
  key AccountId,
  key CompanyCode,
  key KeyDate,
      IsLatest,
      GroupCount,
      ExplainedCount,
      UnexplainedCount,
      ExplainedPercent
}
