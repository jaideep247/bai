// Artifact: zi_ca_opsexcreopen.ddls.asddls
// Purpose: Re-opened exceptions: an exception episode (current row) whose object, check code and company code had
//          an earlier episode that was resolved (disposition R, first seen before) - raised again after a
//          resolution. Counts the earlier resolved episodes. Index OBJ (area, object key). Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: response-time metrics).
// VERIFY-ADT: self-join of ZCA_OPS_FINDING with a comparison of two columns in the WHERE condition (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Exceptions raised again after resolve'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsExcReopen
  as select from zca_ops_finding as Cur
    inner join   zca_ops_finding as Prv on  Prv.area        = Cur.area
                                        and Prv.object_key  = Cur.object_key
                                        and Prv.object_type = Cur.object_type
                                        and Prv.check_code  = Cur.check_code
                                        and Prv.bukrs       = Cur.bukrs
{
  key Cur.run_id                                            as RunId,
  key Cur.finding_no                                        as FindingNo,
      cast( count( * ) as abap.int4 )                       as EarlierResolved
}
where
      Prv.disposition   =  'R'
  and Prv.first_seen_at <  Cur.first_seen_at
  and Cur.disposition   <> 'S'
  and Cur.disposition   <> 'I'
  and(
       Cur.severity     =  'B'
    or Cur.severity     =  'E'
    or Cur.severity     =  'W'
  )
group by
  Cur.run_id,
  Cur.finding_no
