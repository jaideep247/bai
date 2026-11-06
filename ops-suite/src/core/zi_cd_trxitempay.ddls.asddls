// Artifact: zi_cd_trxitempay.ddls.asddls
// Purpose: Payment run evidence per open item of ZI_CD_TrxItem (bounded driver): DPAYH rows
//          with DOC1R = the item's clearing document (confirmed: DPAYH by DOC1R, live status
//          ZZ_PAYMENT_STATUS), proposal runs excluded (XVORL, VERIFY-SE11 as ZCL_CD_EBS_SAP_DAO).
//          DOC1R is not unique in DPAYH (re-runs): runs are counted, the latest run date and the
//          highest status value are shown (status values VERIFY-SE11). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - payment run per item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxItemPay
  as select from ZI_CD_TrxItem as Item
    inner join   dpayh         as Pay on Pay.doc1r = Item.ClearingDoc
                               and Pay.xvorl = ' '
{
  key Item.DocumentNo,
  key Item.RepetitionItem,
  key Item.ItemNo,
  key Item.SubItem,
      cast( count( * ) as abap.int4 )                       as PaymentRunCount,
      max( Pay.laufd )                                      as LastRunDate,
      max( Pay.laufi )                                      as LastRunId,
      max( Pay.zz_payment_status )                          as PaymentStatus
}
where Item.ClearingDoc <> ' '
group by
  Item.DocumentNo,
  Item.RepetitionItem,
  Item.ItemNo,
  Item.SubItem
