// Artifact: zi_ca_opsflowevlitm.ddls.asddls
// Purpose: Account flow reconciliation - what existing checks account for at a key date: the items of the last
//          evaluation of each flow at P_KeyDate (ZI_CA_OpsFlowEvlMax) - account, currency (blank = every other currency
//          of the account), tile category, the amount signed as the journal or unsigned (sign rule B: takes the sign
//          of the closing position), items, evaluated / not evaluated (with the reason) and the evaluation's
//          configuration version. No evaluation at the key date = no row: the dashboard shows the account as not
//          evaluated (grey), never as zero. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): TIMESTAMPL compared with an aggregated TIMESTAMPL in an ON condition (as ZI_CA_OpsBrkSnap).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: evaluation items at a date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowEvlItm
  with parameters
    P_KeyDate : abap.dats
  as select from zca_ops_flwevi      as Itm
    inner join   zca_ops_flwevl      as Evl  on  Evl.eval_id = Itm.eval_id
    inner join   ZI_CA_OpsFlowEvlMax as Last on  Last.Area      = Evl.area
                                             and Last.FlowId    = Evl.flow_id
                                             and Last.KeyDate   = Evl.key_date
                                             and Last.LastStart = Evl.started_at
{
  key Evl.eval_id                                           as EvaluationId,
  key Itm.item_no                                           as ItemNo,
      Evl.area                                              as Area,
      Evl.flow_id                                           as FlowId,
      Evl.key_date                                          as KeyDate,
      Evl.cfg_version                                       as ConfigVersion,
      Itm.flow_acct                                         as FlowAccount,
      Itm.bukrs                                             as CompanyCode,
      cast( Itm.currency as abap.char( 5 ) )                as Currency,
      Itm.category                                          as Category,
      cast( case when Itm.sign_rule = '' then Itm.amount else 0 end as abap.dec( 23, 2 ) ) as SignedAmount,
      cast( case when Itm.sign_rule = 'B' then Itm.amount else 0 end as abap.dec( 23, 2 ) ) as UnsignedAmount,
      Itm.item_count                                        as ItemCount,
      cast( case when Itm.status = 'E' then 1 else 0 end as abap.int4 ) as EvaluatedCount,
      cast( case when Itm.status = 'N' then 1 else 0 end as abap.int4 ) as NotEvaluatedCount,
      Itm.status                                            as ItemStatus,
      Itm.source_class                                      as SourceClass,
      Itm.reason                                            as Reason
}
where
  Evl.key_date = $parameters.P_KeyDate
