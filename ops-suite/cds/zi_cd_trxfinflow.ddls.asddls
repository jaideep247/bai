// Artifact: zi_cd_trxfinflow.ddls.asddls
// Purpose: The SAP side of a FIN number per company code and payment document (src/core
//          ZI_CD_TrxItem + ZI_CD_TrxItemPay): one row per FIN + company code + clearing document
//          (blank = open items) + payment method + direction - items, open, reversed, paid (payment
//          run or cheque) and the first posting date. Company code, clearing document, method and
//          direction are the identity of the row (GROUP BY), never an independent MAX over rows of
//          different payments; a FIN paid in two company codes or by two payments is two rows, and
//          the company-code authorisation of the request funnel (DCL on the row's CompanyCode)
//          applies to exactly the items summed in it. The outcome is not derived here: the request
//          funnel joins the canonical outcome by FIN + source + company code + payment document.
//          ADT only (cds/): it depends on src/ views; src/ never depends on it. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
//                   2026-11-07 | Review defect: grouped by FinId only with MAX( ClearingDoc / ChequeNo /
//                   CompanyCode / PaymentMethod / Direction ) taken independently - identity now
//                   FIN + company code + payment document (+ method, direction); no outcome here.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - SAP side per FIN and payment'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxFinFlow
  as select from    ZI_CD_TrxItem    as Item
    left outer join ZI_CD_TrxItemPay as Pay on  Pay.DocumentNo     = Item.DocumentNo
                                            and Pay.RepetitionItem = Item.RepetitionItem
                                            and Pay.ItemNo         = Item.ItemNo
                                            and Pay.SubItem        = Item.SubItem
    left outer join ZI_CD_TrxItemChq as Chq on  Chq.DocumentNo     = Item.DocumentNo
                                            and Chq.RepetitionItem = Item.RepetitionItem
                                            and Chq.ItemNo         = Item.ItemNo
                                            and Chq.SubItem        = Item.SubItem
{
  key Item.FinId,
  key Item.CompanyCode,
  key Item.ClearingDoc,
  key Item.PaymentMethod,
  key Item.Direction,
      cast( count( * ) as abap.int4 )                       as ItemCount,
      cast( sum( case when Item.ClearingDoc = ' ' then 1 else 0 end ) as abap.int4 )     as HasOpenItem,
      cast( sum( case when Item.ClearingReason = '05' then 1 else 0 end ) as abap.int4 ) as IsReversed,
      cast( sum( case when Pay.LastRunDate is not null or Chq.ChequeCount > 0
                      then 1 else 0 end ) as abap.int4 )    as IsPaid,
      min( Item.PostingDate )                               as PostingDate
}
group by
  Item.FinId,
  Item.CompanyCode,
  Item.ClearingDoc,
  Item.PaymentMethod,
  Item.Direction
