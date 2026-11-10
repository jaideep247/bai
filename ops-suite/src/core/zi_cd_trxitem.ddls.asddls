// Artifact: zi_cd_trxitem.ddls.asddls
// Purpose: Basic view of the transactions dashboard (docs/Dashboard_Transactions.md): open items of
//          the payment engine (standard DFKKOP) that carry a payment request FIN number
//          (ZZ_FIN_TRANS_NUM, confirmed: = ZCD_PAYM_REQ_LOG FIN number) and were posted within the
//          evidence window (BUDAT >= today - 45: bounded live read, the driver of the returns / NOC
//          entity and of the request side in cds/; the worklist rows of the dashboard need no driver).
//          Company code currency and country from T001; collection / disbursement from TFK042Z-XEINZ
//          (confirmed) by country and payment method (key LAND1 / ZLSCH VERIFY-SE11, as the payment
//          trace). Fields: OPBEL, OPUPW, OPUPK, OPUPZ, BUKRS, BUDAT, BETRH, BETRW, WAERS, PYMET,
//          AUGST, AUGBL, AUGDT, AUGRD (standard; VERIFY-SE11 as in ZCL_CD_OPS_TRACE_DAO),
//          ZZ_FIN_TRANS_NUM and ZZ_BILLPLANID (confirmed). No business partner, contract account
//          or member number is selected. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Bound = the 400-day retention of the payment outcome (date filter by
//                   posting, run or value date of the consumer; KPI / problem cards keep 31 days).
//                   2026-11-08 | Exceptions-only worklist: the transactions are the worklist rows; this view
//                   drives only returns / NOC and the request side - bound = the 45-day evidence window.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - open item with FIN (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
// VERIFY-SE11: index on DFKKOP-BUDAT / ZZ_FIN_TRANS_NUM (HANA column store: column scan with the
// date predicate pushed down); ST05 / PlanViz in QA1 at peak volume (Dashboard_Transactions.md)
define view entity ZI_CD_TrxItem
  as select from    dfkkop  as Item
    left outer join t001    as Cc on Cc.bukrs = Item.bukrs
    left outer join tfk042z as Pm on  Pm.land1 = Cc.land1
                                  and Pm.zlsch = Item.pymet
{
  key Item.opbel                                            as DocumentNo,
  key Item.opupw                                            as RepetitionItem,
  key Item.opupk                                            as ItemNo,
  key Item.opupz                                            as SubItem,
      cast( 'CD_OPS' as abap.char( 16 ) )                      as PaymentEngineArea,
      Item.zz_fin_trans_num                                 as FinId,
      Item.zz_billplanid                                    as BillPlanId,
      Item.bukrs                                            as CompanyCode,
      Item.budat                                            as PostingDate,
      Item.pymet                                            as PaymentMethod,
      cast( case
              when Item.pymet = ' '   then 'NONE'
              when Pm.xeinz = 'X'     then 'COLLECTION'
              when Pm.zlsch is null   then 'UNKNOWN'
              else 'DISBURSEMENT' end as abap.char( 12 ) )  as Direction,
      Cc.waers                                              as LocalCurrency,
      @Semantics.amount.currencyCode: 'LocalCurrency'
      Item.betrh                                            as AmountInLocalCurrency,
      Item.waers                                            as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Item.betrw                                            as Amount,
      Item.augst                                            as ClearingStatus,
      Item.augbl                                            as ClearingDoc,
      // Without leading zeros: compared with DFKKNRP-INFOF (ZI_CD_NocItem-PaymentRefNorm)
      cast( ltrim( Item.augbl, '0' ) as abap.char( 50 ) )   as ClearingDocNorm,
      Item.augdt                                            as ClearingDate,
      Item.augrd                                            as ClearingReason
}
where Item.zz_fin_trans_num <> ' '
  and Item.budat >= dats_add_days( $session.system_date, -45, 'INITIAL' )
