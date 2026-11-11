// Artifact: zi_ca_opsbrkkeymax.ddls.asddls
// Purpose: Break analysis: the latest key date analysed per account (ZCA_OPS_BRKRUN, index ACC) - the snapshot the
//          overview card, the check and the pilot metrics read. Aggregated on the database, read-only.
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis: latest key date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsBrkKeyMax
  as select from zca_ops_brkrun
{
  key area                                                  as Area,
  key acct_id                                               as AccountId,
      max( key_date )                                       as LastKeyDate
}
group by
  area,
  acct_id
