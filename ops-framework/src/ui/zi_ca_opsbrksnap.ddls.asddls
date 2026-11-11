// Artifact: zi_ca_opsbrksnap.ddls.asddls
// Purpose: Break analysis snapshots shown: one per account and key date (its last run, ZI_CA_OpsBrkRunMax), with the
//          flag IsLatest for the latest key date of the account (ZI_CA_OpsBrkKeyMax). Header values of ZCA_OPS_BRKRUN:
//          company code, G/L clearing account, ledger, window, status, configuration version, counts. Read-only.
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
// VERIFY-ADT: TIMESTAMPL compared with an aggregated TIMESTAMPL in the ON condition (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis: snapshots'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsBrkSnap
  as select from    zca_ops_brkrun     as Run
    inner join      ZI_CA_OpsBrkRunMax as Last on  Last.Area      = Run.area
                                               and Last.AccountId = Run.acct_id
                                               and Last.KeyDate   = Run.key_date
                                               and Last.LastStart = Run.started_at
    left outer join ZI_CA_OpsBrkKeyMax as Kd   on  Kd.Area      = Run.area
                                               and Kd.AccountId = Run.acct_id
{
  key Run.snap_id                                           as SnapshotId,
      Run.area                                              as Area,
      Run.acct_id                                           as AccountId,
      Run.bukrs                                             as CompanyCode,
      Run.hkont                                             as GLAccount,
      Run.ledger                                            as Ledger,
      Run.key_date                                          as KeyDate,
      Run.from_date                                         as FromDate,
      Run.to_date                                           as ToDate,
      Run.status                                            as SnapshotStatus,
      Run.cfg_version                                       as ConfigVersion,
      Run.group_count                                       as GroupCount,
      Run.item_count                                        as LineCount,
      Run.other_count                                       as OtherCount,
      Run.started_at                                        as StartedAt,
      cast( case when Run.key_date = Kd.LastKeyDate then 'X' else ' ' end as abap_boolean ) as IsLatest
}
