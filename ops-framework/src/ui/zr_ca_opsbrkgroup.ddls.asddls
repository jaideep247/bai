// Artifact: zr_ca_opsbrkgroup.ddls.asddls
// Purpose: Clearing-account breaks (list "Clearing account breaks", service ZUI_CA_OPS_BRK, and the base of the cube
//          ZI_CA_OpsBrkCube): one row per group of a snapshot shown (ZI_CA_OpsBrkSnap) - assignment and currency whose
//          journal lines do not net to zero at the key date - with its variance bucket as a column (text of
//          ZCA_OPS_BRKBKT), explained flag, rule and reason (explainable), age, the lines after the key date that clear
//          it, the reconciliation key and the configuration version of the snapshot. Amounts carry their currency and
//          are never summed across currencies. Drill-down to the lines (_Items). Nothing computed here that the
//          analysis did not store; read-only (no behaviour).
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Clearing account breaks'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsBrkGroup
  as select from    zca_ops_brkgrp   as Grp
    inner join      ZI_CA_OpsBrkSnap as Snap on Snap.SnapshotId = Grp.snap_id
    left outer join zca_ops_brkbkt   as Bkt  on Bkt.bucket = Grp.bucket
  association [0..*] to ZR_CA_OpsBrkItem as _Items on  $projection.SnapshotId = _Items.SnapshotId
                                                   and $projection.GroupNo    = _Items.GroupNo
{
  key Grp.snap_id                                           as SnapshotId,
  key Grp.group_no                                          as GroupNo,
      Snap.Area,
      Snap.AccountId,
      Snap.CompanyCode,
      Snap.GLAccount,
      Snap.Ledger,
      Snap.KeyDate,
      Snap.IsLatest,
      Snap.SnapshotStatus,
      Snap.ConfigVersion,
      Grp.assignment                                        as Assignment,
      Grp.currency                                          as Currency,
      Grp.amount                                            as Amount,
      Grp.line_count                                        as LineCount,
      Grp.first_date                                        as FirstDate,
      Grp.last_date                                         as LastDate,
      Grp.age_days                                          as AgeDays,
      Grp.later_amount                                      as LaterAmount,
      Grp.clears_later                                      as ClearsLater,
      Grp.later_date                                        as LaterDate,
      Grp.bucket                                            as Bucket,
      Bkt.description                                       as BucketText,
      Grp.explained                                         as IsExplained,
      Grp.rule_id                                           as RuleId,
      Grp.reason                                            as Reason,
      Grp.recon_key                                         as ReconKey,
      cast( case Grp.explained when 'X' then 3 else 1 end as abap.int1 ) as BucketCriticality,
      cast( 1 as abap.int4 )                                as GroupCount,
      cast( case Grp.explained when 'X' then 1 else 0 end as abap.int4 ) as ExplainedCount,
      cast( case Grp.explained when 'X' then 0 else 1 end as abap.int4 ) as UnexplainedCount,
      _Items
}
