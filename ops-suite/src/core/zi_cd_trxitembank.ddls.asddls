// Artifact: zi_cd_trxitembank.ddls.asddls
// Purpose: Settlement evidence per open item of ZI_CD_TrxItem: bank statement lines (FEBEP)
//          whose bank reference CHECT = the item's clearing document (confirmed for payment methods
//          E G H I J K L), booked in the last 45 days (FEBEP-BUDAT always filled, confirmed).
//          Exact match of the reference as stored. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - bank line per item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
// VERIFY-SE11: index on FEBEP-CHECT (as the payment trace); the bounded item set drives the join
define view entity ZI_CD_TrxItemBank
  as select from ZI_CD_TrxItem as Item
    inner join   febep         as Bank on Bank.chect = Item.ClearingDoc
{
  key Item.DocumentNo,
  key Item.RepetitionItem,
  key Item.ItemNo,
  key Item.SubItem,
      cast( count( * ) as abap.int4 )                       as BankLineCount,
      max( Bank.budat )                                     as LastBookingDate
}
where Item.ClearingDoc <> ' '
  and Bank.budat >= dats_add_days( $session.system_date, -45, 'INITIAL' )
group by
  Item.DocumentNo,
  Item.RepetitionItem,
  Item.ItemNo,
  Item.SubItem
