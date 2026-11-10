// Artifact: zi_cd_payoutrunlast.ddls.asddls
// Purpose: End time of the last completed run of the payment outcome snapshot (ZCA_OPS_RUN, area
//          CORE, variant PAY_OUTCOME, not test mode, status S / W / E - a refused run never counts).
//          Always exactly one row: aggregate without GROUP BY, null end time when no run qualifies.
//          Read-only.
// Modification log: 2026-11-08 | Initial version (snapshot lag row of the production-support overview).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment outcome snapshot last completed run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
// VERIFY-ADT: aggregate without GROUP BY next to a literal element (as ZI_CD_HckRunLast)
define view entity ZI_CD_PayOutRunLast
  as select from zca_ops_run
{
      cast( 'CD_OPS' as abap.char( 16 ) )                      as PaymentEngineArea,
      max( ended_at )                                       as LastEndedAt
}
where area   = 'CD_OPS'
  and variant   = 'PAY_OUTCOME'
  and test_mode = ' '
  and ( status = 'S' or status = 'W' or status = 'E' )
