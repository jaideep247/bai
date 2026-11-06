// Artifact: zi_cd_ebslinebase.ddls.asddls
// Purpose: Basic view of bank statement lines (standard FEBEP) of the statements in
//          ZI_CD_EbsStmtBase (statement date in the last 31 days) with the house bank of the
//          statement and the finding key FEB<KUKEY>/<ESNUM without leading zeros> that
//          ZCL_CD_EBS_FINDING=>LINE_KEY gives the line. Fields as ZCL_CD_EBS_FEB_DAO reads them:
//          VORGC (external BAI / transaction code), VGINT (posting rule), KWBTR / KWAER, BUDAT
//          (always filled, confirmed), VALUT, CHECT (bank reference = payment document, confirmed),
//          XBLNR (confirmed), BELNR / GJAHR (posting result). VERIFY-SE11 as there. FEBEP holds no
//          return reason: returns come from DFKKRP-RLGRD, NOCs from DFKKNRP-FLGRD (ZR_CD_EbsRetNoc).
//          Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS statement line (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_EbsLineBase
  as select from febep             as Line
    inner join   ZI_CD_EbsStmtBase as Stmt on Stmt.Kukey = Line.kukey
{
  key Line.kukey                                            as Kukey,
  key Line.esnum                                            as Esnum,
      Stmt.StmtObjectKey                                    as StmtObjectKey,
      // VERIFY-ADT: CONCAT / LTRIM with NUMC operands (ESNUM 00012 -> 12, as |{ line_no }| in ABAP)
      cast( concat( concat( Stmt.StmtObjectKey, '/' ), ltrim( Line.esnum, '0' ) ) as abap.char( 70 ) ) as LineObjectKey,
      Stmt.CompanyCode                                      as CompanyCode,
      Stmt.HouseBank                                        as HouseBank,
      Stmt.HouseBankAccount                                 as HouseBankAccount,
      Stmt.StatementNo                                      as StatementNo,
      Stmt.StatementDate                                    as StatementDate,
      Line.vorgc                                            as BaiCode,
      Line.vgint                                            as PostingRule,
      Line.epvoz                                            as DebitCreditInd,
      @Semantics.amount.currencyCode: 'Currency'
      Line.kwbtr                                            as Amount,
      // Line currency, else the statement currency (as ZCL_CD_EBS_SRC_FEB=>MAP_LINE)
      cast( case when Line.kwaer <> ' ' then Line.kwaer else Stmt.Currency end as abap.cuky( 5 ) ) as Currency,
      Line.budat                                            as BookingDate,
      Line.valut                                            as ValueDate,
      Line.chect                                            as BankReference,
      // Without leading zeros / blanks: compared with DFKKNRP-INFOF (ZI_CD_NocItem-PaymentRefNorm)
      cast( ltrim( ltrim( Line.chect, ' ' ), '0' ) as abap.char( 50 ) ) as BankRefNorm,
      Line.xblnr                                            as Xblnr,
      Line.belnr                                            as PostingDocument,
      Line.gjahr                                            as PostingYear,
      case when Line.belnr <> ' '
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsPosted
}
