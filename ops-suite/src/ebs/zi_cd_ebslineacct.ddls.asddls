// Artifact: zi_cd_ebslineacct.ddls.asddls
// Purpose: Basic view of the bank statement lines (standard FEBEP) of the imported statements
//          (FEBKO) with a statement date in the last 31 days (bounded read) and the payment engine
//          bank account each line carries in FEBEP-XBLNR (user decision 2026-11-06: XBLNR = bank
//          text + payment engine account of 10 characters + counter, e.g. JPMC8XX1174412334 ->
//          8XX1174412). Derivation as ZCL_CD_EBS_PE_SCOPE=>PE_ACCOUNT_FROM_XBLNR: leading letters
//          removed, leading blanks removed, first 10 characters, upper case. Pattern '^[A-Za-z]+'
//          and length 10 are the literals of ZIF_CD_EBS_TYPES=>GC_PE_ACCOUNT - a change there is a
//          change here. Fields as ZCL_CD_EBS_FEB_DAO reads them (VERIFY-SE11 as there). Not yet
//          filtered by the scope: ZI_CD_EbsStmtScope decides which statements are shown. Read-only.
// Modification log: 2026-11-06 | Initial version (payment engine account scope from XBLNR).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS line with payment engine account'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_EbsLineAcct
  as select from febep as Line
    inner join   febko as Hdr on Hdr.kukey = Line.kukey
{
  key Line.kukey                                            as Kukey,
  key Line.esnum                                            as Esnum,
      Line.vorgc                                            as BaiCode,
      Line.vgint                                            as PostingRule,
      Line.epvoz                                            as DebitCreditInd,
      @Semantics.amount.currencyCode: 'Currency'
      Line.kwbtr                                            as Amount,
      // Line currency, else the statement currency (as ZCL_CD_EBS_SRC_FEB=>MAP_LINE)
      cast( case when Line.kwaer <> ' ' then Line.kwaer else Hdr.waers end as abap.cuky( 5 ) ) as Currency,
      Line.budat                                            as BookingDate,
      Line.valut                                            as ValueDate,
      Line.chect                                            as BankReference,
      // Without leading zeros / blanks: compared with DFKKNRP-INFOF (ZI_CD_NocItem-PaymentRefNorm)
      cast( ltrim( ltrim( Line.chect, ' ' ), '0' ) as abap.char( 50 ) ) as BankRefNorm,
      // Shown as delivered: the company's own house bank account + counter, no customer data
      Line.xblnr                                            as Xblnr,
      // VERIFY-ADT: REPLACE_REGEXPR (PCRE) in a CDS view entity on 7.58; fallback if not
      // activatable: CASE over the configured bank texts (docs/Dashboard_EBS_Validation.md)
      cast( upper( left( ltrim( replace_regexpr( pcre          => '^[A-Za-z]+',
                                                 value         => Line.xblnr,
                                                 with          => '',
                                                 result_length => 16 ), ' ' ), 10 ) ) as abap.char( 10 ) ) as PeAccount,
      Line.belnr                                            as PostingDocument,
      Line.gjahr                                            as PostingYear,
      case when Line.belnr <> ' '
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsPosted
}
where Hdr.azdat >= dats_add_days( $session.system_date, -31, 'INITIAL' )
