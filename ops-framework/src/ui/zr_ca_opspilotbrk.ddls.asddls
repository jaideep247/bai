// Artifact: zr_ca_opspilotbrk.ddls.asddls
// Purpose: Pilot pack - share of clearing-account breaks explained (service ZUI_CA_OPS_PILOT, export): per area,
//          account, company code and key date of the snapshots shown (ZR_CA_OpsBrkGroup) the groups, the explained
//          groups (a bucket other than OTHER) and the unexplained ones; the share explained = ExplainedCount /
//          GroupCount (a count share - amounts stay per currency in the break list). Aggregated on the database,
//          read-only.
// Modification log: 2026-11-11 | Initial version (build F: pilot pack).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pilot pack: breaks explained'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsPilotBrk
  as select from ZR_CA_OpsBrkGroup
{
  key Area,
  key AccountId,
  key CompanyCode,
  key KeyDate,
      IsLatest,
      cast( sum( GroupCount ) as abap.int4 )                as GroupCount,
      cast( sum( ExplainedCount ) as abap.int4 )            as ExplainedCount,
      cast( sum( UnexplainedCount ) as abap.int4 )          as UnexplainedCount,
      cast( division( sum( ExplainedCount ) * 100, sum( GroupCount ), 1 ) as abap.dec( 5, 1 ) ) as ExplainedPercent
}
group by
  Area,
  AccountId,
  CompanyCode,
  KeyDate,
  IsLatest
