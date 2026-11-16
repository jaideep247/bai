// Artifact: zi_ca_opscatvallast.ddls.asddls
// Purpose: The latest platform validation of a catalogue process (build O, docs/EVALUATION_AND_COVERAGE.md section
//          6): date, system and release as recorded (ZCA_OPS_CATVAL row of the latest date of ZI_CA_OpsCatVal; MAX
//          only decides between two systems validated on the same date). Nothing stored, read-only.
// Modification log: 2026-11-16 | Initial version (build O: catalogue milestones).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Catalogue: latest platform validation'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsCatValLast
  as select from ZI_CA_OpsCatVal as Lst
    inner join   zca_ops_catval  as Val on  Val.process_id   = Lst.ProcessId
                                        and Val.validated_on = Lst.ValidatedOn
{
  key Lst.ProcessId                                         as ProcessId,
      Lst.ValidatedOn                                       as ValidatedOn,
      Lst.ValidatedSystems                                  as ValidatedSystems,
      max( Val.sys_id )                                     as ValidatedSystem,
      max( Val.release_txt )                                as ValidatedRelease,
      max( Val.validated_by )                               as ValidatedBy
}
group by
  Lst.ProcessId,
  Lst.ValidatedOn,
  Lst.ValidatedSystems
