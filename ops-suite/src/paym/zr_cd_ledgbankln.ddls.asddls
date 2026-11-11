// Artifact: zr_cd_ledgbankln.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - bank statement line of a reconciled account (entity BankStatementLine):
//          statement (house bank / account ID, date, number), line (transaction code, bank reference, reference text,
//          amount, value date, posted flags), the subledger clearing document it references and whether that document
//          was reversed or reset since (the line keeps the OLD clearing document), and the key of its G/L clearing line.
//          Bank side drill-down: statement -> line -> G/L clearing line (_GlLine, the journal by its primary key - never
//          searched by reference) and -> the payment and its change timeline. How a line finds its clearing document and
//          its G/L line is the consumer's mapping rule (adapter ZI_CD_LedgBankLn). Read-only.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - bank statement line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_LedgBankLn
  as select from ZI_CD_LedgBankLn as Line
  association [0..*] to ZR_CD_LedgJrnl   as _GlLine  on  $projection.CompanyCode  = _GlLine.CompanyCode
                                                       and $projection.GlFiscalYear = _GlLine.FiscalYear
                                                       and $projection.GlDocument   = _GlLine.GlDocument
                                                       and $projection.GlLineItem   = _GlLine.GlLineItem
  association [0..*] to ZR_CD_Payment    as _Payment on  $projection.ClearingDocument = _Payment.PaymentDocument
  association [0..*] to ZR_CD_PaymChange as _Changes on  $projection.ClearingDocument = _Changes.PaymentDocument
{
  key Line.StatementKey,
  key Line.StatementLine,
      _GlLine,
      _Payment,
      _Changes,
      cast( 'CD_OPS' as abap.char( 16 ) )                 as OpsArea,
      Line.CompanyCode,
      Line.GlAccount,
      Line.Currency,
      Line.BookingDate,
      @Semantics.amount.currencyCode: 'Currency'
      Line.Amount,
      Line.DebitCredit,
      Line.HouseBank,
      Line.HouseBankAccount,
      Line.StatementNumber,
      Line.StatementDate,
      Line.TransactionCode,
      Line.BankReference,
      Line.ReferenceText,
      Line.ValueDate,
      Line.IsPostedArea1,
      Line.IsPostedArea2,
      Line.ClearingDocument,
      Line.ClearingChanged,
      cast( case when Line.ClearingChanged = 'X' then 1 else 3 end as abap.int1 ) as LineCriticality,
      Line.GlFiscalYear,
      Line.GlDocument,
      Line.GlLineItem,
      cast( 1 as abap.int4 )                                as LineCount
}
