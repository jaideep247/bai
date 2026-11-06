// Artifact: zi_cd_trxitemenc.ddls.asddls
// Purpose: Encashment evidence per cheque-paid open item (ZI_CD_TrxItemChq): bank statement lines
//          (FEBEP) whose bank reference CHECT = the cheque number (confirmed: DFKKCR-ZTNUM =
//          FEBEP-CHECT for method C), booked in the last 45 days. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - cheque encashment per item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxItemEnc
  as select from ZI_CD_TrxItemChq as Chq
    inner join   febep            as Bank on Bank.chect = Chq.ChequeNo
{
  key Chq.DocumentNo,
  key Chq.RepetitionItem,
  key Chq.ItemNo,
  key Chq.SubItem,
      cast( count( * ) as abap.int4 )                       as EncashLineCount,
      max( Bank.budat )                                     as EncashDate
}
where Chq.ChequeNo <> ' '
  and Bank.budat   >= dats_add_days( $session.system_date, -45, 'INITIAL' )
group by
  Chq.DocumentNo,
  Chq.RepetitionItem,
  Chq.ItemNo,
  Chq.SubItem
