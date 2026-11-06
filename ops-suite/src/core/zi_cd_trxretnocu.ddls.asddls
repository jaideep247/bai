// Artifact: zi_cd_trxretnocu.ddls.asddls
// Purpose: Returns and NOCs of the transactions of the last 31 days (transactions dashboard,
//          "returns / NOC by reason"): branch RETURN = open item x returns lot item on
//          DFKKRP-SELW1 = DFKKOP-AUGBL (confirmed), reason DFKKRP-RLGRD; branch NOC = open item x NOC
//          lot item on DFKKNRP-INFOF = AUGBL, both without leading zeros, reason DFKKNRP-FLGRD. The
//          bounded item set drives both joins. Never a return reason from FEBEP, never a NOC code
//          from DFKKRP. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions with returns / NOC items'
@Metadata.ignorePropagatedAnnotations: true
// VERIFY-ADT: UNION in CDS view entities (as ZI_CD_EbsRetNocU)
define view entity ZI_CD_TrxRetNocU
  as select from ZI_CD_TrxItem    as Item
    inner join   ZI_CD_ReturnItem as Ret on Ret.PaymentDocument = Item.ClearingDoc
{
  key Item.DocumentNo                                       as DocumentNo,
  key Item.RepetitionItem                                   as RepetitionItem,
  key Item.ItemNo                                           as ItemNo,
  key Item.SubItem                                          as SubItem,
  key cast( 'RETURN' as abap.char( 6 ) )                    as LotKind,
  key cast( Ret.ReturnDocument as abap.char( 40 ) )         as LotItemKey,
      cast( Ret.ReturnReason as abap.char( 10 ) )           as Reason,
      cast( Ret.LotStatus as abap.char( 10 ) )              as LotStatus,
      Item.FinId                                            as FinId,
      Item.CompanyCode                                      as CompanyCode,
      Item.PostingDate                                      as PostingDate,
      Item.PaymentMethod                                    as PaymentMethod,
      Item.Direction                                        as Direction,
      Item.ClearingDoc                                      as ClearingDoc,
      Item.Currency                                         as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Item.Amount                                           as Amount
}
where Item.ClearingDoc <> ' '
union all
  select from ZI_CD_TrxItem as Item
    inner join ZI_CD_NocItem as Noc on Noc.PaymentRefNorm = Item.ClearingDocNorm
{
  key Item.DocumentNo                                       as DocumentNo,
  key Item.RepetitionItem                                   as RepetitionItem,
  key Item.ItemNo                                           as ItemNo,
  key Item.SubItem                                          as SubItem,
  key cast( 'NOC' as abap.char( 6 ) )                       as LotKind,
  key cast( concat( concat( Noc.NocLot, '/' ), Noc.NocItem ) as abap.char( 40 ) ) as LotItemKey,
      cast( Noc.NocReason as abap.char( 10 ) )              as Reason,
      cast( ' ' as abap.char( 10 ) )                        as LotStatus,
      Item.FinId                                            as FinId,
      Item.CompanyCode                                      as CompanyCode,
      Item.PostingDate                                      as PostingDate,
      Item.PaymentMethod                                    as PaymentMethod,
      Item.Direction                                        as Direction,
      Item.ClearingDoc                                      as ClearingDoc,
      Item.Currency                                         as Currency,
      Item.Amount                                           as Amount
}
where Item.ClearingDoc <> ' '
