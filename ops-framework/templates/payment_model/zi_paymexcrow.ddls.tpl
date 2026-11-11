// Artifact: zi_{{p}}_paymexcrow.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - findings of the store ZCA_OPS_FINDING of the consumer's areas
//          ({{AREA_LIST}}) created or resolved in the last {{WINDOW}} days, with the local business date of the
//          creation and of the resolution (time zone of the control review, ZI_CA_OpsCtlTz). Read-only.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
// VERIFY-ADT: index of ZCA_OPS_FINDING on CREATED_AT / RESOLVED_AT for the window (PlanViz).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - findings of the window'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_{{P}}_PaymExcRow
  as select from zca_ops_finding as Fnd
    inner join   ZI_CA_OpsCtlTz  as Tz on Tz.Language = $session.system_language
{
  key Fnd.run_id                                            as RunId,
  key Fnd.finding_no                                        as FindingNo,
      tstmp_to_dats( cast( Fnd.created_at as timestamp ), Tz.TimeZone, $session.client, 'NULL' ) as CreatedOn,
      tstmp_to_dats( cast( Fnd.resolved_at as timestamp ), Tz.TimeZone, $session.client, 'NULL' ) as ResolvedOn,
      cast( Fnd.area as abap.char( 16 ) )                   as OpsArea,
      Fnd.bukrs                                             as CompanyCode,
      Fnd.severity                                          as Severity
}
where
  ( {{AREA_FILTER}} )
  and (    Fnd.created_at  >= cast( tstmp_add_seconds( tstmp_current_utctimestamp(),
                                                       cast( {{WINDOW_SECONDS}} as abap.dec( 15, 0 ) ), 'INITIAL' )
                                    as abap.dec( 21, 7 ) )
        or Fnd.resolved_at >= cast( tstmp_add_seconds( tstmp_current_utctimestamp(),
                                                       cast( {{WINDOW_SECONDS}} as abap.dec( 15, 0 ) ), 'INITIAL' )
                                    as abap.dec( 21, 7 ) ) )
