// Artifact: zr_cd_trxflow.ddls.asddls
// Purpose: Root of the transactions dashboard (analytical list page, OData V4,
//          docs/Dashboard_Transactions.md): one row per payment-engine open item with a payment
//          request FIN number posted in the last 31 days (ZI_CD_TrxItem, live - no batch) with the
//          evidence of each later step: payment run (DPAYH by DOC1R, live status), cheque (DFKKCR),
//          bank settlement / cheque encashment (FEBEP-CHECT), return (DFKKRP-SELW1, reason RLGRD),
//          NOC (DFKKNRP-INFOF, reason FLGRD). Flow bucket = where the item is now (terminal outcome
//          first): RETURNED (returns lot item), REVERSED (clearing reason 05, TRACE_REVERSAL_AUGRD
//          default), SETTLED (bank line on the clearing document or the cheque), PAID (payment run
//          or cheque, no bank line yet), CLEARED (clearing document without payment evidence in the
//          window), POSTED (open). "Reached" measures count every step an item got to.
//          Requested / errored requests, ACK and cheque status need unconfirmed fields of custom
//          tables - they are in cds/ (ZR_CD_TrxReqFlow), never referenced from here.
//          Drill-down: item -> payment runs, returns / NOC lot items; payment trace by FIN or
//          clearing document. No member number, partner or bank account. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - transaction'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MIXED }
define root view entity ZR_CD_TrxFlow
  as select from    ZI_CD_TrxItem     as Item
    left outer join ZI_CD_TrxItemPay  as Pay  on  Pay.DocumentNo = Item.DocumentNo
                                     and Pay.RepetitionItem = Item.RepetitionItem
                                     and Pay.ItemNo = Item.ItemNo
                                     and Pay.SubItem = Item.SubItem
    left outer join ZI_CD_TrxItemChq  as Chq  on  Chq.DocumentNo = Item.DocumentNo
                                     and Chq.RepetitionItem = Item.RepetitionItem
                                     and Chq.ItemNo = Item.ItemNo
                                     and Chq.SubItem = Item.SubItem
    left outer join ZI_CD_TrxItemBank as Bank on  Bank.DocumentNo = Item.DocumentNo
                                     and Bank.RepetitionItem = Item.RepetitionItem
                                     and Bank.ItemNo = Item.ItemNo
                                     and Bank.SubItem = Item.SubItem
    left outer join ZI_CD_TrxItemEnc  as Enc  on  Enc.DocumentNo = Item.DocumentNo
                                     and Enc.RepetitionItem = Item.RepetitionItem
                                     and Enc.ItemNo = Item.ItemNo
                                     and Enc.SubItem = Item.SubItem
    left outer join ZI_CD_TrxItemRet  as Ret  on  Ret.DocumentNo = Item.DocumentNo
                                     and Ret.RepetitionItem = Item.RepetitionItem
                                     and Ret.ItemNo = Item.ItemNo
                                     and Ret.SubItem = Item.SubItem
    left outer join ZI_CD_TrxItemNoc  as Noc  on  Noc.DocumentNo = Item.DocumentNo
                                     and Noc.RepetitionItem = Item.RepetitionItem
                                     and Noc.ItemNo = Item.ItemNo
                                     and Noc.SubItem = Item.SubItem
  association [0..*] to ZR_CD_TrxPayRun as _PaymentRuns on $projection.ClearingDoc = _PaymentRuns.PaymentDocument
  association [0..*] to ZR_CD_TrxRetNoc as _ReturnsNoc  on  $projection.DocumentNo     = _ReturnsNoc.DocumentNo
                                                        and $projection.RepetitionItem = _ReturnsNoc.RepetitionItem
                                                        and $projection.ItemNo         = _ReturnsNoc.ItemNo
                                                        and $projection.SubItem        = _ReturnsNoc.SubItem
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
      Pay.PaymentStatus,
      Chq.ChequeNo,
      Chq.ChequeHouseBank,
      Bank.LastBookingDate                                  as SettlementDate,
      Enc.EncashDate,
      Ret.ReturnReason,
      Noc.NocReason,
      cast( case
              when Ret.ReturnCount > 0                              then 'RETURNED'
              when Item.ClearingReason = '05'                       then 'REVERSED'
              when Bank.BankLineCount > 0 or Enc.EncashLineCount > 0 then 'SETTLED'
              when Pay.PaymentRunCount > 0 or Chq.ChequeCount > 0   then 'PAID'
              when Item.ClearingDoc <> ' '                          then 'CLEARED'
              else 'POSTED' end as abap.char( 10 ) )        as FlowBucket,
      // UI criticality: 1 red (returned, reversed), 3 green (settled), 0 in flight
      cast( case
              when Ret.ReturnCount > 0                              then 1
              when Item.ClearingReason = '05'                       then 1
              when Bank.BankLineCount > 0 or Enc.EncashLineCount > 0 then 3
              else 0 end as abap.int1 )                     as FlowCriticality,
      // ---------------------------------------------------------------- measures
      cast( 1 as abap.int4 )                                as ItemCount,
      cast( case when Ret.ReturnCount > 0 or Bank.BankLineCount > 0 or Enc.EncashLineCount > 0
                   or Pay.PaymentRunCount > 0 or Chq.ChequeCount > 0
                 then 1 else 0 end as abap.int4 )           as PaidReachedCount,
      cast( case when Bank.BankLineCount > 0 or Enc.EncashLineCount > 0
                 then 1 else 0 end as abap.int4 )           as SettledReachedCount,
      cast( case when Ret.ReturnCount > 0 then 1 else 0 end as abap.int4 )          as ReturnedCount,
      cast( case when Ret.ReturnCount > 0 then 0
                 when Item.ClearingReason = '05' then 1 else 0 end as abap.int4 )   as ReversedCount,
      cast( case when Item.ClearingDoc = ' ' then 1 else 0 end as abap.int4 )       as OpenCount,
      cast( case when Noc.NocCount > 0 then 1 else 0 end as abap.int4 )             as NocItemCount,
      cast( case when Chq.ChequeCount > 0 then 1 else 0 end as abap.int4 )          as ChequeItemCount,
      cast( coalesce( Pay.PaymentRunCount, 0 ) as abap.int4 )                       as PaymentRunCount,
      _PaymentRuns,
      _ReturnsNoc
}
