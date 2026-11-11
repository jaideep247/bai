// Artifact: zi_cd_ledgbankday.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - bank lines of the reconciled accounts per company code, G/L account,
//          currency and booking date (adapter ZI_CD_LedgBankLn): line count and amount, and the variance bucket
//          "reset / reversal" - lines whose subledger clearing document was reversed or reset after the bank line was
//          created (ClearingChanged; the line keeps the OLD clearing document, a known cause of clearing-account
//          breaks). Read-only.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - bank lines per account and day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgBankDay
  as select from ZI_CD_LedgBankLn as Line
{
  key Line.CompanyCode,
  key Line.GlAccount,
  key Line.Currency,
  key Line.BookingDate,
      cast( sum( cast( Line.Amount as abap.dec( 23, 2 ) ) ) as abap.dec( 23, 2 ) ) as BankAmount,
      cast( count( * ) as abap.int4 )                       as BankLineCount,
      cast( sum( case when Line.ClearingChanged = 'X' then cast( Line.Amount as abap.dec( 23, 2 ) ) else 0 end )
            as abap.dec( 23, 2 ) )                          as ChangedAmount,
      cast( sum( case when Line.ClearingChanged = 'X' then 1 else 0 end ) as abap.int4 ) as ChangedLineCount
}
group by
  Line.CompanyCode,
  Line.GlAccount,
  Line.Currency,
  Line.BookingDate
