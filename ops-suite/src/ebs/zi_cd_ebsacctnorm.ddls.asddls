// Artifact: zi_cd_ebsacctnorm.ddls.asddls
// Purpose: Active payment engine accounts of the EBS configuration (ZCD_EBS_ACCT, ACTIVE = X, with an
//          account number) with ACCOUNT_NO normalised as ZCL_CD_EBS_PE_SCOPE compares it: leading
//          blanks removed, upper case. ACCOUNT_NO is the 10-character payment engine account as
//          derived from FEBEP-XBLNR (user decision 2026-11-06). Read-only.
// Modification log: 2026-11-06 | Initial version (payment engine account scope from XBLNR).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS active payment engine account'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
@VDM.viewType: #BASIC
define view entity ZI_CD_EbsAcctNorm
  as select from zcd_ebs_acct as Acct
{
  key Acct.bukrs                                            as CompanyCode,
  key Acct.hbkid                                            as HouseBank,
  key Acct.hktid                                            as HouseBankAccount,
      cast( upper( ltrim( Acct.account_no, ' ' ) ) as abap.char( 35 ) ) as AccountNorm,
      Acct.gl_account                                       as GlAccount
}
where Acct.active     =  'X'
  and Acct.account_no <> ' '
