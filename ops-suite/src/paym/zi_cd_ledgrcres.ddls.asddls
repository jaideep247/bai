// Artifact: zi_cd_ledgrcres.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the stored reconciliation result: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          Stored results of A_RECON_3WAY (ZCD_HCK_METRIC RC_* of the latest measurement per group-day and the check's
//          findings of that run, helper views ZI_CD_LedgRcLast / ZI_CD_LedgRcPiv / ZI_CD_LedgRcDay) - reused, never
//          recomputed: the stored G/L leg is the FKKSU part of ACDOCA on the clearing account in ledger EBS_GL_LEDGER.
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter stored reconciliation result'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgRcRes
  as select from ZI_CD_LedgRcDay as Res
{
  key Res.BusinessDate as BusinessDate,
  key Res.CompanyCode as CompanyCode,
  key Res.GlAccount as GlAccount,
  key Res.Currency as Currency,
      Res.BankAmount as BankAmount,
      Res.GlAmount as GlAmount,
      Res.SubledgerAmount as SubledgerAmount,
      Res.BankGlDifference as BankGlDifference,
      Res.GlSubledgerDifference as GlSubledgerDifference,
      Res.Tolerance as Tolerance,
      Res.ResultStatus as ResultStatus,
      Res.Bucket as Bucket,
      Res.MeasuredAt as MeasuredAt
}
