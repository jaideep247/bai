// Artifact: zi_ca_opsjobexc.ddls.asddls
// Purpose: Open exceptions (disposition O open, A assigned) of the SAP job monitor's findings (object type JOB,
//          ZIF_CA_OPS_JOB_TYPES=>GC_OBJECT_TYPE): one row per finding, joined by the board to the kept job on area,
//          object key (job name / job count), check code and company code - carry-forward keeps one open row per
//          identity. Nothing stored, read-only.
// Modification log: 2026-11-11 | Initial version (SAP job monitor: board ZUI_CA_OPS_JOBS).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Job monitor: open exceptions'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsJobExc
  as select from zca_ops_finding
{
  key run_id      as RunId,
  key finding_no  as FindingNo,
      area        as Area,
      object_key  as ObjectKey,
      check_code  as CheckCode,
      bukrs       as CompanyCode,
      disposition as Disposition,
      owner       as Owner,
      due_date    as DueDate
}
where
      object_type = 'JOB'
  and ( disposition = 'O' or disposition = 'A' )
