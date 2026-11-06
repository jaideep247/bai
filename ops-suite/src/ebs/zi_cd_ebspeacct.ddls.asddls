// Artifact: zi_cd_ebspeacct.ddls.asddls
// Purpose: One row per active payment engine account (normalised ZCD_EBS_ACCT-ACCOUNT_NO) with its
//          bank G/L account. Two active rows with the same account number are one payment engine
//          account (as ZCL_CD_EBS_PE_SCOPE), so a line never appears twice; the G/L account is then
//          the highest of them (one G/L account per payment engine account expected). Read-only.
// Modification log: 2026-11-06 | Initial version (payment engine account scope from XBLNR).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS payment engine account'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_EbsPeAcct
  as select from ZI_CD_EbsAcctNorm
{
  key AccountNorm                                           as PeAccount,
      max( GlAccount )                                      as GlAccount
}
group by
  AccountNorm
