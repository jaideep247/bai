// Artifact: zc_ca_opspfcard.ddls.asddls
// Purpose: Payment file lifecycle - overview card "Payment files by next milestone": per area, file type, company code,
//          next milestone, state and currency the number of files and payments, the gross amount (in its currency,
//          never summed across currencies), the duplicate exposure and the most minutes overdue - aggregated in the
//          database from the worklist's base view (ZR_CA_OpsPayFile). Read access: DCL ZC_CA_OPSPFCARD.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment files by next milestone'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZC_CA_OpsPfCard
  as select from ZR_CA_OpsPayFile
{
  key Area,
  key FileType,
  key CompanyCode,
  key NextMilestone,
  key State,
  key Currency,
      count( * )                                            as FileCount,
      sum( PaymentCount )                                   as PaymentCount,
      sum( Amount )                                         as Amount,
      sum( DuplicateAmount )                                as DuplicateAmount,
      max( OverdueMinutes )                                 as MaxOverdueMinutes
}
where
  State <> 'DONE'
group by
  Area,
  FileType,
  CompanyCode,
  NextMilestone,
  State,
  Currency
