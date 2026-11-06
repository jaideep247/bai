// Artifact: zi_cd_trxitemchq.ddls.asddls
// Purpose: Cheque evidence per open item of ZI_CD_TrxItem: cheque register DFKKCR with DOC1R
//          = the item's clearing document (confirmed), cheque number ZTNUM (confirmed: = FEBEP-CHECT
//          on encashment) and house bank (HBKID, as ZCL_CD_EBS_SAP_DAO). A re-issued cheque gives
//          two rows: counted, the highest cheque number is shown. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - cheque per item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxItemChq
  as select from ZI_CD_TrxItem as Item
    inner join   dfkkcr        as Chq on Chq.doc1r = Item.ClearingDoc
{
  key Item.DocumentNo,
  key Item.RepetitionItem,
  key Item.ItemNo,
  key Item.SubItem,
      cast( count( * ) as abap.int4 )                       as ChequeCount,
      max( Chq.ztnum )                                      as ChequeNo,
      max( Chq.hbkid )                                      as ChequeHouseBank
}
where Item.ClearingDoc <> ' '
group by
  Item.DocumentNo,
  Item.RepetitionItem,
  Item.ItemNo,
  Item.SubItem
