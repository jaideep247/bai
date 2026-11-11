// Artifact: zi_ca_opscatactlast.ddls.asddls
// Purpose: Process catalogue activation (2026-11-11): per catalogue process the effective-from date of the
//          activation row that decides today - the latest VALID_FROM on or before the system date of the
//          session (rows of a later date are planned and do not count yet). Nothing stored, read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
// VERIFY-ADT: $session.system_date in the WHERE condition of a grouped view entity (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Catalogue: deciding activation row'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsCatActLast
  as select from zca_ops_catact as Act
{
  key Act.process_id                                        as ProcessId,
      max( Act.valid_from )                                 as ValidFrom
}
where
  Act.valid_from <= $session.system_date
group by
  Act.process_id
