// Artifact: zr_xx_paymexctrend.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the example customer XX (intake) - exceptions raised vs resolved per business date, area, company code
//          and severity (framework store ZCA_OPS_FINDING, last 40 days): raised = created on the date,
//          resolved = resolved on the date. Managers' trend card and IT support's daily failures per area.
//          Aggregated on the database. Read-only.
// Modification log: 2026-11-16 | Generated from the product template (payment model).
// VERIFY-ADT: UNION ALL of two aggregating selects and tstmp_to_dats with the session time zone (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - exceptions per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_XX_PaymExcTrend
  as select from ZI_XX_PaymExcDay
{
  key BusinessDate,
  key OpsArea,
  key CompanyCode,
  key Severity,
      dats_days_between( BusinessDate, $session.system_date ) as DaysAgo,
      cast( sum( RaisedCount ) as abap.int4 )               as RaisedCount,
      cast( sum( ResolvedCount ) as abap.int4 )             as ResolvedCount
}
group by
  BusinessDate,
  OpsArea,
  CompanyCode,
  Severity
