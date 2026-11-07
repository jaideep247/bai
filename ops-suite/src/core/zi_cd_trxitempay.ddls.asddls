// Artifact: zi_cd_trxitempay.ddls.asddls
// Purpose: Payment run evidence per open item of ZI_CD_TrxItem (bounded driver): the LATEST DPAYH
//          row with DOC1R = the item's clearing document (confirmed: DPAYH by DOC1R, live status
//          ZZ_PAYMENT_STATUS), proposal runs excluded (XVORL, VERIFY-SE11 as ZCL_CD_EBS_SAP_DAO).
//          DOC1R is not unique in DPAYH (re-runs): run date, run ID, value date and status all come
//          from ONE row - the run with the highest run date, then the highest run ID (deterministic;
//          the same order as ZIF_CD_OPS_PAY_OUTCOME=>EVALUATE_DOCUMENTS, so the run shown is the run
//          the canonical outcome was judged on). Never independent MAX per column. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Review defect: MAX( laufd ), MAX( laufi ), MAX( status ) taken
//                   independently (values of different runs mixed) - now one row, the latest run
//                   (anti-join on a newer run of the same document); value date DPAYH-VALUT.
// VERIFY-ADT: comparison operators and OR in the ON condition of a left outer join (7.58).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - latest payment run per item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxItemPay
  as select from    ZI_CD_TrxItem as Item
    inner join      dpayh         as Pay   on  Pay.doc1r = Item.ClearingDoc
                                           and Pay.xvorl = ' '
    left outer join dpayh         as Newer on  Newer.doc1r = Pay.doc1r
                                           and Newer.xvorl = ' '
                                           and (    Newer.laufd > Pay.laufd
                                                 or ( Newer.laufd = Pay.laufd and Newer.laufi > Pay.laufi ) )
{
  key Item.DocumentNo,
  key Item.RepetitionItem,
  key Item.ItemNo,
  key Item.SubItem,
      Pay.laufd                                             as LastRunDate,
      Pay.laufi                                             as LastRunId,
      // VERIFY-SE11: DPAYH-VALUT (as ZCL_CD_HCK_RUNTIME_DAO)
      Pay.valut                                             as ValueDate,
      Pay.zz_payment_status                                 as PaymentStatus
}
where Item.ClearingDoc <> ' '
  and Newer.doc1r is null
