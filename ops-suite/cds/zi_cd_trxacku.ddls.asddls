// Artifact: zi_cd_trxacku.ddls.asddls
// Purpose: ACK rows of ZCD_ACH_ACK and ZCD_WIRE_ACK (last 45 days) in one shape: payment key,
//          channel, NACK flag, date. ADT only (cds/); every field is a VERIFY-SE11 placeholder
//          (see ZI_CD_TrxAck). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank ACK rows (ACH / wire)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CD_TrxAckU
  as select from zcd_ach_ack
{
  // VERIFY-SE11: payment key, status and date fields of ZCD_ACH_ACK
  cast( zz_augbl as abap.char( 12 ) )                       as PaymentDocument,
  cast( 'ACH' as abap.char( 4 ) )                           as AckChannel,
  case when zz_ack_status = 'NACK' or zz_ack_status = 'REJECTED' or zz_ack_status = 'R'
       then cast( 'X' as abap_boolean )
       else cast( ' ' as abap_boolean ) end                 as IsNack,
  zz_ack_date                                               as AckDate
}
where zz_ack_date >= dats_add_days( $session.system_date, -45, 'INITIAL' )
union all
  select from zcd_wire_ack
{
  // VERIFY-SE11: payment key (wire reference), status and date fields of ZCD_WIRE_ACK
  cast( zz_augbl as abap.char( 12 ) )                       as PaymentDocument,
  cast( 'WIRE' as abap.char( 4 ) )                          as AckChannel,
  case when zz_ack_status = 'NACK' or zz_ack_status = 'REJECTED' or zz_ack_status = 'R'
       then cast( 'X' as abap_boolean )
       else cast( ' ' as abap_boolean ) end                 as IsNack,
  zz_ack_date                                               as AckDate
}
where zz_ack_date >= dats_add_days( $session.system_date, -45, 'INITIAL' )
