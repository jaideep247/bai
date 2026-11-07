// Artifact: zi_cd_hckrcbankline.ddls.asddls
// Purpose: Bank leg of the three-way reconciliation (check A_RECON_3WAY): bank statement lines
//          (standard FEBEP with the FEBKO statement header) with the payment engine bank account
//          each line carries in FEBEP-XBLNR, derived as EBS does (ZCL_CD_EBS_PE_SCOPE=>
//          PE_ACCOUNT_FROM_XBLNR, ZI_CD_EbsLineAcct): leading letters removed, leading blanks
//          removed, first 10 characters, upper case. Pattern '^[A-Za-z]+' and length 10 are the
//          literals of ZIF_CD_EBS_TYPES=>GC_PE_ACCOUNT (portable check cds_abap_parity). No date
//          window here: ZCL_CD_HCK_RECON_DAO reads it grouped (SUM / COUNT per account, currency,
//          booking day, code, debit / credit) with the reconciliation window and the accounts of
//          the sets (ZCD_EBS_ACCT-ACCOUNT_NO) in the WHERE clause, so HANA aggregates and no line
//          is copied. Fields as ZCL_CD_EBS_FEB_DAO reads them (VORGC, EPVOZ, KWBTR / KWAER,
//          BUDAT, CHECT, XBLNR, BELNR / GJAHR; VERIFY-SE11 as there). Read-only.
// Modification log: 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK reconciliation bank line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_HckRcBankLine
  as select from febep as Line
    inner join   febko as Hdr on Hdr.kukey = Line.kukey
{
  key Line.kukey                                            as Kukey,
  key Line.esnum                                            as Esnum,
      Hdr.bukrs                                             as CompanyCode,
      Hdr.hbkid                                             as HouseBank,
      Hdr.hktid                                             as HouseBankAccount,
      // VERIFY-ADT: REPLACE_REGEXPR (PCRE) in a CDS view entity on 7.58 (as ZI_CD_EbsLineAcct)
      cast( upper( left( ltrim( replace_regexpr( pcre          => '^[A-Za-z]+',
                                                 value         => Line.xblnr,
                                                 with          => '',
                                                 result_length => 16 ), ' ' ), 10 ) ) as abap.char( 35 ) ) as PeAccount,
      Line.vorgc                                            as BaiCode,
      Line.epvoz                                            as DebitCreditInd,
      @Semantics.amount.currencyCode: 'Currency'
      Line.kwbtr                                            as Amount,
      // Line currency, else the statement currency (as ZCL_CD_EBS_SRC_FEB=>MAP_LINE)
      cast( case when Line.kwaer <> ' ' then Line.kwaer else Hdr.waers end as abap.cuky( 5 ) ) as Currency,
      Line.budat                                            as BookingDate,
      Hdr.azdat                                             as StatementDate,
      // Payment document (methods E G H I J K L) = DFKKRP-SELW1 of a returns lot (confirmed path)
      Line.chect                                            as BankReference,
      Line.belnr                                            as PostingDocument,
      Line.gjahr                                            as PostingYear
}
