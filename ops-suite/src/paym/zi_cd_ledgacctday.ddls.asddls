// Artifact: zi_cd_ledgacctday.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - journal leg of the group reconciliation: universal journal lines of the
//          reconciled accounts (ZI_CD_LedgAcct) in the ledger of ZI_CD_LedgCfg aggregated per company code, G/L
//          account, transaction currency and posting date on the database (the access path RLDNR, RBUKRS, RACCT, BUDAT;
//          callers always restrict the posting date) - total, the part of the G/L documents of subledger batch keys
//          (reference type FKKSU) and the rest (other postings: bank statement, manual), line count. Signed
//          as the journal (WSL); never across currencies. Read-only.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
// VERIFY-ADT: SUM of a CASE over a DEC cast of WSL (7.58). PlanViz on the largest day of the consumer (the consumer's
//             performance review).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - journal per account and day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgAcctDay
  as select from acdoca           as Jrn
    inner join   ZI_CD_LedgCfg  as Cfg on  Cfg.Ledger = Jrn.rldnr
    inner join   ZI_CD_LedgAcct as Acc on  Acc.CompanyCode = Jrn.rbukrs
                                          and Acc.GlAccount   = Jrn.racct
                                          and Acc.Currency    = Jrn.rwcur
{
  key Jrn.rbukrs                                            as CompanyCode,
  key Jrn.racct                                             as GlAccount,
  key Jrn.rwcur                                             as Currency,
  key Jrn.budat                                             as PostingDate,
      cast( sum( cast( Jrn.wsl as abap.dec( 23, 2 ) ) ) as abap.dec( 23, 2 ) ) as JournalAmount,
      cast( sum( case when Jrn.awtyp = 'FKKSU' then cast( Jrn.wsl as abap.dec( 23, 2 ) ) else 0 end )
            as abap.dec( 23, 2 ) )                          as TransferAmount,
      cast( count( * ) as abap.int4 )                       as JournalLineCount
}
group by
  Jrn.rbukrs,
  Jrn.racct,
  Jrn.rwcur,
  Jrn.budat
