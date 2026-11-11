// Artifact: zi_cd_ledgsubday.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - subledger leg of the group reconciliation: summary records of the
//          reconciled accounts per company code, G/L account, currency and posting date (subledger total and the number
//          of batch keys - the next level of a group-day row). Signed as the adapter delivers them. Read-only.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - subledger per account and day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgSubDay
  as select from ZI_CD_LedgBatch as Bat
    inner join   ZI_CD_LedgAcct  as Acc on  Acc.CompanyCode = Bat.CompanyCode
                                           and Acc.GlAccount   = Bat.GlAccount
                                           and Acc.Currency    = Bat.Currency
{
  key Bat.CompanyCode,
  key Bat.GlAccount,
  key Bat.Currency,
  key Bat.PostingDate,
      cast( sum( cast( Bat.Amount as abap.dec( 23, 2 ) ) ) as abap.dec( 23, 2 ) ) as SubledgerAmount,
      cast( count( distinct Bat.BatchKey ) as abap.int4 )   as BatchCount
}
group by
  Bat.CompanyCode,
  Bat.GlAccount,
  Bat.Currency,
  Bat.PostingDate
