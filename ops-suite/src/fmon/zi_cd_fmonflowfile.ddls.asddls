// Artifact: zi_cd_fmonflowfile.ddls.asddls
// Purpose: Basic interface view of the file monitoring dashboard (docs/Dashboard_File_Monitoring.md):
//          one row per monitored file instance of ZCD_FMON_FILE with its interface attributes
//          (bank, ACK expected) from ZCD_FMON_IFACE, the flow bucket (current position in the
//          file lifecycle), the success flag and per-file measures. Read-only.
//          Stage literals are the values of ZIF_CD_FMON_TYPES=>GC_STAGE (CDS cannot read ABAP
//          constants); the mapping is the bucket table in Dashboard_File_Monitoring.md section 3.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FMON file monitoring - file (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_FmonFlowFile
  as select from    zcd_fmon_file  as File
    left outer join zcd_fmon_iface as Iface on Iface.iface_id = File.iface_id
{
  key File.file_id                                          as FileId,
      // Same text as ZCL_CD_FMON_UTIL=>FILE_HEX (REFERENCE of every file finding).
      // VERIFY-ADT: BINTOHEX in a view entity on 7.58 returns upper-case hex like ABAP
      cast( bintohex( File.file_id ) as abap.char( 35 ) )   as FileIdHex,
      // Constant area of every row: drives the DCL (ZCD_OPS / ZCA_PARAR = FMON)
      cast( 'CD_FMON' as abap.char( 16 ) )                      as PaymentEngineArea,
      File.iface_id                                         as IfaceId,
      Iface.description                                     as IfaceDescription,
      File.direction                                        as Direction,
      File.file_type                                        as FileType,
      File.source_sys                                       as SourceSystem,
      File.lob                                              as Lob,
      File.pay_method                                       as PaymentMethod,
      // Bank is a property of the interface (the file row carries none); blank = any bank
      Iface.bank_key                                        as BankKey,
      Iface.target_sys                                      as TargetSystem,
      Iface.owner                                           as IfaceOwner,
      // Interface row missing (deleted or renamed): treated as ACK expected - success is never
      // claimed without the evidence the interface would need
      cast( coalesce( Iface.ack_expected, 'X' ) as abap_boolean ) as AckExpected,
      Iface.ack_level                                       as AckLevel,
      File.file_ref                                         as FileRef,
      File.file_name                                        as FileName,
      File.business_date                                    as BusinessDate,
      case when File.business_date = $session.system_date
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsToday,
      File.stage                                            as Stage,
      File.outcome                                          as Outcome,
      // Bucket = where the file is now (mutually exclusive, sums to the file count).
      // The terminal outcome wins over the stage; literals = ZIF_CD_FMON_TYPES=>GC_STAGE.
      // PRISM_RECEIVED / PRISM_DELIVERED / PRISM_FAILED: stages of the PRISM status API (built in
      // parallel, values agreed 2026-11-06) - inactive until the API writes them; accepted as
      // stage or outcome. PRISM_DELIVERED: outbound = delivered to the bank / IRIS / source (SENT),
      // inbound = delivered to SAP (RECEIVED).
      cast( case
              when File.outcome = 'ACK_RECEIVED'          then 'ACKNOWLEDGED'
              when File.outcome = 'NACK_REJECTED'         then 'REJECTED'
              when File.outcome = 'FAILED'                then 'REJECTED'
              when File.outcome = 'PRISM_FAILED'          then 'REJECTED'
              when File.outcome = 'PARTIALLY_PROCESSED'   then 'PARTIAL'
              when File.outcome = 'FULLY_PROCESSED'       then 'PROCESSED'
              when File.stage   = 'FILE_RECEIVED'         then 'RECEIVED'
              when File.stage   = 'GENERATED_IN_SAP'      then 'RECEIVED'
              when File.stage   = 'PRISM_RECEIVED'        then 'AT_PRISM'
              when File.stage   = 'PRISM_DELIVERED' and File.direction = 'I' then 'RECEIVED'
              when File.stage   = 'PRISM_DELIVERED'       then 'SENT'
              when File.stage   = 'FILE_LOADED'           then 'PROCESSED'
              when File.stage   = 'FULLY_PROCESSED'       then 'PROCESSED'
              when File.stage   = 'SENT_TO_PRISM'         then 'SENT'
              when File.stage   = 'FORWARDED_TO_BANK'     then 'SENT'
              when File.stage   = 'ACK_RECEIVED'          then 'ACKNOWLEDGED'
              when File.stage   = 'NACK_REJECTED'         then 'REJECTED'
              when File.stage   = 'FAILED'                then 'REJECTED'
              when File.stage   = 'PRISM_FAILED'          then 'REJECTED'
              when File.stage   = 'PARTIALLY_PROCESSED'   then 'PARTIAL'
              else 'UNKNOWN' end as abap.char( 12 ) )       as FlowBucket,
      // Success: inbound fully processed; outbound acknowledged without a payment-level NACK,
      // or - for an interface without ACK - handed over (sent to / received by PRISM, delivered,
      // forwarded to the bank) and not rejected
      case
        when File.direction = 'I' and File.outcome = 'FULLY_PROCESSED'
          then cast( 'X' as abap_boolean )
        when File.direction = 'O' and File.outcome = 'ACK_RECEIVED' and File.nack_count = 0
          then cast( 'X' as abap_boolean )
        when File.direction = 'O' and coalesce( Iface.ack_expected, 'X' ) = ' '
         and File.outcome <> 'NACK_REJECTED' and File.outcome <> 'PRISM_FAILED'
         and ( File.stage = 'SENT_TO_PRISM' or File.stage = 'PRISM_RECEIVED' or File.stage = 'PRISM_DELIVERED'
            or File.stage = 'FORWARDED_TO_BANK' or File.stage = 'ACK_RECEIVED' )
          then cast( 'X' as abap_boolean )
        else cast( ' ' as abap_boolean ) end                as IsSuccess,
      File.first_event_at                                   as FirstEventAt,
      File.last_event_at                                    as LastEventAt,
      // ---------------------------------------------------------------- measures (per file)
      cast( 1 as abap.int4 )                                as FileCount,
      cast( case
              when File.direction = 'I' and File.outcome = 'FULLY_PROCESSED' then 1
              when File.direction = 'O' and File.outcome = 'ACK_RECEIVED' and File.nack_count = 0 then 1
              when File.direction = 'O' and coalesce( Iface.ack_expected, 'X' ) = ' '
               and File.outcome <> 'NACK_REJECTED' and File.outcome <> 'PRISM_FAILED'
               and ( File.stage = 'SENT_TO_PRISM' or File.stage = 'PRISM_RECEIVED' or File.stage = 'PRISM_DELIVERED'
                  or File.stage = 'FORWARDED_TO_BANK' or File.stage = 'ACK_RECEIVED' )
                then 1
              else 0 end as abap.int4 )                     as SuccessFileCount,
      // Reached at least: inbound loaded (processed fully or partly, or still loading)
      cast( case
              when File.direction = 'I'
               and ( File.stage = 'FILE_LOADED' or File.stage = 'FULLY_PROCESSED' or File.stage = 'PARTIALLY_PROCESSED'
                  or File.outcome = 'FULLY_PROCESSED' or File.outcome = 'PARTIALLY_PROCESSED' )
                then 1
              else 0 end as abap.int4 )                     as ProcessedFileCount,
      // Reached at least: outbound sent to PRISM (also received / delivered by PRISM, forwarded,
      // acknowledged or rejected by the bank)
      cast( case
              when File.direction = 'O'
               and ( File.stage = 'SENT_TO_PRISM' or File.stage = 'PRISM_RECEIVED' or File.stage = 'PRISM_DELIVERED'
                  or File.stage = 'FORWARDED_TO_BANK' or File.stage = 'ACK_RECEIVED' or File.stage = 'NACK_REJECTED' )
                then 1
              else 0 end as abap.int4 )                     as SentFileCount,
      // Bucket counts (acknowledged, rejected, ...) are derived from FlowBucket in ZR_CD_FmonFlow
      File.record_count                                     as RecordCount,
      // Control total in the interface contract currency: the file row stores no currency
      // (Dashboard_File_Monitoring.md section 4) - never add totals across currencies
      File.control_total                                    as ControlTotal,
      File.ack_count                                        as AckCount,
      File.ack_amount                                       as AckAmount,
      // X = the source reported the ACK / NACK count; blank = not reported (not zero)
      File.ack_known                                        as AckCountKnown,
      File.nack_count                                       as NackCount,
      File.unprocessed_count                                as UnprocessedCount,
      File.origin_rows                                      as OriginRows
}
