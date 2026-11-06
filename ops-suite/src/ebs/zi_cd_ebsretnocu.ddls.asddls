// Artifact: zi_cd_ebsretnocu.ddls.asddls
// Purpose: Returns and NOCs behind the bank statement lines of the last 31 days (EBS validation
//          dashboard, "returns / NOC by reason"): branch RETURN = line x returns lot item on
//          DFKKRP-SELW1 = FEBEP-CHECT (confirmed for methods E G H I J K L), reason DFKKRP-RLGRD;
//          branch NOC = line x NOC lot item on DFKKNRP-INFOF = FEBEP-CHECT, both without leading
//          zeros (INFOF holds the payment document or the payment reference), reason DFKKNRP-FLGRD.
//          The bounded line set drives both joins (INFOF is not a key, index VERIFY-SE11). A line
//          with two lot items gives two rows. Never a return reason from FEBEP, never a NOC code
//          from DFKKRP. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS lines with returns / NOC items'
@Metadata.ignorePropagatedAnnotations: true
// VERIFY-ADT: UNION in CDS view entities (as ZI_CD_HckCfgChg); element types aligned by CAST
define view entity ZI_CD_EbsRetNocU
  as select from ZI_CD_EbsLineBase as Line
    inner join   ZI_CD_ReturnItem  as Ret on Ret.PaymentDocument = Line.BankReference
{
  key Line.Kukey                                            as Kukey,
  key Line.Esnum                                            as Esnum,
  key cast( 'RETURN' as abap.char( 6 ) )                    as LotKind,
  key cast( Ret.ReturnDocument as abap.char( 40 ) )         as LotItemKey,
      cast( Ret.ReturnReason as abap.char( 10 ) )           as Reason,
      cast( Ret.LotStatus as abap.char( 10 ) )              as LotStatus,
      Line.LineObjectKey                                    as LineObjectKey,
      Line.CompanyCode                                      as CompanyCode,
      Line.HouseBank                                        as HouseBank,
      Line.StatementDate                                    as StatementDate,
      Line.BookingDate                                      as BookingDate,
      Line.BaiCode                                          as BaiCode,
      Line.BankReference                                    as BankReference,
      Line.Currency                                         as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Line.Amount                                           as Amount
}
union all
  select from ZI_CD_EbsLineBase as Line
    inner join ZI_CD_NocItem    as Noc on Noc.PaymentRefNorm = Line.BankRefNorm
{
  key Line.Kukey                                            as Kukey,
  key Line.Esnum                                            as Esnum,
  key cast( 'NOC' as abap.char( 6 ) )                       as LotKind,
  key cast( concat( concat( Noc.NocLot, '/' ), Noc.NocItem ) as abap.char( 40 ) ) as LotItemKey,
      cast( Noc.NocReason as abap.char( 10 ) )              as Reason,
      cast( ' ' as abap.char( 10 ) )                        as LotStatus,
      Line.LineObjectKey                                    as LineObjectKey,
      Line.CompanyCode                                      as CompanyCode,
      Line.HouseBank                                        as HouseBank,
      Line.StatementDate                                    as StatementDate,
      Line.BookingDate                                      as BookingDate,
      Line.BaiCode                                          as BaiCode,
      Line.BankReference                                    as BankReference,
      Line.Currency                                         as Currency,
      Line.Amount                                           as Amount
}
