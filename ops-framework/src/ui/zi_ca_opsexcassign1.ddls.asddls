// Artifact: zi_ca_opsexcassign1.ddls.asddls
// Purpose: First assignment of each exception episode: the earliest ASSIGN action of the exceptions app
//          (ZCA_OPS_EXC_HIST, written per row) on any row of the episode - the carry-forward moves an exception to
//          a new row at every run, the episode keeps area, object, check code, company code and first time seen.
//          The time to assign of the response-time metrics. Index FND of the history. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: response-time metrics).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'First assignment of an exception'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsExcAssign1
  as select from zca_ops_exc_hist as Hst
    inner join   zca_ops_finding  as Fnd on  Fnd.run_id     = Hst.run_id
                                         and Fnd.finding_no = Hst.finding_no
{
  key Fnd.area                                              as Area,
  key Fnd.object_type                                       as ObjectType,
  key Fnd.object_key                                        as ObjectKey,
  key Fnd.check_code                                        as CheckCode,
  key Fnd.bukrs                                             as CompanyCode,
  key Fnd.first_seen_at                                     as FirstSeenAt,
      min( Hst.created_at )                                 as FirstAssignedAt
}
where
  Hst.action = 'ASSIGN'
group by
  Fnd.area,
  Fnd.object_type,
  Fnd.object_key,
  Fnd.check_code,
  Fnd.bukrs,
  Fnd.first_seen_at
