// Artifact: zi_ca_opscatproceff.ddls.asddls
// Purpose: Effective activation of every catalogue process today (2026-11-11) - the rule of
//          ZCL_CA_OPS_CATALOG=>STATE in CDS: a package switched off (or unknown) makes the process inactive
//          (source P); else the activation row with the latest VALID_FROM on or before today decides (source
//          A, with its reason and approver); else the delivered default DFLT_ACTIVE (source D). Read by the
//          dashboard, the control review and the catalogue list. Nothing stored, read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
// VERIFY-ADT: a CASE over left outer join columns (null when no activation row) cast to ABAP_BOOLEAN (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Catalogue: effective activation today'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsCatProcEff
  as select from    zca_ops_catprc      as Prc
    left outer join zca_ops_catpkg      as Pkg  on  Pkg.pkg_id = Prc.pkg_id
    left outer join ZI_CA_OpsCatActLast as Last on  Last.ProcessId = Prc.process_id
    left outer join zca_ops_catact      as Act  on  Act.process_id = Last.ProcessId
                                                and Act.valid_from = Last.ValidFrom
{
  key Prc.process_id                                        as ProcessId,
      Prc.pkg_id                                            as PackageId,
      cast( case
              when Pkg.active is null or Pkg.active <> 'X' then ' '
              when Act.process_id is not null then Act.active
              else Prc.dflt_active end as abap_boolean )    as IsActive,
      cast( case
              when Pkg.active is null or Pkg.active <> 'X' then 'P'
              when Act.process_id is not null then 'A'
              else 'D' end as abap.char( 1 ) )              as ActivationSource,
      Act.valid_from                                        as ActiveFrom,
      Act.reason                                            as ActivationReason,
      Act.approved_by                                       as ApprovedBy
}
