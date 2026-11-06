@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PRISM payment requests handled manually'
@Metadata.ignorePropagatedAnnotations: true
// PRISM payment requests (design 6.5, record only): who handled which request how
define root view entity ZR_CD_FmonPrqWa
  as select from zcd_fmon_prq_wa
{
      @EndUserText.label: 'Record ID'
  key wa_uuid               as WaUuid,
      @EndUserText.label: 'PRISM request'
      request_ref           as RequestRef,
      @EndUserText.label: 'Source'
      source                as Source,
      @EndUserText.label: 'Handling reference'
      reference             as Reference,
      @EndUserText.label: 'Reason'
      reason                as Reason,
      @EndUserText.label: 'Status'
      status                as Status,
      @EndUserText.label: 'Handled by'
      handled_by            as HandledBy,
      @EndUserText.label: 'Handled at'
      handled_at            as HandledAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at       as LastChangedAt
}
