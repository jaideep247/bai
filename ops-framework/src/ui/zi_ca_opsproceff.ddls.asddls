// Artifact: zi_ca_opsproceff.ddls.asddls
// Purpose: Business processes of ZCA_OPS_PROC in effect today (2026-11-11): the row is active and either names
//          no catalogue process or its catalogue process is active today (ZI_CA_OpsCatProcEff); a catalogue
//          process that is not defined counts as inactive (the onboarding check reports CAT_REF_UNKNOWN). The
//          rule of ZCL_CA_OPS_CATALOG=>INACTIVE_ONBOARDED in CDS. Nothing stored, read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business processes in effect today'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsProcEff
  as select from    zca_ops_proc        as Proc
    left outer join ZI_CA_OpsCatProcEff as Cat on Cat.ProcessId = Proc.cat_process
{
  key Proc.area                                             as Area,
  key Proc.process_id                                       as ProcessId,
      Proc.cat_process                                      as CatalogueProcess,
      cast( case
              when Proc.active <> 'X' then ' '
              when Proc.cat_process = ' ' then 'X'
              when Cat.IsActive = 'X' then 'X'
              else ' ' end as abap_boolean )                as IsActive
}
