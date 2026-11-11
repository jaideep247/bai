// Artifact: zi_ca_opsbrkrunmax.ddls.asddls
// Purpose: Break analysis: the last run of each account and key date (latest start of ZCA_OPS_BRKRUN) - a key date
//          analysed twice shows the newer snapshot only. Aggregated on the database, read-only.
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis: last run per key date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsBrkRunMax
  as select from zca_ops_brkrun
{
  key area                                                  as Area,
  key acct_id                                               as AccountId,
  key key_date                                              as KeyDate,
      max( started_at )                                     as LastStart
}
group by
  area,
  acct_id,
  key_date
