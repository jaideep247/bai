// Artifact: zi_cd_ledgbankln.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the bank statement line: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          Bank lines of the payment engine accounts (ZI_CD_HckRcBankLine: account of FEBEP-XBLNR as EBS) of the reconciled
//          sets (ZCD_EBS_ACCT house bank account -> ZCD_HCK_RCSET of the same company code, house bank, account ID and
//          currency). Clearing document = FEBEP-CHECT (methods E G H I J K L: CHECT = AUGBL, confirmed; for cheques CHECT is
//          the cheque number - V105, not resolved here). ClearingChanged = the referenced payment document was reversed
//          (DFKKKO-STBEL; a clearing reset needs the history, V100). The G/L clearing line (BSEG-XREF2 = AUGBL) is not joined:
//          BSEG has no index on XREF2 (HCK VERIFY item 14) - blank until the index or the clearing-account restriction is
//          confirmed (V106); the payment ledger and the batch key reach the journal instead.
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
// Amount: absolute FEBEP-KWBTR; the sign is DebitCredit (EPVOZ, EBS_FEB_CREDIT_IND / _DEBIT_IND)
// StatementNumber: V107 VERIFY-SE11 FEBKO-AZNUM
// ValueDate: V107 VERIFY-SE11 FEBEP-VALUT
// ClearingDocument: CHECT = AUGBL for methods E G H I J K L (confirmed); cheques: V105
// ClearingChanged: reversal by DFKKKO-STBEL; clearing reset needs the history (V100)
// GlFiscalYear: V106 G/L clearing line by BSEG-XREF2 = AUGBL needs an index (BUKRS / XREF2) - blank until confirmed
// GlDocument: V106 as GlFiscalYear
// GlLineItem: V106 as GlFiscalYear
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter bank statement line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgBankLn
  as select from ZI_CD_HckRcBankLine as Line
    inner join zcd_ebs_acct as Acct on  Acct.account_no = Line.PeAccount
                                    and Acct.active     = 'X'
    inner join zcd_hck_rcset as RcSet on  RcSet.bukrs  = Acct.bukrs
                                      and RcSet.hbkid  = Acct.hbkid
                                      and RcSet.hktid  = Acct.hktid
                                      and RcSet.waers  = Line.Currency
                                      and RcSet.active = 'X'
    left outer join dfkkko as Clr on Clr.opbel = Line.BankReference
{
  key cast( Line.Kukey as abap.char( 20 ) ) as StatementKey,
  key cast( Line.Esnum as abap.char( 10 ) ) as StatementLine,
      RcSet.bukrs as CompanyCode,
      RcSet.hkont as GlAccount,
      Line.Currency as Currency,
      Line.BookingDate as BookingDate,
      @Semantics.amount.currencyCode: 'Currency'
      Line.Amount as Amount,
      Line.DebitCreditInd as DebitCredit,
      Line.HouseBank as HouseBank,
      Line.HouseBankAccount as HouseBankAccount,
      Line.StatementNumber as StatementNumber,
      Line.StatementDate as StatementDate,
      Line.BaiCode as TransactionCode,
      Line.BankReference as BankReference,
      Line.ReferenceText as ReferenceText,
      Line.ValueDate as ValueDate,
      Line.IsPostedArea1 as IsPostedArea1,
      Line.IsPostedArea2 as IsPostedArea2,
      cast( Line.BankReference as abap.char( 20 ) ) as ClearingDocument,
      cast( case when Clr.stbel is not null and Clr.stbel <> ' ' then 'X' else ' ' end as abap_boolean ) as ClearingChanged,
      cast( 0 as abap.numc( 4 ) ) as GlFiscalYear,
      cast( '' as abap.char( 10 ) ) as GlDocument,
      cast( 0 as abap.numc( 3 ) ) as GlLineItem
}
