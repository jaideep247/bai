// Artifact: zi_cd_trxitemnoc.ddls.asddls
// Purpose: NOC evidence per open item of ZI_CD_TrxItem: NOC lot items (ZI_CD_NocItem, DFKKNRP)
//          whose INFOF (payment document or payment reference) equals the item's clearing document,
//          both without leading zeros; NOC reason DFKKNRP-FLGRD (VERIFY-SE11; the highest when
//          several). NOC codes never come from DFKKRP. INFOF has no known index (VERIFY-SE11): the
//          bounded item set drives the join. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - NOCs per item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxItemNoc
  as select from ZI_CD_TrxItem as Item
    inner join   ZI_CD_NocItem as Noc on Noc.PaymentRefNorm = Item.ClearingDocNorm
{
  key Item.DocumentNo,
  key Item.RepetitionItem,
  key Item.ItemNo,
  key Item.SubItem,
      cast( count( * ) as abap.int4 )                       as NocCount,
      max( Noc.NocReason )                                  as NocReason
}
where Item.ClearingDoc <> ' '
group by
  Item.DocumentNo,
  Item.RepetitionItem,
  Item.ItemNo,
  Item.SubItem
