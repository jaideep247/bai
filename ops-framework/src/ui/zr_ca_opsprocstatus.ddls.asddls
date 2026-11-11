// Artifact: zr_ca_opsprocstatus.ddls.asddls
// Purpose: Active business processes of the dashboard (2026-11-11, process catalogue): one row per business
//          process in effect today (ZCA_OPS_PROC active and its catalogue process active) and company-code slice,
//          with its own KPIs (ZI_CA_OpsProcAgg: checks in effect, flagged, stale, open exceptions, worst status)
//          and what the catalogue knows about it (catalogue process, SAP component, dashboard card, business
//          owner role, typical schedule, active since / reason of the activation). A switched-off process has
//          no row: the dashboard shows only what the customer runs. Nothing stored, read-only (no behaviour).
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Dashboard: active business processes'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CA_OpsProcStatus
  as select from    ZI_CA_OpsProcAgg    as Agg
    inner join      zca_ops_proc        as Proc on  Proc.area       = Agg.Area
                                                and Proc.process_id = Agg.ProcessId
    left outer join zca_ops_catprc      as Cat  on  Cat.process_id = Proc.cat_process
    left outer join ZI_CA_OpsCatProcEff as Eff  on  Eff.ProcessId = Proc.cat_process
{
  key Agg.Area                                              as Area,
  key Agg.ProcessId                                         as ProcessId,
  key Agg.CompanyCode                                       as CompanyCode,
      Proc.description                                      as ProcessName,
      Proc.cat_process                                      as CatalogueProcess,
      Cat.description                                       as CatalogueName,
      Cat.component                                         as Component,
      Cat.dash_card                                         as DashboardCard,
      Cat.owner_role                                        as OwnerRole,
      Cat.schedule                                          as Schedule,
      Eff.ActiveFrom                                        as ActiveFrom,
      Eff.ActivationReason                                  as ActivationReason,
      Agg.CheckCount                                        as CheckCount,
      Agg.FlaggedCount                                      as FlaggedCount,
      Agg.StaleCount                                        as StaleCount,
      Agg.OpenExceptions                                    as OpenExceptions,
      cast( case Agg.StatusCriticality when 1 then 'A'
                                       when 2 then 'W'
                                       else 'H' end as zca_ops_ctl_status ) as Status,
      cast( Agg.StatusCriticality as abap.int1 )            as StatusCriticality,
      // An active process without a check in effect (area-level slice): nothing watches it
      cast( case when Agg.CompanyCode = ' ' and Agg.CheckCount = 0 then 'X'
                 else ' ' end as abap_boolean )             as IsUnmonitored,
      cast( case when Agg.StatusCriticality < 3 or Agg.StaleCount > 0
                   or ( Agg.CompanyCode = ' ' and Agg.CheckCount = 0 ) then 'X'
                 else ' ' end as abap_boolean )             as IsAttention,
      cast( case when Agg.CompanyCode = ' ' then 1 else 0 end as abap.int4 ) as ProcessCount,
      cast( case when Agg.CompanyCode = ' ' and Agg.CheckCount = 0 then 1 else 0 end as abap.int4 ) as UnmonitoredCount
}
