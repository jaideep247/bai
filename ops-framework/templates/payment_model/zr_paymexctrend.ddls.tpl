// Artifact: zr_{{p}}_paymexctrend.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - exceptions raised vs resolved per business date, area, company code
//          and severity (framework store ZCA_OPS_FINDING, last {{WINDOW}} days): raised = created on the date,
//          resolved = resolved on the date. Managers' trend card and IT support's daily failures per area.
//          Aggregated on the database. Read-only.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
// VERIFY-ADT: UNION ALL of two aggregating selects and tstmp_to_dats with the session time zone (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - exceptions per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_PaymExcTrend
  as select from ZI_{{P}}_PaymExcDay
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
