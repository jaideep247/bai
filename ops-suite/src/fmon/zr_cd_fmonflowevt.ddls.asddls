// Artifact: zr_cd_fmonflowevt.ddls.asddls
// Purpose: Drill-down of the file monitoring dashboard: the audit trail of one file (ZCD_FMON_EVENT),
//          one row per source event - stage as reported, time, source adapter and reference,
//          counts and amount. Read-only (events are written only by the FMON engine and the
//          manual-status app).
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FMON file monitoring - file event'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_FmonFlowEvt
  as select from zcd_fmon_event
{
  key file_id                                               as FileId,
  key event_no                                              as EventNo,
      cast( 'CD_FMON' as abap.char( 16 ) )                      as PaymentEngineArea,
      // Stage as reported by the source (also when the state machine capped or ignored it)
      stage                                                 as Stage,
      event_at                                              as EventAt,
      // Source adapter; LOT = derived from returns / NOC lots; MANUAL = manual-status app
      src_id                                                as SourceId,
      src_key                                               as SourceKey,
      record_count                                          as RecordCount,
      amount                                                as Amount,
      info                                                  as EventInfo,
      created_by                                            as CreatedBy,
      created_at                                            as CreatedAt
}
