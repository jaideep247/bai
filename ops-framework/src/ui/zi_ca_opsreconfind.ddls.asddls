// Artifact: zi_ca_opsreconfind.ddls.asddls
// Purpose: Alert reconciliation, first leg (build O, docs/EVALUATION_AND_COVERAGE.md section 4): per run, the owned
//          exceptions it recorded (severity B / E / W) - the findings the alert rules could route - and of them the
//          blocking ones (B / E). Index on RUN_ID (key). Nothing stored, read-only.
// Modification log: 2026-11-16 | Initial version (build O: alert delivery reconciliation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert reconciliation: exceptions per run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsReconFind
  as select from zca_ops_finding as Fnd
{
  key Fnd.run_id                                            as RunId,
      cast( sum( case when Fnd.severity = 'B' or Fnd.severity = 'E' or Fnd.severity = 'W'
                      then 1 else 0 end ) as abap.int4 )    as ExceptionCount,
      cast( sum( case when Fnd.severity = 'B' or Fnd.severity = 'E'
                      then 1 else 0 end ) as abap.int4 )    as BlockingCount
}
group by
  Fnd.run_id
