// Artifact: zi_cd_trxack.ddls.asddls
// Purpose: Bank acknowledgements per payment (ACH: ZCD_ACH_ACK, wire: ZCD_WIRE_ACK) of the last
//          45 days, grouped by payment key: ACK and NACK rows (disbursements ACK per payment -
//          payment engine reference). ADT only (cds/): every field below is a VERIFY-SE11
//          placeholder - replace before activation:
//            zz_augbl       -> payment key (expected = DFKKOP-AUGBL / clearing document)
//            zz_ack_status  -> ACK status field; NACK values as TRACE_ACK_NACK_VALUES (NACK, REJECTED, R)
//            zz_ack_date    -> ACK date (DATS)
//          If a table has no payment-level key (file-level ACK only), drop its branch: the file
//          level stays in the file monitoring dashboard. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank ACK per payment (ACH / wire)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CD_TrxAck
  as select from ZI_CD_TrxAckU
{
  key PaymentDocument,
      cast( count( * ) as abap.int4 )                                     as AckRowCount,
      cast( sum( case IsNack when 'X' then 1 else 0 end ) as abap.int4 )  as NackCount,
      max( AckDate )                                                      as LastAckDate
}
group by
  PaymentDocument
