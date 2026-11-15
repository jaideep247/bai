// Artifact: zr_ca_opscatalogue.ddls.asddls
// Purpose: The process catalogue with today's activation (2026-11-11): every catalogue process of every package
//          - package, SAP component, dashboard card, business owner role, typical schedule, evidence / VERIFY
//          item of its definition - with its effective state (ZI_CA_OpsCatProcEff: active, source A activation
//          row / D default / P package off, active since, reason, approver) and the checks in effect that
//          monitor it (ZI_CA_OpsCatMon). Steps, tables and dependencies are in the configuration app. Nothing
//          stored, read-only (no behaviour definition).
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
// Extension point CATALOGUE (2026-11-15, build H; config/extension_points.json, docs/EXTENDING_WITH_CUSTOMER_DATA.md):
//          base view; a customer adds its own elements with extend view entity from its package,
//          never by changing this view. Anchors PROCESS: their elements stay stable.
// VERIFY-ADT (V153): the extensibility annotations below on 7.58.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue with activation'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
@AbapCatalog.extensibility.extensible: true
@AbapCatalog.extensibility.elementSuffix: 'ZOP'
@AbapCatalog.extensibility.allowNewDatasources: true
@AbapCatalog.extensibility.dataSources: [ 'Prc' ]
@AbapCatalog.extensibility.quota.maximumFields: 50
@AbapCatalog.extensibility.quota.maximumBytes: 2000
define root view entity ZR_CA_OpsCatalogue
  as select from    zca_ops_catprc      as Prc
    left outer join zca_ops_catpkg      as Pkg on Pkg.pkg_id = Prc.pkg_id
    left outer join ZI_CA_OpsCatProcEff as Eff on Eff.ProcessId = Prc.process_id
    left outer join ZI_CA_OpsCatMon     as Mon on Mon.ProcessId = Prc.process_id
{
  key Prc.process_id                                        as ProcessId,
      Prc.pkg_id                                            as PackageId,
      Pkg.pkg_kind                                          as PackageKind,
      Pkg.description                                       as PackageName,
      Prc.description                                       as ProcessName,
      Prc.component                                         as Component,
      Prc.dash_card                                         as DashboardCard,
      Prc.owner_role                                        as OwnerRole,
      Prc.schedule                                          as Schedule,
      Prc.evidence                                          as Evidence,
      Prc.verify_ref                                        as VerifyRef,
      Prc.dflt_active                                       as IsDefaultActive,
      Eff.IsActive                                          as IsActive,
      cast( case Eff.IsActive when 'X' then 3 else 0 end as abap.int1 ) as ActiveCriticality,
      Eff.ActivationSource                                  as ActivationSource,
      Eff.ActiveFrom                                        as ActiveFrom,
      Eff.ActivationReason                                  as ActivationReason,
      Eff.ApprovedBy                                        as ApprovedBy,
      cast( coalesce( Mon.MonitoringChecks, 0 ) as abap.int4 ) as MonitoringChecks,
      Prc.seq                                               as Seq
}
