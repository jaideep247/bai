// Artifact: zi_cd_ebslinebase.ddls.asddls
// Purpose: Basic view of bank statement lines (standard FEBEP, via ZI_CD_EbsLineAcct) of the
//          statements in ZI_CD_EbsStmtBase (statement date in the last 31 days, every line a payment
//          engine account) with the house bank of the statement and the finding key
//          FEB<KUKEY>/<ESNUM without leading zeros> that ZCL_CD_EBS_FINDING=>LINE_KEY gives the line.
//          Fields as ZCL_CD_EBS_FEB_DAO reads them: VORGC (external BAI / transaction code), VGINT
//          (posting rule), KWBTR / KWAER, BUDAT (always filled, confirmed), VALUT, CHECT (bank
//          reference = payment document, confirmed), XBLNR (confirmed: bank text + payment engine
//          account + counter), BELNR / GJAHR (posting result). VERIFY-SE11 as there. The payment
//          engine account of the line and the G/L account of its ZCD_EBS_ACCT row. FEBEP holds no
//          return reason: returns come from DFKKRP-RLGRD, NOCs from DFKKNRP-FLGRD (ZR_CD_EbsRetNoc).
//          Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
//                   2026-11-06 | Payment engine account from XBLNR (ZI_CD_EbsLineAcct) and G/L account
//                              | of the matched account row.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS statement line (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_EbsLineBase
  as select from    ZI_CD_EbsLineAcct as Line
    inner join      ZI_CD_EbsStmtBase as Stmt on Stmt.Kukey = Line.Kukey
    left outer join ZI_CD_EbsPeAcct   as Pe   on Pe.PeAccount = Line.PeAccount
{
  key Line.Kukey                                            as Kukey,
  key Line.Esnum                                            as Esnum,
      Stmt.StmtObjectKey                                    as StmtObjectKey,
      // VERIFY-ADT: CONCAT / LTRIM with NUMC operands (ESNUM 00012 -> 12, as |{ line_no }| in ABAP)
      cast( concat( concat( Stmt.StmtObjectKey, '/' ), ltrim( Line.Esnum, '0' ) ) as abap.char( 70 ) ) as LineObjectKey,
      Stmt.CompanyCode                                      as CompanyCode,
      Stmt.HouseBank                                        as HouseBank,
      Stmt.HouseBankAccount                                 as HouseBankAccount,
      Line.PeAccount                                        as PeAccount,
      Pe.GlAccount                                          as GlAccount,
      Stmt.StatementNo                                      as StatementNo,
      Stmt.StatementDate                                    as StatementDate,
      Line.BaiCode                                          as BaiCode,
      Line.PostingRule                                      as PostingRule,
      Line.DebitCreditInd                                   as DebitCreditInd,
      @Semantics.amount.currencyCode: 'Currency'
      Line.Amount                                           as Amount,
      Line.Currency                                         as Currency,
      Line.BookingDate                                      as BookingDate,
      Line.ValueDate                                        as ValueDate,
      Line.BankReference                                    as BankReference,
      Line.BankRefNorm                                      as BankRefNorm,
      Line.Xblnr                                            as Xblnr,
      Line.PostingDocument                                  as PostingDocument,
      Line.PostingYear                                      as PostingYear,
      Line.IsPosted                                         as IsPosted
}
