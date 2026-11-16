// Artifact: zi_ca_opspffilecur.ddls.asddls
// Purpose: Payment file lifecycle - the payments of a file per currency, aggregated in the database (ZCA_OPS_PFPAY):
//          number of payments, gross amount, payments without a known amount, payments another file carries too
//          (reissue) and their amount = the possible duplicate exposure. One row per file and currency: amounts are
//          never summed across currencies. Read-only; the reading entity's DCL decides who sees the file.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
// VERIFY-ADT (V178): IS INITIAL on a RAW element in a CASE of an aggregate (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file amounts per currency'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsPfFileCur
  as select from zca_ops_pfpay as Pay
{
  key Pay.area                                                     as Area,
  key Pay.file_id                                                  as FileId,
  key Pay.currency                                                 as Currency,
      count( * )                                                   as PaymentCount,
      sum( Pay.amount )                                            as Amount,
      sum( case Pay.amount_known when 'X' then 0 else 1 end )      as UnknownCount,
      sum( case when Pay.other_file is initial then 0 else 1 end ) as DuplicateCount,
      sum( case when Pay.other_file is initial then cast( 0 as abap.dec( 23, 2 ) )
                else Pay.amount end )                              as DuplicateAmount
}
group by
  Pay.area,
  Pay.file_id,
  Pay.currency
