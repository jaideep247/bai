// Artifact: zi_cd_trxitemret.ddls.asddls
// Purpose: Return evidence per open item of ZI_CD_TrxItem: returns lot items (ZI_CD_ReturnItem,
//          DFKKRP) with SELW1 = the item's clearing document (confirmed), return reason
//          DFKKRP-RLGRD (VERIFY-SE11; the highest when several). Never a reason from FEBEP. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - returns per item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxItemRet
  as select from ZI_CD_TrxItem as Item
    inner join   ZI_CD_ReturnItem as Ret on Ret.PaymentDocument = Item.ClearingDoc
{
  key Item.DocumentNo,
  key Item.RepetitionItem,
  key Item.ItemNo,
  key Item.SubItem,
      cast( count( * ) as abap.int4 )                       as ReturnCount,
      max( Ret.ReturnReason )                               as ReturnReason
}
where Item.ClearingDoc <> ' '
group by
  Item.DocumentNo,
  Item.RepetitionItem,
  Item.ItemNo,
  Item.SubItem
