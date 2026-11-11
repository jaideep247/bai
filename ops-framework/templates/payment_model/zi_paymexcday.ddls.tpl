// Artifact: zi_{{p}}_paymexcday.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - exceptions raised (created) and resolved per local business date,
//          area, company code (blank = area-level) and severity, last {{WINDOW}} days (ZI_{{P}}_PaymExcRow).
//          Aggregated on the database. Read-only.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
// VERIFY-ADT: UNION ALL of two aggregating selects in a CDS view entity (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - exceptions raised / resolved'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_{{P}}_PaymExcDay
  as select from ZI_{{P}}_PaymExcRow
{
  key CreatedOn                                             as BusinessDate,
  key OpsArea,
  key CompanyCode,
  key Severity,
      cast( count( * ) as abap.int4 )                       as RaisedCount,
      cast( 0 as abap.int4 )                                as ResolvedCount
}
where
  CreatedOn >= dats_add_days( $session.system_date, -{{WINDOW}}, 'INITIAL' )
group by
  CreatedOn,
  OpsArea,
  CompanyCode,
  Severity

union all

select from ZI_{{P}}_PaymExcRow
{
  key ResolvedOn                                            as BusinessDate,
  key OpsArea,
  key CompanyCode,
  key Severity,
      cast( 0 as abap.int4 )                                as RaisedCount,
      cast( count( * ) as abap.int4 )                       as ResolvedCount
}
where
  ResolvedOn >= dats_add_days( $session.system_date, -{{WINDOW}}, 'INITIAL' )
group by
  ResolvedOn,
  OpsArea,
  CompanyCode,
  Severity
