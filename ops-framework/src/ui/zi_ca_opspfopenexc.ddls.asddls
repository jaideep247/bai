// Artifact: zi_ca_opspfopenexc.ddls.asddls
// Purpose: Payment file lifecycle - the open exceptions of the payment file check per object key (ZCA_OPS_FINDING,
//          object type PAYFILE, disposition open or assigned): their number, the worst severity, and the responsible
//          user / team of the exception contract (from the configuration at finding time) and the assigned owner.
//          The worklist joins it on the file's object key (file type / native key / currency). Read-only.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Open exceptions of payment files'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsPfOpenExc
  as select from zca_ops_finding as Fnd
{
  key Fnd.area                                              as Area,
  key Fnd.object_key                                        as ObjectKey,
      count( * )                                            as OpenExceptions,
      max( case Fnd.severity when 'B' then 4 when 'E' then 3 when 'W' then 2 else 1 end ) as SeverityRank,
      max( Fnd.check_code )                                 as CheckCode,
      max( Fnd.resp_user )                                  as ResponsibleUser,
      max( Fnd.resp_team )                                  as ResponsibleTeam,
      max( Fnd.owner )                                      as AssignedTo
}
where
       Fnd.object_type = 'PAYFILE'
  and(
       Fnd.disposition = 'O'
    or Fnd.disposition = 'A'
  )
group by
  Fnd.area,
  Fnd.object_key
