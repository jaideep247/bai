// Artifact: zi_ca_opscatval.ddls.asddls
// Purpose: Catalogue milestone "platform-validated" (build O, docs/EVALUATION_AND_COVERAGE.md section 6): per
//          catalogue process the latest validation date and the number of systems it was validated on
//          (ZCA_OPS_CATVAL, recorded by the install harness or an operator with ZCA_OPS_CAT_VALIDATE, never seeded).
//          Nothing stored, read-only.
// Modification log: 2026-11-16 | Initial version (build O: catalogue milestones).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Catalogue: platform validations'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsCatVal
  as select from zca_ops_catval as Val
{
  key Val.process_id                                        as ProcessId,
      max( Val.validated_on )                               as ValidatedOn,
      cast( count( * ) as abap.int4 )                       as ValidatedSystems
}
group by
  Val.process_id
