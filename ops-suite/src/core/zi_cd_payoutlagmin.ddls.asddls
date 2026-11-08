// Artifact: zi_cd_payoutlagmin.ddls.asddls
// Purpose: The instant up to which the payment outcome snapshot has processed its evidence
//          completely: the oldest CURRENT_TO of the FAST evidence sources of ZCD_PAY_OUTWM (the recheck
//          and the NIGHTLY cursors have no evidence time and are left out; a source without CURRENT_TO yet is left out - as
//          ZCL_CD_OPS_PAY_SNAPSHOT=>LAG). Always exactly one row: aggregate without GROUP BY, null
//          when no source has run. Read-only.
// Modification log: 2026-11-08 | Initial version (snapshot lag, 2 million payments a peak day).
//                   2026-11-08 | NIGHTLY / NIGHTLYREQ cursors left out (exceptions-only worklist).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment outcome snapshot processed up to'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
// VERIFY-ADT: aggregate without GROUP BY next to a literal element (as ZI_CD_HckRunLast)
define view entity ZI_CD_PayOutLagMin
  as select from zcd_pay_outwm
{
      cast( 'CORE' as abap.char( 4 ) )                     as PaymentEngineArea,
      min( current_to )                                     as ProcessedTo
}
where source     <> 'RECHECK'
  and source     <> 'NIGHTLY'
  and source     <> 'NIGHTLYREQ'
  and current_to >  0
