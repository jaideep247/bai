// Artifact: zi_cd_trxitemflow.ddls.asddls
// Purpose: One row per payment-engine open item with a FIN number (ZI_CD_TrxItem, 400-day
//          retention) with its canonical payment outcome valid at the "as of" instant
//          (ZI_CD_PayOutcomeItm: FIN + company code + payment document, written by the 5-minute
//          snapshot from the evaluator ZIF_CD_OPS_PAY_OUTCOME - the verdict of the morning report
//          check A_INFLIGHT and the payment trace) and the evidence shown next to it: latest payment
//          run (one DPAYH row), cheque, bank line / encashment date, return / NOC reason. The flow
//          bucket is the canonical outcome, never re-derived from evidence rows here:
//            REVERSED       clearing reason 05 (the item was cleared by a reversal)
//            <outcome>      CLEARED / RETURNED / RETRIEVED / VOIDED / PENDING / IN_FLIGHT /
//                           UNDETERMINED / INCONSISTENT / AMBIGUOUS / REVERSED (ZCD_PAY_OUTCOME)
//            NOT_EVALUATED  payment run or cheque, but no outcome valid at the instant (method of
//                           no watched class, before go-live, snapshot not yet run)
//            OFFSET         clearing document without payment run (cleared by offset)
//            POSTED         open (no clearing document)
//          A bank line or encashment line alone is never "settled" (review defect of ZR_CD_TrxFlow).
//          The single place of the bucket rule: ZR_CD_TrxFlow (date filter), ZR_CD_TrxKpi and
//          ZR_CD_TrxProblem (current outcome) select from here. Read-only.
// Modification log: 2026-11-07 | Initial version (canonical outcome; bucket and measures moved here from
//                   ZR_CD_TrxFlow).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - item with canonical outcome'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #MIXED }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxItemFlow
  with parameters
    P_AsOfDate : abap.dats,
    P_AsOfTime : abap.tims
  as select from    ZI_CD_TrxItem       as Item
    left outer join ZI_CD_PayOutcomeItm( P_AsOfDate : $parameters.P_AsOfDate,
                                         P_AsOfTime : $parameters.P_AsOfTime ) as Out
                                         on  Out.FinId       = Item.FinId
                                         and Out.CompanyCode = Item.CompanyCode
                                         and Out.ClearingDoc = Item.ClearingDoc
    left outer join ZI_CD_TrxItemPay    as Pay  on  Pay.DocumentNo = Item.DocumentNo
                                       and Pay.RepetitionItem = Item.RepetitionItem
                                       and Pay.ItemNo = Item.ItemNo
                                       and Pay.SubItem = Item.SubItem
    left outer join ZI_CD_TrxItemChq    as Chq  on  Chq.DocumentNo = Item.DocumentNo
                                       and Chq.RepetitionItem = Item.RepetitionItem
                                       and Chq.ItemNo = Item.ItemNo
                                       and Chq.SubItem = Item.SubItem
    left outer join ZI_CD_TrxItemBank   as Bank on  Bank.DocumentNo = Item.DocumentNo
                                       and Bank.RepetitionItem = Item.RepetitionItem
                                       and Bank.ItemNo = Item.ItemNo
                                       and Bank.SubItem = Item.SubItem
    left outer join ZI_CD_TrxItemEnc    as Enc  on  Enc.DocumentNo = Item.DocumentNo
                                       and Enc.RepetitionItem = Item.RepetitionItem
                                       and Enc.ItemNo = Item.ItemNo
                                       and Enc.SubItem = Item.SubItem
    left outer join ZI_CD_TrxItemRet    as Ret  on  Ret.DocumentNo = Item.DocumentNo
                                       and Ret.RepetitionItem = Item.RepetitionItem
                                       and Ret.ItemNo = Item.ItemNo
                                       and Ret.SubItem = Item.SubItem
    left outer join ZI_CD_TrxItemNoc    as Noc  on  Noc.DocumentNo = Item.DocumentNo
                                       and Noc.RepetitionItem = Item.RepetitionItem
                                       and Noc.ItemNo = Item.ItemNo
                                       and Noc.SubItem = Item.SubItem
{
  key Item.DocumentNo,
  key Item.RepetitionItem,
  key Item.ItemNo,
  key Item.SubItem,
      Item.PaymentEngineArea,
      Item.FinId,
      Item.BillPlanId,
      Item.CompanyCode,
      Item.PostingDate,
      case when Item.PostingDate = $session.system_date
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsToday,
      Item.PaymentMethod,
      Item.Direction,
      Item.LocalCurrency,
      @Semantics.amount.currencyCode: 'LocalCurrency'
      Item.AmountInLocalCurrency,
      Item.Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Item.Amount,
      Item.ClearingStatus,
      Item.ClearingDoc,
      Item.ClearingDate,
      Item.ClearingReason,
      Pay.LastRunDate,
      Pay.LastRunId,
      Pay.ValueDate,
      Pay.PaymentStatus,
      Chq.ChequeNo,
      Chq.ChequeHouseBank,
      Bank.LastBookingDate                                  as SettlementDate,
      Enc.EncashDate,
      Ret.ReturnReason,
      Noc.NocReason,
      // ---------------------------------------------------------------- canonical outcome
      Out.Outcome,
      Out.Finding                                           as OutcomeFinding,
      Out.EvidenceKind                                      as OutcomeEvidenceKind,
      Out.EvidenceRef                                       as OutcomeEvidenceRef,
      Out.ValidFrom                                         as OutcomeValidFrom,
      Out.RunDate                                           as OutcomeRunDate,
      Out.RunId                                             as OutcomeRunId,
      Out.SourceCount                                       as OutcomeSourceCount,
      cast( case
              when Item.ClearingReason = '05'                         then 'REVERSED'
              when Out.Outcome is not null                            then Out.Outcome
              when Pay.LastRunDate is not null or Chq.ChequeCount > 0 then 'NOT_EVALUATED'
              when Item.ClearingDoc <> ' '                            then 'OFFSET'
              else 'POSTED' end as abap.char( 20 ) )        as FlowBucket,
      // UI criticality: 1 red (returned, retrieved, voided, reversed, inconsistent, ambiguous),
      // 2 yellow (undetermined, not evaluated), 3 green (cleared), 0 in flight / open
      cast( case
              when Item.ClearingReason = '05'                         then 1
              when Out.Outcome = 'RETURNED' or Out.Outcome = 'RETRIEVED' or Out.Outcome = 'VOIDED'
                or Out.Outcome = 'REVERSED' or Out.Outcome = 'INCONSISTENT'
                or Out.Outcome = 'AMBIGUOUS'                          then 1
              when Out.Outcome = 'UNDETERMINED'                       then 2
              when Out.Outcome = 'CLEARED'                            then 3
              when Out.Outcome is null and ( Pay.LastRunDate is not null or Chq.ChequeCount > 0 ) then 2
              else 0 end as abap.int1 )                     as FlowCriticality,
      // ---------------------------------------------------------------- measures (one per outcome)
      cast( 1 as abap.int4 )                                as ItemCount,
      cast( case when Pay.LastRunDate is not null or Chq.ChequeCount > 0
                 then 1 else 0 end as abap.int4 )           as PaidReachedCount,
      cast( case Out.Outcome when 'CLEARED' then 1 else 0 end as abap.int4 )      as ClearedCount,
      cast( case Out.Outcome when 'RETURNED' then 1 else 0 end as abap.int4 )     as ReturnedCount,
      cast( case Out.Outcome when 'RETRIEVED' then 1 else 0 end as abap.int4 )    as RetrievedCount,
      cast( case Out.Outcome when 'VOIDED' then 1 else 0 end as abap.int4 )       as VoidedCount,
      cast( case Out.Outcome when 'PENDING' then 1 else 0 end as abap.int4 )      as PendingCount,
      cast( case Out.Outcome when 'IN_FLIGHT' then 1 else 0 end as abap.int4 )    as InFlightCount,
      cast( case Out.Outcome when 'UNDETERMINED' then 1 else 0 end as abap.int4 ) as UndeterminedCount,
      cast( case Out.Outcome when 'INCONSISTENT' then 1 else 0 end as abap.int4 ) as InconsistentCount,
      cast( case Out.Outcome when 'AMBIGUOUS' then 1 else 0 end as abap.int4 )    as AmbiguousCount,
      cast( case Out.Outcome when 'REVERSED' then 1 else 0 end as abap.int4 )     as ReversedOutcomeCount,
      cast( case when Item.ClearingReason = '05' then 1 else 0 end as abap.int4 ) as ReversedCount,
      cast( case when Out.Outcome is null and ( Pay.LastRunDate is not null or Chq.ChequeCount > 0 )
                 then 1 else 0 end as abap.int4 )           as NotEvaluatedCount,
      cast( case when Item.ClearingDoc = ' ' then 1 else 0 end as abap.int4 )     as OpenCount,
      cast( case when Noc.NocCount > 0 then 1 else 0 end as abap.int4 )           as NocItemCount,
      cast( case when Chq.ChequeCount > 0 then 1 else 0 end as abap.int4 )        as ChequeItemCount
}
